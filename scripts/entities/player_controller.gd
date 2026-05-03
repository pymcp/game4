## PlayerController
##
## Top-down 2D player. Lives in coordinates measured in NATIVE pixels
## (16-px tiles). The parent WorldRoot is scaled by `WorldConst.RENDER_ZOOM`,
## so this controller does not multiply by zoom itself.
##
## - WASD / arrows / gamepad analogue stick (8-directional, normalized).
## - Walkability check: `_world.is_walkable(cell)` where cell = floor(pos / 16).
## - Sprite container is h-flipped to face left / right.
## - 1-2 px vertical bob while moving (sprite-only, not collision).
## - Edge-of-map: clamp to the current map size.
##
## A `Camera2D` child is the per-player viewport camera; it follows the
## player automatically. The whole node is meant to be added to
## `WorldRoot.entities`.
extends Node2D
class_name PlayerController

signal player_died(player_id: int)
signal leveled_up(player_id: int, new_level: int)

const _MOVE_SPEED_NATIVE: float = 60.0  ## native px/sec (≈3.75 tiles/s)
const _BOB_AMP_PX: float = 1.0
const _BOB_HZ: float = 6.0

@export var player_id: int = 0

var in_conversation: bool = false  ## Set by WorldRoot during dialogue.
var _world: WorldRoot = null
var _sprite_root: Node2D = null
var _weapon_sprite: Sprite2D = null
var _torso_sprite: Sprite2D = null
var _hair_sprite: Sprite2D = null
var _face_sprite: Sprite2D = null
var _boots_sprite: Sprite2D = null
var _shield_sprite: Sprite2D = null
var _action_vfx: ActionVFX = null
var _damage_heart_vfx: DamageHeartVFX = null
var _default_torso_region: Rect2
var _default_hair_region: Rect2
var _bob_t: float = 0.0
var _facing_x: int = 1
var _facing_dir: Vector2i = Vector2i(1, 0)
var _attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_SEC: float = 0.35  ## seconds between swings
var auto_mine: bool = false
var auto_attack: bool = false
var is_dead: bool = false
var _invincible_timer: float = 0.0
const _INVINCIBLE_DURATION: float = 3.0

# ── Dodge roll state ─────────────────────────────────────────────────
const DODGE_COOLDOWN_SEC: float = 0.8
const DODGE_DURATION_SEC: float = 0.2
const DODGE_DISTANCE_PX: float = 40.0   ## 2.5 tiles
const DODGE_IFRAMES_SEC: float = 0.15
var _dodge_cooldown: float = 0.0
var _dodge_timer: float = 0.0           ## > 0 while mid-roll
var _dodge_dir: Vector2 = Vector2.ZERO
var is_dodging: bool = false

# ── Block / parry state ──────────────────────────────────────────────
const PARRY_WINDOW_SEC: float = 0.15
const BLOCK_DAMAGE_MULT: float = 0.25   ## take 25% damage while blocking
const BLOCK_SPEED_MULT: float = 0.5
var is_blocking: bool = false
var _block_timer: float = 0.0           ## time since block started (for parry window)

# ── Charge attack state ──────────────────────────────────────────────
const CHARGE_MAX_SEC: float = 1.0       ## time to reach full charge
const CHARGE_DAMAGE_MULT: float = 2.0   ## bonus multiplier at full charge
const CHARGE_THRESHOLD_SEC: float = 0.2 ## hold time before it counts as charging
var _charge_timer: float = 0.0          ## how long attack has been held
var is_charging: bool = false
const _DEATH_WAIT_SEC: float = 5.0
const _AUTO_MINE_RADIUS: int = 1       ## tiles around player to scan
const _MELEE_REACH_PX: float = 24.0    ## native-px radius for melee auto-attack
const _RANGED_REACH_PX: float = 80.0   ## native-px max range for ranged auto-attack
var hitbox_radius: float = 5.0  ## Gungeon-style body-core radius (native px).
var inventory: Inventory = Inventory.new()
var equipment: Equipment = Equipment.new()
var caravan_data: CaravanData = null
var max_health: int = 10
var health: int = 10
var is_sailing: bool = false
var is_mounted: bool = false
var _mount: Mount = null
var stats: Dictionary = {
	&"charisma": 3, &"wisdom": 3, &"strength": 3,
	&"speed": 0, &"defense": 0, &"dexterity": 0,
}
var fog_of_war: FogOfWarData = FogOfWarData.new()
## Per-floor fog-of-war for dungeons and labyrinths (keyed by map_id).
var dungeon_fog: DungeonFogData = DungeonFogData.new()
var world_map: WorldMapView = null
var dungeon_map: DungeonMapView = null
## Active status effects: Array of {effect_id: StringName, remaining: float, tick_timer: float}
var active_effects: Array[Dictionary] = []
var xp: int = 0
var level: int = 1
var unlocked_passives: Array[StringName] = []
var _pending_stat_points: int = 0


## Base stat value (no equipment bonuses).
func get_stat(stat: StringName) -> int:
	return int(stats.get(stat, 0))

## Grant XP. Triggers level-up loop while threshold is met. No-op at cap (level 20).
func gain_xp(amount: int) -> void:
	if level >= 20:
		return
	xp += amount
	while level < 20 and xp >= LevelingConfig.xp_to_next(level):
		xp -= LevelingConfig.xp_to_next(level)
		_level_up()

## Apply a single level-up: +2 max HP, check milestone passive, add stat point, emit signal.
func _level_up() -> void:
	level += 1
	max_health += 2
	health = min(health + 2, max_health)
	var passive: StringName = LevelingConfig.milestone_passive(level)
	if passive != &"":
		_unlock_passive(passive)
	_pending_stat_points += 1
	ActionParticles.flash_level_up(self)
	leveled_up.emit(player_id, level)

