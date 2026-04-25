## WorldMapView
##
## Per-player worldmap overlay. Fills the player's viewport pane.
## Renders one ImageTexture per discovered region (rebuilt when fog changes).
## Open/close animation: scale zoom-in from center + alpha fade.
## Vignette TextureRect overlaid for altitude effect.
extends Control
class_name WorldMapView

const BIOME_COLORS: Dictionary = {
	&"grass":  Color(0.35, 0.65, 0.25),
	&"water":  Color(0.15, 0.40, 0.75),
	&"desert": Color(0.85, 0.75, 0.45),
	&"swamp":  Color(0.30, 0.45, 0.25),
	&"snow":   Color(0.90, 0.93, 0.98),
	&"cave":   Color(0.30, 0.25, 0.20),
	&"ocean":  Color(0.08, 0.25, 0.60),
}
const BIOME_COLOR_FALLBACK: Color = Color(0.25, 0.25, 0.25)
const FOG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.75)
const SKY_COLOR: Color = Color(0.05, 0.08, 0.15, 1.0)
const LANDMARK_COLOR: Color = Color(0.8, 0.3, 0.3)

var _player: PlayerController = null
var _player_id: int = 0
## Cached ImageTexture per region. Rebuilt by _rebuild_all_textures().
var _region_textures: Dictionary = {}  # Vector2i → ImageTexture
var _textures_dirty: bool = true
var _is_animating: bool = false


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_vignette()


func _build_vignette() -> void:
	var vignette := TextureRect.new()
	vignette.name = "VignetteRect"
	vignette.anchor_left = 0.0
	vignette.anchor_right = 1.0
	vignette.anchor_top = 0.0
	vignette.anchor_bottom = 1.0
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.0, 0.0, 0.0, 0.85))
	grad.gradient = g
	vignette.texture = grad
	add_child(vignette)


## Call from game.gd after the player is created.
func set_player(p: PlayerController) -> void:
	_player = p
	_player_id = p.player_id


## Mark textures as needing rebuild on next draw. Called by PlayerController
## fog reveal timer.
func mark_dirty() -> void:
	_textures_dirty = true


## Toggle open/closed. Re-entrant calls during animation are ignored.
func toggle() -> void:
	if _is_animating:
		return
	if not visible:
		_open()
	else:
		_close()


func _open() -> void:
	_is_animating = true
	_textures_dirty = true
	visible = true
	pivot_offset = size / 2.0
	scale = Vector2(0.05, 0.05)
	modulate.a = 0.0
	InputContext.set_context(_player_id, InputContext.Context.MENU)
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
	InputContext.set_context(_player_id, InputContext.Context.GAMEPLAY)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY_COLOR)
	if _player == null:
		return
	if _textures_dirty:
		_rebuild_all_textures()
		_textures_dirty = false
	if _region_textures.is_empty():
		return
	var bbox: Rect2i = _compute_bbox()
	if bbox.size.x == 0 or bbox.size.y == 0:
		return
	var tile_px: float = _compute_tile_px(bbox)
	var map_origin: Vector2 = _compute_map_origin(bbox, tile_px)
	# Draw region textures.
	for region_id: Vector2i in _region_textures.keys():
		var tex: ImageTexture = _region_textures[region_id]
		var rpos: Vector2 = map_origin + Vector2(region_id.x * 128, region_id.y * 128) * tile_px
		var rsz: Vector2 = Vector2(128.0, 128.0) * tile_px
		draw_texture_rect(tex, Rect2(rpos, rsz), false)
	# Draw dungeon landmark icons.
	for rid: Vector2i in WorldManager.regions.keys():
		if not _region_textures.has(rid):
			continue
		var region: Region = WorldManager.regions[rid]
		for entry: Dictionary in region.dungeon_entrances:
			var cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
			if cell.x < 0:
				continue
			if not _player.fog_of_war.is_revealed(rid, cell):
				continue
			var spos: Vector2 = map_origin + Vector2(rid.x * 128 + cell.x, rid.y * 128 + cell.y) * tile_px
			draw_circle(spos, 3.0, LANDMARK_COLOR)
	# Draw player marker (pulsing).
	if _player._world != null and _player._world._region != null:
		var rid: Vector2i = _player._world._region.region_id
		var cx: int = int(floor(_player.position.x / float(WorldConst.TILE_PX)))
		var cy: int = int(floor(_player.position.y / float(WorldConst.TILE_PX)))
		var pulse: float = sin(Time.get_ticks_msec() * 0.004) * 0.25 + 0.75
		var mpos: Vector2 = map_origin + Vector2(rid.x * 128 + cx, rid.y * 128 + cy) * tile_px
		draw_circle(mpos, 3.0, Color(1.0, 1.0, 1.0, pulse))


func _rebuild_all_textures() -> void:
	_region_textures.clear()
	if _player == null:
		return
	for region_id: Vector2i in _player.fog_of_war.get_all_region_ids():
		_region_textures[region_id] = _build_region_texture(region_id)


func _build_region_texture(region_id: Vector2i) -> ImageTexture:
	var biome_color: Color = BIOME_COLOR_FALLBACK
	if WorldManager.plans.has(region_id):
		var plan: RegionPlan = WorldManager.plans[region_id]
		biome_color = BIOME_COLORS.get(plan.planned_biome, BIOME_COLOR_FALLBACK)
	var img: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var cell := Vector2i(x, y)
			if _player.fog_of_war.is_revealed(region_id, cell):
				img.set_pixel(x, y, biome_color)
			else:
				img.set_pixel(x, y, biome_color.lerp(Color(0.0, 0.0, 0.0, 1.0), 0.75))
	return ImageTexture.create_from_image(img)


func _compute_bbox() -> Rect2i:
	var ids: Array = _player.fog_of_war.get_all_region_ids()
	if ids.is_empty():
		return Rect2i()
	var min_x: int = (ids[0] as Vector2i).x
	var max_x: int = min_x
	var min_y: int = (ids[0] as Vector2i).y
	var max_y: int = min_y
	for rid: Vector2i in ids:
		min_x = mini(min_x, rid.x)
		max_x = maxi(max_x, rid.x)
		min_y = mini(min_y, rid.y)
		max_y = maxi(max_y, rid.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _compute_tile_px(bbox: Rect2i) -> float:
	var avail: float = minf(size.x, size.y) * 0.9
	var px_wide: float = avail / float(bbox.size.x * 128)
	var px_tall: float = avail / float(bbox.size.y * 128)
	return clampf(minf(px_wide, px_tall), 1.0, 6.0)


func _compute_map_origin(bbox: Rect2i, tile_px: float) -> Vector2:
	var total_w: float = float(bbox.size.x * 128) * tile_px
	var total_h: float = float(bbox.size.y * 128) * tile_px
	return Vector2(
		(size.x - total_w) * 0.5 - float(bbox.position.x * 128) * tile_px,
		(size.y - total_h) * 0.5 - float(bbox.position.y * 128) * tile_px
	)
