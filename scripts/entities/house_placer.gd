## HousePlacer
##
## Added to a WorldRoot by World.start_house_placement(). Handles ghost
## rendering and player input for positioning and confirming a new house.
## Emits confirmed(pid, cell) or cancelled(pid) then should be freed by
## the World coordinator.
class_name HousePlacer
extends Node2D

signal confirmed(pid: int, cell: Vector2i)
signal cancelled(pid: int)

## Player ID this placer belongs to (0 = P1, 1 = P2).
var pid: int = 0
## Structure being placed (e.g. &"house_basic").
var structure_id: StringName = &"house_basic"
## Reference to the WorldRoot this placer lives in.
var world_root: WorldRoot = null

const _TILE_PX: float = float(WorldConst.TILE_PX)
const _GHOST_TILES: int = 3        # footprint: 3×3 tiles
const _REPEAT_DELAY: float = 0.15  # held-key repeat interval

var _cursor_cell: Vector2i = Vector2i.ZERO
var _ghost_bg: ColorRect = null     # 3×3 semi-transparent overlay
var _ghost_door: ColorRect = null   # 1×1 yellow door marker
var _repeat_timer: float = 0.0
var _last_dir: Vector2i = Vector2i.ZERO

const _COL_VALID:   Color = Color(0.2, 1.0, 0.2, 0.35)
const _COL_INVALID: Color = Color(1.0, 0.2, 0.2, 0.35)
const _COL_DOOR:    Color = Color(1.0, 0.9, 0.1, 0.6)


func _ready() -> void:
	z_index = 50
	_ghost_bg = ColorRect.new()
	_ghost_bg.size = Vector2(_TILE_PX * _GHOST_TILES, _TILE_PX * _GHOST_TILES)
	_ghost_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost_bg)
	_ghost_door = ColorRect.new()
	_ghost_door.size = Vector2(_TILE_PX, _TILE_PX)
	_ghost_door.color = _COL_DOOR
	_ghost_door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost_door)
	# Start cursor near player.
	var world: World = World.instance()
	if world != null:
		var player: PlayerController = world.get_player(pid)
		if player != null:
			_cursor_cell = Vector2i(
				int(floor(player.position.x / _TILE_PX)),
				int(floor(player.position.y / _TILE_PX)))
	_update_ghost()


func _process(delta: float) -> void:
	_handle_input(delta)


func _handle_input(delta: float) -> void:
	# Confirm.
	if Input.is_action_just_pressed(PlayerActions.action(pid, PlayerActions.INTERACT)):
		if _is_valid(_cursor_cell):
			confirmed.emit(pid, _cursor_cell)
		return
	# Cancel.
	if Input.is_action_just_pressed(PlayerActions.action(pid, PlayerActions.BACK)) \
			or Input.is_action_just_pressed(PlayerActions.action(pid, PlayerActions.INVENTORY)):
		cancelled.emit(pid)
		return
	# Movement (with held-key repeat).
	var dir := Vector2i.ZERO
	if Input.is_action_pressed(PlayerActions.action(pid, PlayerActions.UP)):
		dir = Vector2i(0, -1)
	elif Input.is_action_pressed(PlayerActions.action(pid, PlayerActions.DOWN)):
		dir = Vector2i(0, 1)
	elif Input.is_action_pressed(PlayerActions.action(pid, PlayerActions.LEFT)):
		dir = Vector2i(-1, 0)
	elif Input.is_action_pressed(PlayerActions.action(pid, PlayerActions.RIGHT)):
		dir = Vector2i(1, 0)

	if dir != Vector2i.ZERO:
		if dir != _last_dir:
			_last_dir = dir
			_repeat_timer = _REPEAT_DELAY
			_move_cursor(dir)
		else:
			_repeat_timer -= delta
			if _repeat_timer <= 0.0:
				_repeat_timer = _REPEAT_DELAY
				_move_cursor(dir)
	else:
		_last_dir = Vector2i.ZERO


func _move_cursor(dir: Vector2i) -> void:
	_cursor_cell += dir
	_update_ghost()


func _update_ghost() -> void:
	var valid: bool = _is_valid(_cursor_cell)
	_ghost_bg.color = _COL_VALID if valid else _COL_INVALID
	var centre: Vector2 = (Vector2(_cursor_cell) + Vector2(0.5, 0.5)) * _TILE_PX
	_ghost_bg.position = centre - _ghost_bg.size * 0.5
	_ghost_door.position = Vector2(_cursor_cell) * _TILE_PX


func _is_valid(cell: Vector2i) -> bool:
	if world_root == null:
		return false
	if not world_root.is_walkable(cell):
		return false
	if world_root.has_door(cell):
		return false
	# Check for entities at this cell.
	for child in world_root.entities.get_children():
		if not (child is Node2D):
			continue
		var n: Node2D = child as Node2D
		var nc: Vector2i = Vector2i(
			int(floor(n.position.x / _TILE_PX)),
			int(floor(n.position.y / _TILE_PX)))
		if nc == cell:
			return false
	return true
