## Phase 8b — Entrance placement + MapManager tests.
extends GutTest


func before_each() -> void:
	WorldManager.reset(444)
	MapManager.reset()


func _make_land_region(seed_val: int) -> Region:
	var plans: Dictionary = {}
	var plan := WorldGenerator.plan_region(seed_val, Vector2i(0, 0), plans)
	plan.is_ocean = false
	plan.planned_biome = &"grass"
	return WorldGenerator.generate_region(seed_val, plan, plans)


# ─── Entrance placement ──────────────────────────────────────────────

func test_dungeon_entrances_field_populated_for_some_seeds() -> void:
	var any_found: bool = false
	for s in [101, 202, 303, 404, 505, 606, 707, 808]:
		var r := _make_land_region(s)
		if r.dungeon_entrances.size() > 0:
			any_found = true
			break
	assert_true(any_found, "Expected at least one seed to place a dungeon entrance")


func test_entrances_are_walkable_and_off_decorations() -> void:
	for s in [101, 202, 303, 404, 505]:
		var r := _make_land_region(s)
		var deco_cells: Dictionary = {}
		for entry in r.decorations:
			deco_cells[entry["cell"]] = true
		for entry in r.dungeon_entrances:
			var c: Vector2i = entry["cell"]
			assert_true(r.is_walkable_at(c),
				"entrance %s on non-walkable cell" % [c])
			assert_false(deco_cells.has(c),
				"entrance %s overlaps a decoration" % [c])


func test_entrances_are_far_from_center() -> void:
	for s in [101, 202, 303]:
		var r := _make_land_region(s)
		var center := Vector2i(Region.SIZE / 2, Region.SIZE / 2)
		for entry in r.dungeon_entrances:
			var c: Vector2i = entry["cell"]
			var dist: int = abs(c.x - center.x) + abs(c.y - center.y)
			assert_gte(dist, 16,
				"entrance too close to spawn: cell=%s dist=%d" % [c, dist])


func test_entrances_deterministic() -> void:
	var a := _make_land_region(909)
	var b := _make_land_region(909)
	assert_eq(a.dungeon_entrances.size(), b.dungeon_entrances.size())
	for i in a.dungeon_entrances.size():
		assert_eq(a.dungeon_entrances[i]["cell"], b.dungeon_entrances[i]["cell"])


# ─── MapManager ──────────────────────────────────────────────────────

func test_make_id_is_canonical() -> void:
	var id := MapManager.make_id(Vector2i(2, -1), Vector2i(50, 60), 1)
	assert_eq(id, &"dungeon@2:-1:50:60:1")
	# Different floor produces different id.
	var id2 := MapManager.make_id(Vector2i(2, -1), Vector2i(50, 60), 2)
	assert_ne(id, id2)


func test_get_or_generate_creates_and_caches() -> void:
	var id := MapManager.make_id(Vector2i(0, 0), Vector2i(40, 40), 1)
	var emitted: Array = []
	MapManager.interior_generated.connect(func(mid): emitted.append(mid))
	var m1 := MapManager.get_or_generate(id, Vector2i(0, 0), Vector2i(40, 40))
	var m2 := MapManager.get_or_generate(id, Vector2i(0, 0), Vector2i(40, 40))
	assert_eq(m1, m2, "second call should return the cached map")
	assert_eq(emitted.size(), 1, "interior_generated fires only on first creation")
	assert_eq(m1.map_id, id)
	assert_eq(m1.origin_region_id, Vector2i(0, 0))
	assert_eq(m1.origin_cell, Vector2i(40, 40))


func test_get_or_generate_seed_is_deterministic_per_entrance() -> void:
	var id := MapManager.make_id(Vector2i(1, 1), Vector2i(20, 20))
	var m1 := MapManager.get_or_generate(id, Vector2i(1, 1), Vector2i(20, 20))
	# Wipe cache and regenerate; should be byte-identical.
	var seed_was: int = m1.seed
	var tiles_was: PackedByteArray = m1.tiles.duplicate()
	MapManager.reset()
	var m2 := MapManager.get_or_generate(id, Vector2i(1, 1), Vector2i(20, 20))
	assert_eq(m2.seed, seed_was)
	assert_eq(m2.tiles, tiles_was)


func test_set_active_emits_and_caches() -> void:
	var id := MapManager.make_id(Vector2i(0, 0), Vector2i(50, 50))
	var changed: Array = []
	MapManager.active_interior_changed.connect(func(m): changed.append(m))
	var m := MapManager.set_active(id, Vector2i(0, 0), Vector2i(50, 50))
	assert_not_null(m)
	assert_eq(MapManager.active_interior, m)
	assert_eq(changed.size(), 1)
	# Calling again with same id is idempotent.
	MapManager.set_active(id, Vector2i(0, 0), Vector2i(50, 50))
	assert_eq(changed.size(), 1, "no extra emit when already active")


func test_set_active_empty_clears() -> void:
	var id := MapManager.make_id(Vector2i(0, 0), Vector2i(50, 50))
	MapManager.set_active(id, Vector2i(0, 0), Vector2i(50, 50))
	assert_not_null(MapManager.active_interior)
	MapManager.set_active(&"")
	assert_null(MapManager.active_interior)


func test_exit_to_overworld_clears_active_and_emits() -> void:
	var id := MapManager.make_id(Vector2i(3, -2), Vector2i(70, 30))
	MapManager.set_active(id, Vector2i(3, -2), Vector2i(70, 30))
	var fired: Array = []
	MapManager.exited_to_overworld.connect(
		func(rid, cell): fired.append([rid, cell]))
	MapManager.exit_to_overworld()
	assert_null(MapManager.active_interior)
	assert_eq(fired.size(), 1)
	assert_eq(fired[0][0], Vector2i(3, -2))
	assert_eq(fired[0][1], Vector2i(70, 30))


func test_exit_when_not_in_interior_is_safe() -> void:
	# No active interior; should be a no-op, not crash.
	MapManager.exit_to_overworld()
	assert_null(MapManager.active_interior)
