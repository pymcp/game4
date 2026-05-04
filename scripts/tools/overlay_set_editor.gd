## OverlaySetEditor
##
## Sub-editor for TileMappings.overworld_overlay_sets.
## Shown when "Overlay Sets (terrain blending)" is selected in the GameEditor tree.
##
## Layout
## ------
## Top bar:  [Set dropdown]    [status label]
## Body:     Two-panel HSplit:
##   Left:  _TileDiagramView — renders each assigned atlas cell in its logical
##          position (3x3 blob, 2x2 inner corners, 7 path tiles). Click any cell
##          to activate that slot.
##   Right: _SheetView — the main cell selection pane. Shows all assigned cells
##          highlighted. Click any atlas cell to assign it to the active slot.
##
## All edits go straight into _mappings.overworld_overlay_sets and emit
## dirty_changed(true) so the parent GameEditor can track unsaved changes.
class_name OverlaySetEditor
extends VBoxContainer

signal dirty_changed(is_dirty: bool)

const SET_NAMES: Array = [&"dirt", &"stone", &"snow", &"grass", &"mud", &"purple"]

const COLOR_BLOB:   Color = Color(0.3, 0.8, 1.0)
const COLOR_INNER:  Color = Color(1.0, 0.70, 0.2)
const COLOR_PATH:   Color = Color(0.9, 0.4, 0.85)
const COLOR_ACTIVE: Color = Color(0.3, 1.0, 0.4)

const TILE_PX: int = 16
const GUTTER:  int = 1
const STRIDE:  int = TILE_PX + GUTTER

# --- State ---

var _mappings: TileMappings = null
var _active_set: StringName = &"dirt"
var _active_slot: int = 0
var _texture: Texture2D = null

var _set_opt: OptionButton = null
var _status_lbl: Label = null
var _diagram = null
var _sheet_view = null


# --- Public API ---

func setup(mappings: TileMappings) -> void:
	_mappings = mappings
	_seed_missing_sets()
	_build_ui()
	_texture = load("res://assets/tiles/roguelike/overworld_sheet.png") as Texture2D
	if _sheet_view != null:
		_sheet_view.set_sheet(_texture)
	_load_set(_active_set)


func _seed_missing_sets() -> void:
	if _mappings == null:
		return
	var defaults: TileMappings = TileMappings.default_mappings()
	for name in defaults.overworld_overlay_sets:
		var default_arr: Array = defaults.overworld_overlay_sets[name]
		if not _mappings.overworld_overlay_sets.has(name):
			_mappings.overworld_overlay_sets[name] = default_arr.duplicate()
		else:
			var arr: Array = _mappings.overworld_overlay_sets[name]
			while arr.size() < default_arr.size():
				arr.append(Vector2i(0, 0))


# --- UI construction ---

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 28)
	add_child(bar)

	var lbl := Label.new()
	lbl.text = "Overlay set: "
	bar.add_child(lbl)

	_set_opt = OptionButton.new()
	_set_opt.custom_minimum_size = Vector2(90, 0)
	for i in SET_NAMES.size():
		_set_opt.add_item(SET_NAMES[i])
	_set_opt.item_selected.connect(func(i: int) -> void: _load_set(SET_NAMES[i]))
	bar.add_child(_set_opt)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_status_lbl = Label.new()
	_status_lbl.text = "Click a tile in the diagram to select its slot, then click the atlas to assign."
	_status_lbl.add_theme_font_size_override("font_size", 10)
	bar.add_child(_status_lbl)

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(split)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(310, 0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left_scroll)

	_diagram = _TileDiagramView.new()
	_diagram.mouse_filter = Control.MOUSE_FILTER_STOP
	_diagram.tile_slot_clicked.connect(_on_slot_clicked)
	left_scroll.add_child(_diagram)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)

	_sheet_view = _SheetView.new()
	_sheet_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet_view.cell_clicked.connect(_on_atlas_clicked)
	right_scroll.add_child(_sheet_view)


# --- Data helpers ---

func _load_set(name: StringName) -> void:
	_active_set = name
	for i in SET_NAMES.size():
		if SET_NAMES[i] == name:
			_set_opt.selected = i
			break
	var max_slot: int = 19 if _set_is_20(name) else 12
	if _active_slot > max_slot:
		_active_slot = 0
	_refresh_diagram()
	_refresh_marks()
	_status_lbl.text = "Set: %s  (%s)  ---  slot %d active" % [
		name, ("20 tiles" if _set_is_20(name) else "13 tiles"), _active_slot]


func _get_current_cells() -> Array:
	if _mappings == null:
		return []
	var sets: Dictionary = _mappings.overworld_overlay_sets
	if not sets.has(_active_set):
		return []
	return sets[_active_set] as Array