## Unlock a passive and apply its immediate effect.
func _unlock_passive(key: StringName) -> void:
	if key in unlocked_passives:
		return
	unlocked_passives.append(key)
	match key:
		&"hardy":
			max_health += 4
			health = min(health + 4, max_health)
		&"hero":
			for k: StringName in stats.keys():
				stats[k] = int(stats[k]) + 2

## Spend one pending stat point on the given stat. Called by LevelUpPanel.
func spend_stat_point(stat: StringName) -> void:
	if _pending_stat_points <= 0:
		return
	stats[stat] = int(stats.get(stat, 0)) + 1
	_pending_stat_points -= 1


## Effective stat = base + equipment bonuses.
func get_effective_stat(stat: StringName) -> int:
	var base: int = get_stat(stat)
	var bonus: int = equipment.equipment_stat_totals().get(stat, 0)
	return base + bonus


## Movement speed in native px/sec, modified by speed stat.
## Each point of effective speed = +5%. Mounted speed uses the mount's
## multiplier on top of the base speed.
func get_move_speed() -> float:
	var spd: int = get_effective_stat(&"speed")
	var base: float = _MOVE_SPEED_NATIVE * (1.0 + spd * 0.05)
	if is_mounted and _mount != null:
		base *= _mount.speed_multiplier
	base *= get_status_speed_multiplier()
	return base
var _boat: Boat = null

const _INTERACT_RADIUS_PX: float = 24.0  ## native pixels


func _ready() -> void:
	var n: Node = get_parent()
	while n != null and not (n is WorldRoot):
		n = n.get_parent()
	_world = n as WorldRoot
	_sprite_root = $SpriteRoot
	_weapon_sprite = $SpriteRoot/Weapon
	_torso_sprite = $SpriteRoot/Torso
	_hair_sprite = $SpriteRoot/Hair
	_face_sprite = $SpriteRoot/Face
	_boots_sprite = $SpriteRoot/Boots
	_shield_sprite = $SpriteRoot/Shield
	_default_torso_region = _torso_sprite.region_rect
	_default_hair_region = _hair_sprite.region_rect
	_action_vfx = $ActionVFX as ActionVFX
	if _action_vfx != null:
		_action_vfx.setup(self, _weapon_sprite, _world, _sprite_root)
	_damage_heart_vfx = DamageHeartVFX.new()
	_damage_heart_vfx.name = "DamageHeartVFX"
	add_child(_damage_heart_vfx)
	equipment.contents_changed.connect(_update_weapon_sprite)
	equipment.contents_changed.connect(_update_armor_sprites)
	equipment.contents_changed.connect(_update_shield_sprite)
	var fog_timer := Timer.new()
	fog_timer.name = "FogRevealTimer"
	fog_timer.wait_time = 0.3
	fog_timer.autostart = true
	fog_timer.one_shot = false
	fog_timer.timeout.connect(_on_fog_reveal_timer_timeout)
	add_child(fog_timer)


## Update the WorldRoot reference. Called by [World] after re-parenting
## the player into a different instance (e.g. on view change).
func set_world(w: WorldRoot) -> void:
	_world = w
	if _action_vfx != null:
		_action_vfx._world = w


## Transfer all crafting ingredient items from this player's inventory to the
## caravan's shared inventory. Called automatically when the player transitions
## back to the overworld. No-op if caravan_data is null.
func trigger_overworld_transfer() -> void:
	if caravan_data == null or caravan_data.inventory == null:
		return
	# Collect items to transfer first — do not modify slots during iteration.
	var to_transfer: Array = []
	for i in inventory.size:
		var slot = inventory.slots[i]
		if slot == null:
			continue
		var item_id: StringName = slot["id"]
		var def: ItemDefinition = ItemRegistry.get_item(item_id)
		if def != null and def.is_crafting_ingredient:
			to_transfer.append({"id": item_id, "count": slot["count"]})
	# Transfer collected items.
	for entry in to_transfer:
		var removed: int = inventory.remove(entry["id"], entry["count"])
		if removed > 0:
			caravan_data.inventory.add(entry["id"], removed)


func _update_weapon_sprite() -> void:
	if _weapon_sprite == null:
		return
	# Priority: WEAPON slot, then TOOL slot.
	var item_id: StringName = equipment.get_equipped(ItemDefinition.Slot.WEAPON)
	if item_id == &"":
		item_id = equipment.get_equipped(ItemDefinition.Slot.TOOL)
	if item_id == &"":
		_weapon_sprite.visible = false
		return
	# Prefer hires icon when available (AtlasTexture from hires spritesheet).
	var def: ItemDefinition = ItemRegistry.get_item(item_id)
	if def != null and def.icon != null:
		_weapon_sprite.region_enabled = false
		_weapon_sprite.texture = def.icon
		var tex_w: int = def.icon.get_width()
		var s: float = float(WorldConst.TILE_PX) / float(tex_w) if tex_w > 0 else 1.0
		_weapon_sprite.scale = Vector2(s, s)
		_weapon_sprite.visible = true
		return
	# Fall back to character-sheet weapon atlas.
	var region: Rect2 = WeaponAtlas.region_for(item_id)
	if region.size == Vector2.ZERO:
		_weapon_sprite.visible = false
		return
	_weapon_sprite.texture = load(CharacterAtlas.SHEET_PATH) as Texture2D
	_weapon_sprite.region_enabled = true
	_weapon_sprite.scale = Vector2.ONE
	_weapon_sprite.region_rect = region
	_weapon_sprite.visible = true


