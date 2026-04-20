## SpritePicker (dev tool)
##
## Standalone scene that lets the developer browse every editable sprite
## mapping in [TileMappings], view the source atlas sheet for the
## currently-selected mapping, click a slot in the right pane to mark it
## active, then click a cell in the sheet to bind that cell to the active
## slot. Save writes back to `res://resources/tilesets/tile_mappings.tres`.
##
## v1 intentionally does NOT support adding/renaming slots — only
## rebinding existing ones — to keep the editor focused on visual cell
## picking. New slots get added in source code, then re-seeded.
##
## The scene is built fully from code so the layout is in one place and
## doesn't fight `.tscn` formatting. Run via:
##   godot res://scenes/tools/SpritePicker.tscn
extends Control

const MAPPINGS_PATH: String = "res://resources/tilesets/tile_mappings.tres"

# Mapping kinds. Each entry drives the tree, decides which sheet to show,
# and tells the right-pane what selection shape to render. Hand-curated
# to match the v1 scope agreed in planning.
#
# Fields:
#   id      : StringName — internal key, also used as TreeItem metadata
#   label   : String     — visible label in the tree
#   sheet   : String     — atlas PNG path
#   field   : StringName — TileMappings field to read/write
#   kind    : StringName — selection layout for the right pane:
#                          "single"      Dictionary[StringName→Vector2i]
#                          "list"        Dictionary[StringName→Array[Vector2i]]
#                          "patch3"      Dictionary[StringName→Array[Vector2i] (9)]
#                          "patch3_flat" Array[Vector2i] (9)
#                          "named"       Dictionary[Variant→Vector2i]
#                          "flat_list"   Array[Vector2i]
#                          "autotile"    Array[Dict{mask,cell,flip}]
const _MAPPINGS: Array = [
	{"id": &"overworld_terrain",                 "label": "Overworld terrain",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"overworld_terrain",                 "kind": &"list"},
	{"id": &"overworld_decoration",              "label": "Overworld decorations",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"overworld_decoration",              "kind": &"list"},
	{"id": &"overworld_terrain_patches_3x3",     "label": "Overworld 3×3 terrain patches",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"overworld_terrain_patches_3x3",     "kind": &"patch3"},
	{"id": &"overworld_water_border_grass_3x3",  "label": "Water-on-grass 3×3 border",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"overworld_water_border_grass_3x3",  "kind": &"patch3_flat"},
	{"id": &"overworld_water_outer_corners",     "label": "Water outer corners (diagonals)",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"overworld_water_outer_corners",     "kind": &"named"},
	{"id": &"city_terrain",                      "label": "City terrain",
	 "sheet": "res://assets/tiles/roguelike/city_sheet.png",
	 "field": &"city_terrain",                      "kind": &"list"},
	{"id": &"dungeon_terrain",                   "label": "Dungeon single-cell terrains",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"dungeon_terrain",                   "kind": &"list"},
	{"id": &"dungeon_wall_autotile",             "label": "Dungeon wall autotile (16-mask)",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"dungeon_wall_autotile",             "kind": &"autotile"},
	{"id": &"dungeon_floor_decor",               "label": "Dungeon floor decor",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"dungeon_floor_decor",               "kind": &"flat_list"},
	{"id": &"dungeon_entrance_pair",             "label": "Dungeon entrance marker pair",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"dungeon_entrance_pair",             "kind": &"flat_list"},
	{"id": &"dungeon_doorframe",                 "label": "Dungeon doorframe (named slots)",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"dungeon_doorframe",                 "kind": &"named"},
	{"id": &"interior_terrain",                  "label": "Interior terrain",
	 "sheet": "res://assets/tiles/roguelike/interior_sheet.png",
	 "field": &"interior_terrain",                  "kind": &"list"},
	{"id": &"weapon_sprites",                    "label": "Weapon / tool sprites",
	 "sheet": "res://assets/characters/roguelike/characters_sheet.png",
	 "field": &"weapon_sprites",                    "kind": &"list"},
	{"id": &"mineable_resources",                "label": "Mineable Resources",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_mineable_json",                    "kind": &"mineable"},
]

# Tile-sheet geometry. Matches WorldConst.TILE_PX (16) and the 1-px
# gutter between tiles used by every Roguelike-pack sheet we ship.
const TILE_PX: int = 16
const TILE_GUTTER: int = 1
const SHEET_ZOOM: int = 3

# Slot mark colours. Every bound cell is outlined dim cyan so the
# developer can see at a glance which cells the current mapping uses.
# The active slot's cell is overlaid bright green.
const COLOR_BOUND: Color  = Color(0.3, 0.8, 1.0, 0.9)
const COLOR_ACTIVE: Color = Color(0.3, 1.0, 0.4, 1.0)
const COLOR_HOVER: Color  = Color(0.95, 0.9, 0.2, 0.9)

var _mappings_resource: TileMappings = null
var _dirty: bool = false
var _mineable_editor: MineableEditor = null  ## Active only for kind=="mineable".

# Currently focused mapping entry (one of _MAPPINGS) and its expanded
# slot list. Each slot is a Dictionary:
#   label : String — display text in the row button
#   path  : Array  — addressing path used by `_get_slot_cell` /
#                    `_set_slot_cell` to read/write the resource
#   flip  : int    — 0/1 for autotile entries, -1 for everything else
#                    (autotile rows render an extra Flip checkbox)
var _current_mapping: Dictionary = {}
var _slots: Array = []
var _active_slot: int = -1

# UI refs.
var _tree: Tree = null
var _sheet_view: SheetView = null
var _slot_root: VBoxContainer = null
var _header_label: Label = null
var _status_label: Label = null
var _save_btn: Button = null
var _revert_btn: Button = null
var _preview: PreviewView = null


# ─── Inner class: SheetView ─────────────────────────────────────────────
#
# Custom Control that draws an atlas sheet, a per-cell grid overlay, all
# bound cells (dim cyan), the active slot's cell (bright green), and the
# hovered cell (yellow). Emits `cell_clicked(cell)` on left-click.
class SheetView extends Control:
	signal cell_clicked(cell: Vector2i)

	var texture: Texture2D = null
	var tile_px: int = 16
	var gutter: int = 1
	var zoom: int = 3
	var hovered: Vector2i = Vector2i(-1, -1)
	# `marks` is an Array of Dictionaries: {cell: Vector2i, color: Color, width: float}.
	var marks: Array = []

	func set_sheet(tex: Texture2D) -> void:
		texture = tex
		_resize_to_texture()
		queue_redraw()

	func set_marks(new_marks: Array) -> void:
		marks = new_marks
		queue_redraw()

	func clear_marks() -> void:
		marks = []
		hovered = Vector2i(-1, -1)
		queue_redraw()

	func _resize_to_texture() -> void:
		if texture == null:
			custom_minimum_size = Vector2.ZERO
			return
		custom_minimum_size = Vector2(
				float(texture.get_width() * zoom),
				float(texture.get_height() * zoom))

	# Local mouse coords → atlas (col, row). Returns Vector2i(-1, -1) for
	# clicks outside the texture or inside the inter-tile gutter.
	func _cell_at(pos: Vector2) -> Vector2i:
		if texture == null:
			return Vector2i(-1, -1)
		var step: float = float(tile_px + gutter) * float(zoom)
		var col: int = int(floor(pos.x / step))
		var row: int = int(floor(pos.y / step))
		var max_col: int = (texture.get_width() + gutter) / (tile_px + gutter)
		var max_row: int = (texture.get_height() + gutter) / (tile_px + gutter)
		if col < 0 or col >= max_col or row < 0 or row >= max_row:
			return Vector2i(-1, -1)
		var cell_x_local: float = pos.x - float(col) * step
		var cell_y_local: float = pos.y - float(row) * step
		var visible_px: float = float(tile_px) * float(zoom)
		if cell_x_local >= visible_px or cell_y_local >= visible_px:
			return Vector2i(-1, -1)
		return Vector2i(col, row)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var hc: Vector2i = _cell_at(ev.position)
			if hc != hovered:
				hovered = hc
				queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var cc: Vector2i = _cell_at(ev.position)
			if cc != Vector2i(-1, -1):
				cell_clicked.emit(cc)

	func _draw() -> void:
		if texture == null:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.12), true)
			return
		var dest := Rect2(Vector2.ZERO,
				Vector2(texture.get_width() * zoom, texture.get_height() * zoom))
		draw_texture_rect(texture, dest, false)
		var step: float = float(tile_px + gutter) * float(zoom)
		var max_col: int = (texture.get_width() + gutter) / (tile_px + gutter)
		var max_row: int = (texture.get_height() + gutter) / (tile_px + gutter)
		var grid_col := Color(1, 1, 1, 0.10)
		for x in range(max_col + 1):
			var px: float = float(x) * step
			draw_line(Vector2(px, 0), Vector2(px, dest.size.y), grid_col, 1.0)
		for y in range(max_row + 1):
			var py: float = float(y) * step
			draw_line(Vector2(0, py), Vector2(dest.size.x, py), grid_col, 1.0)
		for m in marks:
			_draw_cell_outline(m["cell"], m["color"], float(m.get("width", 2.0)))
		if hovered.x >= 0:
			_draw_cell_outline(hovered, Color(0.95, 0.9, 0.2, 0.9), 2.0)

	func _draw_cell_outline(cell: Vector2i, col: Color, w: float) -> void:
		var step: float = float(tile_px + gutter) * float(zoom)
		var visible_px: float = float(tile_px) * float(zoom)
		var p := Vector2(float(cell.x) * step, float(cell.y) * step)
		draw_rect(Rect2(p, Vector2(visible_px, visible_px)), col, false, w)


