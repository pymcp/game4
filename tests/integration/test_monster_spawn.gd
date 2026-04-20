## Tests F8 spawning a target-dummy [Monster] alongside the villager
## and the chase-toward-nearest-player behavior.
extends GutTest

const _GameScene: PackedScene = preload("res://scenes/main/Game.tscn")


func _await_world() -> Node:
	var game: Node = _GameScene.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game


func test_f8_spawns_monster_in_each_world_instance() -> void:
	var game: Node = await _await_world()
	var world: World = World.instance()
	assert_not_null(world, "World coordinator must exist")

	world.debug_spawn_monster()
	await get_tree().process_frame

	# Both players begin in the same overworld WorldRoot, so the per-player
	# fan-out spawns a monster for each — verify both instances host them.
	for pid in range(2):
		var inst: WorldRoot = world.get_player_world(pid)
		var monsters: Array = inst.entities.get_children().filter(
				func(n: Node) -> bool: return n is Monster)
		assert_gte(monsters.size(), 1,
				"Player %d's WorldRoot should contain a Monster" % pid)


func test_monster_chases_nearest_player() -> void:
	var game: Node = await _await_world()
	var world: World = World.instance()
	var inst: WorldRoot = world.get_player_world(0)
	var player: PlayerController = world.get_player(0)
	assert_not_null(player)

	# Spawn a monster two tiles east of the player.
	var pcell: Vector2i = Vector2i(
			int(floor(player.position.x / float(WorldConst.TILE_PX))),
			int(floor(player.position.y / float(WorldConst.TILE_PX))))
	var spawn_cell: Vector2i = inst.find_safe_spawn_cell(
			pcell + Vector2i(2, 0), 4, true)
	var entry: Dictionary = {"kind": &"monster", "cell": spawn_cell}
	inst._spawn_monster(entry)
	await get_tree().process_frame

	var monster: Monster = inst.entities.get_children().filter(
			func(n: Node) -> bool: return n is Monster)[0]
	var d_before: float = monster.position.distance_to(player.position)

	# Tick a few process frames so monster.gd._process() runs.
	for i in range(8):
		await get_tree().process_frame

	var d_after: float = monster.position.distance_to(player.position)
	assert_lt(d_after, d_before,
			"Monster should have moved closer to its target player")
