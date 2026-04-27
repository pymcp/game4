extends GutTest

func before_each() -> void:
	CraftingRegistry.reset()

func test_blacksmith_recipes_include_sword() -> void:
	var recipes := CraftingRegistry.get_by_domain(&"blacksmith")
	var ids := []
	for r in recipes:
		ids.append(r.id)
	assert_true(ids.has(&"sword"), "sword should be a blacksmith recipe")

func test_blacksmith_recipes_include_armor() -> void:
	var recipes := CraftingRegistry.get_by_domain(&"blacksmith")
	var ids := []
	for r in recipes:
		ids.append(r.id)
	assert_true(ids.has(&"armor"))
	assert_true(ids.has(&"helmet"))
	assert_true(ids.has(&"boots"))

func test_blacksmith_has_four_recipes() -> void:
	var recipes := CraftingRegistry.get_by_domain(&"blacksmith")
	assert_eq(recipes.size(), 4, "All 4 default recipes are blacksmith domain")

func test_cook_domain_returns_empty() -> void:
	var recipes := CraftingRegistry.get_by_domain(&"cook")
	assert_eq(recipes.size(), 0, "No cook recipes yet")

func test_unknown_domain_returns_empty() -> void:
	var recipes := CraftingRegistry.get_by_domain(&"unknown_xyz")
	assert_eq(recipes.size(), 0)

func test_recipe_has_domain_field() -> void:
	var r := CraftingRegistry.get_recipe(&"sword")
	assert_not_null(r)
	assert_eq(r.crafter_domain, &"blacksmith")