# ─── Inner class: PreviewView ──────────────────────────────────────────
#
# Renders a small 5×5 (or 3×3, for patch layouts) preview of the cells
# currently bound to the focused mapping, stamping from the same atlas
# the runtime renderer uses. Layouts:
#   "tile"   — fill the grid by cycling through `cells` (great for
#              single-cell terrains, lists, autotile entries).
#   "patch3" — render exactly 9 cells in a 3×3 (NW..SE), centred in the
#              preview frame.
class PreviewView extends Control:
	const FRAME: int = 5
	const PREVIEW_ZOOM: int = 3

	var texture: Texture2D = null
	var tile_px: int = 16
	var gutter: int = 1
	var cells: Array = []
	var layout: StringName = &"tile"

	func _ready() -> void:
		_resize()

	func set_data(tex: Texture2D, new_cells: Array, new_layout: StringName) -> void:
		texture = tex
		cells = new_cells
		layout = new_layout
		_resize()
		queue_redraw()

	func _resize() -> void:
		custom_minimum_size = Vector2(
				float(FRAME * tile_px * PREVIEW_ZOOM),
				float(FRAME * tile_px * PREVIEW_ZOOM))

	func _draw() -> void:
		var bg := Color(0.08, 0.08, 0.10)
		draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), bg, true)
		if texture == null or cells.is_empty():
			return
		var dest_step: float = float(tile_px * PREVIEW_ZOOM)
		var src_step: int = tile_px + gutter
		match layout:
			&"patch3":
				# Centred 3×3 in the 5×5 frame.
				var n: int = mini(cells.size(), 9)
				var offset := Vector2(dest_step, dest_step)
				for i in n:
					var cell: Vector2i = cells[i]
					var gx: int = i % 3
					var gy: int = i / 3
					var dest := Rect2(offset + Vector2(float(gx) * dest_step, float(gy) * dest_step),
							Vector2(dest_step, dest_step))
					var src := Rect2(
							float(cell.x * src_step), float(cell.y * src_step),
							float(tile_px), float(tile_px))
					draw_texture_rect_region(texture, dest, src)
			_:
				# "tile" — fill the FRAME×FRAME grid by cycling cells.
				for y in FRAME:
					for x in FRAME:
						var idx: int = (y * FRAME + x) % cells.size()
						var cell: Vector2i = cells[idx]
						var dest := Rect2(
								Vector2(float(x) * dest_step, float(y) * dest_step),
								Vector2(dest_step, dest_step))
						var src := Rect2(
								float(cell.x * src_step), float(cell.y * src_step),
								float(tile_px), float(tile_px))
						draw_texture_rect_region(texture, dest, src)


