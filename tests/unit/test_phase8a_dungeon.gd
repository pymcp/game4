## Phase 8a — InteriorMap + DungeonGenerator unit tests.
extends GutTest


func test_interior_codes_are_distinct() -> void:
	# Make sure the new interior codes don't collide with overworld codes.
	var overworld: Array = [TerrainCodes.OCEAN, TerrainCodes.WATER,
		TerrainCodes.SAND, TerrainCodes.GRASS, TerrainCodes.DIRT,
		TerrainCodes.ROCK, TerrainCodes.SNOW, TerrainCodes.SWAMP]
	var interior: Array = [TerrainCodes.INTERIOR_FLOOR,
		TerrainCodes.INTERIOR_WALL, TerrainCodes.INTERIOR_DOOR,
		TerrainCodes.INTERIOR_STAIRS_UP, TerrainCodes.INTERIOR_STAIRS_DOWN]
	for c in interior:
		assert_false(overworld.has(c),
			"interior code %d collides with overworld" % c)


func test_interior_wall_is_not_walkable() -> void:
	assert_false(TerrainCodes.is_walkable(TerrainCodes.INTERIOR_WALL))
	assert_true(TerrainCodes.is_walkable(TerrainCodes.INTERIOR_FLOOR))
	assert_true(TerrainCodes.is_walkable(TerrainCodes.INTERIOR_DOOR))
	assert_true(TerrainCodes.is_walkable(TerrainCodes.INTERIOR_STAIRS_UP))


func test_interior_map_default_size_is_walls() -> void:
	var m := InteriorMap.new()
	# Default-init resizes tiles to width*height (32*32 by default).
	assert_eq(m.tiles.size(), m.width * m.height)
	for b in m.tiles:
		assert_eq(b, 0)


func test_interior_map_oob_reads_as_wall() -> void:
	var m := InteriorMap.new()
	m.width = 4
	m.height = 4
	m.tiles = PackedByteArray()
	m.tiles.resize(16)
	for i in 16:
		m.tiles[i] = TerrainCodes.INTERIOR_FLOOR
	assert_eq(m.at(Vector2i(-1, 0)), TerrainCodes.INTERIOR_WALL)
	assert_eq(m.at(Vector2i(0, -1)), TerrainCodes.INTERIOR_WALL)
	assert_eq(m.at(Vector2i(4, 0)), TerrainCodes.INTERIOR_WALL)
	assert_eq(m.at(Vector2i(0, 4)), TerrainCodes.INTERIOR_WALL)
	assert_eq(m.at(Vector2i(2, 2)), TerrainCodes.INTERIOR_FLOOR)


# ─── Dungeon generator ────────────────────────────────────────────────

func test_generate_returns_interior_map_with_seed() -> void:
	var m := DungeonGenerator.generate(12345, 32, 32)
	assert_not_null(m)
	assert_eq(m.seed, 12345)
	assert_eq(m.width, 32)
	assert_eq(m.height, 32)
	assert_eq(m.tiles.size(), 32 * 32)


func test_generate_clamps_size_to_bounds() -> void:
	var tiny := DungeonGenerator.generate(1, 4, 4)
	assert_eq(tiny.width, InteriorMap.MIN_SIZE)
	assert_eq(tiny.height, InteriorMap.MIN_SIZE)
	var huge := DungeonGenerator.generate(1, 999, 999)
	assert_eq(huge.width, InteriorMap.MAX_SIZE)
	assert_eq(huge.height, InteriorMap.MAX_SIZE)


func test_generate_is_deterministic() -> void:
	var a := DungeonGenerator.generate(777, 32, 32)
	var b := DungeonGenerator.generate(777, 32, 32)
	assert_eq(a.tiles, b.tiles)
	assert_eq(a.entry_cell, b.entry_cell)
	assert_eq(a.exit_cell, b.exit_cell)
	assert_eq(a.npcs_scatter.size(), b.npcs_scatter.size())


func test_generate_different_seeds_differ() -> void:
	var a := DungeonGenerator.generate(1, 32, 32)
	var b := DungeonGenerator.generate(2, 32, 32)
	assert_ne(a.tiles, b.tiles)


func test_generated_map_has_floor_and_wall() -> void:
	var m := DungeonGenerator.generate(42, 32, 32)
	var floors: int = 0
	var walls: int = 0
	for b in m.tiles:
		if b == TerrainCodes.INTERIOR_FLOOR:
			floors += 1
		elif b == TerrainCodes.INTERIOR_WALL:
			walls += 1
	assert_gt(floors, 50, "should carve a meaningful number of floor tiles")
	assert_gt(walls, 50, "should retain wall tiles around rooms")


func test_entry_and_exit_are_walkable() -> void:
	var m := DungeonGenerator.generate(99, 32, 32)
	assert_true(m.is_walkable_at(m.entry_cell), "entry must be walkable")
	assert_true(m.is_walkable_at(m.exit_cell), "exit must be walkable")
	assert_eq(m.at(m.entry_cell), TerrainCodes.INTERIOR_STAIRS_UP)
	assert_eq(m.at(m.exit_cell), TerrainCodes.INTERIOR_STAIRS_DOWN)


func test_entry_and_exit_are_distinct() -> void:
	# With a 32x32 BSP we should always have multiple rooms, so entry≠exit.
	var m := DungeonGenerator.generate(11, 32, 32)
	assert_ne(m.entry_cell, m.exit_cell)


func test_path_exists_from_entry_to_exit() -> void:
	var m := DungeonGenerator.generate(31415, 32, 32)
	var path := Pathfinder.find_path(m.entry_cell, m.exit_cell,
		func(c: Vector2i) -> bool: return m.is_walkable_at(c),
		8000)
	assert_gt(path.size(), 0,
		"BSP rooms must be connected — no path from entry to exit")


func test_npcs_scatter_only_on_floor() -> void:
	var m := DungeonGenerator.generate(2024, 32, 32)
	for entry in m.npcs_scatter:
		var c: Vector2i = entry["cell"]
		assert_eq(m.at(c), TerrainCodes.INTERIOR_FLOOR,
			"NPC scatter cell %s is not a floor tile" % [c])
