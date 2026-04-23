## NPC
##
## Generic non-player character. Holds HP, runs a small state machine that
## drives movement / attack behaviour, and emits a signal when
## destroyed. The pure helpers [code]decide_state[/code] and
## [code]wander_step[/code] are static so AI logic can be unit-tested
## without instantiating the node.
##
## States:
##   IDLE   — standing still, occasionally roll for a wander step
##   WANDER — drift toward [code]_wander_target_cell[/code] for a few seconds
##   CHASE  — head straight for [code]target[/code] (a [PlayerController])
##   ATTACK — within [code]attack_range_tiles[/code], swing on cooldown
##   DEAD   — frozen, queued for free
##
## Movement is grid-aware via [WorldRoot.is_walkable]; the npc's owning
## world is found by walking ancestors in [code]_ready[/code].
extends Node2D
class_name NPC

signal died(world_position: Vector2, drops: Array)

enum State { IDLE, WANDER, CHASE, ATTACK, DEAD }

const IDLE_DURATION_SEC: float = 1.5
const WANDER_DURATION_SEC: float = 2.5
const ATTACK_COOLDOWN_SEC: float = 1.0
const SIGHT_RADIUS_TILES: float = 6.0
const ATTACK_RADIUS_TILES: float = 1.25
const LEASH_RADIUS_TILES: float = 10.0

@export var kind: StringName = &"slime"
@export var max_health: int = 5
@export var health: int = 5
@export var move_speed: float = 96.0
@export var attack_damage: int = 1
@export var sight_radius_tiles: float = SIGHT_RADIUS_TILES
@export var attack_range_tiles: float = ATTACK_RADIUS_TILES
@export var leash_radius_tiles: float = LEASH_RADIUS_TILES
@export var drops: Array = []  # Array of {id: StringName, count: int}
@export var resistances: Dictionary = {}  # Element enum → float multiplier

## When `true`, this NPC counts as an enemy for pets and other ally AI
## (they will seek out and attack it). Villagers and other friendly NPCs
## leave this `false`. Has no effect on the NPC's own behaviour — purely
## a "team" tag read by other actors.
@export var hostile: bool = false

var state: State = State.IDLE
var target: Node2D = null
var home_cell: Vector2i = Vector2i.ZERO
var in_conversation: bool = false  ## Set by WorldRoot during dialogue.
var _world: WorldRoot = null
var _state_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _wander_target_cell: Vector2i = Vector2i.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _path: Array = []
var _path_target_cell: Vector2i = Vector2i(0x7fffffff, 0x7fffffff)
var _path_repath_timer: float = 0.0
const PATH_REPATH_SEC: float = 0.5


# ---------- Pure helpers ----------

## Decide which state the NPC should be in next, given:
## - [param curr]: current state
## - [param dist_tiles]: tile-distance to target (or +inf if no target)
## - [param hp]: current hp (0 → DEAD)
## - [param leash_tiles]: distance back to home cell (used to break chases)
## - [param sight_tiles], [param attack_tiles], [param leash_max_tiles]:
##   thresholds (instance fields normally; passed for testability).
static func decide_state(curr: State, dist_tiles: float, hp: int,
		leash_tiles: float, sight_tiles: float, attack_tiles: float,
		leash_max_tiles: float) -> State:
	if hp <= 0:
		return State.DEAD
	if curr == State.DEAD:
		return State.DEAD
	# If the npc has wandered too far from home while chasing, give up.
	if (curr == State.CHASE or curr == State.ATTACK) and leash_tiles > leash_max_tiles:
		return State.IDLE
	# Combat range overrides everything else.
	if dist_tiles <= attack_tiles:
		return State.ATTACK
	if dist_tiles <= sight_tiles:
		return State.CHASE
	# No target in sight — maintain non-combat state.
	if curr == State.CHASE or curr == State.ATTACK:
		return State.IDLE
	return curr


## Pick a random walkable neighbouring cell within [param max_dist].
## Returns [code]from[/code] when no valid neighbour exists.
## [param walkable_cb] takes a [Vector2i] and returns bool.
static func wander_step(rng: RandomNumberGenerator, from: Vector2i,
		max_dist: int, walkable_cb: Callable) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for dy in range(-max_dist, max_dist + 1):
		for dx in range(-max_dist, max_dist + 1):
			if dx == 0 and dy == 0:
				continue
			if abs(dx) + abs(dy) > max_dist:
				continue
			var c := from + Vector2i(dx, dy)
			if walkable_cb.call(c):
				candidates.append(c)
	if candidates.is_empty():
		return from
	return candidates[rng.randi() % candidates.size()]


## Step a position one frame toward a target, bounded by speed * delta.
## Returns the new position.
static func step_toward(curr: Vector2, dest: Vector2, speed: float,
		delta: float) -> Vector2:
	var to: Vector2 = dest - curr
	var d: float = to.length()
	if d <= 0.001:
		return curr
	var step: float = speed * delta
	if step >= d:
		return dest
	return curr + to / d * step


