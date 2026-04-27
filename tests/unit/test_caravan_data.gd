extends GutTest

func test_add_member() -> void:
	var cd := CaravanData.new()
	cd.add_member(&"warrior")
	assert_true(cd.has_member(&"warrior"), "Should have warrior after adding")

func test_has_member_false_initially() -> void:
	var cd := CaravanData.new()
	assert_false(cd.has_member(&"blacksmith"), "Should not have blacksmith initially")

func test_remove_member() -> void:
	var cd := CaravanData.new()
	cd.add_member(&"warrior")
	cd.remove_member(&"warrior")
	assert_false(cd.has_member(&"warrior"), "Should not have warrior after removal")

func test_add_duplicate_does_not_duplicate() -> void:
	var cd := CaravanData.new()
	cd.add_member(&"warrior")
	cd.add_member(&"warrior")
	assert_eq(cd.recruited_ids.size(), 1, "No duplicate members allowed")

func test_inventory_is_created() -> void:
	var cd := CaravanData.new()
	assert_not_null(cd.inventory, "Inventory should be initialized")

func test_inventory_add_and_remove() -> void:
	var cd := CaravanData.new()
	cd.inventory.add(&"wood", 3)
	assert_eq(cd.inventory.count_of(&"wood"), 3)
	cd.inventory.remove(&"wood", 2)
	assert_eq(cd.inventory.count_of(&"wood"), 1)

func test_to_dict_and_from_dict_round_trip() -> void:
	var cd := CaravanData.new()
	cd.add_member(&"blacksmith")
	cd.add_member(&"cook")
	cd.inventory.add(&"stone", 5)

	var d: Dictionary = cd.to_dict()

	var cd2 := CaravanData.new()
	cd2.from_dict(d)

	assert_true(cd2.has_member(&"blacksmith"), "Round-trip: blacksmith present")
	assert_true(cd2.has_member(&"cook"), "Round-trip: cook present")
	assert_false(cd2.has_member(&"warrior"), "Round-trip: warrior absent")
	assert_eq(cd2.inventory.count_of(&"stone"), 5, "Round-trip: stone count correct")

func test_empty_to_dict_and_from_dict() -> void:
	var cd := CaravanData.new()
	var d: Dictionary = cd.to_dict()
	var cd2 := CaravanData.new()
	cd2.from_dict(d)
	assert_eq(cd2.recruited_ids.size(), 0)
