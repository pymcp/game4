## HouseGenerator
##
## Tiny procedural interior for a single house — a rectangular room of
## `INTERIOR_FLOOR` surrounded by `INTERIOR_WALL`, with a single
## `INTERIOR_DOOR` punched in the south wall. The door cell doubles as the
## `entry_cell` and `exit_cell` so stepping on it returns the player to the
## overworld (or city) tile they entered from.
##
## Houses are intentionally small (8–14 tiles) — this is the per-locked-
## decision MVP fallback for "procedural houses if possible".
class_name HouseGenerator
extends RefCounted

const MIN_DIM: int = 8
const MAX_DIM: int = 14


static func generate(seed_val: int) -> InteriorMap:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var w: int = rng.randi_range(MIN_DIM, MAX_DIM)
	var h: int = rng.randi_range(MIN_DIM, MAX_DIM)

	var m := InteriorMap.new()
	m.map_id = &"house"
	m.seed = seed_val
	m.width = w
	m.height = h
	m.tiles = PackedByteArray()
	m.tiles.resize(w * h)

	for y in h:
		for x in w:
			var on_edge: bool = (x == 0 or y == 0 or x == w - 1 or y == h - 1)
			m.set_at(Vector2i(x, y),
				TerrainCodes.INTERIOR_WALL if on_edge else TerrainCodes.INTERIOR_FLOOR)

	# Door in the middle of the south wall.
	var door := Vector2i(w / 2, h - 1)
	m.set_at(door, TerrainCodes.INTERIOR_DOOR)
	m.entry_cell = Vector2i(door.x, door.y - 1)
	m.exit_cell = door
	return m
