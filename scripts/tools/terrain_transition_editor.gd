## TerrainTransitionEditor
##
## Sub-editor for reviewing and editing the terrain transition tile sheet.
## Lives inside GameEditor — activated when "Terrain Transitions" is selected
## in the left tree.
##
## Layout
## ------
## Top bar:  [Primary ▼]  [Secondary ▼]  status label
## Body:     Scrollable preview showing a ~17x17 synthetic landscape map
##           composed entirely from the 13-tile bitmask system.  Every
##           visible tile cell is clickable; clicking highlights the
##           corresponding atlas slot in the tile sheet and shows its
##           index/name in the status label.
##
## The preview map is a pre-baked binary grid that exercises every tile
## index (0-12), including inner corners.  All drawing happens in
## _draw() using draw_texture_rect_region() from the transitions sheet.
class_name TerrainTransitionEditor
extends VBoxContainer

# Terrain pair definitions — must match PAIRS order in gen_terrain_transitions.py
# and TERRAIN_TRANSITION_ROWS in tileset_catalog.gd.
const PAIRS: Dictionary = {
	"grass_dirt":  {"primary": "grass",  "secondary": "dirt",  "row": 0},
	"sand_dirt":   {"primary": "sand",   "secondary": "dirt",  "row": 1},
	"stone_dirt":  {"primary": "stone",  "secondary": "dirt",  "row": 2},
	"grass_stone": {"primary": "grass",  "secondary": "stone", "row": 3},
	"clay_water":  {"primary": "clay",   "secondary": "water", "row": 4},
	"grass_sand":  {"primary": "grass",  "secondary": "sand",  "row": 5},
}

const TILE_NAMES: Array = [
	"nw_outer", "n_edge",  "ne_outer",
	"w_edge",   "center",  "e_edge",
	"sw_outer", "s_edge",  "se_outer",
	"inner_nw", "inner_ne","inner_sw", "inner_se",
]

# Tile geometry (must match terrain_transitions_sheet.png + overworld_sheet.png)
const TILE_PX: int = 16
const GUTTER:  int = 1
const STRIDE:  int = TILE_PX + GUTTER  # 17

# Preview scale factor.
const ZOOM: int = 4

# Synthetic preview map.  Each cell is one of:
#   -1  = "outside" (not painted, dark bg)
#    0  = primary terrain (plain)
#    1  = secondary terrain (use bitmask)
#
# Designed to hit every index 0-12.  17 cols × 15 rows.
# Inner corners (9-12) appear at the concave bends of the secondary blob.
const MAP_W: int = 17
const MAP_H: int = 15

# fmt: off
const _MAP: Array = [
	# 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16
	[  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],  # row 0
	[  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],  # row 1
	[  0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0 ],  # row 2
	[  0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0 ],  # row 3
	[  0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0 ],  # row 4 — inner corners at (8,4) and (9,4)
	[  0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0 ],  # row 5
	[  0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0 ],  # row 6 — inner corners at (2,6)
	[  0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0 ],  # row 7
	[  0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0 ],  # row 8 — hole at (6-7)
	[  0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0 ],  # row 9
	[  0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0 ],  # row 10
	[  0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0 ],  # row 11
	[  0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 ],  # row 12
	[  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],  # row 13
	[  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],  # row 14
]
# fmt: on

# Signals a dirty state when the tile sheet is modified externally (none here,
# read-only viewer for now).
signal dirty_changed

var _texture: Texture2D = null
var _selected_pair_key: String = "grass_dirt"
var _highlighted_tile_index: int = -1   # 0-12, -1 = none

# UI refs
var _primary_opt: OptionButton = null
var _secondary_opt: OptionButton = null
var _status_lbl: Label = null
var _preview: _PreviewControl = null


func _ready() -> void:
	_build_ui()
	_reload_texture()
	_update_preview()


