## Tests for Phase 7: Seed Items + Inventory Polish
extends GutTest


func before_each() -> void:
	ItemRegistry.reset()
	ArmorSetRegistry.reset()


# --- Inheritance resolution ---

func test_steel_sword_inherits_base_sword() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"steel_sword")
	assert_not_null(def)
	assert_eq(def.display_name, "Steel Sword")
	assert_eq(def.slot, ItemDefinition.Slot.WEAPON)
	assert_eq(def.hands, 1)
	assert_eq(def.attack_type, ItemDefinition.AttackType.MELEE)
	assert_eq(def.weapon_category, ItemDefinition.WeaponCategory.SWORD)
	assert_almost_eq(def.attack_speed, 0.35, 0.001)
	assert_almost_eq(def.reach, 24.0, 0.1)
	assert_eq(def.power, 6)
	assert_eq(def.tier, "steel")
	assert_eq(def.rarity, ItemDefinition.Rarity.UNCOMMON)


func test_fire_sword_inherits_from_sword() -> void:
	# fire_sword → sword → base_sword (two levels of inheritance)
	var def: ItemDefinition = ItemRegistry.get_item(&"fire_sword")
	assert_not_null(def)
	assert_eq(def.element, ItemDefinition.Element.FIRE)
	assert_eq(def.attack_type, ItemDefinition.AttackType.MELEE)
	assert_eq(def.weapon_category, ItemDefinition.WeaponCategory.SWORD)
	assert_eq(def.rarity, ItemDefinition.Rarity.RARE)
	assert_eq(int(def.stat_bonuses.get("strength", 0)), 1)


func test_mithril_sword_stats() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"mithril_sword")
	assert_eq(def.power, 9)
	assert_eq(def.rarity, ItemDefinition.Rarity.RARE)
	assert_eq(int(def.stat_bonuses.get("speed", 0)), 1)


# --- Base items ---

func test_base_items_exist() -> void:
	for base_id in ["base_sword", "base_axe", "base_spear", "base_bow",
			"base_staff", "base_dagger", "base_shield", "base_helmet",
			"base_armor", "base_boots"]:
		assert_true(ItemRegistry.has_item(StringName(base_id)),
			"base item '%s' should exist" % base_id)


# --- Weapon variety ---

func test_axes_have_knockback() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"iron_axe")
	assert_true(def.knockback > 0, "axes should have knockback")
	assert_eq(def.weapon_category, ItemDefinition.WeaponCategory.AXE)


func test_spear_two_handed_long_reach() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"iron_spear")
	assert_eq(def.hands, 2)
	assert_true(def.reach >= 36, "spears should have long reach")
	assert_eq(def.weapon_category, ItemDefinition.WeaponCategory.SPEAR)


func test_elemental_staves() -> void:
	var fire: ItemDefinition = ItemRegistry.get_item(&"fire_staff")
	assert_eq(fire.element, ItemDefinition.Element.FIRE)
	assert_eq(fire.weapon_category, ItemDefinition.WeaponCategory.STAFF)
	var ice: ItemDefinition = ItemRegistry.get_item(&"ice_staff")
	assert_eq(ice.element, ItemDefinition.Element.ICE)
	var lightning: ItemDefinition = ItemRegistry.get_item(&"lightning_staff")
	assert_eq(lightning.element, ItemDefinition.Element.LIGHTNING)
	assert_eq(lightning.rarity, ItemDefinition.Rarity.RARE)


func test_daggers_fast_attack() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"iron_dagger")
	assert_true(def.attack_speed <= 0.25, "daggers should be fast")
	assert_eq(def.weapon_category, ItemDefinition.WeaponCategory.DAGGER)


func test_poison_dagger() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"poison_dagger")
	assert_eq(def.element, ItemDefinition.Element.POISON)
	assert_eq(def.rarity, ItemDefinition.Rarity.RARE)
	assert_eq(int(def.stat_bonuses.get("dexterity", 0)), 2)


