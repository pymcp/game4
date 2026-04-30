## Region
##
## Full procedurally-generated content for a 128×128 tile region. Stored as
## a `Resource` so it round-trips through `.tres` save files cleanly.
##
## `tiles` is a flat row-major `PackedByteArray` of `TerrainCodes.*` values
## (see `at()` / `set_at()` helpers). Decorations and entity scatter live in
## separate arrays to keep them inspectable per cell without scanning bytes.
class_name Region
extends Resource

const SIZE: int = 128

@export var region_id: Vector2i = Vector2i.ZERO
@export var biome: StringName = &"grass"
@export var seed: int = 0
@export var is_ocean: bool = false
## row-major SIZE*SIZE bytes; values from `TerrainCodes`.
@export var tiles: PackedByteArray = PackedByteArray()
## Each entry: `{kind: StringName, cell: Vector2i, variant: int}`.
@export var decorations: Array = []
## Bitmask of sides that EXTEND LAND (no ocean ring on those edges). N=1
## E=2 S=4 W=8.
@export var bleed_edges: int = 0
## Tile of the pier base on shore (Vector2i(-1,-1) if no pier).
@export var pier_position: Vector2i = Vector2i(-1, -1)
## In-region cells where players spawn when entering.
@export var spawn_points: Array[Vector2i] = []
## Reserved for later phases (resources, NPCs, dungeon entrances).
@export var resources_scatter: Array = []
@export var npcs_scatter: Array = []
@export var dungeon_entrances: Array = []
## Each entry: {cell: Vector2i, source: int (0..2), atlas: Vector2i}.
@export var runes: Array = []
## Placed encounter instances: {encounter_id: StringName, cell: Vector2i}.
@export var encounters: Array = []
## Path tiles painted with overlay path indices (1-tile-wide corridor).
@export var path_tiles: Array[Vector2i] = []


func _init() -> void:
	if tiles.size() != SIZE * SIZE:
		tiles = PackedByteArray()
		tiles.resize(SIZE * SIZE)


func at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= SIZE or cell.y >= SIZE:
		return TerrainCodes.OCEAN
	return tiles[cell.y * SIZE + cell.x]


func set_at(cell: Vector2i, code: int) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= SIZE or cell.y >= SIZE:
		return
	tiles[cell.y * SIZE + cell.x] = code


func is_walkable_at(cell: Vector2i) -> bool:
	return TerrainCodes.is_walkable(at(cell))
