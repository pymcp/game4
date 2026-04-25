## FogOfWarData
##
## Per-player fog-of-war bitmask store. Each visited region gets a
## 2048-byte PackedByteArray (128×128 bits = one bit per tile).
## Bit index = y * 128 + x.
class_name FogOfWarData
extends RefCounted

## region_id (Vector2i) → PackedByteArray (2048 bytes)
var _fog: Dictionary = {}


## Mark all tiles within [param radius] tiles of [param cell] as revealed
## in [param region_id]. Tiles outside 0–127 are silently skipped.
func reveal(region_id: Vector2i, cell: Vector2i, radius: int) -> void:
	if not _fog.has(region_id):
		var data := PackedByteArray()
		data.resize(2048)
		_fog[region_id] = data
	var data: PackedByteArray = _fog[region_id]
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


## Returns true if [param cell] in [param region_id] has been revealed.
func is_revealed(region_id: Vector2i, cell: Vector2i) -> bool:
	if not _fog.has(region_id):
		return false
	if cell.x < 0 or cell.x >= 128 or cell.y < 0 or cell.y >= 128:
		return false
	var idx: int = cell.y * 128 + cell.x
	var data: PackedByteArray = _fog[region_id]
	return (data[idx >> 3] & (1 << (idx & 7))) != 0


## Returns true if [param region_id] has any revealed tiles.
func has_region(region_id: Vector2i) -> bool:
	return _fog.has(region_id)


## Returns an Array[Vector2i] of all region IDs with any revealed tiles.
func get_all_region_ids() -> Array:
	return _fog.keys()


## Serialize to a Dictionary safe for storage in a .tres Resource field.
## Keys are "x,y" strings; values are PackedByteArray.
func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for rid: Vector2i in _fog.keys():
		result["%d,%d" % [rid.x, rid.y]] = _fog[rid].duplicate()
	return result


## Restore from a dictionary produced by [method to_dict].
func from_dict(d: Dictionary) -> void:
	_fog.clear()
	for key: String in d.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() != 2:
			continue
		var rid := Vector2i(int(parts[0]), int(parts[1]))
		_fog[rid] = (d[key] as PackedByteArray).duplicate()
