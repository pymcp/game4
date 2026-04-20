extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")


func _find_world(_node: Node) -> WorldRoot:
	var w: World = World.instance()
	if w == null:
		return null
	return w.get_player_world(0)


func test_runes_generate_and_paint_and_trigger_on_step() -> void:
	# Find a seed where region (0,0) has at least one rune.
	var found_seed: int = -1
	var rune_cell: Vector2i = Vector2i.ZERO
	for s in [1, 2, 3, 5, 7, 11, 17, 23, 31, 42, 99, 137, 271, 333, 511, 999]:
		WorldManager.reset(s)
		# Scan a small window for a non-ocean region with runes.
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var r: Region = WorldManager.get_or_generate(Vector2i(dx, dy))
				if not r.is_ocean and not r.spawn_points.is_empty() \
						and not r.runes.is_empty():
					found_seed = s
					rune_cell = r.runes[0]["cell"]
					break
			if found_seed != -1:
				break
		if found_seed != -1:
			break
	assert_true(found_seed != -1, "found a seed with at least one rune")
	WorldManager.reset(found_seed)

	var game := _GameScene.instantiate()
	add_child_autoqfree(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var world := _find_world(game)
	assert_not_null(world, "WorldRoot found")
	assert_false(world._region.runes.is_empty(), "region has runes")

	# The first rune in the live region — verify overlay was painted.
	var live_rune: Dictionary = world._region.runes[0]
	var src_id: int = world.overlay.get_cell_source_id(live_rune["cell"])
	assert_eq(src_id, int(live_rune["source"]),
		"overlay layer painted with the rune's source id")

	# Step the player onto the rune.
	var px := float(WorldConst.TILE_PX)
	World.instance().get_player(0).position = (Vector2(live_rune["cell"]) + Vector2(0.5, 0.5)) * px
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_true(world.last_rune_message.contains("ancient symbol"),
		"rune message logged, got: '%s'" % world.last_rune_message)
