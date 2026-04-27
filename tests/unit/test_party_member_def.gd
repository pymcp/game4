extends GutTest

func test_fields_exist() -> void:
	var d := PartyMemberDef.new()
	d.id = &"warrior"
	d.display_name = "Warrior"
	d.crafter_domain = &""
	d.portrait_cell = Vector2i(0, 0)
	d.can_follow = true
	assert_eq(d.id, &"warrior")
	assert_eq(d.display_name, "Warrior")
	assert_eq(d.crafter_domain, &"")
	assert_eq(d.portrait_cell, Vector2i(0, 0))
	assert_true(d.can_follow)

func test_crafter_domain_empty_for_warrior() -> void:
	var d := PartyMemberDef.new()
	d.crafter_domain = &""
	assert_eq(d.crafter_domain, &"", "Warrior has no crafter domain")

func test_can_follow_false_for_crafters() -> void:
	var d := PartyMemberDef.new()
	d.can_follow = false
	assert_false(d.can_follow)
