## Unit tests for _generate_starting_region_features:
## - region (0,0) always has at least one dungeon entrance
## - path_tiles is non-empty
## - path_tiles connect spawn to entrance (first and last cell checks)
## - all path_tiles are DIRT terrain
extends GutTest


var _plan_cache: Dictionary = {}


func _make_region_00() -> Region:
	var plan: RegionPlan = WorldGenerator.plan_region(1337, Vector2i(0, 0), _plan_cache)
	return WorldGenerator.generate_region(1337, plan, _plan_cache)


func test_starting_region_has_dungeon_entrance() -> void:
	var region := _make_region_00()
	assert_gt(region.dungeon_entrances.size(), 0,
			"region (0,0) must always have at least one entrance")


func test_starting_region_has_path_tiles() -> void:
	var region := _make_region_00()
	assert_gt(region.path_tiles.size(), 0,
			"region (0,0) must have path_tiles connecting spawn to entrance")


func test_path_tiles_are_dirt() -> void:
	var region := _make_region_00()
	for c: Vector2i in region.path_tiles:
		var code: int = region.at(c)
		assert_eq(code, TerrainCodes.DIRT,
				"path tile %s should be DIRT, got %d" % [c, code])


func test_path_starts_near_spawn() -> void:
	var region := _make_region_00()
	if region.path_tiles.is_empty() or region.spawn_points.is_empty():
		return
	var first: Vector2i = region.path_tiles[0]
	var spawn: Vector2i = region.spawn_points[0]
	var dist: int = abs(first.x - spawn.x) + abs(first.y - spawn.y)
	assert_lte(dist, 2, "first path tile should be at or adjacent to spawn")


func test_path_ends_at_entrance() -> void:
	var region := _make_region_00()
	if region.path_tiles.is_empty() or region.dungeon_entrances.is_empty():
		return
	var entrance: Vector2i = region.dungeon_entrances[0]["cell"]
	var last: Vector2i = region.path_tiles[region.path_tiles.size() - 1]
	assert_eq(last, entrance, "last path tile should be the dungeon entrance cell")