func _update_armor_sprites() -> void:
	# --- BODY slot → Torso sprite ---
	_apply_armor_layer(
		_torso_sprite, _default_torso_region,
		equipment.get_equipped(ItemDefinition.Slot.BODY))
	# --- HEAD slot → Hair sprite ---
	_apply_armor_layer(
		_hair_sprite, _default_hair_region,
		equipment.get_equipped(ItemDefinition.Slot.HEAD))
	# --- FEET slot → Boots sprite ---
	var boots_id: StringName = equipment.get_equipped(ItemDefinition.Slot.FEET)
	var boots_region: Rect2 = ArmorAtlas.region_for(boots_id)
	if boots_region.size == Vector2.ZERO:
		_boots_sprite.visible = false
	else:
		_boots_sprite.region_rect = boots_region
		_boots_sprite.modulate = ArmorAtlas.tint_for(boots_id)
		_boots_sprite.visible = true


func _update_shield_sprite() -> void:
	if _shield_sprite == null:
		return
	var item_id: StringName = equipment.get_equipped(ItemDefinition.Slot.OFF_HAND)
	if item_id == &"":
		_shield_sprite.visible = false
		return
	var def: ItemDefinition = ItemRegistry.get_item(item_id)
	if def == null or def.shield_sprite == Vector2i(-1, -1):
		_shield_sprite.visible = false
		return
	_shield_sprite.region_rect = Rect2(
		def.shield_sprite.x * CharacterAtlas.STRIDE,
		def.shield_sprite.y * CharacterAtlas.STRIDE,
		CharacterAtlas.TILE,
		CharacterAtlas.TILE,
	)
	_shield_sprite.visible = true


## Apply a CharacterBuilder-compatible appearance dict to this player's
## paper-doll sprites. Updates the default regions so armor equip/unequip
## restores the chosen base look.
func apply_appearance(opts: Dictionary) -> void:
	if opts.is_empty():
		return
	# Body (skin tone).
	var body_sprite: Sprite2D = _sprite_root.get_node_or_null("Body") as Sprite2D
	if body_sprite != null:
		var body_cell: Vector2i = CharacterAtlas.body_cell(opts.get("skin", &"light"))
		body_sprite.region_rect = Rect2(CharacterAtlas.tile_rect(body_cell))
	# Torso.
	var torso_cell: Vector2i = CharacterAtlas.torso_cell(
		opts.get("torso_color", &"orange"),
		int(opts.get("torso_style", 0)),
		int(opts.get("torso_row", 0)))
	if torso_cell.x >= 0 and _torso_sprite != null:
		var torso_rect := Rect2(CharacterAtlas.tile_rect(torso_cell))
		_torso_sprite.region_rect = torso_rect
		_default_torso_region = torso_rect
	# Hair.
	if opts.has("hair_color"):
		var h_style: int = int(opts.get("hair_style", CharacterAtlas.HairStyle.SHORT))
		var h_variant: int = int(opts.get("hair_variant", 0))
		var hair_cell: Vector2i = CharacterAtlas.hair_cell(opts["hair_color"], h_style, h_variant)
		if hair_cell.x >= 0 and _hair_sprite != null:
			var hair_rect := Rect2(CharacterAtlas.tile_rect(hair_cell))
			_hair_sprite.region_rect = hair_rect
			_default_hair_region = hair_rect
	# Face (facial hair).
	if _face_sprite != null:
		if opts.has("face_color"):
			var face_cell: Vector2i = CharacterAtlas.hair_cell(
				opts["face_color"], CharacterAtlas.HairStyle.FACIAL,
				int(opts.get("face_variant", 0)))
			if face_cell.x >= 0:
				_face_sprite.region_rect = Rect2(CharacterAtlas.tile_rect(face_cell))
				_face_sprite.visible = true
			else:
				_face_sprite.visible = false
		else:
			_face_sprite.visible = false


## Shared helper: swap a sprite's region to the armor cell, or restore its
## default appearance when the slot is empty.
func _apply_armor_layer(sprite: Sprite2D, default_region: Rect2,
		item_id: StringName) -> void:
	if sprite == null:
		return
	var region: Rect2 = ArmorAtlas.region_for(item_id)
	if region.size == Vector2.ZERO:
		sprite.region_rect = default_region
		sprite.modulate = Color(1, 1, 1)
		return
	sprite.region_rect = region
	sprite.modulate = ArmorAtlas.tint_for(item_id)


