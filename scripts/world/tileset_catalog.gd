## TilesetCatalog
##
## Builds and caches the four `TileSet` resources used by the four views
## (overworld / city / dungeon / interior) plus the rune-overlay TileSet.
##
## Each `TileSet` exposes a single `TileSetAtlasSource` (source_id 0) that
## registers EVERY 16×16 cell in the source PNG. Painters look up cells by
## `(atlas_x, atlas_y)` directly. The catalog also holds a small
## `TERRAIN_CELLS` dictionary mapping high-level terrain `StringName`s to
## the canonical "filled center" cell for each kind, so generators don't have
## to memorise pixel coordinates.
##
## Pure helper — instantiate via `TilesetCatalog.new()` or call the static
## convenience getters.
class_name TilesetCatalog
extends RefCounted

# ─── Sheet paths ────────────────────────────────────────────────────────
## Historical defaults — one per view. Used when no sheet_override exists.
const _DEFAULT_SHEETS: Dictionary = {
	&"overworld_terrain": "res://assets/tiles/roguelike/overworld_sheet.png",
	&"overworld_decoration": "res://assets/tiles/roguelike/overworld_sheet.png",
	&"overworld_terrain_patches_3x3": "res://assets/tiles/roguelike/overworld_sheet.png",
	&"overworld_water_border_grass_3x3": "res://assets/tiles/roguelike/overworld_sheet.png",
	&"overworld_water_outer_corners": "res://assets/tiles/roguelike/overworld_sheet.png",
	&"city_terrain": "res://assets/tiles/roguelike/city_sheet.png",
	&"dungeon_terrain": "res://assets/tiles/roguelike/dungeon_sheet.png",
	&"dungeon_wall_autotile": "res://assets/tiles/roguelike/dungeon_sheet.png",
	&"dungeon_floor_decor": "res://assets/tiles/roguelike/dungeon_sheet.png",
	&"dungeon_entrance_pair": "res://assets/tiles/roguelike/dungeon_sheet.png",
	&"labyrinth_entrance_pair": "res://assets/tiles/roguelike/dungeon_sheet.png",
	&"labyrinth_terrain":       "res://assets/tiles/roguelike/dungeon_sheet.png",
	&"labyrinth_wall_autotile": "res://assets/tiles/roguelike/dungeon_sheet.png",
	&"labyrinth_floor_decor":   "res://assets/tiles/roguelike/dungeon_sheet.png",
	&"dungeon_doorframe": "res://assets/tiles/roguelike/dungeon_sheet.png",
	&"interior_terrain": "res://assets/tiles/roguelike/interior_sheet.png",
}

## Convenience aliases kept for any code that still references the old consts.
const OVERWORLD_PNG: String = "res://assets/tiles/roguelike/overworld_sheet.png"
const CITY_PNG: String      = "res://assets/tiles/roguelike/city_sheet.png"
const DUNGEON_PNG: String   = "res://assets/tiles/roguelike/dungeon_sheet.png"
const INTERIOR_PNG: String  = "res://assets/tiles/roguelike/interior_sheet.png"
const RUNES_BLACK_PNG: String = "res://assets/tiles/runes/runes_black_tile.png"
const RUNES_GREY_PNG: String  = "res://assets/tiles/runes/runes_grey_tile.png"
const RUNES_BLUE_PNG: String  = "res://assets/tiles/runes/runes_blue_tile.png"

## Cached sheet overrides from TileMappings. Populated by _ensure_loaded().
static var _sheet_overrides: Dictionary = {}

## Resolve the PNG path for a given mapping field, respecting user overrides.
static func get_sheet_path(field: StringName) -> String:
	_ensure_loaded()
	var override: Variant = _sheet_overrides.get(field, null)
	if override is String and not (override as String).is_empty():
		return override as String
	var default: Variant = _DEFAULT_SHEETS.get(field, null)
	if default is String:
		return default as String
	return OVERWORLD_PNG

## Resolve the sheet for a whole view (overworld/city/dungeon/interior).
## Picks from the primary field for that view.
static func _sheet_for_view(view: StringName) -> String:
	match view:
		&"overworld":
			return get_sheet_path(&"overworld_terrain")
		&"city":
			return get_sheet_path(&"city_terrain")
		&"dungeon":
			return get_sheet_path(&"dungeon_terrain")
		&"interior":
			return get_sheet_path(&"interior_terrain")
	return OVERWORLD_PNG

# ─── Custom-data layer names (added to every built TileSet) ─────────────
const CUSTOM_TERRAIN: String  = "terrain"     # StringName, e.g. &"grass"
const CUSTOM_WALKABLE: String = "walkable"    # bool

# ─── Canonical "filled center" cells, identified empirically ───────────
# All coordinates are (atlas_x, atlas_y) into the source sheet at TILE_PX
# size with a 1-px gutter (NO outer margin).

