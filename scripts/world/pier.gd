## Pier
##
## A reusable pier prefab built procedurally from Kenney medieval-town wood
## plates + railings. Phase 8 sailing system spawns one Pier on each shore
## tile that connects to the harbor scene.
##
## Public API:
##   length      : how many planks deep the pier extends (away from shore).
##   orientation : 0..3 — selects which Kenney rotation variant is used.
##                 0 = pier extends towards iso (+x, -y) = screen-right;
##                 1 = +y, +x; 2 = -x, +y; 3 = -y, -x. (Matches Kenney's
##                 `_0/_1/_2/_3` convention so the asset itself rotates.)
extends Node2D
class_name Pier

const _MEDIEVAL: String = "res://assets/tiles/medieval/"
const _PLATE_BASE: String = "plate_wood_01"
const _RAIL_BASE: String = "wood_railing_01"

@export var length: int = 4 : set = _set_length
@export var orientation: int = 0 : set = _set_orientation
@export var with_railings: bool = true


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
	var plate := load("%s%s_%d.png" % [_MEDIEVAL, _PLATE_BASE, orientation]) as Texture2D
	var rail: Texture2D = null
	if with_railings:
		rail = load("%s%s_%d.png" % [_MEDIEVAL, _RAIL_BASE, orientation]) as Texture2D
	if plate == null:
		push_warning("[Pier] missing plate texture for orientation %d" % orientation)
		return
	# Step direction in iso tile coords for each orientation.
	var step_iso: Vector2i
	match orientation:
		0: step_iso = Vector2i(1, 0)
		1: step_iso = Vector2i(0, 1)
		2: step_iso = Vector2i(-1, 0)
		3: step_iso = Vector2i(0, -1)
		_: step_iso = Vector2i(1, 0)
	for i in length:
		var cell: Vector2i = step_iso * i
		var spr := Sprite2D.new()
		spr.texture = plate
		spr.position = Vector2(float(cell.x * WorldConst.TILE_PX), float(cell.y * WorldConst.TILE_PX))
		spr.scale = Vector2(0.5, 0.5)
		spr.offset = Vector2(0, -plate.get_height() * 0.25)
		add_child(spr)
		if rail != null and i > 0:
			var r_spr := Sprite2D.new()
			r_spr.texture = rail
			r_spr.position = Vector2(float(cell.x * WorldConst.TILE_PX), float(cell.y * WorldConst.TILE_PX))
			r_spr.scale = Vector2(0.5, 0.5)
			r_spr.offset = Vector2(0, -rail.get_height() * 0.25)
			add_child(r_spr)
