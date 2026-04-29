extends GutTest


func before_each() -> void:
	PetRegistry.reload()


func test_hedgehog_ability_is_sniff_loot() -> void:
	assert_eq(PetRegistry.get_ability(&"hedgehog"), &"sniff_loot")


func test_hedgehog_cooldown_is_positive() -> void:
	assert_gt(PetRegistry.get_ability_cooldown(&"hedgehog"), 0.0)


func test_non_hedgehog_pets_have_no_ability() -> void:
	for sp: StringName in [&"cat", &"dog", &"duck", &"chameleon", &"roly_poly"]:
		assert_eq(PetRegistry.get_ability(sp), &"none",
				"Expected %s to have no ability" % String(sp))


func test_hedgehog_loot_pool_species_in_item_registry() -> void:
	# Validate all hedgehog loot pool items actually exist in ItemRegistry.
	var pool: Array[StringName] = [&"wood", &"stone", &"fiber", &"iron_ore", &"copper_ore"]
	for item_id: StringName in pool:
		var def: ItemDefinition = ItemRegistry.get_item(item_id)
		assert_not_null(def, "ItemRegistry missing item: %s" % String(item_id))
