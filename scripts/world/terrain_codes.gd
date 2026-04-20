## TerrainCodes
##
## Single source of truth for the byte values stored in `Region.tiles`.
## Kept tiny (uint8) so a 128×128 region is only 16 KB on disk.
##
## Mapping back to renderable tiles is the job of `OverworldTileset`; bumping
## a value here is breaking unless save migration is added.
class_name TerrainCodes
extends RefCounted

const OCEAN: int = 0   # deep water, not walkable
const WATER: int = 1   # shallow / shore water, not walkable (yet)
const SAND: int = 2
const GRASS: int = 3
const DIRT: int = 4
const ROCK: int = 5
const SNOW: int = 6    # rendered as modulate-tinted grass
const SWAMP: int = 7   # rendered as modulate-tinted grass

# ─── Interior / dungeon codes (Phase 8) ────────────────────────────────
const INTERIOR_FLOOR: int = 16
const INTERIOR_WALL: int = 17
const INTERIOR_DOOR: int = 18  # walkable; marks entry/exit between rooms
const INTERIOR_STAIRS_UP: int = 19  # walkable; exits the interior
const INTERIOR_STAIRS_DOWN: int = 20  # walkable; descends to next floor

# ─── City codes (top-down city map: roads + sidewalks + buildings) ─────
const CITY_ROAD: int = 24
const CITY_SIDEWALK: int = 25
const CITY_BUILDING_WALL: int = 26  # not walkable; building exterior
const CITY_BUILDING_DOOR: int = 27  # walkable; entry portal into a HOUSE map


## True for terrain a player may stand on.
static func is_walkable(code: int) -> bool:
	if code == OCEAN or code == WATER:
		return false
	if code == INTERIOR_WALL or code == CITY_BUILDING_WALL:
		return false
	return true


## Maps terrain codes to the StringName terrain_type used by the runtime
## TileSet (built by `TileSetBuilder`). Snow/swamp share grass tiles since
## we tint them via modulate.
static func to_terrain_type(code: int) -> StringName:
	match code:
		OCEAN, WATER: return &"water"
		SAND: return &"sand"
		GRASS, SNOW, SWAMP: return &"grass"
		DIRT: return &"dirt"
		ROCK: return &"stone"
		INTERIOR_FLOOR: return &"floor"
		INTERIOR_WALL: return &"wall"
		INTERIOR_DOOR: return &"door"
		INTERIOR_STAIRS_UP, INTERIOR_STAIRS_DOWN: return &"floor"
		CITY_ROAD: return &"road"
		CITY_SIDEWALK: return &"sidewalk"
		CITY_BUILDING_WALL: return &"wall"
		CITY_BUILDING_DOOR: return &"door"
		_: return &"grass"