func _set_cell(idx: int, cell: Vector2i) -> void:
	if _mappings == null:
		return
	var sets: Dictionary = _mappings.overworld_overlay_sets
	if not sets.has(_active_set):
		return
	var arr: Array = sets[_active_set] as Array
	if idx >= arr.size():
		return
	arr[idx] = cell
	dirty_changed.emit(true)


func _set_is_20(name: StringName) -> bool:
	return name == &"dirt" or name == &"stone" or name == &"snow"


# --- Event handlers ---

func _on_slot_clicked(idx: int) -> void:
	_active_slot = idx
	_refresh_diagram()
	_refresh_marks()
	var names: Array = [
		"NW outer", "N edge", "NE outer",
		"W edge", "center", "E edge",
		"SW outer", "S edge", "SE outer",
		"inner NW", "inner NE", "inner SW", "inner SE",
		"N+S straight", "E+W straight",
		"dead-end N", "dead-end S", "dead-end W", "dead-end E",
		"isolated",
		"path corner N+E", "path corner N+W", "path corner S+E", "path corner S+W",
		"T-junction (missing W)", "T-junction (missing S)",
		"T-junction (missing E)", "T-junction (missing N)",
		"cross (+)",
	]
	var lbl: String = names[idx] if idx < names.size() else str(idx)
	_status_lbl.text = "Slot %d: %s  ---  click the atlas to assign" % [idx, lbl]


func _on_atlas_clicked(cell: Vector2i) -> void:
	if _active_slot < 0:
		return
	_set_cell(_active_slot, cell)
	_refresh_diagram()
	_refresh_marks()
	_status_lbl.text = "Slot %d -> (%d, %d)" % [_active_slot, cell.x, cell.y]


# --- UI refresh ---

func _refresh_diagram() -> void:
	if _diagram == null:
		return
	var cells: Array = _get_current_cells()
	_diagram.setup(cells, _set_is_20(_active_set), _active_slot, _texture)


func _refresh_marks() -> void:
	if _sheet_view == null:
		return
	var cells: Array = _get_current_cells()
	var marks: Array = []
	for i in cells.size():
		var c: Vector2i = cells[i]
		var col: Color = COLOR_BLOB if i < 9 else (COLOR_INNER if i < 13 else COLOR_PATH)
		var active: bool = (i == _active_slot)
		marks.append({
			"cell":  c,
			"color": COLOR_ACTIVE if active else col,
			"width": 3.0 if active else 1.5,
		})
	_sheet_view.set_marks(marks)


# ===========================================================================
# Inner class: _TileDiagramView
#
# Shows each tile slot rendered from the atlas at its logical position.
# Clicking a cell emits tile_slot_clicked(index).
# ===========================================================================

