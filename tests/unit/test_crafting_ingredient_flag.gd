extends GutTest

func before_each() -> void:
	ItemRegistry.reset()

func test_wood_is_crafting_ingredient() -> void:
	var item := ItemRegistry.get_item(&"wood")
	assert_not_null(item, "wood should exist")
	assert_true(item.is_crafting_ingredient, "wood should be a crafting ingredient")

func test_stone_is_crafting_ingredient() -> void:
	var item := ItemRegistry.get_item(&"stone")
	assert_not_null(item)
	assert_true(item.is_crafting_ingredient)

func test_fiber_is_crafting_ingredient() -> void:
	var item := ItemRegistry.get_item(&"fiber")
	assert_not_null(item)
	assert_true(item.is_crafting_ingredient)

func test_iron_ore_is_crafting_ingredient() -> void:
	var item := ItemRegistry.get_item(&"iron_ore")
	assert_not_null(item)
	assert_true(item.is_crafting_ingredient)

func test_copper_ore_is_crafting_ingredient() -> void:
	var item := ItemRegistry.get_item(&"copper_ore")
	assert_not_null(item)
	assert_true(item.is_crafting_ingredient)

func test_gold_ore_is_crafting_ingredient() -> void:
	var item := ItemRegistry.get_item(&"gold_ore")
	assert_not_null(item)
	assert_true(item.is_crafting_ingredient)

func test_sword_is_not_crafting_ingredient() -> void:
	var item := ItemRegistry.get_item(&"sword")
	assert_not_null(item)
	assert_false(item.is_crafting_ingredient, "sword should NOT be a crafting ingredient")

func test_armor_is_not_crafting_ingredient() -> void:
	var item := ItemRegistry.get_item(&"armor")
	assert_not_null(item)
	assert_false(item.is_crafting_ingredient)
