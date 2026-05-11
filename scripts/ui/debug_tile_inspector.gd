## DebugTileInspector
##
## CanvasLayer overlay (layer 55) that shows tile information under the mouse
## when debug_mode is active.
##
## Hover:   compact one-liner near the cursor.
## Right-click: pins / unpins a full detail panel showing every layer.
##
## Call [method setup] once after cameras and viewports are ready.
extends CanvasLayer
class_name DebugTileInspector

## Cameras indexed by player_id (0 = P1, 1 = P2).
var _cameras: Array[Camera2D] = [null, null]
## SubViewportContainer nodes indexed by player_id.
var _containers: Array[Control] = [null, null]
## SubViewport nodes indexed by player_id.
var _viewports: Array[SubViewport] = [null, null]

## The currently hovered tile cell (world space).
var _hover_cell: Vector2i = Vector2i(-9999, -9999)
## True when the detail panel is pinned by a right-click.
var _pinned: bool = false

@onready var _hover_label:   Label          = $HoverLabel
@onready var _detail_panel:  PanelContainer = $DetailPanel
@onready var _detail_label:  Label          = $DetailPanel/Margin/DetailLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_hover_label.visible = false
	_detail_panel.visible = false


## Provide cameras and viewport containers so the inspector can convert mouse
## screen coordinates to world tile cells.
## Call this from game.gd after _wire_hud_and_cameras().
func setup(cam_p1: Camera2D, cam_p2: Camera2D,
		container_p1: Control, container_p2: Control,
		vp_p1: SubViewport, vp_p2: SubViewport) -> void:
	_cameras[0]    = cam_p1
	_cameras[1]    = cam_p2
	_containers[0] = container_p1
	_containers[1] = container_p2
	_viewports[0]  = vp_p1
	_viewports[1]  = vp_p2


func _process(_delta: float) -> void:
	if not GameState.get_flag("debug_mode"):
		visible = false
		_pinned = false
		return
	visible = true

	var mouse_screen: Vector2 = get_viewport().get_mouse_position()
	var pid: int = _pid_from_screen_pos(mouse_screen)
	if pid < 0:
		_hover_label.visible = false
		return

	var cell: Vector2i = _screen_to_tile(mouse_screen, pid)
	if cell == Vector2i(-9999, -9999):
		_hover_label.visible = false
		return
	_hover_cell = cell

	# Update hover label.
	var world_root: WorldRoot = World.instance().get_player_world(pid) if World.instance() != null else null
	if world_root == null:
		_hover_label.visible = false
		return

	var info: Dictionary = world_root.get_tile_info_at_cell(cell)
	_hover_label.text = _build_hover_text(info)
	_hover_label.visible = true
	# Position the label near the cursor, offset so it doesn't sit under the pointer.
	var label_pos: Vector2 = mouse_screen + Vector2(14, -10)
	var vp_size: Vector2 = Vector2(get_viewport().size)
	label_pos.x = clampf(label_pos.x, 0.0, vp_size.x - 200.0)
	label_pos.y = clampf(label_pos.y, 0.0, vp_size.y - 40.0)
	_hover_label.position = label_pos

	# If pinned, keep detail panel content updated only when cell changes.
	if _pinned:
		_detail_label.text = _build_detail_text(info)


func _input(event: InputEvent) -> void:
	if not GameState.get_flag("debug_mode"):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _pinned:
				# Right-click again → unpin.
				_pinned = false
				_detail_panel.visible = false
			else:
				# Pin at current hover cell.
				var mouse_screen: Vector2 = get_viewport().get_mouse_position()
				var pid: int = _pid_from_screen_pos(mouse_screen)
				if pid >= 0:
					var world_root: WorldRoot = World.instance().get_player_world(pid) if World.instance() != null else null
					if world_root != null and _hover_cell != Vector2i(-9999, -9999):
						var info: Dictionary = world_root.get_tile_info_at_cell(_hover_cell)
						_detail_label.text = _build_detail_text(info)
						_detail_panel.visible = true
						_detail_panel.reset_size()
						_pinned = true
						# Position panel near click, clamped to screen.
						var panel_pos: Vector2 = mouse_screen + Vector2(16, 16)
						var vp_size: Vector2 = Vector2(get_viewport().size)
						panel_pos.x = clampf(panel_pos.x, 0.0, vp_size.x - 320.0)
						panel_pos.y = clampf(panel_pos.y, 0.0, vp_size.y - 400.0)
						_detail_panel.position = panel_pos
			get_viewport().set_input_as_handled()


# ─── Coordinate math ──────────────────────────────────────────────────────────

## Return 0 or 1 based on which screen half the mouse is in.
## Returns -1 if neither container is ready.
func _pid_from_screen_pos(screen_pos: Vector2) -> int:
	for pid: int in 2:
		var container: Control = _containers[pid]
		if container == null or not is_instance_valid(container):
			continue
		var rect: Rect2 = _get_global_rect(container)
		if rect.has_point(screen_pos):
			return pid
	return -1


