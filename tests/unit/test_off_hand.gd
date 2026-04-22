## Tests for Phase 2: OFF_HAND slot, shields, handedness & Equipment.equip()
extends GutTest


func before_each() -> void:
	ItemRegistry.reset()


# --- can_equip() --------------------------------------------------

func test_can_equip_shield_when_no_weapon() -> void:
	var eq := Equipment.new()
	assert_true(eq.can_equip(ItemDefinition.Slot.OFF_HAND, &"sword"),
		"should allow off-hand when no weapon equipped")


func test_can_equip_shield_with_1h_weapon() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.WEAPON, &"sword")  # sword is 1-handed
	assert_true(eq.can_equip(ItemDefinition.Slot.OFF_HAND, &"sword"),
		"should allow off-hand with 1h weapon")


func test_cannot_equip_shield_with_2h_weapon() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.WEAPON, &"bow")  # bow is 2-handed
	assert_false(eq.can_equip(ItemDefinition.Slot.OFF_HAND, &"sword"),
		"should reject off-hand when 2h weapon equipped")


func test_can_equip_unknown_item_returns_false() -> void:
	var eq := Equipment.new()
	assert_false(eq.can_equip(ItemDefinition.Slot.WEAPON, &"nonexistent"),
		"should reject unknown items")


# --- equip() displaced items return --------------------------------

func test_equip_returns_previous_occupant() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.WEAPON, &"sword")
	var displaced: Array = eq.equip(ItemDefinition.Slot.WEAPON, &"bow")
	assert_eq(displaced.size(), 1, "should displace one item")
	assert_eq(displaced[0][0], ItemDefinition.Slot.WEAPON)
	assert_eq(displaced[0][1], &"sword")


func test_equip_empty_slot_returns_empty() -> void:
	var eq := Equipment.new()
	var displaced: Array = eq.equip(ItemDefinition.Slot.WEAPON, &"sword")
	assert_eq(displaced.size(), 0, "empty slot should displace nothing")


func test_equip_2h_weapon_displaces_off_hand() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.OFF_HAND, &"sword")  # 1h in off-hand
	var displaced: Array = eq.equip(ItemDefinition.Slot.WEAPON, &"bow")  # 2h
	# Should displace the off-hand item.
	var displaced_ids: Array = []
	for pair in displaced:
		displaced_ids.append(pair[1])
	assert_has(displaced_ids, &"sword", "2h weapon should displace off-hand")
	# Off-hand should now be empty.
	assert_eq(eq.get_equipped(ItemDefinition.Slot.OFF_HAND), &"")


func test_equip_2h_weapon_displaces_both_prev_and_offhand() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.WEAPON, &"sword")
	eq.equip(ItemDefinition.Slot.OFF_HAND, &"pickaxe")
	var displaced: Array = eq.equip(ItemDefinition.Slot.WEAPON, &"bow")  # 2h
	assert_eq(displaced.size(), 2, "should displace weapon + off-hand")


func test_equip_1h_weapon_does_not_displace_offhand() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.OFF_HAND, &"pickaxe")
	var displaced: Array = eq.equip(ItemDefinition.Slot.WEAPON, &"sword")  # 1h
	assert_eq(displaced.size(), 0, "1h weapon should not displace off-hand")
	assert_eq(eq.get_equipped(ItemDefinition.Slot.OFF_HAND), &"pickaxe")


# --- OFF_HAND slot basics -----------------------------------------

func test_equip_off_hand() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.OFF_HAND, &"sword")
	assert_eq(eq.get_equipped(ItemDefinition.Slot.OFF_HAND), &"sword")


func test_unequip_off_hand() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.OFF_HAND, &"sword")
	var prev: StringName = eq.unequip(ItemDefinition.Slot.OFF_HAND)
	assert_eq(prev, &"sword")
	assert_eq(eq.get_equipped(ItemDefinition.Slot.OFF_HAND), &"")


func test_off_hand_counts_in_total_power() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.OFF_HAND, &"sword")  # power=4
	assert_eq(eq.total_power(ItemDefinition.Slot.OFF_HAND), 4)


func test_off_hand_in_grand_total() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.WEAPON, &"sword")    # power=4
	eq.equip(ItemDefinition.Slot.OFF_HAND, &"bow")    # power=3
	assert_eq(eq.total_power(), 7, "grand total should include off-hand")


# --- Armor defense includes OFF_HAND ------------------------------

func test_armor_defense_with_off_hand() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	player.health = 10
	player.max_health = 10
	player.equipment.equip(ItemDefinition.Slot.BODY, &"armor")    # power=3
	player.equipment.equip(ItemDefinition.Slot.OFF_HAND, &"bow")  # power=3 (used as shield proxy)
	player.take_hit(10)
	# defense = 3+3 = 6, effective = max(1, 10-6) = 4
	assert_eq(player.health, 6,
		"off-hand power should count as defense")


# --- Slot enum backward compat ------------------------------------

func test_slot_off_hand_value() -> void:
	assert_eq(ItemDefinition.Slot.OFF_HAND, 6)


func test_original_slots_unchanged() -> void:
	assert_eq(ItemDefinition.Slot.NONE, 0)
	assert_eq(ItemDefinition.Slot.WEAPON, 1)
	assert_eq(ItemDefinition.Slot.TOOL, 2)
	assert_eq(ItemDefinition.Slot.HEAD, 3)
	assert_eq(ItemDefinition.Slot.BODY, 4)
	assert_eq(ItemDefinition.Slot.FEET, 5)


# --- Serialization with OFF_HAND ----------------------------------

func test_to_dict_includes_off_hand() -> void:
	var eq := Equipment.new()
	eq.equip(ItemDefinition.Slot.WEAPON, &"sword")
	eq.equip(ItemDefinition.Slot.OFF_HAND, &"bow")
	var d: Dictionary = eq.to_dict()
	assert_eq(d[int(ItemDefinition.Slot.OFF_HAND)], "bow")


func test_from_dict_restores_off_hand() -> void:
	var eq := Equipment.new()
	eq.from_dict({
		int(ItemDefinition.Slot.WEAPON): "sword",
		int(ItemDefinition.Slot.OFF_HAND): "bow",
	})
	assert_eq(eq.get_equipped(ItemDefinition.Slot.OFF_HAND), &"bow")


# --- Inventory screen slot label ----------------------------------

func test_slot_label_off_hand() -> void:
	var label: String = InventoryScreen.slot_label(ItemDefinition.Slot.OFF_HAND)
	assert_eq(label, "Off-Hand")


func test_slot_label_weapon() -> void:
	var label: String = InventoryScreen.slot_label(ItemDefinition.Slot.WEAPON)
	assert_eq(label, "Weapon")
