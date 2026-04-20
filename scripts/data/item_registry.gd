## ItemRegistry
##
## Static registry of `ItemDefinition`s. Built lazily on first access. Designer
## overrides may be dropped at `res://resources/items/<id>.tres` and will
## replace the in-code default for that id.
class_name ItemRegistry
extends RefCounted

const _OVERRIDE_DIR: String = "res://resources/items/"
const _ICON_BASE: String = "res://assets/icons/generic_items/genericItem_color_%03d.png"

static var _cache: Dictionary = {}
static var _initialised: bool = false


static func get_item(id: StringName) -> ItemDefinition:
	if not _initialised:
		_init_defaults()
	return _cache.get(id, null)


static func has_item(id: StringName) -> bool:
	if not _initialised:
		_init_defaults()
	return _cache.has(id)


static func all_ids() -> Array:
	if not _initialised:
		_init_defaults()
	return _cache.keys()


## Convenience for tests / save migration.
static func reset() -> void:
	_cache.clear()
	_initialised = false


static func _init_defaults() -> void:
	_initialised = true
	_define(&"wood", "Wood", 1, ItemDefinition.Slot.NONE, 0, 99,
		"A bundle of sturdy logs.")
	_define(&"stone", "Stone", 2, ItemDefinition.Slot.NONE, 0, 99,
		"A heavy chunk of rock.")
	_define(&"fiber", "Fiber", 3, ItemDefinition.Slot.NONE, 0, 99,
		"Plant fibres for crafting.")
	_define(&"iron_ore", "Iron Ore", 4, ItemDefinition.Slot.NONE, 0, 99,
		"A lump of unrefined iron.")
	_define(&"copper_ore", "Copper Ore", 5, ItemDefinition.Slot.NONE, 0, 99,
		"A lump of unrefined copper.")
	_define(&"gold_ore", "Gold Ore", 6, ItemDefinition.Slot.NONE, 0, 99,
		"A gleaming nugget of gold.")
	_define(&"pickaxe", "Iron Pickaxe", 22, ItemDefinition.Slot.TOOL, 2, 1,
		"Doubles mining damage against rocks and ore veins.")
	_define(&"sword", "Iron Sword", 21, ItemDefinition.Slot.WEAPON, 4, 1,
		"A balanced blade for combat.")
	_define(&"bow", "Wooden Bow", 24, ItemDefinition.Slot.WEAPON, 3, 1,
		"Fires arrows at distant targets.")
	_define(&"helmet", "Leather Helmet", 31, ItemDefinition.Slot.HEAD, 2, 1,
		"Reduces damage taken to the head.")
	_define(&"armor", "Leather Armor", 32, ItemDefinition.Slot.BODY, 3, 1,
		"Reduces damage taken to the body.")
	_define(&"boots", "Leather Boots", 33, ItemDefinition.Slot.FEET, 1, 1,
		"Slightly increases movement speed.")
	# Apply on-disk overrides if any exist.
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_OVERRIDE_DIR)):
		var d := DirAccess.open(_OVERRIDE_DIR)
		if d != null:
			d.list_dir_begin()
			var n: String = d.get_next()
			while n != "":
				if n.ends_with(".tres"):
					var def := load(_OVERRIDE_DIR + n) as ItemDefinition
					if def != null and def.id != &"":
						_cache[def.id] = def
				n = d.get_next()


static func _define(id: StringName, name: String, icon_idx: int,
		slot: ItemDefinition.Slot, power: int, stack: int, desc: String) -> void:
	var def := ItemDefinition.new()
	def.id = id
	def.display_name = name
	def.stack_size = stack
	def.slot = slot
	def.power = power
	def.description = desc
	var path: String = _ICON_BASE % icon_idx
	if ResourceLoader.exists(path):
		def.icon = load(path) as Texture2D
	_cache[id] = def
