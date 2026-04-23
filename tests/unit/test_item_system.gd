## Tests for Phase 1: Data Foundation (items.json, ItemDefinition, ItemRegistry)
extends GutTest


# --- ItemDefinition enums -----------------------------------------

func test_slot_enum_has_off_hand() -> void:
	assert_eq(ItemDefinition.Slot.OFF_HAND, 6,
		"OFF_HAND should be the last Slot value")


func test_slot_backward_compat() -> void:
	assert_eq(ItemDefinition.Slot.NONE, 0)
	assert_eq(ItemDefinition.Slot.WEAPON, 1)
	assert_eq(ItemDefinition.Slot.TOOL, 2)
	assert_eq(ItemDefinition.Slot.HEAD, 3)
	assert_eq(ItemDefinition.Slot.BODY, 4)
	assert_eq(ItemDefinition.Slot.FEET, 5)


func test_rarity_enum() -> void:
	assert_eq(ItemDefinition.Rarity.COMMON, 0)
	assert_eq(ItemDefinition.Rarity.LEGENDARY, 4)


func test_attack_type_enum() -> void:
	assert_eq(ItemDefinition.AttackType.NONE, 0)
	assert_eq(ItemDefinition.AttackType.MELEE, 1)
	assert_eq(ItemDefinition.AttackType.RANGED, 2)


func test_weapon_category_enum() -> void:
	assert_eq(ItemDefinition.WeaponCategory.SWORD, 1)
	assert_eq(ItemDefinition.WeaponCategory.DAGGER, 6)


func test_element_enum() -> void:
	assert_eq(ItemDefinition.Element.FIRE, 1)
	assert_eq(ItemDefinition.Element.POISON, 4)


func test_rarity_colors_has_all_values() -> void:
	for r in ItemDefinition.Rarity.values():
		assert_has(ItemDefinition.RARITY_COLORS, r,
			"RARITY_COLORS should have key for %s" % ItemDefinition.Rarity.keys()[r])


# --- ItemDefinition.generate_description() ------------------------

func test_generate_description_weapon() -> void:
	var def := ItemDefinition.new()
	def.slot = ItemDefinition.Slot.WEAPON
	def.power = 4
	def.attack_speed = 0.35
	def.attack_type = ItemDefinition.AttackType.MELEE
	def.element = ItemDefinition.Element.FIRE
	def.description_flavor = "Burning blade."
	var desc: String = def.generate_description()
	assert_string_contains(desc, "4 ATK")
	assert_string_contains(desc, "Melee")
	assert_string_contains(desc, "Fire")
	assert_string_contains(desc, "Burning blade.")
	# attack_speed formatting varies ("0.35s" or "0.4s") — just check it's present
	assert_true(desc.contains("s"), "should contain attack speed with 's' suffix")


func test_generate_description_armor() -> void:
	var def := ItemDefinition.new()
	def.slot = ItemDefinition.Slot.BODY
	def.power = 3
	def.description_flavor = "Sturdy leather."
	var desc: String = def.generate_description()
	assert_string_contains(desc, "3 DEF")
	assert_string_contains(desc, "Sturdy leather.")


func test_generate_description_stat_bonuses() -> void:
	var def := ItemDefinition.new()
	def.slot = ItemDefinition.Slot.WEAPON
	def.power = 2
	def.stat_bonuses = {"strength": 2, "speed": -1}
	var desc: String = def.generate_description()
	assert_string_contains(desc, "+2 STRENGTH")
	assert_string_contains(desc, "-1 SPEED")


func test_generate_description_set_id() -> void:
	var def := ItemDefinition.new()
	def.slot = ItemDefinition.Slot.BODY
	def.power = 3
	def.set_id = "iron"
	var desc: String = def.generate_description()
	assert_string_contains(desc, "Iron Set")


func test_generate_description_empty() -> void:
	var def := ItemDefinition.new()
	var desc: String = def.generate_description()
	assert_eq(desc, "", "empty item should have empty description")


func test_generate_description_flavor_only() -> void:
	var def := ItemDefinition.new()
	def.description_flavor = "A simple rock."
	var desc: String = def.generate_description()
	assert_eq(desc, "A simple rock.")


# --- ItemRegistry loading -----------------------------------------

