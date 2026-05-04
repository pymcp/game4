## Integration tests for the housing construction system.
## Tests cover: builder recruitment, placement creation, cancel, confirm, and material deduction.
extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")

var _game: Node = null


func before_each() -> void:
	WorldManager.reset(99991)
	PartyMemberRegistry.reset()
	_game = _GameScene.instantiate()
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	_game = null


func test_builder_registered_after_debug_recruit() -> void:
	var world := World.instance()
	assert_not_null(world, "World should exist")
	world.debug_add_all_party_members()
	var cd: CaravanData = world.get_caravan_data(0)
	assert_not_null(cd)
	assert_true(cd.has_member(&"builder"), "builder should be recruited after debug_add_all_party_members")


func test_start_house_placement_creates_placer() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	world.debug_add_all_party_members()
	world.start_house_placement(0, &"house_basic")
	await get_tree().process_frame
	var inst: WorldRoot = world.get_player_world(0)
	assert_not_null(inst)
	var placer: Node = inst.get_node_or_null("HousePlacer_P0")
	assert_not_null(placer, "HousePlacer_P0 should exist after start_house_placement")


func test_cancel_removes_placer() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	world.debug_add_all_party_members()
	world.start_house_placement(0, &"house_basic")
	await get_tree().process_frame
	world._on_house_cancelled(0)
	await get_tree().process_frame
	var inst: WorldRoot = world.get_player_world(0)
	var placer: Node = inst.get_node_or_null("HousePlacer_P0") if inst != null else null
	assert_null(placer, "placer should be freed after cancel")


func test_confirm_adds_house_to_region() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	world.debug_add_all_party_members()
	var cd: CaravanData = world.get_caravan_data(0)
	assert_not_null(cd)
	cd.inventory.add(&"wood", 10)
	var region: Region = WorldManager.get_or_generate(Vector2i.ZERO)
	var before_count: int = region.dungeon_entrances.size()
	var cell := Vector2i(10, 10)
	world.start_house_placement(0, &"house_basic")
	await get_tree().process_frame
	world._on_house_confirmed(0, cell)
	await get_tree().process_frame
	assert_eq(region.dungeon_entrances.size(), before_count + 1,
			"region should have one more entrance after placement")
	var last: Dictionary = region.dungeon_entrances.back()
	assert_eq(last.get("kind", &""), &"house")
	assert_eq(last.get("cell", Vector2i(-1, -1)), cell)


func test_confirm_deducts_wood() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	world.debug_add_all_party_members()
	var cd: CaravanData = world.get_caravan_data(0)
	assert_not_null(cd)
	cd.inventory.add(&"wood", 10)
	assert_eq(cd.inventory.count_of(&"wood"), 10)
	world.start_house_placement(0, &"house_basic")
	await get_tree().process_frame
	world._on_house_confirmed(0, Vector2i(10, 10))
	await get_tree().process_frame
	assert_eq(cd.inventory.count_of(&"wood"), 0, "10 wood should be consumed on confirm")
