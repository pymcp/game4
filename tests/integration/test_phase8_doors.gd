extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")


func _find_world(_node: Node) -> WorldRoot:
	var w: World = World.instance()
	if w == null:
		return null
	return w.get_player_world(0)


func _await_view_for(world: WorldRoot, kind: StringName, max_frames: int = 8) -> bool:
	for _i in max_frames:
		if ViewManager.get_view_kind(0) == kind:
			return true
		await get_tree().process_frame
	return ViewManager.get_view_kind(0) == kind


func test_dungeon_enter_and_exit_via_door() -> void:
	# Force a deterministic seed where region (0,0) has at least one
	# dungeon entrance. Walk a few seeds until we find one.
	var found_seed: int = -1
	for s in [1, 2, 3, 7, 11, 17, 23, 31, 42, 99, 101, 137, 271, 333, 511]:
		WorldManager.reset(s)
		var r: Region = WorldManager.get_or_generate(Vector2i.ZERO)
		var land: Region = r
		if r.is_ocean or r.spawn_points.is_empty():
			# Search neighbours like WorldRoot does.
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var c: Region = WorldManager.get_or_generate(Vector2i(dx, dy))
					if not c.is_ocean and not c.spawn_points.is_empty() \
							and not c.dungeon_entrances.is_empty():
						land = c
						break
				if not land.dungeon_entrances.is_empty():
					break
		if not land.dungeon_entrances.is_empty():
			found_seed = s
			break
	assert_true(found_seed != -1, "found a seed with a dungeon entrance")
	WorldManager.reset(found_seed)

	var game := _GameScene.instantiate()
	add_child_autoqfree(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var world := _find_world(game)
	assert_not_null(world, "WorldRoot found")
	assert_eq(ViewManager.get_view_kind(0), &"overworld",
		"start on overworld")

	# Pick an entrance from the rendered region and teleport player there.
	assert_false(world._region.dungeon_entrances.is_empty(),
		"region has at least one dungeon entrance")
	var entrance_cell: Vector2i = world._region.dungeon_entrances[0]["cell"]
	var px := float(WorldConst.TILE_PX)
	World.instance().get_player(0).position = (Vector2(entrance_cell) + Vector2(0.5, 0.5)) * px
	# Force a physics tick so WorldRoot._physics_process catches the new cell.
	await get_tree().physics_frame
	await get_tree().process_frame

	assert_true(await _await_view_for(world, &"dungeon"),
		"player entered dungeon view")
	# After transition, P0 has moved into the dungeon WorldRoot instance.
	world = World.instance().get_player_world(0)
	assert_not_null(world._interior, "interior loaded")
	assert_eq(world._interior.origin_cell, entrance_cell,
		"interior remembers origin_cell")

	# Now stand on the interior entry_cell (STAIRS_UP) to climb out.
	# On floor 1 with no parent map, this returns to the overworld.
	World.instance().get_player(0).position = (Vector2(world._interior.entry_cell)
		+ Vector2(0.5, 0.5)) * px
	await get_tree().physics_frame
	await get_tree().process_frame

	# Generous wait: cave-to-overworld stair use plays a fade transition
	# (~230ms fade-out) before the view switch fires.
	assert_true(await _await_view_for(world, &"overworld", 60),
		"player returned to overworld")
	# After exit the spawn override should land player at/near entrance_cell.
	var my_cell := Vector2i(
		int(floor(World.instance().get_player(0).position.x / px)),
		int(floor(World.instance().get_player(0).position.y / px)))
	var dist: int = abs(my_cell.x - entrance_cell.x) + abs(my_cell.y - entrance_cell.y)
	assert_true(dist <= 16, "player landed within 16 tiles of entrance, got %d" % dist)


func _await_view_for_pid(pid: int, kind: StringName, max_frames: int = 60) -> bool:
	for _i in max_frames:
		if ViewManager.get_view_kind(pid) == kind:
			return true
		await get_tree().process_frame
	return ViewManager.get_view_kind(pid) == kind


func test_one_player_leaves_cave_while_other_stays() -> void:
	# Same dungeon-seed search as the first test.
	var found_seed: int = -1
	for s in [1, 2, 3, 7, 11, 17, 23, 31, 42, 99, 101, 137, 271, 333, 511]:
		WorldManager.reset(s)
		var r: Region = WorldManager.get_or_generate(Vector2i.ZERO)
		if not r.is_ocean and not r.dungeon_entrances.is_empty():
			found_seed = s
			break
	assert_true(found_seed != -1, "seed with dungeon entrance")
	WorldManager.reset(found_seed)

	var game := _GameScene.instantiate()
	add_child_autoqfree(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var coord: World = World.instance()
	var overworld: WorldRoot = coord.get_player_world(0)
	var entrance_cell: Vector2i = overworld._region.dungeon_entrances[0]["cell"]
	var px := float(WorldConst.TILE_PX)

	# Both players step into the cave.
	coord.get_player(0).position = (Vector2(entrance_cell) + Vector2(0.5, 0.5)) * px
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_true(await _await_view_for_pid(0, &"dungeon"), "P0 in dungeon")

	coord.get_player(1).position = (Vector2(entrance_cell) + Vector2(0.5, 0.5)) * px
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_true(await _await_view_for_pid(1, &"dungeon"), "P1 in dungeon")

	var cave: WorldRoot = coord.get_player_world(0)
	assert_eq(coord.get_player_world(1), cave, "both players share cave instance")

	# P0 stands on stairs_up to climb out.
	coord.get_player(0).position = (Vector2(cave._interior.entry_cell)
		+ Vector2(0.5, 0.5)) * px
	await get_tree().physics_frame
	await get_tree().process_frame

	assert_true(await _await_view_for_pid(0, &"overworld", 60),
		"P0 returns to overworld while P1 stays in cave")
	assert_eq(ViewManager.get_view_kind(1), &"dungeon",
		"P1 still in dungeon view")
	assert_eq(coord.get_player_world(1), cave, "P1 still in cave instance")
	assert_true(coord.get_player_world(0) != cave, "P0 moved to a different instance")
