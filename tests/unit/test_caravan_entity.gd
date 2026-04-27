extends GutTest

var _caravan: Caravan = null

func before_each() -> void:
	_caravan = Caravan.new()
	add_child_autofree(_caravan)

func test_caravan_has_interacted_signal() -> void:
	assert_true(_caravan.has_signal("interacted"), "Should have interacted signal")

func test_caravan_data_initially_null() -> void:
	# caravan_data is null until set by world.gd
	assert_null(_caravan.caravan_data)

func test_can_set_caravan_data() -> void:
	var cd := CaravanData.new()
	_caravan.caravan_data = cd
	assert_not_null(_caravan.caravan_data)

func test_can_interact_with_close_player() -> void:
	# Without a real player we just test the null path returns false.
	assert_false(_caravan.can_interact_with(null))

func test_lag_position_falls_back_gracefully() -> void:
	# Without owner_player, _lag_position should return current position.
	_caravan.owner_player = null
	# Should not crash.
	var result: Vector2 = _caravan._lag_position()
	assert_eq(result, _caravan.position)
