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

enum State { IDLE, WANDER, CHASE, ATTACK, STAGGERED, DEAD }

const IDLE_DURATION_SEC: float = 1.5
const WANDER_DURATION_SEC: float = 2.5
const ATTACK_COOLDOWN_SEC: float = 1.0
const STAGGER_DURATION_SEC: float = 0.6
const SIGHT_RADIUS_TILES: float = 6.0
const ATTACK_RADIUS_TILES: float = 1.25
const LEASH_RADIUS_TILES: float = 10.0

## Convert pixel position to integer tile cell for this game's top-down grid.
static func _pos_to_cell(pos: Vector2) -> Vector2i:
	var t: int = WorldConst.TILE_PX
	return Vector2i(int(floor(pos.x / float(t))), int(floor(pos.y / float(t))))

## Return pixel centre of a tile cell.
static func _cell_center(cell: Vector2i) -> Vector2:
	var t: float = float(WorldConst.TILE_PX)
	return Vector2((cell.x + 0.5) * t, (cell.y + 0.5) * t)

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
var hitbox_radius: float = 5.0  ## Gungeon-style body-core radius (native px).
var _world: WorldRoot = null
var _state_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _telegraph_timer: float = 0.0
var _telegraph_duration: float = 0.5
var _wander_target_cell: Vector2i = Vector2i.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _path: Array = []
var _path_target_cell: Vector2i = Vector2i(0x7fffffff, 0x7fffffff)
var _path_repath_timer: float = 0.0
var _bob_t: float = 0.0
var _npc_sprite: Node = null  ## The Sprite child, for bob animation.
var _heart_display: HeartDisplay = null
var _action_vfx: ActionVFX = null
const PATH_REPATH_SEC: float = 0.5
const _BOB_HZ: float = 4.0
const _BOB_AMP_PX: float = 1.0
## LOD / performance.
var _lod_sleeping: bool = false
var _lod_index: int = 0


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
	home_cell = _pos_to_cell(position)
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
	_npc_sprite = get_node_or_null("Sprite")
	# Hitbox radius: explicit JSON override → auto-calc from sprite → default.
	var explicit_hb: float = CreatureSpriteRegistry.get_hitbox_radius(kind)
	if explicit_hb >= 0.0:
		hitbox_radius = explicit_hb
	elif _npc_sprite is Sprite2D:
		hitbox_radius = HitboxCalc.radius_from_sprite(_npc_sprite as Sprite2D)
	# Overhead heart display — visible only when damaged.
	# Position above the sprite's visual top edge (accounts for hires multi-tile sprites).
	var heart_y: float = -14.0
	if _npc_sprite != null:
		if _npc_sprite.centered:
			var tex_h: float = float(_npc_sprite.texture.get_height()) if _npc_sprite.texture != null else 16.0
			heart_y = -(tex_h * 0.5 * abs(_npc_sprite.scale.y)) - 2.0
		else:
			heart_y = _npc_sprite.offset.y * abs(_npc_sprite.scale.y) - 2.0
	_heart_display = HeartDisplay.new(6.0)
	_heart_display.position = Vector2(-10, heart_y)
	_heart_display.visible = false
	add_child(_heart_display)
	# Attack VFX — lunges the sprite toward the target.
	_action_vfx = ActionVFX.new()
	add_child(_action_vfx)
	_action_vfx.setup(self, null, _world, _npc_sprite as Node2D)
	_telegraph_duration = CreatureSpriteRegistry.get_telegraph_duration(kind)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	# Update overhead hearts.
	if _heart_display != null:
		_heart_display.update(health, max_health)
		_heart_display.visible = health > 0 and health < max_health
	# Freeze while in a conversation.
	if in_conversation:
		return
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_state_timer += delta
	# Compute decision inputs.
	var dist_tiles: float = INF
	if is_instance_valid(target):
		var dist_px: float = position.distance_to(target.position)
		var target_hb: float = HitboxCalc.get_radius(target)
		dist_tiles = max(0.0, dist_px - target_hb) / float(WorldConst.TILE_PX)
	var leash_tiles: float = position.distance_to(_cell_center(home_cell)) / float(WorldConst.TILE_PX)
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
		State.STAGGERED:
			if _state_timer > STAGGER_DURATION_SEC:
				_enter_state(State.CHASE)
		_:
			pass
	# Bob sprite while moving.
	if _npc_sprite != null:
		if _action_vfx != null and _action_vfx.is_playing():
			pass  # Skip bob during lunge.
		elif state == State.WANDER or state == State.CHASE:
			_bob_t += delta
			_npc_sprite.position.y = -sin(_bob_t * TAU * _BOB_HZ) * _BOB_AMP_PX
		else:
			_bob_t = 0.0
			_npc_sprite.position.y = 0.0


