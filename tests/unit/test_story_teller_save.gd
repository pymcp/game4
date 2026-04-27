extends GutTest

func before_each() -> void:
	QuestTracker.reset()
	GameState.clear_flags()

func test_version_is_4() -> void:
	assert_eq(SaveGame.VERSION, 4)

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

func test_travel_log_data_in_caravan_save_data() -> void:
	var csd := CaravanSaveData.new()
	csd.travel_log_data = [{"current_run": {"enemies_killed": 5}}, {}]
	assert_eq(csd.travel_log_data[0].get("current_run", {}).get("enemies_killed", 0), 5)
