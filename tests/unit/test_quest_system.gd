## Unit tests for the quest data layer: QuestRegistry, QuestTracker, and
## the herbalist_remedy.json prototype quest file.
extends GutTest


# ─── QuestRegistry: loading and queries ───────────────────────────

func test_registry_loads_quests() -> void:
	QuestRegistry.reload()
	var ids: Array[String] = QuestRegistry.all_ids()
	assert_true(ids.size() > 0, "should load at least one quest")
	assert_true(ids.has("herbalist_remedy"), "herbalist_remedy should be loaded")


func test_registry_get_quest_returns_dict() -> void:
	QuestRegistry.reload()
	var quest: Dictionary = QuestRegistry.get_quest("herbalist_remedy")
	assert_eq(quest["id"], "herbalist_remedy")
	assert_eq(quest["display_name"], "The Quiet Sickness")
	assert_eq(quest["giver"], "Mara")


func test_registry_get_quest_unknown_returns_empty() -> void:
	QuestRegistry.reload()
	var quest: Dictionary = QuestRegistry.get_quest("nonexistent_quest")
	assert_true(quest.is_empty())


func test_registry_get_branch_main() -> void:
	QuestRegistry.reload()
	var branch: Dictionary = QuestRegistry.get_branch("herbalist_remedy", "main")
	assert_eq(branch["trigger_flag"], "quest_herbalist_main")
	var objs: Array = branch["objectives"]
	assert_eq(objs.size(), 8, "main branch has 8 sequential objectives")
	assert_eq(objs[0]["id"], "enter_mine")
	assert_eq(objs[0]["type"], "reach")
	assert_eq(objs[4]["id"], "get_fennel")
	assert_eq(objs[4]["type"], "collect")


func test_registry_get_branch_unknown_returns_empty() -> void:
	QuestRegistry.reload()
	var branch: Dictionary = QuestRegistry.get_branch("herbalist_remedy", "nope")
	assert_true(branch.is_empty())


func test_registry_get_prerequisites_empty() -> void:
	QuestRegistry.reload()
	var prereqs: Array[String] = QuestRegistry.get_prerequisites("herbalist_remedy")
	assert_eq(prereqs.size(), 0, "herbalist_remedy has no prerequisites")


# ─── Requirements manifest ────────────────────────────────────────

func test_registry_get_unimplemented_requirements() -> void:
	QuestRegistry.reload()
	var missing: Array[Dictionary] = QuestRegistry.get_unimplemented_requirements("herbalist_remedy")
	# All requirements are now IMPLEMENTED — missing list should be empty.
	assert_eq(missing.size(), 0, "all requirements should be IMPLEMENTED")


func test_registry_requirement_summary() -> void:
	QuestRegistry.reload()
	var summary: Dictionary = QuestRegistry.get_requirement_summary("herbalist_remedy")
	assert_true(summary["total"] > 0, "should have requirements")
	assert_eq(summary["not_implemented"], 0, "all requirements should be implemented")
	assert_eq(summary["implemented"], summary["total"])


func test_registry_requirements_cover_all_categories() -> void:
	QuestRegistry.reload()
	var missing: Array[Dictionary] = QuestRegistry.get_unimplemented_requirements("herbalist_remedy")
	# All requirements are implemented — no NOT_IMPLEMENTED entries remain.
	assert_eq(missing.size(), 0, "no unimplemented requirements")


# ─── QuestTracker: lifecycle ──────────────────────────────────────

func test_tracker_start_quest_main() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "main")
	assert_true(QuestTracker.is_quest_active("herbalist_remedy"))
	assert_false(QuestTracker.is_quest_complete("herbalist_remedy"))
	assert_eq(QuestTracker.get_active_branch("herbalist_remedy"), "main")
	assert_true(GameState.get_flag("quest_herbalist_main"), "trigger flag should be set")
	assert_true(GameState.get_flag("quest_herbalist_remedy_started"), "started flag should be set")
	GameState.clear_flags()


func test_tracker_start_quest_main_branch() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "main")
	assert_eq(QuestTracker.get_active_branch("herbalist_remedy"), "main")
	assert_true(GameState.get_flag("quest_herbalist_main"), "main trigger flag should be set")
	GameState.clear_flags()


func test_tracker_start_ignores_duplicate() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "main")
	QuestTracker.start_quest("herbalist_remedy", "mine")
	assert_eq(QuestTracker.get_active_branch("herbalist_remedy"), "main",
		"second start should be ignored")
	GameState.clear_flags()


