## Unit tests for WorldRoot.PATH_BITMASK_TO_INDEX and _path_index_for_cell.
extends GutTest


func test_bitmask_lookup_has_16_entries() -> void:
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX.size(), 16)


func test_isolated_is_19() -> void:
	# mask 0 = no connections
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[0], 19)


func test_straight_vertical_is_13() -> void:
	# mask 3 = N+S (bit0|bit1)
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[3], 13)


func test_straight_horizontal_is_14() -> void:
	# mask 12 = E+W (bit2|bit3)
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[12], 14)


func test_cross_is_28() -> void:
	# mask 15 = all four (bit0|bit1|bit2|bit3)
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[15], 28)


func test_corner_NE_is_20() -> void:
	# mask 5 = N+E (bit0|bit2)
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[5], 20)


func test_corner_NW_is_21() -> void:
	# mask 9 = N+W (bit0|bit3)
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[9], 21)


func test_corner_SE_is_22() -> void:
	# mask 6 = S+E (bit1|bit2)
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[6], 22)


func test_corner_SW_is_23() -> void:
	# mask 10 = S+W (bit1|bit3)
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[10], 23)


func test_t_junction_missing_W_is_24() -> void:
	# mask 7 = N+S+E (bit0|bit1|bit2)
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[7], 24)


func test_t_junction_missing_S_is_25() -> void:
	# mask 13 = N+E+W (bit0|bit2|bit3)
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[13], 25)


func test_t_junction_missing_E_is_26() -> void:
	# mask 11 = N+S+W (bit0|bit1|bit3)
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[11], 26)


func test_t_junction_missing_N_is_27() -> void:
	# mask 14 = S+E+W (bit1|bit2|bit3)
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[14], 27)


func test_dead_ends() -> void:
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[1], 16)  # N only
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[2], 15)  # S only
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[4], 17)  # E only
	assert_eq(WorldRoot.PATH_BITMASK_TO_INDEX[8], 18)  # W only


func test_path_index_for_cell_isolated() -> void:
	var path_set := {Vector2i(5, 5): true}
	var idx := WorldRoot._path_index_for_cell(path_set, 5, 5, 128)
	assert_eq(idx, 19)  # isolated


func test_path_index_for_cell_straight_horizontal() -> void:
	var path_set := {
		Vector2i(4, 5): true,
		Vector2i(5, 5): true,
		Vector2i(6, 5): true,
	}
	var idx := WorldRoot._path_index_for_cell(path_set, 5, 5, 128)
	assert_eq(idx, 14)  # E+W straight


func test_path_index_for_cell_corner_NE() -> void:
	var path_set := {
		Vector2i(5, 4): true,  # N
		Vector2i(5, 5): true,  # center
		Vector2i(6, 5): true,  # E
	}
	var idx := WorldRoot._path_index_for_cell(path_set, 5, 5, 128)
	assert_eq(idx, 20)  # cNE


func test_path_index_for_cell_cross() -> void:
	var path_set := {
		Vector2i(5, 4): true,
		Vector2i(5, 6): true,
		Vector2i(4, 5): true,
		Vector2i(6, 5): true,
		Vector2i(5, 5): true,
	}
	var idx := WorldRoot._path_index_for_cell(path_set, 5, 5, 128)
	assert_eq(idx, 28)  # cross
