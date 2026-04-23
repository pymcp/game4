## EncounterEditor
##
## Sub-editor panel for the Game Editor that creates and edits encounter
## templates stored in `resources/encounters/*.json`.
##
## Left pane: encounter list with Add / Delete buttons.
## Right pane: tabbed — Canvas (NxM tile grid) and Properties
## (id, size, biomes, placement rules).
##
## Click a cell on the canvas to select it. A Cell Editor panel appears
## below showing the terrain, decoration, and entity at that cell, with
## dropdowns to change or clear them.
class_name EncounterEditor
extends VBoxContainer

signal dirty_changed

const CELL_DRAW_SIZE := 32  ## Pixel size of each cell in the canvas grid.

const _TERRAIN_CODES: Dictionary = {
	-1: {"label": "Keep (unchanged)", "color": Color(0.2, 0.2, 0.2)},
	0:  {"label": "Ocean", "color": Color(0.1, 0.2, 0.5)},
	1:  {"label": "Water", "color": Color(0.2, 0.4, 0.7)},
	2:  {"label": "Sand", "color": Color(0.85, 0.8, 0.55)},
	3:  {"label": "Grass", "color": Color(0.3, 0.65, 0.25)},
	4:  {"label": "Dirt", "color": Color(0.55, 0.4, 0.25)},
	5:  {"label": "Rock", "color": Color(0.5, 0.5, 0.5)},
	6:  {"label": "Snow", "color": Color(0.9, 0.92, 0.95)},
	7:  {"label": "Swamp", "color": Color(0.35, 0.5, 0.3)},
}

## Sorted terrain code keys for dropdown indexing.
var _terrain_keys: Array = []

const _BIOME_IDS: Array = ["grass", "desert", "snow", "swamp", "rocky"]

const _DECORATION_KINDS: Array = ["(none)", "tree", "bush", "rock", "flower",
	"lilypad", "iron_vein", "copper_vein"]

const _ENTITY_KINDS: Array = ["(none)", "slime", "skeleton", "goblin", "bat",
	"wolf", "ogre", "fire_elemental", "ice_elemental"]

var sheet_path: String = ""

var _encounters: Dictionary = {}  ## id -> encounter dict (working copy).
var _selected_id: String = ""
var _dirty: bool = false
var _selected_cell: Vector2i = Vector2i(-1, -1)

# UI refs — list.
var _enc_list: ItemList = null
var _add_btn: Button = null
var _del_btn: Button = null

# UI refs — tabs.
var _tab_bar: TabBar = null

# UI refs — canvas tab.
var _canvas_panel: VBoxContainer = null
var _canvas_scroll: ScrollContainer = null
var _canvas: _EncounterCanvas = null
var _cell_editor: PanelContainer = null
var _cell_label: Label = null
var _cell_terrain_option: OptionButton = null
var _cell_deco_option: OptionButton = null
var _cell_deco_variant_spin: SpinBox = null
var _cell_entity_option: OptionButton = null

# UI refs — properties tab.
var _props_scroll: ScrollContainer = null
var _id_edit: LineEdit = null
var _width_spin: SpinBox = null
var _height_spin: SpinBox = null
var _biome_checks: Dictionary = {}  ## biome_id -> CheckBox
var _dist_center_spin: SpinBox = null
var _dist_between_spin: SpinBox = null
var _max_per_region_spin: SpinBox = null
var _weight_spin: SpinBox = null


func _ready() -> void:
	_terrain_keys = _TERRAIN_CODES.keys()
	_terrain_keys.sort()
	_load_data()
	_build_ui()
	_populate_list()
	if _enc_list.item_count > 0:
		_enc_list.select(0)
		_on_encounter_selected(0)


func _load_data() -> void:
	_encounters.clear()
	EncounterRegistry.reset()
	for id in EncounterRegistry.all_ids():
		_encounters[id] = EncounterRegistry.get_encounter(StringName(id)).duplicate(true)


# ─── Public API (sub-editor contract) ─────────────────────────────────

func get_marks() -> Array:
	return []


