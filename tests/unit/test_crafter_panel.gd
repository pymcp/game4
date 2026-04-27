extends GutTest

func before_each() -> void:
	CraftingRegistry.reset()
	ItemRegistry.reset()


func test_format_recipe_label_static() -> void:
	# Reuse CraftingPanel.format_recipe_label — it's already tested.
	# Just confirm CrafterPanel has the static ordered_by_domain helper.
	var recipes := CrafterPanel.ordered_by_domain(&"blacksmith")
	assert_true(recipes is Array)


func test_blacksmith_recipes_count() -> void:
	var recipes := CrafterPanel.ordered_by_domain(&"blacksmith")
	assert_eq(recipes.size(), 4, "Blacksmith should have 4 recipes")


func test_cook_domain_returns_empty() -> void:
	var recipes := CrafterPanel.ordered_by_domain(&"cook")
	assert_eq(recipes.size(), 0)


func test_unknown_domain_returns_empty() -> void:
	var recipes := CrafterPanel.ordered_by_domain(&"unknown_xyz")
	assert_eq(recipes.size(), 0)
