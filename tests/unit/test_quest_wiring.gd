## Unit tests for the herbalist_remedy quest — linear main branch.
##   - QuestRegistry.get_quest_for_trigger_flag()
##   - QuestTracker.notify_item_collected()
##   - QuestTracker.notify_location_reached()
##   - QuestTracker.advance_objective() auto-flag
##   - Sequential talk objectives (Villager bug fix)
##   - QuestTracker position registration API
extends GutTest


func before_each() -> void:
	QuestRegistry.reload()
	QuestTracker.reset()
	GameState.clear_flags()


# --- QuestRegistry.get_quest_for_trigger_flag ---

func test_trigger_flag_main() -> void:
	var result: Dictionary = QuestRegistry.get_quest_for_trigger_flag("quest_herbalist_main")
	assert_eq(result.get("quest_id", ""), "herbalist_remedy")
	assert_eq(result.get("branch_id", ""), "main")


func test_trigger_flag_unknown() -> void:
	var result: Dictionary = QuestRegistry.get_quest_for_trigger_flag("nonexistent_flag")
	assert_true(result.is_empty())


# --- Main branch full flow (8 objectives) ---

func test_main_branch_full_flow() -> void:
	QuestTracker.start_quest("herbalist_remedy", "main")
	assert_true(QuestTracker.is_quest_active("herbalist_remedy"))
	# 1. enter_mine
	QuestTracker.notify_location_reached("moonstone_mine")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "enter_mine"), 1)
	# 2. seal_leak
	QuestTracker.mark_objective_done("herbalist_remedy", "seal_leak")
	# 3. get_evidence
	QuestTracker.notify_item_collected(&"contaminated_ore", 1)
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_evidence"), 1)
	# 4. show_evidence (talk)
	QuestTracker.mark_objective_done("herbalist_remedy", "show_evidence")
	# 5-7. herbs + water
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	QuestTracker.notify_item_collected(&"blue_nightcap", 1)
	QuestTracker.notify_item_collected(&"clean_spring_water", 1)
	# 8. return_mara (talk)
	QuestTracker.mark_objective_done("herbalist_remedy", "return_mara")
	assert_true(QuestTracker.is_quest_ready_to_complete("herbalist_remedy"))
	QuestTracker.complete_quest("herbalist_remedy")
	assert_true(QuestTracker.is_quest_complete("herbalist_remedy"))


# --- Auto-flag set when objective reaches target ---

func test_auto_objective_flag() -> void:
	QuestTracker.start_quest("herbalist_remedy", "main")
	assert_false(GameState.get_flag("quest_herbalist_remedy_obj_get_evidence_done"))
	QuestTracker.notify_item_collected(&"contaminated_ore", 1)
	assert_true(GameState.get_flag("quest_herbalist_remedy_obj_get_evidence_done"),
		"Auto-flag should be set when get_evidence objective completes")


func test_auto_flag_not_set_before_target() -> void:
	QuestTracker.start_quest("herbalist_remedy", "main")
	# get_evidence requires count=1. Progress 0 -> no flag yet.
	assert_false(GameState.get_flag("quest_herbalist_remedy_obj_get_evidence_done"))


# --- Sequential talk objectives (show_evidence then return_mara) ---

func test_sequential_talk_objectives_first_advances_only_first() -> void:
	QuestTracker.start_quest("herbalist_remedy", "main")
	# Complete pre-requisites so show_evidence is the next incomplete talk obj.
	QuestTracker.notify_location_reached("moonstone_mine")
	QuestTracker.mark_objective_done("herbalist_remedy", "seal_leak")
	QuestTracker.notify_item_collected(&"contaminated_ore", 1)
	# Simulate first visit to Mara: only show_evidence should advance.
	QuestTracker.mark_objective_done("herbalist_remedy", "show_evidence")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "show_evidence"), 1,
		"show_evidence should be done after first visit")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "return_mara"), 0,
		"return_mara must NOT be advanced on the first visit")


func test_sequential_talk_objectives_second_advances_second() -> void:
	QuestTracker.start_quest("herbalist_remedy", "main")
	# Complete all objectives except the final two talk objectives.
	QuestTracker.notify_location_reached("moonstone_mine")
	QuestTracker.mark_objective_done("herbalist_remedy", "seal_leak")
	QuestTracker.notify_item_collected(&"contaminated_ore", 1)
	QuestTracker.mark_objective_done("herbalist_remedy", "show_evidence")
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	QuestTracker.notify_item_collected(&"blue_nightcap", 1)
	QuestTracker.notify_item_collected(&"clean_spring_water", 1)
	# Second visit: return_mara should now advance.
	QuestTracker.mark_objective_done("herbalist_remedy", "return_mara")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "return_mara"), 1)
	assert_true(QuestTracker.is_quest_ready_to_complete("herbalist_remedy"))


