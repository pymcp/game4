## WeaponAtlas
##
## Maps equipped item IDs to character-sheet atlas cells for the persistent
## weapon sprite on the player. Reads from the [TileMappings] resource
## (editable via SpritePicker); falls back to coded defaults when the
## mapping is absent.
##
## Weapons are 2 tiles tall on the character sheet (16×33 region).
## Call [method cell_for] with an item id; returns Vector2i(-1, -1) if the
## item has no displayable weapon sprite.
extends RefCounted
class_name WeaponAtlas

## Fallback cells used when TileMappings has no weapon_sprites entry.
## These are the "best guess" defaults for the roguelike character sheet.
const _DEFAULTS: Dictionary = {
	&"sword":   Vector2i(42, 5),   # first sword variant, first color row
	&"pickaxe": Vector2i(50, 0),   # hammer column (closest to pickaxe)
	&"bow":     Vector2i(52, 0),   # first bow variant
}

const _NO_CELL := Vector2i(-1, -1)


## Returns the atlas cell for the given item id's weapon sprite.
## Priority: ItemDefinition.weapon_sprite → TileMappings → _DEFAULTS.
## Returns `Vector2i(-1, -1)` for items with no displayable weapon.
static func cell_for(item_id: StringName) -> Vector2i:
	# 1. ItemDefinition field (data-driven)
	var def: ItemDefinition = ItemRegistry.get_item(item_id)
	if def != null and def.weapon_sprite != _NO_CELL:
		return def.weapon_sprite
	# 2. TileMappings (editor-assigned)
	var tm: TileMappings = _load_mappings()
	if tm != null and tm.weapon_sprites.has(item_id):
		var arr: Array = tm.weapon_sprites[item_id]
		if arr.size() > 0:
			return arr[0]
	# 3. Hardcoded defaults (legacy)
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


static var _cached_mappings: TileMappings = null

static func _load_mappings() -> TileMappings:
	if _cached_mappings != null:
		return _cached_mappings
	if ResourceLoader.exists("res://resources/tilesets/tile_mappings.tres"):
		_cached_mappings = load("res://resources/tilesets/tile_mappings.tres") as TileMappings
	return _cached_mappings
