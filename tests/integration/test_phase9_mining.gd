extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")


func _find_world(_node: Node) -> WorldRoot:
	var w: World = World.instance()
	if w == null:
		return null
	return w.get_player_world(0)


func test_mine_decoration_until_destroyed_and_drops_loot() -> void:
	WorldManager.reset(7)
	var game := _GameScene.instantiate()
	add_child_autoqfree(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var world := _find_world(game)
	assert_not_null(world, "WorldRoot found")
	assert_false(world._mineable.is_empty(), "some mineables exist")

	# Pick the first tree (stable HP=3) — fall back to any mineable.
	var target_cell: Vector2i = Vector2i.ZERO
	var target_kind: StringName = &""
	var target_hp: int = 0
	for cell in world._mineable:
		var e: Dictionary = world._mineable[cell]
		if e["kind"] == &"tree":
			target_cell = cell
			target_kind = e["kind"]
			target_hp = e["hp"]
			break
	if target_kind == &"":
		var first: Vector2i = world._mineable.keys()[0]
		target_cell = first
		var e2: Dictionary = world._mineable[first]
		target_kind = e2["kind"]
		target_hp = e2["hp"]

	# Hit until the second-to-last blow.
	for i in range(target_hp - 1):
		var r1: Dictionary = world.mine_at(target_cell, 1)
		assert_true(r1.get("hit", false), "partial hit %d registered" % i)
		assert_false(r1.get("destroyed", false), "not destroyed yet")

	# Final blow destroys + drops.
	var r2: Dictionary = world.mine_at(target_cell, 1)
	assert_true(r2.get("destroyed", false), "destroyed on final hit")
	assert_eq(r2["kind"], target_kind, "kind preserved")
	var drops: Array = r2.get("drops", [])
	assert_false(drops.is_empty(), "drops generated")
	assert_true(drops[0].has("id"), "drop entry has id")
	assert_true(drops[0].has("count"), "drop entry has count")

	# Cell is no longer mineable; further hits return {hit:false}.
	var r3: Dictionary = world.mine_at(target_cell, 1)
	assert_false(r3.get("hit", false), "no further hits after destroyed")

	# Decoration tile cleared.
	assert_eq(world.decoration.get_cell_source_id(target_cell), -1,
		"decoration cell cleared")


func test_player_attack_hits_neighbour_decoration() -> void:
	WorldManager.reset(7)
	var game := _GameScene.instantiate()
	add_child_autoqfree(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var world := _find_world(game)
	var player: PlayerController = World.instance().get_player(0)
	# Find a mineable + walkable neighbour to stand on.
	var stand_cell: Vector2i = Vector2i(-1, -1)
	var target_cell: Vector2i = Vector2i(-1, -1)
	for cell in world._mineable:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + d
			if world.is_walkable(n):
				stand_cell = n
				target_cell = cell
				player._facing_dir = -d  # facing into the mineable
				break
		if stand_cell != Vector2i(-1, -1):
			break
	assert_true(stand_cell != Vector2i(-1, -1), "found mineable with walkable neighbour")

	var px := float(WorldConst.TILE_PX)
	player.position = (Vector2(stand_cell) + Vector2(0.5, 0.5)) * px
	# Hit until destroyed.
	var hits: int = 0
	while hits < 10:
		var r: Dictionary = player.try_attack()
		hits += 1
		if r.get("destroyed", false):
			break
	assert_true(hits < 10, "destroyed within 10 hits")
	# Inventory should now have at least one entry.
	var total: int = 0
	for slot in player.inventory.slots:
		if slot != null:
			total += int(slot["count"])
	assert_true(total > 0, "player got loot in inventory")
