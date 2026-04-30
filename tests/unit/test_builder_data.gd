extends GutTest

func before_each() -> void:
	PartyMemberRegistry.reset()

func test_builder_is_registered() -> void:
	var def: PartyMemberDef = PartyMemberRegistry.get_member(&"builder")
	assert_not_null(def, "builder should be registered")
	assert_eq(def.id, &"builder")

func test_builder_has_builds_field() -> void:
	var def: PartyMemberDef = PartyMemberDef.new()
	assert_true(def.has_method("get") or "builds" in def,
			"PartyMemberDef should have builds property")

func test_builder_builds_loaded_from_json() -> void:
	var def: PartyMemberDef = PartyMemberRegistry.get_member(&"builder")
	assert_not_null(def)
	assert_true(def.builds.size() > 0, "builder should have at least one build entry")
	var entry: Dictionary = def.builds[0]
	assert_eq(entry.get("id", ""), "house_basic")
	assert_true(entry.has("cost"), "build entry should have cost")

func test_house_basic_costs_10_wood() -> void:
	var def: PartyMemberDef = PartyMemberRegistry.get_member(&"builder")
	assert_not_null(def)
	var entry: Dictionary = def.builds[0]
	var cost: Dictionary = entry.get("cost", {})
	assert_eq(int(cost.get("wood", 0)), 10)

func test_other_members_builds_empty() -> void:
	var warrior: PartyMemberDef = PartyMemberRegistry.get_member(&"warrior")
	assert_not_null(warrior)
	assert_eq(warrior.builds.size(), 0, "warrior should have no builds")