func save() -> void:
	for id in _encounters:
		EncounterRegistry.save_encounter(_encounters[id])
	# Delete encounters removed from our working set.
	for id in EncounterRegistry.all_ids():
		if not _encounters.has(String(id)):
			EncounterRegistry.delete_encounter(StringName(id))
	_dirty = false
	dirty_changed.emit()


func revert() -> void:
	_load_data()
	_populate_list()
	if _enc_list.item_count > 0:
		_enc_list.select(0)
		_on_encounter_selected(0)
	else:
		_selected_id = ""
		_selected_cell = Vector2i(-1, -1)
		_clear_canvas()
		_clear_props()
	_dirty = false
	dirty_changed.emit()


func is_dirty() -> bool:
	return _dirty


func on_atlas_cell_clicked(_cell: Vector2i) -> void:
	pass


# ─── Internal helpers ──────────────────────────────────────────────────

func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		dirty_changed.emit()


func _current_encounter() -> Dictionary:
	if _selected_id == "":
		return {}
	return _encounters.get(_selected_id, {})


# ─── UI construction ──────────────────────────────────────────────────

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Tab bar: Canvas | Properties
	_tab_bar = TabBar.new()
	_tab_bar.add_tab("Canvas")
	_tab_bar.add_tab("Properties")
	_tab_bar.tab_changed.connect(_on_tab_changed)
	add_child(_tab_bar)

	# Main split.
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 160
	add_child(split)

	# Left: encounter list + buttons.
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size.x = 140
	split.add_child(left)

	_enc_list = ItemList.new()
	_enc_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enc_list.item_selected.connect(_on_encounter_selected)
	left.add_child(_enc_list)

	var btn_row := HBoxContainer.new()
	left.add_child(btn_row)
	_add_btn = Button.new()
	_add_btn.text = "Add"
	_add_btn.pressed.connect(_on_add_pressed)
	btn_row.add_child(_add_btn)
	_del_btn = Button.new()
	_del_btn.text = "Delete"
	_del_btn.pressed.connect(_on_del_pressed)
	btn_row.add_child(_del_btn)

	# Right: stacked canvas panel + properties panel.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right)

	# ── Canvas tab content ──
	_canvas_panel = VBoxContainer.new()
	_canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_canvas_panel)

	_canvas_scroll = ScrollContainer.new()
	_canvas_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_canvas_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_canvas_panel.add_child(_canvas_scroll)

	_canvas = _EncounterCanvas.new()
	_canvas.cell_selected.connect(_on_canvas_cell_selected)
	_canvas_scroll.add_child(_canvas)

	_build_cell_editor()

	# ── Properties tab content ──
	_props_scroll = ScrollContainer.new()
	_props_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_props_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_props_scroll.visible = false
	right.add_child(_props_scroll)

	_build_properties_panel()


