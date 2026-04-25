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
var hitbox_radius: float = 5.0  ## Gungeon-style body-core radius (native px).
var _heart_display: HeartDisplay = null
var _action_vfx: ActionVFX = null


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
	# Hitbox radius: explicit JSON override → auto-calc from sprite → default.
	var explicit_hb: float = CreatureSpriteRegistry.get_hitbox_radius(monster_kind)
	if explicit_hb >= 0.0:
		hitbox_radius = explicit_hb
	else:
		hitbox_radius = HitboxCalc.radius_from_sprite(_sprite)
	# Overhead heart display — visible only when damaged.
	_heart_display = HeartDisplay.new(6.0)
	_heart_display.position = Vector2(-10, -14)
	_heart_display.visible = false
	add_child(_heart_display)
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
		_heart_display.visible = health > 0 and health < max_health
	_tick_effects(delta)
	if health <= 0:
		return
	# Freeze while in a conversation.
	if in_conversation:
		return
	if _is_stunned():
		return
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	var target: PlayerController = nearest_player(position,
			_world.entities.get_children(), SIGHT_RADIUS_TILES)
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
	_attack_cooldown = _attack_speed
	if target.has_method("take_hit"):
		target.call("take_hit", _attack_damage, self, _attack_element)
	# Lunge + particle VFX.
	if _action_vfx != null:
		var to_norm: Vector2 = to_target.normalized() if to_target.length() > 0.01 else Vector2(1, 0)
		var target_cell := Vector2i(
				int(floor(target.position.x / float(WorldConst.TILE_PX))),
				int(floor(target.position.y / float(WorldConst.TILE_PX))))
		_action_vfx.play_creature_attack(target_cell, to_norm, _attack_style, _attack_element)


func take_hit(damage: int, _attacker: Node = null, element: int = 0) -> void:
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
		i -= 1


func _is_stunned() -> bool:
	for entry: Dictionary in active_effects:
		var eff: StatusEffect = StatusEffectRegistry.get_effect(entry["effect_id"])
		if eff != null and eff.stun:
			return true
	return false


func _get_speed_multiplier() -> float:
	var mult: float = 1.0
	for entry: Dictionary in active_effects:
		var eff: StatusEffect = StatusEffectRegistry.get_effect(entry["effect_id"])
		if eff != null:
			mult *= eff.speed_multiplier
	return mult
