## TileMappings
##
## Resource that owns every editable atlas-cell mapping for world / city /
## dungeon / interior rendering. Serves as the single source of truth that
## [TilesetCatalog] reads from at runtime, replacing the old in-source
## `const` tables. Persists as `res://resources/tilesets/tile_mappings.tres`
## and is editable by the Game Editor dev tool.
##
## Design notes:
##   - Typed `Array[Vector2i]` is used wherever Godot supports it; nested
##     dictionaries fall back to plain `Dictionary` with documented value
##     types since GDScript 4.3 has limited typed-dict support.
##   - The dungeon wall autotile is stored as a flat `Array[Dictionary]`
##     of `{mask:int, cell:Vector2i, flip:int}` (instead of the runtime
##     `Dictionary[int → [Vector2i, bool]]`) because typed exports don't
##     handle the nested-array shape cleanly. [TilesetCatalog] rebuilds
##     the dict on load.
##   - `default_mappings()` returns a fresh instance populated with the
##     historical constants, so any consumer that fails to load the
##     `.tres` (e.g. fresh checkout, missing file) still renders correctly.
class_name TileMappings
extends Resource

# ─── Overworld ──────────────────────────────────────────────────────────

## Per-terrain ordered cell list. Element [0] is the canonical filled-
## centre cell (used for tagging + as the default by [TilesetCatalog.cell_for]);
## subsequent elements are optional variants rolled in by
## [TilesetCatalog.cell_for_variant] at the per-terrain chance defined in
## [TilesetCatalog.GROUND_VARIANT_CHANCE_BY_TERRAIN].
## `StringName → Array[Vector2i]` (length ≥ 1).
@export var overworld_terrain: Dictionary = {}

## Decoration kind → ordered variant list. The painter picks an index by
## `entry["variant"] % arr.size()` so order matters for determinism.
## `StringName → Array[Vector2i]`.
@export var overworld_decoration: Dictionary = {}

## 3×3 patch sets for blended terrain edges. Each value is exactly 9 cells
## in row-major NW, N, NE, W, C, E, SW, S, SE order.
## `StringName → Array[Vector2i]` (length 9).
@export var overworld_terrain_patches_3x3: Dictionary = {}

## Fully-opaque 3×3 water-on-grass border tiles (centre = plain water,
## corners curve grass into water). Same NW…SE ordering. Length 9.
@export var overworld_water_border_grass_3x3: Array[Vector2i] = []

## Convex water-corner tiles for diagonal grass neighbours.
## `Vector2i offset → Vector2i cell`. Offsets are diagonal deltas
## ((-1,-1), (1,-1), (-1,1), (1,1)) from the water cell to the grass cell.
@export var overworld_water_outer_corners: Dictionary = {}

# ─── City ───────────────────────────────────────────────────────────────

## Per-terrain cell list (same schema as `overworld_terrain`).
## `StringName → Array[Vector2i]`.
@export var city_terrain: Dictionary = {}

# ─── Dungeon ────────────────────────────────────────────────────────────

## Single-cell dungeon terrains (floor / door / water).
## `StringName → Array[Vector2i]` (element [0] is canonical).
@export var dungeon_terrain: Dictionary = {}

## Wall autotile lookup as a flat list. Each entry is a `Dictionary` with:
##   - `mask`: `int` (4-bit floor-neighbour mask: N=8, S=4, E=2, W=1)
##   - `cell`: `Vector2i`
##   - `flip`: `int` (0 = no flip, 1 = vertical flip — used for top-of-wall)
@export var dungeon_wall_autotile: Array[Dictionary] = []

## Decorative floor overlay cells (random ~10% on floor tiles).
@export var dungeon_floor_decor: Array[Vector2i] = []

## Two side-by-side cells for the cave-mouth marker on the overworld.
## Length 2, ordered [west, east].
@export var dungeon_entrance_pair: Array[Vector2i] = []

## Two side-by-side labyrinth entrance marker tiles on the dungeon sheet.
## Painted on the overworld to mark labyrinth entrances with a tint.
@export var labyrinth_entrance_pair: Array[Vector2i] = []

## Single-cell labyrinth terrains (floor / door / water).
## `StringName → Array[Vector2i]` (element [0] is canonical).
## Defaults to dungeon tiles until overridden via the Game Editor.
@export var labyrinth_terrain: Dictionary = {}

## Wall autotile lookup for the labyrinth (same schema as dungeon_wall_autotile).
@export var labyrinth_wall_autotile: Array[Dictionary] = []

## Decorative floor overlay cells for the labyrinth (~10% on floor tiles).
@export var labyrinth_floor_decor: Array[Vector2i] = []

