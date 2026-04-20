extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")


func _find_world(_node: Node) -> WorldRoot:
	var w: World = World.instance()
	if w == null:
		return null
	return w.get_player_world(0)


func test_boat_spawns_and_player_can_board() -> void:
	var game := _GameScene.instantiate()
	add_child_autoqfree(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var world := _find_world(game)
	assert_not_null(world, "WorldRoot found")
	assert_not_null(World.instance().get_player(0), "player spawned")
	assert_not_null(world._boat, "boat spawned")
	assert_true(world._is_water_cell(world._boat.dock_cell), "boat dock cell is water")
	assert_true(world._has_walkable_neighbour(world._boat.dock_cell),
		"dock has walkable neighbour")

	var player: PlayerController = World.instance().get_player(0)
	var boat: Boat = world._boat

	# Board: invoke interact directly (avoids input plumbing).
	assert_true(boat.interact(player), "board succeeds")
	assert_true(player.is_sailing, "player is sailing after board")

	# In sailing mode, water cell should be passable.
	assert_true(player._passable(boat.dock_cell), "water passable while sailing")

	# Disembark: snaps player to a walkable land cell.
	assert_true(boat.interact(player), "disembark succeeds")
	assert_false(player.is_sailing, "no longer sailing")
	var my_cell := Vector2i(
		int(floor(player.position.x / float(WorldConst.TILE_PX))),
		int(floor(player.position.y / float(WorldConst.TILE_PX))))
	assert_true(world.is_walkable(my_cell), "player on walkable land after disembark")