# ─── Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	_load_mappings_resource()
	_build_ui()
	_populate_tree()
	_select_mapping(_MAPPINGS[0])


func _load_mappings_resource() -> void:
	if ResourceLoader.exists(MAPPINGS_PATH):
		var r: Resource = load(MAPPINGS_PATH)
		if r is TileMappings:
			# duplicate(true) so edits don't mutate Godot's resource cache
			# until the user explicitly Saves.
			_mappings_resource = r.duplicate(true) as TileMappings
			return
	push_warning("SpritePicker: %s missing or wrong type, using defaults" % MAPPINGS_PATH)
	_mappings_resource = TileMappings.default_mappings()


# ─── UI construction ───────────────────────────────────────────────────

func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	root.add_child(_build_toolbar())

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 280
	root.add_child(split)
	split.add_child(_build_left_pane())

	var inner := HSplitContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.split_offset = -320
	split.add_child(inner)
	inner.add_child(_build_middle_pane())
	inner.add_child(_build_right_pane())

	_status_label = Label.new()
	_status_label.text = "ready"
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	root.add_child(_status_label)


func _build_toolbar() -> Control:
	var hb := HBoxContainer.new()
	var title := Label.new()
	title.text = "SpritePicker"
	title.add_theme_font_size_override("font_size", 18)
	hb.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	_save_btn = Button.new()
	_save_btn.text = "Save"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_save)
	hb.add_child(_save_btn)
	_revert_btn = Button.new()
	_revert_btn.text = "Revert"
	_revert_btn.disabled = true
	_revert_btn.pressed.connect(_revert)
	hb.add_child(_revert_btn)
	var path_lbl := Label.new()
	path_lbl.text = "  " + MAPPINGS_PATH
	path_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	hb.add_child(path_lbl)
	return hb