## Wooden doorframe cells for dungeon corridor exits, addressed by named
## slot. Slots: `&"TL"`, `&"TOP"`, `&"TR"`, `&"LW"`, `&"LW2"`, `&"RW"`,
## `&"RW2"`. `StringName → Vector2i`.
@export var dungeon_doorframe: Dictionary = {}

# ─── Interior ───────────────────────────────────────────────────────────

## `StringName → Array[Vector2i]` (element [0] is canonical).
@export var interior_terrain: Dictionary = {}

# ─── Character / weapon sprites ─────────────────────────────────────────

# ─── Sheet overrides ────────────────────────────────────────────────────

## Optional per-field sheet-path overrides. When a mapping field (e.g.
## `&"city_terrain"`) needs to pull cells from a different PNG than the
## historical default, store the mapping here: `StringName → String`.
## The Game Editor sheet selector writes this; TilesetCatalog reads it.
## Missing keys fall back to the built-in default sheet.
@export var sheet_overrides: Dictionary = {}


## Returns a fresh `TileMappings` populated with the historical default
## values that previously lived as `const` tables in [TilesetCatalog].
## Used (a) to seed the on-disk `.tres` and (b) as a fallback when the
## `.tres` is missing so a fresh checkout still renders.
static func default_mappings() -> TileMappings:
	var m := TileMappings.new()

	m.overworld_terrain = {
		&"dirt":  [Vector2i(1, 26)],
		&"stone": [Vector2i(4, 26)],
		&"sand":  [Vector2i(7, 26)],
		&"grass": [
			Vector2i(10, 26),                                 # canonical
			Vector2i(0, 6), Vector2i(1, 6), Vector2i(0, 7),   # variants
			Vector2i(0, 9), Vector2i(1, 9), Vector2i(0, 10),
		],
		&"clay":  [Vector2i(13, 26)],
		&"water": [
			Vector2i(0, 0),                                   # canonical
			Vector2i(0, 1),                                   # variant
		],
		&"deep_water": [Vector2i(32, 26)],
		&"snow":  [Vector2i(45, 26)],
	}

	m.overworld_decoration = {
		&"tree":   [Vector2i(13, 9), Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9)],
		&"bush":   [Vector2i(20, 9), Vector2i(21, 9)],
		&"rock":   [Vector2i(7, 13), Vector2i(8, 13), Vector2i(9, 13)],
		&"iron_vein":   [Vector2i(10, 13), Vector2i(11, 13)],
		&"copper_vein": [Vector2i(12, 13)],
		&"gold_vein":   [],
		&"flower":  [Vector2i(28, 9), Vector2i(29, 9), Vector2i(30, 9), Vector2i(31, 9)],
		&"lilypad": [Vector2i(28, 10)],
	}

	m.overworld_terrain_patches_3x3 = {
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
		&"grass": [
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
		],
		&"snow": [
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
		],
	}

	m.overworld_water_border_grass_3x3 = [
		Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	]

	m.overworld_water_outer_corners = {
		Vector2i(-1, -1): Vector2i(1, 2),
		Vector2i( 1, -1): Vector2i(0, 2),
		Vector2i(-1,  1): Vector2i(1, 1),
		Vector2i( 1,  1): Vector2i(0, 1),
	}

	m.city_terrain = {
		&"road":     [Vector2i(7, 19)],
		&"sidewalk": [Vector2i(15, 1)],
		&"grass":    [Vector2i(35, 27)],
		&"water":    [Vector2i(33, 1)],
	}

	m.dungeon_terrain = {
		&"floor": [Vector2i(9, 7)],
		&"door":  [Vector2i(2, 8)],
		&"water": [Vector2i(2, 12)],
	}

	m.dungeon_wall_autotile = [
		{"mask": 2,  "cell": Vector2i(8, 7),  "flip": 0},
		{"mask": 1,  "cell": Vector2i(10, 7), "flip": 0},
		{"mask": 8,  "cell": Vector2i(9, 9),  "flip": 0},
		{"mask": 10, "cell": Vector2i(8, 9),  "flip": 0},
		{"mask": 9,  "cell": Vector2i(10, 9), "flip": 0},
		{"mask": 11, "cell": Vector2i(9, 9),  "flip": 0},
		{"mask": 4,  "cell": Vector2i(9, 9),  "flip": 1},
		{"mask": 6,  "cell": Vector2i(8, 9),  "flip": 1},
		{"mask": 5,  "cell": Vector2i(10, 9), "flip": 1},
		{"mask": 7,  "cell": Vector2i(9, 9),  "flip": 1},
		{"mask": 3,  "cell": Vector2i(9, 9),  "flip": 0},
		{"mask": 12, "cell": Vector2i(9, 9),  "flip": 0},
		{"mask": 13, "cell": Vector2i(10, 7), "flip": 0},
		{"mask": 14, "cell": Vector2i(8, 7),  "flip": 0},
		{"mask": 15, "cell": Vector2i(9, 9),  "flip": 0},
	]

	m.dungeon_floor_decor = [
		Vector2i(12, 10), Vector2i(13, 10),
		Vector2i(12, 11), Vector2i(13, 11),
		Vector2i(12, 12), Vector2i(13, 12),
		Vector2i(12, 13), Vector2i(13, 13),
		Vector2i(12, 14), Vector2i(13, 14),
	]

	m.dungeon_entrance_pair = [Vector2i(24, 4), Vector2i(25, 4)]

	# Labyrinth terrain defaults — same tiles as dungeon until the user
	# overrides them in the Game Editor → Labyrinth sections.
	m.labyrinth_terrain = {
		&"floor": [Vector2i(9, 7)],
		&"door":  [Vector2i(2, 8)],
		&"water": [Vector2i(2, 12)],
	}

	m.labyrinth_wall_autotile = [
		{"mask": 2,  "cell": Vector2i(8, 7),  "flip": 0},
		{"mask": 1,  "cell": Vector2i(10, 7), "flip": 0},
		{"mask": 8,  "cell": Vector2i(9, 9),  "flip": 0},
		{"mask": 10, "cell": Vector2i(8, 9),  "flip": 0},
		{"mask": 9,  "cell": Vector2i(10, 9), "flip": 0},
		{"mask": 11, "cell": Vector2i(9, 9),  "flip": 0},
		{"mask": 4,  "cell": Vector2i(9, 9),  "flip": 1},
		{"mask": 6,  "cell": Vector2i(8, 9),  "flip": 1},
		{"mask": 5,  "cell": Vector2i(10, 9), "flip": 1},
		{"mask": 7,  "cell": Vector2i(9, 9),  "flip": 1},
		{"mask": 3,  "cell": Vector2i(9, 9),  "flip": 0},
		{"mask": 12, "cell": Vector2i(9, 9),  "flip": 0},
		{"mask": 13, "cell": Vector2i(10, 7), "flip": 0},
		{"mask": 14, "cell": Vector2i(8, 7),  "flip": 0},
		{"mask": 15, "cell": Vector2i(9, 9),  "flip": 0},
	]

	m.labyrinth_floor_decor = [
		Vector2i(12, 10), Vector2i(13, 10),
		Vector2i(12, 11), Vector2i(13, 11),
		Vector2i(12, 12), Vector2i(13, 12),
		Vector2i(12, 13), Vector2i(13, 13),
		Vector2i(12, 14), Vector2i(13, 14),
	]

	m.dungeon_doorframe = {
		&"TL":  Vector2i(5, 8),
		&"TOP": Vector2i(6, 9),
		&"TR":  Vector2i(8, 9),
		&"LW":  Vector2i(5, 9),
		&"LW2": Vector2i(5, 10),
		&"RW":  Vector2i(8, 10),
		&"RW2": Vector2i(8, 11),
	}

	m.interior_terrain = {
		&"floor": [Vector2i(5, 13)],
		&"wall":  [Vector2i(5, 1)],
		&"door":  [Vector2i(20, 9)],
	}

	# No sheet overrides by default — everything uses the historical sheets.
	m.sheet_overrides = {}

	return m


## Rebuild the runtime autotile dict (`{mask: [cell, flip_v_bool]}`) from
## the flat resource list. Centralised here so [TilesetCatalog] doesn't
## need to know the storage shape.
func build_dungeon_wall_autotile_dict() -> Dictionary:
	var out: Dictionary = {}
	for entry in dungeon_wall_autotile:
		var mask: int = int(entry.get("mask", -1))
		if mask < 0:
			continue
		var cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
		var flip_v: bool = int(entry.get("flip", 0)) != 0
		out[mask] = [cell, flip_v]
	return out


## Same as build_dungeon_wall_autotile_dict but for labyrinth_wall_autotile.
func build_labyrinth_wall_autotile_dict() -> Dictionary:
	var out: Dictionary = {}
	for entry in labyrinth_wall_autotile:
		var mask: int = int(entry.get("mask", -1))
		if mask < 0:
			continue
		var cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
		var flip_v: bool = int(entry.get("flip", 0)) != 0
		out[mask] = [cell, flip_v]
	return out
