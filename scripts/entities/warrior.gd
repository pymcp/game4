## Warrior
##
## Companion fighter that follows the player into dungeons and labyrinths.
## On the overworld, the warrior stands near the caravan.
##
## Behavior:
##   OVERWORLD (_is_in_dungeon == false):
##     Follow caravan position, idle when close.
##   DUNGEON/LABYRINTH (_is_in_dungeon == true):
##     Follow player, attack hostiles on sight, auto-collect nearby loot.
##
## world.gd spawns/manages one Warrior per player. The Warrior is NOT added
## to the "scattered_npcs" group — it persists across view transitions.
class_name Warrior
extends Node2D

signal warrior_died(world_position: Vector2)

const _MOVE_SPEED_PX_S: float = 90.0
const _ARRIVE_DIST_PX: float = 10.0
const _TELEPORT_TILES: float = 20.0
const _ATTACK_COOLDOWN_SEC: float = 0.8
const _ATTACK_DAMAGE: int = 5
const _LOOT_RADIUS_PX: float = 24.0
const _ENEMY_SCAN_INTERVAL: float = 0.3

## Set by world.gd.
@export var owner_player: PlayerController = null
## Reference to the player's caravan (for overworld follow target).
@export var caravan: Caravan = null
## True when inside a dungeon/labyrinth (follow player + attack mode).
@export var is_in_dungeon: bool = false

var health: int = 20
var max_health: int = 20

var _world: WorldRoot = null
var _state: WarriorState.State = WarriorState.State.IDLE
var _attack_cooldown: float = 0.0
var _enemy_scan_timer: float = 0.0
var _cached_enemy: Node2D = null
var _cached_enemy_dist_tiles: float = INF
var _facing_dir: Vector2 = Vector2(1, 0)
var _sprite: Node2D = null  ## CharacterBuilder output
var _action_vfx: ActionVFX = null
var _bob_t: float = 0.0
const _BOB_HZ: float = 4.0
const _BOB_AMP_PX: float = 1.0


func _ready() -> void:
	_world = WorldRoot.find_from(self)
	_build_sprite()
	_action_vfx = ActionVFX.new()
	add_child(_action_vfx)
	_action_vfx.setup(self, null, _world, _sprite)


func _process(delta: float) -> void:
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_bob_t += delta

	# Throttle hostile scan.
	_enemy_scan_timer -= delta
	if _enemy_scan_timer <= 0.0:
		_enemy_scan_timer = _ENEMY_SCAN_INTERVAL
		_scan_enemies()

	var dist_target_tiles: float = _dist_to_follow_target_tiles()
	var dist_enemy_tiles: float = _cached_enemy_dist_tiles

	_state = WarriorState.decide_state(_state, health,
			dist_target_tiles, dist_enemy_tiles)

	match _state:
		WarriorState.State.DEAD:
			_on_die()
		WarriorState.State.ATTACK:
			_tick_attack(delta)
		WarriorState.State.FOLLOW:
			_tick_follow(delta)
		WarriorState.State.IDLE:
			_tick_idle()

	# Bob guard: skip bob if VFX lunge is playing.
	if _sprite != null and not _action_vfx.is_playing():
		_sprite.position.y = sin(_bob_t * _BOB_HZ * TAU) * _BOB_AMP_PX

	# Auto-collect loot only in dungeon mode.
	if is_in_dungeon:
		_tick_loot_collect()


func _tick_follow(delta: float) -> void:
	var target_pos: Vector2 = _follow_target_position()
	_step_toward(target_pos, delta)
	_update_facing(target_pos)


func _tick_idle() -> void:
	pass  # Idle — just bob animation


func _tick_attack(delta: float) -> void:
	if _cached_enemy == null or not is_instance_valid(_cached_enemy):
		_cached_enemy = null
		_cached_enemy_dist_tiles = INF
		return
	var enemy_pos: Vector2 = _cached_enemy.position
	var dist_px: float = position.distance_to(enemy_pos)
	var attack_range_px: float = WarriorState.ATTACK_RANGE_TILES * float(WorldConst.TILE_PX)
	_update_facing(enemy_pos)
	# Move in if not in melee range.
	if dist_px > attack_range_px:
		_step_toward(enemy_pos, delta)
	elif _attack_cooldown <= 0.0:
		_do_attack()


