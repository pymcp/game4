## Tests for Phase 1 registry infrastructure: save_data / get_raw_data
## round-trips for LootTableRegistry, ArmorSetRegistry, CraftingRegistry,
## BiomeRegistry, and QuestRegistry CRUD.
extends GutTest


# ─── LootTableRegistry ────────────────────────────────────────────────

func test_loot_table_get_raw_data_returns_dict() -> void:
	LootTableRegistry.reset()
	var raw: Dictionary = LootTableRegistry.get_raw_data()
	assert_true(raw.has("slime"), "raw data should include slime")
	assert_true(raw["slime"].has("health"), "slime entry should have health")


func test_loot_table_save_data_round_trip() -> void:
	LootTableRegistry.reset()
	var raw: Dictionary = LootTableRegistry.get_raw_data().duplicate(true)
	# Mutate: bump slime health.
	raw["slime"]["health"] = 99
	LootTableRegistry.save_data(raw)
	# Verify in-memory.
	assert_eq(LootTableRegistry.get_health(&"slime"), 99,
		"in-memory health should be updated")
	# Verify on disk — reset and reload.
	LootTableRegistry.reset()
	assert_eq(LootTableRegistry.get_health(&"slime"), 99,
		"on-disk health should persist after reset+reload")
	# Restore original.
	raw["slime"]["health"] = 3
	LootTableRegistry.save_data(raw)
	LootTableRegistry.reset()
	assert_eq(LootTableRegistry.get_health(&"slime"), 3,
		"health should be restored to original")


func test_loot_table_save_data_isolates_dict() -> void:
	LootTableRegistry.reset()
	var raw: Dictionary = LootTableRegistry.get_raw_data().duplicate(true)
	LootTableRegistry.save_data(raw)
	# Mutating the passed-in dict should NOT affect internal state.
	raw["slime"]["health"] = 777
	assert_ne(LootTableRegistry.get_health(&"slime"), 777,
		"internal data should be isolated from caller's dict")
	LootTableRegistry.reset()


# ─── ArmorSetRegistry ─────────────────────────────────────────────────

func test_armor_set_get_raw_data_returns_dict() -> void:
	ArmorSetRegistry.reset()
	var raw: Dictionary = ArmorSetRegistry.get_raw_data()
	assert_true(raw.has("leather"), "raw data should include leather")
	assert_true(raw.has("iron"), "raw data should include iron")


func test_armor_set_save_data_round_trip() -> void:
	ArmorSetRegistry.reset()
	var raw: Dictionary = ArmorSetRegistry.get_raw_data().duplicate(true)
	# Mutate: change leather display_name.
	raw["leather"]["display_name"] = "Test Set"
	ArmorSetRegistry.save_data(raw)
	ArmorSetRegistry.reset()
	var reloaded: Dictionary = ArmorSetRegistry.get_set("leather")
	assert_eq(reloaded.get("display_name"), "Test Set",
		"display_name should persist after save+reload")
	# Restore.
	raw["leather"]["display_name"] = "Leather Set"
	ArmorSetRegistry.save_data(raw)
	ArmorSetRegistry.reset()


func test_armor_set_save_data_isolates_dict() -> void:
	ArmorSetRegistry.reset()
	var raw: Dictionary = ArmorSetRegistry.get_raw_data().duplicate(true)
	ArmorSetRegistry.save_data(raw)
	raw["leather"]["display_name"] = "MUTATED"
	var current: Dictionary = ArmorSetRegistry.get_set("leather")
	assert_ne(current.get("display_name"), "MUTATED",
		"internal data should be isolated")
	ArmorSetRegistry.reset()


# ─── CraftingRegistry ─────────────────────────────────────────────────

func test_crafting_loads_from_json() -> void:
	CraftingRegistry.reset()
	var recipes: Array = CraftingRegistry.all_recipes()
	assert_true(recipes.size() >= 4, "should have at least 4 recipes")
	var sword: CraftingRecipe = CraftingRegistry.get_recipe(&"sword")
	assert_not_null(sword, "sword recipe should exist")
	assert_eq(sword.output_id, &"sword")
	assert_eq(sword.output_count, 1)
	assert_eq(sword.inputs.size(), 3, "sword needs 3 input types")


func test_crafting_get_raw_data_returns_dict() -> void:
	CraftingRegistry.reset()
	var raw: Dictionary = CraftingRegistry.get_raw_data()
	assert_true(raw.has("sword"), "raw data should include sword")
	assert_true(raw.has("helmet"), "raw data should include helmet")


func test_crafting_save_data_round_trip() -> void:
	CraftingRegistry.reset()
	var raw: Dictionary = CraftingRegistry.get_raw_data().duplicate(true)
	# Add a new recipe.
	raw["test_recipe"] = {
		"inputs": [{"id": "wood", "count": 2}],
		"output_id": "bow",
		"output_count": 1
	}
	CraftingRegistry.save_data(raw)
	var test_r: CraftingRecipe = CraftingRegistry.get_recipe(&"test_recipe")
	assert_not_null(test_r, "new recipe should exist in cache")
	assert_eq(test_r.output_id, &"bow")
	# Reset and reload from disk.
	CraftingRegistry.reset()
	test_r = CraftingRegistry.get_recipe(&"test_recipe")
	assert_not_null(test_r, "new recipe should persist on disk")
	# Restore: remove test recipe.
	raw.erase("test_recipe")
	CraftingRegistry.save_data(raw)
	CraftingRegistry.reset()
	assert_null(CraftingRegistry.get_recipe(&"test_recipe"),
		"test recipe should be gone after restore")


