## ChestLootEditor
##
## GameEditor panel for editing resources/chest_loot.json.
class_name ChestLootEditor
extends VBoxContainer

signal dirty_changed

var _dirty: bool = false
var _tier_containers: Array = []


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Chest Loot Tiers (depth-scaled)"
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox := VBoxContainer.new()
	scroll.add_child(vbox)

	var tiers: Array = ChestLootRegistry.get_raw_tiers()
	_tier_containers.clear()
	for t_idx in tiers.size():
		var tier: Dictionary = tiers[t_idx]
		var panel: VBoxContainer = _build_tier_panel(tier, t_idx)
		vbox.add_child(panel)
		_tier_containers.append(panel)

	var save_btn := Button.new()
	save_btn.text = "Save Chest Loot"
	save_btn.pressed.connect(save)
	add_child(save_btn)


func _build_tier_panel(tier: Dictionary, t_idx: int) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.set_meta("tier_idx", t_idx)

	var header := HBoxContainer.new()
	panel.add_child(header)

	var tier_label := Label.new()
	tier_label.text = "Tier %d — floors " % (t_idx + 1)
	header.add_child(tier_label)

	var min_spin := SpinBox.new()
	min_spin.name = "MinFloor"
	min_spin.min_value = 1
	min_spin.max_value = 999
	min_spin.value = float(tier.get("min_floor", 1))
	min_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	header.add_child(min_spin)

	var to_label := Label.new()
	to_label.text = " to "
	header.add_child(to_label)

	var max_spin := SpinBox.new()
	max_spin.name = "MaxFloor"
	max_spin.min_value = 1
	max_spin.max_value = 999
	max_spin.value = float(tier.get("max_floor", 5))
	max_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	header.add_child(max_spin)

	var row_container := VBoxContainer.new()
	row_container.name = "Rows"
	panel.add_child(row_container)

	for loot_entry in tier.get("loot", []):
		_add_loot_row(row_container, loot_entry)

	var add_row_btn := Button.new()
	add_row_btn.text = "+ Add Item"
	add_row_btn.pressed.connect(func() -> void: _add_loot_row(row_container, {}); _mark_dirty())
	panel.add_child(add_row_btn)

	return panel


func _add_loot_row(container: VBoxContainer, entry: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	container.add_child(hbox)

	var id_edit := LineEdit.new()
	id_edit.placeholder_text = "item_id"
	id_edit.text = String(entry.get("id", ""))
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.text_changed.connect(func(_t: String) -> void: _mark_dirty())
	hbox.add_child(id_edit)

	for key_default: Array in [["weight", 5], ["min", 1], ["max", 3]]:
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = 999
		spin.value = float(entry.get(key_default[0], key_default[1]))
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
		hbox.add_child(spin)

	var del_btn := Button.new()
	del_btn.text = "X"
	del_btn.pressed.connect(func() -> void: hbox.queue_free(); _mark_dirty())
	hbox.add_child(del_btn)


func _collect_tiers() -> Array:
	var result: Array = []
	for panel in _tier_containers:
		if not is_instance_valid(panel):
			continue
		var min_spin: SpinBox = panel.find_child("MinFloor", false, false)
		var max_spin: SpinBox = panel.find_child("MaxFloor", false, false)
		var row_container: VBoxContainer = panel.find_child("Rows", false, false)
		var loot: Array = []
		if row_container != null:
			for hbox in row_container.get_children():
				var children: Array = hbox.get_children()
				if children.size() < 4:
					continue
				loot.append({
					"id": (children[0] as LineEdit).text,
					"weight": int((children[1] as SpinBox).value),
					"min": int((children[2] as SpinBox).value),
					"max": int((children[3] as SpinBox).value),
				})
		result.append({
			"min_floor": int(min_spin.value) if min_spin else 1,
			"max_floor": int(max_spin.value) if max_spin else 5,
			"loot": loot,
		})
	return result


func save() -> void:
	ChestLootRegistry.save_data(_collect_tiers())
	ChestLootRegistry.reset()
	_dirty = false
	dirty_changed.emit()


func revert() -> void:
	ChestLootRegistry.reset()
	_dirty = false
	# Clear existing tier panels and rebuild.
	var vbox: Node = get_child(1).get_child(0)  # scroll → vbox
	for c in vbox.get_children():
		c.queue_free()
	_tier_containers.clear()
	var tiers: Array = ChestLootRegistry.get_raw_tiers()
	for t_idx in tiers.size():
		var panel: VBoxContainer = _build_tier_panel(tiers[t_idx], t_idx)
		vbox.add_child(panel)
		_tier_containers.append(panel)


func is_dirty() -> bool:
	return _dirty


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		dirty_changed.emit()
