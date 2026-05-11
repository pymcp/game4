## Pier
##
## A reusable pier prefab built procedurally from tiles sliced out of the
## existing overworld_sheet.png.  Spawned by WorldRoot on any land region
## that has a recorded pier_position (set by WorldGenerator._place_pier).
##
## Public API:
##   length      : how many plank tiles the pier extends into the water.
##   orientation : 0..3 — cardinal direction the pier extends into:
##                 0 = east (+x);  1 = south (+y);
##                 2 = west (-x);  3 = north (-y).
##   with_railings: reserved for future use, currently unused.
extends Node2D
class_name Pier

const _SHEET: String = "res://assets/tiles/roguelike/overworld_sheet.png"
const _TILE_PX: int = WorldConst.TILE_PX   # 16
const _STRIDE: int = _TILE_PX + 1          # 17 (1 px gutter, no outer margin)

## Sand tile (8, 22) — warm brown/tan, visually reads as weathered dock wood.
const _PLANK_CELL: Vector2i = Vector2i(8, 22)

@export var length: int = 4 : set = _set_length
@export var orientation: int = 0 : set = _set_orientation
@export var with_railings: bool = true  # reserved; no separate railing sprite yet


func _ready() -> void:
	_rebuild()


func _set_length(v: int) -> void:
	length = max(1, v)
	if is_inside_tree():
		_rebuild()


func _set_orientation(v: int) -> void:
	orientation = posmod(v, 4)
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()

	var sheet: Texture2D = load(_SHEET) as Texture2D
	if sheet == null:
		push_warning("[Pier] overworld sheet not found: %s" % _SHEET)
		return

	var plate := AtlasTexture.new()
	plate.atlas = sheet
	plate.region = Rect2(
		_PLANK_CELL.x * _STRIDE,
		_PLANK_CELL.y * _STRIDE,
		_TILE_PX, _TILE_PX)

	var step: Vector2i
	match orientation:
		0: step = Vector2i(1, 0)
		1: step = Vector2i(0, 1)
		2: step = Vector2i(-1, 0)
		3: step = Vector2i(0, -1)
		_: step = Vector2i(1, 0)

	for i in length:
		var cell: Vector2i = step * i
		var spr := Sprite2D.new()
		spr.texture = plate
		# Sprite2D centres by default; offset by half a tile so (0,0) aligns
		# with the top-left corner of cell 0 (matching TileMapLayer convention).
		spr.offset = Vector2(_TILE_PX * 0.5, _TILE_PX * 0.5)
		spr.position = Vector2(float(cell.x * _TILE_PX), float(cell.y * _TILE_PX))
		add_child(spr)