func _physics_process(delta: float) -> void:
	# Tick invincibility regardless of world state so tests can verify timer behaviour.
	if _invincible_timer > 0.0:
		_invincible_timer = max(0.0, _invincible_timer - delta)
	if _world == null:
		return
	tick_effects(delta)
	# Drive flashing visual while invincible.
	if _invincible_timer > 0.0:
		# Flash: visible every other 0.15s window.
		if _sprite_root != null:
			_sprite_root.visible = int(_invincible_timer / 0.15) % 2 == 0
	else:
		if _sprite_root != null:
			_sprite_root.visible = true
	# Freeze this player while they are in a conversation.
	if in_conversation:
		_bob_t = 0.0
		_sprite_root.position = Vector2.ZERO
		# Still allow the interact key to dismiss / advance dialogue.
		if Input.is_action_just_pressed(PlayerActions.action(player_id, PlayerActions.INTERACT)):
			_try_interact()
		elif Input.is_action_just_pressed(PlayerActions.action(player_id, PlayerActions.BACK)):
			_world.hide_dialogue()
		return
	# Skip all gameplay input when this player isn't in GAMEPLAY context
	# (inventory open, disabled by pause menu, etc.).
	if InputContext.get_context(player_id) != InputContext.Context.GAMEPLAY:
		_bob_t = 0.0
		_sprite_root.position = Vector2.ZERO
		return
	if is_stunned():
		_bob_t = 0.0
		_sprite_root.position = Vector2.ZERO
		return
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_dodge_cooldown = max(0.0, _dodge_cooldown - delta)
	# ── Dodge roll tick ──────────────────────────────────────────────
	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		var speed: float = DODGE_DISTANCE_PX / DODGE_DURATION_SEC
		_step(_dodge_dir * speed * delta)
		if _dodge_timer <= 0.0:
			is_dodging = false
			# Restore sprite shape after squish.
			if _sprite_root != null:
				_sprite_root.scale = Vector2(_facing_x, 1)
		return  # No other input during dodge.
	# ── Block state ──────────────────────────────────────────────────
	var block_action: StringName = PlayerActions.action(player_id, PlayerActions.BLOCK)
	if Input.is_action_pressed(block_action):
		if not is_blocking:
			is_blocking = true
			_block_timer = 0.0
		else:
			_block_timer += delta
	else:
		is_blocking = false
		_block_timer = 0.0
	if Input.is_action_just_pressed(PlayerActions.action(player_id, PlayerActions.INTERACT)):
		_try_interact()
		# Re-check context: interact may have opened a menu (caravan, shop, etc.).
		if InputContext.get_context(player_id) != InputContext.Context.GAMEPLAY:
			return
	if Input.is_action_just_pressed(PlayerActions.action(player_id, PlayerActions.AUTO_MINE)):
		auto_mine = not auto_mine
	if Input.is_action_just_pressed(PlayerActions.action(player_id, PlayerActions.AUTO_ATTACK)):
		auto_attack = not auto_attack
	# ── Dodge input ──────────────────────────────────────────────────
	if Input.is_action_just_pressed(PlayerActions.action(player_id, PlayerActions.DODGE)):
		if _dodge_cooldown <= 0.0:
			_start_dodge()
			return
	# ── Attack (blocked while blocking) ──────────────────────────────
	if not is_blocking:
		var atk_action: StringName = PlayerActions.action(player_id, PlayerActions.ATTACK)
		if Input.is_action_just_pressed(atk_action):
			if is_mounted and _mount != null and _mount.can_jump:
				_mount.try_hop(_facing_dir)
			elif _attack_cooldown <= 0.0:
				_charge_timer = 0.0
				is_charging = true
		elif is_charging and Input.is_action_pressed(atk_action):
			_charge_timer = minf(_charge_timer + delta, CHARGE_MAX_SEC)
			if _charge_timer >= CHARGE_THRESHOLD_SEC:
				_show_charge_visual()
		elif is_charging:
			# Released — fire the attack with charge multiplier.
			var mult: float = _get_charge_multiplier()
			is_charging = false
			_hide_charge_visual()
			if _attack_cooldown <= 0.0:
				try_attack(mult)
				_attack_cooldown = ATTACK_COOLDOWN_SEC
		# Auto-mine: mine nearest mineable within radius when cooldown ready.
		if auto_mine and _attack_cooldown <= 0.0 and not is_charging:
			_tick_auto_mine()
		# Auto-attack: attack nearby hostiles or fire ranged in facing dir.
		if auto_attack and _attack_cooldown <= 0.0 and not is_charging:
			_tick_auto_attack()
	var input := Vector2(
		Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.RIGHT))
			- Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.LEFT)),
		Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.DOWN))
			- Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.UP)),
	)
	var moving: bool = input.length_squared() > 0.0001
	if moving:
		if input.length() > 1.0:
			input = input.normalized()
		var speed: float = get_move_speed()
		if is_blocking:
			speed *= BLOCK_SPEED_MULT
		_step(input * speed * delta)
		if input.x > 0.05:
			_facing_x = 1
		elif input.x < -0.05:
			_facing_x = -1
		# Track 8-direction facing for attack/mine target selection.
		# Both components are preserved for diagonal movement.
		_facing_dir = Vector2i(signi(input.x), signi(input.y))
		_sprite_root.scale = Vector2(_facing_x, 1)
		if _action_vfx == null or not _action_vfx.is_playing():
			_bob_t += delta
			var bob: float = sin(_bob_t * TAU * _BOB_HZ) * _BOB_AMP_PX
			_sprite_root.position = Vector2(0, -bob)
	else:
		if _action_vfx == null or not _action_vfx.is_playing():
			_bob_t = 0.0
			_sprite_root.position = Vector2.ZERO


# ── Dodge roll ────────────────────────────────────────────────────────

func _start_dodge() -> void:
	# Direction: use current movement input, fall back to facing direction.
	var input := Vector2(
		Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.RIGHT))
			- Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.LEFT)),
		Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.DOWN))
			- Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.UP)),
	)
	if input.length_squared() < 0.01:
		input = Vector2(_facing_dir)
	_dodge_dir = input.normalized()
	_dodge_timer = DODGE_DURATION_SEC
	_dodge_cooldown = DODGE_COOLDOWN_SEC
	is_dodging = true
	is_blocking = false
	_block_timer = 0.0
	# Cancel charge on dodge.
	if is_charging:
		is_charging = false
		_charge_timer = 0.0
		_hide_charge_visual()
	# VFX: squish sprite (narrow + tall) during roll.
	if _sprite_root != null:
		_sprite_root.scale = Vector2(_facing_x * 0.7, 1.3)


## True if currently in dodge i-frame window (invincible).
func is_dodge_invincible() -> bool:
	return is_dodging and _dodge_timer > (DODGE_DURATION_SEC - DODGE_IFRAMES_SEC)


## True if in parry window (first PARRY_WINDOW_SEC of blocking).
func is_parrying() -> bool:
	return is_blocking and _block_timer <= PARRY_WINDOW_SEC


## Returns the damage multiplier based on current charge level.
## Below threshold → 1.0 (normal). At max → CHARGE_DAMAGE_MULT.
func _get_charge_multiplier() -> float:
	if _charge_timer < CHARGE_THRESHOLD_SEC:
		return 1.0
	var t: float = (_charge_timer - CHARGE_THRESHOLD_SEC) / (CHARGE_MAX_SEC - CHARGE_THRESHOLD_SEC)
	return lerpf(1.0, CHARGE_DAMAGE_MULT, clampf(t, 0.0, 1.0))


