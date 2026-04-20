## CraftingRegistry
##
## Static collection of `CraftingRecipe`s. Defaults are baked in; designers
## may drop `.tres` overrides under `res://resources/recipes/` (will replace
## any default with the same id).
class_name CraftingRegistry
extends RefCounted

const _OVERRIDE_DIR: String = "res://resources/recipes/"

static var _cache: Dictionary = {}
static var _initialised: bool = false


static func get_recipe(id: StringName) -> CraftingRecipe:
	if not _initialised:
		_init_defaults()
	return _cache.get(id, null)


static func all_recipes() -> Array:
	if not _initialised:
		_init_defaults()
	return _cache.values()


static func reset() -> void:
	_cache.clear()
	_initialised = false


static func _init_defaults() -> void:
	_initialised = true
	_define(&"sword",
		[{"id": &"wood", "count": 1}, {"id": &"stone", "count": 4},
			{"id": &"fiber", "count": 1}],
		&"sword", 1)
	_define(&"helmet",
		[{"id": &"fiber", "count": 4}],
		&"helmet", 1)
	_define(&"armor",
		[{"id": &"fiber", "count": 6}],
		&"armor", 1)
	_define(&"boots",
		[{"id": &"fiber", "count": 3}],
		&"boots", 1)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_OVERRIDE_DIR)):
		var d := DirAccess.open(_OVERRIDE_DIR)
		if d != null:
			d.list_dir_begin()
			var n: String = d.get_next()
			while n != "":
				if n.ends_with(".tres"):
					var r := load(_OVERRIDE_DIR + n) as CraftingRecipe
					if r != null and r.id != &"":
						_cache[r.id] = r
				n = d.get_next()


static func _define(id: StringName, inputs: Array, output_id: StringName,
		output_count: int) -> void:
	var r := CraftingRecipe.new()
	r.id = id
	r.inputs = inputs
	r.output_id = output_id
	r.output_count = output_count
	_cache[id] = r
