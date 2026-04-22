## Tests for Phase 5: Element Resistances + Armor Set Bonuses
extends GutTest


var _backup: Dictionary = {}


func before_all() -> void:
	ItemRegistry.reset()
	ArmorSetRegistry.reset()
	_backup = ItemRegistry.get_raw_data().duplicate(true)


func before_each() -> void:
	ItemRegistry.reset()
	ArmorSetRegistry.reset()


func after_all() -> void:
	ItemRegistry.save_data(_backup)
	ItemRegistry.reset()
	ArmorSetRegistry.reset()


# --- Monster element resistance ----------------------------------

func test_monster_no_resistance_full_damage() -> void:
	var m := Monster.new()
	add_child_autofree(m)
	m.take_hit(2, null, ItemDefinition.Element.FIRE)
	assert_eq(m.health, 1, "no resistance → full damage")


func test_monster_resistance_reduces_damage() -> void:
	var m := Monster.new()
	m.resistances = {ItemDefinition.Element.FIRE: 0.5}
	add_child_autofree(m)
	m.take_hit(4, null, ItemDefinition.Element.FIRE)
	# ceil(4 * 0.5) = 2, health = 3 - 2 = 1
	assert_eq(m.health, 1, "fire resist 0.5 → half damage")


func test_monster_immunity() -> void:
	var m := Monster.new()
	m.resistances = {ItemDefinition.Element.ICE: 0.0}
	add_child_autofree(m)
	m.take_hit(10, null, ItemDefinition.Element.ICE)
	# ceil(10 * 0.0) = 0, clamped to 1
	assert_eq(m.health, 2, "immune still takes min 1 damage")


func test_monster_weakness_amplifies_damage() -> void:
	var m := Monster.new()
	m.resistances = {ItemDefinition.Element.LIGHTNING: 2.0}
	add_child_autofree(m)
	m.take_hit(2, null, ItemDefinition.Element.LIGHTNING)
	# ceil(2 * 2.0) = 4, health = 3 - 4 = 0 (clamped)
	assert_eq(m.health, 0, "weakness doubles damage")


func test_monster_physical_ignores_resistance() -> void:
	var m := Monster.new()
	m.resistances = {ItemDefinition.Element.FIRE: 0.0}
	add_child_autofree(m)
	m.take_hit(2, null, 0)  # element NONE = 0
	assert_eq(m.health, 1, "physical damage ignores element resistances")


func test_monster_unmatched_element_full_damage() -> void:
	var m := Monster.new()
	m.resistances = {ItemDefinition.Element.FIRE: 0.0}
	add_child_autofree(m)
	m.take_hit(2, null, ItemDefinition.Element.ICE)
	assert_eq(m.health, 1, "ice attack vs fire resist = full damage")


# --- NPC element resistance --------------------------------------

func test_npc_resistance_reduces_damage() -> void:
	var n := NPC.new()
	n.resistances = {ItemDefinition.Element.POISON: 0.5}
	n.hostile = true
	add_child_autofree(n)
	n.take_hit(4, null, ItemDefinition.Element.POISON)
	# ceil(4 * 0.5) = 2, health = 5 - 2 = 3
	assert_eq(n.health, 3)


# --- ArmorSetRegistry loading ------------------------------------

func test_leather_set_exists() -> void:
	var ids: Array = ArmorSetRegistry.all_ids()
	assert_true(ids.has("leather"), "leather set should be registered")


func test_set_bonus_below_threshold() -> void:
	var bonuses: Dictionary = ArmorSetRegistry.calc_set_bonuses("leather", 1)
	assert_eq(bonuses.size(), 0, "1 piece = no bonus")


func test_set_bonus_at_2_pieces() -> void:
	var bonuses: Dictionary = ArmorSetRegistry.calc_set_bonuses("leather", 2)
	assert_eq(int(bonuses.get(&"speed", 0)), 1, "2pc = +1 speed")


func test_set_bonus_at_3_pieces_cumulative() -> void:
	var bonuses: Dictionary = ArmorSetRegistry.calc_set_bonuses("leather", 3)
	# 2pc: speed+1, 3pc: speed+1 defense+1 → cumulative: speed=2, defense=1
	assert_eq(int(bonuses.get(&"speed", 0)), 2, "3pc = +2 speed cumulative")
	assert_eq(int(bonuses.get(&"defense", 0)), 1, "3pc = +1 defense")


func test_unknown_set_returns_empty() -> void:
	var bonuses: Dictionary = ArmorSetRegistry.calc_set_bonuses("nonexistent", 5)
	assert_eq(bonuses.size(), 0)


# --- Equipment.get_active_set_bonuses() --------------------------

func test_no_set_items_no_bonus() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.WEAPON, &"sword")
	var bonuses: Dictionary = eq.get_active_set_bonuses()
	assert_eq(bonuses.size(), 0)


func test_two_leather_pieces_grants_bonus() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.HEAD, &"helmet")
	eq.equip(ItemDefinition.Slot.BODY, &"armor")
	var bonuses: Dictionary = eq.get_active_set_bonuses()
	assert_eq(int(bonuses.get(&"speed", 0)), 1, "2 leather pieces = +1 speed")


func test_three_leather_pieces_grants_full_bonus() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.HEAD, &"helmet")
	eq.equip(ItemDefinition.Slot.BODY, &"armor")
	eq.equip(ItemDefinition.Slot.FEET, &"boots")
	var bonuses: Dictionary = eq.get_active_set_bonuses()
	assert_eq(int(bonuses.get(&"speed", 0)), 2, "3 leather = +2 speed")
	assert_eq(int(bonuses.get(&"defense", 0)), 1, "3 leather = +1 defense")


# --- Set bonuses feed into equipment_stat_totals() ---------------

func test_stat_totals_includes_set_bonus() -> void:
	var raw: Dictionary = _backup.duplicate(true)
	raw["test_helm_s"] = {
		"display_name": "Set Helm",
		"icon_idx": 1,
		"slot": "head",
		"power": 1,
		"set_id": "leather",
		"stat_bonuses": {"strength": 1},
	}
	raw["test_chest_s"] = {
		"display_name": "Set Chest",
		"icon_idx": 2,
		"slot": "body",
		"power": 2,
		"set_id": "leather",
		"stat_bonuses": {},
	}
	ItemRegistry.save_data(raw)
	ItemRegistry.reset()

	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.HEAD, &"test_helm_s")
	eq.equip(ItemDefinition.Slot.BODY, &"test_chest_s")
	var totals: Dictionary = eq.equipment_stat_totals()
	# Item bonuses: strength=1. Set bonus (2pc leather): speed=1.
	assert_eq(int(totals.get(&"strength", 0)), 1, "item bonus")
	assert_eq(int(totals.get(&"speed", 0)), 1, "set bonus speed")
