## ShopRegistry
##
## Static registry for shop data.  Each shop has a buy_markup, sell_discount,
## and a list of items with stock + optional price overrides.
## Loaded from resources/shops.json.
class_name ShopRegistry
extends RefCounted

const _PATH: String = "res://resources/shops.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_load_json()
	_loaded = true


static func _load_json() -> void:
	_data = {}
	var f: FileAccess = FileAccess.open(_PATH, FileAccess.READ)
	if f == null:
		return
	var parser := JSON.new()
	if parser.parse(f.get_as_text()) != OK:
		push_error("ShopRegistry: JSON parse error: %s" % parser.get_error_message())
		return
	var result: Variant = parser.data
	if result is Dictionary:
		_data = result


static func reset() -> void:
	_data = {}
	_loaded = false


static func get_raw_data() -> Dictionary:
	_ensure_loaded()
	return _data.duplicate(true)


static func save_data(data: Dictionary) -> void:
	_data = data.duplicate(true)
	_loaded = true
	var f: FileAccess = FileAccess.open(_PATH, FileAccess.WRITE)
	if f == null:
		push_error("ShopRegistry: cannot write %s" % _PATH)
		return
	f.store_string(JSON.stringify(_data, "\t"))


static func all_ids() -> Array:
	_ensure_loaded()
	var keys: Array = _data.keys()
	keys.sort()
	return keys


static func has_shop(shop_id: String) -> bool:
	_ensure_loaded()
	return _data.has(shop_id)


static func get_shop(shop_id: String) -> Dictionary:
	_ensure_loaded()
	return _data.get(shop_id, {})


## Returns the final buy price for an item in a given shop.
## Formula: item_buy_price × buy_markup, with optional per-item override.
static func buy_price(shop_id: String, item_id: StringName) -> int:
	_ensure_loaded()
	var shop: Dictionary = _data.get(shop_id, {})
	var markup: float = float(shop.get("buy_markup", 1.5))
	var items: Array = shop.get("items", [])
	for entry in items:
		if StringName(entry.get("item_id", "")) == item_id:
			var override: int = int(entry.get("price_override", -1))
			if override >= 0:
				return override
			var def: ItemDefinition = ItemRegistry.get_item(item_id)
			if def != null and def.buy_price > 0:
				return int(ceil(float(def.buy_price) * markup))
			return 0
	return 0


## Returns the final sell price for an item at a given shop.
## Formula: item_sell_price × sell_discount.
static func sell_price(shop_id: String, item_id: StringName) -> int:
	_ensure_loaded()
	var shop: Dictionary = _data.get(shop_id, {})
	var discount: float = float(shop.get("sell_discount", 0.5))
	var def: ItemDefinition = ItemRegistry.get_item(item_id)
	if def == null or def.sell_price <= 0:
		return 0
	return int(floor(float(def.sell_price) * discount))