func _build_left_pane() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_make_section_label("Mappings"))
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.item_selected.connect(_on_tree_item_selected)
	vb.add_child(_tree)
	return vb


func _build_middle_pane() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_make_section_label("Sheet (click a cell to bind to the active slot)"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	_sheet_view = SheetView.new()
	_sheet_view.tile_px = TILE_PX
	_sheet_view.gutter = TILE_GUTTER
	_sheet_view.zoom = SHEET_ZOOM
	_sheet_view.cell_clicked.connect(_on_cell_clicked)
	scroll.add_child(_sheet_view)
	return vb


func _build_right_pane() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_header_label = _make_section_label("Slots")
	vb.add_child(_header_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	_slot_root = VBoxContainer.new()
	_slot_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_slot_root)
	vb.add_child(_make_section_label("Live preview"))
	_preview = PreviewView.new()
	_preview.tile_px = TILE_PX
	_preview.gutter = TILE_GUTTER
	vb.add_child(_preview)
	return vb


func _make_section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	return l


# ─── Tree population ───────────────────────────────────────────────────

func _populate_tree() -> void:
	_tree.clear()
	var root := _tree.create_item()
	for entry in _MAPPINGS:
		var item := _tree.create_item(root)
		item.set_text(0, entry["label"])
		item.set_metadata(0, entry["id"])


func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	var id: StringName = item.get_metadata(0)
	for entry in _MAPPINGS:
		if entry["id"] == id:
			_select_mapping(entry)
			return


# ─── Mapping selection ─────────────────────────────────────────────────

func _select_mapping(entry: Dictionary) -> void:
	_current_mapping = entry
	var kind: StringName = entry["kind"]
	var tex: Texture2D = load(entry["sheet"]) as Texture2D
	if tex == null:
		_status_label.text = "ERROR: sheet not found at %s" % entry["sheet"]
		return
	_sheet_view.set_sheet(tex)

	if kind == &"mineable":
		_show_mineable_editor()
		_refresh_marks()
		_status_label.text = "Editing mineables — %s" % entry["sheet"]
		return

	_hide_mineable_editor()
	_slots = _build_slots(entry)
	_active_slot = 0 if _slots.size() > 0 else -1
	_header_label.text = "Slots — %s (%s)" % [entry["label"], entry["kind"]]
	_rebuild_slot_ui()
	_refresh_marks()
	_status_label.text = entry["sheet"]


# Build the flat slot list for `entry` from the current resource state.
# Each slot's `path` is what `_get_slot_cell`/`_set_slot_cell` use to
# read or write through the resource.
func _build_slots(entry: Dictionary) -> Array:
	var field: StringName = entry["field"]
	var kind: StringName = entry["kind"]
	if kind == &"mineable":
		return []  # Mineable resources use their own editor.
	var value: Variant = _mappings_resource.get(field)
	var out: Array = []

	match kind:
		&"single", &"named":
			# Dictionary[Variant → Vector2i]
			var d: Dictionary = value
			var keys: Array = d.keys()
			keys.sort_custom(func(a, b): return _key_str(a) < _key_str(b))
			for k in keys:
				out.append({
					"label": _key_str(k),
					"path":  [field, k],
					"flip":  -1,
				})
		&"list":
			# Dictionary[StringName → Array[Vector2i]]. One slot per
			# named sub-array; click toggles cells in/out of that array.
			var d: Dictionary = value
			var keys: Array = d.keys()
			keys.sort_custom(func(a, b): return _key_str(a) < _key_str(b))
			for k in keys:
				out.append({
					"label": _key_str(k),
					"path":  [field, k],
					"flip":  -1,
					"is_array": true,
				})
		&"patch3":
			# Dictionary[StringName → Array[Vector2i] (9)]
			var d: Dictionary = value
			var keys: Array = d.keys()
			keys.sort_custom(func(a, b): return _key_str(a) < _key_str(b))
			for k in keys:
				var arr: Array = d[k]
				for i in arr.size():
					out.append({
						"label": "%s[%d] %s" % [_key_str(k), i, _patch3_pos_label(i)],
						"path":  [field, k, i],
						"flip":  -1,
					})
		&"patch3_flat":
			var arr: Array = value
			for i in arr.size():
				out.append({
					"label": "[%d] %s" % [i, _patch3_pos_label(i)],
					"path":  [field, i],
					"flip":  -1,
				})
		&"flat_list":
			# Single Array[Vector2i] for the whole field. One slot;
			# click toggles cells in/out of the array.
			out.append({
				"label": _key_str(field),
				"path":  [field],
				"flip":  -1,
				"is_array": true,
			})
		&"autotile":
			var arr: Array = value
			for i in arr.size():
				var ent: Dictionary = arr[i]
				var mask: int = int(ent.get("mask", 0))
				out.append({
					"label": "mask=%2d  (%s)" % [mask, _autotile_mask_desc(mask)],
					"path":  [field, i, "cell"],
					"flip":  int(ent.get("flip", 0)),
				})
	return out


# Patch 3×3 position labels — match the NW…SE ordering used by both the
# patch helper in world_root.gd and the resource itself.
static func _patch3_pos_label(i: int) -> String:
	const LBL := ["NW", "N", "NE", "W", "C", "E", "SW", "S", "SE"]
	if i >= 0 and i < LBL.size():
		return LBL[i]
	return "?"


# Decode the 4-bit floor-neighbour mask into a compact direction string.
static func _autotile_mask_desc(mask: int) -> String:
	var parts: Array = []
	if mask & 8: parts.append("N")
	if mask & 4: parts.append("S")
	if mask & 2: parts.append("E")
	if mask & 1: parts.append("W")
	return "+".join(parts) if parts.size() > 0 else "—"


# Pretty-print arbitrary keys (StringName, Vector2i, etc.) for slot
# labels and sort-comparison.
static func _key_str(k: Variant) -> String:
	if k is Vector2i:
		return "(%d,%d)" % [k.x, k.y]
	return str(k)


# ─── Slot UI ───────────────────────────────────────────────────────────

func _rebuild_slot_ui() -> void:
	for c in _slot_root.get_children():
		c.queue_free()
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var row := HBoxContainer.new()
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_pressed = (i == _active_slot)
		if slot.get("is_array", false):
			var arr: Variant = _get_at_path(slot["path"])
			var n: int = (arr as Array).size() if arr is Array else 0
			btn.text = "%s   (%d cell%s) — click atlas to add/remove" % [
					slot["label"], n, "" if n == 1 else "s"]
		else:
			btn.text = "%s   →   %s" % [slot["label"], _str_cell(_get_slot_cell(i))]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_slot_pressed.bind(i))
		row.add_child(btn)
		# Autotile rows get an inline Flip checkbox.
		if int(slot["flip"]) >= 0:
			var flip := CheckBox.new()
			flip.text = "flip"
			flip.button_pressed = (int(slot["flip"]) == 1)
			flip.toggled.connect(_on_flip_toggled.bind(i))
			row.add_child(flip)
		_slot_root.add_child(row)


