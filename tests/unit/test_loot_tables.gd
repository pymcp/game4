## Tests for LootTableRegistry and monster death → loot drop pipeline.
extends GutTest


# --- LootTableRegistry loading -----------------------------------

func before_each() -> void:
	LootTableRegistry.reset()


func test_loads_loot_tables_json() -> void:
	assert_true(LootTableRegistry.has_table(&"slime"),
		"slime table should exist")


func test_all_kinds_returns_registered() -> void:
	var kinds: Array = LootTableRegistry.all_kinds()
	assert_true(kinds.size() >= 2, "at least 2 kinds expected")
	assert_true(kinds.has(&"slime"), "should include slime")
	assert_true(kinds.has(&"skeleton"), "should include skeleton")


func test_has_table_false_for_missing() -> void:
	assert_false(LootTableRegistry.has_table(&"nonexistent"),
		"nonexistent kind should return false")


func test_get_table_returns_dict() -> void:
	var t: Dictionary = LootTableRegistry.get_table(&"slime")
	assert_true(t.has("health"), "table should have health field")
	assert_true(t.has("drops"), "table should have drops array")
	assert_true(t.has("drop_count"), "table should have drop_count")
	assert_true(t.has("drop_chance"), "table should have drop_chance")


func test_get_health_returns_int() -> void:
	var hp: int = LootTableRegistry.get_health(&"slime")
	assert_eq(hp, 3, "slime should have 3 health")


func test_get_health_ogre() -> void:
	var hp: int = LootTableRegistry.get_health(&"ogre")
	assert_eq(hp, 12, "ogre should have 12 health")


func test_get_resistances_empty_for_slime() -> void:
	var r: Dictionary = LootTableRegistry.get_resistances(&"slime")
	assert_eq(r.size(), 0, "slime has no resistances")


func test_get_resistances_ogre() -> void:
	var r: Dictionary = LootTableRegistry.get_resistances(&"ogre")
	assert_true(r.has(4), "ogre should resist element 4")
	assert_eq(r[4], 0.5, "ogre element 4 resistance should be 0.5")


func test_get_resistances_fire_elemental() -> void:
	var r: Dictionary = LootTableRegistry.get_resistances(&"fire_elemental")
	assert_eq(r[1], 0.0, "fire elemental immune to fire (element 1)")
	assert_eq(r[2], 2.0, "fire elemental weak to ice (element 2)")


# --- Drop rolling ------------------------------------------------

func test_roll_drops_returns_array() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var drops: Array = LootTableRegistry.roll_drops(&"slime", rng)
	assert_typeof(drops, TYPE_ARRAY)


func test_roll_drops_items_have_id_and_count() -> void:
	# Use a seeded RNG and high drop_chance kind to ensure we get drops.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# Ogre has 0.9 drop_chance and 2 rolls — very likely to produce drops.
	var drops: Array = LootTableRegistry.roll_drops(&"ogre", rng)
	if drops.size() > 0:
		var d: Dictionary = drops[0]
		assert_true(d.has("id"), "drop should have id")
		assert_true(d.has("count"), "drop should have count")
		assert_true(d["count"] >= 1, "count should be >= 1")


func test_roll_drops_respects_min_max() -> void:
	var rng := RandomNumberGenerator.new()
	# Run many rolls to check bounds.
	for i in 100:
		rng.seed = i
		var drops: Array = LootTableRegistry.roll_drops(&"ogre", rng)
		for d in drops:
			# ogre max is 4 for iron_ore (the largest max)
			assert_true(d["count"] >= 1, "count should be >= 1")
			assert_true(d["count"] <= 4, "count should be <= max (4 for ogre)")


func test_roll_drops_empty_for_unknown_kind() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var drops: Array = LootTableRegistry.roll_drops(&"unknown_creature", rng)
	assert_eq(drops.size(), 0, "unknown kind should return no drops")


func test_roll_drops_statistical_distribution() -> void:
	# Roll slime drops many times and check that items from the table appear.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var seen_ids: Dictionary = {}
	for i in 500:
		rng.seed = i
		var drops: Array = LootTableRegistry.roll_drops(&"slime", rng)
		for d in drops:
			seen_ids[d["id"]] = true
	# Slime drops: fiber (weight 40), copper_ore (15), fennel_root (10)
	# Over 500 rolls with 70% drop_chance, we should see all three.
	assert_true(seen_ids.has(&"fiber"), "fiber should appear in slime drops")
	assert_true(seen_ids.has(&"copper_ore"), "copper_ore should appear in slime drops")
	assert_true(seen_ids.has(&"fennel_root"), "fennel_root should appear in slime drops")


func test_roll_drops_never_drops_unlisted_items() -> void:
	var rng := RandomNumberGenerator.new()
	var slime_table: Dictionary = LootTableRegistry.get_table(&"slime")
	var valid_ids: Dictionary = {}
	for entry in slime_table.get("drops", []):
		valid_ids[StringName(entry["item_id"])] = true
	for i in 200:
		rng.seed = i
		var drops: Array = LootTableRegistry.roll_drops(&"slime", rng)
		for d in drops:
			assert_true(valid_ids.has(d["id"]),
				"rolled id '%s' should be in slime's drop table" % d["id"])


# --- Monster integration -----------------------------------------

func test_monster_has_monster_kind_property() -> void:
	var m := Monster.new()
	assert_eq(m.monster_kind, &"slime", "default monster_kind should be slime")
	m.monster_kind = &"skeleton"
	assert_eq(m.monster_kind, &"skeleton")
	m.free()


func test_monster_die_rolls_from_loot_table() -> void:
	var m := Monster.new()
	m.monster_kind = &"ogre"
	# Leave drops empty — should auto-roll from loot table.
	var box: Array = []  # container so lambda can mutate by ref
	m.died.connect(func(_pos, drops): box.append(drops))
	add_child_autofree(m)
	m.health = 1
	m.take_hit(10)
	# Monster calls _die → rolls from LootTableRegistry.
	assert_eq(box.size(), 1, "died signal should have fired once")
	assert_true(box[0] is Array, "should receive drops array")


func test_monster_die_uses_explicit_drops_if_set() -> void:
	var m := Monster.new()
	m.monster_kind = &"slime"
	m.drops = [{"id": &"custom_item", "count": 5}]
	var box: Array = []  # container so lambda can mutate by ref
	m.died.connect(func(_pos, drops): box.append(drops))
	add_child_autofree(m)
	m.health = 1
	m.take_hit(10)
	assert_eq(box.size(), 1, "died signal should have fired")
	var received_drops: Array = box[0]
	assert_eq(received_drops.size(), 1, "should use explicit drops")
	assert_eq(received_drops[0]["id"], &"custom_item")
	assert_eq(received_drops[0]["count"], 5)
