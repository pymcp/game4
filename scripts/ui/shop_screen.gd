## ShopScreen
##
## Full-screen overlay for buying/selling items at a shop.
## Shows shop inventory on the left, player inventory on the right,
## gold display, and Buy/Sell buttons.
class_name ShopScreen
extends Control

signal closed

var _shop_id: String = ""
var _player: PlayerController = null
var _npc: Node2D = null
var _shop_data: Dictionary = {}

# UI refs
var _title_label: Label = null
var _gold_label: Label = null
var _shop_list: ItemList = null
var _player_list: ItemList = null
var _buy_btn: Button = null
var _sell_btn: Button = null
var _close_btn: Button = null
var _info_label: Label = null

# Cached filtered arrays for the two lists.
var _shop_entries: Array = []  # Array of {item_id, stock, price}
var _player_entries: Array = []  # Array of {item_id, count, sell_price}


func _ready() -> void:
	visible = false
	_build_ui()


func open(player: PlayerController, shop_id: String, npc: Node2D = null) -> void:
	_player = player
	_shop_id = shop_id
	_npc = npc
	_shop_data = ShopRegistry.get_shop(shop_id)
	_title_label.text = _shop_data.get("display_name", shop_id)
	_refresh()
	visible = true
	if _player != null:
		_player.in_conversation = true


func close() -> void:
	visible = false
	if _player != null:
		_player.in_conversation = false
	if _npc != null and _npc is Villager:
		(_npc as Villager).in_conversation = false
	closed.emit()


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("p1_inventory"):
		close()
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 40
	vbox.offset_right = -40
	vbox.offset_top = 30
	vbox.offset_bottom = -30
	add_child(vbox)

	# Title row.
	var title_row := HBoxContainer.new()
	_title_label = Label.new()
	_title_label.text = "Shop"
	_title_label.add_theme_font_size_override("font_size", 22)
	title_row.add_child(_title_label)
	title_row.add_child(HSeparator.new())
	_gold_label = Label.new()
	_gold_label.text = "Gold: 0"
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_row.add_child(_gold_label)
	vbox.add_child(title_row)

	vbox.add_child(HSeparator.new())

	# Two-column layout.
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 300
	vbox.add_child(split)

	# Left: Shop items.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var shop_header := Label.new()
	shop_header.text = "Shop Stock"
	shop_header.add_theme_font_size_override("font_size", 16)
	left.add_child(shop_header)
	_shop_list = ItemList.new()
	_shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_list.item_selected.connect(_on_shop_item_selected)
	left.add_child(_shop_list)
	_buy_btn = Button.new()
	_buy_btn.text = "Buy"
	_buy_btn.pressed.connect(_on_buy)
	left.add_child(_buy_btn)
	split.add_child(left)

	# Right: Player inventory.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inv_header := Label.new()
	inv_header.text = "Your Items"
	inv_header.add_theme_font_size_override("font_size", 16)
	right.add_child(inv_header)
	_player_list = ItemList.new()
	_player_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_player_list.item_selected.connect(_on_player_item_selected)
	right.add_child(_player_list)
	_sell_btn = Button.new()
	_sell_btn.text = "Sell"
	_sell_btn.pressed.connect(_on_sell)
	right.add_child(_sell_btn)
	split.add_child(right)

	# Info label.
	_info_label = Label.new()
	_info_label.text = ""
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vbox.add_child(_info_label)

	# Close button.
	_close_btn = Button.new()
	_close_btn.text = "Close Shop"
	_close_btn.pressed.connect(close)
	vbox.add_child(_close_btn)


# ═══════════════════════════════════════════════════════════════════════
#  REFRESH
# ═══════════════════════════════════════════════════════════════════════

func _refresh() -> void:
	_refresh_gold()
	_refresh_shop_list()
	_refresh_player_list()
	_info_label.text = ""


func _refresh_gold() -> void:
	var gold: int = 0
	if _player != null:
		gold = _player.inventory.count_of(&"gold")
	_gold_label.text = "Gold: %d" % gold