func _on_slot_pressed(idx: int) -> void:
	_active_slot = idx
	_rebuild_slot_ui()
	_refresh_marks()
	if idx >= 0 and idx < _slots.size():
		_status_label.text = "active slot: %s = %s" % [
				_slots[idx]["label"], _str_cell(_get_slot_cell(idx))]


func _on_flip_toggled(pressed: bool, idx: int) -> void:
	if idx < 0 or idx >= _slots.size():
		return
	var slot: Dictionary = _slots[idx]
	if int(slot["flip"]) < 0:
		return
	# Autotile slots store flip on the parent dict entry, addressed by the
	# path's leaf key swap (cell → flip).
	var path: Array = slot["path"].duplicate()
	path[-1] = "flip"
	var new_flip: int = 1 if pressed else 0
	_set_at_path(path, new_flip)
	slot["flip"] = new_flip
	_mark_dirty()
	_status_label.text = "%s flip = %d" % [slot["label"], new_flip]


# ─── Cell click handler ────────────────────────────────────────────────

func _on_cell_clicked(cell: Vector2i) -> void:
	# Route to mineable editor if active.
	if _mineable_editor != null and _mineable_editor.visible:
		_mineable_editor.on_atlas_cell_clicked(cell)
		_refresh_marks()
		_status_label.text = "toggled sprite %s" % _str_cell(cell)
		return
	if _active_slot < 0 or _active_slot >= _slots.size():
		_status_label.text = "no active slot — pick one in the right pane first"
		return
	var slot: Dictionary = _slots[_active_slot]
	if slot.get("is_array", false):
		var arr: Variant = _get_at_path(slot["path"])
		if not (arr is Array):
			_status_label.text = "slot path is not an Array — cannot toggle"
			return
		var typed: Array = arr
		var idx: int = typed.find(cell)
		if idx >= 0:
			typed.remove_at(idx)
			_status_label.text = "removed %s from %s (now %d)" % [
					_str_cell(cell), slot["label"], typed.size()]
		else:
			typed.append(cell)
			_status_label.text = "added %s to %s (now %d)" % [
					_str_cell(cell), slot["label"], typed.size()]
	else:
		_set_slot_cell(_active_slot, cell)
		_status_label.text = "%s = %s" % [slot["label"], _str_cell(cell)]
	_mark_dirty()
	_rebuild_slot_ui()
	_refresh_marks()