# Overworld base terrains (Roguelike Base sheet, 57×31 cells).
# Each value is `Array[Vector2i]`. Element [0] is the canonical filled-
# centre cell; subsequent elements are optional variants rolled in by
# `cell_for_variant()` at the per-terrain probability defined in
# `GROUND_VARIANT_CHANCE_BY_TERRAIN`. All variants must be 100% opaque so
# they can replace the canonical ground tile cleanly.
# Fallback defaults when the .tres is missing (fresh checkout).
const _DEFAULT_OVERWORLD_TERRAIN: Dictionary = {
	&"dirt":  [Vector2i(1, 26)],
	&"stone": [Vector2i(4, 26)],
	&"sand":  [Vector2i(7, 26)],
	&"grass": [
		Vector2i(10, 26),
		Vector2i(0, 6), Vector2i(1, 6), Vector2i(0, 7),
		Vector2i(0, 9), Vector2i(1, 9), Vector2i(0, 10),
	],
	&"clay":  [Vector2i(13, 26)],
	&"water": [
		Vector2i(0, 0),
		Vector2i(0, 1),
	],
	&"deep_water": [Vector2i(32, 26)],
	&"snow":  [Vector2i(45, 26)],
}
static var OVERWORLD_TERRAIN_CELLS: Dictionary = _DEFAULT_OVERWORLD_TERRAIN

# Overworld decoration cells. Some are collidable obstacles (trees/rocks),
# others are purely cosmetic single-tile sprites with transparent corners
# (flowers/lilypads) that overlay grass/water without blocking movement.
# Each value is an Array of (atlas_x, atlas_y) cell variants. The variant
# is chosen by the generator's `entry["variant"]` modulo arr.size().
const _DEFAULT_OVERWORLD_DECORATION: Dictionary = {
	&"tree":   [Vector2i(13, 9), Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9)],
	&"bush":   [Vector2i(20, 9), Vector2i(21, 9)],
	&"rock":   [Vector2i(7, 13), Vector2i(8, 13), Vector2i(9, 13)],
	&"iron_vein":   [Vector2i(10, 13), Vector2i(11, 13)],
	&"copper_vein": [Vector2i(12, 13)],
	&"flower":  [Vector2i(28, 9), Vector2i(29, 9), Vector2i(30, 9), Vector2i(31, 9)],
	&"lilypad": [Vector2i(28, 10)],
}
static var OVERWORLD_DECORATION_CELLS: Dictionary = _DEFAULT_OVERWORLD_DECORATION

# Default probability a given cell rolls into a registered variant.
# Kept low for grass so flower variants read as occasional accents, not
# wallpaper. Override per-terrain via GROUND_VARIANT_CHANCE_BY_TERRAIN.
const GROUND_VARIANT_CHANCE: float = 0.012
# Per-terrain override of the variant roll chance. Anything not listed
# falls back to GROUND_VARIANT_CHANCE.
const GROUND_VARIANT_CHANCE_BY_TERRAIN: Dictionary = {
	&"water": 0.5,
}

# 3×3 corner/edge patch sets for terrains that have a "rounded outlined
# patch" stamp in the Roguelike sheet. Painted on the Patch TileMapLayer
# (above Ground, below Decoration) to add blended edges where a secondary
# terrain (e.g. dirt blob) sits on a primary (e.g. grass / sand). The
# corners + edges of these tiles have transparent OUTER pixels so the
# underlying Ground tile shows through and the patch reads as a soft
# rounded shape rather than a hard square.
#
# Cell order is row-major NW, N, NE, W, C, E, SW, S, SE — see
# `_patch_index_for_neighbors` in world_root.gd for the mapping.
const _DEFAULT_OVERWORLD_PATCH_3X3: Dictionary = {
	&"dirt": [
		Vector2i(0, 25), Vector2i(1, 25), Vector2i(2, 25),
		Vector2i(0, 26), Vector2i(1, 26), Vector2i(2, 26),
		Vector2i(0, 27), Vector2i(1, 27), Vector2i(2, 27),
	],
	&"stone": [
		Vector2i(3, 25), Vector2i(4, 25), Vector2i(5, 25),
		Vector2i(3, 26), Vector2i(4, 26), Vector2i(5, 26),
		Vector2i(3, 27), Vector2i(4, 27), Vector2i(5, 27),
	],
	&"sand": [
		Vector2i(6, 25), Vector2i(7, 25), Vector2i(8, 25),
		Vector2i(6, 26), Vector2i(7, 26), Vector2i(8, 26),
		Vector2i(6, 27), Vector2i(7, 27), Vector2i(8, 27),
	],
	&"clay": [
		Vector2i(12, 25), Vector2i(13, 25), Vector2i(14, 25),
		Vector2i(12, 26), Vector2i(13, 26), Vector2i(14, 26),
		Vector2i(12, 27), Vector2i(13, 27), Vector2i(14, 27),
	],
}
static var OVERWORLD_TERRAIN_PATCH_3X3: Dictionary = _DEFAULT_OVERWORLD_PATCH_3X3

# 3×3 corner/edge tiles that paint a curved water-on-grass boundary.
# Unlike `OVERWORLD_TERRAIN_PATCH_3X3`, these tiles are FULLY OPAQUE: the
# NW corner tile has grass in its NW portion and water curving into the
# SE; the N edge tile has a grass strip across the top and water below;
# the centre is plain water. So they REPLACE the ground tile of a water
# cell that borders grass (rather than overlay on a separate Patch layer
# with transparent corners).
#
# Cell order: NW, N, NE, W, C, E, SW, S, SE — same mapping as the patch
# helper so we can reuse `_patch_index_for_neighbors`.
const _DEFAULT_WATER_BORDER_3X3: Array = [
	Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
	Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
]
static var OVERWORLD_WATER_BORDER_GRASS_3X3: Array = _DEFAULT_WATER_BORDER_3X3