func test_tracker_advance_objective() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "main")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel"), 0)
	QuestTracker.advance_objective("herbalist_remedy", "get_fennel")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel"), 1)
	GameState.clear_flags()


func test_tracker_mark_objective_done() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "main")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_mushroom")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_mushroom"), 1)
	GameState.clear_flags()


func test_tracker_not_ready_until_all_objectives_met() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "main")
	# Complete only 7 of 8 objectives.
	for obj_id in ["enter_mine", "seal_leak", "get_evidence", "show_evidence",
			"get_fennel", "get_mushroom", "get_water"]:
		QuestTracker.mark_objective_done("herbalist_remedy", obj_id)
	assert_false(QuestTracker.is_quest_ready_to_complete("herbalist_remedy"),
		"should not be ready — return_mara not done")
	GameState.clear_flags()


func test_tracker_ready_when_all_objectives_met() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "main")
	for obj_id in ["enter_mine", "seal_leak", "get_evidence", "show_evidence",
			"get_fennel", "get_mushroom", "get_water", "return_mara"]:
		QuestTracker.mark_objective_done("herbalist_remedy", obj_id)
	assert_true(QuestTracker.is_quest_ready_to_complete("herbalist_remedy"))
	GameState.clear_flags()


func test_tracker_complete_quest_sets_flags() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "main")
	for obj_id in ["enter_mine", "seal_leak", "get_evidence", "show_evidence",
			"get_fennel", "get_mushroom", "get_water", "return_mara"]:
		QuestTracker.mark_objective_done("herbalist_remedy", obj_id)
	QuestTracker.complete_quest("herbalist_remedy")
	assert_true(QuestTracker.is_quest_complete("herbalist_remedy"))
	assert_false(QuestTracker.is_quest_active("herbalist_remedy"))
	assert_true(GameState.get_flag("quest_herbalist_remedy_complete"), "completion flag should be set")
	assert_true(GameState.get_flag("valley_remedy_brewed"), "branch reward flag should be set")
	GameState.clear_flags()


func test_tracker_complete_does_nothing_if_not_ready() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "main")
	QuestTracker.complete_quest("herbalist_remedy")
	assert_false(QuestTracker.is_quest_complete("herbalist_remedy"),
		"should not complete — objectives not met")
	GameState.clear_flags()


# ─── Serialization ────────────────────────────────────────────────

func test_tracker_serialization_roundtrip() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "main")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_fennel")
	var snapshot: Dictionary = QuestTracker.to_dict()
	QuestTracker.reset()
	assert_false(QuestTracker.is_quest_active("herbalist_remedy"), "should be cleared after reset")
	QuestTracker.from_dict(snapshot)
	assert_true(QuestTracker.is_quest_active("herbalist_remedy"), "should restore after from_dict")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel"), 1)
	assert_eq(QuestTracker.get_active_branch("herbalist_remedy"), "main")
	GameState.clear_flags()


# ─── Edge cases ───────────────────────────────────────────────────

func test_tracker_advance_unknown_quest_is_noop() -> void:
	QuestTracker.reset()
	QuestTracker.advance_objective("nonexistent", "obj1")
	# No crash, no error — just a no-op.
	assert_eq(QuestTracker.get_objective_progress("nonexistent", "obj1"), -1)


func test_tracker_advance_unknown_objective_is_noop() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "main")
	QuestTracker.advance_objective("herbalist_remedy", "nonexistent_obj")
	# Should not crash.
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "nonexistent_obj"), -1)
	GameState.clear_flags()


func test_tracker_inactive_quest_queries() -> void:
	QuestTracker.reset()
	assert_false(QuestTracker.is_quest_active("herbalist_remedy"))
	assert_false(QuestTracker.is_quest_complete("herbalist_remedy"))
	assert_eq(QuestTracker.get_active_branch("herbalist_remedy"), "")
	assert_false(QuestTracker.is_quest_ready_to_complete("herbalist_remedy"))


func test_registry_get_quests_by_giver_mara() -> void:
	QuestRegistry.reload()
	var ids: Array[String] = QuestRegistry.get_quests_by_giver("Mara")
	assert_true(ids.has("herbalist_remedy"), "Mara should give herbalist_remedy")


func test_registry_get_quests_by_giver_unknown_returns_empty() -> void:
	QuestRegistry.reload()
	var ids: Array[String] = QuestRegistry.get_quests_by_giver("Nobody")
	assert_true(ids.is_empty(), "Unknown giver returns empty array")
