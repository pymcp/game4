## Tests for Phase 3: Stat System Overhaul
extends GutTest


var _backup: Dictionary = {}


func before_all() -> void:
	ItemRegistry.reset()
	_backup = ItemRegistry.get_raw_data().duplicate(true)


func before_each() -> void:
	ItemRegistry.reset()


func after_all() -> void:
	ItemRegistry.save_data(_backup)
	ItemRegistry.reset()


# --- Equipment.equipment_stat_totals() ----------------------------

func test_stat_totals_empty_equipment() -> void:
	var eq := Equipment.new()
	var totals: Dictionary = eq.equipment_stat_totals()
	assert_eq(totals.size(), 0, "empty equipment = empty totals")


func test_stat_totals_single_item_no_bonuses() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.WEAPON, &"sword")
	var totals: Dictionary = eq.equipment_stat_totals()
	assert_eq(totals.size(), 0, "sword has no stat bonuses")


func test_stat_totals_with_bonuses() -> void:
	var raw: Dictionary = _backup.duplicate(true)
	raw["test_ring"] = {
		"display_name": "Ring of Might",
		"icon_idx": 1,
		"slot": "off_hand",
		"power": 0,
		"stat_bonuses": {"strength": 2, "speed": 1},
	}
	ItemRegistry.save_data(raw)
	ItemRegistry.reset()

	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.OFF_HAND, &"test_ring")
	var totals: Dictionary = eq.equipment_stat_totals()
	assert_eq(int(totals.get(&"strength", 0)), 2)
	assert_eq(int(totals.get(&"speed", 0)), 1)


func test_stat_totals_stacks_across_slots() -> void:
	var raw: Dictionary = _backup.duplicate(true)
	raw["test_helm"] = {
		"display_name": "Test Helm",
		"icon_idx": 1,
		"slot": "head",
		"power": 1,
		"stat_bonuses": {"strength": 1},
	}
	raw["test_chest"] = {
		"display_name": "Test Chest",
		"icon_idx": 2,
		"slot": "body",
		"power": 2,
		"stat_bonuses": {"strength": 3, "dexterity": 1},
	}
	ItemRegistry.save_data(raw)
	ItemRegistry.reset()

	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.HEAD, &"test_helm")
	eq.equip(ItemDefinition.Slot.BODY, &"test_chest")
	var totals: Dictionary = eq.equipment_stat_totals()
	assert_eq(int(totals.get(&"strength", 0)), 4, "1+3 strength")
	assert_eq(int(totals.get(&"dexterity", 0)), 1)


# --- PlayerController.get_effective_stat() ------------------------

func test_get_effective_stat_base_only() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	assert_eq(player.get_effective_stat(&"strength"), 3,
		"base strength = 3 with no equipment bonuses")


func test_get_effective_stat_with_equipment() -> void:
	var raw: Dictionary = _backup.duplicate(true)
	raw["str_sword"] = {
		"display_name": "Str Sword",
		"icon_idx": 21,
		"slot": "weapon",
		"power": 4,
		"stat_bonuses": {"strength": 2},
	}
	ItemRegistry.save_data(raw)
	ItemRegistry.reset()

	var player := PlayerController.new()
	add_child_autofree(player)
	player.equipment.equip(ItemDefinition.Slot.WEAPON, &"str_sword")
	assert_eq(player.get_effective_stat(&"strength"), 5,
		"base 3 + equipment 2 = 5")


func test_get_effective_stat_unknown_stat() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	assert_eq(player.get_effective_stat(&"luck"), 0,
		"unknown stat should be 0")


# --- PlayerController.get_move_speed() ----------------------------

func test_move_speed_no_bonus() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	assert_almost_eq(player.get_move_speed(), 60.0, 0.01)


func test_move_speed_with_speed_stat() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	player.stats[&"speed"] = 4
	assert_almost_eq(player.get_move_speed(), 72.0, 0.01,
		"60 * 1.2 = 72")


func test_move_speed_with_equipment_bonus() -> void:
	var raw: Dictionary = _backup.duplicate(true)
	raw["speed_boots"] = {
		"display_name": "Speed Boots",
		"icon_idx": 33,
		"slot": "feet",
		"power": 1,
		"stat_bonuses": {"speed": 2},
	}
	ItemRegistry.save_data(raw)
	ItemRegistry.reset()

	var player := PlayerController.new()
	add_child_autofree(player)
	player.equipment.equip(ItemDefinition.Slot.FEET, &"speed_boots")
	assert_almost_eq(player.get_move_speed(), 66.0, 0.01)


# --- Expanded base stats ------------------------------------------

func test_expanded_stats_exist() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	assert_eq(player.get_stat(&"speed"), 0)
	assert_eq(player.get_stat(&"defense"), 0)
	assert_eq(player.get_stat(&"dexterity"), 0)
	assert_eq(player.get_stat(&"charisma"), 3)
	assert_eq(player.get_stat(&"wisdom"), 3)
	assert_eq(player.get_stat(&"strength"), 3)
