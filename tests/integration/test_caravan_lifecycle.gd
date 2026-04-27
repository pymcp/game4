## Integration tests for caravan system lifecycle:
## - caravan spawns on overworld with the player
## - caravan_data is attached
## - warrior not recruited by default
## - debug_add_all_party_members() recruits warrior + blacksmith
extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")

var _game: Node = null


func before_each() -> void:
	WorldManager.reset(202402)
	_game = _GameScene.instantiate()
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	_game = null


func test_caravan_exists_on_overworld() -> void:
	var world := World.instance()
	assert_not_null(world, "World should exist")
	var caravan := world.get_caravan(0)
	assert_not_null(caravan, "P1 caravan should exist on overworld")


func test_caravan_has_caravan_data() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	var caravan := world.get_caravan(0)
	if caravan == null:
		pending("Caravan not available")
		return
	assert_not_null(caravan.caravan_data, "Caravan should have caravan_data reference")


func test_caravan_data_accessible_on_player() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	var player := world.get_player(0)
	assert_not_null(player, "Player should exist")
	assert_not_null(player.caravan_data, "Player should have caravan_data set")


func test_warrior_not_recruited_initially() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	var cd := world.get_caravan_data(0)
	assert_not_null(cd, "CaravanData should exist")
	assert_false(cd.has_member(&"warrior"), "Warrior should not be recruited initially")


func test_debug_add_all_party_members_recruits_warrior_and_blacksmith() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	world.debug_add_all_party_members()
	await get_tree().process_frame
	var cd := world.get_caravan_data(0)
	assert_true(cd.has_member(&"warrior"), "Warrior should be recruited after debug call")
	assert_true(cd.has_member(&"blacksmith"), "Blacksmith should be recruited after debug call")
