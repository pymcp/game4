## InteriorMap
##
## A self-contained interior (dungeon, building, cave, etc.). Stored as a
## small `Resource` so it can be cached or saved alongside `Region`s.
##
## Coordinate system: (0, 0) is the top-left tile. `entry_cell` is the tile
## the player stands on when first entering — typically a stairs/door cell
## that `WorldRoot` (Phase 8c) will treat as an exit when stepped on.
##
## `exit_cell` is the matching cell that returns to the overworld when
## stepped on. May equal `entry_cell` for single-tile interiors.
class_name InteriorMap
extends Resource

## Layout-shaping constants. Generators are free to ignore them but the
## defaults match Region-style 8-bit tile codes.
const MIN_SIZE: int = 16
const MAX_SIZE: int = 96

@export var map_id: StringName = &""
## Source-of-truth for tile dimensions; tiles array length must equal
## `width * height`.
@export var width: int = 32
@export var height: int = 32
## Row-major `TerrainCodes.INTERIOR_*` bytes.
@export var tiles: PackedByteArray = PackedByteArray()
## Tile player spawns on when entering; usually a stairs-up tile.
@export var entry_cell: Vector2i = Vector2i.ZERO
## Tile that returns to overworld when stepped on.
@export var exit_cell: Vector2i = Vector2i.ZERO
## Deterministic seed used to generate this map (for re-derivation).
@export var seed: int = 0
## Each entry: `{kind: StringName, cell: Vector2i, variant: int}`.
@export var npcs_scatter: Array = []
## Each entry: `{kind: StringName, cell: Vector2i}`.
@export var loot_scatter: Array = []
## Region this map is attached to (so we know where to land on exit).
@export var origin_region_id: Vector2i = Vector2i.ZERO
## Cell in the overworld region that hosts the entrance. Returning the
## player from the dungeon teleports them adjacent to this cell.
@export var origin_cell: Vector2i = Vector2i.ZERO
## 1-based cave depth. Floor 1 is the cave entered from the overworld;
## stepping on STAIRS_DOWN descends to floor 2, and so on.
@export var floor_num: int = 1
## `map_id` of the cave one floor up. Empty when the parent is the
## overworld (i.e. `floor_num == 1`).
@export var parent_map_id: StringName = &""
## Cell on the parent floor where the player should reappear when they
## climb back up — this is the parent floor's STAIRS_DOWN cell.
@export var parent_entrance_cell: Vector2i = Vector2i.ZERO
## Each entry: {cell: Vector2i, floor_num: int} — placed by LabyrinthGenerator at dead ends.
@export var chest_scatter: Array = []
## Floor cells that make up the boss room area (used for boss-room floor decor overlay).
@export var boss_room_cells: Array = []  # Array of Vector2i
## Boss spawn data: {kind: StringName, cell: Vector2i, adds: [{kind, cell}]}.
## Empty dict when this floor has no boss room.
@export var boss_data: Dictionary = {}
## Maximum depth for this interior chain. 0 = unlimited (default).
## When floor_num == max_floor, stairs_down are suppressed so the player
## cannot descend further. Propagated automatically by MapManager.descend_from.
@export var max_floor: int = 0
## Human-readable name shown in the location toast when entering.
## Stamped by MapManager.get_or_generate; callers may override for named
## locations (e.g. "Moonstone Mine").
@export var location_name: String = ""

## Deterministic random name list used to name generic dungeons/labyrinths.
static var _DUNGEON_NAMES: Array[String] = [
	"Ashfall Catacombs", "Bonewhisper Depths", "Carrion Hollow",
	"Duskstone Warren", "Ember Vault", "Festering Grotto",
	"Gloomhaven Burrow", "Howling Rift", "Ironblood Keep",
	"Jackal's Den", "Korrith's Tomb", "Lichen Pit",
	"Murkmere Cavern", "Nightshard Mine", "Obsidian Tangle",
	"Pale Root Hollow", "Quarry of Sighs", "Rattlecage Dungeon",
	"Saltmaw Cavern", "Thornveil Labyrinth", "Umbral Passage",
	"Venomstone Depths", "Wailing Chasm", "Xenolith Vault",
	"Yellowing Halls", "Zephyr Crypt", "Ashen Gate",
	"Blightfold Tunnel", "Coldbone Cave", "Darkroot Descent",
	"Eroded Sanctum", "Frostbitten Keep", "Grimrock Hollow",
	"Hearthstone Delve", "Inkwater Abyss", "Jagged Maw",
	"Kelpweed Grotto", "Loststone Labyrinth", "Mossbreach Cavern",
	"Nettlevein Pit", "Ossuary of Storms", "Putrid Warren",
	"Quavering Deep", "Rusthaven Tunnels", "Scourgebone Rift",
	"Tidewrack Catacombs", "Underglass Mine", "Vapour Hollow",
	"Whisperstone Depths", "Xorn's Crossing", "Yellowstone Pit",
]

## Pick a deterministic name from the list using an integer seed.
static func pick_name(seed_val: int) -> String:
	var idx: int = absi(seed_val) % _DUNGEON_NAMES.size()
	return _DUNGEON_NAMES[idx]

## Visual style for room-wall rendering: &"wood" (default) or &"stone".
## Drives which dungeon_sheet.png row set the renderer uses for walls/floors.
@export var style: StringName = &"wood"
## Furniture placed inside rooms. Each entry: {cell: Vector2i, type: StringName}.
## WorldRoot reads `TileMappings.interior_furniture[type]` to resolve the atlas cell.
@export var furniture_scatter: Array = []
## Rects (in interior tile coordinates) that contain room-style chambers inside
## a dungeon or labyrinth. WorldRoot uses room-wall tiles for cells inside
## these rects instead of the cave autotile.
@export var chamber_rects: Array = []  # Array of Rect2i


func _init() -> void:
	if tiles.size() != width * height:
		tiles = PackedByteArray()
		tiles.resize(width * height)


## Returns the terrain code at `cell`, or `INTERIOR_WALL` if out of bounds
## (so OOB lookups behave like running into a wall).
func at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return TerrainCodes.INTERIOR_WALL
	return tiles[cell.y * width + cell.x]


func set_at(cell: Vector2i, code: int) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return
	tiles[cell.y * width + cell.x] = code


func is_walkable_at(cell: Vector2i) -> bool:
	return TerrainCodes.is_walkable(at(cell))
