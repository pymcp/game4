## Tests for Phase 3: Economy, Consumable, Shop.
extends GutTest


var _item_backup: Dictionary = {}
var _shop_backup: Dictionary = {}


func before_all() -> void:
	ItemRegistry.reset()
	_item_backup = ItemRegistry.get_raw_data().duplicate(true)
	ShopRegistry.reset()
	_shop_backup = ShopRegistry.get_raw_data().duplicate(true)


func before_each() -> void:
	ItemRegistry.reset()
	ShopRegistry.reset()


func after_all() -> void:
	ItemRegistry.save_data(_item_backup)
	ItemRegistry.reset()
	ShopRegistry.save_data(_shop_backup)
	ShopRegistry.reset()


# ═══════════════════════════════════════════════════════════════════════
#  3A: Economy fields
# ═══════════════════════════════════════════════════════════════════════

func test_buy_sell_price_parsed() -> void:
	# Items with buy_price/sell_price in JSON should parse correctly.
	var raw: Dictionary = ItemRegistry.get_raw_data()
	# Gold item has no explicit buy/sell price — should default to 0.
	var gold_def: ItemDefinition = ItemRegistry.get_item(&"gold")
	assert_not_null(gold_def, "gold item should exist")
	assert_eq(gold_def.buy_price, 0, "gold buy_price defaults to 0")
	assert_eq(gold_def.sell_price, 0, "gold sell_price defaults to 0")


func test_buy_sell_price_round_trip() -> void:
	var raw: Dictionary = ItemRegistry.get_raw_data()
	raw["sword"]["buy_price"] = 50
	raw["sword"]["sell_price"] = 25
	ItemRegistry.save_data(raw)
	ItemRegistry.reset()
	var sword: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_eq(sword.buy_price, 50, "buy_price persists")
	assert_eq(sword.sell_price, 25, "sell_price persists")


# ═══════════════════════════════════════════════════════════════════════
#  3B: Consumable
# ═══════════════════════════════════════════════════════════════════════

func test_consumable_fields_parsed() -> void:
	var herb: ItemDefinition = ItemRegistry.get_item(&"healing_herb")
	assert_not_null(herb, "healing_herb should exist")
	assert_true(herb.consumable, "healing_herb is consumable")
	assert_eq(herb.heal_amount, 3, "healing_herb heals 3")


func test_fennel_root_consumable() -> void:
	var root: ItemDefinition = ItemRegistry.get_item(&"fennel_root")
	assert_not_null(root)
	assert_true(root.consumable)
	assert_eq(root.heal_amount, 1)


func test_non_consumable_sword() -> void:
	var sword: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_not_null(sword)
	assert_false(sword.consumable, "sword is not consumable")
	assert_eq(sword.heal_amount, 0)


func test_consumable_description_contains_heal() -> void:
	var herb: ItemDefinition = ItemRegistry.get_item(&"healing_herb")
	assert_not_null(herb)
	assert_true(herb.description.find("Heal") >= 0,
		"description should mention healing: got '%s'" % herb.description)


# ═══════════════════════════════════════════════════════════════════════
#  3C: Shop Registry
# ═══════════════════════════════════════════════════════════════════════

func test_shop_registry_loads() -> void:
	var ids: Array = ShopRegistry.all_ids()
	assert_true(ids.size() >= 1, "should have at least 1 shop")
	assert_true(ShopRegistry.has_shop("general_store"))


func test_shop_get_data() -> void:
	var shop: Dictionary = ShopRegistry.get_shop("general_store")
	assert_false(shop.is_empty(), "general_store should have data")
	assert_true(shop.has("buy_markup"))
	assert_true(shop.has("sell_discount"))
	assert_true(shop.has("items"))


func test_shop_buy_price() -> void:
	# Set up a known buy_price on sword.
	var raw: Dictionary = ItemRegistry.get_raw_data()
	raw["sword"]["buy_price"] = 100
	ItemRegistry.save_data(raw)
	ItemRegistry.reset()
	var price: int = ShopRegistry.buy_price("general_store", &"sword")
	# buy_markup is 1.5, so 100 * 1.5 = 150.
	assert_eq(price, 150, "buy price = base * markup")


func test_shop_buy_price_override() -> void:
	# healing_herb has price_override: 5 in shops.json.
	var price: int = ShopRegistry.buy_price("general_store", &"healing_herb")
	assert_eq(price, 5, "price_override takes precedence")


func test_shop_sell_price_zero_for_no_sell() -> void:
	# Gold item has no sell_price — should return 0.
	var price: int = ShopRegistry.sell_price("general_store", &"gold")
	assert_eq(price, 0, "no sell_price means 0")


func test_shop_save_data_round_trip() -> void:
	var raw: Dictionary = ShopRegistry.get_raw_data()
	raw["test_shop"] = {"display_name": "Test", "buy_markup": 2.0,
		"sell_discount": 0.3, "items": []}
	ShopRegistry.save_data(raw)
	ShopRegistry.reset()
	assert_true(ShopRegistry.has_shop("test_shop"), "new shop persists")
	var shop: Dictionary = ShopRegistry.get_shop("test_shop")
	assert_eq(shop["buy_markup"], 2.0)


# ═══════════════════════════════════════════════════════════════════════
#  3D: ShopEditor
# ═══════════════════════════════════════════════════════════════════════

func test_shop_editor_loads_data() -> void:
	var editor := ShopEditor.new()
	add_child_autofree(editor)
	assert_true(editor._data.size() > 0, "should load shop data")
	assert_false(editor.is_dirty())


func test_shop_editor_add_shop() -> void:
	var editor := ShopEditor.new()
	add_child_autofree(editor)
	var before: int = editor._data.size()
	editor._on_add()
	assert_eq(editor._data.size(), before + 1)
	assert_true(editor.is_dirty())


func test_shop_editor_delete_shop() -> void:
	var editor := ShopEditor.new()
	add_child_autofree(editor)
	editor._on_add()
	var before: int = editor._data.size()
	editor._on_delete()
	assert_eq(editor._data.size(), before - 1)


func test_shop_editor_save_revert() -> void:
	var editor := ShopEditor.new()
	add_child_autofree(editor)
	editor._on_add()
	assert_true(editor.is_dirty())
	editor.save()
	assert_false(editor.is_dirty(), "clean after save")
	editor._on_add()
	editor.revert()
	assert_false(editor.is_dirty(), "clean after revert")


func test_shop_editor_add_item_to_shop() -> void:
	var editor := ShopEditor.new()
	add_child_autofree(editor)
	if editor._shop_list.item_count > 0:
		editor._shop_list.select(0)
		editor._on_shop_selected(0)
		var id: String = editor._selected_id
		var before: int = editor._data[id].get("items", []).size()
		editor._on_add_item()
		assert_eq(editor._data[id]["items"].size(), before + 1)


func test_shop_editor_get_marks() -> void:
	var editor := ShopEditor.new()
	add_child_autofree(editor)
	assert_typeof(editor.get_marks(), TYPE_ARRAY)
