## ShopEditor
##
## Sub-editor for editing shops.json inside the Game Editor.
## Left: shop list + Add/Delete. Right: display_name, buy_markup, sell_discount,
## item list (item_id + stock + price_override).
class_name ShopEditor
extends VBoxContainer

signal dirty_changed

var sheet_path: String = ""

var _data: Dictionary = {}
var _selected_id: String = ""
var _dirty: bool = false
var _next_id: int = 0

# UI refs
var _shop_list: ItemList = null
var _prop_panel: VBoxContainer = null
var _add_btn: Button = null
var _del_btn: Button = null

# Property widgets
var _name_edit: LineEdit = null
var _markup_spin: SpinBox = null
var _discount_spin: SpinBox = null
var _items_container: VBoxContainer = null


func _ready() -> void:
	_load_data()
	_build_ui()
	_populate_list()
	if _shop_list.item_count > 0:
		_shop_list.select(0)
		_on_shop_selected(0)


func _load_data() -> void:
	ShopRegistry.reset()
	_data = ShopRegistry.get_raw_data().duplicate(true)


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

	_shop_list = ItemList.new()
	_shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_list.item_selected.connect(_on_shop_selected)
	left.add_child(_shop_list)

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

	# Buy markup.
	_prop_panel.add_child(_make_label("Buy Markup"))
	_markup_spin = SpinBox.new()
	_markup_spin.min_value = 0.1
	_markup_spin.max_value = 10.0
	_markup_spin.step = 0.1
	_markup_spin.value_changed.connect(func(v): _set_field("buy_markup", v))
	_prop_panel.add_child(_markup_spin)

	# Sell discount.
	_prop_panel.add_child(_make_label("Sell Discount"))
	_discount_spin = SpinBox.new()
	_discount_spin.min_value = 0.0
	_discount_spin.max_value = 1.0
	_discount_spin.step = 0.05
	_discount_spin.value_changed.connect(func(v): _set_field("sell_discount", v))
	_prop_panel.add_child(_discount_spin)

	# Items header.
	_prop_panel.add_child(HSeparator.new())
	var items_header := HBoxContainer.new()
	items_header.add_child(_make_label("Shop Items"))
	var add_item_btn := Button.new()
	add_item_btn.text = "+ Item"
	add_item_btn.pressed.connect(_on_add_item)
	items_header.add_child(add_item_btn)
	_prop_panel.add_child(items_header)

	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_panel.add_child(_items_container)


# ═══════════════════════════════════════════════════════════════════════
#  LIST MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════

func _populate_list() -> void:
	_shop_list.clear()
	var keys: Array = _data.keys()
	keys.sort()
	for k in keys:
		var entry: Dictionary = _data[k]
		_shop_list.add_item(entry.get("display_name", k))


func _on_shop_selected(idx: int) -> void:
	var sorted_keys: Array = _data.keys().duplicate()
	sorted_keys.sort()
	_selected_id = sorted_keys[idx] if idx < sorted_keys.size() else ""
	_refresh_props()


func _on_add() -> void:
	var new_id: String = "new_shop_%d" % _next_id
	_next_id += 1
	_data[new_id] = {
		"display_name": "New Shop",
		"buy_markup": 1.5,
		"sell_discount": 0.5,
		"items": [],
	}
	_mark_dirty()
	_populate_list()
	var sorted_keys: Array = _data.keys().duplicate()
	sorted_keys.sort()
	var target: int = sorted_keys.find(new_id)
	if target >= 0:
		_shop_list.select(target)
		_on_shop_selected(target)


func _on_delete() -> void:
	if _selected_id.is_empty():
		return
	_data.erase(_selected_id)
	_selected_id = ""
	_mark_dirty()
	_populate_list()
	if _shop_list.item_count > 0:
		_shop_list.select(0)
		_on_shop_selected(0)


# ═══════════════════════════════════════════════════════════════════════
#  PROPERTY REFRESH
# ═══════════════════════════════════════════════════════════════════════

