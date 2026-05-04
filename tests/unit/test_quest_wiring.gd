## Unit tests for quest wiring infrastructure:
##   - QuestRegistry.get_quest_for_trigger_flag()
##   - QuestTracker.notify_item_collected()
##   - QuestTracker.notify_location_reached()
##   - QuestTracker give_item rewards
extends GutTest


func before_each() -> void:
	QuestRegistry.reload()
	QuestTracker.reset()
	GameState.clear_flags()


# ─── QuestRegistry.get_quest_for_trigger_flag ─────────────────────

func test_trigger_flag_herbs() -> void:
	var result: Dictionary = QuestRegistry.get_quest_for_trigger_flag("quest_herbalist_herbs")
	assert_eq(result.get("quest_id", ""), "herbalist_remedy")
	assert_eq(result.get("branch_id", ""), "herbs")


func test_trigger_flag_mine() -> void:
	var result: Dictionary = QuestRegistry.get_quest_for_trigger_flag("quest_herbalist_mine")
	assert_eq(result.get("quest_id", ""), "herbalist_remedy")
	assert_eq(result.get("branch_id", ""), "mine")


func test_trigger_flag_both() -> void:
	var result: Dictionary = QuestRegistry.get_quest_for_trigger_flag("quest_herbalist_both")
	assert_eq(result.get("quest_id", ""), "herbalist_remedy")
	assert_eq(result.get("branch_id", ""), "both")


func test_trigger_flag_unknown() -> void:
	var result: Dictionary = QuestRegistry.get_quest_for_trigger_flag("nonexistent_flag")
	assert_true(result.is_empty())


# ─── QuestTracker.notify_item_collected ───────────────────────────

func test_notify_item_collected_advances_collect_objective() -> void:
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	var progress: int = QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel")
	assert_eq(progress, 1)


func test_notify_item_collected_does_not_exceed_target() -> void:
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	QuestTracker.notify_item_collected(&"fennel_root", 5)
	var progress: int = QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel")
	assert_eq(progress, 1, "Should not exceed target count of 1")


func test_notify_item_collected_ignores_unrelated_items() -> void:
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	QuestTracker.notify_item_collected(&"wood", 5)
	var progress: int = QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel")
	assert_eq(progress, 0)


func test_notify_item_collected_no_active_quest() -> void:
	# Should not crash when no quest is active.
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	pass_test("No crash when notifying with no active quest")


func test_notify_item_collected_completed_quest_ignored() -> void:
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	# Mark all objectives done and complete.
	QuestTracker.mark_objective_done("herbalist_remedy", "get_fennel")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_mushroom")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_water")
	QuestTracker.mark_objective_done("herbalist_remedy", "return_mara")
	QuestTracker.complete_quest("herbalist_remedy")
	# Now collect more — should have no effect.
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	assert_true(QuestTracker.is_quest_complete("herbalist_remedy"))


# ─── QuestTracker.notify_location_reached ─────────────────────────

func test_notify_location_reached_marks_reach_objective() -> void:
	QuestTracker.start_quest("herbalist_remedy", "mine")
	QuestTracker.notify_location_reached("moonstone_mine")
	var progress: int = QuestTracker.get_objective_progress("herbalist_remedy", "enter_mine")
	assert_eq(progress, 1)


func test_notify_location_reached_ignores_wrong_location() -> void:
	QuestTracker.start_quest("herbalist_remedy", "mine")
	QuestTracker.notify_location_reached("some_other_dungeon")
	var progress: int = QuestTracker.get_objective_progress("herbalist_remedy", "enter_mine")
	assert_eq(progress, 0)


func test_notify_location_reached_no_active_quest() -> void:
	QuestTracker.notify_location_reached("moonstone_mine")
	pass_test("No crash when notifying location with no active quest")


# ─── Collect flow for "both" branch ──────────────────────────────

func test_both_branch_collects_from_both_branches() -> void:
	QuestTracker.start_quest("herbalist_remedy", "both")
	# Herbs objectives
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	QuestTracker.notify_item_collected(&"blue_nightcap", 1)
	QuestTracker.notify_item_collected(&"clean_spring_water", 1)
	# Mine objectives
	QuestTracker.notify_location_reached("moonstone_mine")
	QuestTracker.notify_item_collected(&"contaminated_ore", 1)
	# Check all objectives progressed.
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel"), 1)
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_mushroom"), 1)
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_water"), 1)
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "enter_mine"), 1)
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_evidence"), 1)


# ─── Quest completion with rewards ───────────────────────────────

func test_herbs_branch_completes_with_all_items() -> void:
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	QuestTracker.notify_item_collected(&"blue_nightcap", 1)
	QuestTracker.notify_item_collected(&"clean_spring_water", 1)
	QuestTracker.mark_objective_done("herbalist_remedy", "return_mara")
	assert_true(QuestTracker.is_quest_ready_to_complete("herbalist_remedy"))


func test_mine_branch_ready_after_all_objectives() -> void:
	QuestTracker.start_quest("herbalist_remedy", "mine")
	QuestTracker.notify_location_reached("moonstone_mine")
	QuestTracker.notify_item_collected(&"contaminated_ore", 1)
	QuestTracker.mark_objective_done("herbalist_remedy", "seal_leak")
	QuestTracker.mark_objective_done("herbalist_remedy", "return_mara")
	assert_true(QuestTracker.is_quest_ready_to_complete("herbalist_remedy"))