# Convex / outer corner tiles for water cells that touch grass only on a
# diagonal (i.e. all four orthogonal neighbours are still water, so the
# 3×3 border set above doesn't fire). Each tile is mostly water with a
# small brown / sand corner speck in one of its four corners. Painted on
# the Ground layer in place of the plain water tile.
#
# Keys are the diagonal direction (dx, dy) of the grass cell relative to
# the water cell. Values are atlas cells in the overworld sheet.
const _DEFAULT_WATER_OUTER_CORNERS: Dictionary = {
	Vector2i(-1, -1): Vector2i(1, 2),
	Vector2i( 1, -1): Vector2i(0, 2),
	Vector2i(-1,  1): Vector2i(1, 1),
	Vector2i( 1,  1): Vector2i(0, 1),
}
static var OVERWORLD_WATER_OUTER_CORNERS: Dictionary = _DEFAULT_WATER_OUTER_CORNERS

# City sheet: roads, sidewalks, building exteriors.
# Same `Array[Vector2i]` schema as `OVERWORLD_TERRAIN_CELLS`.
const _DEFAULT_CITY_TERRAIN: Dictionary = {
	&"road":     [Vector2i(7, 19)],
	&"sidewalk": [Vector2i(15, 1)],
	&"grass":    [Vector2i(35, 27)],
	&"water":    [Vector2i(33, 1)],
}
static var CITY_TERRAIN_CELLS: Dictionary = _DEFAULT_CITY_TERRAIN

# Dungeon sheet: cave floor + cave wall autotile.
#
# Cave floor uses the centre tile (9, 7). Walls use a 9-slice autotile
# whose appearance depends on which neighbouring cells are floor:
#   - vertical wall edges: (8, 7) left, (10, 7) right
#   - bottom row (wall meets floor BELOW): (9, 9) (10, 9) (11, 9)
#   - top row    (wall meets floor ABOVE): the bottom-row tiles flipped
#                                          vertically
# Wall cells with no adjacent floor are "dead space" — painted as a
# darkened (9, 7) on a separate dim TileMapLayer at runtime.
# Floor cells additionally get a 10% chance of one decorative overlay
# tile from `DUNGEON_FLOOR_DECOR_CELLS`.
const _DEFAULT_DUNGEON_TERRAIN: Dictionary = {
	&"floor": [Vector2i(9, 7)],
	&"wall":  [
		Vector2i(8, 7), Vector2i(10, 7),
		Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9),
	],
	&"door":  [Vector2i(2, 8)],
	&"water": [Vector2i(2, 12)],
}
static var DUNGEON_TERRAIN_CELLS: Dictionary = _DEFAULT_DUNGEON_TERRAIN

# Wall autotile lookup. Key is a 4-bit floor-neighbour mask:
#   bit 3 (8) = floor to north
#   bit 2 (4) = floor to south
#   bit 1 (2) = floor to east
#   bit 0 (1) = floor to west
# Value is `[atlas_cell, flip_v, flip_h]`.
# `flip_v` is true when the tile must be flipped vertically (top-of-wall).
# `flip_h` is true when the tile must be flipped horizontally (mirrored E/W).
# Mask 0 (no floor neighbour) is omitted — dead space rendered separately.
const _DEFAULT_DUNGEON_WALL_AUTOTILE: Dictionary = {
	2:  [Vector2i(8, 7),  false, false],
	1:  [Vector2i(10, 7), false, false],
	8:  [Vector2i(9, 9),  false, false],
	10: [Vector2i(8, 9),  false, false],
	9:  [Vector2i(10, 9), false, false],
	11: [Vector2i(9, 9),  false, false],
	4:  [Vector2i(9, 9),  true,  false],
	6:  [Vector2i(8, 9),  true,  false],
	5:  [Vector2i(10, 9), true,  false],
	7:  [Vector2i(9, 9),  true,  false],
	3:  [Vector2i(9, 9),  false, false],
	12: [Vector2i(9, 9),  false, false],
	13: [Vector2i(10, 7), false, false],
	14: [Vector2i(8, 7),  false, false],
	15: [Vector2i(9, 9),  false, false],
}
static var DUNGEON_WALL_AUTOTILE: Dictionary = _DEFAULT_DUNGEON_WALL_AUTOTILE

# Decorative floor overlay tiles. Painted on the decoration layer over a
# (9, 7) floor cell at ~10% chance. Range covers atlas cells (12, 10)
# through (13, 14) — 2 columns × 5 rows = 10 unique tiles.
const _DEFAULT_DUNGEON_FLOOR_DECOR: Array = [
	Vector2i(12, 10), Vector2i(13, 10),
	Vector2i(12, 11), Vector2i(13, 11),
	Vector2i(12, 12), Vector2i(13, 12),
	Vector2i(12, 13), Vector2i(13, 13),
	Vector2i(12, 14), Vector2i(13, 14),
]
static var DUNGEON_FLOOR_DECOR_CELLS: Array = _DEFAULT_DUNGEON_FLOOR_DECOR

