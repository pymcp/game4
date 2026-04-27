extends GutTest

func before_each() -> void:
	PartyMemberRegistry.reset()

func test_get_all_returns_five_members() -> void:
	var all := PartyMemberRegistry.get_all()
	assert_eq(all.size(), 5, "Should have 5 party members")

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

func test_all_ids_returns_five() -> void:
	var ids := PartyMemberRegistry.all_ids()
	assert_eq(ids.size(), 5)

func test_reset_clears_cache() -> void:
	var _pre := PartyMemberRegistry.get_all()
	PartyMemberRegistry.reset()
	var post := PartyMemberRegistry.get_all()
	assert_eq(post.size(), 5, "Should reload from disk after reset")

func test_story_teller_exists_and_cannot_follow() -> void:
	var d := PartyMemberRegistry.get_member(&"story_teller")
	assert_not_null(d, "Story Teller should exist")
	assert_false(d.can_follow, "Story Teller should not follow into dungeons")
	assert_eq(d.crafter_domain, &"", "Story Teller has no crafter domain")

func test_get_unknown_returns_null() -> void:
	var d := PartyMemberRegistry.get_member(&"unknown_xyz")
	assert_null(d, "Unknown id should return null")
