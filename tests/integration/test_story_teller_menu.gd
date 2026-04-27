# tests/integration/test_story_teller_menu.gd
extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")
var _game: Game = null

func before_each() -> void:
	WorldManager.reset(202402)
	_game = _GameScene.instantiate()
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	_game = null

func test_story_teller_recruited_at_start() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	var cd := world.get_caravan_data(0)
	assert_not_null(cd, "CaravanData should exist")
	assert_true(cd.has_member(&"story_teller"),
			"Story teller should be auto-recruited at game start")

func test_story_teller_has_name_assigned() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	var cd := world.get_caravan_data(0)
	if cd == null:
		pending("CaravanData not available")
		return
	var name: String = cd.get_member_name(&"story_teller")
	assert_true(name.length() > 0, "Story teller should have a non-empty name")
	assert_ne(name, "story_teller", "Name should be from pool, not fall back to id")

func test_both_players_get_story_teller() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	for pid in [0, 1]:
		var cd := world.get_caravan_data(pid)
		assert_not_null(cd)
		assert_true(cd.has_member(&"story_teller"),
				"P%d should have story_teller recruited" % (pid + 1))

func test_travel_logs_initialized_per_player() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	for pid in [0, 1]:
		var cd := world.get_caravan_data(pid)
		if cd == null:
			pending("CaravanData not available for P%d" % (pid + 1))
			return
		assert_eq(cd.travel_logs.size(), 2, "Should have 2 TravelLog slots")
		assert_not_null(cd.travel_logs[pid],
				"TravelLog for P%d should not be null" % (pid + 1))

func test_all_members_have_names_assigned() -> void:
	var world := World.instance()
	if world == null:
		pending("World not available")
		return
	var cd := world.get_caravan_data(0)
	if cd == null:
		pending("CaravanData not available")
		return
	for mid in [&"story_teller", &"warrior", &"blacksmith", &"cook", &"alchemist"]:
		var name: String = cd.get_member_name(mid)
		assert_true(name.length() > 0, "Member %s should have a name" % mid)
