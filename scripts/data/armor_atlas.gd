## ArmorAtlas
##
## Maps equipped armor item IDs to character-sheet atlas cells for the
## persistent equipment sprites on the player (Torso, Hair/Head, Boots).
## Mirrors the [WeaponAtlas] pattern.
##
## Each entry is {cell: Vector2i, tint: Color}. Armor tiers reuse the same
## base cell with a color tint overlay (e.g. Leather → Tough Leather).
## Call [method region_for] with an item id; returns an empty Rect2 if the
## item has no displayable armor sprite.
extends RefCounted
class_name ArmorAtlas

const _NO_CELL := Vector2i(-1, -1)

## Default armor visuals keyed by item id.
## cell = character-sheet grid cell.
## tint = Sprite2D.modulate override (white = no tint).
const _DEFAULTS: Dictionary = {
	# BODY slot — torso "armored" variants (style 3)
	&"armor":   {"cell": Vector2i(9, 5), "tint": Color(1, 1, 1)},  # tan armored, row 5

	# HEAD slot — hair ACCESSORY style (row+3)
	&"helmet":  {"cell": Vector2i(19, 3), "tint": Color(1, 1, 1)},  # brown accessory cap

	# FEET slot — placeholder, user will map via SpritePicker
	&"boots":   {"cell": _NO_CELL, "tint": Color(1, 1, 1)},
}


## Returns {cell: Vector2i, tint: Color} for the given armor item.
## Priority: ItemDefinition fields → _DEFAULTS.
## Returns {"cell": Vector2i(-1,-1), "tint": white} when the item has no
## displayable armor sprite.
static func lookup(item_id: StringName) -> Dictionary:
	# 1. ItemDefinition fields (data-driven)
	var def: ItemDefinition = ItemRegistry.get_item(item_id)
	if def != null and def.armor_sprite != Vector2i(-1, -1):
		return {"cell": def.armor_sprite, "tint": def.armor_tint}
	# 2. Hardcoded defaults (legacy)
	var entry: Dictionary = _DEFAULTS.get(item_id, {})
	if entry.is_empty():
		return {"cell": _NO_CELL, "tint": Color(1, 1, 1)}
	return entry


## Returns the atlas cell for the given armor item, or Vector2i(-1,-1).
static func cell_for(item_id: StringName) -> Vector2i:
	return lookup(item_id).get("cell", _NO_CELL)


## Returns the tint color for the given armor item, or white.
static func tint_for(item_id: StringName) -> Color:
	return lookup(item_id).get("tint", Color(1, 1, 1))


## Returns the Rect2 region for an armor cell (single tile, 16×16).
static func region_for(item_id: StringName) -> Rect2:
	var cell: Vector2i = cell_for(item_id)
	if cell == _NO_CELL:
		return Rect2()
	return Rect2(
		cell.x * CharacterAtlas.STRIDE,
		cell.y * CharacterAtlas.STRIDE,
		CharacterAtlas.TILE,
		CharacterAtlas.TILE,
	)
