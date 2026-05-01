## Verifies MapManager dispatches house generation when kind=&"house"
## and that the resulting interior id differs from a dungeon at the same
## (region, cell) so the two caches don't collide.
extends GutTest


func before_each() -> void:
	MapManager.interiors.clear()


func test_make_id_includes_kind_prefix() -> void:
	var rid := Vector2i(1, 2)
	var cell := Vector2i(8, 9)
	var d_id: StringName = MapManager.make_id(rid, cell, 1, &"dungeon")
	var h_id: StringName = MapManager.make_id(rid, cell, 1, &"house")
	assert_eq(String(d_id), "dungeon@1:2:8:9:1")
	assert_eq(String(h_id), "house@1:2:8:9:1")
	assert_ne(d_id, h_id)


func test_get_or_generate_house_uses_house_generator() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(4, 4)
	var hid: StringName = MapManager.make_id(rid, cell, 1, &"house")
	var m: InteriorMap = MapManager.get_or_generate(
			hid, rid, cell, 1, MapManager.DEFAULT_FLOOR_SIZE, &"house")
	assert_not_null(m)
	# House interiors are 8..14 tiles per side (HouseGenerator.MIN/MAX_DIM).
	assert_between(m.width, HouseGenerator.MIN_DIM, HouseGenerator.MAX_DIM)
	assert_between(m.height, HouseGenerator.MIN_DIM, HouseGenerator.MAX_DIM)
	# exit_cell must be a DOOR cell on the south half of the map.
	assert_eq(m.at(m.exit_cell), TerrainCodes.INTERIOR_DOOR, "exit_cell must be a door")
	assert_true(m.exit_cell.y >= m.height / 2, "exit_cell must be on the south half")
	assert_eq(m.origin_region_id, rid)
	assert_eq(m.origin_cell, cell)


func test_house_and_dungeon_at_same_cell_are_distinct() -> void:
	var rid := Vector2i(2, -1)
	var cell := Vector2i(10, 10)
	var d_id: StringName = MapManager.make_id(rid, cell, 1, &"dungeon")
	var h_id: StringName = MapManager.make_id(rid, cell, 1, &"house")
	var d: InteriorMap = MapManager.get_or_generate(d_id, rid, cell, 1)
	var h: InteriorMap = MapManager.get_or_generate(
			h_id, rid, cell, 1, MapManager.DEFAULT_FLOOR_SIZE, &"house")
	assert_not_same(d, h)
	# Dungeons are DEFAULT_FLOOR_SIZE (32) while houses are 8..14, so the
	# two should never be confused even ignoring the cache.
	assert_eq(d.width, MapManager.DEFAULT_FLOOR_SIZE)
	assert_lt(h.width, MapManager.DEFAULT_FLOOR_SIZE)
