## ArmorSetEditor
##
## Sub-editor for editing armor_sets.json inside the Game Editor.
## Left: set list + Add/Delete. Right: display_name, thresholds
## (pieces + stat bonuses per threshold).
class_name ArmorSetEditor
extends VBoxContainer

signal dirty_changed

var sheet_path: String = ""

var _data: Dictionary = {}
var _selected_id: String = ""
var _dirty: bool = false
var _next_id: int = 0

# UI refs
var _set_list: ItemList = null
var _prop_panel: VBoxContainer = null
var _add_btn: Button = null
var _del_btn: Button = null

# Property widgets
var _name_edit: LineEdit = null
var _thresholds_container: VBoxContainer = null
var _items_in_set_container: VBoxContainer = null


func _ready() -> void:
	_load_data()
	_build_ui()
	_populate_list()
	if _set_list.item_count > 0:
		_set_list.select(0)
		_on_set_selected(0)


func _load_data() -> void:
	ArmorSetRegistry.reset()
	_data = ArmorSetRegistry.get_raw_data().duplicate(true)


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

	_set_list = ItemList.new()
	_set_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_set_list.item_selected.connect(_on_set_selected)
	left.add_child(_set_list)

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
	# Display name.
	_prop_panel.add_child(_make_label("Display Name"))
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t): _set_field("display_name", t))
	_prop_panel.add_child(_name_edit)

	# Thresholds section.
	_prop_panel.add_child(HSeparator.new())
	var header := HBoxContainer.new()
	header.add_child(_make_label("Thresholds"))
	var add_thresh_btn := Button.new()
	add_thresh_btn.text = "+ Threshold"
	add_thresh_btn.pressed.connect(_on_add_threshold)
	header.add_child(add_thresh_btn)
	_prop_panel.add_child(header)

	_thresholds_container = VBoxContainer.new()
	_thresholds_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_panel.add_child(_thresholds_container)

	# Items in set (cross-reference).
	_prop_panel.add_child(HSeparator.new())
	_prop_panel.add_child(_make_label("Items in Set"))
	_items_in_set_container = VBoxContainer.new()
	_items_in_set_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_panel.add_child(_items_in_set_container)


# ═══════════════════════════════════════════════════════════════════════
#  LIST MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════

func _populate_list() -> void:
	_set_list.clear()
	var keys: Array = _data.keys()
	keys.sort()
	for k in keys:
		_set_list.add_item(k)


func _on_set_selected(idx: int) -> void:
	_selected_id = _set_list.get_item_text(idx)
	_refresh_props()


func _on_add() -> void:
	var new_id: String = "new_set_%d" % _next_id
	_next_id += 1
	_data[new_id] = {
		"display_name": new_id.capitalize(),
		"thresholds": [],
	}
	_mark_dirty()
	_populate_list()
	for i in _set_list.item_count:
		if _set_list.get_item_text(i) == new_id:
			_set_list.select(i)
			_on_set_selected(i)
			break


func _on_delete() -> void:
	if _selected_id.is_empty():
		return
	_data.erase(_selected_id)
	_selected_id = ""
	_mark_dirty()
	_populate_list()
	if _set_list.item_count > 0:
		_set_list.select(0)
		_on_set_selected(0)


# ═══════════════════════════════════════════════════════════════════════
#  PROPERTY REFRESH
# ═══════════════════════════════════════════════════════════════════════

func _refresh_props() -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return
	_name_edit.text = entry.get("display_name", "")
	_refresh_thresholds(entry)
	_refresh_items_in_set()


func _refresh_thresholds(entry: Dictionary) -> void:
	for c in _thresholds_container.get_children():
		c.queue_free()
	var thresholds: Array = entry.get("thresholds", [])
	for i in thresholds.size():
		var t: Dictionary = thresholds[i]
		var frame := VBoxContainer.new()
		frame.add_theme_constant_override("separation", 2)

		# Pieces row.
		var pieces_row := HBoxContainer.new()
		pieces_row.add_child(_make_small_label("Pieces ≥"))
		var pieces_spin := SpinBox.new()
		pieces_spin.min_value = 1
		pieces_spin.max_value = 10
		pieces_spin.value = float(t.get("pieces", 2))
		pieces_spin.value_changed.connect(_on_threshold_pieces_changed.bind(i))
		pieces_row.add_child(pieces_spin)
		var del := Button.new()
		del.text = "×"
		del.pressed.connect(_on_remove_threshold.bind(i))
		pieces_row.add_child(del)
		frame.add_child(pieces_row)

		# Stat bonuses.
		var bonuses: Dictionary = t.get("stat_bonuses", {})
		var stats: Array = ["strength", "speed", "defense", "dexterity", "charisma", "wisdom"]
		for stat_name in stats:
			if not bonuses.has(stat_name) and bonuses.size() > 0:
				continue  # Only show stats that have a bonus (or show all if empty)
			var stat_row := HBoxContainer.new()
			stat_row.add_child(_make_small_label(stat_name.capitalize()))
			var stat_spin := SpinBox.new()
			stat_spin.min_value = -10
			stat_spin.max_value = 10
			stat_spin.value = float(bonuses.get(stat_name, 0))
			stat_spin.value_changed.connect(
				_on_threshold_stat_changed.bind(i, stat_name))
			stat_row.add_child(stat_spin)
			frame.add_child(stat_row)

		# Add stat button.
		var add_stat_btn := Button.new()
		add_stat_btn.text = "+ Stat Bonus"
		add_stat_btn.pressed.connect(_on_add_stat_to_threshold.bind(i))
		frame.add_child(add_stat_btn)

		frame.add_child(HSeparator.new())
		_thresholds_container.add_child(frame)