func _do_attack() -> void:
	if _cached_enemy == null or not is_instance_valid(_cached_enemy):
		return
	_attack_cooldown = _ATTACK_COOLDOWN_SEC
	var target_cell: Vector2i = _pos_to_cell(_cached_enemy.position)
	_action_vfx.play_creature_attack(target_cell, _facing_dir, &"swing", 0)
	# Apply damage.
	if _cached_enemy.has_method("take_hit"):
		_cached_enemy.call("take_hit", _ATTACK_DAMAGE, self)


func _tick_loot_collect() -> void:
	if _world == null:
		return
	var pickup_radius_sq: float = _LOOT_RADIUS_PX * _LOOT_RADIUS_PX
	for child in _world.entities.get_children():
		if child is LootPickup:
			var lp := child as LootPickup
			if not lp._consumed and position.distance_squared_to(lp.position) <= pickup_radius_sq:
				if owner_player != null and is_instance_valid(owner_player):
					owner_player.inventory.add(lp.item_id, lp.count)
					lp._consumed = true
					lp.queue_free()


func take_hit(damage: int, _attacker: Node = null) -> void:
	health -= max(1, damage)
	if _sprite != null:
		ActionParticles.flash_hit(_sprite)
	if health <= 0:
		health = 0


func _on_die() -> void:
	warrior_died.emit(position)
	queue_free()


# ─── Movement helpers ───────────────────────────────────────────────

func _follow_target_position() -> Vector2:
	if is_in_dungeon:
		if owner_player != null and is_instance_valid(owner_player):
			return owner_player.position
	else:
		if caravan != null and is_instance_valid(caravan):
			return caravan.position + Vector2(float(WorldConst.TILE_PX), 0.0)
	return position


func _dist_to_follow_target_tiles() -> float:
	var target: Vector2 = _follow_target_position()
	return position.distance_to(target) / float(WorldConst.TILE_PX)


func _step_toward(target_pos: Vector2, delta: float) -> void:
	var to_target: Vector2 = target_pos - position
	if to_target.length() <= _ARRIVE_DIST_PX:
		return
	var step: Vector2 = to_target.normalized() * _MOVE_SPEED_PX_S * delta
	var new_pos: Vector2 = position + step
	if _world != null:
		var cell: Vector2i = Vector2i(
				int(floor(new_pos.x / float(WorldConst.TILE_PX))),
				int(floor(new_pos.y / float(WorldConst.TILE_PX))))
		if not _world.is_walkable(cell):
			return
	position = new_pos


func _update_facing(toward: Vector2) -> void:
	var dir: Vector2 = (toward - position)
	if dir.length_squared() > 0.01:
		_facing_dir = dir.normalized()
		if _sprite != null:
			_sprite.scale.x = -1.0 if _facing_dir.x < 0.0 else 1.0


static func _pos_to_cell(pos: Vector2) -> Vector2i:
	var t: int = WorldConst.TILE_PX
	return Vector2i(int(floor(pos.x / float(t))), int(floor(pos.y / float(t))))


# ─── Enemy scanning ─────────────────────────────────────────────────

func _scan_enemies() -> void:
	if _world == null or not is_in_dungeon:
		_cached_enemy = null
		_cached_enemy_dist_tiles = INF
		return
	var best: Node2D = null
	var best_d2: float = INF
	var sight_px: float = WarriorState.SIGHT_RANGE_TILES * float(WorldConst.TILE_PX)
	var sight_d2: float = sight_px * sight_px
	for node in _world.get_hostile_cache():
		var d2: float = position.distance_squared_to(node.position)
		if d2 < best_d2 and d2 <= sight_d2:
			best_d2 = d2
			best = node
	_cached_enemy = best
	_cached_enemy_dist_tiles = sqrt(best_d2) / float(WorldConst.TILE_PX) if best != null else INF


# ─── Sprite ─────────────────────────────────────────────────────────

func _build_sprite() -> void:
	# Build a simple warrior paper-doll via CharacterBuilder.
	_sprite = CharacterBuilder.build({
		"skin": &"light",
		"torso_color": &"brown",
		"torso_style": 0,
		"torso_row": 0,
	})
	add_child(_sprite)
