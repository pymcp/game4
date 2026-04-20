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


func test_registry_get_branch_herbs() -> void:
	QuestRegistry.reload()
	var branch: Dictionary = QuestRegistry.get_branch("herbalist_remedy", "herbs")
	assert_eq(branch["trigger_flag"], "quest_herbalist_herbs")
	var objs: Array = branch["objectives"]
	assert_eq(objs.size(), 4)
	assert_eq(objs[0]["id"], "get_fennel")
	assert_eq(objs[0]["type"], "collect")


func test_registry_get_branch_mine() -> void:
	QuestRegistry.reload()
	var branch: Dictionary = QuestRegistry.get_branch("herbalist_remedy", "mine")
	assert_eq(branch["trigger_flag"], "quest_herbalist_mine")
	var objs: Array = branch["objectives"]
	assert_eq(objs.size(), 4)
	assert_eq(objs[0]["id"], "enter_mine")
	assert_eq(objs[0]["type"], "reach")


func test_registry_get_branch_both_merges_objectives() -> void:
	QuestRegistry.reload()
	var branch: Dictionary = QuestRegistry.get_branch("herbalist_remedy", "both")
	assert_eq(branch["trigger_flag"], "quest_herbalist_both")
	# "both" includes herbs (4 objectives) + mine (4 objectives) = 8
	var objs: Array = branch["objectives"]
	assert_eq(objs.size(), 8, "both branch should merge herbs + mine objectives")
	# First 4 from herbs, next 4 from mine.
	assert_eq(objs[0]["id"], "get_fennel")
	assert_eq(objs[4]["id"], "enter_mine")


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
	assert_true(missing.size() > 0, "all requirements should be NOT_IMPLEMENTED")
	# Verify each entry has expected keys.
	for entry in missing:
		assert_true(entry.has("id"), "entry should have id")
		assert_true(entry.has("status"), "entry should have status")
		assert_true(entry.has("category"), "entry should have category")
		assert_eq(entry["status"], "NOT_IMPLEMENTED")


func test_registry_requirement_summary() -> void:
	QuestRegistry.reload()
	var summary: Dictionary = QuestRegistry.get_requirement_summary("herbalist_remedy")
	assert_true(summary["total"] > 0, "should have requirements")
	assert_eq(summary["implemented"], 0, "nothing implemented yet")
	assert_eq(summary["not_implemented"], summary["total"])


func test_registry_requirements_cover_all_categories() -> void:
	QuestRegistry.reload()
	var missing: Array[Dictionary] = QuestRegistry.get_unimplemented_requirements("herbalist_remedy")
	var categories: Dictionary = {}
	for entry in missing:
		categories[entry["category"]] = true
	assert_true(categories.has("npcs"), "should have NPC requirements")
	assert_true(categories.has("items"), "should have item requirements")
	assert_true(categories.has("locations"), "should have location requirements")
	assert_true(categories.has("entities"), "should have entity requirements")
	assert_true(categories.has("terrain_features"), "should have terrain requirements")
	assert_true(categories.has("dialogue_updates"), "should have dialogue update requirements")


# ─── QuestTracker: lifecycle ──────────────────────────────────────

func test_tracker_start_quest_herbs() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	assert_true(QuestTracker.is_quest_active("herbalist_remedy"))
	assert_false(QuestTracker.is_quest_complete("herbalist_remedy"))
	assert_eq(QuestTracker.get_active_branch("herbalist_remedy"), "herbs")
	assert_true(GameState.get_flag("quest_herbalist_herbs"), "trigger flag should be set")
	assert_true(GameState.get_flag("quest_herbalist_remedy_started"), "started flag should be set")
	GameState.clear_flags()


func test_tracker_start_quest_mine() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "mine")
	assert_eq(QuestTracker.get_active_branch("herbalist_remedy"), "mine")
	assert_true(GameState.get_flag("quest_herbalist_mine"), "mine trigger flag should be set")
	GameState.clear_flags()


func test_tracker_start_ignores_duplicate() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	QuestTracker.start_quest("herbalist_remedy", "mine")
	assert_eq(QuestTracker.get_active_branch("herbalist_remedy"), "herbs",
		"second start should be ignored")
	GameState.clear_flags()


func test_tracker_advance_objective() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel"), 0)
	QuestTracker.advance_objective("herbalist_remedy", "get_fennel")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel"), 1)
	GameState.clear_flags()


func test_tracker_mark_objective_done() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_mushroom")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_mushroom"), 1)
	GameState.clear_flags()


func test_tracker_not_ready_until_all_objectives_met() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	# Complete only 3 of 4 objectives.
	QuestTracker.mark_objective_done("herbalist_remedy", "get_fennel")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_mushroom")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_water")
	assert_false(QuestTracker.is_quest_ready_to_complete("herbalist_remedy"),
		"should not be ready — return_mara not done")
	GameState.clear_flags()


func test_tracker_ready_when_all_objectives_met() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_fennel")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_mushroom")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_water")
	QuestTracker.mark_objective_done("herbalist_remedy", "return_mara")
	assert_true(QuestTracker.is_quest_ready_to_complete("herbalist_remedy"))
	GameState.clear_flags()


func test_tracker_complete_quest_sets_flags() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_fennel")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_mushroom")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_water")
	QuestTracker.mark_objective_done("herbalist_remedy", "return_mara")
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
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	QuestTracker.complete_quest("herbalist_remedy")
	assert_false(QuestTracker.is_quest_complete("herbalist_remedy"),
		"should not complete — objectives not met")
	GameState.clear_flags()


# ─── Serialization ────────────────────────────────────────────────

func test_tracker_serialization_roundtrip() -> void:
	GameState.clear_flags()
	QuestRegistry.reload()
	QuestTracker.reset()
	QuestTracker.start_quest("herbalist_remedy", "herbs")
	QuestTracker.mark_objective_done("herbalist_remedy", "get_fennel")
	var snapshot: Dictionary = QuestTracker.to_dict()
	QuestTracker.reset()
	assert_false(QuestTracker.is_quest_active("herbalist_remedy"), "should be cleared after reset")
	QuestTracker.from_dict(snapshot)
	assert_true(QuestTracker.is_quest_active("herbalist_remedy"), "should restore after from_dict")
	assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "get_fennel"), 1)
	assert_eq(QuestTracker.get_active_branch("herbalist_remedy"), "herbs")
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
	QuestTracker.start_quest("herbalist_remedy", "herbs")
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