func _refresh_items_in_set() -> void:
	for c in _items_in_set_container.get_children():
		c.queue_free()
	if _selected_id.is_empty():
		return
	# Cross-reference: find items with matching set_id.
	var item_data: Dictionary = ItemRegistry.get_raw_data()
	var found := false
	var keys: Array = item_data.keys()
	keys.sort()
	for item_id in keys:
		var item_entry: Dictionary = item_data[item_id]
		var resolved: Dictionary = ItemRegistry.get_resolved_entry(item_id)
		var set_id: String = resolved.get("set_id", "")
		if set_id == _selected_id:
			found = true
			var lbl := Label.new()
			lbl.text = "• %s (%s)" % [item_id, resolved.get("display_name", item_id)]
			lbl.add_theme_font_size_override("font_size", 12)
			_items_in_set_container.add_child(lbl)
	if not found:
		var lbl := Label.new()
		lbl.text = "(no items have set_id = \"%s\")" % _selected_id
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		lbl.add_theme_font_size_override("font_size", 12)
		_items_in_set_container.add_child(lbl)


# ═══════════════════════════════════════════════════════════════════════
#  THRESHOLD EDITING
# ═══════════════════════════════════════════════════════════════════════

func _on_add_threshold() -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return
	if not entry.has("thresholds"):
		entry["thresholds"] = []
	entry["thresholds"].append({"pieces": 2, "stat_bonuses": {}})
	_mark_dirty()
	_refresh_thresholds(entry)


func _on_remove_threshold(idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var thresholds: Array = entry.get("thresholds", [])
	if idx < thresholds.size():
		thresholds.remove_at(idx)
		_mark_dirty()
		_refresh_thresholds(entry)


func _on_threshold_pieces_changed(val: float, idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var thresholds: Array = entry.get("thresholds", [])
	if idx < thresholds.size():
		thresholds[idx]["pieces"] = int(val)
		_mark_dirty()


func _on_threshold_stat_changed(val: float, idx: int, stat_name: String) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var thresholds: Array = entry.get("thresholds", [])
	if idx < thresholds.size():
		if not thresholds[idx].has("stat_bonuses"):
			thresholds[idx]["stat_bonuses"] = {}
		if int(val) == 0:
			thresholds[idx]["stat_bonuses"].erase(stat_name)
		else:
			thresholds[idx]["stat_bonuses"][stat_name] = int(val)
		_mark_dirty()


func _on_add_stat_to_threshold(idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var thresholds: Array = entry.get("thresholds", [])
	if idx >= thresholds.size():
		return
	if not thresholds[idx].has("stat_bonuses"):
		thresholds[idx]["stat_bonuses"] = {}
	# Add the first stat that isn't already present.
	var stats: Array = ["strength", "speed", "defense", "dexterity", "charisma", "wisdom"]
	for s in stats:
		if not thresholds[idx]["stat_bonuses"].has(s):
			thresholds[idx]["stat_bonuses"][s] = 1
			_mark_dirty()
			_refresh_thresholds(entry)
			return


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
	pass  # Armor sets don't use atlas cells.


func get_marks() -> Array:
	return []


func save() -> void:
	ArmorSetRegistry.save_data(_data)
	ArmorSetRegistry.reset()
	_load_data()
	_populate_list()
	if not _selected_id.is_empty():
		for i in _set_list.item_count:
			if _set_list.get_item_text(i) == _selected_id:
				_set_list.select(i)
				_on_set_selected(i)
				break
	elif _set_list.item_count > 0:
		_set_list.select(0)
		_on_set_selected(0)
	_dirty = false


func revert() -> void:
	ArmorSetRegistry.reset()
	_load_data()
	_dirty = false
	_populate_list()
	if _set_list.item_count > 0:
		_set_list.select(0)
		_on_set_selected(0)


func is_dirty() -> bool:
	return _dirty
