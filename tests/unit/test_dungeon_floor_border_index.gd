## Unit tests for WorldRoot._dungeon_floor_border_index.
##
## The function returns 0-8 based on which orthogonal neighbours of a floor
## cell are walls. Priority: NW/NE/SW/SE corners first, then N/S/W/E edges,
## then centre (4).
extends GutTest


# ─── helpers ──────────────────────────────────────────────────────────────────

func _make_interior(size: int) -> InteriorMap:
	var m := InteriorMap.new()
	m.width = size
	m.height = size
	m.tiles.resize(size * size)
	m.tiles.fill(TerrainCodes.INTERIOR_WALL)
	return m


# Center of the 5×5 test map — all four neighbours fit inside.
const CELL := Vector2i(2, 2)

const N := Vector2i(2, 1)
const S := Vector2i(2, 3)
const W := Vector2i(1, 2)
const E := Vector2i(3, 2)


# ─── tests ────────────────────────────────────────────────────────────────────

func test_centre_all_neighbours_floor_returns_4() -> void:
	var m := _make_interior(5)
	m.set_at(N, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(S, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(W, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(E, TerrainCodes.INTERIOR_FLOOR)
	assert_eq(WorldRoot._dungeon_floor_border_index(m, CELL), 4)


func test_n_edge_north_wall_returns_1() -> void:
	var m := _make_interior(5)
	# N stays wall; S, W, E are floor.
	m.set_at(S, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(W, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(E, TerrainCodes.INTERIOR_FLOOR)
	assert_eq(WorldRoot._dungeon_floor_border_index(m, CELL), 1)


func test_s_edge_south_wall_returns_7() -> void:
	var m := _make_interior(5)
	# S stays wall; N, W, E are floor.
	m.set_at(N, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(W, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(E, TerrainCodes.INTERIOR_FLOOR)
	assert_eq(WorldRoot._dungeon_floor_border_index(m, CELL), 7)


func test_w_edge_west_wall_returns_3() -> void:
	var m := _make_interior(5)
	# W stays wall; N, S, E are floor.
	m.set_at(N, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(S, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(E, TerrainCodes.INTERIOR_FLOOR)
	assert_eq(WorldRoot._dungeon_floor_border_index(m, CELL), 3)


func test_e_edge_east_wall_returns_5() -> void:
	var m := _make_interior(5)
	# E stays wall; N, S, W are floor.
	m.set_at(N, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(S, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(W, TerrainCodes.INTERIOR_FLOOR)
	assert_eq(WorldRoot._dungeon_floor_border_index(m, CELL), 5)


func test_nw_corner_north_and_west_wall_returns_0() -> void:
	var m := _make_interior(5)
	# N and W stay wall; S and E are floor.
	m.set_at(S, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(E, TerrainCodes.INTERIOR_FLOOR)
	assert_eq(WorldRoot._dungeon_floor_border_index(m, CELL), 0)


func test_ne_corner_north_and_east_wall_returns_2() -> void:
	var m := _make_interior(5)
	# N and E stay wall; S and W are floor.
	m.set_at(S, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(W, TerrainCodes.INTERIOR_FLOOR)
	assert_eq(WorldRoot._dungeon_floor_border_index(m, CELL), 2)


func test_sw_corner_south_and_west_wall_returns_6() -> void:
	var m := _make_interior(5)
	# S and W stay wall; N and E are floor.
	m.set_at(N, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(E, TerrainCodes.INTERIOR_FLOOR)
	assert_eq(WorldRoot._dungeon_floor_border_index(m, CELL), 6)


func test_se_corner_south_and_east_wall_returns_8() -> void:
	var m := _make_interior(5)
	# S and E stay wall; N and W are floor.
	m.set_at(N, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(W, TerrainCodes.INTERIOR_FLOOR)
	assert_eq(WorldRoot._dungeon_floor_border_index(m, CELL), 8)


func test_opposite_n_s_walls_n_edge_wins_returns_1() -> void:
	# With N and S both walls and W+E floor, no corner check fires.
	# The first edge check (N) fires → returns 1.
	var m := _make_interior(5)
	m.set_at(W, TerrainCodes.INTERIOR_FLOOR)
	m.set_at(E, TerrainCodes.INTERIOR_FLOOR)
	assert_eq(WorldRoot._dungeon_floor_border_index(m, CELL), 1)


func test_boundary_west_oob_counts_as_wall_returns_w_edge() -> void:
	# Cell at (0, 2): west neighbour (-1, 2) is out of bounds → treated as wall.
	# Set N, S, E to floor; W is OOB-wall → W edge (3).
	var m := _make_interior(5)
	var boundary_cell := Vector2i(0, 2)
	m.set_at(Vector2i(0, 1), TerrainCodes.INTERIOR_FLOOR)  # N
	m.set_at(Vector2i(0, 3), TerrainCodes.INTERIOR_FLOOR)  # S
	m.set_at(Vector2i(1, 2), TerrainCodes.INTERIOR_FLOOR)  # E
	# West neighbour (-1, 2) is OOB → _dungeon_neighbour_is_floor returns false.
	assert_eq(WorldRoot._dungeon_floor_border_index(m, boundary_cell), 3)
