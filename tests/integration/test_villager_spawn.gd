## Integration test: F8 spawns a Villager near the player, the spawn is
## persisted in `region.npcs_scatter`, and `interact()` opens the
## per-viewport DialogueBox with one of the canonical lines.
extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")


func _find_world(_node: Node) -> WorldRoot:
	var w: World = World.instance()
	if w == null:
		return null
	return w.get_player_world(0)


func _find_villager(world: WorldRoot) -> Villager:
	for c in world.entities.get_children():
		if c is Villager:
			return c
		if c.is_in_group(&"scattered_npcs") and c.get_script() != null \
				and c.get_script().resource_path.ends_with("villager.gd"):
			return c
	return null


func test_f8_spawns_villager_persists_and_dialogues() -> void:
	WorldManager.reset(42)
	var game := _GameScene.instantiate()
	add_child_autoqfree(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var world := _find_world(game)
	assert_not_null(world, "WorldRoot found")
	assert_not_null(World.instance().get_player(0), "player exists")

	# Sanity: nothing scattered yet.
	var initial_count: int = world._region.npcs_scatter.size()

	# Trigger F8 spawn directly (not through PauseManager) so the test
	# doesn't depend on input dispatch.
	world.debug_spawn_villager()
	await get_tree().process_frame
	await get_tree().process_frame

	# Persistence: a villager entry should be in npcs_scatter now.
	var added: Array = []
	for entry in world._region.npcs_scatter:
		if typeof(entry) == TYPE_DICTIONARY and entry.get("kind", &"") == &"villager":
			added.append(entry)
	assert_true(added.size() >= 1,
		"scatter has at least one villager (was %d, now %d)"
			% [initial_count, world._region.npcs_scatter.size()])

	# Instantiation: a Villager node should exist under entities.
	var v: Villager = _find_villager(world)
	assert_not_null(v, "villager node spawned")

	# Interact: should open the dialogue box on this player's WorldRoot.
	v.interact(World.instance().get_player(0))
	assert_true(world.dialogue_open(), "dialogue opened after interact")

	# Dialogue text should be one of the canonical lines.
	var box: DialogueBox = world.get_node_or_null("DialogueBox") as DialogueBox
	assert_not_null(box, "dialogue box created")
	var body: String = box.get_node("Panel").get_node("VBoxContainer").get_node("Body").text
	assert_true(VillagerDialogue.LINES.has(body),
		"dialogue body is one of the canonical lines, got: %s" % body)

	# Hide via WorldRoot API.
	world.hide_dialogue()
	assert_false(world.dialogue_open(), "dialogue closes via hide_dialogue")