class _TileDiagramView extends Control:
	signal tile_slot_clicked(index: int)

	const TILE_PX: int = 16
	const GUTTER:  int = 1
	const STRIDE:  int = TILE_PX + GUTTER
	const ZOOM:    int = 3
	const CELL:    int = TILE_PX * ZOOM
	const LABEL_H: int = 14
	const PAD_X:   int = 8
	const PAD_Y:   int = 4
	const STEP_X:  int = CELL + PAD_X
	const STEP_Y:  int = CELL + LABEL_H + PAD_Y
	const COL_GAP: int = 24
	const SEC_GAP: int = 22
	const HDR_H:   int = 16

	const TILE_LABELS: Array = [
		"NW", "N", "NE",
		"W", "C", "E",
		"SW", "S", "SE",
		"iNW", "iNE", "iSW", "iSE",
		"N|S", "E|W",
		"dN", "dS", "dW", "dE",
		"iso",
		"cNE", "cNW", "cSE", "cSW",
		"tW", "tS", "tE", "tN",
		"+",
	]

	const COLOR_BLOB:   Color = Color(0.3, 0.8, 1.0, 0.9)
	const COLOR_INNER:  Color = Color(1.0, 0.70, 0.2, 0.9)
	const COLOR_PATH:   Color = Color(0.9, 0.4, 0.85, 0.9)
	const COLOR_ACTIVE: Color = Color(0.3, 1.0, 0.4, 1.0)
	const COLOR_DIM:    Color = Color(0.9, 0.4, 0.85, 0.3)
	const BG_CELL:      Color = Color(0.13, 0.13, 0.16)
	const BG_CELL_DIM:  Color = Color(0.09, 0.09, 0.11)

	var _cells: Array = []
	var _is_20: bool = true
	var _active_slot: int = -1
	var _texture: Texture2D = null
	var _slot_rects: Array = []

	func setup(cells: Array, is_20: bool, active: int, tex: Texture2D) -> void:
		_cells = cells
		_is_20 = is_20
		_active_slot = active
		_texture = tex
		_build_layout()
		queue_redraw()

	func _build_layout() -> void:
		_slot_rects.clear()

		var sec_a_y: int = HDR_H
		for i in 9:
			var col: int = i % 3
			var row: int = i / 3
			_slot_rects.append({
				"idx": i,
				"rect": Rect2(float(col * STEP_X), float(sec_a_y + row * STEP_Y),
						float(CELL), float(CELL)),
			})
		var ic_x: int = 4 * STEP_X + COL_GAP
		for i in 4:
			var col: int = i % 2
			var row: int = i / 2
			_slot_rects.append({
				"idx": 9 + i,
				"rect": Rect2(float(ic_x + col * STEP_X), float(sec_a_y + row * STEP_Y),
						float(CELL), float(CELL)),
			})

		var sec_b_y: int = sec_a_y + 3 * STEP_Y + SEC_GAP + HDR_H
		_slot_rects.append({"idx": 13, "rect": Rect2(0.0, float(sec_b_y), float(CELL), float(CELL))})
		_slot_rects.append({"idx": 14, "rect": Rect2(float(STEP_X), float(sec_b_y), float(CELL), float(CELL))})
		for i in 4:
			_slot_rects.append({
				"idx": 15 + i,
				"rect": Rect2(float(i * STEP_X), float(sec_b_y + STEP_Y), float(CELL), float(CELL)),
			})
		_slot_rects.append({"idx": 19, "rect": Rect2(0.0, float(sec_b_y + 2 * STEP_Y), float(CELL), float(CELL))})

		# Section C: path corners (20-23), T-junctions (24-27), cross (28)
		var sec_c_y: int = sec_b_y + 3 * STEP_Y + SEC_GAP + HDR_H
		for i in 4:
			_slot_rects.append({
				"idx": 20 + i,
				"rect": Rect2(float(i * STEP_X), float(sec_c_y), float(CELL), float(CELL)),
			})
		for i in 4:
			_slot_rects.append({
				"idx": 24 + i,
				"rect": Rect2(float(i * STEP_X), float(sec_c_y + STEP_Y), float(CELL), float(CELL)),
			})
		_slot_rects.append({"idx": 28, "rect": Rect2(0.0, float(sec_c_y + 2 * STEP_Y), float(CELL), float(CELL))})

		var max_x: float = 0.0
		var max_y: float = 0.0
		for item in _slot_rects:
			var r: Rect2 = item["rect"]
			max_x = maxf(max_x, r.end.x)
			max_y = maxf(max_y, r.end.y + float(LABEL_H + PAD_Y))
		custom_minimum_size = Vector2(max_x + float(PAD_X), max_y + float(PAD_Y))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			for item in _slot_rects:
				var r: Rect2 = item["rect"]
				var hit := Rect2(r.position, r.size + Vector2(0.0, float(LABEL_H + PAD_Y)))
				if hit.has_point(ev.position):
					tile_slot_clicked.emit(item["idx"])
					return

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		var sec_a_y: float = float(HDR_H)
		var sec_b_y: float = sec_a_y + float(3 * STEP_Y + SEC_GAP + HDR_H)
		var sec_c_y: float = sec_b_y + float(3 * STEP_Y + SEC_GAP + HDR_H)
		var ic_x: float    = float(4 * STEP_X + COL_GAP)

		var hdr_blob  := Color(COLOR_BLOB.r,  COLOR_BLOB.g,  COLOR_BLOB.b,  0.85)
		var hdr_inner := Color(COLOR_INNER.r, COLOR_INNER.g, COLOR_INNER.b, 0.85)
		var hdr_path  := Color(COLOR_PATH.r,  COLOR_PATH.g,  COLOR_PATH.b,
				0.85 if _is_20 else 0.35)

		draw_string(font, Vector2(0.0, sec_a_y - 3.0),
				"Outer transitions (0-8)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hdr_blob)
		draw_string(font, Vector2(ic_x, sec_a_y - 3.0),
				"Inner corners (9-12)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hdr_inner)
		var path_hdr: String = "Path tiles 13-19  (N/A for 13-tile sets)" if not _is_20 \
				else "Path tiles (13-19)"
		draw_string(font, Vector2(0.0, sec_b_y - 3.0),
				path_hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hdr_path)
		var ext_hdr: String = "Path corners/T-junctions/cross (20-28)  (N/A for 13-tile sets)" if not _is_20 \
				else "Path corners / T-junctions / cross (20-28)"
		draw_string(font, Vector2(0.0, sec_c_y - 3.0),
				ext_hdr, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hdr_path)

		for item in _slot_rects:
			var idx: int   = item["idx"]
			var r: Rect2   = item["rect"]
			var is_path:   bool = idx >= 13
			var is_active: bool = idx == _active_slot
			var is_dim:    bool = is_path and not _is_20

			var cat_col: Color
			if is_dim:
				cat_col = COLOR_DIM
			elif idx < 9:
				cat_col = COLOR_BLOB
			elif idx < 13:
				cat_col = COLOR_INNER
			else:
				cat_col = COLOR_PATH

			draw_rect(r, BG_CELL_DIM if is_dim else BG_CELL, true)

			if _texture != null and idx < _cells.size() and not is_dim:
				var atlas_cell: Vector2i = _cells[idx]
				var src := Rect2(
						float(atlas_cell.x * STRIDE), float(atlas_cell.y * STRIDE),
						float(TILE_PX), float(TILE_PX))
				draw_texture_rect_region(_texture, r, src)

			if is_active:
				draw_rect(r, COLOR_ACTIVE, false, 3.0)
			else:
				draw_rect(r, cat_col, false, 1.5)

			var idx_col: Color = Color(1, 1, 1, 0.55) if not is_dim else Color(1, 1, 1, 0.2)
			draw_string(font, Vector2(r.position.x + 2.0, r.position.y + 10.0),
					str(idx), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, idx_col)

			var lbl: String = TILE_LABELS[idx] if idx < TILE_LABELS.size() else str(idx)
			draw_string(font,
					Vector2(r.position.x, r.end.y + float(LABEL_H) - 2.0),
					lbl, HORIZONTAL_ALIGNMENT_LEFT, int(r.size.x) + PAD_X, 10,
					COLOR_ACTIVE if is_active else cat_col)


# ===========================================================================
# Inner class: _SheetView - full atlas sheet with cell highlights and click
# ===========================================================================

class _SheetView extends Control:
	signal cell_clicked(cell: Vector2i)

	const TILE_PX: int = 16
	const GUTTER:  int = 1
	const ZOOM:    int = 3

	var texture: Texture2D = null
	var marks: Array = []
	var _hovered: Vector2i = Vector2i(-1, -1)

	func set_sheet(tex: Texture2D) -> void:
		texture = tex
		if texture != null:
			custom_minimum_size = Vector2(
					float(texture.get_width() * ZOOM),
					float(texture.get_height() * ZOOM))
		queue_redraw()

	func set_marks(m: Array) -> void:
		marks = m
		queue_redraw()

	func _cell_at(pos: Vector2) -> Vector2i:
		if texture == null:
			return Vector2i(-1, -1)
		var step: float = float(TILE_PX + GUTTER) * float(ZOOM)
		var col: int = int(floor(pos.x / step))
		var row: int = int(floor(pos.y / step))
		var max_col: int = (texture.get_width()  + GUTTER) / (TILE_PX + GUTTER)
		var max_row: int = (texture.get_height() + GUTTER) / (TILE_PX + GUTTER)
		if col < 0 or col >= max_col or row < 0 or row >= max_row:
			return Vector2i(-1, -1)
		var lx: float = pos.x - float(col) * step
		var ly: float = pos.y - float(row) * step
		if lx >= float(TILE_PX * ZOOM) or ly >= float(TILE_PX * ZOOM):
			return Vector2i(-1, -1)
		return Vector2i(col, row)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var hc: Vector2i = _cell_at(ev.position)
			if hc != _hovered:
				_hovered = hc
				queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var cc: Vector2i = _cell_at(ev.position)
			if cc != Vector2i(-1, -1):
				cell_clicked.emit(cc)

	func _draw() -> void:
		if texture == null:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.12), true)
			return
		draw_texture_rect(texture,
				Rect2(Vector2.ZERO, Vector2(
				float(texture.get_width() * ZOOM),
				float(texture.get_height() * ZOOM))), false)
		var step: float  = float(TILE_PX + GUTTER) * float(ZOOM)
		var vis: float   = float(TILE_PX * ZOOM)
		var max_col: int = (texture.get_width()  + GUTTER) / (TILE_PX + GUTTER)
		var max_row: int = (texture.get_height() + GUTTER) / (TILE_PX + GUTTER)
		var gc := Color(1.0, 1.0, 1.0, 0.07)
		for x in max_col + 1:
			draw_line(Vector2(float(x) * step, 0.0),
					Vector2(float(x) * step, size.y), gc, 1.0)
		for y in max_row + 1:
			draw_line(Vector2(0.0, float(y) * step),
					Vector2(size.x, float(y) * step), gc, 1.0)
		for m in marks:
			var c: Vector2i = m["cell"]
			var p := Vector2(float(c.x) * step, float(c.y) * step)
			draw_rect(Rect2(p, Vector2(vis, vis)),
					m["color"] as Color, false, float(m.get("width", 2.0)))
		if _hovered.x >= 0:
			var p := Vector2(float(_hovered.x) * step, float(_hovered.y) * step)
			draw_rect(Rect2(p, Vector2(vis, vis)), Color(0.95, 0.9, 0.2, 0.9), false, 2.0)