func _enter_state(s: State) -> void:
	state = s
	_state_timer = 0.0
	if s == State.WANDER:
		if _world != null:
			_wander_target_cell = wander_step(_rng,
					_pos_to_cell(position), 3,
					func(c: Vector2i) -> bool: return _world.is_walkable(c))
		else:
			_wander_target_cell = _pos_to_cell(position)

func _tick_wander(delta: float) -> void:
	if _state_timer > WANDER_DURATION_SEC:
		_enter_state(State.IDLE)
		return
	var dest: Vector2 = _cell_center(_wander_target_cell)
	position = step_toward(position, dest, move_speed * 0.5, delta)


func _tick_chase(delta: float) -> void:
	if not is_instance_valid(target):
		return
	# Repath periodically or whenever the target's cell changes.
	_path_repath_timer -= delta
	var goal_cell: Vector2i = _pos_to_cell(target.position)
	if _world != null and (_path.is_empty() or _path_repath_timer <= 0.0
			or goal_cell != _path_target_cell):
		var start_cell: Vector2i = _pos_to_cell(position)
		_path = Pathfinder.find_path(start_cell, goal_cell,
			func(c: Vector2i) -> bool: return _world.is_walkable(c))
		_path_target_cell = goal_cell
		_path_repath_timer = PATH_REPATH_SEC + _lod_index * 0.125
	# Determine the immediate destination cell.
	var dest_pos: Vector2 = target.position
	if not _path.is_empty():
		var here: Vector2i = _pos_to_cell(position)
		var nxt: Vector2i = Pathfinder.next_step(_path, here)
		dest_pos = _cell_center(nxt)
	# Move toward the next waypoint, but only commit if it's walkable.
	var step_pos: Vector2 = step_toward(position, dest_pos, move_speed, delta)
	var next_cell: Vector2i = _pos_to_cell(step_pos)
	if _world == null or _world.is_walkable(next_cell) or next_cell == goal_cell:
		position = step_pos


func _tick_attack(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	if _attack_cooldown > 0.0:
		return
	# Telegraph phase: show windup before dealing damage.
	if _telegraph_timer > 0.0:
		_telegraph_timer -= _delta
		if _telegraph_timer <= 0.0:
			_finish_attack()
		return
	# Start a new telegraph.
	_telegraph_timer = _telegraph_duration
	_show_telegraph()


## Called when the telegraph timer expires — deliver the actual hit.
func _finish_attack() -> void:
	_hide_telegraph()
	_attack_cooldown = ATTACK_COOLDOWN_SEC
	if not is_instance_valid(target):
		return
	var attack_element: int = CreatureSpriteRegistry.get_element(kind)
	if target.has_method("take_hit"):
		target.call("take_hit", attack_damage, self, attack_element)
	# Lunge + particle VFX.
	var attack_style: StringName = CreatureSpriteRegistry.get_attack_style(kind)
	if _action_vfx != null and attack_style != &"none":
		var to_target: Vector2 = target.position - position
		var to_norm: Vector2 = to_target.normalized() if to_target.length() > 0.01 else Vector2(1, 0)
		var target_cell := Vector2i(
				int(floor(target.position.x / float(WorldConst.TILE_PX))),
				int(floor(target.position.y / float(WorldConst.TILE_PX))))
		_action_vfx.play_creature_attack(target_cell, to_norm, attack_style, attack_element)


## Show a red tint on the sprite to telegraph an incoming attack.
func _show_telegraph() -> void:
	if _npc_sprite != null:
		_npc_sprite.modulate = Color(1.5, 0.5, 0.5, 1.0)


## Clear the telegraph visual.
func _hide_telegraph() -> void:
	if _npc_sprite != null:
		_npc_sprite.modulate = Color.WHITE


# ---------- Damage / death ----------

func take_hit(damage: int, attacker: Node = null, element: int = 0) -> void:
	if state == State.DEAD:
		return
	# Wake from LOD sleep so the enemy can respond.
	if _lod_sleeping:
		_lod_sleeping = false
		set_physics_process(true)
	# Invincible while in a conversation.
	if in_conversation:
		return
	var effective: int = _apply_resistance(damage, element)
	health = max(0, health - effective)
	ActionParticles.flash_hit(self)
	if attacker is Node2D and target == null:
		target = attacker as Node2D
	if health <= 0:
		_die()
	else:
		pass  # Hit but not dead


## Called by player parry — enters STAGGERED state (frozen for STAGGER_DURATION_SEC).
func stagger() -> void:
	if state == State.DEAD:
		return
	_enter_state(State.STAGGERED)
	ActionParticles.flash_hit(self)


func _apply_resistance(damage: int, element: int) -> int:
	if element == 0 or not resistances.has(element):
		return max(1, damage)
	var mult: float = float(resistances[element])
	return max(1, ceili(damage * mult))


func _die() -> void:
	state = State.DEAD
	set_physics_process(false)
	died.emit(position, drops)
	queue_free()


# ---------- Helpers used by tests / spawner ----------

func set_target(t: Node2D) -> void:
	target = t


func set_world(world: WorldRoot) -> void:
	_world = world