# ---------- Lifecycle ----------

func _ready() -> void:
	_rng.randomize()
	if health <= 0:
		health = max_health
	# Find owning world.
	var n: Node = self
	while n != null and not (n is WorldRoot):
		n = n.get_parent()
	_world = n as WorldRoot
	home_cell = IsoUtils.world_to_iso(position)
	# Default sprite from creature sprite registry; fallback to tinted placeholder.
	if get_node_or_null("Sprite") == null:
		var built: Sprite2D = CreatureSpriteRegistry.build_sprite(kind)
		if built != null:
			built.name = "Sprite"
			add_child(built)
		else:
			var s := Sprite2D.new()
			s.name = "Sprite"
			s.modulate = Color(0.85, 0.4, 0.4)
			add_child(s)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	# Freeze while in a conversation.
	if in_conversation:
		return
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_state_timer += delta
	# Compute decision inputs.
	var dist_tiles: float = INF
	if is_instance_valid(target):
		dist_tiles = position.distance_to(target.position) / IsoUtils.TILE_SIZE.x
	var leash_tiles: float = position.distance_to(IsoUtils.iso_to_world(home_cell)) / IsoUtils.TILE_SIZE.x
	var next: State = decide_state(state, dist_tiles, health, leash_tiles,
		sight_radius_tiles, attack_range_tiles, leash_radius_tiles)
	if next != state:
		_enter_state(next)
	# Per-state behaviour.
	match state:
		State.IDLE:
			if _state_timer > IDLE_DURATION_SEC:
				_enter_state(State.WANDER)
		State.WANDER:
			_tick_wander(delta)
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack(delta)
		_:
			pass


func _enter_state(s: State) -> void:
	state = s
	_state_timer = 0.0
	if s == State.WANDER:
		if _world != null:
			_wander_target_cell = wander_step(_rng,
				IsoUtils.world_to_iso(position), 3,
				func(c: Vector2i) -> bool: return _world.is_walkable(c))
		else:
			_wander_target_cell = IsoUtils.world_to_iso(position)


func _tick_wander(delta: float) -> void:
	if _state_timer > WANDER_DURATION_SEC:
		_enter_state(State.IDLE)
		return
	var dest: Vector2 = IsoUtils.iso_to_world(_wander_target_cell)
	position = step_toward(position, dest, move_speed * 0.5, delta)


func _tick_chase(delta: float) -> void:
	if not is_instance_valid(target):
		return
	# Repath periodically or whenever the target's cell changes.
	_path_repath_timer -= delta
	var goal_cell: Vector2i = IsoUtils.world_to_iso(target.position)
	if _world != null and (_path.is_empty() or _path_repath_timer <= 0.0
			or goal_cell != _path_target_cell):
		var start_cell: Vector2i = IsoUtils.world_to_iso(position)
		_path = Pathfinder.find_path(start_cell, goal_cell,
			func(c: Vector2i) -> bool: return _world.is_walkable(c))
		_path_target_cell = goal_cell
		_path_repath_timer = PATH_REPATH_SEC
	# Determine the immediate destination cell.
	var dest_pos: Vector2 = target.position
	if not _path.is_empty():
		var here: Vector2i = IsoUtils.world_to_iso(position)
		var nxt: Vector2i = Pathfinder.next_step(_path, here)
		dest_pos = IsoUtils.iso_to_world(nxt)
	# Move toward the next waypoint, but only commit if it's walkable.
	var step_pos: Vector2 = step_toward(position, dest_pos, move_speed, delta)
	var next_cell: Vector2i = IsoUtils.world_to_iso(step_pos)
	if _world == null or _world.is_walkable(next_cell) or next_cell == goal_cell:
		position = step_pos


func _tick_attack(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = ATTACK_COOLDOWN_SEC
	if target.has_method("take_hit"):
		target.call("take_hit", attack_damage, self)


# ---------- Damage / death ----------

func take_hit(damage: int, attacker: Node = null, element: int = 0) -> void:
	if state == State.DEAD:
		return
	# Invincible while in a conversation.
	if in_conversation:
		return
	var effective: int = _apply_resistance(damage, element)
	health = max(0, health - effective)
	if attacker is Node2D and target == null:
		target = attacker as Node2D
	if health <= 0:
		_die()
	else:
		pass  # Hit but not dead


func _apply_resistance(damage: int, element: int) -> int:
	if element == 0 or not resistances.has(element):
		return max(1, damage)
	var mult: float = float(resistances[element])
	return max(1, ceili(damage * mult))


func _die() -> void:
	state = State.DEAD
	died.emit(position, drops)
	queue_free()


# ---------- Helpers used by tests / spawner ----------

func set_target(t: Node2D) -> void:
	target = t


func set_world(world: WorldRoot) -> void:
	_world = world
