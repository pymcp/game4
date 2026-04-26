## DungeonMapView
##
## Per-player dungeon / labyrinth floor map overlay. Opens/closes with
## the same zoom-from-centre animation as [WorldMapView] but draws the
## current interior floor using [DungeonFogData] for fog, reading tile
## data directly from the [InteriorMap] resource.
##
## Activate via the same worldmap toggle action as [WorldMapView]; the
## [PlayerController] routes the toggle to whichever map is appropriate
## for the player's current context (overworld → WorldMapView,
## interior → DungeonMapView).
extends Control
class_name DungeonMapView

## Tile display colours.
const COL_BG:          Color = Color(0.04, 0.04, 0.07, 1.0)
const COL_FOG:         Color = Color(0.0,  0.0,  0.0,  0.82)
const COL_WALL:        Color = Color(0.18, 0.14, 0.12)
const COL_FLOOR:       Color = Color(0.48, 0.44, 0.38)
const COL_DOOR:        Color = Color(0.70, 0.58, 0.38)
const COL_STAIRS_UP:   Color = Color(0.88, 0.82, 0.20)
const COL_STAIRS_DOWN: Color = Color(0.85, 0.28, 0.22)

var _player: PlayerController = null
var _is_animating: bool = false
var _floor_label: Label = null


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	# Floor number label — top-centre.
	_floor_label = Label.new()
	_floor_label.name = "FloorLabel"
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_label.anchor_left = 0.0
	_floor_label.anchor_right = 1.0
	_floor_label.anchor_top = 0.0
	_floor_label.anchor_bottom = 0.0
	_floor_label.offset_top = 8.0
	_floor_label.offset_bottom = 32.0
	_floor_label.add_theme_font_size_override("font_size", 16)
	_floor_label.add_theme_color_override("font_color", Color.WHITE)
	_floor_label.add_theme_constant_override("outline_size", 2)
	_floor_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_floor_label)


## Wire the player reference. Call from game.gd after players are created.
func set_player(p: PlayerController) -> void:
	_player = p


## Trigger a redraw on next frame (called after fog is updated).
func mark_dirty() -> void:
	queue_redraw()


## Toggle open / closed. Re-entrant calls during animation are ignored.
func toggle() -> void:
	if _is_animating:
		return
	if not visible:
		_open()
	else:
		_close()


func _open() -> void:
	_is_animating = true
	visible = true
	pivot_offset = size / 2.0 if size != Vector2.ZERO else Vector2(size.x * 0.5, size.y * 0.5)
	scale = Vector2(0.05, 0.05)
	modulate.a = 0.0
	InputContext.set_context(_player.player_id, InputContext.Context.MENU)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: _is_animating = false)


func _close() -> void:
	_is_animating = true
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.05, 0.05), 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(_on_close_finished)


func _on_close_finished() -> void:
	visible = false
	_is_animating = false
	InputContext.set_context(_player.player_id, InputContext.Context.GAMEPLAY)


func _process(_delta: float) -> void:
	if visible:
		pivot_offset = size / 2.0
		# Update floor label from current interior.
		if _player != null and _player._world != null:
			var interior: InteriorMap = _player._world._interior
			if interior != null:
				_floor_label.text = "Floor %d" % interior.floor_num
			else:
				_floor_label.text = ""
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	if _player == null or _player._world == null:
		return
	var interior: InteriorMap = _player._world._interior
	if interior == null:
		return
	var fog: DungeonFogData = _player.dungeon_fog
	var map_w: int = interior.width
	var map_h: int = interior.height
	# Fit entire map into 90 % of the available area.
	var tile_px: float = minf(
			size.x * 0.9 / float(map_w),
			size.y * 0.9 / float(map_h))
	tile_px = clampf(tile_px, 2.0, 12.0)
	# Centre the grid.
	var origin: Vector2 = (size - Vector2(float(map_w), float(map_h)) * tile_px) * 0.5
	var rsz := Vector2(tile_px + 0.5, tile_px + 0.5)  # slight overdraw to avoid gaps
	for y in map_h:
		for x in map_w:
			var cell := Vector2i(x, y)
			var rpos: Vector2 = origin + Vector2(float(x), float(y)) * tile_px
			if not fog.is_revealed(interior.map_id, cell):
				draw_rect(Rect2(rpos, rsz), COL_FOG)
				continue
			var code: int = interior.at(cell)
			var col: Color
			match code:
				TerrainCodes.INTERIOR_WALL:
					col = COL_WALL
				TerrainCodes.INTERIOR_STAIRS_UP:
					col = COL_STAIRS_UP
				TerrainCodes.INTERIOR_STAIRS_DOWN:
					col = COL_STAIRS_DOWN
				TerrainCodes.INTERIOR_DOOR:
					col = COL_DOOR
				_:
					col = COL_FLOOR
			draw_rect(Rect2(rpos, rsz), col)
	# Player position dot (pulsing white, centred on player tile).
	var px: float = _player.position.x / float(WorldConst.TILE_PX)
	var py: float = _player.position.y / float(WorldConst.TILE_PX)
	var dot: Vector2 = origin + Vector2(px, py) * tile_px
	var pulse: float = sin(Time.get_ticks_msec() * 0.004) * 0.25 + 0.75
	draw_circle(dot, maxf(tile_px * 0.55, 3.0), Color(1.0, 1.0, 1.0, pulse))
