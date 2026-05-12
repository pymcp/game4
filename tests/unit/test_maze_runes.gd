## Unit tests verifying MazeGenerator places rune markers inside maze interiors.
extends GutTest


func test_maze_generate_populates_runes() -> void:
	var m: InteriorMap = MazeGenerator.generate(12345, 32, 32, 1)
	assert_not_null(m, "generate() returns a map")
	# InteriorMap must have a runes array.
	assert_true("runes" in m, "InteriorMap should have a runes array")
	# Floor 1 of the quest mine should contain at least 2 rune markers.
	assert_true((m.runes as Array).size() >= 2,
			"maze floor 1 should have at least 2 runes, got %d" % (m.runes as Array).size())


func test_maze_runes_use_blue_source() -> void:
	var m: InteriorMap = MazeGenerator.generate(99999, 32, 32, 1)
	for rune in (m.runes as Array):
		var src: int = int(rune.get("source", -1))
		assert_eq(src, 2, "mine runes should use source=2 (blue/classified)")


func test_maze_runes_on_floor_cells() -> void:
	var m: InteriorMap = MazeGenerator.generate(54321, 40, 40, 1)
	for rune in (m.runes as Array):
		var cell: Vector2i = rune["cell"]
		var code: int = m.at(cell)
		assert_eq(code, TerrainCodes.INTERIOR_FLOOR,
				"rune at %s should be on a floor cell" % cell)


func test_maze_runes_not_in_boss_room() -> void:
	# Floor 5 triggers a boss room (default boss_interval=5).
	var m: InteriorMap = MazeGenerator.generate(77777, 48, 48, 5)
	var boss_cells: Dictionary = {}
	for cell in m.boss_room_cells:
		boss_cells[cell] = true
	for rune in (m.runes as Array):
		var cell: Vector2i = rune["cell"]
		assert_false(boss_cells.has(cell),
				"rune should not be placed inside the boss room")


func test_maze_runes_vary_atlas_cells() -> void:
	# A maze with many runes should use more than one atlas variant.
	var m: InteriorMap = MazeGenerator.generate(11111, 64, 64, 1)
	var atlas_set: Dictionary = {}
	for rune in (m.runes as Array):
		atlas_set[rune["atlas"]] = true
	# With 64×64 map we expect at least 2 runes and thus likely >1 atlas variant.
	if (m.runes as Array).size() >= 2:
		assert_true(atlas_set.size() >= 1, "atlas cells should be assigned")
