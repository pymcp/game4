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

@onready var _title_label: Label = $VBox/TitleRow/TitleLabel
@onready var _gold_label: Label = $VBox/TitleRow/GoldLabel
@onready var _shop_list: ItemList = $VBox/Split/Left/ShopList
@onready var _player_list: ItemList = $VBox/Split/Right/PlayerList
@onready var _buy_btn: Button = $VBox/Split/Left/BuyBtn
@onready var _sell_btn: Button = $VBox/Split/Right/SellBtn
@onready var _close_btn: Button = $VBox/CloseBtn
@onready var _info_label: Label = $VBox/InfoLabel

# Cached filtered arrays for the two lists.
var _shop_entries: Array = []  # Array of {item_id, stock, price}
var _player_entries: Array = []  # Array of {item_id, count, sell_price}


func _ready() -> void:
	visible = false
	_shop_list.item_selected.connect(_on_shop_item_selected)
	_player_list.item_selected.connect(_on_player_item_selected)
	_buy_btn.pressed.connect(_on_buy)
	_sell_btn.pressed.connect(_on_sell)
	_close_btn.pressed.connect(close)


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
	if event.is_action_pressed("ui_cancel") or (_player != null and event.is_action_pressed(PlayerActions.action(_player.player_id, PlayerActions.INVENTORY))):
		close()
		get_viewport().set_input_as_handled()


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
