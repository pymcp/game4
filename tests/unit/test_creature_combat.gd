## Tests for creature combat data accessors.
extends GutTest


func before_each() -> void:
	CreatureSpriteRegistry.reset()


# --- Attack style accessors ----------------------------------------

func test_goblin_attack_style_is_swing() -> void:
	assert_eq(CreatureSpriteRegistry.get_attack_style(&"goblin"), &"swing")


func test_wolf_attack_style_is_thrust() -> void:
	assert_eq(CreatureSpriteRegistry.get_attack_style(&"wolf"), &"thrust")


func test_fire_elemental_attack_style_is_projectile() -> void:
	assert_eq(CreatureSpriteRegistry.get_attack_style(&"fire_elemental"), &"projectile")


func test_slime_attack_style_is_slam() -> void:
	assert_eq(CreatureSpriteRegistry.get_attack_style(&"slime"), &"slam")


func test_grasshopper_attack_style_is_none() -> void:
	assert_eq(CreatureSpriteRegistry.get_attack_style(&"grasshopper"), &"none")


func test_missing_kind_defaults_to_none() -> void:
	assert_eq(CreatureSpriteRegistry.get_attack_style(&"nonexistent"), &"none")


# --- Attack damage -------------------------------------------------

func test_goblin_attack_damage() -> void:
	assert_eq(CreatureSpriteRegistry.get_attack_damage(&"goblin"), 2)


func test_ogre_attack_damage() -> void:
	assert_eq(CreatureSpriteRegistry.get_attack_damage(&"ogre"), 4)


func test_missing_kind_defaults_damage_to_1() -> void:
	assert_eq(CreatureSpriteRegistry.get_attack_damage(&"nonexistent"), 1)


# --- Attack speed --------------------------------------------------

func test_wolf_attack_speed() -> void:
	assert_almost_eq(CreatureSpriteRegistry.get_attack_speed(&"wolf"), 0.7, 0.01)


func test_ogre_attack_speed() -> void:
	assert_almost_eq(CreatureSpriteRegistry.get_attack_speed(&"ogre"), 1.5, 0.01)


func test_missing_kind_defaults_speed_to_1() -> void:
	assert_almost_eq(CreatureSpriteRegistry.get_attack_speed(&"nonexistent"), 1.0, 0.01)


# --- Attack range --------------------------------------------------

func test_slime_attack_range() -> void:
	assert_almost_eq(CreatureSpriteRegistry.get_attack_range_tiles(&"slime"), 1.0, 0.01)


func test_fire_elemental_attack_range() -> void:
	assert_almost_eq(CreatureSpriteRegistry.get_attack_range_tiles(&"fire_elemental"), 5.0, 0.01)


func test_missing_kind_defaults_range_to_1_25() -> void:
	assert_almost_eq(CreatureSpriteRegistry.get_attack_range_tiles(&"nonexistent"), 1.25, 0.01)


# --- Element -------------------------------------------------------

func test_fire_elemental_element() -> void:
	assert_eq(CreatureSpriteRegistry.get_element(&"fire_elemental"),
		ItemDefinition.Element.FIRE)


func test_ice_elemental_element() -> void:
	assert_eq(CreatureSpriteRegistry.get_element(&"ice_elemental"),
		ItemDefinition.Element.ICE)


func test_goblin_element_is_none() -> void:
	assert_eq(CreatureSpriteRegistry.get_element(&"goblin"),
		ItemDefinition.Element.NONE)


func test_missing_kind_element_is_none() -> void:
	assert_eq(CreatureSpriteRegistry.get_element(&"nonexistent"),
		ItemDefinition.Element.NONE)


# --- All creatures have valid combat data --------------------------

func test_all_creatures_have_attack_style() -> void:
	var valid_styles: Array[StringName] = [
		&"swing", &"thrust", &"projectile", &"slam", &"none",
	]
	for kind: StringName in CreatureSpriteRegistry.all_kinds():
		var style: StringName = CreatureSpriteRegistry.get_attack_style(kind)
		assert_true(valid_styles.has(style),
			"%s has invalid attack_style: %s" % [kind, style])


func test_all_creatures_have_positive_attack_damage() -> void:
	for kind: StringName in CreatureSpriteRegistry.all_kinds():
		var dmg: int = CreatureSpriteRegistry.get_attack_damage(kind)
		assert_true(dmg >= 1, "%s has attack_damage < 1: %d" % [kind, dmg])


func test_all_creatures_have_positive_attack_speed() -> void:
	for kind: StringName in CreatureSpriteRegistry.all_kinds():
		var spd: float = CreatureSpriteRegistry.get_attack_speed(kind)
		assert_true(spd > 0.0, "%s has attack_speed <= 0" % kind)
