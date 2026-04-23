## WeaponAtlas
##
## Maps equipped item IDs to character-sheet atlas cells for the persistent
## weapon sprite on the player. Reads from ItemDefinition.weapon_sprite
## (set in items.json via the Item Editor); falls back to coded defaults
## when the field is unset.
##
## Weapons are 2 tiles tall on the character sheet (16×33 region).
## Call [method cell_for] with an item id; returns Vector2i(-1, -1) if the
## item has no displayable weapon sprite.
extends RefCounted
class_name WeaponAtlas

## Fallback cells used when ItemDefinition has no weapon_sprite.
const _DEFAULTS: Dictionary = {
	&"sword":   Vector2i(42, 5),
	&"pickaxe": Vector2i(50, 0),
	&"bow":     Vector2i(52, 0),
}

const _NO_CELL := Vector2i(-1, -1)


## Returns the atlas cell for the given item id's weapon sprite.
## Priority: ItemDefinition.weapon_sprite → _DEFAULTS.
## Returns `Vector2i(-1, -1)` for items with no displayable weapon.
static func cell_for(item_id: StringName) -> Vector2i:
	var def: ItemDefinition = ItemRegistry.get_item(item_id)
	if def != null and def.weapon_sprite != _NO_CELL:
		return def.weapon_sprite
	return _DEFAULTS.get(item_id, _NO_CELL)


## Returns the Rect2 region for a weapon cell (2 tiles tall).
static func region_for(item_id: StringName) -> Rect2:
	var cell: Vector2i = cell_for(item_id)
	if cell == _NO_CELL:
		return Rect2()
	return Rect2(
		cell.x * CharacterAtlas.STRIDE,
		cell.y * CharacterAtlas.STRIDE,
		CharacterAtlas.TILE,
		CharacterAtlas.TILE * 2 + 1,  # 33px for 2-tile-tall weapon
	)
