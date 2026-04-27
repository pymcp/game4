# tests/unit/test_game_state_prefix.gd
extends GutTest

func before_each() -> void:
	GameState.clear_flags()

func test_keys_with_prefix_returns_matching_keys() -> void:
	GameState.set_flag("met_mara")
	GameState.set_flag("met_the_guard")
	GameState.set_flag("quest_herbalist_started")
	var keys := GameState.keys_with_prefix("met_")
	assert_eq(keys.size(), 2, "Should return only met_ keys")
	assert_true("met_mara" in keys)
	assert_true("met_the_guard" in keys)

func test_keys_with_prefix_empty_when_none_match() -> void:
	GameState.set_flag("quest_herbalist_started")
	var keys := GameState.keys_with_prefix("lore_")
	assert_eq(keys.size(), 0)

func test_keys_with_prefix_only_true_flags() -> void:
	GameState.set_flag("met_guard", true)
	GameState.set_flag("met_bandit", false)
	var keys := GameState.keys_with_prefix("met_")
	assert_true("met_guard" in keys)
	assert_false("met_bandit" in keys,
			"False flags should not appear in prefix list")
