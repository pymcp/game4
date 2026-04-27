extends GutTest

func before_each() -> void:
	EncounterTableRegistry.reset()


func test_loads_labyrinth_table() -> void:
	var result: Array = EncounterTableRegistry.get_weighted_list(&"labyrinth", 1)
	assert_true(result.size() > 0, "Should have entries for labyrinth floor 1")


func test_floor_range_filtering() -> void:
	var result: Array = EncounterTableRegistry.get_weighted_list(&"labyrinth", 1)
	var kinds: Array = result.map(func(e): return e["creature"])
	assert_true(&"goblin" in kinds, "goblin should appear at floor 1")
	assert_false(&"ogre" in kinds, "ogre should NOT appear at floor 1")


func test_deep_floor_entries() -> void:
	var result: Array = EncounterTableRegistry.get_weighted_list(&"labyrinth", 20)
	var kinds: Array = result.map(func(e): return e["creature"])
	assert_true(&"ogre" in kinds, "ogre should appear at floor 20")
	assert_true(&"fire_elemental" in kinds, "fire_elemental should appear at floor 20")


func test_boss_interval() -> void:
	assert_eq(EncounterTableRegistry.get_boss_interval(&"labyrinth"), 2)


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
