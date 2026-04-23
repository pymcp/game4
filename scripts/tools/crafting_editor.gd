## CraftingEditor
##
## Sub-editor for editing recipes.json inside the Game Editor.
## Left: recipe list + Add/Delete. Right: output item, output count,
## inputs list (item_id + count).
class_name CraftingEditor
extends VBoxContainer

signal dirty_changed

var sheet_path: String = ""

var _data: Dictionary = {}
var _selected_id: String = ""
var _dirty: bool = false
var _next_id: int = 0

# UI refs
var _recipe_list: ItemList = null
var _prop_panel: VBoxContainer = null
var _add_btn: Button = null
var _del_btn: Button = null

# Property widgets
var _output_id_edit: LineEdit = null
var _output_count_spin: SpinBox = null
var _inputs_container: VBoxContainer = null


func _ready() -> void:
	_load_data()
	_build_ui()
	_populate_list()
	if _recipe_list.item_count > 0:
		_recipe_list.select(0)
		_on_recipe_selected(0)


func _load_data() -> void:
	CraftingRegistry.reset()
	_data = CraftingRegistry.get_raw_data().duplicate(true)


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

	# Left pane: recipe list + buttons.
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(160, 0)
	split.add_child(left)

	_recipe_list = ItemList.new()
	_recipe_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_recipe_list.item_selected.connect(_on_recipe_selected)
	left.add_child(_recipe_list)

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
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)

	_prop_panel = VBoxContainer.new()
	_prop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_prop_panel)

	_build_prop_panel()


func _build_prop_panel() -> void:
	# Output item.
	_prop_panel.add_child(_make_label("Output Item ID"))
	_output_id_edit = LineEdit.new()
	_output_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_id_edit.text_changed.connect(func(t): _set_field("output_id", t))
	_prop_panel.add_child(_output_id_edit)

	# Output count.
	_prop_panel.add_child(_make_label("Output Count"))
	_output_count_spin = SpinBox.new()
	_output_count_spin.min_value = 1
	_output_count_spin.max_value = 99
	_output_count_spin.value_changed.connect(func(v): _set_field("output_count", int(v)))
	_prop_panel.add_child(_output_count_spin)

	# Inputs section.
	_prop_panel.add_child(HSeparator.new())
	var header := HBoxContainer.new()
	header.add_child(_make_label("Inputs"))
	var add_input_btn := Button.new()
	add_input_btn.text = "+ Input"
	add_input_btn.pressed.connect(_on_add_input)
	header.add_child(add_input_btn)
	_prop_panel.add_child(header)

	_inputs_container = VBoxContainer.new()
	_inputs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_panel.add_child(_inputs_container)


# ═══════════════════════════════════════════════════════════════════════
#  LIST MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════

func _populate_list() -> void:
	_recipe_list.clear()
	var keys: Array = _data.keys()
	keys.sort()
	for k in keys:
		_recipe_list.add_item(k)


func _on_recipe_selected(idx: int) -> void:
	_selected_id = _recipe_list.get_item_text(idx)
	_refresh_props()


func _on_add() -> void:
	var new_id: String = "new_recipe_%d" % _next_id
	_next_id += 1
	_data[new_id] = {
		"inputs": [],
		"output_id": new_id,
		"output_count": 1,
	}
	_mark_dirty()
	_populate_list()
	for i in _recipe_list.item_count:
		if _recipe_list.get_item_text(i) == new_id:
			_recipe_list.select(i)
			_on_recipe_selected(i)
			break


func _on_delete() -> void:
	if _selected_id.is_empty():
		return
	_data.erase(_selected_id)
	_selected_id = ""
	_mark_dirty()
	_populate_list()
	if _recipe_list.item_count > 0:
		_recipe_list.select(0)
		_on_recipe_selected(0)


# ═══════════════════════════════════════════════════════════════════════
#  PROPERTY REFRESH
# ═══════════════════════════════════════════════════════════════════════

func _refresh_props() -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return
	_output_id_edit.text = entry.get("output_id", "")
	_output_count_spin.set_value_no_signal(float(entry.get("output_count", 1)))
	_refresh_inputs(entry)


func _refresh_inputs(entry: Dictionary) -> void:
	for c in _inputs_container.get_children():
		c.queue_free()
	var inputs: Array = entry.get("inputs", [])
	for i in inputs.size():
		var inp: Dictionary = inputs[i]
		var row := HBoxContainer.new()

		var id_edit := LineEdit.new()
		id_edit.text = str(inp.get("id", ""))
		id_edit.custom_minimum_size = Vector2(120, 0)
		id_edit.text_changed.connect(_on_input_id_changed.bind(i))
		row.add_child(id_edit)

		row.add_child(_make_small_label("×"))
		var count_spin := SpinBox.new()
		count_spin.min_value = 1
		count_spin.max_value = 99
		count_spin.value = float(inp.get("count", 1))
		count_spin.value_changed.connect(_on_input_count_changed.bind(i))
		row.add_child(count_spin)

		var del := Button.new()
		del.text = "×"
		del.pressed.connect(_on_remove_input.bind(i))
		row.add_child(del)

		_inputs_container.add_child(row)


func _on_input_id_changed(text: String, idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var inputs: Array = entry.get("inputs", [])
	if idx < inputs.size():
		inputs[idx]["id"] = text
		_mark_dirty()


func _on_input_count_changed(val: float, idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var inputs: Array = entry.get("inputs", [])
	if idx < inputs.size():
		inputs[idx]["count"] = int(val)
		_mark_dirty()


func _on_add_input() -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return
	if not entry.has("inputs"):
		entry["inputs"] = []
	entry["inputs"].append({"id": "", "count": 1})
	_mark_dirty()
	_refresh_inputs(entry)


func _on_remove_input(idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var inputs: Array = entry.get("inputs", [])
	if idx < inputs.size():
		inputs.remove_at(idx)
		_mark_dirty()
		_refresh_inputs(entry)


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
	pass  # Crafting recipes don't use atlas cells.


func get_marks() -> Array:
	return []


func save() -> void:
	CraftingRegistry.save_data(_data)
	CraftingRegistry.reset()
	_load_data()
	_populate_list()
	if not _selected_id.is_empty():
		for i in _recipe_list.item_count:
			if _recipe_list.get_item_text(i) == _selected_id:
				_recipe_list.select(i)
				_on_recipe_selected(i)
				break
	elif _recipe_list.item_count > 0:
		_recipe_list.select(0)
		_on_recipe_selected(0)
	_dirty = false


func revert() -> void:
	CraftingRegistry.reset()
	_load_data()
	_dirty = false
	_populate_list()
	if _recipe_list.item_count > 0:
		_recipe_list.select(0)
		_on_recipe_selected(0)


func is_dirty() -> bool:
	return _dirty
