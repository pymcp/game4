## Villager
##
## Peaceful NPC built from a deterministic CharacterBuilder paper-doll.
## Wanders within `wander_radius` tiles of `home_cell`, picking a fresh
## random walkable cell every few seconds and pathing there via
## [Pathfinder]. On `interact` opens the local player's dialogue box
## with one of [VillagerDialogue]'s one-liners (also seed-deterministic).
##
## Coordinate system mirrors [PlayerController]: positions are native
## pixels (16-px tiles), the cell of a position is
## `Vector2i(floor(p.x / 16), floor(p.y / 16))`.
##
## State machine:
##   IDLE   — stand still for IDLE_DURATION_SEC, then pick a wander goal
##   WANDER — walk along the planned path until reached or stuck
extends Node2D
class_name Villager

enum State { IDLE, WANDER }

const IDLE_DURATION_SEC: float = 2.5
const WANDER_DURATION_SEC: float = 4.0
const MOVE_SPEED: float = 32.0  ## native px/sec
const PATH_REPATH_SEC: float = 0.75
const STUCK_EPSILON: float = 0.5
const STUCK_TIMEOUT_SEC: float = 0.8
const _BOB_HZ: float = 4.0
const _BOB_AMP_PX: float = 1.0

@export var npc_seed: int = 0
@export var home_cell: Vector2i = Vector2i.ZERO
@export var wander_radius: int = 6
## Optional branching dialogue tree. If null, falls back to one-liner.
@export var dialogue_tree: DialogueTree = null

var in_conversation: bool = false  ## Set by WorldRoot during dialogue.
var state: State = State.IDLE
var _world: WorldRoot = null
var _sprite_root: Node2D = null
var _state_timer: float = 0.0
var _path: Array = []
var _path_target_cell: Vector2i = Vector2i.ZERO
var _path_repath_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _bob_t: float = 0.0


# ---------- Pure helpers (testable without a scene) ----------

## Pick a walkable cell within `radius` tiles of `home`. Returns `home`
## if no candidate exists. `walkable_cb` is `Callable(Vector2i) -> bool`.
static func pick_wander_target(rng: RandomNumberGenerator, home: Vector2i,
		radius: int, walkable_cb: Callable) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			if abs(dx) + abs(dy) > radius:
				continue
			var c := home + Vector2i(dx, dy)
			if walkable_cb.call(c):
				candidates.append(c)
	if candidates.is_empty():
		return home
	return candidates[rng.randi() % candidates.size()]


## Step a position one frame toward `dest`, bounded by `speed * delta`.
static func step_toward(curr: Vector2, dest: Vector2, speed: float,
		delta: float) -> Vector2:
	var to: Vector2 = dest - curr
	var d: float = to.length()
	if d <= 0.001:
		return dest
	var step: float = speed * delta
	if step >= d:
		return dest
	return curr + to / d * step