func _refresh_shop_list() -> void:
	_shop_list.clear()
	_shop_entries = []
	var items_arr: Array = _shop_data.get("items", [])
	for entry in items_arr:
		var item_id: String = entry.get("item_id", "")
		var stock: int = int(entry.get("stock", 0))
		if stock <= 0:
			continue
		var price: int = ShopRegistry.buy_price(_shop_id, StringName(item_id))
		var def: ItemDefinition = ItemRegistry.get_item(StringName(item_id))
		var name: String = def.display_name if def != null else item_id
		_shop_entries.append({"item_id": item_id, "stock": stock, "price": price})
		_shop_list.add_item("%s  ×%d  [%d gold]" % [name, stock, price])


func _refresh_player_list() -> void:
	_player_list.clear()
	_player_entries = []
	if _player == null:
		return
	var seen: Dictionary = {}
	for slot_data in _player.inventory.slots:
		if slot_data == null:
			continue
		var item_id: StringName = slot_data["id"]
		if item_id == &"" or item_id == &"gold":
			continue
		if seen.has(item_id):
			continue
		seen[item_id] = true
		var count: int = _player.inventory.count_of(item_id)
		var sell_p: int = ShopRegistry.sell_price(_shop_id, item_id)
		var def: ItemDefinition = ItemRegistry.get_item(item_id)
		var name: String = def.display_name if def != null else String(item_id)
		_player_entries.append({"item_id": item_id, "count": count, "sell_price": sell_p})
		if sell_p > 0:
			_player_list.add_item("%s  ×%d  [sell %d gold]" % [name, count, sell_p])
		else:
			_player_list.add_item("%s  ×%d  [not sellable]" % [name, count])


# ═══════════════════════════════════════════════════════════════════════
#  ACTIONS
# ═══════════════════════════════════════════════════════════════════════

func _on_shop_item_selected(idx: int) -> void:
	if idx < 0 or idx >= _shop_entries.size():
		return
	var entry: Dictionary = _shop_entries[idx]
	_info_label.text = "Buy %s for %d gold (stock: %d)" % [entry["item_id"], entry["price"], entry["stock"]]


func _on_player_item_selected(idx: int) -> void:
	if idx < 0 or idx >= _player_entries.size():
		return
	var entry: Dictionary = _player_entries[idx]
	if entry["sell_price"] > 0:
		_info_label.text = "Sell %s for %d gold" % [entry["item_id"], entry["sell_price"]]
	else:
		_info_label.text = "%s cannot be sold here" % entry["item_id"]


func _on_buy() -> void:
	var sel: PackedInt32Array = _shop_list.get_selected_items()
	if sel.size() == 0:
		_info_label.text = "Select an item to buy."
		return
	var idx: int = sel[0]
	if idx < 0 or idx >= _shop_entries.size():
		return
	var entry: Dictionary = _shop_entries[idx]
	var price: int = entry["price"]
	if price <= 0:
		_info_label.text = "This item is not for sale."
		return
	var gold: int = _player.inventory.count_of(&"gold") if _player != null else 0
	if price > gold:
		_info_label.text = "Not enough gold! Need %d, have %d." % [price, gold]
		return
	if entry["stock"] <= 0:
		_info_label.text = "Out of stock!"
		return
	# Deduct gold.
	_player.inventory.remove(&"gold", price)
	# Add item.
	_player.inventory.add(StringName(entry["item_id"]), 1)
	# Reduce stock in local data.
	entry["stock"] -= 1
	# Also update in _shop_data items array.
	var items_arr: Array = _shop_data.get("items", [])
	for shop_entry in items_arr:
		if shop_entry.get("item_id", "") == entry["item_id"]:
			shop_entry["stock"] = entry["stock"]
			break
	_info_label.text = "Bought %s for %d gold." % [entry["item_id"], price]
	_refresh()


func _on_sell() -> void:
	var sel: PackedInt32Array = _player_list.get_selected_items()
	if sel.size() == 0:
		_info_label.text = "Select an item to sell."
		return
	var idx: int = sel[0]
	if idx < 0 or idx >= _player_entries.size():
		return
	var entry: Dictionary = _player_entries[idx]
	var sell_p: int = entry["sell_price"]
	if sell_p <= 0:
		_info_label.text = "This item cannot be sold."
		return
	if entry["count"] <= 0:
		return
	# Remove item.
	_player.inventory.remove(StringName(entry["item_id"]), 1)
	# Add gold.
	_player.inventory.add(&"gold", sell_p)
	_info_label.text = "Sold %s for %d gold." % [entry["item_id"], sell_p]
	_refresh()