# ─── UI Construction ──────────────────────────────────────────────────

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Top bar: pair selectors + info.
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 32)
	add_child(bar)

	var pri_lbl := Label.new()
	pri_lbl.text = "Primary:"
	bar.add_child(pri_lbl)

	_primary_opt = OptionButton.new()
	_primary_opt.custom_minimum_size = Vector2(120, 0)
	bar.add_child(_primary_opt)

	var sec_lbl := Label.new()
	sec_lbl.text = "  Secondary:"
	bar.add_child(sec_lbl)

	_secondary_opt = OptionButton.new()
	_secondary_opt.custom_minimum_size = Vector2(120, 0)
	bar.add_child(_secondary_opt)

	_status_lbl = Label.new()
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_lbl.text = ""
	bar.add_child(_status_lbl)

	# Tile-name legend bar.
	var legend := HBoxContainer.new()
	add_child(legend)
	var leg_lbl := Label.new()
	leg_lbl.text = "Tiles: "
	leg_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	legend.add_child(leg_lbl)
	for i in TILE_NAMES.size():
		var nl := Label.new()
		var color: Color = Color(1.0, 0.82, 0.2) if i >= 9 else Color(0.6, 0.9, 1.0)
		nl.add_theme_color_override("font_color", color)
		nl.text = "[%d]%s  " % [i, TILE_NAMES[i]]
		nl.add_theme_font_size_override("font_size", 9)
		legend.add_child(nl)

	# Split: left = pair list, right = preview.
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 160
	add_child(split)

	# Left: pair list.
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size = Vector2(155, 0)
	split.add_child(left_scroll)

	var pair_list := VBoxContainer.new()
	pair_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(pair_list)

	# Populate dropdowns and pair list from PAIRS const.
	var primaries: Array = []
	var secondaries: Array = []
	for key in PAIRS.keys():
		var p: Dictionary = PAIRS[key]
		if p["primary"] not in primaries:
			primaries.append(p["primary"])
		if p["secondary"] not in secondaries:
			secondaries.append(p["secondary"])
	for prim in primaries:
		_primary_opt.add_item(prim)
	for sec in secondaries:
		_secondary_opt.add_item(sec)
	_primary_opt.selected = 0
	_secondary_opt.selected = 0

	_primary_opt.item_selected.connect(func(_i): _on_pair_changed())
	_secondary_opt.item_selected.connect(func(_i): _on_pair_changed())

	# One button per pair in the pair list.
	for key in PAIRS.keys():
		var p: Dictionary = PAIRS[key]
		var btn := Button.new()
		btn.text = "%s → %s" % [p["primary"], p["secondary"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_select_pair.bind(key))
		pair_list.add_child(btn)

	# Tile index strip (13 buttons, one per tile).
	var idx_scroll := ScrollContainer.new()
	idx_scroll.custom_minimum_size = Vector2(155, 28)
	idx_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pair_list.add_child(idx_scroll)
	var idx_row := HBoxContainer.new()
	idx_scroll.add_child(idx_row)
	for i in TILE_NAMES.size():
		var tb := Button.new()
		tb.text = str(i)
		tb.custom_minimum_size = Vector2(22, 22)
		tb.add_theme_font_size_override("font_size", 10)
		var color: Color = Color(1.0, 0.82, 0.2) if i >= 9 else Color(0.3, 0.85, 1.0)
		tb.add_theme_color_override("font_color", color)
		tb.pressed.connect(_highlight_tile_index.bind(i))
		idx_row.add_child(tb)

	# Right: scrollable preview.
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)

	_preview = _PreviewControl.new()
	_preview.tile_index_selected.connect(_on_tile_clicked)
	right_scroll.add_child(_preview)


# ─── Data / logic ─────────────────────────────────────────────────────

func _reload_texture() -> void:
	var path: String = "res://assets/tiles/roguelike/terrain_transitions_sheet.png"
	_texture = load(path) as Texture2D
	if _texture == null:
		_status_lbl.text = "ERROR: transitions sheet not found at %s" % path


