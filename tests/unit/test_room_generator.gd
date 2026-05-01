## Unit tests for RoomGenerator.
extends GutTest


func _make_rng(seed_val: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r


# ── Single-rect generation ────────────────────────────────────────

func test_single_rect_dimensions():
	var rng := _make_rng(42)
	var m: InteriorMap = RoomGenerator.generate(rng, 8, 8)
	assert_eq(m.width, 8)
	assert_eq(m.height, 8)


func test_single_rect_has_walls_and_floor():
	var rng := _make_rng(1)
	var m: InteriorMap = RoomGenerator.generate(rng, 8, 8)
	# All border cells must be walls.
	for x in 8:
		assert_eq(m.at(Vector2i(x, 0)), TerrainCodes.INTERIOR_WALL, "top row x=%d" % x)
		var bot_code: int = m.at(Vector2i(x, 7))
		assert_true(bot_code == TerrainCodes.INTERIOR_WALL or bot_code == TerrainCodes.INTERIOR_DOOR,
			"bottom row x=%d should be wall or door" % x)
	for y in 8:
		assert_eq(m.at(Vector2i(0, y)), TerrainCodes.INTERIOR_WALL, "left col y=%d" % y)
		assert_eq(m.at(Vector2i(7, y)), TerrainCodes.INTERIOR_WALL, "right col y=%d" % y)
	# Interior cells must be floor or door.
	for y in range(1, 7):
		for x in range(1, 7):
			var code: int = m.at(Vector2i(x, y))
			assert_true(
				code == TerrainCodes.INTERIOR_FLOOR or code == TerrainCodes.INTERIOR_DOOR,
				"interior cell (%d,%d) code=%d" % [x, y, code])


func test_single_rect_door_on_south_wall():
	var rng := _make_rng(7)
	var m: InteriorMap = RoomGenerator.generate(rng, 8, 8)
	var door: Vector2i = m.exit_cell
	assert_eq(door.y, 7, "exit_cell should be on south wall (y=7)")
	assert_eq(m.at(door), TerrainCodes.INTERIOR_DOOR)


func test_single_rect_entry_cell_above_door():
	var rng := _make_rng(99)
	var m: InteriorMap = RoomGenerator.generate(rng, 8, 8)
	assert_eq(m.entry_cell.y, m.exit_cell.y - 1)
	assert_eq(m.entry_cell.x, m.exit_cell.x)


func test_single_rect_deterministic():
	var m1: InteriorMap = RoomGenerator.generate(_make_rng(123), 8, 8)
	var m2: InteriorMap = RoomGenerator.generate(_make_rng(123), 8, 8)
	assert_eq(m1.tiles, m2.tiles, "same seed must produce identical layout")


# ── Multi-room generation ─────────────────────────────────────────

func test_multi_room_has_floor():
	var rng := _make_rng(5)
	var m: InteriorMap = RoomGenerator.generate(rng, 20, 20)
	var floor_count: int = 0
	for i in m.tiles.size():
		if m.tiles[i] == TerrainCodes.INTERIOR_FLOOR:
			floor_count += 1
	assert_true(floor_count > 0, "multi-room must contain floor cells")


func test_multi_room_has_exit_door():
	var rng := _make_rng(17)
	var m: InteriorMap = RoomGenerator.generate(rng, 20, 20)
	assert_eq(m.at(m.exit_cell), TerrainCodes.INTERIOR_DOOR)


func test_multi_room_has_at_least_one_door():
	var rng := _make_rng(50)
	var m: InteriorMap = RoomGenerator.generate(rng, 20, 20)
	var door_count: int = 0
	for i in m.tiles.size():
		if m.tiles[i] == TerrainCodes.INTERIOR_DOOR:
			door_count += 1
	assert_true(door_count >= 1)


func test_multi_room_deterministic():
	var m1: InteriorMap = RoomGenerator.generate(_make_rng(77), 20, 20)
	var m2: InteriorMap = RoomGenerator.generate(_make_rng(77), 20, 20)
	assert_eq(m1.tiles, m2.tiles)


func test_multi_room_exits_are_walkable():
	var rng := _make_rng(88)
	var m: InteriorMap = RoomGenerator.generate(rng, 20, 20)
	assert_true(m.is_walkable_at(m.entry_cell),
		"entry_cell must be walkable")
	assert_true(m.is_walkable_at(m.exit_cell),
		"exit_cell must be walkable")


# ── carve_into ────────────────────────────────────────────────────

func test_carve_into_stamps_walls_and_floor():
	var rng := _make_rng(2)
	var m: InteriorMap = InteriorMap.new()
	m.width = 20
	m.height = 20
	m.tiles = PackedByteArray()
	m.tiles.resize(400)
	for i in 400:
		m.tiles[i] = TerrainCodes.INTERIOR_WALL  # start as all wall (realistic dungeon state)
	var rect := Rect2i(2, 2, 8, 8)
	RoomGenerator.carve_into(rng, m, rect)
	# Outer border of rect → walls.
	for x in range(rect.position.x, rect.end.x):
		assert_eq(m.at(Vector2i(x, rect.position.y)), TerrainCodes.INTERIOR_WALL,
			"top border x=%d" % x)
	# Interior → floor.
	for y in range(rect.position.y + 1, rect.end.y - 1):
		for x in range(rect.position.x + 1, rect.end.x - 1):
			var code: int = m.at(Vector2i(x, y))
			assert_true(code == TerrainCodes.INTERIOR_FLOOR or code == TerrainCodes.INTERIOR_DOOR,
				"interior of carved room (%d,%d) code=%d" % [x, y, code])


func test_carve_into_records_chamber_rect():
	var rng := _make_rng(3)
	var m: InteriorMap = InteriorMap.new()
	m.width = 20
	m.height = 20
	m.tiles = PackedByteArray()
	m.tiles.resize(400)
	for i in 400:
		m.tiles[i] = TerrainCodes.INTERIOR_WALL
	var rect := Rect2i(3, 3, 6, 6)
	RoomGenerator.carve_into(rng, m, rect)
	assert_eq(m.chamber_rects.size(), 1, "chamber_rects should have 1 entry")
	var stored: Rect2i = m.chamber_rects[0]
	assert_eq(stored, rect)


func test_carve_into_too_small_is_no_op():
	var rng := _make_rng(4)
	var m: InteriorMap = InteriorMap.new()
	m.width = 10
	m.height = 10
	m.tiles = PackedByteArray()
	m.tiles.resize(100)
	for i in 100:
		m.tiles[i] = TerrainCodes.INTERIOR_WALL
	RoomGenerator.carve_into(rng, m, Rect2i(0, 0, 2, 2))
	assert_eq(m.chamber_rects.size(), 0, "too-small rect should not be recorded")


# ── Size dispatch threshold ───────────────────────────────────────

func test_threshold_dispatch_small_uses_single_rect():
	# min(9,9) = 9 < MULTI_ROOM_THRESHOLD(10) → single rect
	var rng := _make_rng(11)
	var m: InteriorMap = RoomGenerator.generate(rng, 9, 9)
	# A single-rect always has walls on all four border rows.
	assert_eq(m.at(Vector2i(0, 0)), TerrainCodes.INTERIOR_WALL)
	assert_eq(m.at(Vector2i(8, 0)), TerrainCodes.INTERIOR_WALL)


func test_threshold_dispatch_large_uses_multi_room():
	# min(20,20) = 20 ≥ 10 → multi-room; should have more floor cells than single-rect 9x9
	var rng := _make_rng(12)
	var m: InteriorMap = RoomGenerator.generate(rng, 20, 20)
	assert_eq(m.width, 20)
	assert_eq(m.height, 20)
