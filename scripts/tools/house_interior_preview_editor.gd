## HouseInteriorPreviewEditor
##
## Full-pane editor for the Game Editor that renders a procedurally generated
## house interior using the exact same tile-selection logic as
## [WorldRoot._paint_room_walls]. Use this to visually verify that the
## house_wall_*_autotile LUT entries in [TilesetCatalog] produce the correct
## visual result before editing them.
##
## Hover a wall cell → status bar shows atlas coords + mask description.
## Click a wall cell → emits [signal wall_cell_clicked] so the Game Editor can
## navigate to the matching autotile slot for immediate editing.
## Click a corner cell → emits [signal wall_cell_clicked] with mask=0 and
## corner_idx (0-3) so the Game Editor can navigate to the corner slot.
class_name HouseInteriorPreviewEditor
extends VBoxContainer

const DUNGEON_PNG: String = "res://assets/tiles/roguelike/dungeon_sheet.png"
const TILE_PX: int = 16
const TILE_GUTTER: int = 1
const ZOOM: int = 2

## Emitted when the user clicks a clickable wall cell.
## mask 1-15 → LUT entry; mask 0 → corner tile (corner_idx 0-3 identifies which).
## corner_idx is -1 for non-corner (mask > 0) clicks.
signal wall_cell_clicked(mask: int, style: StringName, corner_idx: int)

var _seed_val: int = 12345
var _style: StringName = &"wood"
var _complex: bool = false
var _status: Label = null
var _view: _HouseView = null
var _texture: Texture2D = null


# ── Inner class: _HouseView ──────────────────────────────────────────────────

