extends GutTest


func before_each() -> void:
	PetRegistry.reload()


func test_all_species_returns_six() -> void:
	var species: Array[StringName] = PetRegistry.all_species()
	assert_eq(species.size(), 6)


func test_all_species_contains_expected() -> void:
	var species: Array[StringName] = PetRegistry.all_species()
	assert_true(species.has(&"cat"))
	assert_true(species.has(&"dog"))
	assert_true(species.has(&"hedgehog"))
	assert_true(species.has(&"duck"))
	assert_true(species.has(&"chameleon"))
	assert_true(species.has(&"roly_poly"))


func test_display_name_hedgehog() -> void:
	assert_eq(PetRegistry.get_display_name(&"hedgehog"), "Hedgehog")


func test_display_name_roly_poly() -> void:
	assert_eq(PetRegistry.get_display_name(&"roly_poly"), "Roly Poly")


func test_ability_hedgehog() -> void:
	assert_eq(PetRegistry.get_ability(&"hedgehog"), &"sniff_loot")


func test_ability_cat_is_none() -> void:
	assert_eq(PetRegistry.get_ability(&"cat"), &"none")


func test_ability_dog_is_none() -> void:
	assert_eq(PetRegistry.get_ability(&"dog"), &"none")


func test_cooldown_hedgehog() -> void:
	assert_eq(PetRegistry.get_ability_cooldown(&"hedgehog"), 90.0)


func test_cooldown_none_ability_is_zero() -> void:
	assert_eq(PetRegistry.get_ability_cooldown(&"cat"), 0.0)


func test_ability_description_hedgehog() -> void:
	var desc: String = PetRegistry.get_ability_description(&"hedgehog")
	assert_true(desc.length() > 0)


func test_unknown_species_returns_defaults() -> void:
	assert_eq(PetRegistry.get_display_name(&"unknown_critter"), "unknown_critter")
	assert_eq(PetRegistry.get_ability(&"unknown_critter"), &"none")
	assert_eq(PetRegistry.get_ability_cooldown(&"unknown_critter"), 0.0)
	assert_eq(PetRegistry.get_ability_description(&"unknown_critter"), "")


func test_reload_clears_and_reloads_cache() -> void:
	var _s: Array[StringName] = PetRegistry.all_species()  # populate cache
	PetRegistry.reload()
	var species: Array[StringName] = PetRegistry.all_species()
	assert_eq(species.size(), 6)
