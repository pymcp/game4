## Phase 3c: bleed planning + conflict resolution exercised end-to-end via
## the public WorldGenerator + WorldManager APIs.
extends GutTest


# Search for a (seed, region_id) pair where the generated land region rolls
# at least one bleed onto a neighbor. With ~25% per-edge chance, we expect
# any random land region to have ~68% chance of >=1 bleed; usually finds
# one in <5 tries.
func _find_bleeding_region(start_seed: int, max_tries: int = 50) -> Array:
	for s in max_tries:
		var seed_val: int = start_seed + s
		var plans: Dictionary = {}
		var plan: RegionPlan = WorldGenerator.plan_region(seed_val, Vector2i.ZERO, plans)
		if plan.is_ocean:
			continue
		var region: Region = WorldGenerator.generate_region(seed_val, plan, plans)
		if region.bleed_edges != 0:
			return [seed_val, plans, region]
	return []


func test_bleed_locks_neighbor_plan_with_same_biome() -> void:
	var found: Array = _find_bleeding_region(2024)
	assert_gt(found.size(), 0, "Could not find bleeding region within 50 tries")
	var seed_val: int = found[0]
	var plans: Dictionary = found[1]
	var region: Region = found[2]
	# For each bleed-bit set in region.bleed_edges, the matching neighbor
	# plan must exist, be locked, and share the biome.
	var sides: Array = [
		[1, Vector2i(0, -1)],  # N
		[2, Vector2i(1, 0)],   # E
		[4, Vector2i(0, 1)],   # S
		[8, Vector2i(-1, 0)],  # W
	]
	var found_any: bool = false
	for s in sides:
		var bit: int = s[0]
		var off: Vector2i = s[1]
		if (region.bleed_edges & bit) == 0:
			continue
		found_any = true
		var nid: Vector2i = region.region_id + off
		assert_true(plans.has(nid), "Neighbor plan should exist on bleed side bit=%d" % bit)
		var npp: RegionPlan = plans[nid]
		assert_true(npp.is_locked_by_bleed)
		assert_eq(npp.planned_biome, region.biome,
			"Neighbor planned_biome must match source biome")
	assert_true(found_any, "Sanity: should have found at least one bleeding side")


func test_bleeding_neighbor_has_no_ocean_ring_on_shared_edge() -> void:
	var found: Array = _find_bleeding_region(2024)
	assert_gt(found.size(), 0)
	var seed_val: int = found[0]
	var plans: Dictionary = found[1]
	var region: Region = found[2]
	# Generate the bleeding neighbor and check the shared edge has land.
	var sides_data: Array = [
		[1, Vector2i(0, -1), 4],   # I bleed N → neighbor's S edge should be land
		[2, Vector2i(1, 0),  8],   # I bleed E → neighbor's W edge land
		[4, Vector2i(0, 1),  1],   # I bleed S → neighbor's N edge land
		[8, Vector2i(-1, 0), 2],   # I bleed W → neighbor's E edge land
	]
	var size := Region.SIZE
	for d in sides_data:
		var bit: int = d[0]
		var off: Vector2i = d[1]
		var their_bit: int = d[2]
		if (region.bleed_edges & bit) == 0:
			continue
		var neighbor: Region = WorldGenerator.generate_region(seed_val, plans[region.region_id + off], plans)
		assert_eq(neighbor.bleed_edges & their_bit, their_bit,
			"Neighbor must have matching bleed-edge bit set on shared side")
		# Verify the FIRST cell on the shared edge is not OCEAN (bleed edges
		# extend land instead of carving the ocean ring).
		var probe: Vector2i
		match their_bit:
			1: probe = Vector2i(size / 2, 0)
			4: probe = Vector2i(size / 2, size - 1)
			8: probe = Vector2i(0, size / 2)
			2: probe = Vector2i(size - 1, size / 2)
		assert_ne(neighbor.at(probe), TerrainCodes.OCEAN,
			"Bleed edge must not be OCEAN at probe %s" % str(probe))


func test_full_plan_set_deterministic_across_traversal_order() -> void:
	# Generate region A, then its bled neighbors. The final plan dict should
	# be identical regardless of *which order* we visit equally-rolled
	# neighbors. We approximate by running the same seed twice and comparing
	# the plans dict.
	var seed_val: int = 555
	var plans1: Dictionary = {}
	var plans2: Dictionary = {}
	for region_id in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]:
		var p1: RegionPlan = WorldGenerator.plan_region(seed_val, region_id, plans1)
		WorldGenerator.generate_region(seed_val, p1, plans1)
	# Reverse order on the second run.
	for region_id in [Vector2i(0,-1), Vector2i(-1,0), Vector2i(0,1), Vector2i(1,0), Vector2i(0,0)]:
		var p2: RegionPlan = WorldGenerator.plan_region(seed_val, region_id, plans2)
		WorldGenerator.generate_region(seed_val, p2, plans2)
	# Same set of region_ids planned.
	var keys1: Array = plans1.keys()
	var keys2: Array = plans2.keys()
	keys1.sort()
	keys2.sort()
	assert_eq(keys1, keys2, "Same region_ids must be planned regardless of order")
	for k in keys1:
		assert_eq(plans1[k].planned_biome, plans2[k].planned_biome,
			"Biome at %s should match across traversal orders" % str(k))


func test_world_manager_streams_and_caches_regions() -> void:
	WorldManager.reset(98765)
	var r1: Region = WorldManager.get_or_generate(Vector2i(2, 3))
	var r2: Region = WorldManager.get_or_generate(Vector2i(2, 3))
	assert_same(r1, r2, "WorldManager must cache regions by id")
	# Plans dict should also have the entry.
	assert_true(WorldManager.plans.has(Vector2i(2, 3)))


func test_world_manager_set_active_emits_signal() -> void:
	WorldManager.reset(11111)
	var got_signals: Array = []
	var cb := func(region: Region) -> void: got_signals.append(region.region_id)
	WorldManager.active_region_changed.connect(cb)
	WorldManager.set_active_region(Vector2i(5, 5))
	# Setting same again should NOT re-emit.
	WorldManager.set_active_region(Vector2i(5, 5))
	WorldManager.set_active_region(Vector2i(6, 5))
	WorldManager.active_region_changed.disconnect(cb)
	assert_eq(got_signals, [Vector2i(5, 5), Vector2i(6, 5)],
		"signal should fire once per distinct active region")
