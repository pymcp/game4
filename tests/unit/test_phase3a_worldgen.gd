extends GutTest


func test_terrain_codes_walkable() -> void:
	assert_false(TerrainCodes.is_walkable(TerrainCodes.OCEAN))
	assert_false(TerrainCodes.is_walkable(TerrainCodes.WATER))
	assert_true(TerrainCodes.is_walkable(TerrainCodes.GRASS))
	assert_true(TerrainCodes.is_walkable(TerrainCodes.SAND))
	assert_true(TerrainCodes.is_walkable(TerrainCodes.ROCK))


func test_region_byte_roundtrip() -> void:
	var r := Region.new()
	assert_eq(r.tiles.size(), Region.SIZE * Region.SIZE)
	r.set_at(Vector2i(5, 9), TerrainCodes.SAND)
	assert_eq(r.at(Vector2i(5, 9)), TerrainCodes.SAND)
	# Out-of-bounds reads are OCEAN sentinel, writes are no-ops.
	assert_eq(r.at(Vector2i(-1, 0)), TerrainCodes.OCEAN)
	r.set_at(Vector2i(-1, 0), TerrainCodes.GRASS)  # should not crash


func test_biome_registry_default_grass() -> void:
	var b := BiomeRegistry.get_biome(&"grass")
	assert_not_null(b)
	assert_eq(b.id, &"grass")
	assert_eq(b.primary_terrain, TerrainCodes.GRASS)
	# Cached: second fetch returns same instance.
	assert_same(b, BiomeRegistry.get_biome(&"grass"))


func test_world_generator_plan_deterministic() -> void:
	var plans1: Dictionary = {}
	var plans2: Dictionary = {}
	var p1: RegionPlan = WorldGenerator.plan_region(424242, Vector2i(3, 7), plans1)
	var p2: RegionPlan = WorldGenerator.plan_region(424242, Vector2i(3, 7), plans2)
	assert_eq(p1.is_ocean, p2.is_ocean)
	assert_eq(p1.planned_biome, p2.planned_biome)


func test_world_generator_full_region_deterministic() -> void:
	var plans1: Dictionary = {}
	var plans2: Dictionary = {}
	# Force a land plan by trying seeds until we get one. PURE_OCEAN_CHANCE
	# is ~60% so a few attempts is enough.
	var seed_val := 12345
	var plan_a: RegionPlan = null
	for s in range(100):
		var p := WorldGenerator.plan_region(seed_val + s, Vector2i.ZERO, {})
		if not p.is_ocean:
			seed_val += s
			plan_a = WorldGenerator.plan_region(seed_val, Vector2i.ZERO, plans1)
			break
	assert_not_null(plan_a, "Could not find a land seed within 100 tries")
	var plan_b: RegionPlan = WorldGenerator.plan_region(seed_val, Vector2i.ZERO, plans2)
	var ra: Region = WorldGenerator.generate_region(seed_val, plan_a, plans1)
	var rb: Region = WorldGenerator.generate_region(seed_val, plan_b, plans2)
	assert_eq(ra.tiles, rb.tiles, "Region.tiles must be byte-identical for same seed")
	assert_eq(ra.biome, rb.biome)
	assert_eq(ra.bleed_edges, rb.bleed_edges)
	assert_eq(ra.spawn_points.size(), rb.spawn_points.size())


func test_world_generator_ocean_region_all_ocean() -> void:
	var plan := RegionPlan.new()
	plan.region_id = Vector2i(0, 0)
	plan.planned_biome = &"ocean"
	plan.is_ocean = true
	var r: Region = WorldGenerator.generate_region(1, plan, {})
	# All tiles should be ocean.
	for b in r.tiles:
		assert_eq(b, TerrainCodes.OCEAN)
	assert_eq(r.bleed_edges, 0)
	assert_eq(r.decorations.size(), 0)
	assert_eq(r.spawn_points.size(), 0)


func test_world_generator_land_region_has_spawn_and_decorations() -> void:
	# Construct a known-land plan directly (skip random ocean roll).
	var plan := RegionPlan.new()
	plan.region_id = Vector2i(0, 0)
	plan.planned_biome = &"grass"
	plan.is_ocean = false
	var r: Region = WorldGenerator.generate_region(7, plan, {})
	assert_gt(r.spawn_points.size(), 0, "Land region should yield at least one spawn point")
	for sp in r.spawn_points:
		assert_true(r.is_walkable_at(sp), "Spawn point must be walkable")
	# Should have *some* decorations on a 128×128 grass region with ~6%/4%/etc weights.
	assert_gt(r.decorations.size(), 0, "Expected scattered decorations on a grass region")


func test_bleed_conflict_lowest_id_wins() -> void:
	# Two source regions both bleed into the same neighbor.
	var plans: Dictionary = {}
	var center := Vector2i(0, 0)
	var src_low := RegionPlan.new()
	src_low.region_id = Vector2i(-1, 0)  # west neighbor of center, biome A
	src_low.planned_biome = &"grass"
	var src_high := RegionPlan.new()
	src_high.region_id = Vector2i(1, 0)  # east neighbor of center, biome B
	src_high.planned_biome = &"desert"
	var neighbor := RegionPlan.new()
	neighbor.region_id = center
	plans[center] = neighbor
	# Apply higher-id source FIRST: locks neighbor to desert.
	var ok1 := WorldGenerator.try_apply_bleed(src_high, neighbor, 8)
	assert_true(ok1)
	assert_eq(neighbor.planned_biome, &"desert")
	# Then lower-id source applies; should win and overwrite.
	var ok2 := WorldGenerator.try_apply_bleed(src_low, neighbor, 2)
	assert_true(ok2)
	assert_eq(neighbor.planned_biome, &"grass", "Lower region_id source must win conflict")
	# Higher-id retry fails.
	var ok3 := WorldGenerator.try_apply_bleed(src_high, neighbor, 8)
	assert_false(ok3, "Already locked by lower-id source; should reject")


func test_bleed_does_not_overwrite_ocean() -> void:
	var src := RegionPlan.new()
	src.region_id = Vector2i(0, 0)
	src.planned_biome = &"grass"
	var neighbor := RegionPlan.new()
	neighbor.region_id = Vector2i(1, 0)
	neighbor.is_ocean = true
	var ok := WorldGenerator.try_apply_bleed(src, neighbor, 8)
	assert_false(ok, "Ocean neighbors should reject bleed")
	assert_true(neighbor.is_ocean)