## Draws an InteriorMap as a flat 2D image from pre-computed atlas assignments.
##
## draw_data entry fields:
##   cell        : Vector2i  — grid position
##   floor_atlas : Vector2i  — floor tile (optional, -1,-1 if absent)
##   wall_atlas  : Vector2i  — wall tile  (optional, -1,-1 if absent)
##   mask        : int       — -1 = floor/door/outer-fill (not clickable)
##                              0 = true corner (clickable, has corner_idx)
##                              1-15 = LUT wall (clickable)
##   corner_idx  : int       — 0-3 for mask=0 corners only
##   is_door     : bool      — optional, highlights door cells
class _HouseView extends Control:
	var texture: Texture2D = null
	var interior: InteriorMap = null
	var draw_data: Array = []
	var tile_px: int = 16
	var gutter: int = 1
	var zoom: int = 2
	var _hovered: Vector2i = Vector2i(-1, -1)

	## corner_idx is -1 for non-corner walls, 0-3 for true corners.
	signal cell_hovered(cell: Vector2i, floor_atlas: Vector2i, wall_atlas: Vector2i, mask: int, corner_idx: int)
	signal wall_clicked(mask: int, corner_idx: int)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func setup(tex: Texture2D, im: InteriorMap, data: Array) -> void:
		texture = tex
		interior = im
		draw_data = data
		_hovered = Vector2i(-1, -1)
		if im != null:
			custom_minimum_size = Vector2(
				float(im.width * tile_px * zoom),
				float(im.height * tile_px * zoom))
		queue_redraw()

	func _cell_at(pos: Vector2) -> Vector2i:
		var dest_step: float = float(tile_px * zoom)
		return Vector2i(int(floor(pos.x / dest_step)), int(floor(pos.y / dest_step)))

	func _data_for(cell: Vector2i) -> Dictionary:
		for d in draw_data:
			if d["cell"] == cell:
				return d
		return {}

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var hc: Vector2i = _cell_at((ev as InputEventMouseMotion).position)
			if hc != _hovered:
				_hovered = hc
				var d: Dictionary = _data_for(hc)
				cell_hovered.emit(hc,
					d.get("floor_atlas", Vector2i(-1, -1)),
					d.get("wall_atlas",  Vector2i(-1, -1)),
					d.get("mask", -1),
					d.get("corner_idx", -1))
				queue_redraw()
		elif ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				var d: Dictionary = _data_for(_cell_at(mb.position))
				var m: int = d.get("mask", -1)
				# Only cells with mask >= 0 are clickable:
				#   mask 1-15 = LUT wall, mask 0 = true corner.
				# mask -1 covers floor, door, AND outer-fill wall cells.
				if m >= 0:
					wall_clicked.emit(m, d.get("corner_idx", -1))
					accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), Color(0.06, 0.06, 0.08), true)
		if texture == null or draw_data.is_empty():
			return
		var dest_step: float = float(tile_px * zoom)
		var src_step: int = tile_px + gutter
		for d in draw_data:
			var cell: Vector2i = d["cell"]
			var dest := Rect2(
				Vector2(float(cell.x) * dest_step, float(cell.y) * dest_step),
				Vector2(dest_step, dest_step))
			var fa: Vector2i = d.get("floor_atlas", Vector2i(-1, -1))
			if fa.x >= 0:
				var src := Rect2(float(fa.x * src_step), float(fa.y * src_step),
					float(tile_px), float(tile_px))
				draw_texture_rect_region(texture, dest, src)
			var wa: Vector2i = d.get("wall_atlas", Vector2i(-1, -1))
			if wa.x >= 0:
				var src := Rect2(float(wa.x * src_step), float(wa.y * src_step),
					float(tile_px), float(tile_px))
				draw_texture_rect_region(texture, dest, src)
			if d.get("is_door", false):
				draw_rect(dest, Color(0.0, 0.8, 0.8, 0.7), false, 2.0)
		if _hovered.x >= 0 and interior != null \
				and _hovered.x < interior.width and _hovered.y < interior.height:
			var dest := Rect2(
				Vector2(float(_hovered.x) * dest_step, float(_hovered.y) * dest_step),
				Vector2(dest_step, dest_step))
			draw_rect(dest, Color(1.0, 0.9, 0.2, 0.9), false, 2.0)


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ts: TileSet = TilesetCatalog.interior()
	var src := ts.get_source(1) as TileSetAtlasSource
	if src != null:
		_texture = src.texture
	if _texture == null:
		_texture = load(DUNGEON_PNG) as Texture2D
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)

	var seed_lbl := Label.new()
	seed_lbl.text = "Seed:"
	toolbar.add_child(seed_lbl)

	var seed_spin := SpinBox.new()
	seed_spin.min_value = 0
	seed_spin.max_value = 999999
	seed_spin.step = 1
	seed_spin.value = _seed_val
	seed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_spin.value_changed.connect(func(v: float) -> void:
		_seed_val = int(v)
		_refresh())
	toolbar.add_child(seed_spin)

	var style_lbl := Label.new()
	style_lbl.text = "  Style:"
	toolbar.add_child(style_lbl)

	var style_opt := OptionButton.new()
	style_opt.add_item("wood", 0)
	style_opt.add_item("stone", 1)
	style_opt.selected = 0
	style_opt.item_selected.connect(func(idx: int) -> void:
		_style = &"wood" if idx == 0 else &"stone"
		_refresh())
	toolbar.add_child(style_opt)

	var complex_chk := CheckBox.new()
	complex_chk.text = "Complex"
	complex_chk.button_pressed = _complex
	complex_chk.toggled.connect(func(v: bool) -> void:
		_complex = v
		_refresh())
	toolbar.add_child(complex_chk)

	var refresh_btn := Button.new()
	refresh_btn.text = "Randomize"
	refresh_btn.pressed.connect(func() -> void:
		_complex = randi() % 10 < 4  # ~40% chance of complex layout
		complex_chk.button_pressed = _complex
		seed_spin.value = randi() % 1000000)
	toolbar.add_child(refresh_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_view = _HouseView.new()
	_view.tile_px = TILE_PX
	_view.gutter = TILE_GUTTER
	_view.zoom = ZOOM
	_view.cell_hovered.connect(_on_cell_hovered)
	_view.wall_clicked.connect(func(m: int, ci: int) -> void:
		wall_cell_clicked.emit(m, _style, ci))
	scroll.add_child(_view)

	_status = Label.new()
	_status.text = "Hover a cell — click a wall or corner to edit it"
	_status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	add_child(_status)


# ── Refresh (call after editing the LUT to see updated rendering) ─────────────

func refresh() -> void:
	_refresh()


func _refresh() -> void:
	var interior: InteriorMap = HouseGenerator.generate(_seed_val, _style, _complex)
	var data: Array = _compute_draw_data(interior, _style)
	if _view != null:
		_view.setup(_texture, interior, data)


# ── Draw-data builder ────────────────────────────────────────────────────────

## Build per-cell draw commands using the same logic as WorldRoot._paint_room_walls.
##
## mask values in output entries:
##   -1 = floor, door, or outer-fill wall (no cardinal OR 2+ diagonal floors)
##    0 = true corner (exactly one diagonal floor); also has "corner_idx" (0-3)
##   1-15 = LUT wall entry
func _compute_draw_data(interior: InteriorMap, sty: StringName) -> Array:
	var wall_lut: Dictionary = (TilesetCatalog.HOUSE_WALL_WOOD_AUTOTILE
			if sty == &"wood" else TilesetCatalog.HOUSE_WALL_STONE_AUTOTILE)
	var floor_pool: Array = (TilesetCatalog.HOUSE_FLOOR_WOOD
			if sty == &"wood" else TilesetCatalog.HOUSE_FLOOR_STONE)
	var corner_cells: Array = TilesetCatalog.house_corner_cells(sty)
	var floor_idx: int = (interior.seed >> 3) % maxi(floor_pool.size(), 1)
	var floor_cell: Vector2i = floor_pool[floor_idx] if not floor_pool.is_empty() \
			else Vector2i(19, 12)
	var drip_row: int = 9 if sty == &"wood" else 4
	var data: Array = []

	for y in interior.height:
		for x in interior.width:
			var cell := Vector2i(x, y)
			var code: int = interior.at(cell)

			if code == TerrainCodes.INTERIOR_DOOR:
				data.append({"cell": cell, "floor_atlas": floor_cell, "mask": -1, "is_door": true})
				continue

			if _is_room_floor(interior, cell):
				data.append({"cell": cell, "floor_atlas": floor_cell, "mask": -1})
				continue

			if code != TerrainCodes.INTERIOR_WALL:
				continue

			var fN: bool = _is_room_floor(interior, cell + Vector2i(0, -1))
			var fS: bool = _is_room_floor(interior, cell + Vector2i(0, 1))
			var fE: bool = _is_room_floor(interior, cell + Vector2i(1, 0))
			var fW: bool = _is_room_floor(interior, cell + Vector2i(-1, 0))
			var fNW: bool = _is_room_floor(interior, cell + Vector2i(-1, -1))
			var fNE: bool = _is_room_floor(interior, cell + Vector2i(1, -1))
			var fSW: bool = _is_room_floor(interior, cell + Vector2i(-1, 1))
			var fSE: bool = _is_room_floor(interior, cell + Vector2i(1, 1))
			var lut_mask: int = (8 if fN else 0) | (4 if fS else 0) | (2 if fE else 0) | (1 if fW else 0)
			var atlas: Vector2i

			if lut_mask == 0:
				var diag_count: int = (1 if fSE else 0) + (1 if fSW else 0) \
						+ (1 if fNE else 0) + (1 if fNW else 0)
				if diag_count == 1:
					# True corner: exactly one diagonal floor. Clickable → corners editor.
					var ci: int
					if fSE:   ci = 0; atlas = corner_cells[0]
					elif fSW: ci = 1; atlas = corner_cells[1]
					elif fNE: ci = 2; atlas = corner_cells[2]
					else:     ci = 3; atlas = corner_cells[3]
					var entry: Dictionary = {"cell": cell, "wall_atlas": atlas,
							"floor_atlas": floor_cell, "mask": 0, "corner_idx": ci}
					data.append(entry)
				else:
					# Outer fill / isolated (0 or 2+ diagonals): not clickable.
					atlas = Vector2i(19, 3 if sty != &"wood" else 8)
					data.append({"cell": cell, "wall_atlas": atlas, "mask": -1})
				continue

			var lut_entry: Variant = wall_lut.get(lut_mask, null)
			if lut_entry == null:
				continue
			atlas = lut_entry as Vector2i
			var lut_atlas: Vector2i = atlas  # stored value before x-override
			if lut_mask == 4 or lut_mask == 5 or lut_mask == 6:
				atlas.x = _nwall_col(fW, fE)
			elif lut_mask == 8 or lut_mask == 9 or lut_mask == 10:
				atlas.x = _nwall_col(fW, fE)

			var entry: Dictionary = {"cell": cell, "wall_atlas": atlas, "mask": lut_mask}
			if atlas.x != lut_atlas.x:
				entry["lut_atlas"] = lut_atlas
			if atlas.y != drip_row:
				entry["floor_atlas"] = floor_cell
			data.append(entry)

	return data


static func _is_room_floor(interior: InteriorMap, cell: Vector2i) -> bool:
	var code: int = interior.at(cell)
	return (code == TerrainCodes.INTERIOR_FLOOR
			or code == TerrainCodes.INTERIOR_DOOR
			or code == TerrainCodes.INTERIOR_STAIRS_UP
			or code == TerrainCodes.INTERIOR_STAIRS_DOWN)


static func _nwall_col(fW: bool, fE: bool) -> int:
	if fW: return 17
	if fE: return 19
	return 18


static func _mask_desc(mask: int) -> String:
	var parts: Array[String] = []
	if mask & 8: parts.append("N")
	if mask & 4: parts.append("S")
	if mask & 2: parts.append("E")
	if mask & 1: parts.append("W")
	return "+".join(parts)


const _CORNER_DESC: Array = [
	"NW-cap (SE floor)", "NE-cap (SW floor)",
	"SW-cap (NE floor)", "SE-cap (NW floor)",
]


# ── Callbacks ────────────────────────────────────────────────────────────────

const _X_OVERRIDE_MASKS: Array = [4, 5, 6, 8, 9, 10]


func _on_cell_hovered(cell: Vector2i, floor_atlas: Vector2i, wall_atlas: Vector2i,
		mask: int, corner_idx: int) -> void:
	var parts: Array[String] = ["cell (%d,%d)" % [cell.x, cell.y]]
	if wall_atlas.x >= 0:
		parts.append("wall (%d,%d)" % [wall_atlas.x, wall_atlas.y])
		if mask in _X_OVERRIDE_MASKS:
			var fW_h: bool = (mask & 1) != 0
			var fE_h: bool = (mask & 2) != 0
			if fW_h:
				parts.append("[col 17 — W-floor drives x]")
			elif fE_h:
				parts.append("[col 19 — E-floor drives x]")
			else:
				parts.append("[col 18 — center, no E/W floor]")
			var d: Dictionary = _view._data_for(cell)
			var lut_atlas: Vector2i = d.get("lut_atlas", Vector2i(-1, -1))
			if lut_atlas.x >= 0:
				parts.append("LUT stores (%d,%d) — x ignored" % [lut_atlas.x, lut_atlas.y])
		if mask == 0 and corner_idx >= 0:
			parts.append("corner %s" % _CORNER_DESC[corner_idx])
			parts.append("← click to edit")
		elif mask > 0:
			parts.append("mask %d (%s)" % [mask, _mask_desc(mask)])
			parts.append("← click to edit y")
		# mask -1 with wall_atlas = outer fill: show coords only, no click hint
	elif floor_atlas.x >= 0:
		parts.append("floor (%d,%d)" % [floor_atlas.x, floor_atlas.y])
	_status.text = "  ".join(parts)