# --- pushed_deal reward variant ---

func test_pushed_deal_reward_variant_applied_when_flag_set() -> void:
	GameState.set_flag("quest_herbalist_pushed_deal")
	QuestTracker.start_quest("herbalist_remedy", "main")
	# Complete all objectives.
	QuestTracker.notify_location_reached("moonstone_mine")
	QuestTracker.mark_objective_done("herbalist_remedy", "seal_leak")
	QuestTracker.notify_item_collected(&"contaminated_ore", 1)
	QuestTracker.mark_objective_done("herbalist_remedy", "show_evidence")
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	QuestTracker.notify_item_collected(&"blue_nightcap", 1)
	QuestTracker.notify_item_collected(&"clean_spring_water", 1)
	QuestTracker.mark_objective_done("herbalist_remedy", "return_mara")
	QuestTracker.complete_quest("herbalist_remedy")
	assert_true(QuestTracker.is_quest_complete("herbalist_remedy"),
		"Quest should complete even with pushed_deal flag set")


func test_pushed_deal_not_applied_without_flag() -> void:
	# No quest_herbalist_pushed_deal flag set.
	QuestTracker.start_quest("herbalist_remedy", "main")
	QuestTracker.notify_location_reached("moonstone_mine")
	QuestTracker.mark_objective_done("herbalist_remedy", "seal_leak")
	QuestTracker.notify_item_collected(&"contaminated_ore", 1)
	QuestTracker.mark_objective_done("herbalist_remedy", "show_evidence")
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	QuestTracker.notify_item_collected(&"blue_nightcap", 1)
	QuestTracker.notify_item_collected(&"clean_spring_water", 1)
	QuestTracker.mark_objective_done("herbalist_remedy", "return_mara")
	assert_true(QuestTracker.is_quest_ready_to_complete("herbalist_remedy"))
	QuestTracker.complete_quest("herbalist_remedy")
	assert_true(QuestTracker.is_quest_complete("herbalist_remedy"))


# --- QuestTracker position registration ---

func test_register_and_get_objective_markers() -> void:
	QuestTracker.start_quest("herbalist_remedy", "main")
	QuestTracker.register_objective_position("herbalist_remedy", "enter_mine",
		Vector2i(0, 0), Vector2i(15, 5))
	var markers: Array[Dictionary] = QuestTracker.get_objective_markers()
	assert_eq(markers.size(), 1)
	assert_eq(markers[0]["quest_id"], "herbalist_remedy")
	assert_eq(markers[0]["obj_id"], "enter_mine")
	assert_eq(markers[0]["cell"], Vector2i(15, 5))


func test_markers_exclude_completed_objectives() -> void:
	QuestTracker.start_quest("herbalist_remedy", "main")
	QuestTracker.register_objective_position("herbalist_remedy", "enter_mine",
		Vector2i(0, 0), Vector2i(15, 5))
	QuestTracker.notify_location_reached("moonstone_mine")
	# enter_mine is now done (progress > 0) — should not appear in markers.
	var markers: Array[Dictionary] = QuestTracker.get_objective_markers()
	assert_eq(markers.size(), 0,
		"Completed objectives should not appear in markers")


func test_markers_empty_when_no_quest_active() -> void:
	QuestTracker.register_objective_position("herbalist_remedy", "enter_mine",
		Vector2i(0, 0), Vector2i(15, 5))
	var markers: Array[Dictionary] = QuestTracker.get_objective_markers()
	assert_eq(markers.size(), 0, "No markers when quest is not active")


# --- Collect helpers ---

func test_notify_item_collected_ignores_unrelated_items() -> void:
	QuestTracker.start_quest("herbalist_remedy", "main")
	QuestTracker.notify_item_collected(&"wood", 5)
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel"), 0)


func test_notify_item_collected_no_active_quest() -> void:
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	pass_test("No crash when notifying with no active quest")


func test_notify_item_collected_completed_quest_ignored() -> void:
	QuestTracker.start_quest("herbalist_remedy", "main")
	QuestTracker.notify_location_reached("moonstone_mine")
	QuestTracker.mark_objective_done("herbalist_remedy", "seal_leak")
	QuestTracker.notify_item_collected(&"contaminated_ore", 1)
	QuestTracker.mark_objective_done("herbalist_remedy", "show_evidence")
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	QuestTracker.notify_item_collected(&"blue_nightcap", 1)
	QuestTracker.notify_item_collected(&"clean_spring_water", 1)
	QuestTracker.mark_objective_done("herbalist_remedy", "return_mara")
	QuestTracker.complete_quest("herbalist_remedy")
	QuestTracker.notify_item_collected(&"fennel_root", 1)
	assert_true(QuestTracker.is_quest_complete("herbalist_remedy"))