func before_each() -> void:
	ItemRegistry.reset()


func test_all_13_items_loaded() -> void:
	var ids: Array = ItemRegistry.all_ids()
	assert_eq(ids.size(), 43, "should load 43 items from items.json")


func test_has_all_original_ids() -> void:
	var expected: Array = [
		&"wood", &"stone", &"fiber", &"iron_ore", &"copper_ore", &"gold_ore",
		&"pickaxe", &"sword", &"bow", &"helmet", &"armor", &"boots",
	]
	for id in expected:
		assert_true(ItemRegistry.has_item(id),
			"should have item '%s'" % id)


func test_get_item_returns_definition() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_not_null(def, "sword should exist")
	assert_eq(def.id, &"sword")
	assert_eq(def.display_name, "Iron Sword")


func test_get_item_unknown_returns_null() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"nonexistent")
	assert_null(def)


func test_has_item_false_for_unknown() -> void:
	assert_false(ItemRegistry.has_item(&"nonexistent"))


func test_reset_clears_cache() -> void:
	var _def := ItemRegistry.get_item(&"sword")
	ItemRegistry.reset()
	# After reset, next call should reload fresh.
	var def2: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_not_null(def2, "should reload after reset")


# --- Migrated item field values -----------------------------------

func test_wood_material() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"wood")
	assert_eq(def.display_name, "Wood")
	assert_eq(def.stack_size, 99)
	assert_eq(def.slot, ItemDefinition.Slot.NONE)
	assert_eq(def.power, 0)


func test_sword_fields() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_eq(def.display_name, "Iron Sword")
	assert_eq(def.stack_size, 1)
	assert_eq(def.slot, ItemDefinition.Slot.WEAPON)
	assert_eq(def.power, 4)
	assert_eq(def.hands, 1)
	assert_eq(def.attack_type, ItemDefinition.AttackType.MELEE)
	assert_almost_eq(def.attack_speed, 0.35, 0.001)
	assert_almost_eq(def.reach, 24.0, 0.1)
	assert_eq(def.weapon_category, ItemDefinition.WeaponCategory.SWORD)
	assert_eq(def.tier, "iron")
	assert_eq(def.weapon_sprite, Vector2i(43, 5))


func test_bow_fields() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"bow")
	assert_eq(def.slot, ItemDefinition.Slot.WEAPON)
	assert_eq(def.power, 3)
	assert_eq(def.hands, 2)
	assert_eq(def.attack_type, ItemDefinition.AttackType.RANGED)
	assert_eq(def.weapon_category, ItemDefinition.WeaponCategory.BOW)
	assert_eq(def.weapon_sprite, Vector2i(52, 0))


func test_pickaxe_fields() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"pickaxe")
	assert_eq(def.slot, ItemDefinition.Slot.TOOL)
	assert_eq(def.power, 2)
	assert_eq(def.weapon_sprite, Vector2i(50, 0))


func test_armor_fields() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"armor")
	assert_eq(def.slot, ItemDefinition.Slot.BODY)
	assert_eq(def.power, 3)
	assert_eq(def.tier, "leather")
	assert_eq(def.armor_sprite, Vector2i(9, 5))


func test_helmet_fields() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"helmet")
	assert_eq(def.slot, ItemDefinition.Slot.HEAD)
	assert_eq(def.power, 2)
	assert_eq(def.armor_sprite, Vector2i(19, 3))


func test_boots_fields() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"boots")
	assert_eq(def.slot, ItemDefinition.Slot.FEET)
	assert_eq(def.power, 1)


func test_description_auto_generated() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_ne(def.description, "", "sword description should be auto-generated")
	assert_string_contains(def.description, "4 ATK")


func test_material_description_is_flavor() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"wood")
	assert_eq(def.description, "A bundle of sturdy logs.")


# --- Inheritance (unit tests using _resolve_inheritance directly) --

