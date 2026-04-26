## DungeonFogData
##
## Per-player fog-of-war bitmask store for interior maps (dungeons,
## labyrinths, etc.). Mirrors [FogOfWarData] but uses [StringName]
## map_ids as keys instead of [Vector2i] region ids.
##
## Interior maps are at most 128 tiles wide/tall (MAX_SIZE = 96 + margin),
## so we reuse the same 2048-byte bitmask layout (128×128 bits).
class_name DungeonFogData
extends RefCounted

## map_id (StringName) → PackedByteArray (2048 bytes, 128×128 bits).
var _fog: Dictionary = {}


## Mark all tiles within [param radius] tiles of [param cell] as revealed
## for [param map_id]. Tiles outside 0–127 are silently skipped.
func reveal(map_id: StringName, cell: Vector2i, radius: int) -> void:
	if not _fog.has(map_id):
		var data := PackedByteArray()
		data.resize(2048)
		_fog[map_id] = data
	var data: PackedByteArray = _fog[map_id]
	var r2: int = radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var cx: int = cell.x + dx
			var cy: int = cell.y + dy
			if cx < 0 or cx >= 128 or cy < 0 or cy >= 128:
				continue
			var idx: int = cy * 128 + cx
			data[idx >> 3] = data[idx >> 3] | (1 << (idx & 7))


## Returns true if [param cell] in [param map_id] has been revealed.
func is_revealed(map_id: StringName, cell: Vector2i) -> bool:
	if not _fog.has(map_id):
		return false
	if cell.x < 0 or cell.x >= 128 or cell.y < 0 or cell.y >= 128:
		return false
	var idx: int = cell.y * 128 + cell.x
	var data: PackedByteArray = _fog[map_id]
	return (data[idx >> 3] & (1 << (idx & 7))) != 0


## Returns true if [param map_id] has any revealed tiles.
func has_map(map_id: StringName) -> bool:
	return _fog.has(map_id)


## Returns an Array of all map_ids with any revealed tiles.
func get_all_map_ids() -> Array:
	return _fog.keys()


## Serialize to a [Dictionary] safe for storage in a .tres Resource field.
## Keys are String representations of the map_id; values are PackedByteArray.
func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for mid: StringName in _fog.keys():
		result[String(mid)] = _fog[mid].duplicate()
	return result


## Restore from a dictionary produced by [method to_dict].
func from_dict(d: Dictionary) -> void:
	_fog.clear()
	for key: String in d.keys():
		_fog[StringName(key)] = (d[key] as PackedByteArray).duplicate()