func test_crafting_all_ids() -> void:
	CraftingRegistry.reset()
	var ids: Array = CraftingRegistry.all_ids()
	assert_true(ids.has(&"sword"))
	assert_true(ids.has(&"helmet"))
	assert_true(ids.has(&"armor"))
	assert_true(ids.has(&"boots"))


# ─── BiomeRegistry ────────────────────────────────────────────────────

func test_biome_loads_from_json() -> void:
	BiomeRegistry.reset()
	var grass: BiomeDefinition = BiomeRegistry.get_biome(&"grass")
	assert_not_null(grass, "grass biome should exist")
	assert_eq(grass.primary_terrain, TerrainCodes.GRASS)
	assert_eq(grass.secondary_terrain, TerrainCodes.DIRT)


func test_biome_all_ids_from_json() -> void:
	BiomeRegistry.reset()
	var ids: Array[StringName] = BiomeRegistry.all_ids()
	assert_true(ids.has(&"grass"))
	assert_true(ids.has(&"desert"))
	assert_true(ids.has(&"snow"))
	assert_true(ids.has(&"swamp"))
	assert_true(ids.has(&"rocky"))


func test_biome_get_raw_data_returns_dict() -> void:
	BiomeRegistry.reset()
	var raw: Dictionary = BiomeRegistry.get_raw_data()
	assert_true(raw.has("grass"), "raw data should include grass")
	assert_true(raw.has("rocky"), "raw data should include rocky")


func test_biome_save_data_round_trip() -> void:
	BiomeRegistry.reset()
	var raw: Dictionary = BiomeRegistry.get_raw_data().duplicate(true)
	# Mutate: change desert npc_density.
	raw["desert"]["npc_density"] = 0.5
	BiomeRegistry.save_data(raw)
	var desert: BiomeDefinition = BiomeRegistry.get_biome(&"desert")
	assert_almost_eq(desert.npc_density, 0.5, 0.001,
		"in-memory npc_density should update")
	# Reset and reload.
	BiomeRegistry.reset()
	desert = BiomeRegistry.get_biome(&"desert")
	assert_almost_eq(desert.npc_density, 0.5, 0.001,
		"on-disk npc_density should persist")
	# Restore.
	raw["desert"]["npc_density"] = 0.002
	BiomeRegistry.save_data(raw)
	BiomeRegistry.reset()


func test_biome_desert_terrain_codes() -> void:
	BiomeRegistry.reset()
	var desert: BiomeDefinition = BiomeRegistry.get_biome(&"desert")
	assert_eq(desert.primary_terrain, TerrainCodes.SAND)
	assert_eq(desert.secondary_terrain, TerrainCodes.DIRT)


func test_biome_snow_terrain_codes() -> void:
	BiomeRegistry.reset()
	var snow: BiomeDefinition = BiomeRegistry.get_biome(&"snow")
	assert_eq(snow.primary_terrain, TerrainCodes.SNOW)
	assert_eq(snow.secondary_terrain, TerrainCodes.ROCK)


func test_biome_ground_modulate_parsed() -> void:
	BiomeRegistry.reset()
	var desert: BiomeDefinition = BiomeRegistry.get_biome(&"desert")
	assert_almost_eq(desert.ground_modulate.r, 1.0, 0.01)
	assert_almost_eq(desert.ground_modulate.g, 0.95, 0.01)
	assert_almost_eq(desert.ground_modulate.b, 0.75, 0.01)


# ─── QuestRegistry CRUD ──────────────────────────────────────────────

func test_quest_get_raw_data_returns_dict() -> void:
	QuestRegistry.reload()
	var raw: Dictionary = QuestRegistry.get_raw_data()
	assert_true(raw.has("herbalist_remedy"),
		"raw data should include herbalist_remedy")


func test_quest_create_and_delete() -> void:
	QuestRegistry.reload()
	# Create a test quest.
	var template: Dictionary = QuestRegistry.create_quest("test_quest_1e")
	assert_eq(template["id"], "test_quest_1e")
	assert_true(QuestRegistry.all_ids().has("test_quest_1e"),
		"new quest should appear in all_ids")
	# Verify it loads from disk.
	QuestRegistry.reload()
	var loaded: Dictionary = QuestRegistry.get_quest("test_quest_1e")
	assert_eq(loaded.get("id"), "test_quest_1e",
		"created quest should persist on disk")
	# Delete it.
	QuestRegistry.delete_quest("test_quest_1e")
	assert_false(QuestRegistry.all_ids().has("test_quest_1e"),
		"deleted quest should be gone from cache")
	# Verify gone from disk.
	QuestRegistry.reload()
	assert_true(QuestRegistry.get_quest("test_quest_1e").is_empty(),
		"deleted quest should be gone from disk")


func test_quest_save_quest_updates_data() -> void:
	QuestRegistry.reload()
	# Create, modify, and save.
	QuestRegistry.create_quest("test_quest_save")
	var data: Dictionary = QuestRegistry.get_quest("test_quest_save").duplicate(true)
	data["display_name"] = "Modified Quest"
	data["giver"] = "test_npc"
	QuestRegistry.save_quest("test_quest_save", data)
	# Reload and verify.
	QuestRegistry.reload()
	var loaded: Dictionary = QuestRegistry.get_quest("test_quest_save")
	assert_eq(loaded.get("display_name"), "Modified Quest")
	assert_eq(loaded.get("giver"), "test_npc")
	# Cleanup.
	QuestRegistry.delete_quest("test_quest_save")
	QuestRegistry.reload()
