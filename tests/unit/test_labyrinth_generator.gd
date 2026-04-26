extends GutTest

func test_generates_interiormap() -> void:
	var m: InteriorMap = LabyrinthGenerator.generate(12345, 64, 64, 1)
	assert_not_null(m)
	assert_eq(m.width, 64)
	assert_eq(m.height, 64)


func test_entry_and_exit_are_floor() -> void:
	var m: InteriorMap = LabyrinthGenerator.generate(42, 64, 64, 1)
	assert_eq(m.at(m.entry_cell), TerrainCodes.INTERIOR_STAIRS_UP)
	assert_eq(m.at(m.exit_cell), TerrainCodes.INTERIOR_STAIRS_DOWN)
	assert_ne(m.entry_cell, m.exit_cell)


func test_maze_is_connected() -> void:
	var m: InteriorMap = LabyrinthGenerator.generate(99, 64, 64, 1)
	var visited: Dictionary = {}
	var queue: Array = [m.entry_cell]
	visited[m.entry_cell] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nb: Vector2i = cur + d
			if visited.has(nb):
				continue
			if m.at(nb) != TerrainCodes.INTERIOR_WALL:
				visited[nb] = true
				queue.append(nb)
	assert_true(visited.has(m.exit_cell), "Exit cell must be reachable from entry")


func test_has_chests_at_dead_ends() -> void:
	var m: InteriorMap = LabyrinthGenerator.generate(7777, 64, 64, 1)
	assert_true(m.chest_scatter.size() >= 2, "Should have at least 2 dead-end chests; got %d" % m.chest_scatter.size())


func test_no_boss_on_non_boss_floor() -> void:
	var m: InteriorMap = LabyrinthGenerator.generate(1, 64, 64, 1)
	assert_true(m.boss_data.is_empty(), "Floor 1 should have no boss")


func test_boss_on_boss_floor() -> void:
	var m: InteriorMap = LabyrinthGenerator.generate(1, 64, 64, 5)
	assert_false(m.boss_data.is_empty(), "Floor 5 should have a boss")
	assert_true(m.boss_room_cells.size() >= 4, "Boss room should have some floor cells")


func test_variable_size() -> void:
	var m_small: InteriorMap = LabyrinthGenerator.generate(1, 10, 10, 1)
	assert_eq(m_small.width, InteriorMap.MIN_SIZE)
	var m_big: InteriorMap = LabyrinthGenerator.generate(1, 200, 200, 1)
	assert_eq(m_big.width, InteriorMap.MAX_SIZE)
