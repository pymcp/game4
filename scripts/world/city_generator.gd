## CityGenerator
##
## Procedural top-down city map: a regular grid of one-tile-wide roads with
## rectangular building blocks between them. Each block is wrapped in
## `CITY_SIDEWALK` and filled with `CITY_BUILDING_WALL`; a single door
## (`CITY_BUILDING_DOOR`) is punched in one wall per block, which `WorldRoot`
## later wires to a `HouseGenerator` interior map.
##
## Output is an [InteriorMap] using `CITY_*` codes. Deterministic on `seed`.
class_name CityGenerator
extends RefCounted

const BLOCK_W: int = 8       # building footprint width in tiles
const BLOCK_H: int = 8       # building footprint height
const ROAD_W: int = 2        # road width between blocks
const SIDEWALK_W: int = 1    # sidewalk ring inside each block


## Generate a city of `cols × rows` building blocks. The map size is derived
## from the grid layout so the right/bottom edges still get a road border.
static func generate(seed_val: int, cols: int = 4, rows: int = 4) -> InteriorMap:
	cols = max(2, cols)
	rows = max(2, rows)
	var pitch_x: int = BLOCK_W + ROAD_W
	var pitch_y: int = BLOCK_H + ROAD_W
	var width: int = ROAD_W + cols * pitch_x
	var height: int = ROAD_W + rows * pitch_y

	var m := InteriorMap.new()
	m.map_id = &"city"
	m.seed = seed_val
	m.width = width
	m.height = height
	m.tiles = PackedByteArray()
	m.tiles.resize(width * height)

	# 1) Fill with road everywhere — blocks will overwrite.
	for i in width * height:
		m.tiles[i] = TerrainCodes.CITY_ROAD

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# 2) Stamp each block: sidewalk ring + building interior + one door.
	for by in rows:
		for bx in cols:
			var origin := Vector2i(ROAD_W + bx * pitch_x, ROAD_W + by * pitch_y)
			_stamp_block(m, rng, origin)

	# Player enters the city in the south-most road, centered.
	m.entry_cell = Vector2i(width / 2, height - 1)
	m.exit_cell = m.entry_cell
	return m


static func _stamp_block(m: InteriorMap, rng: RandomNumberGenerator,
		origin: Vector2i) -> void:
	# Sidewalk ring.
	for y in BLOCK_H:
		for x in BLOCK_W:
			var c := origin + Vector2i(x, y)
			m.set_at(c, TerrainCodes.CITY_SIDEWALK)
	# Building interior (walls — non-walkable).
	for y in range(SIDEWALK_W, BLOCK_H - SIDEWALK_W):
		for x in range(SIDEWALK_W, BLOCK_W - SIDEWALK_W):
			m.set_at(origin + Vector2i(x, y), TerrainCodes.CITY_BUILDING_WALL)
	# Door on a random side, centered.
	var side: int = rng.randi_range(0, 3)
	var door: Vector2i
	match side:
		0: door = origin + Vector2i(BLOCK_W / 2, SIDEWALK_W)            # top wall
		1: door = origin + Vector2i(BLOCK_W - 1 - SIDEWALK_W, BLOCK_H / 2)  # right wall
		2: door = origin + Vector2i(BLOCK_W / 2, BLOCK_H - 1 - SIDEWALK_W)  # bottom wall
		_: door = origin + Vector2i(SIDEWALK_W, BLOCK_H / 2)            # left wall
	m.set_at(door, TerrainCodes.CITY_BUILDING_DOOR)
