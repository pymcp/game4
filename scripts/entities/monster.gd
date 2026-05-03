## Monster
##
## Hostile creature. Chases the nearest [PlayerController] within
## [SIGHT_RADIUS_TILES] and attacks when within range. Combat stats
## (damage, speed, range, style) are read from
## [code]creature_sprites.json[/code] via [CreatureSpriteRegistry].
##
## Coordinate system mirrors [PlayerController]: positions are native
## pixels, [WorldConst.TILE_PX] per tile. Pathing is naive — step
## directly toward the target and skip the move when the next cell is
## not [WorldRoot.is_walkable].
extends Node2D
class_name Monster

signal died(world_position: Vector2, drops: Array)

const SIGHT_RADIUS_TILES: float = 8.0
const _MOVE_SPEED_PX_PER_S: float = 32.0  ## native pixels (pre-zoom)
const _BOB_HZ: float = 4.0
const _BOB_AMP_PX: float = 1.0

@export var max_health: int = 3
@export var health: int = 3
@export var drops: Array = []  ## [{id: StringName, count: int}]
@export var resistances: Dictionary = {}  ## Element enum → float multiplier (0.0=immune, 2.0=weak)
@export var monster_kind: StringName = &"slime"  ## Creature type key
var tier: int = 0  ## MonsterTier.Tier — set by _spawn_monster before _ready()
var xp_reward_override: int = -1  ## If >= 0, used instead of registry value.

var in_conversation: bool = false  ## Set by WorldRoot during dialogue.
var active_effects: Array = []  ## [{effect_id, remaining, tick_timer}]
var _world: WorldRoot = null
var _sprite: Sprite2D = null
var _facing_right: bool = false
var _bob_t: float = 0.0
var _last_position: Vector2 = Vector2.ZERO

# --- Combat stats (loaded from creature data in _ready) ---
var _attack_damage: int = 1
var _attack_speed: float = 1.0
var _attack_range_tiles: float = 1.25
var _attack_style: StringName = &"slam"
var _attack_element: int = 0
var _attack_cooldown: float = 0.0
var _stagger_timer: float = 0.0
const STAGGER_DURATION: float = 0.6
var _telegraph_timer: float = 0.0
var _telegraph_duration: float = 0.5
var _telegraph_target: PlayerController = null
var _telegraph_indicator: Sprite2D = null
var hitbox_radius: float = 5.0  ## Gungeon-style body-core radius (native px).
var _heart_display: HeartDisplay = null
var _action_vfx: ActionVFX = null
var _tier_name_label: Label = null
## LOD / performance.
var _lod_sleeping: bool = false
var _lod_index: int = 0
## Target scan throttle — re-evaluate nearest player every interval.
const TARGET_SCAN_INTERVAL: float = 0.25
var _target_scan_timer: float = 0.0
var _cached_target: PlayerController = null
## Cached status-effect state computed in _tick_effects to avoid triple-iteration.
var _cached_stunned: bool = false
var _cached_speed_mult: float = 1.0


func _ready() -> void:
	_world = WorldRoot.find_from(self)
	_sprite = CreatureSpriteRegistry.build_sprite(monster_kind)
	if _sprite == null:
		# Fallback: coloured square so the monster is still visible.
		_sprite = Sprite2D.new()
		_sprite.centered = true
	_facing_right = CreatureSpriteRegistry.is_facing_right(monster_kind)
	add_child(_sprite)
	add_to_group(&"monsters")
	add_to_group(&"scattered_npcs")
	_last_position = position
	# Load combat stats from creature data.
	_attack_damage = CreatureSpriteRegistry.get_attack_damage(monster_kind)
	_attack_speed = CreatureSpriteRegistry.get_attack_speed(monster_kind)
	_attack_range_tiles = CreatureSpriteRegistry.get_attack_range_tiles(monster_kind)
	_attack_style = CreatureSpriteRegistry.get_attack_style(monster_kind)
	_attack_element = CreatureSpriteRegistry.get_element(monster_kind)
	_telegraph_duration = CreatureSpriteRegistry.get_telegraph_duration(monster_kind)
	# Apply tier multipliers to combat stats.
	if tier > 0:
		_attack_damage = int(ceil(_attack_damage * MonsterTier.DMG_MULT[tier]))
		if _sprite != null:
			_sprite.scale *= MonsterTier.SCALE_MULT[tier]
			_sprite.modulate = MonsterTier.apply_color(_sprite.modulate, tier)
	# Hitbox radius: explicit JSON override → auto-calc from sprite → default.
	var explicit_hb: float = CreatureSpriteRegistry.get_hitbox_radius(monster_kind)
	if explicit_hb >= 0.0:
		hitbox_radius = explicit_hb
	else:
		hitbox_radius = HitboxCalc.radius_from_sprite(_sprite)
	# Overhead heart display — visible only when damaged.
	# Position above the sprite's visual top edge (accounts for hires multi-tile sprites).
	var heart_y: float = -14.0
	if _sprite != null:
		if _sprite.centered:
			var tex_h: float = float(_sprite.texture.get_height()) if _sprite.texture != null else 16.0
			heart_y = -(tex_h * 0.5 * abs(_sprite.scale.y)) - 2.0
		else:
			heart_y = _sprite.offset.y * abs(_sprite.scale.y) - 2.0
	_heart_display = HeartDisplay.new(6.0)
	_heart_display.position = Vector2(-10, heart_y)
	_heart_display.visible = false
	add_child(_heart_display)
	# Tier name label — only for tier 1+ monsters.
	if tier > 0:
		_setup_tier_label(heart_y)
	# Tier aura particles — only for tier 3+ (Veteran/Elite).
	if tier >= MonsterTier.Tier.VETERAN:
		_setup_tier_aura()
	# Attack VFX — lunges the sprite toward the target.
	_action_vfx = ActionVFX.new()
	add_child(_action_vfx)
	_action_vfx.setup(self, null, _world, _sprite)