## Convert a screen position to a world tile cell for the given player.
func _screen_to_tile(screen_pos: Vector2, pid: int) -> Vector2i:
	var cam: Camera2D = _cameras[pid]
	var container: Control = _containers[pid]
	var viewport: SubViewport = _viewports[pid]
	if cam == null or container == null or viewport == null:
		return Vector2i(-9999, -9999)
	if not is_instance_valid(cam):
		return Vector2i(-9999, -9999)

	var container_rect: Rect2 = _get_global_rect(container)
	var container_local: Vector2 = screen_pos - container_rect.position
	# Stretch factor: container may be larger than the SubViewport pixel size.
	var vp_size: Vector2 = Vector2(viewport.size)
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return Vector2i(-9999, -9999)
	var stretch: Vector2 = container_rect.size / vp_size
	var viewport_local: Vector2 = container_local / stretch
	# Camera offset: camera sits at the player world position.
	# The World node is scaled by RENDER_ZOOM, so one tile occupies TILE_PX * RENDER_ZOOM
	# canvas pixels.  WorldRoot instances are offset along X by N * INSTANCE_OFFSET_PX in
	# global space so they never overlap.  We must subtract the WorldRoot's global_position
	# before dividing so that the resulting cell is local to THIS instance (0-based), not
	# the raw global canvas coordinate.  Without this, any non-overworld instance (dungeon,
	# maze, house) returns a cell shifted by ~N * 1562 tiles.
	var instance_origin: Vector2 = Vector2.ZERO
	if World.instance() != null:
		var wr: WorldRoot = World.instance().get_player_world(pid)
		if wr != null:
			instance_origin = wr.global_position
	# Divide the viewport-local offset by cam.zoom so the tile lookup stays
	# accurate regardless of zoom level.  cam.zoom > 1 means fewer canvas
	# pixels per screen pixel (zoomed in); cam.zoom < 1 means more (zoomed out).
	var world_pos: Vector2 = (cam.global_position - instance_origin) + (viewport_local - vp_size * 0.5) / cam.zoom.x
	var tile_world_px: float = float(WorldConst.TILE_PX) * float(WorldConst.RENDER_ZOOM)
	return Vector2i(int(floor(world_pos.x / tile_world_px)), int(floor(world_pos.y / tile_world_px)))


## Get a Control's global rect in screen space.
func _get_global_rect(c: Control) -> Rect2:
	return Rect2(c.get_global_rect())


# ─── Text builders ────────────────────────────────────────────────────────────

func _build_hover_text(info: Dictionary) -> String:
	var cell: Vector2i = info.get("cell", Vector2i.ZERO)
	var biome: StringName = info.get("biome", &"")
	var layers: Array = info.get("layers", [])
	if layers.is_empty():
		return "Tile (%d,%d) | biome:%s | (empty)" % [cell.x, cell.y, String(biome)]
	# Show the topmost painted layer with its sheet name and atlas coords.
	var top: Dictionary = layers[layers.size() - 1]
	var atlas: Vector2i = top.get("atlas", Vector2i.ZERO)
	var sheet_path: String = top.get("sheet_path", "")
	var sheet_name: String = sheet_path.get_file() if sheet_path != "" else "?"
	var mn: Variant = top.get("mineable", null)
	var kind_str: String
	if mn is Dictionary:
		kind_str = mn.get("display_name", "?")
	else:
		var terrain: StringName = top.get("terrain", &"")
		kind_str = String(terrain) if terrain != &"" else top.get("layer", "?")
	return "(%d,%d) %s | sheet:%s atlas:(%d,%d)" % [cell.x, cell.y, kind_str, sheet_name, atlas.x, atlas.y]


func _build_detail_text(info: Dictionary) -> String:
	var cell: Vector2i = info.get("cell", Vector2i.ZERO)
	var biome: StringName = info.get("biome", &"")
	var tile_idx: int = info.get("region_tile_index", -1)
	var layers: Array = info.get("layers", [])

	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== Tile (%d, %d) ===" % [cell.x, cell.y])
	lines.append("Biome: %s  |  Region tile index: %d" % [String(biome), tile_idx])
	lines.append("")

	if layers.is_empty():
		lines.append("(no painted tiles at this cell)")
	else:
		for layer: Dictionary in layers:
			lines.append("── %s ──" % layer.get("layer", "?"))
			var atlas: Vector2i = layer.get("atlas", Vector2i.ZERO)
			lines.append("  Atlas cell:   (%d, %d)" % [atlas.x, atlas.y])
			var terrain: StringName = layer.get("terrain", &"")
			if terrain != &"":
				lines.append("  Terrain tag:  %s" % String(terrain))
			lines.append("  Sheet field:  %s" % String(layer.get("sheet_field", &"")))
			lines.append("  Sheet PNG:    %s" % layer.get("sheet_path", ""))
			var mn: Variant = layer.get("mineable", null)
			if mn is Dictionary:
				lines.append("  Mineable:     %s" % mn.get("display_name", "?"))
				lines.append("    HP:         %d" % int(mn.get("hp", 0)))
				lines.append("    Pickaxe+:   %s" % str(mn.get("is_pickaxe_bonus", false)))
				var drops: Array = mn.get("drops", [])
				if not drops.is_empty():
					var drop_strs: PackedStringArray = PackedStringArray()
					for d: Dictionary in drops:
						drop_strs.append("%s×%d" % [d.get("item_id", "?"), d.get("count", 1)])
					lines.append("    Drops:      %s" % ", ".join(drop_strs))
				var bw: Dictionary = mn.get("biome_weights", {})
				if not bw.is_empty():
					var bw_parts: PackedStringArray = PackedStringArray()
					for bk: String in bw:
						bw_parts.append("%s:%.2f" % [bk, float(bw[bk])])
					lines.append("    Biome wts:  %s" % ", ".join(bw_parts))
			lines.append("")

	return "\n".join(lines)
