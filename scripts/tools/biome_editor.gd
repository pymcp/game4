## BiomeEditor
##
## Sub-editor for editing biomes.json inside the Game Editor.
## Left: biome list + Add/Delete. Right: terrain, modulate color,
## decoration weights, NPC density/kinds.
class_name BiomeEditor
extends VBoxContainer

signal dirty_changed

var sheet_path: String = ""

var _data: Dictionary = {}
var _selected_id: String = ""
var _dirty: bool = false
var _next_id: int = 0

# UI refs
var _biome_list: ItemList = null
var _prop_panel: VBoxContainer = null
var _add_btn: Button = null
var _del_btn: Button = null

# Property widgets
var _primary_spin: SpinBox = null
var _secondary_spin: SpinBox = null
var _secondary_chance_spin: SpinBox = null
var _modulate_picker: ColorPickerButton = null
var _bleed_chance_spin: SpinBox = null
var _npc_density_spin: SpinBox = null
var _decoration_container: VBoxContainer = null
var _npc_kinds_container: VBoxContainer = null

# Terrain code labels for display.
const _TERRAIN_NAMES: Dictionary = {
	0: "Ocean", 1: "Water", 2: "Sand", 3: "Grass",
	4: "Dirt", 5: "Rock", 6: "Snow", 7: "Swamp",
}


func _ready() -> void:
	_load_data()
	_build_ui()
	_populate_list()
	if _biome_list.item_count > 0:
		_biome_list.select(0)
		_on_biome_selected(0)


func _load_data() -> void:
	BiomeRegistry.reset()
	_data = BiomeRegistry.get_raw_data().duplicate(true)


# ═══════════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 160
	add_child(split)

	# Left pane.
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(140, 0)
	split.add_child(left)

	_biome_list = ItemList.new()
	_biome_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_biome_list.item_selected.connect(_on_biome_selected)
	left.add_child(_biome_list)

	var btn_row := HBoxContainer.new()
	_add_btn = Button.new()
	_add_btn.text = "Add"
	_add_btn.pressed.connect(_on_add)
	btn_row.add_child(_add_btn)
	_del_btn = Button.new()
	_del_btn.text = "Delete"
	_del_btn.pressed.connect(_on_delete)
	btn_row.add_child(_del_btn)
	left.add_child(btn_row)

	# Right pane.
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)

	_prop_panel = VBoxContainer.new()
	_prop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_prop_panel)

	_build_prop_panel()


func _build_prop_panel() -> void:
	# Primary terrain.
	_prop_panel.add_child(_make_label("Primary Terrain"))
	_primary_spin = SpinBox.new()
	_primary_spin.min_value = 0
	_primary_spin.max_value = 7
	_primary_spin.value_changed.connect(func(v): _set_field("primary_terrain", int(v)))
	_prop_panel.add_child(_primary_spin)

	# Secondary terrain.
	_prop_panel.add_child(_make_label("Secondary Terrain"))
	_secondary_spin = SpinBox.new()
	_secondary_spin.min_value = 0
	_secondary_spin.max_value = 7
	_secondary_spin.value_changed.connect(func(v): _set_field("secondary_terrain", int(v)))
	_prop_panel.add_child(_secondary_spin)

	# Secondary chance.
	_prop_panel.add_child(_make_label("Secondary Chance"))
	_secondary_chance_spin = SpinBox.new()
	_secondary_chance_spin.min_value = 0.0
	_secondary_chance_spin.max_value = 1.0
	_secondary_chance_spin.step = 0.01
	_secondary_chance_spin.value_changed.connect(func(v): _set_field("secondary_chance", v))
	_prop_panel.add_child(_secondary_chance_spin)

	# Ground modulate.
	_prop_panel.add_child(_make_label("Ground Modulate"))
	_modulate_picker = ColorPickerButton.new()
	_modulate_picker.custom_minimum_size = Vector2(60, 30)
	_modulate_picker.color_changed.connect(_on_modulate_changed)
	_prop_panel.add_child(_modulate_picker)

	# Bleed chance.
	_prop_panel.add_child(_make_label("Bleed Chance"))
	_bleed_chance_spin = SpinBox.new()
	_bleed_chance_spin.min_value = 0.0
	_bleed_chance_spin.max_value = 1.0
	_bleed_chance_spin.step = 0.05
	_bleed_chance_spin.value_changed.connect(func(v): _set_field("bleed_chance", v))
	_prop_panel.add_child(_bleed_chance_spin)

	# NPC density.
	_prop_panel.add_child(HSeparator.new())
	_prop_panel.add_child(_make_label("NPC Density"))
	_npc_density_spin = SpinBox.new()
	_npc_density_spin.min_value = 0.0
	_npc_density_spin.max_value = 0.1
	_npc_density_spin.step = 0.001
	_npc_density_spin.value_changed.connect(func(v): _set_field("npc_density", v))
	_prop_panel.add_child(_npc_density_spin)

	# NPC kinds.
	var npc_header := HBoxContainer.new()
	npc_header.add_child(_make_label("NPC Kinds"))
	var add_npc_btn := Button.new()
	add_npc_btn.text = "+ Kind"
	add_npc_btn.pressed.connect(_on_add_npc_kind)
	npc_header.add_child(add_npc_btn)
	_prop_panel.add_child(npc_header)

	_npc_kinds_container = VBoxContainer.new()
	_npc_kinds_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_panel.add_child(_npc_kinds_container)

	# Decoration weights.
	_prop_panel.add_child(HSeparator.new())
	var deco_header := HBoxContainer.new()
	deco_header.add_child(_make_label("Decoration Weights"))
	var add_deco_btn := Button.new()
	add_deco_btn.text = "+ Decoration"
	add_deco_btn.pressed.connect(_on_add_decoration)
	deco_header.add_child(add_deco_btn)
	_prop_panel.add_child(deco_header)

	_decoration_container = VBoxContainer.new()
	_decoration_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_panel.add_child(_decoration_container)


