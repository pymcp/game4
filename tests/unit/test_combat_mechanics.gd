extends GutTest
## Unit tests for dodge roll, block/parry, and telegraph mechanics.

# ─── PlayerActions constants ────────────────────────────────────────

func test_dodge_verb_exists() -> void:
	assert_eq(PlayerActions.DODGE, &"dodge")

func test_block_verb_exists() -> void:
	assert_eq(PlayerActions.BLOCK, &"block")

func test_dodge_action_name_p1() -> void:
	assert_eq(PlayerActions.action(0, PlayerActions.DODGE), &"p1_dodge")

func test_dodge_action_name_p2() -> void:
	assert_eq(PlayerActions.action(1, PlayerActions.DODGE), &"p2_dodge")

func test_block_action_name_p1() -> void:
	assert_eq(PlayerActions.action(0, PlayerActions.BLOCK), &"p1_block")

func test_block_action_name_p2() -> void:
	assert_eq(PlayerActions.action(1, PlayerActions.BLOCK), &"p2_block")


# ─── Dodge state logic ──────────────────────────────────────────────

func _make_player() -> PlayerController:
	var p := PlayerController.new()
	p.player_id = 0
	return p

func test_dodge_initial_state() -> void:
	var p := _make_player()
	assert_false(p.is_dodging, "Should not be dodging initially")
	assert_eq(p._dodge_cooldown, 0.0, "Cooldown starts at 0")
	assert_eq(p._dodge_timer, 0.0, "Timer starts at 0")

func test_dodge_invincible_only_during_iframes() -> void:
	var p := _make_player()
	# Simulate mid-dodge: timer near start (within i-frame window).
	p.is_dodging = true
	p._dodge_timer = PlayerController.DODGE_DURATION_SEC - 0.05
	assert_true(p.is_dodge_invincible(), "Should be invincible near start of dodge")
	# Timer past i-frame window.
	p._dodge_timer = PlayerController.DODGE_DURATION_SEC - PlayerController.DODGE_IFRAMES_SEC - 0.01
	assert_false(p.is_dodge_invincible(), "Should NOT be invincible after i-frames expire")

func test_dodge_invincible_false_when_not_dodging() -> void:
	var p := _make_player()
	p.is_dodging = false
	p._dodge_timer = PlayerController.DODGE_DURATION_SEC
	assert_false(p.is_dodge_invincible(), "Not invincible when is_dodging is false")


# ─── Block / Parry state logic ──────────────────────────────────────

func test_block_initial_state() -> void:
	var p := _make_player()
	assert_false(p.is_blocking, "Should not be blocking initially")
	assert_eq(p._block_timer, 0.0, "Block timer starts at 0")

func test_parry_window_at_start_of_block() -> void:
	var p := _make_player()
	p.is_blocking = true
	p._block_timer = 0.0
	assert_true(p.is_parrying(), "Should be parrying at start of block")

func test_parry_window_at_edge() -> void:
	var p := _make_player()
	p.is_blocking = true
	p._block_timer = PlayerController.PARRY_WINDOW_SEC
	assert_true(p.is_parrying(), "Should be parrying at exact window edge")

func test_parry_window_expired() -> void:
	var p := _make_player()
	p.is_blocking = true
	p._block_timer = PlayerController.PARRY_WINDOW_SEC + 0.01
	assert_false(p.is_parrying(), "Should NOT be parrying after window")

func test_parry_false_when_not_blocking() -> void:
	var p := _make_player()
	p.is_blocking = false
	p._block_timer = 0.0
	assert_false(p.is_parrying(), "Not parrying when not blocking")


# ─── take_hit respects dodge/block ──────────────────────────────────

func test_take_hit_blocked_by_dodge_iframes() -> void:
	var p := _make_player()
	p.health = 10
	p.max_health = 10
	p.is_dodging = true
	p._dodge_timer = PlayerController.DODGE_DURATION_SEC - 0.05
	p.take_hit(5)
	assert_eq(p.health, 10, "Dodge i-frames should prevent damage")

func test_take_hit_reduced_by_block() -> void:
	var p := _make_player()
	p.health = 10
	p.max_health = 10
	p.is_blocking = true
	p._block_timer = PlayerController.PARRY_WINDOW_SEC + 0.1  # Past parry window
	p.take_hit(8)
	# 8 damage * 0.25 = 2, min 1. No armor. So effective = 2.
	assert_eq(p.health, 8, "Block should reduce damage to 25%")

func test_take_hit_parry_negates_damage() -> void:
	var p := _make_player()
	p.health = 10
	p.max_health = 10
	p.is_blocking = true
	p._block_timer = 0.0  # In parry window
	p.take_hit(10)
	assert_eq(p.health, 10, "Parry should negate all damage")


# ─── Telegraph duration accessor ────────────────────────────────────

func test_telegraph_duration_default() -> void:
	# For a creature with attack_speed=1.0, telegraph should be 0.5s
	var dur: float = CreatureSpriteRegistry.get_telegraph_duration(&"slime")
	assert_gt(dur, 0.1, "Telegraph should be positive")
	assert_lte(dur, 2.0, "Telegraph should be reasonable")

func test_telegraph_duration_minimum() -> void:
	# Even fast creatures should have at least 0.2s telegraph
	var dur: float = CreatureSpriteRegistry.get_telegraph_duration(&"bat")
	assert_gte(dur, 0.2, "Telegraph minimum should be 0.2s")


