extends GutTest

func before_each() -> void:
	ChestLootRegistry.reset()


func test_rolls_loot_floor_1() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result: Dictionary = ChestLootRegistry.roll_loot(1, rng)
	assert_true(result.has("id"), "Should have id field")
	assert_true(result.has("count"), "Should have count field")
	assert_true(int(result["count"]) >= 1)


func test_rolls_loot_deep_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result: Dictionary = ChestLootRegistry.roll_loot(20, rng)
	assert_true(result.has("id"))


func test_floor_tier_selection() -> void:
	var tier1: Dictionary = ChestLootRegistry.get_tier_for_floor(1)
	var tier3: Dictionary = ChestLootRegistry.get_tier_for_floor(20)
	assert_eq(int(tier1.get("max_floor", 0)), 5)
	assert_eq(int(tier3.get("min_floor", 0)), 16)


func test_reset_clears_cache() -> void:
	# Force a load, then reset — subsequent get should reload from disk.
	var before: Dictionary = ChestLootRegistry.get_tier_for_floor(1)
	assert_false(before.is_empty(), "Should return a tier before reset")
	ChestLootRegistry.reset()
	# get_raw_tiers calls _ensure_loaded internally, so it auto-reloads;
	# verify data is accessible again after reset.
	var after: Array = ChestLootRegistry.get_raw_tiers()
	assert_true(after.size() > 0, "Should reload tiers from disk after reset")