# ═══════════════════════════════════════════════════════════════════════
#  LIST MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════

func _populate_list() -> void:
	_biome_list.clear()
	var keys: Array = _data.keys()
	keys.sort()
	for k in keys:
		_biome_list.add_item(k)


func _on_biome_selected(idx: int) -> void:
	_selected_id = _biome_list.get_item_text(idx)
	_refresh_props()


func _on_add() -> void:
	var new_id: String = "new_biome_%d" % _next_id
	_next_id += 1
	_data[new_id] = {
		"primary_terrain": 3,
		"secondary_terrain": 4,
		"secondary_chance": 0.08,
		"ground_modulate": [1.0, 1.0, 1.0, 1.0],
		"decoration_weights": {},
		"bleed_chance": 0.25,
		"npc_density": 0.002,
		"npc_kinds": ["slime"],
	}
	_mark_dirty()
	_populate_list()
	for i in _biome_list.item_count:
		if _biome_list.get_item_text(i) == new_id:
			_biome_list.select(i)
			_on_biome_selected(i)
			break


func _on_delete() -> void:
	if _selected_id.is_empty():
		return
	_data.erase(_selected_id)
	_selected_id = ""
	_mark_dirty()
	_populate_list()
	if _biome_list.item_count > 0:
		_biome_list.select(0)
		_on_biome_selected(0)


# ═══════════════════════════════════════════════════════════════════════
#  PROPERTY REFRESH
# ═══════════════════════════════════════════════════════════════════════

func _refresh_props() -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return

	_primary_spin.set_value_no_signal(float(entry.get("primary_terrain", 3)))
	_secondary_spin.set_value_no_signal(float(entry.get("secondary_terrain", 4)))
	_secondary_chance_spin.set_value_no_signal(float(entry.get("secondary_chance", 0.08)))
	_bleed_chance_spin.set_value_no_signal(float(entry.get("bleed_chance", 0.25)))
	_npc_density_spin.set_value_no_signal(float(entry.get("npc_density", 0.002)))

	var gm: Variant = entry.get("ground_modulate", [1.0, 1.0, 1.0, 1.0])
	_modulate_picker.set_block_signals(true)
	if gm is Array and gm.size() >= 4:
		_modulate_picker.color = Color(float(gm[0]), float(gm[1]),
			float(gm[2]), float(gm[3]))
	elif gm is Array and gm.size() >= 3:
		_modulate_picker.color = Color(float(gm[0]), float(gm[1]), float(gm[2]))
	_modulate_picker.set_block_signals(false)

	_refresh_npc_kinds(entry)
	_refresh_decorations(entry)


func _on_modulate_changed(color: Color) -> void:
	_set_field("ground_modulate", [color.r, color.g, color.b, color.a])