## Pure helper: nearest [PlayerController] to [param from] within
## [param max_tiles] among [param candidates]. Returns the player or
## [code]null[/code] when none qualify. Static so AI logic is testable
## without instantiating a scene.
static func nearest_player(from: Vector2, candidates: Array,
		max_tiles: float) -> PlayerController:
	var best: PlayerController = null
	var best_d2: float = INF
	var max_px: float = max_tiles * float(WorldConst.TILE_PX)
	var max_d2: float = max_px * max_px
	for n in candidates:
		var p := n as PlayerController
		if p == null:
			continue
		# Skip dead or disabled players.
		if p.health <= 0 or not p.visible:
			continue
		var d2: float = from.distance_squared_to(p.position)
		if d2 < best_d2 and d2 <= max_d2:
			best_d2 = d2
			best = p
	return best


func _process(delta: float) -> void:
	if _world == null:
		return
	# Update overhead hearts.
	if _heart_display != null:
		_heart_display.update(health, max_health)
		var show_overhead: bool = health > 0 and health < max_health
		_heart_display.visible = show_overhead
		if _tier_name_label != null:
			_tier_name_label.visible = show_overhead
	_tick_effects(delta)
	if health <= 0:
		return
	# Freeze while in a conversation.
	if in_conversation:
		return
	if _is_stunned():
		return
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		return
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	# Throttle target scan: re-evaluate every TARGET_SCAN_INTERVAL seconds.
	_target_scan_timer -= delta
	if _target_scan_timer <= 0.0 or \
			(_cached_target != null and not is_instance_valid(_cached_target)):
		_cached_target = nearest_player(position,
				_world.get_player_cache(), SIGHT_RADIUS_TILES)
		_target_scan_timer = TARGET_SCAN_INTERVAL
	var target: PlayerController = _cached_target
	if target == null:
		return
	var to: Vector2 = target.position - position
	var dist: float = to.length()
	var attack_range_px: float = _attack_range_tiles * float(WorldConst.TILE_PX) + target.hitbox_radius
	# Attack if in range.
	if dist <= attack_range_px and _attack_style != &"none":
		_tick_attack(target, to)
		return
	if dist <= 1.0:
		return
	var step: float = _MOVE_SPEED_PX_PER_S * _get_speed_multiplier() * delta
	if step > dist:
		step = dist
	var next_pos: Vector2 = position + to / dist * step
	var next_cell := Vector2i(
			int(floor(next_pos.x / float(WorldConst.TILE_PX))),
			int(floor(next_pos.y / float(WorldConst.TILE_PX))))
	if _world.is_walkable(next_cell):
		position = next_pos
	# Flip sprite based on movement direction.
	if to.x != 0.0:
		if _facing_right:
			_sprite.flip_h = (to.x < 0.0)
		else:
			_sprite.flip_h = (to.x > 0.0)
	# Bob while moving.
	var moved: bool = position.distance_squared_to(_last_position) > 0.01
	_last_position = position
	if _action_vfx != null and _action_vfx.is_playing():
		pass  # Skip bob during lunge.
	elif moved:
		_bob_t += delta
		_sprite.position.y = -sin(_bob_t * TAU * _BOB_HZ) * _BOB_AMP_PX
	else:
		_bob_t = 0.0
		_sprite.position.y = 0.0


func _tick_attack(target: PlayerController, to_target: Vector2) -> void:
	# Face the target.
	if to_target.x != 0.0:
		if _facing_right:
			_sprite.flip_h = (to_target.x < 0.0)
		else:
			_sprite.flip_h = (to_target.x > 0.0)
	if _attack_cooldown > 0.0:
		return
	# Telegraph phase: show windup indicator before dealing damage.
	if _telegraph_timer > 0.0:
		_telegraph_timer -= get_process_delta_time()
		if _telegraph_timer <= 0.0:
			_finish_attack(target, to_target)
		return
	# Start a new telegraph.
	_telegraph_timer = _telegraph_duration
	_telegraph_target = target
	_show_telegraph(to_target)


