## CrafterPanel
##
## Domain-filtered crafting panel. Shows only recipes for a specific
## crafter_domain and operates against the caravan's shared inventory.
##
## One CrafterPanel is instantiated per crafter in the CaravanMenu.
extends Control
class_name CrafterPanel

var _domain: StringName = &""
var _caravan_data: CaravanData = null
var _list: VBoxContainer = null
var _buttons: Array[Button] = []
var _ordered_ids: Array[StringName] = []
var _cursor: int = 0


## Returns all recipes for [param domain] in stable alphabetical order.
static func ordered_by_domain(domain: StringName) -> Array:
	var recipes: Array = CraftingRegistry.get_by_domain(domain)
	var copy: Array = recipes.duplicate()
	copy.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return copy


func set_crafter(domain: StringName, caravan_data: CaravanData) -> void:
	_domain = domain
	_caravan_data = caravan_data
	if _caravan_data != null and _caravan_data.inventory != null:
		if not _caravan_data.inventory.contents_changed.is_connected(_refresh):
			_caravan_data.inventory.contents_changed.connect(_refresh)
	_build()
	_refresh()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(220, 0)


func _build() -> void:
	# Clear any previously built children.
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	_ordered_ids.clear()
	_cursor = 0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	margin.add_child(v)

	for recipe in ordered_by_domain(_domain):
		_ordered_ids.append(recipe.id)
		var btn := Button.new()
		btn.text = CraftingPanel.format_recipe_label(recipe)
		btn.pressed.connect(_on_pressed.bind(recipe.id))
		v.add_child(btn)
		_buttons.append(btn)
	_refresh_cursor()


func _refresh() -> void:
	for i in range(_ordered_ids.size()):
		var id: StringName = _ordered_ids[i]
		if i >= _buttons.size():
			break
		var btn: Button = _buttons[i]
		var recipe: CraftingRecipe = CraftingRegistry.get_recipe(id)
		if recipe == null or _caravan_data == null or _caravan_data.inventory == null:
			btn.disabled = true
			continue
		btn.disabled = not recipe.can_craft(_caravan_data.inventory)


func _on_pressed(recipe_id: StringName) -> void:
	if _caravan_data == null:
		return
	var recipe: CraftingRecipe = CraftingRegistry.get_recipe(recipe_id)
	if recipe == null:
		return
	recipe.craft(_caravan_data.inventory)


## Called by CaravanMenu when this panel has keyboard focus.
## [param verb] is a PlayerActions verb constant.
func navigate(verb: StringName) -> void:
	if _buttons.is_empty():
		return
	match verb:
		PlayerActions.UP:
			_cursor = wrapi(_cursor - 1, 0, _buttons.size())
			_refresh_cursor()
		PlayerActions.DOWN:
			_cursor = wrapi(_cursor + 1, 0, _buttons.size())
			_refresh_cursor()
		PlayerActions.INTERACT:
			if _cursor < _ordered_ids.size():
				_on_pressed(_ordered_ids[_cursor])


func _refresh_cursor() -> void:
	for i in _buttons.size():
		var btn: Button = _buttons[i]
		if i == _cursor:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			btn.remove_theme_color_override("font_color")
