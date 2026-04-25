extends GutTest

func test_fog_survives_save_load_round_trip() -> void:
	# Arrange: set up WorldManager with a known seed and region.
	WorldManager.reset(202402)
	var region: Region = WorldManager.get_or_generate(Vector2i.ZERO)
	assert_not_null(region)

	# Arrange: create a player with some fog revealed.
	var player := PlayerController.new()
	player.player_id = 0
	add_child_autofree(player)
	player.fog_of_war.reveal(Vector2i.ZERO, Vector2i(20, 20), 5)
	assert_true(player.fog_of_war.is_revealed(Vector2i.ZERO, Vector2i(20, 20)))
	assert_false(player.fog_of_war.is_revealed(Vector2i.ZERO, Vector2i(0, 0)))

	# Act: snapshot to PlayerSaveData.
	var psd := PlayerSaveData.new()
	psd.fog_data = player.fog_of_war.to_dict()

	# Act: restore to a fresh player.
	var player2 := PlayerController.new()
	player2.player_id = 0
	add_child_autofree(player2)
	player2.fog_of_war.from_dict(psd.fog_data)

	# Assert: fog state is identical.
	assert_true(player2.fog_of_war.is_revealed(Vector2i.ZERO, Vector2i(20, 20)))
	assert_false(player2.fog_of_war.is_revealed(Vector2i.ZERO, Vector2i(0, 0)))