## Called when the telegraph timer expires — deliver the actual hit.
func _finish_attack(target: PlayerController, to_target: Vector2) -> void:
	_hide_telegraph()
	_attack_cooldown = _attack_speed
	_telegraph_target = null
	if not is_instance_valid(target):
		return
	if target.has_method("take_hit"):
		target.call("take_hit", _attack_damage, self, _attack_element)
	# Lunge + particle VFX.
	if _action_vfx != null:
		var to_norm: Vector2 = to_target.normalized() if to_target.length() > 0.01 else Vector2(1, 0)
		var target_cell := Vector2i(
				int(floor(target.position.x / float(WorldConst.TILE_PX))),
				int(floor(target.position.y / float(WorldConst.TILE_PX))))
		_action_vfx.play_creature_attack(target_cell, to_norm, _attack_style, _attack_element)


## Show a red flash/pulse on the sprite to telegraph an incoming attack.
func _show_telegraph(_to_target: Vector2) -> void:
	if _sprite != null:
		_sprite.modulate = Color(1.5, 0.5, 0.5, 1.0)


## Clear the telegraph visual.
func _hide_telegraph() -> void:
	if _sprite != null:
		_sprite.modulate = Color.WHITE


func take_hit(damage: int, _attacker: Node = null, element: int = 0) -> void:
	# Wake from LOD sleep so the enemy can respond.
	if _lod_sleeping:
		_lod_sleeping = false
		set_process(true)
	# Invincible while in a conversation.
	if in_conversation:
		return
	var effective: int = _apply_resistance(damage, element)
	health = max(0, health - effective)
	ActionParticles.flash_hit(self)
	if element != 0:
		_apply_status_from_element(element)
	if health <= 0:
		_die()


func _apply_resistance(damage: int, element: int) -> int:
	if element == 0 or not resistances.has(element):
		return max(1, damage)
	var mult: float = float(resistances[element])
	return max(1, ceili(damage * mult))


func _die() -> void:
	set_process(false)
	var loot: Array = drops.duplicate()
	# Roll drops from loot table if no explicit drops were set.
	if loot.is_empty():
		loot = LootTableRegistry.roll_drops(monster_kind)
	died.emit(position, loot)
	queue_free()


# --- Status effects -------------------------------------------------

func _apply_status_from_element(element: int) -> void:
	var eff: StatusEffect = StatusEffectRegistry.get_effect_for_element(element)
	if eff == null:
		return
	for entry: Dictionary in active_effects:
		if entry["effect_id"] == eff.id:
			entry["remaining"] = eff.duration_sec
			entry["tick_timer"] = 0.0
			return
	active_effects.append({
		"effect_id": eff.id,
		"remaining": eff.duration_sec,
		"tick_timer": 0.0,
	})


func _tick_effects(delta: float) -> void:
	_cached_stunned = false
	_cached_speed_mult = 1.0
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
		if eff.damage_per_tick > 0 and eff.tick_interval > 0.0:
			entry["tick_timer"] += delta
			if entry["tick_timer"] >= eff.tick_interval:
				entry["tick_timer"] -= eff.tick_interval
				health = max(0, health - eff.damage_per_tick)
				if health <= 0:
					_die()
					return
		# Accumulate stun and speed in the same pass.
		if eff.stun:
			_cached_stunned = true
		_cached_speed_mult *= eff.speed_multiplier
		i -= 1


func _is_stunned() -> bool:
	return _cached_stunned


## Called by player parry — freezes the monster for STAGGER_DURATION seconds.
func stagger() -> void:
	_stagger_timer = STAGGER_DURATION
	ActionParticles.flash_hit(self)


func _get_speed_multiplier() -> float:
	return _cached_speed_mult


## Set up overhead tier name label for tier 1+ monsters.
func _setup_tier_label(heart_y: float) -> void:
	var base_name: String = CreatureSpriteRegistry.get_display_name(monster_kind)
	var label_text: String = MonsterTier.display_name(base_name, tier)
	_tier_name_label = Label.new()
	_tier_name_label.text = label_text
	_tier_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_name_label.add_theme_font_size_override("font_size", 8)
	_tier_name_label.add_theme_color_override("font_color",
		MonsterTier.apply_color(Color.WHITE, tier))
	_tier_name_label.position = Vector2(-20, heart_y - 10)
	_tier_name_label.custom_minimum_size = Vector2(40, 0)
	_tier_name_label.visible = false
	add_child(_tier_name_label)


## Set up radial aura particles for tier 3+ (Veteran/Elite).
func _setup_tier_aura() -> void:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	var aura_color: Color = MonsterTier.apply_color(
		CreatureSpriteRegistry.get_tint(monster_kind), tier)
	aura_color.a = 0.5 if tier >= MonsterTier.Tier.ELITE else 0.3
	mat.color = aura_color
	particles.process_material = mat
	particles.amount = 6
	particles.lifetime = 1.0 if tier >= MonsterTier.Tier.ELITE else 1.5
	particles.emitting = true
	# Additive blend for glow effect.
	particles.material = CanvasItemMaterial.new()
	(particles.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_child(particles)