## Build the CharacterBuilder option dict for a villager seed. Pure
## function so tests can verify determinism without instantiating any
## sprites.
static func roll_appearance(npc_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = ((npc_seed << 1) | 1) & 0x7fffffff
	var torso_colors: Array[StringName] = [
		&"orange", &"teal", &"purple", &"green", &"tan", &"black",
	]
	var hair_colors: Array[StringName] = [
		&"brown", &"blonde", &"white", &"ginger", &"gray",
	]
	var hair_styles: Array[int] = [
		CharacterAtlas.HairStyle.SHORT,
		CharacterAtlas.HairStyle.LONG,
		CharacterAtlas.HairStyle.ACCESSORY,
	]
	var skin_tones: Array[StringName] = [&"light", &"tan", &"dark"]
	var opts: Dictionary = {
		"skin": skin_tones[rng.randi() % skin_tones.size()],
		"torso_color": torso_colors[rng.randi() % torso_colors.size()],
		"torso_style": rng.randi() % 4,
		"torso_row": rng.randi() % 5,
		"hair_color": hair_colors[rng.randi() % hair_colors.size()],
		"hair_style": hair_styles[rng.randi() % hair_styles.size()],
		"hair_variant": rng.randi() % 4,
	}
	# 1-in-4 villagers get a beard accessory.
	if (rng.randi() % 4) == 0:
		opts["face_color"] = hair_colors[rng.randi() % hair_colors.size()]
		opts["face_variant"] = rng.randi() % 4
	return opts


# ---------- Lifecycle ----------

func _ready() -> void:
	# Find the owning WorldRoot so we can query walkability.
	var n: Node = self
	while n != null and not (n is WorldRoot):
		n = n.get_parent()
	_world = n as WorldRoot
	_sprite_root = get_node_or_null("SpriteRoot") as Node2D
	if _sprite_root == null:
		_sprite_root = Node2D.new()
		_sprite_root.name = "SpriteRoot"
		add_child(_sprite_root)
	_build_appearance()
	_last_pos = position


func _build_appearance() -> void:
	# Clear any leftover children (defensive — scene may already have a
	# Character child if instantiated more than once).
	for c in _sprite_root.get_children():
		c.queue_free()
	var opts: Dictionary = roll_appearance(npc_seed)
	var character: Node2D = CharacterBuilder.build(opts)
	# Lift the sprite up so its feet land on the cell centre rather than
	# its midpoint. The sheet is 16×16 with the body filling the bottom
	# ~12px; -6 puts the feet near y=0 (the Villager's origin).
	character.position = Vector2(0, -6)
	_sprite_root.add_child(character)


func _physics_process(delta: float) -> void:
	if _world == null:
		return
	# Freeze while in a conversation.
	if in_conversation:
		return
	_state_timer += delta
	_path_repath_timer -= delta
	match state:
		State.IDLE:
			if _state_timer > IDLE_DURATION_SEC:
				_enter_wander()
		State.WANDER:
			_tick_wander(delta)
	# Bob sprite while wandering.
	if state == State.WANDER and _sprite_root != null:
		_bob_t += delta
		_sprite_root.position.y = -abs(sin(_bob_t * TAU * _BOB_HZ)) * _BOB_AMP_PX
	elif _sprite_root != null:
		_bob_t = 0.0
		_sprite_root.position.y = 0.0


func _enter_wander() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (npc_seed ^ Time.get_ticks_msec()) & 0x7fffffff
	var goal: Vector2i = pick_wander_target(rng, home_cell, wander_radius,
		func(c: Vector2i) -> bool: return _world.is_walkable(c))
	_path = Pathfinder.find_path(_current_cell(), goal,
		func(c: Vector2i) -> bool: return _world.is_walkable(c))
	_path_target_cell = goal
	_path_repath_timer = PATH_REPATH_SEC
	_state_timer = 0.0
	_stuck_timer = 0.0
	_last_pos = position
	state = State.WANDER


func _enter_idle() -> void:
	_state_timer = 0.0
	_path = []
	state = State.IDLE


func _tick_wander(delta: float) -> void:
	if _state_timer > WANDER_DURATION_SEC or _path.is_empty():
		_enter_idle()
		return
	var here: Vector2i = _current_cell()
	var nxt: Vector2i = Pathfinder.next_step(_path, here)
	if nxt == here and here == _path_target_cell:
		_enter_idle()
		return
	var dest: Vector2 = (Vector2(nxt) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
	var new_pos: Vector2 = step_toward(position, dest, MOVE_SPEED, delta)
	# Only commit the move if the destination tile remains walkable
	# (something might have changed while we were on the way).
	var new_cell: Vector2i = Vector2i(
		int(floor(new_pos.x / float(WorldConst.TILE_PX))),
		int(floor(new_pos.y / float(WorldConst.TILE_PX))))
	if _world.is_walkable(new_cell) or new_cell == here:
		# Face left/right based on travel direction.
		if abs(new_pos.x - position.x) > 0.05 and _sprite_root != null:
			_sprite_root.scale.x = -1.0 if new_pos.x < position.x else 1.0
		position = new_pos
	# Stuck detection: re-path if we haven't moved meaningfully in a while.
	if position.distance_to(_last_pos) < STUCK_EPSILON:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
		_last_pos = position
	if _stuck_timer > STUCK_TIMEOUT_SEC or _path_repath_timer <= 0.0:
		_path = Pathfinder.find_path(here, _path_target_cell,
			func(c: Vector2i) -> bool: return _world.is_walkable(c))
		_path_repath_timer = PATH_REPATH_SEC
		_stuck_timer = 0.0
		if _path.is_empty():
			_enter_idle()


func _current_cell() -> Vector2i:
	return Vector2i(
		int(floor(position.x / float(WorldConst.TILE_PX))),
		int(floor(position.y / float(WorldConst.TILE_PX))))


# ---------- Interaction ----------

## Called by [PlayerController._try_interact] when the player presses
## the interact key while standing in range. Opens this player's
## dialogue box (per-viewport, so the other player isn't affected).
func interact(player: PlayerController) -> bool:
	if _world == null or player == null:
		return false
	if dialogue_tree != null:
		_world.show_dialogue_tree(player, dialogue_tree, self)
		return true
	# Fallback: one-liner dialogue.
	var speaker: String = VillagerDialogue.pick_name(npc_seed)
	var line: String = VillagerDialogue.pick_line(npc_seed)
	_world.show_dialogue(player.player_id, speaker, line, self)
	return true