func _on_pair_changed() -> void:
	var prim: String = _primary_opt.get_item_text(_primary_opt.selected)
	var sec: String  = _secondary_opt.get_item_text(_secondary_opt.selected)
	var found_key: String = ""
	for key in PAIRS.keys():
		var p: Dictionary = PAIRS[key]
		if p["primary"] == prim and p["secondary"] == sec:
			found_key = key
			break
	if found_key.is_empty():
		_status_lbl.text = "No tile pair defined for %s + %s" % [prim, sec]
		return
	_select_pair(found_key)


func _select_pair(key: String) -> void:
	_selected_pair_key = key
	var p: Dictionary = PAIRS[key]
	# Sync dropdowns.
	for i in _primary_opt.item_count:
		if _primary_opt.get_item_text(i) == p["primary"]:
			_primary_opt.selected = i
	for i in _secondary_opt.item_count:
		if _secondary_opt.get_item_text(i) == p["secondary"]:
			_secondary_opt.selected = i
	_highlighted_tile_index = -1
	_status_lbl.text = "Pair: %s  (sheet row %d)" % [key, p["row"]]
	_update_preview()


func _highlight_tile_index(idx: int) -> void:
	_highlighted_tile_index = idx
	var name: String = TILE_NAMES[idx] if idx < TILE_NAMES.size() else "?"
	var star: String = " ★ (needs art)" if idx >= 9 else ""
	_status_lbl.text = "Tile %d: %s%s" % [idx, name, star]
	_update_preview()


func _on_tile_clicked(idx: int) -> void:
	_highlight_tile_index(idx)


func _update_preview() -> void:
	if _preview == null:
		return
	var p: Dictionary = PAIRS.get(_selected_pair_key, {})
	if p.is_empty():
		return
	_preview.setup(_texture, p["row"], _highlighted_tile_index)


# ─── Inner class: map preview ─────────────────────────────────────────

