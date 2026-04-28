## Caravan
##
## The player's traveling caravan wagon. Follows the owner_player with a
## short lag on the overworld. Only exists on overworld/city views —
## world.gd handles spawning/despawning.
##
## Interacting with the caravan (pressing p*_interact while adjacent)
## opens the CaravanMenu for the owning player.
class_name Caravan
extends Node2D

## Sprite atlas cell on the overworld sheet. Mirrors TileMappings.caravan_wagon[0].
## Used as a fallback if TileMappings cannot be loaded.
const _FALLBACK_SPRITE_CELL: Vector2i = Vector2i(10, 0)
const _SHEET_PATH: String = "res://assets/tiles/roguelike/overworld_sheet.png"
const _TILE_SIZE: int = 16  # native pixels per atlas cell

const _FOLLOW_DIST_PX: float = 28.0   ## Start moving when farther than this.
const _ARRIVE_DIST_PX: float = 8.0    ## Stop moving when this close to lag point.
const _MOVE_SPEED_PX_S: float = 60.0
const _TELEPORT_TILES: float = 25.0   ## Snap to owner when this many tiles away.
const _PATH_REPATH_SEC: float = 0.5

## Set by world.gd when the caravan is created.
@export var owner_player: PlayerController = null
## The caravan's shared data (party membership + inventory).
@export var caravan_data: CaravanData = null

var _world: WorldRoot = null
var _sprite: Sprite2D = null
var _path: Array = []
var _path_target_cell: Vector2i = Vector2i(0x7fffffff, 0x7fffffff)
var _path_repath_timer: float = 0.0

## Emitted when player interacts with the caravan.
## world.gd / game.gd connects this to open the CaravanMenu.
signal interacted(by_player: PlayerController)


func _ready() -> void:
	_world = WorldRoot.find_from(self)
	_build_sprite()


func _process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	var owner_pos: Vector2 = owner_player.position
	var dist_px: float = position.distance_to(owner_pos)
	# Teleport if too far (owner fast-traveled or warped).
	if dist_px > _TELEPORT_TILES * float(WorldConst.TILE_PX):
		_teleport_to_owner()
		return
	# Walk toward a point just behind the owner using A* pathfinding.
	var lag_point: Vector2 = _lag_position()
	_tick_follow(lag_point, delta)


## Returns the position the caravan should aim for (behind the player).
func _lag_position() -> Vector2:
	if owner_player == null:
		return position
	# Follow one tile behind the player. Use a simple south offset
	# so the wagon appears behind on the screen.
	return owner_player.position + Vector2(0.0, float(WorldConst.TILE_PX) * 1.5)


func _step_toward(target_pos: Vector2, delta: float) -> void:
	var to_target: Vector2 = target_pos - position
	if to_target.length() <= _ARRIVE_DIST_PX:
		return
	var step: Vector2 = to_target.normalized() * _MOVE_SPEED_PX_S * delta
	var new_pos: Vector2 = position + step
	if _world != null:
		var cell: Vector2i = _pos_to_cell(new_pos)
		if not _world.is_walkable(cell):
			return
	position = new_pos


func _tick_follow(lag_point: Vector2, delta: float) -> void:
	if position.distance_to(lag_point) <= _ARRIVE_DIST_PX:
		return
	_path_repath_timer -= delta
	var goal_cell: Vector2i = _pos_to_cell(lag_point)
	if _world != null and (_path.is_empty() or _path_repath_timer <= 0.0
			or goal_cell != _path_target_cell):
		var start_cell: Vector2i = _pos_to_cell(position)
		_path = Pathfinder.find_path(start_cell, goal_cell,
			func(c: Vector2i) -> bool: return _world.is_walkable(c))
		_path_target_cell = goal_cell
		_path_repath_timer = _PATH_REPATH_SEC
	var dest_pos: Vector2 = lag_point
	if not _path.is_empty():
		var here: Vector2i = _pos_to_cell(position)
		var nxt: Vector2i = Pathfinder.next_step(_path, here)
		dest_pos = _cell_center(nxt)
	_step_toward(dest_pos, delta)


func _teleport_to_owner() -> void:
	if owner_player == null:
		return
	position = owner_player.position + Vector2(0.0, float(WorldConst.TILE_PX) * 1.5)
	_path.clear()
	_path_target_cell = Vector2i(0x7fffffff, 0x7fffffff)


static func _pos_to_cell(pos: Vector2) -> Vector2i:
	var t: int = WorldConst.TILE_PX
	return Vector2i(int(floor(pos.x / float(t))), int(floor(pos.y / float(t))))


static func _cell_center(cell: Vector2i) -> Vector2:
	var t: float = float(WorldConst.TILE_PX)
	return Vector2((cell.x + 0.5) * t, (cell.y + 0.5) * t)


## Called by WorldRoot._try_interact when the player is adjacent.
func interact(by: Node) -> void:
	if by is PlayerController and by == owner_player:
		interacted.emit(by as PlayerController)


## Returns true if `player` is close enough to interact.
func can_interact_with(player: PlayerController) -> bool:
	if player == null:
		return false
	var dist: float = position.distance_to(player.position)
	return dist <= float(WorldConst.TILE_PX) * 2.5


func _build_sprite() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = true
	var cell: Vector2i = _FALLBACK_SPRITE_CELL
	var sheet_path: String = _SHEET_PATH
	var tile_size: int = _TILE_SIZE
	# Try to read from TileMappings — also respect sheet_overrides.
	var tm: TileMappings = _load_tile_mappings()
	if tm != null and not tm.caravan_wagon.is_empty():
		cell = tm.caravan_wagon[0]
	# Resolve sheet override (may point to a hires sheet with different tile_px).
	sheet_path = TilesetCatalog.get_sheet_path(&"caravan_wagon")
	if sheet_path.is_empty():
		sheet_path = _SHEET_PATH
	var spec: SheetSpec = SheetSpecReader.read(sheet_path)
	tile_size = spec.tile_px if spec.tile_px > 0 else _TILE_SIZE
	var tex: Texture2D = load(sheet_path) as Texture2D
	if tex == null:
		push_warning("[Caravan] could not load sheet %s" % sheet_path)
		return
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(
			float(cell.x * spec.stride),
			float(cell.y * spec.stride),
			float(spec.tile_px),
			float(spec.tile_px))
	var sf: float = spec.scale_factor()
	if sf != 1.0:
		_sprite.scale = Vector2(sf, sf)
	add_child(_sprite)


static func _load_tile_mappings() -> TileMappings:
	var res: Resource = load("res://resources/tilesets/tile_mappings.tres")
	if res is TileMappings:
		return res as TileMappings
	return null