# ─── Save / Revert ─────────────────────────────────────────────────────

func _mark_dirty() -> void:
	_dirty = true
	_save_btn.disabled = false
	_revert_btn.disabled = false


func _save() -> void:
	# Save mineable data if the mineable editor is active and dirty.
	if _mineable_editor != null and _mineable_editor.is_dirty():
		_mineable_editor.save()
	var err: int = ResourceSaver.save(_mappings_resource, MAPPINGS_PATH)
	if err != OK:
		_status_label.text = "SAVE FAILED (err %d)" % err
		return
	_dirty = false
	_save_btn.disabled = true
	_revert_btn.disabled = true
	_status_label.text = "saved → %s" % MAPPINGS_PATH


func _revert() -> void:
	# Revert mineable data if the mineable editor exists.
	if _mineable_editor != null:
		_mineable_editor.revert()
	# Force a fresh load — drop the cached resource so subsequent loads
	# pick up the on-disk version (in case it was edited externally).
	if ResourceLoader.has_cached(MAPPINGS_PATH):
		# No public API to evict a single resource cache entry in 4.3, so
		# we just `load()` and trust it; the duplicate(true) below means
		# our working copy is independent regardless.
		pass
	_load_mappings_resource()
	_dirty = false
	_save_btn.disabled = true
	_revert_btn.disabled = true
	if not _current_mapping.is_empty():
		_select_mapping(_current_mapping)
	_status_label.text = "reverted"


