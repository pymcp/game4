extends GutTest

var _cd: CaravanData = null
var _player: PlayerController = null


func before_each() -> void:
	ItemRegistry.reset()
	_cd = CaravanData.new()
	# Use autofree (not add_child_autofree) to avoid _ready() crash —
	# PlayerController._ready() expects child scene nodes that don't exist
	# in unit tests. The method under test only needs inventory/caravan_data,
	# both of which are initialized at class-variable level before _ready().
	_player = autofree(PlayerController.new())
	_player.caravan_data = _cd


func test_iron_ore_transfers_to_caravan() -> void:
	_player.inventory.add(&"iron_ore", 5)
	_player.trigger_overworld_transfer()
	assert_eq(_player.inventory.count_of(&"iron_ore"), 0,
			"iron_ore should leave player inventory")
	assert_eq(_cd.inventory.count_of(&"iron_ore"), 5,
			"iron_ore should arrive in caravan inventory")


func test_wood_transfers_to_caravan() -> void:
	_player.inventory.add(&"wood", 3)
	_player.trigger_overworld_transfer()
	assert_eq(_player.inventory.count_of(&"wood"), 0)
	assert_eq(_cd.inventory.count_of(&"wood"), 3)


func test_sword_does_not_transfer() -> void:
	_player.inventory.add(&"sword", 1)
	_player.trigger_overworld_transfer()
	assert_eq(_player.inventory.count_of(&"sword"), 1,
			"sword should stay in player inventory")
	assert_eq(_cd.inventory.count_of(&"sword"), 0,
			"sword should not appear in caravan inventory")


func test_no_crash_when_caravan_data_null() -> void:
	_player.caravan_data = null
	_player.inventory.add(&"stone", 2)
	# Should not crash.
	_player.trigger_overworld_transfer()
	assert_eq(_player.inventory.count_of(&"stone"), 2,
			"stone should remain if no caravan_data")


func test_mixed_inventory_transfers_only_ingredients() -> void:
	_player.inventory.add(&"stone", 4)
	_player.inventory.add(&"helmet", 1)
	_player.inventory.add(&"fiber", 2)
	_player.trigger_overworld_transfer()
	assert_eq(_player.inventory.count_of(&"stone"), 0)
	assert_eq(_player.inventory.count_of(&"fiber"), 0)
	assert_eq(_player.inventory.count_of(&"helmet"), 1, "equipment stays")
	assert_eq(_cd.inventory.count_of(&"stone"), 4)
	assert_eq(_cd.inventory.count_of(&"fiber"), 2)
