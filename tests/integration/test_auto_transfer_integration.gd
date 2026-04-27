## Integration tests for auto-transfer: crafting ingredients move from
## player inventory to caravan inventory on trigger_overworld_transfer().
## Non-ingredient items (equipment, weapons) must stay in player inventory.
extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")

var _game: Node = null


func before_each() -> void:
	WorldManager.reset(202402)
	ItemRegistry.reset()
	_game = _GameScene.instantiate()
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	_game = null


func test_iron_ore_transfers_on_trigger() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	var player := world.get_player(0)
	if player == null or player.caravan_data == null:
		pending("Player or caravan_data not available")
		return
	player.inventory.add(&"iron_ore", 3)
	player.trigger_overworld_transfer()
	assert_eq(player.inventory.count_of(&"iron_ore"), 0,
			"iron_ore should leave player inventory")
	assert_eq(player.caravan_data.inventory.count_of(&"iron_ore"), 3,
			"iron_ore should be in caravan inventory")


func test_sword_stays_in_player_inventory() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	var player := world.get_player(0)
	if player == null or player.caravan_data == null:
		pending("Player or caravan_data not available")
		return
	player.inventory.add(&"sword", 1)
	player.trigger_overworld_transfer()
	assert_eq(player.inventory.count_of(&"sword"), 1,
			"sword should stay in player inventory")
	assert_eq(player.caravan_data.inventory.count_of(&"sword"), 0,
			"sword should not appear in caravan inventory")


func test_mixed_transfer() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	var player := world.get_player(0)
	if player == null or player.caravan_data == null:
		pending("Player or caravan_data not available")
		return
	player.inventory.add(&"stone", 5)
	player.inventory.add(&"helmet", 1)
	player.trigger_overworld_transfer()
	assert_eq(player.inventory.count_of(&"stone"), 0, "stone should transfer")
	assert_eq(player.inventory.count_of(&"helmet"), 1, "helmet should stay")
	assert_eq(player.caravan_data.inventory.count_of(&"stone"), 5,
			"stone should be in caravan inventory")