## 3×3 border cells for dungeon floors (NW…SE, index 4 = open centre).
## All default to the plain floor cell until TileMappings overrides them.
const _DEFAULT_DUNGEON_FLOOR_BORDER: Array = [
	Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),
	Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),
	Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),
]
static var DUNGEON_FLOOR_BORDER_3X3: Array = _DEFAULT_DUNGEON_FLOOR_BORDER

## Same as DUNGEON_FLOOR_BORDER_3X3 for labyrinth.
const _DEFAULT_LABYRINTH_FLOOR_BORDER: Array = [
	Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),
	Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),
	Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),
]
static var LABYRINTH_FLOOR_BORDER_3X3: Array = _DEFAULT_LABYRINTH_FLOOR_BORDER

# Cave entrance marker on the overworld. Two side-by-side dungeon-sheet
# tiles (anchor cell + cell to the east) drawn on a Sprite-based marker.
const _DEFAULT_DUNGEON_ENTRANCE: Array = [
	Vector2i(24, 4), Vector2i(25, 4),
]
static var DUNGEON_OVERWORLD_ENTRANCE_CELLS: Array = _DEFAULT_DUNGEON_ENTRANCE

## Labyrinth entrance marker — default reuses dungeon entrance cells.
## SpritePicker can override to distinct tiles.
const _DEFAULT_LABYRINTH_ENTRANCE: Array = [
	Vector2i(24, 4), Vector2i(25, 4),
]
static var LABYRINTH_OVERWORLD_ENTRANCE_CELLS: Array = _DEFAULT_LABYRINTH_ENTRANCE

# Labyrinth interior terrain. Only &"floor" is used by the painting path.
# (&"door" and &"water" are never emitted by LabyrinthGenerator, so they
# are intentionally omitted here.)
const _DEFAULT_LABYRINTH_TERRAIN: Dictionary = {
	&"floor": [Vector2i(9, 7)],
}
static var LABYRINTH_TERRAIN_CELLS: Dictionary = _DEFAULT_LABYRINTH_TERRAIN

const _DEFAULT_LABYRINTH_WALL_AUTOTILE: Dictionary = {
	2:  [Vector2i(8, 7),  false, false],
	1:  [Vector2i(10, 7), false, false],
	8:  [Vector2i(9, 9),  false, false],
	10: [Vector2i(8, 9),  false, false],
	9:  [Vector2i(10, 9), false, false],
	11: [Vector2i(9, 9),  false, false],
	4:  [Vector2i(9, 9),  true,  false],
	6:  [Vector2i(8, 9),  true,  false],
	5:  [Vector2i(10, 9), true,  false],
	7:  [Vector2i(9, 9),  true,  false],
	3:  [Vector2i(9, 9),  false, false],
	12: [Vector2i(9, 9),  false, false],
	13: [Vector2i(10, 7), false, false],
	14: [Vector2i(8, 7),  false, false],
	15: [Vector2i(9, 9),  false, false],
}
static var LABYRINTH_WALL_AUTOTILE: Dictionary = _DEFAULT_LABYRINTH_WALL_AUTOTILE

const _DEFAULT_LABYRINTH_FLOOR_DECOR: Array = [
	Vector2i(12, 10), Vector2i(13, 10),
	Vector2i(12, 11), Vector2i(13, 11),
	Vector2i(12, 12), Vector2i(13, 12),
	Vector2i(12, 13), Vector2i(13, 13),
	Vector2i(12, 14), Vector2i(13, 14),
]
static var LABYRINTH_FLOOR_DECOR_CELLS: Array = _DEFAULT_LABYRINTH_FLOOR_DECOR

## Treasure chest sprite cells on the dungeon sheet: [closed, open].
## TreasureChest reads index 0 for closed state, index 1 for open state.
const _DEFAULT_LABYRINTH_CHEST: Array = [Vector2i(2, 10), Vector2i(3, 10)]
static var LABYRINTH_CHEST_CELLS: Array = _DEFAULT_LABYRINTH_CHEST

# Wooden doorframe drawn at the south end of a north-south cave corridor
# where it opens into a room. Purely decorative — placed as Sprite2D
# children, so they do not affect walkability or terrain queries.
#
# Layout (anchored at the corridor exit row, west_col = corridor_west - 1,
# east_col = corridor_east + 1):
#   y=row     : TL  top×N  TR             ← the lintel
#   y=row+1   : LW          RW            ← side jambs (top half)
#   y=row+2   : LW2         RW2           ← side jambs (bottom half)
const _DEFAULT_DUNGEON_DOORFRAME: Dictionary = {
	&"TL":  Vector2i(5, 8),
	&"TOP": Vector2i(6, 9),
	&"TR":  Vector2i(8, 9),
	&"LW":  Vector2i(5, 9),
	&"LW2": Vector2i(5, 10),
	&"RW":  Vector2i(8, 10),
	&"RW2": Vector2i(8, 11),
}
static var DUNGEON_DOORFRAME: Dictionary = _DEFAULT_DUNGEON_DOORFRAME

## Legacy accessors for doorframe slots — reads from the loaded dict.
static var DUNGEON_DOORFRAME_TL:  Vector2i:
	get: return DUNGEON_DOORFRAME.get(&"TL", Vector2i(5, 8))