## Returns charge progress 0.0–1.0 (for UI/visual feedback).
func get_charge_ratio() -> float:
	if not is_charging or _charge_timer < CHARGE_THRESHOLD_SEC:
		return 0.0
	return clampf((_charge_timer - CHARGE_THRESHOLD_SEC) / (CHARGE_MAX_SEC - CHARGE_THRESHOLD_SEC), 0.0, 1.0)


func _show_charge_visual() -> void:
	if _sprite_root == null:
		return
	var ratio: float = get_charge_ratio()
	# Yellow-white glow intensifies with charge.
	var glow: float = 1.0 + ratio * 1.5
	_sprite_root.modulate = Color(glow, glow, 1.0 + ratio * 0.5, 1.0)


func _hide_charge_visual() -> void:
	if _sprite_root == null:
		return
	_sprite_root.modulate = Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	var map_action: StringName = PlayerActions.action(player_id, PlayerActions.WORLDMAP)
	if event.is_action_pressed(map_action):
		if _world != null and _world.is_in_interior():
			if dungeon_map != null:
				dungeon_map.toggle()
		else:
			if world_map != null:
				world_map.toggle()
		get_viewport().set_input_as_handled()


func _on_fog_reveal_timer_timeout() -> void:
	if _world == null:
		return
	if _world.is_in_interior():
		var interior: InteriorMap = _world._interior
		if interior == null:
			return
		dungeon_fog.reveal(interior.map_id, _cell_of(position), 10)
		if dungeon_map != null and dungeon_map.visible:
			dungeon_map.mark_dirty()
	else:
		if _world._region == null:
			return
		fog_of_war.reveal(_world._region.region_id, _cell_of(position), 10)
		if world_map != null and world_map.visible:
			world_map.mark_dirty()


func _step(delta_pos: Vector2) -> void:
	var map_size: Vector2i = _world.get_map_size()
	var max_x: float = map_size.x * WorldConst.TILE_PX
	var max_y: float = map_size.y * WorldConst.TILE_PX
	# Try X then Y so we can slide along walls.
	var try_x: Vector2 = position + Vector2(delta_pos.x, 0)
	try_x.x = clamp(try_x.x, 0.0, max_x - 0.001)
	if _passable(_cell_of(try_x)):
		position.x = try_x.x
	var try_y: Vector2 = position + Vector2(0, delta_pos.y)
	try_y.y = clamp(try_y.y, 0.0, max_y - 0.001)
	if _passable(_cell_of(try_y)):
		position.y = try_y.y


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / float(WorldConst.TILE_PX))),
		int(floor(p.y / float(WorldConst.TILE_PX))))


# --- Sailing & interact -------------------------------------------

func _passable(cell: Vector2i) -> bool:
	if is_sailing:
		return _world.get_terrain_at(cell) in [&"water", &"deep_water"]
	return _world.is_walkable(cell)


func start_sailing(boat: Boat) -> void:
	is_sailing = true
	_boat = boat


func stop_sailing(_boat: Boat) -> void:
	is_sailing = false
	_boat = null


func start_riding(mount: Mount) -> void:
	is_mounted = true
	_mount = mount


