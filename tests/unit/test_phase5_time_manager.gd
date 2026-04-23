extends GutTest

# TimeManager is an autoload, so we test it directly.

func before_each() -> void:
	TimeManager.time_of_day = 8.0
	TimeManager.day_count = 0
	TimeManager.ticking = true


func test_initial_period_is_day() -> void:
	assert_eq(TimeManager.get_period(), &"day")


func test_dawn_period() -> void:
	TimeManager.time_of_day = 6.0
	assert_eq(TimeManager.get_period(), &"dawn")


func test_dusk_period() -> void:
	TimeManager.time_of_day = 20.0
	assert_eq(TimeManager.get_period(), &"dusk")


func test_night_period_late() -> void:
	TimeManager.time_of_day = 23.0
	assert_eq(TimeManager.get_period(), &"night")


func test_night_period_early() -> void:
	TimeManager.time_of_day = 3.0
	assert_eq(TimeManager.get_period(), &"night")


func test_dawn_boundary_5() -> void:
	TimeManager.time_of_day = 5.0
	assert_eq(TimeManager.get_period(), &"dawn")


func test_day_boundary_7() -> void:
	TimeManager.time_of_day = 7.0
	assert_eq(TimeManager.get_period(), &"day")


func test_dusk_boundary_19() -> void:
	TimeManager.time_of_day = 19.0
	assert_eq(TimeManager.get_period(), &"dusk")


func test_night_boundary_21() -> void:
	TimeManager.time_of_day = 21.0
	assert_eq(TimeManager.get_period(), &"night")


func test_get_ambient_color_day_is_white() -> void:
	TimeManager.time_of_day = 12.0
	var c: Color = TimeManager.get_ambient_color()
	assert_almost_eq(c.r, 1.0, 0.01)
	assert_almost_eq(c.g, 1.0, 0.01)
	assert_almost_eq(c.b, 1.0, 0.01)


func test_get_ambient_color_night_is_dark() -> void:
	TimeManager.time_of_day = 0.0
	var c: Color = TimeManager.get_ambient_color()
	assert_true(c.r < 0.5, "Night should be dark (r < 0.5)")
	assert_true(c.b > c.r, "Night should be bluish")


func test_get_period_color_returns_color() -> void:
	var c: Color = TimeManager.get_period_color()
	assert_true(c is Color)


func test_save_load_roundtrip() -> void:
	TimeManager.time_of_day = 15.5
	TimeManager.day_count = 3
	var data: Dictionary = TimeManager.get_save_data()
	TimeManager.time_of_day = 0.0
	TimeManager.day_count = 0
	TimeManager.load_save_data(data)
	assert_almost_eq(TimeManager.time_of_day, 15.5, 0.01)
	assert_eq(TimeManager.day_count, 3)


func test_ticking_false_stops_time() -> void:
	TimeManager.ticking = false
	var before: float = TimeManager.time_of_day
	# Simulate a _process call manually
	TimeManager._process(1.0)
	assert_almost_eq(TimeManager.time_of_day, before, 0.001)
	TimeManager.ticking = true


func test_time_advances() -> void:
	var before: float = TimeManager.time_of_day
	TimeManager._process(1.0)
	assert_true(TimeManager.time_of_day > before, "Time should advance")


func test_day_rollover() -> void:
	TimeManager.time_of_day = 23.999
	TimeManager.day_count = 0
	var hours_per_sec: float = 24.0 / TimeManager.DAY_DURATION_SEC
	var needed_delta: float = (24.0 - 23.999) / hours_per_sec + 0.1
	TimeManager._process(needed_delta)
	assert_eq(TimeManager.day_count, 1, "Day should increment on rollover")
	assert_true(TimeManager.time_of_day < 24.0, "Time should wrap")
