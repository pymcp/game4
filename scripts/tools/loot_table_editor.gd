## LootTableEditor
##
## Sub-editor for editing loot_tables.json inside the Game Editor.
## Left: creature kind list + Add/Delete. Right: properties (health,
## drop_count, drop_chance, resistances, drops list).
class_name LootTableEditor
extends VBoxContainer

signal dirty_changed

var sheet_path: String = ""

var _data: Dictionary = {}
var _selected_id: String = ""
var _dirty: bool = false
var _next_id: int = 0

# UI refs
var _kind_list: ItemList = null
var _prop_scroll: ScrollContainer = null
var _prop_panel: VBoxContainer = null
var _add_btn: Button = null
var _del_btn: Button = null

# Property widgets
var _name_edit: LineEdit = null
var _health_spin: SpinBox = null
var _drop_count_spin: SpinBox = null
var _drop_chance_spin: SpinBox = null
var _drops_container: VBoxContainer = null
var _resist_container: VBoxContainer = null


func _ready() -> void:
	_load_data()
	_build_ui()
	_populate_list()
	if _kind_list.item_count > 0:
		_kind_list.select(0)
		_on_kind_selected(0)


func _load_data() -> void:
	LootTableRegistry.reset()
	_data = LootTableRegistry.get_raw_data().duplicate(true)


# ═══════════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 180
	add_child(split)

	# Left pane: kind list + buttons.
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(160, 0)
	split.add_child(left)

	_kind_list = ItemList.new()
	_kind_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kind_list.item_selected.connect(_on_kind_selected)
	left.add_child(_kind_list)

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

	# Right pane: properties.
	_prop_scroll = ScrollContainer.new()
	_prop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_prop_scroll)

	_prop_panel = VBoxContainer.new()
	_prop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_scroll.add_child(_prop_panel)

	_build_prop_panel()


func _build_prop_panel() -> void:
	# Display name.
	_prop_panel.add_child(_make_label("Display Name"))
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t): _set_field("display_name", t))
	_prop_panel.add_child(_name_edit)

	# Health.
	_prop_panel.add_child(_make_label("Health"))
	_health_spin = SpinBox.new()
	_health_spin.min_value = 1
	_health_spin.max_value = 9999
	_health_spin.value_changed.connect(func(v): _set_field("health", int(v)))
	_prop_panel.add_child(_health_spin)

	# Drop count.
	_prop_panel.add_child(_make_label("Drop Count"))
	_drop_count_spin = SpinBox.new()
	_drop_count_spin.min_value = 0
	_drop_count_spin.max_value = 20
	_drop_count_spin.value_changed.connect(func(v): _set_field("drop_count", int(v)))
	_prop_panel.add_child(_drop_count_spin)

	# Drop chance.
	_prop_panel.add_child(_make_label("Drop Chance"))
	_drop_chance_spin = SpinBox.new()
	_drop_chance_spin.min_value = 0.0
	_drop_chance_spin.max_value = 1.0
	_drop_chance_spin.step = 0.05
	_drop_chance_spin.value_changed.connect(func(v): _set_field("drop_chance", v))
	_prop_panel.add_child(_drop_chance_spin)

	# Resistances section.
	_prop_panel.add_child(HSeparator.new())
	_prop_panel.add_child(_make_label("Resistances"))
	_resist_container = VBoxContainer.new()
	_resist_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_panel.add_child(_resist_container)

	# Drops section.
	_prop_panel.add_child(HSeparator.new())
	var drops_header := HBoxContainer.new()
	drops_header.add_child(_make_label("Drops"))
	var add_drop_btn := Button.new()
	add_drop_btn.text = "+ Drop"
	add_drop_btn.pressed.connect(_on_add_drop)
	drops_header.add_child(add_drop_btn)
	_prop_panel.add_child(drops_header)

	_drops_container = VBoxContainer.new()
	_drops_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_panel.add_child(_drops_container)


# ═══════════════════════════════════════════════════════════════════════
#  LIST MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════

func _populate_list() -> void:
	_kind_list.clear()
	var keys: Array = _data.keys()
	keys.sort()
	for k in keys:
		_kind_list.add_item(k)


func _on_kind_selected(idx: int) -> void:
	_selected_id = _kind_list.get_item_text(idx)
	_refresh_props()


func _on_add() -> void:
	var new_id: String = "new_creature_%d" % _next_id
	_next_id += 1
	_data[new_id] = {
		"display_name": new_id.capitalize(),
		"health": 3,
		"drops": [],
		"drop_count": 1,
		"drop_chance": 0.7,
	}
	_mark_dirty()
	_populate_list()
	# Select the new entry.
	for i in _kind_list.item_count:
		if _kind_list.get_item_text(i) == new_id:
			_kind_list.select(i)
			_on_kind_selected(i)
			break


func _on_delete() -> void:
	if _selected_id.is_empty():
		return
	_data.erase(_selected_id)
	_selected_id = ""
	_mark_dirty()
	_populate_list()
	if _kind_list.item_count > 0:
		_kind_list.select(0)
		_on_kind_selected(0)


