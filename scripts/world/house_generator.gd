## HouseGenerator
##
## Procedural house interior. Delegates layout to [RoomGenerator] then
## stamps a visual style and scatters furniture.
##
## `style` selects the wall/floor tile set:
##   &"wood"  — dungeon_sheet.png rows 6-9 (default, normal overworld houses)
##   &"stone" — dungeon_sheet.png rows 1-4 (ruins, dungeon-adjacent)
##
## Furniture cells are drawn from [TilesetCatalog.INTERIOR_FURNITURE] (which
## the user configures in the Game Editor → "Interior Furniture" category).
## If no furniture is configured the scatter array is left empty.
class_name HouseGenerator
extends RefCounted

const MIN_DIM: int = 8
const MAX_DIM: int = 14
const MIN_DIM_COMPLEX: int = 22
const MAX_DIM_COMPLEX: int = 30
const MAX_ROOMS_COMPLEX: int = 5
## Max furniture items to scatter per house.
const MAX_FURNITURE: int = 5


static func generate(seed_val: int, style: StringName = &"wood",
		complex: bool = false) -> InteriorMap:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var min_d: int = MIN_DIM_COMPLEX if complex else MIN_DIM
	var max_d: int = MAX_DIM_COMPLEX if complex else MAX_DIM
	var w: int = rng.randi_range(min_d, max_d)
	var h: int = rng.randi_range(min_d, max_d)

	var m: InteriorMap
	if complex:
		m = RoomGenerator.generate_complex(rng, w, h, MAX_ROOMS_COMPLEX)
	else:
		m = RoomGenerator.generate(rng, w, h)
	m.map_id = &"house"
	m.seed = seed_val
	m.style = style

	_scatter_furniture(rng, m)
	return m


static func _scatter_furniture(rng: RandomNumberGenerator, m: InteriorMap) -> void:
	var furniture: Dictionary = TilesetCatalog.INTERIOR_FURNITURE
	if furniture.is_empty():
		return
	var types: Array = furniture.keys()
	# Collect walkable floor cells that are not the entry/exit and not on
	# the map edge so furniture is never placed blocking doors.
	var candidates: Array[Vector2i] = []
	for y in range(1, m.height - 1):
		for x in range(1, m.width - 1):
			var cell := Vector2i(x, y)
			if m.at(cell) != TerrainCodes.INTERIOR_FLOOR:
				continue
			if cell == m.entry_cell or cell == m.exit_cell:
				continue
			candidates.append(cell)
	if candidates.is_empty():
		return
	# Shuffle candidates deterministically.
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var count: int = mini(rng.randi_range(1, MAX_FURNITURE), candidates.size())
	for i in count:
		var t: StringName = types[rng.randi_range(0, types.size() - 1)]
		m.furniture_scatter.append({"cell": candidates[i], "type": t})