func test_longbow_greater_range() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"longbow")
	var bow: ItemDefinition = ItemRegistry.get_item(&"bow")
	assert_true(def.reach > bow.reach, "longbow should have greater reach than bow")


# --- Shields ---

func test_shields_off_hand() -> void:
	for shield_id in [&"wooden_shield", &"iron_shield", &"steel_shield"]:
		var def: ItemDefinition = ItemRegistry.get_item(shield_id)
		assert_eq(def.slot, ItemDefinition.Slot.OFF_HAND,
			"%s should be off_hand" % shield_id)
		assert_true(int(def.stat_bonuses.get("defense", 0)) > 0,
			"%s should have defense bonus" % shield_id)


func test_shield_power_scales_with_tier() -> void:
	var wood: ItemDefinition = ItemRegistry.get_item(&"wooden_shield")
	var iron: ItemDefinition = ItemRegistry.get_item(&"iron_shield")
	var steel: ItemDefinition = ItemRegistry.get_item(&"steel_shield")
	assert_true(steel.power > iron.power and iron.power > wood.power,
		"shield power should scale: wood < iron < steel")


# --- Armor sets ---

func test_iron_armor_set_pieces() -> void:
	for piece_id in [&"iron_helmet", &"iron_armor", &"iron_boots"]:
		var def: ItemDefinition = ItemRegistry.get_item(piece_id)
		assert_eq(def.set_id, "iron",
			"%s should be in iron set" % piece_id)
		assert_eq(def.rarity, ItemDefinition.Rarity.UNCOMMON)


func test_iron_set_bonus_exists() -> void:
	var bonuses: Dictionary = ArmorSetRegistry.calc_set_bonuses("iron", 3)
	assert_true(bonuses.size() > 0, "iron 3pc should have bonuses")
	assert_true(int(bonuses.get(&"defense", 0)) >= 2,
		"iron 3pc should give defense")
	assert_true(int(bonuses.get(&"strength", 0)) >= 1,
		"iron 3pc should give strength")


# --- Description generation ---

func test_description_contains_element() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"fire_sword")
	var desc: String = def.generate_description()
	assert_true(desc.contains("Fire"), "fire sword description should mention Fire")


func test_description_contains_stat_bonuses() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"mithril_sword")
	var desc: String = def.generate_description()
	assert_true(desc.contains("SPD") or desc.contains("SPEED"),
		"mithril sword description should mention speed bonus")


func test_description_contains_set_name() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"iron_armor")
	var desc: String = def.generate_description()
	assert_true(desc.contains("Iron") and desc.contains("Set"),
		"iron armor description should mention Iron Set")


# --- Rarity colors ---

func test_rarity_colors_dict_complete() -> void:
	for r in ItemDefinition.Rarity.values():
		assert_true(ItemDefinition.RARITY_COLORS.has(r),
			"RARITY_COLORS should have entry for %s" % ItemDefinition.Rarity.keys()[r])


func test_rare_items_have_correct_rarity() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"steel_sword")
	assert_eq(def.rarity, ItemDefinition.Rarity.UNCOMMON)
	def = ItemRegistry.get_item(&"mithril_sword")
	assert_eq(def.rarity, ItemDefinition.Rarity.RARE)


# --- Total item count ---

func test_total_item_count() -> void:
	var ids: Array = ItemRegistry.all_ids()
	assert_true(ids.size() >= 42, "should have at least 42 items")


# --- Materials preserved ---

func test_materials_preserved() -> void:
	for mat_id in [&"wood", &"stone", &"fiber", &"iron_ore", &"copper_ore",
			&"gold_ore", &"fennel_root"]:
		var def: ItemDefinition = ItemRegistry.get_item(mat_id)
		assert_not_null(def, "%s should exist" % mat_id)
		assert_eq(def.slot, ItemDefinition.Slot.NONE)
		assert_eq(def.stack_size, 99)