# ═══════════════════════════════════════════════════════════════════════
#  PROPERTY REFRESH
# ═══════════════════════════════════════════════════════════════════════

func _refresh_props() -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return

	_name_edit.text = entry.get("display_name", "")
	_health_spin.set_value_no_signal(float(entry.get("health", 3)))
	_drop_count_spin.set_value_no_signal(float(entry.get("drop_count", 1)))
	_drop_chance_spin.set_value_no_signal(float(entry.get("drop_chance", 1.0)))

	_refresh_resistances(entry)
	_refresh_drops(entry)


func _refresh_resistances(entry: Dictionary) -> void:
	for c in _resist_container.get_children():
		c.queue_free()
	var resistances: Dictionary = entry.get("resistances", {})
	var elements: Array = ["1", "2", "3", "4"]  # fire, ice, lightning, poison
	var element_names: Array = ["Fire", "Ice", "Lightning", "Poison"]
	for i in elements.size():
		var key: String = elements[i]
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = element_names[i]
		lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(lbl)
		var spin := SpinBox.new()
		spin.min_value = 0.0
		spin.max_value = 3.0
		spin.step = 0.1
		spin.value = float(resistances.get(key, 1.0))
		spin.value_changed.connect(_on_resistance_changed.bind(key))
		row.add_child(spin)
		_resist_container.add_child(row)


func _on_resistance_changed(val: float, element_key: String) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return
	if not entry.has("resistances"):
		entry["resistances"] = {}
	if is_equal_approx(val, 1.0):
		entry["resistances"].erase(element_key)
		if entry["resistances"].is_empty():
			entry.erase("resistances")
	else:
		entry["resistances"][element_key] = val
	_mark_dirty()


func _refresh_drops(entry: Dictionary) -> void:
	for c in _drops_container.get_children():
		c.queue_free()
	var drops: Array = entry.get("drops", [])
	for i in drops.size():
		var drop: Dictionary = drops[i]
		var row := HBoxContainer.new()

		var id_edit := LineEdit.new()
		id_edit.text = drop.get("item_id", "")
		id_edit.custom_minimum_size = Vector2(100, 0)
		id_edit.text_changed.connect(_on_drop_field_changed.bind(i, "item_id"))
		row.add_child(id_edit)

		row.add_child(_make_small_label("W:"))
		var w_spin := SpinBox.new()
		w_spin.min_value = 1
		w_spin.max_value = 999
		w_spin.value = float(drop.get("weight", 1))
		w_spin.value_changed.connect(_on_drop_num_changed.bind(i, "weight"))
		row.add_child(w_spin)

		row.add_child(_make_small_label("Min:"))
		var min_spin := SpinBox.new()
		min_spin.min_value = 1
		min_spin.max_value = 99
		min_spin.value = float(drop.get("min", 1))
		min_spin.value_changed.connect(_on_drop_num_changed.bind(i, "min"))
		row.add_child(min_spin)

		row.add_child(_make_small_label("Max:"))
		var max_spin := SpinBox.new()
		max_spin.min_value = 1
		max_spin.max_value = 99
		max_spin.value = float(drop.get("max", 1))
		max_spin.value_changed.connect(_on_drop_num_changed.bind(i, "max"))
		row.add_child(max_spin)

		var del := Button.new()
		del.text = "×"
		del.pressed.connect(_on_remove_drop.bind(i))
		row.add_child(del)

		_drops_container.add_child(row)


func _on_drop_field_changed(text: String, idx: int, field: String) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var drops: Array = entry.get("drops", [])
	if idx < drops.size():
		drops[idx][field] = text
		_mark_dirty()


func _on_drop_num_changed(val: float, idx: int, field: String) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var drops: Array = entry.get("drops", [])
	if idx < drops.size():
		drops[idx][field] = int(val)
		_mark_dirty()


func _on_add_drop() -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return
	if not entry.has("drops"):
		entry["drops"] = []
	entry["drops"].append({"item_id": "", "weight": 10, "min": 1, "max": 1})
	_mark_dirty()
	_refresh_drops(entry)


func _on_remove_drop(idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var drops: Array = entry.get("drops", [])
	if idx < drops.size():
		drops.remove_at(idx)
		_mark_dirty()
		_refresh_drops(entry)


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
	pass  # Loot tables don't use atlas cells directly.


func get_marks() -> Array:
	return []  # No atlas marks for loot tables.


func save() -> void:
	LootTableRegistry.save_data(_data)
	LootTableRegistry.reset()
	_load_data()
	_populate_list()
	if not _selected_id.is_empty():
		for i in _kind_list.item_count:
			if _kind_list.get_item_text(i) == _selected_id:
				_kind_list.select(i)
				_on_kind_selected(i)
				break
	elif _kind_list.item_count > 0:
		_kind_list.select(0)
		_on_kind_selected(0)
	_dirty = false


func revert() -> void:
	LootTableRegistry.reset()
	_load_data()
	_dirty = false
	_populate_list()
	if _kind_list.item_count > 0:
		_kind_list.select(0)
		_on_kind_selected(0)


func is_dirty() -> bool:
	return _dirty