static var DUNGEON_DOORFRAME_TOP: Vector2i:
	get: return DUNGEON_DOORFRAME.get(&"TOP", Vector2i(6, 9))
static var DUNGEON_DOORFRAME_TR:  Vector2i:
	get: return DUNGEON_DOORFRAME.get(&"TR", Vector2i(8, 9))
static var DUNGEON_DOORFRAME_LW:  Vector2i:
	get: return DUNGEON_DOORFRAME.get(&"LW", Vector2i(5, 9))
static var DUNGEON_DOORFRAME_LW2: Vector2i:
	get: return DUNGEON_DOORFRAME.get(&"LW2", Vector2i(5, 10))
static var DUNGEON_DOORFRAME_RW:  Vector2i:
	get: return DUNGEON_DOORFRAME.get(&"RW", Vector2i(8, 10))
static var DUNGEON_DOORFRAME_RW2: Vector2i:
	get: return DUNGEON_DOORFRAME.get(&"RW2", Vector2i(8, 11))

# Interior sheet: wood floor, wood wall.
# Same `Array[Vector2i]` schema as `OVERWORLD_TERRAIN_CELLS`.
const _DEFAULT_INTERIOR_TERRAIN: Dictionary = {
	&"floor": [Vector2i(5, 13)],
	&"wall":  [Vector2i(5, 1)],
	&"door":  [Vector2i(20, 9)],
}
static var INTERIOR_TERRAIN_CELLS: Dictionary = _DEFAULT_INTERIOR_TERRAIN

# ─── Walkability rules (used by generators + collision) ────────────────
const WALKABLE: Dictionary = {
	# overworld
	&"grass": true, &"dirt": true, &"sand": true, &"stone": true,
	&"clay":  true, &"snow": true,
	&"water": false, &"deep_water": false,
	# city
	&"road": true, &"sidewalk": true,
	# dungeon / interior
	&"floor": true, &"wall": false, &"door": true,
}

# ─── .tres loading ──────────────────────────────────────────────────────
const _TRES_PATH: String = "res://resources/tilesets/tile_mappings.tres"
static var _loaded: bool = false

## Load cell coordinates from the .tres resource, replacing the hardcoded
## defaults. Called lazily on first access to any TileSet or cell_for*().
static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var res: Resource = load(_TRES_PATH)
	if res == null:
		push_warning("TilesetCatalog: %s not found, using built-in defaults" % _TRES_PATH)
		return
	var m: TileMappings = res as TileMappings
	if m == null:
		push_warning("TilesetCatalog: %s is not a TileMappings resource" % _TRES_PATH)
		return
	# Overworld
	if not m.overworld_terrain.is_empty():
		OVERWORLD_TERRAIN_CELLS = m.overworld_terrain
	if not m.overworld_decoration.is_empty():
		OVERWORLD_DECORATION_CELLS = m.overworld_decoration
	# Merge mineable resource sprites from MineableRegistry on top of
	# TileMappings decorations. Mineables take priority; non-mineable
	# decorations (flower, lilypad) stay from TileMappings.
	var mineable_cells: Dictionary = MineableRegistry.build_decoration_cells()
	for rid in mineable_cells:
		var arr: Array = mineable_cells[rid]
		if not arr.is_empty():
			OVERWORLD_DECORATION_CELLS[rid] = arr
	if not m.overworld_terrain_patches_3x3.is_empty():
		OVERWORLD_TERRAIN_PATCH_3X3 = m.overworld_terrain_patches_3x3
	if not m.overworld_water_border_grass_3x3.is_empty():
		OVERWORLD_WATER_BORDER_GRASS_3X3 = m.overworld_water_border_grass_3x3
	if not m.overworld_water_outer_corners.is_empty():
		OVERWORLD_WATER_OUTER_CORNERS = m.overworld_water_outer_corners
	# City
	if not m.city_terrain.is_empty():
		CITY_TERRAIN_CELLS = m.city_terrain
	# Dungeon
	if not m.dungeon_terrain.is_empty():
		DUNGEON_TERRAIN_CELLS = m.dungeon_terrain
	var autotile: Dictionary = m.build_dungeon_wall_autotile_dict()
	if not autotile.is_empty():
		DUNGEON_WALL_AUTOTILE = autotile
	if not m.dungeon_floor_decor.is_empty():
		DUNGEON_FLOOR_DECOR_CELLS = m.dungeon_floor_decor
	if not m.dungeon_entrance_pair.is_empty():
		DUNGEON_OVERWORLD_ENTRANCE_CELLS = m.dungeon_entrance_pair
	if not m.labyrinth_entrance_pair.is_empty():
		LABYRINTH_OVERWORLD_ENTRANCE_CELLS = m.labyrinth_entrance_pair
	# Labyrinth terrain
	if not m.labyrinth_terrain.is_empty():
		LABYRINTH_TERRAIN_CELLS = m.labyrinth_terrain
	var lab_autotile: Dictionary = m.build_labyrinth_wall_autotile_dict()
	if not lab_autotile.is_empty():
		LABYRINTH_WALL_AUTOTILE = lab_autotile
	if not m.labyrinth_floor_decor.is_empty():
		LABYRINTH_FLOOR_DECOR_CELLS = m.labyrinth_floor_decor
	if m.labyrinth_chest_pair.size() >= 2:
		LABYRINTH_CHEST_CELLS = m.labyrinth_chest_pair
	# Exact 9 required — partial arrays would mis-index the NW…SE lookup.
	if m.dungeon_floor_border_3x3.size() == 9:
		DUNGEON_FLOOR_BORDER_3X3 = m.dungeon_floor_border_3x3
	if m.labyrinth_floor_border_3x3.size() == 9:
		LABYRINTH_FLOOR_BORDER_3X3 = m.labyrinth_floor_border_3x3
	if not m.dungeon_doorframe.is_empty():
		DUNGEON_DOORFRAME = m.dungeon_doorframe
	# Interior
	if not m.interior_terrain.is_empty():
		INTERIOR_TERRAIN_CELLS = m.interior_terrain
	# Sheet overrides
	_sheet_overrides = m.sheet_overrides.duplicate()

