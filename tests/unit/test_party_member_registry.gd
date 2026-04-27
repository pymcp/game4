extends GutTest

func before_each() -> void:
	PartyMemberRegistry.reset()

func test_get_all_returns_four_members() -> void:
	var all := PartyMemberRegistry.get_all()
	assert_eq(all.size(), 4, "Should have 4 party members")

func test_get_warrior_returns_def() -> void:
	var d := PartyMemberRegistry.get_member(&"warrior")
	assert_not_null(d, "Warrior should exist")
	assert_eq(d.id, &"warrior")
	assert_true(d.can_follow)

func test_crafters_have_domains() -> void:
	for id in [&"blacksmith", &"cook", &"alchemist"]:
		var d := PartyMemberRegistry.get_member(id)
		assert_not_null(d, "%s should exist" % id)
		assert_ne(d.crafter_domain, &"", "%s should have a crafter_domain" % id)

func test_warrior_has_no_crafter_domain() -> void:
	var d := PartyMemberRegistry.get_member(&"warrior")
	assert_eq(d.crafter_domain, &"")

func test_all_ids_returns_four() -> void:
	var ids := PartyMemberRegistry.all_ids()
	assert_eq(ids.size(), 4)

func test_reset_clears_cache() -> void:
	var _pre := PartyMemberRegistry.get_all()
	PartyMemberRegistry.reset()
	var post := PartyMemberRegistry.get_all()
	assert_eq(post.size(), 4, "Should reload from disk after reset")

func test_get_unknown_returns_null() -> void:
	var d := PartyMemberRegistry.get_member(&"unknown_xyz")
	assert_null(d, "Unknown id should return null")
