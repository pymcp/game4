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

const _MOVE_SPEED_NATIVE: float = 60.0  ## native px/sec (≈3.75 tiles/s)
const _BOB_AMP_PX: float = 1.0
const _BOB_HZ: float = 6.0

@export var player_id: int = 0

var _world: WorldRoot = null
var _sprite_root: Node2D = null
var _bob_t: float = 0.0
var _facing_x: int = 1
var _facing_dir: Vector2i = Vector2i(1, 0)
var inventory: Inventory = Inventory.new()
var equipment: Equipment = Equipment.new()
var max_health: int = 10
var health: int = 10
var is_sailing: bool = false
var _boat: Boat = null

const _INTERACT_RADIUS_PX: float = 24.0  ## native pixels


func _ready() -> void:
	var n: Node = get_parent()
	while n != null and not (n is WorldRoot):
		n = n.get_parent()
	_world = n as WorldRoot
	_sprite_root = $SpriteRoot


## Update the WorldRoot reference. Called by [World] after re-parenting
## the player into a different instance (e.g. on view change).
func set_world(w: WorldRoot) -> void:
	_world = w


func _physics_process(delta: float) -> void:
	if _world == null:
		return
	# Skip all gameplay input when this player isn't in GAMEPLAY context
	# (inventory open, disabled by pause menu, etc.).
	if InputContext.get_context(player_id) != InputContext.Context.GAMEPLAY:
		_bob_t = 0.0
		_sprite_root.position = Vector2.ZERO
		return
	var prefix: String = "p%d_" % (player_id + 1)
	if Input.is_action_just_pressed(StringName(prefix + "interact")):
		_try_interact()
	if Input.is_action_just_pressed(StringName(prefix + "attack")):
		try_attack()
	var input := Vector2(
		Input.get_action_strength(StringName(prefix + "right"))
			- Input.get_action_strength(StringName(prefix + "left")),
		Input.get_action_strength(StringName(prefix + "down"))
			- Input.get_action_strength(StringName(prefix + "up")),
	)
	var moving: bool = input.length_squared() > 0.0001
	if moving:
		if input.length() > 1.0:
			input = input.normalized()
		_step(input * _MOVE_SPEED_NATIVE * delta)
		if input.x > 0.05:
			_facing_x = 1
		elif input.x < -0.05:
			_facing_x = -1
		# Track 4-direction facing for attack target selection.
		if abs(input.y) > abs(input.x):
			_facing_dir = Vector2i(0, signi(input.y))
		else:
			_facing_dir = Vector2i(signi(input.x), 0)
		_sprite_root.scale = Vector2(_facing_x, 1)
		_bob_t += delta
		var bob: float = sin(_bob_t * TAU * _BOB_HZ) * _BOB_AMP_PX
		_sprite_root.position = Vector2(0, -bob)
	else:
		_bob_t = 0.0
		_sprite_root.position = Vector2.ZERO


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
	# If a dialogue is open, the interact key acts as a dismiss instead of
	# rolling a new conversation (otherwise pressing E would immediately
	# re-open the same villager's box).
	if _world.dialogue_open():
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


# --- Attack / mining ---------------------------------------------

func try_attack() -> Dictionary:
	var my_cell: Vector2i = _cell_of(position)
	var target: Vector2i = my_cell + _facing_dir
	var res: Dictionary = _world.mine_at(target, 1)
	if not res.get("hit", false):
		return res
	if res.get("destroyed", false):
		for d in res.get("drops", []):
			inventory.add(d["id"], d["count"])
		_world.spawn_break_burst(target)
	else:
		_world.spawn_hit_burst(target)
	return res
