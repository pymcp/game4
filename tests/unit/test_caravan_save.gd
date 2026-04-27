extends GutTest


func test_caravan_data_round_trip() -> void:
	var cd := CaravanData.new()
	cd.add_member(&"blacksmith")
	cd.add_member(&"warrior")
	cd.inventory.add(&"stone", 7)

	var d: Dictionary = cd.to_dict()

	var cd2 := CaravanData.new()
	cd2.from_dict(d)

	assert_true(cd2.has_member(&"blacksmith"))
	assert_true(cd2.has_member(&"warrior"))
	assert_eq(cd2.inventory.count_of(&"stone"), 7)


func test_caravan_save_data_fields() -> void:
	var csd := CaravanSaveData.new()
	csd.player_id = 1
	csd.recruited_ids = [&"warrior", &"cook"]
	csd.inventory_data = {"slots": []}
	assert_eq(csd.player_id, 1)
	assert_eq(csd.recruited_ids.size(), 2)
	assert_true(csd.inventory_data.has("slots"))
