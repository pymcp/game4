## Phase 8c: enter & exit a dungeon at runtime via WorldRoot + MapManager.
extends GutTest

const GameScene: PackedScene = preload("res://scenes/main/Game.tscn")

var game: Node = null
var world: WorldRoot = null


func before_each() -> void:
	MapManager.reset()
	game = GameScene.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var coord: World = (game as Game)._world
	assert_not_null(coord, "World coordinator missing")
	world = coord.get_player_world(0)
	assert_not_null(world)


func after_each() -> void:
	MapManager.reset()


# --- helpers ----------------------------------------------------------

func _find_region_with_entrance() -> Region:
	# Search nearby regions for one with an entrance; otherwise generate
	# a wider area until one appears.
	for ry in range(-2, 3):
		for rx in range(-2, 3):
			var rid := Vector2i(rx, ry)
			var r: Region = WorldManager.get_or_generate(rid)
			if r != null and r.dungeon_entrances.size() > 0:
				return r
	return null


# --- tests ------------------------------------------------------------

func test_markers_exist_for_entrances() -> void:
	var count := 0
	for c in world.decorations.get_children():
		if c.has_meta("dungeon_entrance_cell"):
			count += 1
	assert_eq(count, world._region.dungeon_entrances.size(),
		"one marker per entrance")


func test_get_entrance_at_returns_metadata() -> void:
	if world._region.dungeon_entrances.is_empty():
		pass_test("region has no entrances")
		return
	var e: Dictionary = world._region.dungeon_entrances[0]
	var got: Dictionary = world.get_entrance_at(e["cell"])
	assert_false(got.is_empty())
	assert_eq(got.get("kind", &""), &"dungeon")


func test_enter_interior_swaps_scene() -> void:
	var region: Region = _find_region_with_entrance()
	if region == null:
		pass_test("no entrances found in scan range")
		return
	var entry: Dictionary = region.dungeon_entrances[0]
	var cell: Vector2i = entry["cell"]
	var map_id: StringName = MapManager.make_id(region.region_id, cell, 1)
	var interior: InteriorMap = MapManager.get_or_generate(map_id, region.region_id, cell, 1)
	# Drive the full transition through World so WorldRoot.apply_view() runs.
	var coord: World = World.instance()
	coord.transition_player(0, &"dungeon", region, interior)
	await get_tree().process_frame
	# Update world ref — player moved to a new WorldRoot instance.
	world = coord.get_player_world(0)
	assert_true(world.is_in_interior(), "world should be in interior")
	assert_not_null(world._interior)
	# Player should land at or very near the interior entry cell.
	# find_safe_spawn_cell may shift by 1 tile to avoid obstacles.
	var p1: PlayerController = coord.get_player(0)
	var p1_tile: Vector2i = Vector2i(
			int(floor(p1.position.x / float(WorldConst.TILE_PX))),
			int(floor(p1.position.y / float(WorldConst.TILE_PX))))
	var dist: int = abs(p1_tile.x - interior.entry_cell.x) + abs(p1_tile.y - interior.entry_cell.y)
	assert_true(dist <= 2,
			"player should land within 2 tiles of entry_cell, got %s vs %s" \
			% [str(p1_tile), str(interior.entry_cell)])


func test_enter_then_exit_restores_overworld() -> void:
	var region: Region = _find_region_with_entrance()
	if region == null:
		pass_test("no entrances found in scan range")
		return
	var entry: Dictionary = region.dungeon_entrances[0]
	var cell: Vector2i = entry["cell"]
	var saved_p1: Vector2 = world.p1.position
	var map_id: StringName = MapManager.make_id(region.region_id, cell, 1)
	MapManager.set_active(map_id, region.region_id, cell, 1)
	assert_true(world.is_in_interior())
	MapManager.exit_to_overworld()
	assert_false(world.is_in_interior())
	# Position restored.
	assert_almost_eq(world.p1.position.x, saved_p1.x, 0.5)
	assert_almost_eq(world.p1.position.y, saved_p1.y, 0.5)


func test_interior_npcs_spawn() -> void:
	var region: Region = _find_region_with_entrance()
	if region == null:
		pass_test("no entrances found")
		return
	var entry: Dictionary = region.dungeon_entrances[0]
	var cell: Vector2i = entry["cell"]
	var map_id: StringName = MapManager.make_id(region.region_id, cell, 1)
	MapManager.set_active(map_id, region.region_id, cell, 1)
	# queue_free is deferred — wait a frame for overworld NPCs to drop.
	await get_tree().process_frame
	await get_tree().process_frame
	var interior: InteriorMap = world._active_interior
	var npc_count := 0
	for c in world.entities.get_children():
		if c is NPC:
			npc_count += 1
	assert_eq(npc_count, interior.npcs_scatter.size(),
		"interior NPCs spawned to match scatter list")