# ─── Monster stagger ────────────────────────────────────────────────

func test_monster_stagger_sets_timer() -> void:
	var m := Monster.new()
	m.stagger()
	assert_gt(m._stagger_timer, 0.0, "Stagger should set timer")
	assert_eq(m._stagger_timer, Monster.STAGGER_DURATION, "Should match constant")


# ─── NPC stagger ────────────────────────────────────────────────────

func test_npc_stagger_enters_state() -> void:
	var n := NPC.new()
	n.health = 5
	n.max_health = 5
	n.stagger()
	assert_eq(n.state, NPC.State.STAGGERED, "Stagger should enter STAGGERED state")

func test_npc_stagger_ignored_when_dead() -> void:
	var n := NPC.new()
	n.state = NPC.State.DEAD
	n.stagger()
	assert_eq(n.state, NPC.State.DEAD, "Dead NPC should not stagger")


# ─── Constants sanity ───────────────────────────────────────────────

func test_dodge_constants_reasonable() -> void:
	assert_gt(PlayerController.DODGE_COOLDOWN_SEC, 0.0)
	assert_gt(PlayerController.DODGE_DURATION_SEC, 0.0)
	assert_gt(PlayerController.DODGE_DISTANCE_PX, 0.0)
	assert_gt(PlayerController.DODGE_IFRAMES_SEC, 0.0)
	assert_lte(PlayerController.DODGE_IFRAMES_SEC, PlayerController.DODGE_DURATION_SEC,
		"I-frames can't exceed dodge duration")

func test_block_constants_reasonable() -> void:
	assert_gt(PlayerController.PARRY_WINDOW_SEC, 0.0)
	assert_gt(PlayerController.BLOCK_DAMAGE_MULT, 0.0)
	assert_lt(PlayerController.BLOCK_DAMAGE_MULT, 1.0, "Block should reduce damage")
	assert_gt(PlayerController.BLOCK_SPEED_MULT, 0.0)
	assert_lt(PlayerController.BLOCK_SPEED_MULT, 1.0, "Block should slow movement")


# ─── Charge attack ──────────────────────────────────────────────────

func test_charge_constants_reasonable() -> void:
	assert_gt(PlayerController.CHARGE_MAX_SEC, 0.0)
	assert_gt(PlayerController.CHARGE_DAMAGE_MULT, 1.0, "Charge should boost damage")
	assert_gt(PlayerController.CHARGE_THRESHOLD_SEC, 0.0)
	assert_lt(PlayerController.CHARGE_THRESHOLD_SEC, PlayerController.CHARGE_MAX_SEC,
		"Threshold must be less than max charge time")

func test_charge_initial_state() -> void:
	var p := _make_player()
	assert_false(p.is_charging, "Should not be charging initially")
	assert_eq(p._charge_timer, 0.0, "Charge timer starts at 0")

func test_get_charge_ratio_zero_when_not_charging() -> void:
	var p := _make_player()
	assert_eq(p.get_charge_ratio(), 0.0)

func test_get_charge_ratio_zero_below_threshold() -> void:
	var p := _make_player()
	p.is_charging = true
	p._charge_timer = PlayerController.CHARGE_THRESHOLD_SEC * 0.5
	assert_eq(p.get_charge_ratio(), 0.0, "Below threshold should report 0")

func test_get_charge_ratio_full_at_max() -> void:
	var p := _make_player()
	p.is_charging = true
	p._charge_timer = PlayerController.CHARGE_MAX_SEC
	assert_almost_eq(p.get_charge_ratio(), 1.0, 0.001, "Max charge should be 1.0")

func test_get_charge_ratio_mid() -> void:
	var p := _make_player()
	p.is_charging = true
	# Halfway between threshold and max.
	p._charge_timer = PlayerController.CHARGE_THRESHOLD_SEC + \
		(PlayerController.CHARGE_MAX_SEC - PlayerController.CHARGE_THRESHOLD_SEC) * 0.5
	assert_almost_eq(p.get_charge_ratio(), 0.5, 0.001, "Mid charge should be ~0.5")

func test_charge_multiplier_no_charge() -> void:
	var p := _make_player()
	p._charge_timer = 0.0
	assert_eq(p._get_charge_multiplier(), 1.0, "No charge = normal damage")

func test_charge_multiplier_below_threshold() -> void:
	var p := _make_player()
	p._charge_timer = PlayerController.CHARGE_THRESHOLD_SEC * 0.5
	assert_eq(p._get_charge_multiplier(), 1.0, "Below threshold = normal damage")

func test_charge_multiplier_full_charge() -> void:
	var p := _make_player()
	p._charge_timer = PlayerController.CHARGE_MAX_SEC
	assert_almost_eq(p._get_charge_multiplier(), PlayerController.CHARGE_DAMAGE_MULT, 0.001,
		"Full charge = max multiplier")

func test_charge_cancelled_by_hit() -> void:
	var p := _make_player()
	p.health = 10
	p.max_health = 10
	p.is_charging = true
	p._charge_timer = 0.5
	p.take_hit(1)
	assert_false(p.is_charging, "Hit should cancel charge")
	assert_eq(p._charge_timer, 0.0, "Charge timer should reset on hit")
