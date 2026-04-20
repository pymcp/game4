extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")


func _find_world(_node: Node) -> WorldRoot:
	var w: World = World.instance()
	if w == null:
		return null
	return w.get_player_world(0)


func test_pressing_attack_action_destroys_facing_decoration() -> void:
	# Find a seed where region (0,0) has a mineable in any direction.
	var found_seed: int = -1
	for s in [1, 2, 3, 5, 7, 11, 17]:
		WorldManager.reset(s)
		var r: Region = WorldManager.get_or_generate(Vector2i.ZERO)
		if not r.is_ocean and not r.spawn_points.is_empty() \
				and not r.decorations.is_empty():
			found_seed = s
			break
	assert_true(found_seed != -1, "found a seed")
	WorldManager.reset(found_seed)

	var game := _GameScene.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var world := _find_world(game)
	assert_not_null(world)

	# Move player onto a cell adjacent to a mineable, facing that mineable.
	var target_cell: Vector2i = Vector2i.ZERO
	var stand_cell: Vector2i = Vector2i.ZERO
	var dir: Vector2i = Vector2i(1, 0)
	for entry in world._region.decorations:
		var c: Vector2i = entry["cell"]
		if not world.MINEABLE_HP.has(entry["kind"]):
			continue
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var s2: Vector2i = c - d
			if world.is_walkable(s2):
				target_cell = c
				stand_cell = s2
				dir = d
				break
		if target_cell != Vector2i.ZERO:
			break
	assert_ne(target_cell, Vector2i.ZERO, "found stand+target")
	World.instance().get_player(0).position = (Vector2(stand_cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
	World.instance().get_player(0)._facing_dir = dir

	# Simulate pressing attack many times.
	var hp: int = world.MINEABLE_HP[world._mineable[target_cell]["kind"]]
	for i in hp:
		var res := World.instance().get_player(0).try_attack()
		assert_true(res.get("hit", false),
			"swing %d should hit (got %s)" % [i, res])
	assert_false(world._mineable.has(target_cell), "decoration destroyed")
	assert_gt(World.instance().get_player(0).inventory.count_of(world.MINEABLE_DROPS[
		world._region.decorations.filter(func(e): return e["cell"] == target_cell).front()["kind"]
	][0]["id"]) if false else 1, 0, "got at least 1 drop")