func _build_cell_editor() -> void:
	_cell_editor = PanelContainer.new()
	_cell_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cell_editor.custom_minimum_size.y = 90
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.border_color = Color(0.35, 0.35, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	_cell_editor.add_theme_stylebox_override("panel", style)
	_canvas_panel.add_child(_cell_editor)

	var vbox := VBoxContainer.new()
	_cell_editor.add_child(vbox)

	_cell_label = Label.new()
	_cell_label.text = "Click a cell to edit it"
	vbox.add_child(_cell_label)

	var grid := GridContainer.new()
	grid.columns = 2
	vbox.add_child(grid)

	# Terrain.
	grid.add_child(_make_label("Terrain:"))
	_cell_terrain_option = OptionButton.new()
	for code in _terrain_keys:
		_cell_terrain_option.add_item(_TERRAIN_CODES[code]["label"])
	_cell_terrain_option.item_selected.connect(_on_cell_terrain_changed)
	grid.add_child(_cell_terrain_option)

	# Decoration.
	grid.add_child(_make_label("Decoration:"))
	var deco_row := HBoxContainer.new()
	grid.add_child(deco_row)
	_cell_deco_option = OptionButton.new()
	_cell_deco_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for kind in _DECORATION_KINDS:
		_cell_deco_option.add_item(kind)
	_cell_deco_option.item_selected.connect(_on_cell_deco_changed)
	deco_row.add_child(_cell_deco_option)
	_cell_deco_variant_spin = SpinBox.new()
	_cell_deco_variant_spin.min_value = 0
	_cell_deco_variant_spin.max_value = 10
	_cell_deco_variant_spin.prefix = "v"
	_cell_deco_variant_spin.tooltip_text = "Variant index"
	_cell_deco_variant_spin.value_changed.connect(_on_cell_deco_variant_changed)
	deco_row.add_child(_cell_deco_variant_spin)

	# Entity.
	grid.add_child(_make_label("Entity:"))
	_cell_entity_option = OptionButton.new()
	for kind in _ENTITY_KINDS:
		_cell_entity_option.add_item(kind)
	_cell_entity_option.item_selected.connect(_on_cell_entity_changed)
	grid.add_child(_cell_entity_option)

	_update_cell_editor()


func _build_properties_panel() -> void:
	var props := VBoxContainer.new()
	props.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_props_scroll.add_child(props)

	# ID field.
	props.add_child(_make_label("Encounter ID:"))
	_id_edit = LineEdit.new()
	_id_edit.text_changed.connect(_on_id_changed)
	props.add_child(_id_edit)

	# Size fields.
	props.add_child(HSeparator.new())
	props.add_child(_make_label("Grid Size:"))
	var size_row := HBoxContainer.new()
	props.add_child(size_row)
	size_row.add_child(_make_label("Width:"))
	_width_spin = SpinBox.new()
	_width_spin.min_value = 1
	_width_spin.max_value = 32
	_width_spin.value = 5
	_width_spin.value_changed.connect(_on_size_changed)
	size_row.add_child(_width_spin)
	size_row.add_child(_make_label("Height:"))
	_height_spin = SpinBox.new()
	_height_spin.min_value = 1
	_height_spin.max_value = 32
	_height_spin.value = 5
	_height_spin.value_changed.connect(_on_size_changed)
	size_row.add_child(_height_spin)

	# Biome checkboxes.
	props.add_child(HSeparator.new())
	props.add_child(_make_label("Biomes (where this encounter can appear):"))
	var biome_row := HFlowContainer.new()
	props.add_child(biome_row)
	for b in _BIOME_IDS:
		var cb := CheckBox.new()
		cb.text = b
		cb.toggled.connect(func(_on: bool) -> void: _sync_biomes_to_data())
		biome_row.add_child(cb)
		_biome_checks[b] = cb

	# Placement rules.
	props.add_child(HSeparator.new())
	props.add_child(_make_label("Placement Rules:"))
	var rules := GridContainer.new()
	rules.columns = 2
	props.add_child(rules)

	rules.add_child(_make_label("Min dist from center:"))
	_dist_center_spin = SpinBox.new()
	_dist_center_spin.min_value = 0
	_dist_center_spin.max_value = 128
	_dist_center_spin.value = 20
	_dist_center_spin.value_changed.connect(func(_v: float) -> void: _sync_placement_to_data())
	rules.add_child(_dist_center_spin)

	rules.add_child(_make_label("Min dist between encounters:"))
	_dist_between_spin = SpinBox.new()
	_dist_between_spin.min_value = 0
	_dist_between_spin.max_value = 128
	_dist_between_spin.value = 24
	_dist_between_spin.value_changed.connect(func(_v: float) -> void: _sync_placement_to_data())
	rules.add_child(_dist_between_spin)

	rules.add_child(_make_label("Max per region:"))
	_max_per_region_spin = SpinBox.new()
	_max_per_region_spin.min_value = 0
	_max_per_region_spin.max_value = 20
	_max_per_region_spin.value = 1
	_max_per_region_spin.value_changed.connect(func(_v: float) -> void: _sync_placement_to_data())
	rules.add_child(_max_per_region_spin)

	rules.add_child(_make_label("Weight (higher = more likely):"))
	_weight_spin = SpinBox.new()
	_weight_spin.min_value = 1
	_weight_spin.max_value = 100
	_weight_spin.value = 10
	_weight_spin.value_changed.connect(func(_v: float) -> void: _sync_placement_to_data())
	rules.add_child(_weight_spin)


func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


# ─── List management ──────────────────────────────────────────────────

func _populate_list() -> void:
	_enc_list.clear()
	var ids: Array = _encounters.keys()
	ids.sort()
	for id in ids:
		_enc_list.add_item(id)


func _on_encounter_selected(idx: int) -> void:
	_selected_id = _enc_list.get_item_text(idx)
	_selected_cell = Vector2i(-1, -1)
	_load_encounter_into_ui()


func _on_add_pressed() -> void:
	var base := "new_encounter"
	var id := base
	var n := 1
	while _encounters.has(id):
		id = "%s_%d" % [base, n]
		n += 1
	var enc: Dictionary = {
		"id": id,
		"size": [5, 5],
		"tiles": _make_empty_tiles(5, 5),
		"decorations": [],
		"entities": [],
		"placement": {
			"biomes": ["grass"],
			"min_distance_from_center": 20,
			"min_distance_between": 24,
			"max_per_region": 1,
			"weight": 10,
		},
	}
	_encounters[id] = enc
	_populate_list()
	for i in _enc_list.item_count:
		if _enc_list.get_item_text(i) == id:
			_enc_list.select(i)
			_on_encounter_selected(i)
			break
	_mark_dirty()


func _on_del_pressed() -> void:
	if _selected_id == "":
		return
	_encounters.erase(_selected_id)
	_selected_id = ""
	_selected_cell = Vector2i(-1, -1)
	_populate_list()
	_clear_canvas()
	_clear_props()
	if _enc_list.item_count > 0:
		_enc_list.select(0)
		_on_encounter_selected(0)
	_mark_dirty()


func _make_empty_tiles(w: int, h: int) -> Array:
	var tiles: Array = []
	for _y in h:
		var row: Array = []
		for _x in w:
			row.append(-1)
		tiles.append(row)
	return tiles


# ─── Load encounter into UI ───────────────────────────────────────────

func _load_encounter_into_ui() -> void:
	var enc := _current_encounter()
	if enc.is_empty():
		_clear_canvas()
		_clear_props()
		return

	# Properties.
	_id_edit.text = enc.get("id", "")
	var sz: Array = enc.get("size", [5, 5])
	_width_spin.set_value_no_signal(sz[0])
	_height_spin.set_value_no_signal(sz[1])

	var placement: Dictionary = enc.get("placement", {})
	var biomes: Array = placement.get("biomes", [])
	for b in _BIOME_IDS:
		_biome_checks[b].set_pressed_no_signal(b in biomes)
	_dist_center_spin.set_value_no_signal(placement.get("min_distance_from_center", 20))
	_dist_between_spin.set_value_no_signal(placement.get("min_distance_between", 24))
	_max_per_region_spin.set_value_no_signal(placement.get("max_per_region", 1))
	_weight_spin.set_value_no_signal(placement.get("weight", 10))

	# Canvas.
	_canvas.load_encounter(enc)
	_canvas.set_selected_cell(_selected_cell)
	_update_cell_editor()


func _clear_canvas() -> void:
	_canvas.load_encounter({})
	_canvas.set_selected_cell(Vector2i(-1, -1))
	_update_cell_editor()


func _clear_props() -> void:
	_id_edit.text = ""
	_width_spin.set_value_no_signal(5)
	_height_spin.set_value_no_signal(5)
	for b in _BIOME_IDS:
		_biome_checks[b].set_pressed_no_signal(false)
	_dist_center_spin.set_value_no_signal(20)
	_dist_between_spin.set_value_no_signal(24)
	_max_per_region_spin.set_value_no_signal(1)
	_weight_spin.set_value_no_signal(10)


# ─── Cell editor: read state from data for the selected cell ──────────

func _update_cell_editor() -> void:
	var enc := _current_encounter()
	var c := _selected_cell
	if enc.is_empty() or c.x < 0 or c.y < 0:
		_cell_label.text = "Click a cell to edit it"
		_cell_terrain_option.disabled = true
		_cell_deco_option.disabled = true
		_cell_deco_variant_spin.editable = false
		_cell_entity_option.disabled = true
		return

	var sz: Array = enc.get("size", [1, 1])
	if c.x >= int(sz[0]) or c.y >= int(sz[1]):
		_cell_label.text = "Cell out of bounds"
		_cell_terrain_option.disabled = true
		_cell_deco_option.disabled = true
		_cell_deco_variant_spin.editable = false
		_cell_entity_option.disabled = true
		return

	_cell_label.text = "Cell (%d, %d)" % [c.x, c.y]
	_cell_terrain_option.disabled = false
	_cell_deco_option.disabled = false
	_cell_deco_variant_spin.editable = true
	_cell_entity_option.disabled = false

	# Terrain.
	var code: int = -1
	var tiles: Array = enc.get("tiles", [])
	if c.y < tiles.size() and c.x < tiles[c.y].size():
		code = int(tiles[c.y][c.x])
	var terrain_idx: int = _terrain_keys.find(code)
	if terrain_idx < 0:
		terrain_idx = _terrain_keys.find(-1)
	_cell_terrain_option.selected = terrain_idx

	# Decoration.
	var deco := _find_marker_at(enc.get("decorations", []), c)
	if deco.is_empty():
		_cell_deco_option.selected = 0  # "(none)"
		_cell_deco_variant_spin.set_value_no_signal(0)
	else:
		var kind_str: String = deco.get("kind", "")
		var deco_idx: int = _DECORATION_KINDS.find(kind_str)
		if deco_idx < 0:
			deco_idx = 0
		_cell_deco_option.selected = deco_idx
		_cell_deco_variant_spin.set_value_no_signal(deco.get("variant", 0))

	# Entity.
	var ent := _find_marker_at(enc.get("entities", []), c)
	if ent.is_empty():
		_cell_entity_option.selected = 0  # "(none)"
	else:
		var kind_str: String = ent.get("kind", "")
		var ent_idx: int = _ENTITY_KINDS.find(kind_str)
		if ent_idx < 0:
			ent_idx = 0
		_cell_entity_option.selected = ent_idx


func _find_marker_at(markers: Array, cell: Vector2i) -> Dictionary:
	for m in markers:
		var off: Array = m.get("offset", [0, 0])
		if int(off[0]) == cell.x and int(off[1]) == cell.y:
			return m
	return {}


# ─── Cell editor: write changes back to data ──────────────────────────

func _on_cell_terrain_changed(idx: int) -> void:
	var enc := _current_encounter()
	if enc.is_empty() or _selected_cell.x < 0:
		return
	var code: int = _terrain_keys[idx]
	enc["tiles"][_selected_cell.y][_selected_cell.x] = code
	_canvas.load_encounter(enc)
	_canvas.set_selected_cell(_selected_cell)
	_mark_dirty()


func _on_cell_deco_changed(idx: int) -> void:
	var enc := _current_encounter()
	if enc.is_empty() or _selected_cell.x < 0:
		return
	_remove_marker_at(enc, "decorations", _selected_cell)
	if idx > 0:  # Not "(none)".
		enc["decorations"].append({
			"offset": [_selected_cell.x, _selected_cell.y],
			"kind": _DECORATION_KINDS[idx],
			"variant": int(_cell_deco_variant_spin.value),
		})
	_canvas.load_encounter(enc)
	_canvas.set_selected_cell(_selected_cell)
	_mark_dirty()


func _on_cell_deco_variant_changed(value: float) -> void:
	var enc := _current_encounter()
	if enc.is_empty() or _selected_cell.x < 0:
		return
	var deco := _find_marker_at(enc.get("decorations", []), _selected_cell)
	if deco.is_empty():
		return
	deco["variant"] = int(value)
	_mark_dirty()


func _on_cell_entity_changed(idx: int) -> void:
	var enc := _current_encounter()
	if enc.is_empty() or _selected_cell.x < 0:
		return
	_remove_marker_at(enc, "entities", _selected_cell)
	if idx > 0:  # Not "(none)".
		enc["entities"].append({
			"offset": [_selected_cell.x, _selected_cell.y],
			"type": "npc",
			"kind": _ENTITY_KINDS[idx],
		})
	_canvas.load_encounter(enc)
	_canvas.set_selected_cell(_selected_cell)
	_mark_dirty()


func _remove_marker_at(enc: Dictionary, key: String, cell: Vector2i) -> void:
	var arr: Array = enc.get(key, [])
	var filtered: Array = []
	for m in arr:
		var off: Array = m.get("offset", [0, 0])
		if int(off[0]) != cell.x or int(off[1]) != cell.y:
			filtered.append(m)
	enc[key] = filtered


# ─── Canvas cell selected ─────────────────────────────────────────────

func _on_canvas_cell_selected(cell: Vector2i) -> void:
	var enc := _current_encounter()
	if enc.is_empty():
		return
	var sz: Array = enc.get("size", [5, 5])
	if cell.x < 0 or cell.y < 0 or cell.x >= int(sz[0]) or cell.y >= int(sz[1]):
		return
	_selected_cell = cell
	_canvas.set_selected_cell(cell)
	_update_cell_editor()


# ─── Property sync ────────────────────────────────────────────────────

func _on_id_changed(new_id: String) -> void:
	var enc := _current_encounter()
	if enc.is_empty():
		return
	var old_id := _selected_id
	if new_id == old_id:
		return
	if new_id == "" or _encounters.has(new_id):
		return
	enc["id"] = new_id
	_encounters.erase(old_id)
	_encounters[new_id] = enc
	_selected_id = new_id
	for i in _enc_list.item_count:
		if _enc_list.get_item_text(i) == old_id:
			_enc_list.set_item_text(i, new_id)
			break
	_mark_dirty()


func _on_size_changed(_value: float) -> void:
	var enc := _current_encounter()
	if enc.is_empty():
		return
	var w := int(_width_spin.value)
	var h := int(_height_spin.value)
	var old_sz: Array = enc.get("size", [5, 5])
	if w == int(old_sz[0]) and h == int(old_sz[1]):
		return
	enc["size"] = [w, h]
	var old_tiles: Array = enc.get("tiles", [])
	var new_tiles: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			if y < old_tiles.size() and x < old_tiles[y].size():
				row.append(old_tiles[y][x])
			else:
				row.append(-1)
		new_tiles.append(row)
	enc["tiles"] = new_tiles
	enc["decorations"] = _filter_markers_in_bounds(enc.get("decorations", []), w, h)
	enc["entities"] = _filter_markers_in_bounds(enc.get("entities", []), w, h)
	# Clear selection if now out of bounds.
	if _selected_cell.x >= w or _selected_cell.y >= h:
		_selected_cell = Vector2i(-1, -1)
	_canvas.load_encounter(enc)
	_canvas.set_selected_cell(_selected_cell)
	_update_cell_editor()
	_mark_dirty()


func _filter_markers_in_bounds(markers: Array, w: int, h: int) -> Array:
	var out: Array = []
	for m in markers:
		var off: Array = m.get("offset", [0, 0])
		if int(off[0]) < w and int(off[1]) < h:
			out.append(m)
	return out


func _sync_biomes_to_data() -> void:
	var enc := _current_encounter()
	if enc.is_empty():
		return
	var biomes: Array = []
	for b in _BIOME_IDS:
		if _biome_checks[b].button_pressed:
			biomes.append(b)
	if not enc.has("placement"):
		enc["placement"] = {}
	enc["placement"]["biomes"] = biomes
	_mark_dirty()


func _sync_placement_to_data() -> void:
	var enc := _current_encounter()
	if enc.is_empty():
		return
	if not enc.has("placement"):
		enc["placement"] = {}
	enc["placement"]["min_distance_from_center"] = int(_dist_center_spin.value)
	enc["placement"]["min_distance_between"] = int(_dist_between_spin.value)
	enc["placement"]["max_per_region"] = int(_max_per_region_spin.value)
	enc["placement"]["weight"] = int(_weight_spin.value)
	_mark_dirty()


# ─── Tab switching ────────────────────────────────────────────────────

func _on_tab_changed(idx: int) -> void:
	_canvas_panel.visible = (idx == 0)
	_props_scroll.visible = (idx == 1)


# ─── Inner canvas class ───────────────────────────────────────────────

class _EncounterCanvas extends Control:
	signal cell_selected(cell: Vector2i)

	var _tiles: Array = []
	var _decos: Array = []
	var _entities: Array = []
	var _w: int = 0
	var _h: int = 0
	var _sel: Vector2i = Vector2i(-1, -1)

	func load_encounter(enc: Dictionary) -> void:
		if enc.is_empty():
			_tiles = []
			_decos = []
			_entities = []
			_w = 0
			_h = 0
			_update_size()
			queue_redraw()
			return
		var sz: Array = enc.get("size", [1, 1])
		_w = int(sz[0])
		_h = int(sz[1])
		_tiles = enc.get("tiles", [])
		_decos = enc.get("decorations", [])
		_entities = enc.get("entities", [])
		_update_size()
		queue_redraw()

	func set_selected_cell(cell: Vector2i) -> void:
		_sel = cell
		queue_redraw()

	func _update_size() -> void:
		var needed := Vector2(_w * CELL_DRAW_SIZE + 1, _h * CELL_DRAW_SIZE + 1)
		custom_minimum_size = needed
		# Force the control to be at least this big so clicks register
		# on newly-added cells.
		size = needed

	func _draw() -> void:
		if _w == 0 or _h == 0:
			return
		var cs := CELL_DRAW_SIZE
		# Draw terrain cells.
		for y in _h:
			for x in _w:
				var code: int = -1
				if y < _tiles.size() and x < _tiles[y].size():
					code = int(_tiles[y][x])
				var info: Dictionary = EncounterEditor._TERRAIN_CODES.get(code,
					EncounterEditor._TERRAIN_CODES[-1])
				var rect := Rect2(x * cs, y * cs, cs, cs)
				draw_rect(rect, info["color"])
				# Grid lines.
				draw_rect(rect, Color(0.4, 0.4, 0.4), false, 1.0)
				# Terrain label in cell.
				var label_text: String = info["label"].split(" ")[0]
				if code == -1:
					label_text = "—"
				draw_string(ThemeDB.fallback_font,
					Vector2(x * cs + 2, y * cs + 12),
					label_text, HORIZONTAL_ALIGNMENT_LEFT,
					cs - 4, 9, Color(1, 1, 1, 0.6))

		# Draw decoration markers (green circle + kind text).
		for d in _decos:
			var off: Array = d.get("offset", [0, 0])
			var cx: int = int(off[0])
			var cy: int = int(off[1])
			if cx >= _w or cy >= _h:
				continue
			var center := Vector2(cx * cs + cs * 0.5, cy * cs + cs * 0.5 + 4)
			draw_circle(center, cs * 0.28, Color(0.15, 0.6, 0.15, 0.85))
			var kind_str: String = d.get("kind", "?")
			var short: String = kind_str.substr(0, 4)
			draw_string(ThemeDB.fallback_font, center - Vector2(8, -3),
				short, HORIZONTAL_ALIGNMENT_LEFT,
				cs - 4, 8, Color.WHITE)

		# Draw entity markers (red circle + kind text).
		for e in _entities:
			var off: Array = e.get("offset", [0, 0])
			var cx: int = int(off[0])
			var cy: int = int(off[1])
			if cx >= _w or cy >= _h:
				continue
			var center := Vector2(cx * cs + cs * 0.5, cy * cs + cs * 0.5 + 4)
			draw_circle(center, cs * 0.28, Color(0.7, 0.15, 0.15, 0.85))
			var kind_str: String = e.get("kind", "?")
			var short: String = kind_str.substr(0, 4)
			draw_string(ThemeDB.fallback_font, center - Vector2(8, -3),
				short, HORIZONTAL_ALIGNMENT_LEFT,
				cs - 4, 8, Color.WHITE)

		# Draw selection highlight.
		if _sel.x >= 0 and _sel.y >= 0 and _sel.x < _w and _sel.y < _h:
			var sel_rect := Rect2(_sel.x * cs, _sel.y * cs, cs, cs)
			draw_rect(sel_rect, Color(1, 1, 0, 0.7), false, 3.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				var cell := Vector2i(
					clampi(int(mb.position.x) / CELL_DRAW_SIZE, 0, maxi(_w - 1, 0)),
					clampi(int(mb.position.y) / CELL_DRAW_SIZE, 0, maxi(_h - 1, 0)))
				if _w > 0 and _h > 0:
					cell_selected.emit(cell)
					accept_event()