# ─── Cached TileSets ────────────────────────────────────────────────────
static var _overworld_ts: TileSet = null
static var _city_ts: TileSet = null
static var _dungeon_ts: TileSet = null
static var _labyrinth_ts: TileSet = null
static var _interior_ts: TileSet = null
static var _runes_ts: TileSet = null


static func overworld() -> TileSet:
	_ensure_loaded()
	if _overworld_ts == null:
		var sheet := _sheet_for_view(&"overworld")
		_overworld_ts = _build(sheet, OVERWORLD_TERRAIN_CELLS, false,
				SheetSpecReader.read(sheet))
	return _overworld_ts


static func city() -> TileSet:
	_ensure_loaded()
	if _city_ts == null:
		var sheet := _sheet_for_view(&"city")
		_city_ts = _build(sheet, CITY_TERRAIN_CELLS, false,
				SheetSpecReader.read(sheet))
	return _city_ts


static func dungeon() -> TileSet:
	_ensure_loaded()
	if _dungeon_ts == null:
		var sheet := _sheet_for_view(&"dungeon")
		_dungeon_ts = _build(sheet, DUNGEON_TERRAIN_CELLS, true,
				SheetSpecReader.read(sheet))
	return _dungeon_ts


static func labyrinth() -> TileSet:
	_ensure_loaded()
	if _labyrinth_ts == null:
		var sheet := get_sheet_path(&"labyrinth_terrain")
		_labyrinth_ts = _build(sheet, LABYRINTH_TERRAIN_CELLS, true,
				SheetSpecReader.read(sheet))
	return _labyrinth_ts


static func interior() -> TileSet:
	_ensure_loaded()
	if _interior_ts == null:
		var sheet := _sheet_for_view(&"interior")
		_interior_ts = _build(sheet, INTERIOR_TERRAIN_CELLS, false,
				SheetSpecReader.read(sheet))
	return _interior_ts


## Returns the rune overlay TileSet (uses 3 atlases — one per color).
static func runes() -> TileSet:
	if _runes_ts == null:
		_runes_ts = _build_runes()
	return _runes_ts


## Returns the scale factor a TileMapLayer should use for the given sheet path.
## 1.0 for standard 16 px sheets (no-op); 0.25 for 64 px sheets, etc.
static func scale_for_sheet(sheet_path: String) -> float:
	return SheetSpecReader.read(sheet_path).scale_factor()


# ─── Builders ──────────────────────────────────────────────────────────