class _PreviewControl extends Control:
	signal tile_index_selected(index: int)

	var _texture: Texture2D = null
	var _sheet_row: int = 0
	var _highlighted: int = -1

	# Per-cell tile index cache, rebuilt in setup().
	var _cell_index: Array = []   # flat MAP_W × MAP_H array of int (0-12 or -1)

	func setup(tex: Texture2D, sheet_row: int, highlighted: int) -> void:
		_texture = tex
		_sheet_row = sheet_row
		_highlighted = highlighted
		_bake_indices()
		custom_minimum_size = Vector2(
				float(MAP_W * STRIDE * ZOOM),
				float(MAP_H * STRIDE * ZOOM))
		queue_redraw()

	func _bake_indices() -> void:
		_cell_index.resize(MAP_W * MAP_H)
		for cy in MAP_H:
			for cx in MAP_W:
				if _MAP[cy][cx] != 1:
					_cell_index[cy * MAP_W + cx] = -1
					continue
				_cell_index[cy * MAP_W + cx] = _compute_index(cx, cy)

	# Compute the 13-tile bitmask index for a secondary cell at (cx, cy).
	func _compute_index(cx: int, cy: int) -> int:
		var n: bool = cy > 0 and _MAP[cy - 1][cx] == 1
		var s: bool = cy < MAP_H - 1 and _MAP[cy + 1][cx] == 1
		var w: bool = cx > 0 and _MAP[cy][cx - 1] == 1
		var e: bool = cx < MAP_W - 1 and _MAP[cy][cx + 1] == 1
		if not n and not w: return 0  # nw_outer
		if not n and not e: return 2  # ne_outer
		if not s and not w: return 6  # sw_outer
		if not s and not e: return 8  # se_outer
		if not n: return 1  # n_edge
		if not s: return 7  # s_edge
		if not w: return 3  # w_edge
		if not e: return 5  # e_edge
		# All cardinals are secondary — check diagonals for inner corners.
		var nw_p: bool = cx == 0 or cy == 0 or _MAP[cy - 1][cx - 1] != 1
		var ne_p: bool = cx == MAP_W - 1 or cy == 0 or _MAP[cy - 1][cx + 1] != 1
		var sw_p: bool = cx == 0 or cy == MAP_H - 1 or _MAP[cy + 1][cx - 1] != 1
		var se_p: bool = cx == MAP_W - 1 or cy == MAP_H - 1 or _MAP[cy + 1][cx + 1] != 1
		var cnt: int = int(nw_p) + int(ne_p) + int(sw_p) + int(se_p)
		if cnt == 1:
			if nw_p: return 9
			if ne_p: return 10
			if sw_p: return 11
			if se_p: return 12
		return 4  # center

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var cell := _cell_at(ev.position)
			if cell.x >= 0:
				var idx: int = _cell_index[cell.y * MAP_W + cell.x]
				if idx >= 0:
					tile_index_selected.emit(idx)

	func _cell_at(pos: Vector2) -> Vector2i:
		var step: float = float(STRIDE * ZOOM)
		var cx: int = int(floor(pos.x / step))
		var cy: int = int(floor(pos.y / step))
		if cx < 0 or cx >= MAP_W or cy < 0 or cy >= MAP_H:
			return Vector2i(-1, -1)
		return Vector2i(cx, cy)

	func _draw() -> void:
		var bg_dark := Color(0.1, 0.1, 0.12)
		var step: float = float(STRIDE * ZOOM)
		var tile_draw: float = float(TILE_PX * ZOOM)

		# Tile source region size on the sheet.
		var src_step: int = STRIDE  # = TILE_PX + GUTTER = 17

		for cy in MAP_H:
			for cx in MAP_W:
				var dest := Rect2(
						Vector2(float(cx) * step, float(cy) * step),
						Vector2(tile_draw, tile_draw))

				var map_val: int = _MAP[cy][cx]
				if map_val == -1:
					draw_rect(dest, bg_dark, true)
					continue

				if map_val == 0:
					# Primary terrain: draw plain gray background color.
					draw_rect(dest, Color(0.25, 0.35, 0.18), true)
					continue

				# Secondary terrain (map_val == 1).
				var tile_idx: int = _cell_index[cy * MAP_W + cx]
				if _texture == null or tile_idx < 0:
					draw_rect(dest, Color(0.4, 0.25, 0.15), true)
					continue

				var src_x: int = tile_idx * src_step
				var src_y: int = _sheet_row * src_step
				var src := Rect2(float(src_x), float(src_y), float(TILE_PX), float(TILE_PX))
				draw_texture_rect_region(_texture, dest, src)

				# Highlight: bright outline for the selected tile index.
				if tile_idx == _highlighted:
					draw_rect(dest, Color(1.0, 0.85, 0.1, 0.9), false, 2.0)

		# Draw a thin grid so individual tile boundaries are clear.
		var grid_col := Color(1, 1, 1, 0.07)
		for cx in MAP_W + 1:
			draw_line(Vector2(float(cx) * step, 0),
					Vector2(float(cx) * step, float(MAP_H) * step), grid_col, 1.0)
		for cy in MAP_H + 1:
			draw_line(Vector2(0, float(cy) * step),
					Vector2(float(MAP_W) * step, float(cy) * step), grid_col, 1.0)

		# Index labels on each secondary cell.
		for cy in MAP_H:
			for cx in MAP_W:
				if _MAP[cy][cx] != 1:
					continue
				var idx: int = _cell_index[cy * MAP_W + cx]
				if idx < 0:
					continue
				var lx: float = float(cx) * step + 2.0
				var ly: float = float(cy) * step + 1.0
				var col: Color = Color(1.0, 0.85, 0.15) if idx >= 9 else Color(1, 1, 1, 0.75)
				draw_string(ThemeDB.fallback_font, Vector2(lx, ly + 10), str(idx),
						HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)
