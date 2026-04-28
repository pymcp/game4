## CraftingPanel
##
## A vertical list of buttons — one per [CraftingRecipe] in
## [CraftingRegistry]. Each button shows the output icon, name, and inputs.
## Disabled buttons indicate the recipe can't currently be crafted.
##
## Designed to live inside [InventoryScreen]; pure helpers
## [code]format_recipe_label[/code] and [code]ordered_recipes[/code] are
## static and unit-testable.
extends Control
class_name CraftingPanel

var _player: PlayerController = null
var _list: VBoxContainer = null
var _buttons: Array[Button] = []
var _ordered_ids: Array[StringName] = []


# ---------- Pure helpers ----------

## Return all recipes in a stable, alphabetical-by-id order so UI doesn't
## reshuffle every time the registry rebuilds its dictionary.
static func ordered_recipes() -> Array:
	var recipes: Array = CraftingRegistry.all_recipes()
	var copy: Array = recipes.duplicate()
	copy.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return copy


## Format a one-line summary of the recipe inputs, e.g.
## "3× wood + 1× fiber → axe".
static func format_recipe_label(recipe: CraftingRecipe) -> String:
	if recipe == null:
		return ""
	var parts: Array = []
	for ing in recipe.inputs:
		var def: ItemDefinition = ItemRegistry.get_item(ing["id"])
		var label: String = def.display_name if def != null else String(ing["id"])
		parts.append("%d× %s" % [int(ing["count"]), label])
	var out_def: ItemDefinition = ItemRegistry.get_item(recipe.output_id)
	var out_name: String = out_def.display_name if out_def != null else String(recipe.output_id)
	var prefix: String = ""
	if int(recipe.output_count) > 1:
		prefix = "%d× " % int(recipe.output_count)
	return "%s → %s%s" % [" + ".join(parts), prefix, out_name]


# ---------- Lifecycle ----------

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(220, 0)
	_build()
	_refresh()


func set_player(p: PlayerController) -> void:
	if _player == p:
		return
	if _player != null and _player.inventory != null:
		if _player.inventory.contents_changed.is_connected(_refresh):
			_player.inventory.contents_changed.disconnect(_refresh)
	_player = p
	if _player != null and _player.inventory != null:
		_player.inventory.contents_changed.connect(_refresh)
	_refresh()


# ---------- Build / refresh ----------

func _build() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)

	var title := Label.new()
	title.text = "Crafting"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	v.add_child(_list)

	for recipe in ordered_recipes():
		_ordered_ids.append(recipe.id)
		var btn := Button.new()
		btn.theme_type_variation = &"WoodButton"
		btn.text = format_recipe_label(recipe)
		btn.pressed.connect(_on_pressed.bind(recipe.id))
		_list.add_child(btn)
		_buttons.append(btn)


func _refresh() -> void:
	for i in range(_ordered_ids.size()):
		var id: StringName = _ordered_ids[i]
		var btn: Button = _buttons[i]
		var recipe: CraftingRecipe = CraftingRegistry.get_recipe(id)
		if recipe == null or _player == null or _player.inventory == null:
			btn.disabled = true
			continue
		btn.disabled = not recipe.can_craft(_player.inventory)


func _on_pressed(recipe_id: StringName) -> void:
	if _player == null:
		return
	var recipe: CraftingRecipe = CraftingRegistry.get_recipe(recipe_id)
	if recipe == null:
		return
	recipe.craft(_player.inventory)
	# `_refresh` will fire via inventory's contents_changed signal.


