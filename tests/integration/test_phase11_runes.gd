extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")


func _find_world(_node: Node) -> WorldRoot:
	var w: World = World.instance()
	if w == null:
		return null
	return w.get_player_world(0)


func test_runes_generate_and_inject_quest_interactables() -> void:
	# Find a seed where region (0,0) has at least one rune.
	var found_seed: int = -1
	var rune_cell: Vector2i = Vector2i.ZERO
	for s in [1, 2, 3, 5, 7, 11, 17, 23, 31, 42, 99, 137, 271, 333, 511, 999]:
		WorldManager.reset(s)
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

	# Verify QuestInteractable nodes were injected for each rune.
	var live_rune: Dictionary = world._region.runes[0]
	var expected_oid: String = "rune_interactable_%d_%d" % [
		live_rune["cell"].x, live_rune["cell"].y
	]
	var found_qi: QuestInteractable = null
	for child in world.entities.get_children():
		if child is QuestInteractable and child.objective_id == expected_oid:
			found_qi = child
			break
	assert_not_null(found_qi, "QuestInteractable injected for first rune")
	assert_true(found_qi.interact_text.contains("ancient symbol"),
		"rune text is flavour, got: '%s'" % found_qi.interact_text)

	# Interact with the rune and verify flag is set.
	GameState.set_flag("rune_tile_touched", false)
	var player: PlayerController = World.instance().get_player(0)
	found_qi.interact(player)
	assert_true(GameState.get_flag("rune_tile_touched"),
		"rune_tile_touched flag set after interaction")