# ─── Slot read/write through path ──────────────────────────────────────

func _get_slot_cell(idx: int) -> Vector2i:
	if idx < 0 or idx >= _slots.size():
		return Vector2i(-1, -1)
	var v: Variant = _get_at_path(_slots[idx]["path"])
	if v is Vector2i:
		return v
	return Vector2i(-1, -1)


func _set_slot_cell(idx: int, cell: Vector2i) -> void:
	if idx < 0 or idx >= _slots.size():
		return
	_set_at_path(_slots[idx]["path"], cell)


# Walk `path` against the resource. Path elements: first is the field
# StringName; subsequent elements are dict keys or array indices.
func _get_at_path(path: Array) -> Variant:
	var cur: Variant = _mappings_resource.get(path[0])
	for i in range(1, path.size()):
		var step: Variant = path[i]
		if cur is Dictionary:
			cur = (cur as Dictionary).get(step, null)
		elif cur is Array:
			var idx: int = int(step)
			var arr: Array = cur
			if idx < 0 or idx >= arr.size():
				return null
			cur = arr[idx]
		else:
			return null
		if cur == null:
			return null
	return cur


# Write `value` to the location addressed by `path`. We walk to the
# parent container, then mutate the leaf in place. Containers in Godot
# are reference-typed so this propagates back into the resource.
func _set_at_path(path: Array, value: Variant) -> void:
	var parent: Variant = _mappings_resource.get(path[0])
	for i in range(1, path.size() - 1):
		var step: Variant = path[i]
		if parent is Dictionary:
			parent = (parent as Dictionary)[step]
		elif parent is Array:
			parent = (parent as Array)[int(step)]
	var leaf: Variant = path[-1]
	if parent is Dictionary:
		(parent as Dictionary)[leaf] = value
	elif parent is Array:
		(parent as Array)[int(leaf)] = value


# ─── Mark refresh (sheet overlay) ──────────────────────────────────────

