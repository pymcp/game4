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
	ChestLootRegistry.get_tier_for_floor(1)
	ChestLootRegistry.reset()
	assert_false(ChestLootRegistry.is_loaded())
