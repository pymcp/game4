## EncounterTableEditor
##
## GameEditor panel for editing resources/encounter_tables.json.
class_name EncounterTableEditor
extends VBoxContainer

signal dirty_changed

var _data: Dictionary = {}
var _dirty: bool = false
var _type_selector: OptionButton
var _boss_interval_spin: SpinBox
var _table_container: VBoxContainer
var _current_type: String = "labyrinth"


func _ready() -> void:
	_data = EncounterTableRegistry.get_raw_data()
	_build_ui()
	_load_type(_current_type)


func _build_ui() -> void:
	var top := HBoxContainer.new()
	add_child(top)

	var type_label := Label.new()
	type_label.text = "Dungeon type:"
	top.add_child(type_label)

	_type_selector = OptionButton.new()
	for t in _data.keys():
		_type_selector.add_item(String(t))
	_type_selector.item_selected.connect(_on_type_selected)
	top.add_child(_type_selector)

	var interval_label := Label.new()
	interval_label.text = "  Boss interval:"
	top.add_child(interval_label)

	_boss_interval_spin = SpinBox.new()
	_boss_interval_spin.min_value = 1
	_boss_interval_spin.max_value = 99
	_boss_interval_spin.value = 5
	_boss_interval_spin.value_changed.connect(_on_boss_interval_changed)
	top.add_child(_boss_interval_spin)

	var headers := HBoxContainer.new()
	add_child(headers)
	for h in ["Creature", "Min Floor", "Max Floor", "Weight", ""]:
		var l := Label.new()
		l.text = h
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		headers.add_child(l)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	add_child(scroll)

	_table_container = VBoxContainer.new()
	scroll.add_child(_table_container)

	var bottom := HBoxContainer.new()
	add_child(bottom)

	var add_btn := Button.new()
	add_btn.text = "+ Add Row"
	add_btn.pressed.connect(_on_add_row)
	bottom.add_child(add_btn)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(save)
	bottom.add_child(save_btn)


func _load_type(type_name: String) -> void:
	_current_type = type_name
	for c in _table_container.get_children():
		c.queue_free()
	var type_data: Variant = _data.get(type_name, null)
	if not (type_data is Dictionary):
		return
	_boss_interval_spin.value = float(type_data.get("boss_interval", 5))
	var rows: Array = type_data.get("enemy_tables", [])
	for row in rows:
		_add_row_widget(row)


func _add_row_widget(row: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	_table_container.add_child(hbox)

	var creature_edit := LineEdit.new()
	creature_edit.text = String(row.get("creature", ""))
	creature_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	creature_edit.text_changed.connect(func(_t: String) -> void: _mark_dirty())
	hbox.add_child(creature_edit)

	for key in ["min_floor", "max_floor", "weight"]:
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = 999
		spin.value = float(row.get(key, 1))
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
		hbox.add_child(spin)

	var del_btn := Button.new()
	del_btn.text = "X"
	del_btn.pressed.connect(func() -> void: hbox.queue_free(); _mark_dirty())
	hbox.add_child(del_btn)


func _collect_data() -> void:
	var rows: Array = []
	for hbox in _table_container.get_children():
		var children: Array = hbox.get_children()
		if children.size() < 4:
			continue
		rows.append({
			"creature": (children[0] as LineEdit).text,
			"min_floor": int((children[1] as SpinBox).value),
			"max_floor": int((children[2] as SpinBox).value),
			"weight":    int((children[3] as SpinBox).value),
		})
	if not _data.has(_current_type):
		_data[_current_type] = {}
	(_data[_current_type] as Dictionary)["enemy_tables"] = rows
	(_data[_current_type] as Dictionary)["boss_interval"] = int(_boss_interval_spin.value)


func _on_type_selected(idx: int) -> void:
	_collect_data()
	_load_type(_type_selector.get_item_text(idx))


func _on_boss_interval_changed(_v: float) -> void:
	_mark_dirty()


func _on_add_row() -> void:
	_add_row_widget({"creature": "slime", "min_floor": 1, "max_floor": 10, "weight": 5})
	_mark_dirty()


func save() -> void:
	_collect_data()
	EncounterTableRegistry.save_data(_data)
	_dirty = false
	dirty_changed.emit()


func revert() -> void:
	EncounterTableRegistry.reset()
	_data = EncounterTableRegistry.get_raw_data()
	_dirty = false
	# Rebuild type selector options.
	_type_selector.clear()
	for t in _data.keys():
		_type_selector.add_item(String(t))
	_load_type(_current_type)


func is_dirty() -> bool:
	return _dirty


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		dirty_changed.emit()
