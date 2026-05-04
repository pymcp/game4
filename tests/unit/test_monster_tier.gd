extends GutTest
## Unit tests for MonsterTier — the 5-tier monster variant system.


# ─── Constants sanity ───────────────────────────────────────────────

func test_tier_enum_values() -> void:
	assert_eq(MonsterTier.Tier.NORMAL, 0)
	assert_eq(MonsterTier.Tier.TOUGH, 1)
	assert_eq(MonsterTier.Tier.HARDENED, 2)
	assert_eq(MonsterTier.Tier.VETERAN, 3)
	assert_eq(MonsterTier.Tier.ELITE, 4)

func test_arrays_same_length() -> void:
	var count: int = MonsterTier.Tier.size()
	assert_eq(MonsterTier.TIER_NAMES.size(), count, "TIER_NAMES length")
	assert_eq(MonsterTier.HP_MULT.size(), count, "HP_MULT length")
	assert_eq(MonsterTier.DMG_MULT.size(), count, "DMG_MULT length")
	assert_eq(MonsterTier.SCALE_MULT.size(), count, "SCALE_MULT length")
	assert_eq(MonsterTier.XP_MULT.size(), count, "XP_MULT length")
	assert_eq(MonsterTier.TINT_FACTORS.size(), count, "TINT_FACTORS length")

func test_multipliers_monotonically_increasing() -> void:
	for i in range(1, MonsterTier.HP_MULT.size()):
		assert_gt(MonsterTier.HP_MULT[i], MonsterTier.HP_MULT[i - 1], "HP_MULT[%d]" % i)
		assert_gt(MonsterTier.DMG_MULT[i], MonsterTier.DMG_MULT[i - 1], "DMG_MULT[%d]" % i)
		assert_gt(MonsterTier.SCALE_MULT[i], MonsterTier.SCALE_MULT[i - 1], "SCALE_MULT[%d]" % i)
		assert_gt(MonsterTier.XP_MULT[i], MonsterTier.XP_MULT[i - 1], "XP_MULT[%d]" % i)

func test_normal_tier_multipliers_are_one() -> void:
	assert_eq(MonsterTier.HP_MULT[0], 1.0)
	assert_eq(MonsterTier.DMG_MULT[0], 1.0)
	assert_eq(MonsterTier.SCALE_MULT[0], 1.0)
	assert_eq(MonsterTier.XP_MULT[0], 1.0)


# ─── display_name ───────────────────────────────────────────────────

func test_display_name_normal_returns_base() -> void:
	assert_eq(MonsterTier.display_name("Goblin", 0), "Goblin")

func test_display_name_tough() -> void:
	assert_eq(MonsterTier.display_name("Goblin", 1), "Tough Goblin")

func test_display_name_elite() -> void:
	assert_eq(MonsterTier.display_name("Slime", 4), "Elite Slime")

func test_display_name_out_of_range() -> void:
	assert_eq(MonsterTier.display_name("Bat", -1), "Bat")
	assert_eq(MonsterTier.display_name("Bat", 99), "Bat")


# ─── apply_color ────────────────────────────────────────────────────

func test_apply_color_normal_unchanged() -> void:
	var base := Color(0.5, 0.8, 0.3)
	var result: Color = MonsterTier.apply_color(base, 0)
	assert_eq(result, base, "Normal tier should not modify tint")

func test_apply_color_tough_shifts_warm() -> void:
	var base := Color(0.5, 0.5, 0.5)
	var result: Color = MonsterTier.apply_color(base, 1)
	assert_gt(result.r, base.r, "Tough should increase red")
	assert_lt(result.b, base.b, "Tough should decrease blue slightly")

func test_apply_color_elite_significant_shift() -> void:
	var base := Color(0.5, 0.5, 0.5)
	var result: Color = MonsterTier.apply_color(base, 4)
	assert_gt(result.r, result.b, "Elite should be much warmer")

func test_apply_color_preserves_alpha() -> void:
	var base := Color(0.5, 0.5, 0.5, 0.7)
	var result: Color = MonsterTier.apply_color(base, 3)
	assert_almost_eq(result.a, 0.7, 0.001, "Alpha should be preserved")


# ─── roll_tier — floor caps ────────────────────────────────────────

func _make_rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng

func test_floor_1_never_above_normal_naturally() -> void:
	# Run many rolls on floor 1 — without elite promo, all should be 0.
	# We can't fully prevent promo, but we can check the floor band logic.
	var rng := _make_rng(12345)
	var max_tier: int = 0
	for i in 200:
		var t: int = MonsterTier.roll_tier(1, rng)
		max_tier = maxi(max_tier, t)
	# With 5% promo chance, floor 1 can get at most tier 1 (Tough).
	assert_lte(max_tier, 1, "Floor 1 should cap at tier 1 (promo only)")

func test_floor_4_caps_at_normal_plus_promo() -> void:
	var rng := _make_rng(99999)
	var max_tier: int = 0
	for i in 200:
		max_tier = maxi(max_tier, MonsterTier.roll_tier(4, rng))
	assert_lte(max_tier, 1, "Floor 4 (band 0) max should be 1 with promo")

func test_floor_5_can_produce_tough() -> void:
	var rng := _make_rng(42)
	var found_tough: bool = false
	for i in 200:
		if MonsterTier.roll_tier(5, rng) >= 1:
			found_tough = true
			break
	assert_true(found_tough, "Floor 5+ should occasionally produce Tough tier")

func test_floor_20_can_produce_elite() -> void:
	var rng := _make_rng(77777)
	var found_elite: bool = false
	for i in 500:
		if MonsterTier.roll_tier(20, rng) == 4:
			found_elite = true
			break
	assert_true(found_elite, "Floor 20+ should occasionally produce Elite tier")

func test_roll_tier_always_valid_range() -> void:
	var rng := _make_rng(11111)
	for floor_num in [1, 5, 10, 15, 20, 50, 100]:
		for i in 50:
			var t: int = MonsterTier.roll_tier(floor_num, rng)
			assert_gte(t, 0, "Tier should be >= 0")
			assert_lte(t, 4, "Tier should be <= ELITE (4)")


# ─── _floor_band ────────────────────────────────────────────────────

func test_floor_band_boundaries() -> void:
	# Access via roll_tier behavior since _floor_band is private.
	# Floor 1-4 = band 0, floor 5-9 = band 1, etc.
	# We test indirectly: floor 4 max natural = 0, floor 5 max natural = 1.
	var rng := _make_rng(0)
	# Floor 4 (band 0): only weight for tier 0 — all rolls should be 0 (ignoring promo).
	# We verify by checking that the majority are 0.
	var tier_0_count: int = 0
	for i in 100:
		rng.seed = i
		if MonsterTier.roll_tier(4, rng) == 0:
			tier_0_count += 1
	assert_gte(tier_0_count, 90, "Floor 4 should overwhelmingly produce tier 0")


# ─── Elite promotion ───────────────────────────────────────────────

func test_elite_promotion_exists() -> void:
	# Over many rolls on floor 1, at least one should be tier 1 (from promo).
	var rng := _make_rng(54321)
	var found_promoted: bool = false
	for i in 500:
		if MonsterTier.roll_tier(1, rng) > 0:
			found_promoted = true
			break
	assert_true(found_promoted, "Elite promotion should occasionally fire on floor 1")
