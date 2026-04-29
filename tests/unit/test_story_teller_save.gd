extends GutTest

func before_each() -> void:
	QuestTracker.reset()
	GameState.clear_flags()

func test_version_is_5() -> void:
	assert_eq(SaveGame.VERSION, 5)

func test_quest_tracker_data_saved_and_restored() -> void:
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	QuestTracker.advance_objective("herbalist_remedy", "get_fennel", 2)
	var save := SaveGame.new()
	# Snapshot calls QuestTracker.to_dict() — no world needed for unit test.
	save.quest_tracker_data = QuestTracker.to_dict()
	# Restore into a fresh state.
	QuestTracker.reset()
	assert_false(QuestTracker.is_quest_active("herbalist_remedy"),
			"After reset, quest should not be active")
	QuestTracker.from_dict(save.quest_tracker_data)
	assert_true(QuestTracker.is_quest_active("herbalist_remedy"),
			"After restore, quest should be active")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel"), 2,
			"Objective progress should survive save/load")

func test_caravan_data_travel_log_round_trip() -> void:
	var cd := CaravanData.new()
	cd.travel_logs[0].start_run(&"dungeon", "0_0")
	cd.travel_logs[0].record_kill()
	cd.travel_logs[0].record_kill()
	cd.member_names[&"warrior"] = "Derin"
	var d := cd.to_dict()
	var cd2 := CaravanData.new()
	cd2.from_dict(d)
	assert_eq(cd2.travel_logs[0].current_run.get("enemies_killed", 0), 2,
			"Kill count should survive CaravanData to_dict/from_dict round-trip")
	assert_eq(cd2.member_names.get(&"warrior", ""), "Derin",
			"Member name should survive round-trip")
