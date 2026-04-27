extends GutTest

func before_each() -> void:
	NamesRegistry.reset()

func test_roll_name_returns_string_from_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var name: String = NamesRegistry.roll_name(&"story_teller", rng)
	assert_true(name.length() > 0, "Should return a non-empty name")
	assert_true(name in NamesRegistry.get_pool(&"story_teller"),
			"Name should be from the story_teller pool")

func test_roll_name_unknown_role_returns_role_string() -> void:
	var rng := RandomNumberGenerator.new()
	var name: String = NamesRegistry.roll_name(&"wizard", rng)
	assert_eq(name, "wizard", "Unknown role should return role id as fallback")

func test_all_roles_have_pools() -> void:
	for role in [&"story_teller", &"warrior", &"blacksmith", &"cook", &"alchemist"]:
		var pool := NamesRegistry.get_pool(role)
		assert_true(pool.size() >= 3, "Pool for %s should have at least 3 names" % role)
