# tests/unit/test_travel_log.gd
extends GutTest

var _log: TravelLog = null

func before_each() -> void:
	_log = TravelLog.new()

func test_starts_empty() -> void:
	assert_true(_log.current_run.is_empty(), "current_run should start empty")
	assert_true(_log.last_run.is_empty(), "last_run should start empty")

func test_first_start_run_leaves_last_run_empty() -> void:
	_log.start_run(&"dungeon", "0_0")
	assert_true(_log.last_run.is_empty(),
			"last_run should remain empty on the very first start_run")

func test_start_run_moves_current_to_last() -> void:
	_log.start_run(&"dungeon", "0_0")
	_log.record_kill()
	_log.record_kill()
	_log.start_run(&"labyrinth", "1_2")
	assert_eq(_log.last_run.get("enemies_killed", 0), 2,
			"last_run should snapshot the previous run kills")
	assert_eq(_log.current_run.get("enemies_killed", 0), 0,
			"current_run should reset after start_run")

func test_record_kill() -> void:
	_log.start_run(&"dungeon", "0_0")
	_log.record_kill()
	_log.record_kill()
	_log.record_kill()
	assert_eq(_log.current_run.get("enemies_killed", 0), 3)

func test_record_floor() -> void:
	_log.start_run(&"dungeon", "0_0")
	_log.record_floor()
	_log.record_floor()
	assert_eq(_log.current_run.get("floors_descended", 0), 2)

func test_record_loot() -> void:
	_log.start_run(&"dungeon", "0_0")
	_log.record_loot(5)
	_log.record_loot(2)
	assert_eq(_log.current_run.get("items_looted", 0), 7)

func test_record_chest() -> void:
	_log.start_run(&"dungeon", "0_0")
	_log.record_chest()
	assert_eq(_log.current_run.get("chests_opened", 0), 1)

func test_to_dict_from_dict_round_trip() -> void:
	_log.start_run(&"dungeon", "0_0")
	_log.record_kill()
	_log.record_loot(3)
	var d: Dictionary = _log.to_dict()
	var log2 := TravelLog.new()
	log2.from_dict(d)
	assert_eq(log2.current_run.get("enemies_killed", 0), 1)
	assert_eq(log2.current_run.get("items_looted", 0), 3)

func test_no_op_before_start_run() -> void:
	# Calling record methods before start_run should not crash.
	_log.record_kill()
	_log.record_floor()
	_log.record_loot(1)
	_log.record_chest()
	assert_true(true, "No crash before start_run")
