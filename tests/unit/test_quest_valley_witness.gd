## Unit tests for the valley_witness quest data layer.
extends GutTest


func before_each() -> void:
	QuestRegistry.reload()


# ─── QuestRegistry: quest loads ───────────────────────────────────

func test_valley_witness_loads() -> void:
	var ids: Array[String] = QuestRegistry.all_ids()
	assert_true(ids.has("valley_witness"), "valley_witness should be loaded")


func test_valley_witness_metadata() -> void:
	var quest: Dictionary = QuestRegistry.get_quest("valley_witness")
	assert_eq(quest["id"], "valley_witness")
	assert_eq(quest["display_name"], "The Word on the Wind")
	assert_eq(quest["giver"], "Edda")


func test_valley_witness_main_branch_exists() -> void:
	var branch: Dictionary = QuestRegistry.get_branch("valley_witness", "main")
	assert_false(branch.is_empty(), "main branch should exist")
	assert_eq(branch["trigger_flag"], "quest_valley_witness_main")


func test_valley_witness_objectives_structure() -> void:
	var branch: Dictionary = QuestRegistry.get_branch("valley_witness", "main")
	var objs: Array = branch["objectives"]
	assert_eq(objs.size(), 4, "quest has 4 objectives")
	assert_eq(objs[0]["id"], "talk_edda")
	assert_eq(objs[0]["type"], "talk")
	assert_eq(objs[1]["id"], "examine_well")
	assert_eq(objs[1]["type"], "interact")
	assert_eq(objs[2]["id"], "speak_farmer")
	assert_eq(objs[2]["type"], "talk")
	assert_eq(objs[3]["id"], "return_edda")
	assert_eq(objs[3]["type"], "talk")


func test_valley_witness_rewards_set_flags() -> void:
	var branch: Dictionary = QuestRegistry.get_branch("valley_witness", "main")
	var rewards: Array = branch["rewards"]
	var flags: Array = rewards.filter(func(r: Dictionary) -> bool: return r["type"] == "flag")
	var flag_names: Array = flags.map(func(r: Dictionary) -> String: return r["flag"])
	assert_true(flag_names.has("edda_quest_complete"), "edda_quest_complete reward flag")
	assert_true(flag_names.has("aldric_known"), "aldric_known reward flag")


func test_valley_witness_has_no_unimplemented_requirements() -> void:
	# All requirements start as NOT_IMPLEMENTED; this test will fail until
	# each one is marked IMPLEMENTED.
	var missing: Array[Dictionary] = QuestRegistry.get_unimplemented_requirements("valley_witness")
	assert_eq(missing.size(), 0, "all requirements should be IMPLEMENTED")


# ─── QuestTracker: runtime integration ────────────────────────────

func test_tracker_can_start_valley_witness() -> void:
	QuestTracker.reset()
	QuestTracker.start_quest("valley_witness", "main")
	assert_true(QuestTracker.is_quest_active("valley_witness"))
	assert_true(GameState.get_flag("quest_valley_witness_main"))


func test_tracker_advance_examine_well() -> void:
	QuestTracker.reset()
	QuestTracker.start_quest("valley_witness", "main")
	QuestTracker.mark_objective_done("valley_witness", "examine_well")
	assert_true(GameState.get_flag("quest_valley_witness_obj_examine_well_done"))


func test_tracker_complete_sets_aldric_known() -> void:
	QuestTracker.reset()
	GameState.clear_flags()
	QuestTracker.start_quest("valley_witness", "main")
	QuestTracker.mark_objective_done("valley_witness", "talk_edda")
	QuestTracker.mark_objective_done("valley_witness", "examine_well")
	QuestTracker.mark_objective_done("valley_witness", "speak_farmer")
	QuestTracker.mark_objective_done("valley_witness", "return_edda")
	QuestTracker.complete_quest("valley_witness")
	assert_true(GameState.get_flag("aldric_known"), "aldric_known should be set on completion")
	assert_true(GameState.get_flag("edda_quest_complete"), "edda_quest_complete should be set")