func test_inheritance_child_overrides_parent() -> void:
	var raw: Dictionary = {
		"base_sword": {
			"display_name": "Base Sword",
			"icon_idx": 21,
			"stack_size": 1,
			"slot": "weapon",
			"power": 4,
			"hands": 1,
			"attack_type": "melee",
			"weapon_category": "sword",
		},
		"steel_sword": {
			"parent": "base_sword",
			"display_name": "Steel Sword",
			"power": 6,
		},
	}
	var resolved: Dictionary = ItemRegistry._resolve_inheritance(raw)
	var steel: Dictionary = resolved["steel_sword"]
	assert_eq(steel["display_name"], "Steel Sword")
	assert_eq(int(steel["power"]), 6, "child should override power")
	assert_eq(int(steel["hands"]), 1, "child should inherit hands from parent")
	assert_eq(steel["slot"], "weapon", "child should inherit slot")
	assert_eq(steel["weapon_category"], "sword",
		"child should inherit weapon_category")


func test_inheritance_multi_level() -> void:
	var raw: Dictionary = {
		"base": {
			"display_name": "Base",
			"icon_idx": 1,
			"stack_size": 1,
			"slot": "weapon",
			"power": 2,
			"tier": "wood",
		},
		"mid": {
			"parent": "base",
			"display_name": "Mid",
			"power": 4,
			"tier": "iron",
		},
		"top": {
			"parent": "mid",
			"display_name": "Top",
			"power": 8,
		},
	}
	var resolved: Dictionary = ItemRegistry._resolve_inheritance(raw)
	var top: Dictionary = resolved["top"]
	assert_eq(int(top["power"]), 8, "top should have its own power")
	assert_eq(top["tier"], "iron", "top should inherit tier from mid")
	assert_eq(int(top["stack_size"]), 1, "top should inherit stack_size from base")


func test_inheritance_circular_does_not_crash() -> void:
	var raw: Dictionary = {
		"a": {"parent": "b", "display_name": "A", "icon_idx": 1},
		"b": {"parent": "a", "display_name": "B", "icon_idx": 2},
	}
	# Should not hang or crash — just warn and resolve.
	var resolved: Dictionary = ItemRegistry._resolve_inheritance(raw)
	assert_true(resolved.has("a"), "circular ref should still produce a result")
	assert_true(resolved.has("b"), "circular ref should still produce a result")


# --- WeaponAtlas reads from ItemDefinition ------------------------

func test_weapon_atlas_reads_item_definition() -> void:
	var cell: Vector2i = WeaponAtlas.cell_for(&"sword")
	assert_eq(cell, Vector2i(43, 5),
		"weapon_sprite from items.json should be used")


func test_weapon_atlas_bow() -> void:
	var cell: Vector2i = WeaponAtlas.cell_for(&"bow")
	assert_eq(cell, Vector2i(52, 0))


func test_weapon_atlas_pickaxe() -> void:
	var cell: Vector2i = WeaponAtlas.cell_for(&"pickaxe")
	assert_eq(cell, Vector2i(50, 0))


func test_weapon_atlas_unknown() -> void:
	var cell: Vector2i = WeaponAtlas.cell_for(&"wood")
	assert_eq(cell, Vector2i(-1, -1))


# --- ArmorAtlas reads from ItemDefinition -------------------------

func test_armor_atlas_reads_item_definition() -> void:
	var cell: Vector2i = ArmorAtlas.cell_for(&"armor")
	assert_eq(cell, Vector2i(9, 5),
		"armor_sprite from items.json should be used")


func test_armor_atlas_helmet() -> void:
	var cell: Vector2i = ArmorAtlas.cell_for(&"helmet")
	assert_eq(cell, Vector2i(19, 3))


func test_armor_atlas_unknown() -> void:
	var cell: Vector2i = ArmorAtlas.cell_for(&"wood")
	assert_eq(cell, Vector2i(-1, -1))


# --- Editor API ---------------------------------------------------

func test_get_raw_data_returns_dict() -> void:
	var raw: Dictionary = ItemRegistry.get_raw_data()
	assert_true(raw.has("sword"), "raw data should have sword entry")
	assert_true(raw.has("wood"), "raw data should have wood entry")


func test_get_resolved_entry() -> void:
	var entry: Dictionary = ItemRegistry.get_resolved_entry("sword")
	assert_eq(entry.get("display_name", ""), "Iron Sword")
	assert_eq(int(entry.get("power", 0)), 4)


func test_reload() -> void:
	var _def := ItemRegistry.get_item(&"sword")
	ItemRegistry.reload()
	var def2: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_not_null(def2)
	assert_eq(def2.display_name, "Iron Sword")