func _refresh_npc_kinds(entry: Dictionary) -> void:
	for c in _npc_kinds_container.get_children():
		c.queue_free()
	var kinds: Array = entry.get("npc_kinds", [])
	for i in kinds.size():
		var row := HBoxContainer.new()
		var edit := LineEdit.new()
		edit.text = str(kinds[i])
		edit.custom_minimum_size = Vector2(100, 0)
		edit.text_changed.connect(_on_npc_kind_changed.bind(i))
		row.add_child(edit)
		var del := Button.new()
		del.text = "×"
		del.pressed.connect(_on_remove_npc_kind.bind(i))
		row.add_child(del)
		_npc_kinds_container.add_child(row)


func _on_npc_kind_changed(text: String, idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var kinds: Array = entry.get("npc_kinds", [])
	if idx < kinds.size():
		kinds[idx] = text
		_mark_dirty()


func _on_add_npc_kind() -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return
	if not entry.has("npc_kinds"):
		entry["npc_kinds"] = []
	entry["npc_kinds"].append("slime")
	_mark_dirty()
	_refresh_npc_kinds(entry)


func _on_remove_npc_kind(idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var kinds: Array = entry.get("npc_kinds", [])
	if idx < kinds.size():
		kinds.remove_at(idx)
		_mark_dirty()
		_refresh_npc_kinds(entry)


func _refresh_decorations(entry: Dictionary) -> void:
	for c in _decoration_container.get_children():
		c.queue_free()
	var weights: Variant = entry.get("decoration_weights", {})
	if not weights is Dictionary:
		return
	var keys: Array = (weights as Dictionary).keys()
	keys.sort()
	for k in keys:
		var row := HBoxContainer.new()
		var name_edit := LineEdit.new()
		name_edit.text = str(k)
		name_edit.custom_minimum_size = Vector2(90, 0)
		name_edit.editable = false  # Key is read-only; delete and re-add to rename.
		row.add_child(name_edit)
		var spin := SpinBox.new()
		spin.min_value = 0.0
		spin.max_value = 1.0
		spin.step = 0.005
		spin.value = float(weights[k])
		spin.value_changed.connect(_on_decoration_weight_changed.bind(str(k)))
		row.add_child(spin)
		var del := Button.new()
		del.text = "×"
		del.pressed.connect(_on_remove_decoration.bind(str(k)))
		row.add_child(del)
		_decoration_container.add_child(row)


func _on_decoration_weight_changed(val: float, key: String) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var weights: Dictionary = entry.get("decoration_weights", {})
	weights[key] = val
	_mark_dirty()


func _on_add_decoration() -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return
	if not entry.has("decoration_weights"):
		entry["decoration_weights"] = {}
	# Add with a placeholder name.
	var idx: int = entry["decoration_weights"].size()
	var key: String = "decoration_%d" % idx
	entry["decoration_weights"][key] = 0.01
	_mark_dirty()
	_refresh_decorations(entry)


func _on_remove_decoration(key: String) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var weights: Dictionary = entry.get("decoration_weights", {})
	weights.erase(key)
	_mark_dirty()
	_refresh_decorations(entry)


# ═══════════════════════════════════════════════════════════════════════
#  HELPERS
# ═══════════════════════════════════════════════════════════════════════

func _set_field(key: String, value: Variant) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return
	entry[key] = value
	_mark_dirty()


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		dirty_changed.emit()


func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	return l


func _make_small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	return l


# ═══════════════════════════════════════════════════════════════════════
#  SUB-EDITOR INTERFACE
# ═══════════════════════════════════════════════════════════════════════

func on_atlas_cell_clicked(_cell: Vector2i) -> void:
	pass  # Biomes don't use atlas cells.


func get_marks() -> Array:
	return []


func save() -> void:
	BiomeRegistry.save_data(_data)
	BiomeRegistry.reset()
	_load_data()
	_populate_list()
	if not _selected_id.is_empty():
		for i in _biome_list.item_count:
			if _biome_list.get_item_text(i) == _selected_id:
				_biome_list.select(i)
				_on_biome_selected(i)
				break
	elif _biome_list.item_count > 0:
		_biome_list.select(0)
		_on_biome_selected(0)
	_dirty = false


func revert() -> void:
	BiomeRegistry.reset()
	_load_data()
	_dirty = false
	_populate_list()
	if _biome_list.item_count > 0:
		_biome_list.select(0)
		_on_biome_selected(0)


func is_dirty() -> bool:
	return _dirty