func stop_riding() -> void:
	is_mounted = false
	_mount = null
	# Snap to nearest walkable land if currently on water.
	var my_cell: Vector2i = _cell_of(position)
	if _world.is_walkable(my_cell):
		return
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if max(abs(dx), abs(dy)) != r:
					continue
				var c := my_cell + Vector2i(dx, dy)
				if _world.is_walkable(c):
					position = (Vector2(c) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
					return


func _try_interact() -> void:
	# If a dialogue box is open, E either confirms the highlighted choice
	# (branching mode) or dismisses (leaf / one-liner mode).
	if _world.dialogue_open():
		var box: DialogueBox = _world.get_dialogue_box()
		if box != null and box.has_selected_choice():
			box.confirm_selected_choice()
		else:
			_world.hide_dialogue()
		return
	var best: Node = null
	var best_d2: float = INF
	for n in _world.entities.get_children():
		if n == self or not n.has_method("interact"):
			continue
		var d2: float = position.distance_squared_to((n as Node2D).position)
		if d2 < best_d2 and d2 < _INTERACT_RADIUS_PX * _INTERACT_RADIUS_PX:
			best_d2 = d2
			best = n
	if best != null:
		best.call("interact", self)


# --- Auto-mine / auto-attack ------------------------------------

func _tick_auto_mine() -> void:
	# Find nearest mineable within reach — no facing filter for auto-mine.
	var reach: float = _MELEE_REACH_PX + WorldConst.MINEABLE_HITBOX_RADIUS
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_d2: float = reach * reach + 1.0
	for cell: Vector2i in _world._mineable.keys():
		var tile_center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
		var d2: float = position.distance_squared_to(tile_center)
		if d2 < best_d2:
			best_d2 = d2
			best_cell = cell
	if best_cell == Vector2i(-1, -1):
		return
	# Face the target cell.
	var diff: Vector2 = (Vector2(best_cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX) - position
	if diff.x == 0 and diff.y == 0:
		pass
	else:
		_facing_dir = Vector2i(signi(diff.x), signi(diff.y))
	var damage: int = _compute_mine_damage(best_cell)
	var res: Dictionary = _world.mine_at(best_cell, damage)
	var is_mineable: bool = _world._mineable.has(best_cell) or res.get("hit", false)
	_play_action_vfx(best_cell, is_mineable, res)
	if res.get("destroyed", false):
		for d in res.get("drops", []):
			var cnt: int = d["count"]
			if &"scavenger" in unlocked_passives and randf() < 0.25:
				cnt *= 2
			inventory.add(d["id"], cnt)
	_attack_cooldown = ATTACK_COOLDOWN_SEC


func _tick_auto_attack() -> void:
	var weapon_id: StringName = equipment.get_equipped(ItemDefinition.Slot.WEAPON)
	var def: ItemDefinition = ItemRegistry.get_item(weapon_id) if weapon_id != &"" else null
	if def != null and def.attack_type == ItemDefinition.AttackType.RANGED:
		_auto_attack_ranged(weapon_id, def)
	else:
		_auto_attack_melee(weapon_id, def)


func _auto_attack_melee(weapon_id: StringName, def: ItemDefinition) -> void:
	var reach: float = def.reach if def != null and def.reach > 0 else _MELEE_REACH_PX
	var best: Node2D = null
	var best_d2: float = INF
	for n in _world.entities.get_children():
		if n == self:
			continue
		var is_hostile: bool = false
		if n is NPC and (n as NPC).hostile and (n as NPC).health > 0:
			is_hostile = true
		elif n is Monster and (n as Monster).health > 0:
			is_hostile = true
		if not is_hostile:
			continue
		var eff_reach: float = reach + HitboxCalc.get_radius(n)
		var eff_reach2: float = eff_reach * eff_reach
		var d2: float = position.distance_squared_to((n as Node2D).position)
		if d2 < best_d2 and d2 <= eff_reach2:
			best_d2 = d2
			best = n as Node2D
	if best == null:
		return
	# Face the target.
	var diff: Vector2 = best.position - position
	if diff.x == 0 and diff.y == 0:
		pass
	else:
		_facing_dir = Vector2i(signi(diff.x), signi(diff.y))
	var target_cell: Vector2i = _cell_of(best.position)
	if best.has_method("take_hit"):
		var power: int = max(1, get_effective_stat(&"strength")) if def == null else max(1, def.power + get_effective_stat(&"strength"))
		var elem: int = def.element if def != null else 0
		best.call("take_hit", power, self, elem)
		_try_record_kill(best)
	if def != null and def.knockback > 0:
		_apply_knockback(best, def.knockback)
	_play_action_vfx(target_cell, false, {})
	_attack_cooldown = def.attack_speed if def != null and def.attack_speed > 0 else ATTACK_COOLDOWN_SEC


func _auto_attack_ranged(weapon_id: StringName, def: ItemDefinition) -> void:
	var my_cell: Vector2i = _cell_of(position)
	var target_cell: Vector2i = my_cell + _facing_dir
	# Fire in the facing direction — VFX handles the arrow visual.
	_play_action_vfx(target_cell, false, {})
	# Check if any hostile is roughly in the facing direction within range.
	var reach: float = def.reach if def != null and def.reach > 0 else _RANGED_REACH_PX
	var dir := Vector2(_facing_dir).normalized()
	for n in _world.entities.get_children():
		if n == self:
			continue
		var is_hostile: bool = false
		if n is NPC and (n as NPC).hostile and (n as NPC).health > 0:
			is_hostile = true
		elif n is Monster and (n as Monster).health > 0:
			is_hostile = true
		if not is_hostile:
			continue
		var to: Vector2 = (n as Node2D).position - position
		var eff_reach: float = reach + HitboxCalc.get_radius(n)
		if to.length_squared() > eff_reach * eff_reach:
			continue
		# Check alignment with facing direction (dot > 0.7 ≈ within ~45°).
		if to.normalized().dot(dir) < 0.7:
			continue
		if n.has_method("take_hit"):
			var power: int = 1
			if def != null:
				power = max(1, def.power + get_effective_stat(&"strength"))
			var elem: int = def.element if def != null else 0
			n.call("take_hit", power, self, elem)
			_try_record_kill(n)
		if def != null and def.knockback > 0:
			_apply_knockback(n as Node2D, def.knockback)
		break  # One target per shot.
	_attack_cooldown = def.attack_speed if def != null and def.attack_speed > 0 else ATTACK_COOLDOWN_SEC


# --- Damage received -----------------------------------------------

## Apply incoming damage reduced by equipped armor defense.
## Formula: effective = max(1, raw_damage - armor_defense).
## If element != NONE, applies the corresponding status effect.
func take_hit(damage: int, _attacker: Node = null, element: int = 0) -> void:
	if is_dead:
		return
	if health <= 0:
		return
	if _invincible_timer > 0.0:
		return
	# Invincible while in a conversation.
	if in_conversation:
		return
	# Dodge i-frames: fully invincible.
	if is_dodge_invincible():
		return
	# Parry: perfect block in first 0.15s — negate all damage + stagger attacker.
	if is_parrying():
		ActionParticles.flash_hit(self)  # visual feedback (parry flash)
		if _attacker != null and _attacker.has_method("stagger"):
			_attacker.stagger()
		return
	var defense: int = _armor_defense()
	var effective: int = max(1, damage - defense)
	if &"iron_skin" in unlocked_passives:
		effective = max(1, effective - 1)
	# Block: reduce damage by 75%.
	if is_blocking:
		effective = max(1, int(effective * BLOCK_DAMAGE_MULT))
	# Getting hit interrupts charge.
	if is_charging:
		is_charging = false
		_charge_timer = 0.0
		_hide_charge_visual()
	health = max(0, health - effective)
	ActionParticles.flash_hit(self)
	if _damage_heart_vfx != null:
		_damage_heart_vfx.show_damage(effective)
	if element != 0:
		apply_status_from_element(element)
	if health <= 0:
		player_died.emit(player_id)


## Restore health, clamped to max_health.
func heal(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = min(health + amount, max_health)


## Called when health reaches 0. Enters dead state and tweens sprite to lying-down.
## Does NOT emit player_died — that is emitted from take_hit() as before.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	health = 0
	InputContext.set_context(player_id, InputContext.Context.DISABLED)
	_bob_t = 0.0
	if _sprite_root != null:
		_sprite_root.position = Vector2.ZERO
		# Tween sprite root to 90 degrees (lying on side).
		var tw := create_tween()
		tw.tween_property(_sprite_root, "rotation_degrees", 90.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Restore player from dead state with [param new_health] HP and start invincibility.
func respawn(new_health: int) -> void:
	if not is_dead:
		return
	is_dead = false
	health = mini(new_health, max_health)
	_invincible_timer = _INVINCIBLE_DURATION
	if _sprite_root != null:
		_sprite_root.visible = true
	InputContext.set_context(player_id, InputContext.Context.GAMEPLAY)
	# Tween sprite root back upright.
	if _sprite_root != null:
		var tw := create_tween()
		tw.tween_property(_sprite_root, "rotation_degrees", 0.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING)


## Sum defensive power from HEAD + BODY + FEET + OFF_HAND equipment slots,
## plus the effective defense stat.
func _armor_defense() -> int:
	return (equipment.total_power(ItemDefinition.Slot.HEAD)
		+ equipment.total_power(ItemDefinition.Slot.BODY)
		+ equipment.total_power(ItemDefinition.Slot.FEET)
		+ equipment.total_power(ItemDefinition.Slot.OFF_HAND)
		+ get_effective_stat(&"defense"))


## Push a target away from the player.
func _apply_knockback(target: Node2D, amount: float) -> void:
	if amount <= 0 or target == null:
		return
	var dir: Vector2 = (target.position - position).normalized()
	target.position += dir * amount


# --- Attack / mining ---------------------------------------------

## Returns the mining damage for a given target cell, factoring in
## the equipped tool (pickaxe doubles damage vs rock/ore kinds).
func _compute_mine_damage(target_cell: Vector2i) -> int:
	var tool_id: StringName = equipment.get_equipped(ItemDefinition.Slot.TOOL)
	if tool_id == &"":
		return 1
	var tdef: ItemDefinition = ItemRegistry.get_item(tool_id)
	if tdef == null or tdef.power <= 0:
		return 1
	# Tools apply their power against appropriate resource kinds.
	var entry: Variant = _world._mineable.get(target_cell, null)
	if entry != null and WorldRoot.PICKAXE_BONUS_KINDS.has(entry["kind"]):
		return tdef.power
	return 1


## Records a kill in the TravelLog if [param entity] is now dead.
func _try_record_kill(entity: Node) -> void:
	var h: Variant = entity.get("health")
	if h == null or int(h) > 0:
		return
	# Grant XP for the kill. Monster uses "monster_kind", NPC uses "kind".
	var kind_v: Variant = entity.get("monster_kind")
	if kind_v == null or StringName(kind_v) == &"":
		kind_v = entity.get("kind")
	if kind_v != null and StringName(kind_v) != &"":
		var xp_override: Variant = entity.get("xp_reward_override")
		if xp_override != null and int(xp_override) >= 0:
			gain_xp(int(xp_override))
		else:
			gain_xp(CreatureSpriteRegistry.get_xp_reward(StringName(kind_v)))
	# Record kill in caravan travel log.
	if caravan_data != null and caravan_data.travel_logs.size() > player_id:
		caravan_data.travel_logs[player_id].record_kill()


func try_attack(charge_mult: float = 1.0) -> Dictionary:
	var res: Dictionary = {}

	# --- Entity hit scan first (melee / punch) ---
	var hit_entity: Node2D = _find_facing_hostile()
	if hit_entity != null and hit_entity.has_method("take_hit"):
		var weapon_id: StringName = equipment.get_equipped(ItemDefinition.Slot.WEAPON)
		var wdef: ItemDefinition = ItemRegistry.get_item(weapon_id) if weapon_id != &"" else null
		var power: int = max(1, get_effective_stat(&"strength")) if wdef == null else max(1, wdef.power + get_effective_stat(&"strength"))
		power = int(power * charge_mult)
		var elem: int = wdef.element if wdef != null else 0
		hit_entity.call("take_hit", power, self, elem)
		_try_record_kill(hit_entity)
		if wdef != null and wdef.knockback > 0:
			_apply_knockback(hit_entity, wdef.knockback)
		res["hit_entity"] = true
		var dummy_target: Vector2i = _cell_of(hit_entity.position)
		_play_action_vfx(dummy_target, false, res)
		return res

	# --- No hostile in range — find nearest mineable in facing cone ---
	var target: Vector2i = _find_facing_mineable()
	var damage: int = int(_compute_mine_damage(target) * charge_mult)
	res = _world.mine_at(target, damage)

	var is_mineable: bool = _world._mineable.has(target) or res.get("hit", false)
	_play_action_vfx(target, is_mineable, res)

	if not res.get("hit", false):
		return res
	if res.get("destroyed", false):
		for d in res.get("drops", []):
			var cnt: int = d["count"]
			if &"scavenger" in unlocked_passives and randf() < 0.25:
				cnt *= 2
			inventory.add(d["id"], cnt)
	return res


## Find the nearest mineable tile whose centre falls within melee reach and
## inside a ~60° cone in the facing direction (dot > 0.5).
## Falls back to [code]my_cell + _facing_dir[/code] when nothing is in range
## so the player still swings in a sensible direction on empty ground.
func _find_facing_mineable() -> Vector2i:
	if _world == null:
		return _cell_of(position) + _facing_dir
	var dir := Vector2(_facing_dir).normalized()
	var reach: float = _MELEE_REACH_PX + WorldConst.MINEABLE_HITBOX_RADIUS
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_d2: float = reach * reach + 1.0
	for cell: Vector2i in _world._mineable.keys():
		var tile_center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
		var to: Vector2 = tile_center - position
		if to.length_squared() > best_d2:
			continue
		# Facing cone: dot > 0.5 means within ~60° of facing direction.
		if to.normalized().dot(dir) < 0.5:
			continue
		best_d2 = to.length_squared()
		best_cell = cell
	if best_cell == Vector2i(-1, -1):
		return _cell_of(position) + _facing_dir
	return best_cell


## Find the nearest hostile entity in the facing direction within melee reach.
func _find_facing_hostile() -> Node2D:
	var weapon_id: StringName = equipment.get_equipped(ItemDefinition.Slot.WEAPON)
	var wdef: ItemDefinition = ItemRegistry.get_item(weapon_id) if weapon_id != &"" else null
	var reach: float = wdef.reach if wdef != null and wdef.reach > 0 else _MELEE_REACH_PX
	var dir := Vector2(_facing_dir).normalized()
	var best: Node2D = null
	var best_d2: float = INF
	for n in _world.entities.get_children():
		if n == self:
			continue
		var is_hostile: bool = false
		if n is NPC and (n as NPC).hostile and (n as NPC).health > 0:
			is_hostile = true
		elif n is Monster and (n as Monster).health > 0:
			is_hostile = true
		if not is_hostile:
			continue
		var to: Vector2 = (n as Node2D).position - position
		var eff_reach: float = reach + HitboxCalc.get_radius(n)
		if to.length_squared() > eff_reach * eff_reach:
			continue
		# Must be roughly in the facing direction (dot > 0.3 ≈ ~73° cone).
		if to.length_squared() > 0.01 and to.normalized().dot(dir) < 0.3:
			continue
		var d2: float = to.length_squared()
		if d2 < best_d2:
			best_d2 = d2
			best = n as Node2D
	return best


func _play_action_vfx(target: Vector2i, is_mineable: bool, res: Dictionary) -> void:
	if _action_vfx == null:
		return

	var kind: StringName = res.get("kind", &"")

	if is_mineable:
		var tool_id: StringName = equipment.get_equipped(ItemDefinition.Slot.TOOL)
		var facing := Vector2(_facing_dir)
		if tool_id != &"":
			_action_vfx.play_mine_swing(target, kind, facing, tool_id)
		else:
			_action_vfx.play_gather(target, facing)
	else:
		var weapon_id: StringName = equipment.get_equipped(ItemDefinition.Slot.WEAPON)
		if weapon_id != &"":
			var wdef: ItemDefinition = ItemRegistry.get_item(weapon_id)
			if wdef != null:
				var spd: float = wdef.attack_speed if wdef.attack_speed > 0 else ATTACK_COOLDOWN_SEC
				var facing := Vector2(_facing_dir)
				_action_vfx.play_attack(target, wdef.weapon_category, wdef.element, spd, facing, weapon_id)
			else:
				_action_vfx.play_melee_swing(target, Vector2(_facing_dir), weapon_id)
		else:
			# Bare-hands punch — body lunge toward target.
			_action_vfx.play_unarmed_lunge(target, Vector2(_facing_dir))


# --- Status effects -------------------------------------------------

## Apply a status effect by element. Resets duration if already active.
func apply_status_from_element(element: int) -> void:
	var eff: StatusEffect = StatusEffectRegistry.get_effect_for_element(element)
	if eff == null:
		return
	apply_status(eff.id)


## Apply a status effect by id. Resets duration if already active (no stacking).
func apply_status(effect_id: StringName) -> void:
	var eff: StatusEffect = StatusEffectRegistry.get_effect(effect_id)
	if eff == null:
		return
	for entry: Dictionary in active_effects:
		if entry["effect_id"] == effect_id:
			entry["remaining"] = eff.duration_sec
			entry["tick_timer"] = 0.0
			return
	active_effects.append({
		"effect_id": effect_id,
		"remaining": eff.duration_sec,
		"tick_timer": 0.0,
	})


## Remove a status effect by id.
func remove_status(effect_id: StringName) -> void:
	for i in range(active_effects.size() - 1, -1, -1):
		if active_effects[i]["effect_id"] == effect_id:
			active_effects.remove_at(i)
			return


## Clear all active effects.
func clear_effects() -> void:
	active_effects.clear()


## Tick all active effects. Call from _physics_process.
func tick_effects(delta: float) -> void:
	if health <= 0:
		return
	var i: int = active_effects.size() - 1
	while i >= 0:
		var entry: Dictionary = active_effects[i]
		var eff: StatusEffect = StatusEffectRegistry.get_effect(entry["effect_id"])
		if eff == null:
			active_effects.remove_at(i)
			i -= 1
			continue
		entry["remaining"] -= delta
		if entry["remaining"] <= 0.0:
			active_effects.remove_at(i)
			i -= 1
			continue
		# Tick damage
		if eff.damage_per_tick > 0 and eff.tick_interval > 0.0:
			entry["tick_timer"] += delta
			if entry["tick_timer"] >= eff.tick_interval:
				entry["tick_timer"] -= eff.tick_interval
				health = max(0, health - eff.damage_per_tick)
				if health <= 0:
					clear_effects()
					die()
					player_died.emit(player_id)
					return
		i -= 1


## Returns true if any active effect has stun == true.
func is_stunned() -> bool:
	for entry: Dictionary in active_effects:
		var eff: StatusEffect = StatusEffectRegistry.get_effect(entry["effect_id"])
		if eff != null and eff.stun:
			return true
	return false


## Combined speed multiplier from all active effects.
func get_status_speed_multiplier() -> float:
	var mult: float = 1.0
	for entry: Dictionary in active_effects:
		var eff: StatusEffect = StatusEffectRegistry.get_effect(entry["effect_id"])
		if eff != null:
			mult *= eff.speed_multiplier
	return mult


## Check if a specific effect is active.
func has_status(effect_id: StringName) -> bool:
	for entry: Dictionary in active_effects:
		if entry["effect_id"] == effect_id:
			return true
	return false