static func _build(png_path: String, terrain_cells: Dictionary,
		is_dungeon: bool = false, spec: SheetSpec = null) -> TileSet:
	if spec == null:
		spec = SheetSpec.new()
	var tex: Texture2D = load(png_path) as Texture2D
	if tex == null:
		push_error("TilesetCatalog: missing texture %s" % png_path)
		return TileSet.new()

	var ts := TileSet.new()
	ts.tile_size = Vector2i(spec.tile_px, spec.tile_px)
	# Two custom data layers: terrain (StringName) + walkable (bool).
	ts.add_custom_data_layer(0)
	ts.set_custom_data_layer_name(0, CUSTOM_TERRAIN)
	ts.set_custom_data_layer_type(0, TYPE_STRING_NAME)
	ts.add_custom_data_layer(1)
	ts.set_custom_data_layer_name(1, CUSTOM_WALKABLE)
	ts.set_custom_data_layer_type(1, TYPE_BOOL)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(spec.tile_px, spec.tile_px)
	src.margins = Vector2i(0, 0)
	src.separation = Vector2i(spec.margin_px, spec.margin_px)
	# IMPORTANT: source must be added to the TileSet BEFORE creating tiles
	# in it, otherwise `TileData.set_custom_data` errors with "tile_set is null".
	ts.add_source(src, 0)

	var cols: int = (tex.get_width() + spec.margin_px) / spec.stride
	var rows: int = (tex.get_height() + spec.margin_px) / spec.stride

	# Reverse-lookup: cell -> terrain name (so we can stamp custom data).
	# Terrain values are `Array[Vector2i]` (canonical first, then variants);
	# a bare `Vector2i` is also accepted as a defensive fallback for any
	# legacy callers that haven't been migrated yet.
	var cell_to_terrain: Dictionary = {}
	for terrain_name in terrain_cells.keys():
		var v = terrain_cells[terrain_name]
		if v is Vector2i:
			cell_to_terrain[v] = terrain_name
		elif v is Array:
			for cell in v:
				cell_to_terrain[cell] = terrain_name
	# 3×3 patch corner/edge cells likewise inherit their parent terrain so
	# painting them on the Patch layer doesn't accidentally alter
	# walkability or terrain queries on cells where they overlay primary
	# Ground tiles.
	for terrain_name in OVERWORLD_TERRAIN_PATCH_3X3.keys():
		if not terrain_cells.has(terrain_name):
			continue
		for cell in OVERWORLD_TERRAIN_PATCH_3X3[terrain_name]:
			cell_to_terrain[cell] = terrain_name
	# Water-grass border tiles: the centre + edge cells are mostly water,
	# corners are mostly grass — but we register them all as `water` so
	# walkability matches a normal water tile (boats only). The slight
	# grass overhang in corner tiles is purely cosmetic.
	for cell in OVERWORLD_WATER_BORDER_GRASS_3X3:
		cell_to_terrain[cell] = &"water"
	# Convex outer corners are also tagged as water so walkability + terrain
	# queries match a normal water tile.
	for cell in OVERWORLD_WATER_OUTER_CORNERS.values():
		cell_to_terrain[cell] = &"water"
	# Dungeon-only: the floor-decoration tiles share `floor` walkability so
	# they don't accidentally block the player when stamped on the
	# decoration layer over a (10,6) floor cell.
	if is_dungeon:
		for cell in DUNGEON_FLOOR_DECOR_CELLS:
			cell_to_terrain[cell] = &"floor"

	# Register every cell as a tile.
	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			src.create_tile(cell)
			var data: TileData = src.get_tile_data(cell, 0)
			if data == null:
				continue
			var terrain_name: StringName = cell_to_terrain.get(cell, &"")
			data.set_custom_data(CUSTOM_TERRAIN, terrain_name)
			data.set_custom_data(CUSTOM_WALKABLE, WALKABLE.get(terrain_name, true))

	# Mark decoration atlas cells used by mineables as non-walkable so
	# is_walkable() correctly blocks on tree trunks, rocks, etc.
	if not is_dungeon:
		var obstacle_cells: Dictionary = {}  # Vector2i → true
		for rid in MineableRegistry.all_ids():
			var sprites: Array = _get_mineable_sprites(rid)
			var sz: Vector2i = MineableRegistry.get_tile_size(rid)
			var mask: Array = MineableRegistry.get_walkable_mask(rid)
			for s in sprites:
				# s is the top-left anchor of the NxM block.
				for dy in sz.y:
					for dx in sz.x:
						var mi: int = dy * sz.x + dx
						var blocks: bool = mask[mi] if mi < mask.size() else (dy == sz.y - 1)
						if blocks:
							obstacle_cells[s + Vector2i(dx, dy)] = true
		for cell in obstacle_cells:
			if cell_to_terrain.has(cell):
				continue  # Don't override explicitly-tagged terrain tiles (e.g. door).
			var data: TileData = src.get_tile_data(cell, 0)
			if data != null:
				data.set_custom_data(CUSTOM_WALKABLE, false)

	# Dungeon-only: pre-create vertically flipped alternatives for the
	# bottom-row wall tiles so the autotile painter can stamp top-of-wall
	# pieces by passing the FLIP_V alternative ID to `set_cell()`.
	if is_dungeon:
		for cell in [Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9)]:
			src.create_alternative_tile(cell,
				TileSetAtlasSource.TRANSFORM_FLIP_V)
			var alt_data: TileData = src.get_tile_data(cell,
				TileSetAtlasSource.TRANSFORM_FLIP_V)
			if alt_data != null:
				alt_data.set_custom_data(CUSTOM_TERRAIN, &"wall")
				alt_data.set_custom_data(CUSTOM_WALKABLE, false)

	return ts


## Helper: get the sprite anchor cells for a mineable as Vector2i array.
static func _get_mineable_sprites(rid: StringName) -> Array[Vector2i]:
	var entry: Variant = MineableRegistry.get_resource(rid)
	if entry == null:
		return []
	var sprites: Array = entry.get("sprites", [])
	var out: Array[Vector2i] = []
	for s in sprites:
		if s is Array and s.size() >= 2:
			out.append(Vector2i(int(s[0]), int(s[1])))
	return out


static func _build_runes() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(WorldConst.TILE_PX, WorldConst.TILE_PX)
	var paths: Array[String] = [RUNES_BLACK_PNG, RUNES_GREY_PNG, RUNES_BLUE_PNG]
	for i in paths.size():
		var tex: Texture2D = load(paths[i]) as Texture2D
		if tex == null:
			continue
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(WorldConst.TILE_PX, WorldConst.TILE_PX)
		src.margins = Vector2i(0, 0)
		src.separation = Vector2i(WorldConst.TILESHEET_MARGIN, WorldConst.TILESHEET_MARGIN)
		var cols: int = (tex.get_width() + WorldConst.TILESHEET_MARGIN) / (WorldConst.TILE_PX + WorldConst.TILESHEET_MARGIN)
		var rows: int = (tex.get_height() + WorldConst.TILESHEET_MARGIN) / (WorldConst.TILE_PX + WorldConst.TILESHEET_MARGIN)
		for y in rows:
			for x in cols:
				src.create_tile(Vector2i(x, y))
		ts.add_source(src, i)
	return ts