func _refresh_marks() -> void:
	# Use mineable editor marks when in mineable mode.
	if _mineable_editor != null and _mineable_editor.visible:
		_sheet_view.set_marks(_mineable_editor.get_marks())
		return
	var marks: Array = []
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var is_active: bool = (i == _active_slot)
		if slot.get("is_array", false):
			var arr: Variant = _get_at_path(slot["path"])
			if not (arr is Array):
				continue
			for c in arr:
				if not (c is Vector2i):
					continue
				if is_active:
					marks.append({"cell": c, "color": COLOR_ACTIVE, "width": 3.0})
				else:
					marks.append({"cell": c, "color": COLOR_BOUND, "width": 2.0})
		else:
			var c: Vector2i = _get_slot_cell(i)
			if c.x < 0:
				continue
			if is_active:
				marks.append({"cell": c, "color": COLOR_ACTIVE, "width": 3.0})
			else:
				marks.append({"cell": c, "color": COLOR_BOUND, "width": 2.0})
	_sheet_view.set_marks(marks)
	_refresh_preview()


# Build the preview cell list for the focused mapping. For `patch3` we
# render only the active slot's 9-cell group (the one the user is looking
# at); for everything else we cycle through every bound cell.
func _refresh_preview() -> void:
	if _preview == null or _current_mapping.is_empty():
		return
	var tex: Texture2D = load(_current_mapping["sheet"]) as Texture2D
	if tex == null:
		_preview.set_data(null, [], &"tile")
		return
	var kind: StringName = _current_mapping["kind"]
	var cells: Array = []
	var layout: StringName = &"tile"
	match kind:
		&"patch3":
			layout = &"patch3"
			cells = _active_patch3_group_cells()
		&"patch3_flat":
			layout = &"patch3"
			var arr: Array = _mappings_resource.get(_current_mapping["field"])
			cells = arr.duplicate()
		_:
			for i in _slots.size():
				var slot: Dictionary = _slots[i]
				if slot.get("is_array", false):
					var arr: Variant = _get_at_path(slot["path"])
					if arr is Array:
						for cc in arr:
							if cc is Vector2i:
								cells.append(cc)
				else:
					var c: Vector2i = _get_slot_cell(i)
					if c.x >= 0:
						cells.append(c)
	_preview.set_data(tex, cells, layout)


# Pull the 9 cells of the 3×3 group containing the active slot. Returns
# an empty array if there's no active slot or its parent group can't be
# read.
func _active_patch3_group_cells() -> Array:
	if _active_slot < 0 or _active_slot >= _slots.size():
		return []
	var path: Array = _slots[_active_slot]["path"]
	# path is [field, key, idx]; drop idx to get the parent Array[Vector2i].
	if path.size() < 3:
		return []
	var parent_path: Array = path.slice(0, path.size() - 1)
	var parent: Variant = _get_at_path(parent_path)
	if parent is Array:
		return (parent as Array).duplicate()
	return []


# ─── Misc ──────────────────────────────────────────────────────────────

static func _str_cell(c: Vector2i) -> String:
	return "(%d, %d)" % [c.x, c.y]


# ─── Mineable editor integration ──────────────────────────────────────

func _show_mineable_editor() -> void:
	# Hide normal slot UI.
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _mineable_editor == null:
		_mineable_editor = MineableEditor.new()
		_mineable_editor.dirty_changed.connect(_on_mineable_dirty)
		# Insert into the right pane's parent (the ScrollContainer that
		# holds _slot_root).
		_slot_root.get_parent().get_parent().add_child(_mineable_editor)
	_mineable_editor.visible = true


func _hide_mineable_editor() -> void:
	if _mineable_editor != null:
		_mineable_editor.visible = false
	_slot_root.visible = true
	_header_label.visible = true
	if _preview != null:
		_preview.visible = true


func _on_mineable_dirty() -> void:
	_mark_dirty()
	_refresh_marks()
