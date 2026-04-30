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

# ---- PlayerController XP tests ----

func test_gain_xp_increases_xp() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	p.gain_xp(50)
	assert_eq(p.xp, 50)

func test_gain_xp_levels_up_when_threshold_met() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	p.gain_xp(100)  # level 1 threshold = 100
	assert_eq(p.level, 2)
	assert_eq(p.xp, 0)

func test_gain_xp_increases_max_health_on_level_up() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	var old_max := p.max_health
	p.gain_xp(100)
	assert_eq(p.max_health, old_max + 2)

func test_gain_xp_no_overflow_at_cap() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	p.level = 20
	p.gain_xp(50000)
	assert_eq(p.level, 20)
	assert_eq(p.xp, 0)

func test_level_up_adds_pending_stat_point() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	p.gain_xp(100)
	assert_eq(p._pending_stat_points, 1)

func test_spend_stat_point_increases_stat() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	var old_str: int = p.get_stat(&"strength")
	p._pending_stat_points = 1
	p.spend_stat_point(&"strength")
	assert_eq(p.get_stat(&"strength"), old_str + 1)
	assert_eq(p._pending_stat_points, 0)

func test_milestone_level_5_unlocks_hardy() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	p.level = 4
	p.xp = 0
	var old_max := p.max_health
	# Level 4->5 costs 400 XP
	p.gain_xp(400)
	assert_eq(p.level, 5)
	assert_true(&"hardy" in p.unlocked_passives)
	# +2 from level up, +4 from hardy
	assert_eq(p.max_health, old_max + 2 + 4)

func test_iron_skin_reduces_damage() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	p.unlocked_passives.append(&"iron_skin")
	var old_health := p.health
	# base effective = max(1, 2 - 0) = 2; iron_skin -> max(1, 2-1) = 1
	p.take_hit(2)
	assert_eq(p.health, old_health - 1)

func test_hero_passive_boosts_all_stats() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	var old_str: int = p.get_stat(&"strength")
	p._unlock_passive(&"hero")
	assert_eq(p.get_stat(&"strength"), old_str + 2)

func test_unlock_passive_idempotent() -> void:
	var p := PlayerController.new()
	add_child_autofree(p)
	p._unlock_passive(&"hardy")
	var hp_after_first: int = p.max_health
	p._unlock_passive(&"hardy")
	assert_eq(p.max_health, hp_after_first)  # no double-apply