## Returns the canonical filled-center atlas cell for `terrain` in the
## given view, or `Vector2i(-1, -1)` if not registered. Reads element [0]
## of the per-terrain `Array[Vector2i]`; tolerates a bare `Vector2i` as a
## defensive fallback.
static func cell_for(view_kind: StringName, terrain: StringName) -> Vector2i:
	_ensure_loaded()
	var d: Dictionary
	match view_kind:
		&"overworld": d = OVERWORLD_TERRAIN_CELLS
		&"city": d = CITY_TERRAIN_CELLS
		&"dungeon": d = DUNGEON_TERRAIN_CELLS
		&"labyrinth": d = LABYRINTH_TERRAIN_CELLS
		&"interior", &"house": d = INTERIOR_TERRAIN_CELLS
		_: return Vector2i(-1, -1)
	var v: Variant = d.get(terrain, null)
	if v is Vector2i:
		return v
	if v is Array and not (v as Array).is_empty():
		return (v as Array)[0]
	return Vector2i(-1, -1)


## Returns a deterministic ground tile for `terrain` in `view_kind`. When
## the terrain's array has more than one entry and `hash32` rolls below
## the per-terrain variant chance, returns one of the variants (elements
## [1..]) chosen by `hash32`; otherwise returns the canonical element [0].
##
## `hash32` should be a stable per-cell hash (e.g. region.seed XOR cell
## coords) so reloads paint identical tiles.
static func cell_for_variant(view_kind: StringName, terrain: StringName, hash32: int) -> Vector2i:
	_ensure_loaded()
	var d: Dictionary
	match view_kind:
		&"overworld": d = OVERWORLD_TERRAIN_CELLS
		&"city": d = CITY_TERRAIN_CELLS
		&"dungeon": d = DUNGEON_TERRAIN_CELLS
		&"labyrinth": d = LABYRINTH_TERRAIN_CELLS
		&"interior", &"house": d = INTERIOR_TERRAIN_CELLS
		_: return Vector2i(-1, -1)
	var v: Variant = d.get(terrain, null)
	if v is Array and (v as Array).size() > 1:
		var arr: Array = v
		# Use the high bits to pick the variant index, low bits for the
		# variant-roll so the two decisions are independent.
		var u: int = hash32 & 0x7fffffff
		var roll: float = float(u % 1000) / 1000.0
		var chance: float = float(
			GROUND_VARIANT_CHANCE_BY_TERRAIN.get(terrain, GROUND_VARIANT_CHANCE))
		if roll < chance:
			var idx: int = (u >> 10) % (arr.size() - 1)
			return arr[1 + idx]
		return arr[0]
	if v is Array and not (v as Array).is_empty():
		return (v as Array)[0]
	if v is Vector2i:
		return v
	return Vector2i(-1, -1)


# ─── Multi-tile rendering helpers ───────────────────────────────────────

# Terrain kinds whose canonical tile occupies TWO vertical cells: a trunk
# (the painted cell, blocking + collidable) and a canopy (one cell above
# on the Decoration layer, walk-through). The canopy atlas cell is always
# the trunk atlas cell - Vector2i(0, 1) (i.e. one row up in the sheet).
const TALL_TILE_KINDS: Array = [&"door"]


## True if `terrain` should render as a two-cell stack (trunk + canopy
## above). See `TALL_TILE_KINDS`.
static func is_tall_tile(terrain: StringName) -> bool:
	return TALL_TILE_KINDS.has(terrain)


## Cached decoration size / walkable data from MineableRegistry.
static var _deco_size_cache: Dictionary = {}    ## StringName → Vector2i
static var _deco_mask_cache: Dictionary = {}    ## StringName → Array[bool]

static func _ensure_deco_cache() -> void:
	if not _deco_size_cache.is_empty():
		return
	for rid in MineableRegistry.all_ids():
		_deco_size_cache[rid] = MineableRegistry.get_tile_size(rid)
		_deco_mask_cache[rid] = MineableRegistry.get_walkable_mask(rid)

## Invalidate the decoration size/mask caches (call after editing mineables).
static func invalidate_deco_cache() -> void:
	_deco_size_cache.clear()
	_deco_mask_cache.clear()
	_tall_decoration_cache.clear()


## Return the tile footprint of a decoration kind (default 1×1).
static func get_decoration_size(kind: StringName) -> Vector2i:
	_ensure_deco_cache()
	return _deco_size_cache.get(kind, Vector2i(1, 1))


## Return the walkability bitmask for a decoration kind (row-major,
## true = blocks). Length = width × height.
static func get_decoration_walkable_mask(kind: StringName) -> Array:
	_ensure_deco_cache()
	return _deco_mask_cache.get(kind, [true])


## Decoration kinds that occupy more than one tile.
## Built from MineableRegistry + a hardcoded set for non-mineable tall
## decorations.
static var _tall_decoration_cache: Dictionary = {}

## True if a decoration `kind` should render as a multi-cell footprint.
static func is_tall_decoration(kind: StringName) -> bool:
	if _tall_decoration_cache.is_empty():
		_tall_decoration_cache = MineableRegistry.build_tall_kinds()
	return _tall_decoration_cache.get(kind, false)
