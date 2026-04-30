extends GutTest

func test_xp_to_next_level_1() -> void:
	assert_eq(LevelingConfig.xp_to_next(1), 100)

func test_xp_to_next_level_10() -> void:
	assert_eq(LevelingConfig.xp_to_next(10), 1000)

func test_xp_to_next_level_19() -> void:
	assert_eq(LevelingConfig.xp_to_next(19), 1900)

func test_xp_to_next_level_20_returns_sentinel() -> void:
	assert_true(LevelingConfig.xp_to_next(20) > 99999)

func test_milestone_level_5_is_hardy() -> void:
	assert_eq(LevelingConfig.milestone_passive(5), &"hardy")

func test_milestone_level_10_is_scavenger() -> void:
	assert_eq(LevelingConfig.milestone_passive(10), &"scavenger")

func test_milestone_level_15_is_iron_skin() -> void:
	assert_eq(LevelingConfig.milestone_passive(15), &"iron_skin")

func test_milestone_level_20_is_hero() -> void:
	assert_eq(LevelingConfig.milestone_passive(20), &"hero")

func test_milestone_non_milestone_returns_empty() -> void:
	assert_eq(LevelingConfig.milestone_passive(3), &"")

func test_xp_reward_default_for_unknown_creature() -> void:
	assert_eq(CreatureSpriteRegistry.get_xp_reward(&"__nonexistent__"), 10)
