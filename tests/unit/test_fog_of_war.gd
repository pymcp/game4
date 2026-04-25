extends GutTest

var fog: FogOfWarData

func before_each() -> void:
	fog = FogOfWarData.new()

func test_unrevealed_returns_false() -> void:
	assert_false(fog.is_revealed(Vector2i.ZERO, Vector2i(5, 5)))

func test_has_region_false_before_reveal() -> void:
	assert_false(fog.has_region(Vector2i.ZERO))

func test_has_region_true_after_reveal() -> void:
	fog.reveal(Vector2i.ZERO, Vector2i(5, 5), 1)
	assert_true(fog.has_region(Vector2i.ZERO))

func test_reveal_center_cell() -> void:
	fog.reveal(Vector2i.ZERO, Vector2i(10, 10), 0)
	assert_true(fog.is_revealed(Vector2i.ZERO, Vector2i(10, 10)))

func test_reveal_radius_includes_adjacent() -> void:
	fog.reveal(Vector2i.ZERO, Vector2i(10, 10), 2)
	assert_true(fog.is_revealed(Vector2i.ZERO, Vector2i(12, 10)))
	assert_true(fog.is_revealed(Vector2i.ZERO, Vector2i(10, 8)))

func test_reveal_radius_excludes_outside() -> void:
	fog.reveal(Vector2i.ZERO, Vector2i(10, 10), 2)
	# (10,10) + (3,0) = distance 3, outside radius 2
	assert_false(fog.is_revealed(Vector2i.ZERO, Vector2i(13, 10)))

func test_reveal_near_origin_does_not_panic() -> void:
	# Cells with negative coords after subtracting radius must be clamped
	fog.reveal(Vector2i.ZERO, Vector2i(2, 2), 10)
	assert_true(fog.is_revealed(Vector2i.ZERO, Vector2i(0, 0)))

func test_to_dict_from_dict_round_trip() -> void:
	fog.reveal(Vector2i(3, -1), Vector2i(64, 64), 5)
	var d: Dictionary = fog.to_dict()
	var fog2 := FogOfWarData.new()
	fog2.from_dict(d)
	assert_true(fog2.is_revealed(Vector2i(3, -1), Vector2i(64, 64)))
	assert_false(fog2.is_revealed(Vector2i(3, -1), Vector2i(0, 0)))

func test_get_all_region_ids_returns_revealed_regions() -> void:
	fog.reveal(Vector2i(1, 2), Vector2i(10, 10), 1)
	fog.reveal(Vector2i(-1, 0), Vector2i(10, 10), 1)
	var ids: Array = fog.get_all_region_ids()
	assert_eq(ids.size(), 2)