func _refresh_props() -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return

	_name_edit.text = entry.get("display_name", "")
	_markup_spin.set_value_no_signal(float(entry.get("buy_markup", 1.5)))
	_discount_spin.set_value_no_signal(float(entry.get("sell_discount", 0.5)))
	_refresh_items(entry)


func _refresh_items(entry: Dictionary) -> void:
	for c in _items_container.get_children():
		c.queue_free()
	var items: Array = entry.get("items", [])
	for i in items.size():
		var item: Dictionary = items[i]
		var row := HBoxContainer.new()

		var id_edit := LineEdit.new()
		id_edit.text = item.get("item_id", "")
		id_edit.custom_minimum_size = Vector2(100, 0)
		id_edit.placeholder_text = "item_id"
		id_edit.text_changed.connect(_on_item_field_changed.bind(i, "item_id"))
		row.add_child(id_edit)

		var stock_lbl := Label.new()
		stock_lbl.text = "Stock:"
		row.add_child(stock_lbl)
		var stock_spin := SpinBox.new()
		stock_spin.min_value = 0
		stock_spin.max_value = 9999
		stock_spin.value = float(item.get("stock", 1))
		stock_spin.value_changed.connect(_on_stock_changed.bind(i))
		row.add_child(stock_spin)

		var price_lbl := Label.new()
		price_lbl.text = "Price:"
		row.add_child(price_lbl)
		var price_spin := SpinBox.new()
		price_spin.min_value = -1
		price_spin.max_value = 99999
		price_spin.value = float(item.get("price_override", -1))
		price_spin.value_changed.connect(_on_price_changed.bind(i))
		row.add_child(price_spin)

		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.pressed.connect(_on_remove_item.bind(i))
		row.add_child(del_btn)
		_items_container.add_child(row)


func _on_item_field_changed(text: String, idx: int, field: String) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var items: Array = entry.get("items", [])
	if idx < items.size():
		items[idx][field] = text
		_mark_dirty()


func _on_stock_changed(val: float, idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var items: Array = entry.get("items", [])
	if idx < items.size():
		items[idx]["stock"] = int(val)
		_mark_dirty()


func _on_price_changed(val: float, idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var items: Array = entry.get("items", [])
	if idx < items.size():
		items[idx]["price_override"] = int(val)
		_mark_dirty()


func _on_add_item() -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	if entry.is_empty():
		return
	if not entry.has("items"):
		entry["items"] = []
	entry["items"].append({"item_id": "", "stock": 1, "price_override": -1})
	_mark_dirty()
	_refresh_items(entry)


func _on_remove_item(idx: int) -> void:
	var entry: Dictionary = _data.get(_selected_id, {})
	var items: Array = entry.get("items", [])
	if idx < items.size():
		items.remove_at(idx)
		_mark_dirty()
		_refresh_items(entry)


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


# ═══════════════════════════════════════════════════════════════════════
#  SUB-EDITOR INTERFACE
# ═══════════════════════════════════════════════════════════════════════

func on_atlas_cell_clicked(_cell: Vector2i) -> void:
	pass


func get_marks() -> Array:
	return []


func save() -> void:
	ShopRegistry.save_data(_data)
	ShopRegistry.reset()
	_load_data()
	_populate_list()
	if not _selected_id.is_empty():
		var sorted_keys: Array = _data.keys().duplicate()
		sorted_keys.sort()
		var target: int = sorted_keys.find(_selected_id)
		if target >= 0:
			_shop_list.select(target)
			_on_shop_selected(target)
	elif _shop_list.item_count > 0:
		_shop_list.select(0)
		_on_shop_selected(0)
	_dirty = false


func revert() -> void:
	ShopRegistry.reset()
	_load_data()
	_dirty = false
	_populate_list()
	if _shop_list.item_count > 0:
		_shop_list.select(0)
		_on_shop_selected(0)


func is_dirty() -> bool:
	return _dirty
