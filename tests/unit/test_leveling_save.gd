extends GutTest

func test_player_save_data_has_xp_field() -> void:
	var psd := PlayerSaveData.new()
	assert_eq(psd.xp, 0)

func test_player_save_data_has_level_field() -> void:
	var psd := PlayerSaveData.new()
	assert_eq(psd.level, 1)

func test_player_save_data_has_unlocked_passives_field() -> void:
	var psd := PlayerSaveData.new()
	assert_eq(psd.unlocked_passives.size(), 0)

func test_player_save_data_has_pending_stat_points_field() -> void:
	var psd := PlayerSaveData.new()
	assert_eq(psd.pending_stat_points, 0)

func test_xp_round_trip_through_save_data() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	p.xp = 75
	p.level = 3
	p._pending_stat_points = 2
	p.unlocked_passives.append(&"hardy")

	# Simulate what SaveGame.snapshot() does
	var psd := PlayerSaveData.new()
	psd.xp = p.xp
	psd.level = p.level
	psd.pending_stat_points = p._pending_stat_points
	psd.unlocked_passives = p.unlocked_passives.duplicate()

	# Simulate what SaveGame.apply() does
	var p2 := PlayerController.new()
	add_child_autofree(p2)
	p2.xp = psd.xp
	p2.level = psd.level
	p2._pending_stat_points = psd.pending_stat_points
	p2.unlocked_passives = psd.unlocked_passives.duplicate()

	assert_eq(p2.xp, 75)
	assert_eq(p2.level, 3)
	assert_eq(p2._pending_stat_points, 2)
	assert_true(&"hardy" in p2.unlocked_passives)
