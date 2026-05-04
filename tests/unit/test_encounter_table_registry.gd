extends GutTest

func before_each() -> void:
	EncounterTableRegistry.reset()


func test_loads_maze_table() -> void:
	var result: Array = EncounterTableRegistry.get_weighted_list(&"maze", 1)
	assert_true(result.size() > 0, "Should have entries for maze floor 1")


func test_floor_range_filtering() -> void:
	var result: Array = EncounterTableRegistry.get_weighted_list(&"maze", 1)
	var kinds: Array = result.map(func(e): return e["creature"])
	assert_true(&"goblin" in kinds, "goblin should appear at floor 1")
	assert_false(&"ogre" in kinds, "ogre should NOT appear at floor 1")


func test_deep_floor_entries() -> void:
	var result: Array = EncounterTableRegistry.get_weighted_list(&"maze", 20)
	var kinds: Array = result.map(func(e): return e["creature"])
	assert_true(&"ogre" in kinds, "ogre should appear at floor 20")
	assert_true(&"fire_elemental" in kinds, "fire_elemental should appear at floor 20")


func test_boss_interval() -> void:
	assert_eq(EncounterTableRegistry.get_boss_interval(&"maze"), 2)


func test_unknown_type_returns_empty() -> void:
	var result: Array = EncounterTableRegistry.get_weighted_list(&"nonexistent", 1)
	assert_eq(result.size(), 0)


func test_weighted_pick() -> void:
	var table: Array = [
		{"creature": &"a", "weight": 1},
		{"creature": &"b", "weight": 9},
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pick: Dictionary = EncounterTableRegistry.weighted_pick(rng, table)
	assert_true(pick.has("creature"))


# --- Overworld encounter table tests ---

func test_overworld_grass_dist0_returns_basic_creatures() -> void:
	var result: Array = EncounterTableRegistry.get_overworld_weighted_list("grass", 0)
	var kinds: Array = result.map(func(e): return e["creature"])
	assert_true(&"slime" in kinds,  "slime should appear in grass at dist 0")
	assert_true(&"snake" in kinds,  "snake should appear in grass at dist 0")
	assert_true(&"rat" in kinds,    "rat should appear in grass at dist 0")
	assert_false(&"wolf" in kinds,  "wolf should NOT appear in grass at dist 0")
	assert_false(&"goblin" in kinds, "goblin should NOT appear in grass at dist 0")
	assert_false(&"bear" in kinds,  "bear should NOT appear in grass at dist 0")


func test_overworld_grass_dist2_unlocks_wolf_and_goblin() -> void:
	var result: Array = EncounterTableRegistry.get_overworld_weighted_list("grass", 2)
	var kinds: Array = result.map(func(e): return e["creature"])
	assert_true(&"wolf" in kinds,   "wolf should appear in grass at dist 2")
	assert_true(&"goblin" in kinds, "goblin should appear in grass at dist 2")
	assert_false(&"bear" in kinds,  "bear should NOT appear in grass at dist 2 (needs 4)")


func test_overworld_snow_dist0_returns_wolf_and_bat_only() -> void:
	var result: Array = EncounterTableRegistry.get_overworld_weighted_list("snow", 0)
	var kinds: Array = result.map(func(e): return e["creature"])
	assert_true(&"wolf" in kinds,            "wolf should appear in snow at dist 0")
	assert_true(&"bat" in kinds,             "bat should appear in snow at dist 0")
	assert_false(&"zombie" in kinds,         "zombie should NOT appear in snow at dist 0")
	assert_false(&"ice_elemental" in kinds,  "ice_elemental should NOT appear in snow at dist 0")


func test_overworld_rocky_dist6_includes_troll() -> void:
	var result: Array = EncounterTableRegistry.get_overworld_weighted_list("rocky", 6)
	var kinds: Array = result.map(func(e): return e["creature"])
	assert_true(&"troll" in kinds, "troll should appear in rocky at dist 6")


func test_overworld_unknown_biome_returns_empty() -> void:
	var result: Array = EncounterTableRegistry.get_overworld_weighted_list("atlantis", 0)
	assert_eq(result.size(), 0, "unknown biome should return empty list")


func test_pick_overworld_creature_returns_valid_name() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var creature: StringName = EncounterTableRegistry.pick_overworld_creature("grass", 0, rng)
	assert_ne(creature, &"", "should return a non-empty creature name")


func test_pick_overworld_creature_fallback_on_unknown_biome() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var creature: StringName = EncounterTableRegistry.pick_overworld_creature("atlantis", 0, rng)
	assert_eq(creature, &"slime", "unknown biome should fall back to slime")
