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

## Transparent overlay sets keyed by overlay set name (e.g. &"dirt", &"stone").
## 20-tile sets: indices 0–8 blob, 9–12 inner corners, 13–19 path-only tiles.
## 13-tile sets: indices 0–8 blob, 9–12 inner corners (no path tiles).
## Indices 13–19 on a 13-tile set are clamped to center (4) at runtime.
## `StringName → Array[Vector2i]` (length 13 or 20).
@export var overworld_overlay_sets: Dictionary = {}

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
##   - `flip_v`: `int` (0/1) vertical flip — top-of-wall / south-facing tiles
##   - `flip_h`: `int` (0/1) horizontal flip — mirrored east/west tiles
##   (Old saves with a single `flip` key are read as `flip_v` for compatibility.)
@export var dungeon_wall_autotile: Array[Dictionary] = []

## Decorative floor overlay cells (random ~10% on floor tiles).
@export var dungeon_floor_decor: Array[Vector2i] = []

## 3×3 border set for dungeon floor cells that are adjacent to walls.
## NW/N/NE/W/C/E/SW/S/SE ordering (same as overworld_terrain_patches_3x3).
## C (index 4) = fully-surrounded "open floor" cell.
## Edge cells = floor meeting wall on one side.
## Corner cells = floor meeting wall on two sides.
## Leave empty to disable floor borders (falls back to plain floor cell).
@export var dungeon_floor_border_3x3: Array[Vector2i] = []

## Same as dungeon_floor_border_3x3 for labyrinth floors.
@export var labyrinth_floor_border_3x3: Array[Vector2i] = []

## Two side-by-side cells for the cave-mouth marker on the overworld.
## Length 2, ordered [west, east].
@export var dungeon_entrance_pair: Array[Vector2i] = []

## Two side-by-side labyrinth entrance marker tiles on the dungeon sheet.
## Painted on the overworld to mark labyrinth entrances with a tint.
@export var labyrinth_entrance_pair: Array[Vector2i] = []

## Two atlas cells for the treasure chest sprite: [closed_cell, open_cell].
## Used by TreasureChest._refresh_sprite() to draw the correct frame.
@export var labyrinth_chest_pair: Array[Vector2i] = []

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

## Wall autotile for stone-style room walls (dungeon_sheet.png cols 17-21, rows 1-4).
## Same schema as dungeon_wall_autotile: flat Array of {mask, cell, flip_v, flip_h}.
## Stone = rows 1-4, wood = rows 6-9 (row_offset = 5).
@export var house_wall_stone_autotile: Array[Dictionary] = []

## Wall autotile for wood-style room walls (dungeon_sheet.png cols 17-21, rows 6-9).
@export var house_wall_wood_autotile: Array[Dictionary] = []

## Floor tile variants for stone-style rooms (dungeon_sheet.png cols 17-21, row 12).
## Exactly 5 entries (one per column). WorldRoot picks one by seed % 5.
@export var house_floor_stone: Array[Vector2i] = []

## Floor tile variants for wood-style rooms (dungeon_sheet.png cols 17-21, row 17).
@export var house_floor_wood: Array[Vector2i] = []

## Named furniture items selectable in the Game Editor → "Interior Furniture".
## `StringName → Vector2i` mapping furniture type id → atlas cell on interior_sheet.png.
## Empty by default; user populates via SpritePicker.
@export var interior_furniture: Dictionary = {}

# ─── Character / weapon sprites ─────────────────────────────────────────

# ─── Sheet overrides ────────────────────────────────────────────────────

## Optional per-field sheet-path overrides. When a mapping field (e.g.
## `&"city_terrain"`) needs to pull cells from a different PNG than the
## historical default, store the mapping here: `StringName → String`.
## The Game Editor sheet selector writes this; TilesetCatalog reads it.
## Missing keys fall back to the built-in default sheet.
@export var sheet_overrides: Dictionary = {}

# ─── Entity sprites ──────────────────────────────────────────────────────

## Atlas cell(s) for the caravan wagon sprite on the overworld sheet.
## Element [0] is the cell used by the Caravan entity. Editable via the
## Game Editor → "Caravan Wagon" category.
@export var caravan_wagon: Array[Vector2i] = []


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

	m.overworld_overlay_sets = {
		# ── 20-tile sets ──────────────────────────────────────────────────
		&"dirt": [
			# blob 3×3 (indices 0–8)
			Vector2i(8, 10), Vector2i(9, 10), Vector2i(10, 10),
			Vector2i(8, 11), Vector2i(9, 11), Vector2i(10, 11),
			Vector2i(8, 12), Vector2i(9, 12), Vector2i(10, 12),
			# inner corners (indices 9–12)
			Vector2i(7, 11), Vector2i(6, 11), Vector2i(7, 10), Vector2i(6, 10),
			# path-only (indices 13–19): straight, dead-ends, isolated
			Vector2i(10, 8), Vector2i(10, 9),
			Vector2i(6, 12), Vector2i(7, 12), Vector2i(6, 13), Vector2i(7, 13),
			Vector2i(9, 13),
			# path corners (indices 20–23): cNE, cNW, cSE, cSW
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			# path T-junctions (indices 24–27): tW, tS, tE, tN
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			# path cross (index 28): +
			Vector2i(0, 0),
		],
		&"stone": [
			Vector2i(8, 16), Vector2i(9, 16), Vector2i(10, 16),
			Vector2i(8, 17), Vector2i(9, 17), Vector2i(10, 17),
			Vector2i(8, 18), Vector2i(9, 18), Vector2i(10, 18),
			Vector2i(7, 17), Vector2i(6, 17), Vector2i(7, 16), Vector2i(6, 16),
			Vector2i(10, 14), Vector2i(10, 15),
			Vector2i(6, 18), Vector2i(7, 18), Vector2i(6, 19), Vector2i(7, 19),
			Vector2i(9, 19),
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0),
		],
		&"snow": [
			Vector2i(8, 22), Vector2i(9, 22), Vector2i(10, 22),
			Vector2i(8, 23), Vector2i(9, 23), Vector2i(10, 23),
			Vector2i(8, 24), Vector2i(9, 24), Vector2i(10, 24),
			Vector2i(7, 23), Vector2i(6, 23), Vector2i(7, 22), Vector2i(6, 22),
			Vector2i(10, 20), Vector2i(10, 21),
			Vector2i(6, 24), Vector2i(7, 24), Vector2i(6, 25), Vector2i(7, 25),
			Vector2i(9, 25),
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
			Vector2i(0, 0),
		],
		# ── 13-tile sets ──────────────────────────────────────────────────
		&"grass": [
			Vector2i(3, 16), Vector2i(4, 16), Vector2i(5, 16),
			Vector2i(3, 17), Vector2i(4, 17), Vector2i(5, 17),
			Vector2i(3, 18), Vector2i(4, 18), Vector2i(5, 18),
			Vector2i(2, 17), Vector2i(1, 17), Vector2i(2, 16), Vector2i(1, 16),
		],
		&"mud": [
			Vector2i(3, 19), Vector2i(4, 19), Vector2i(5, 19),
			Vector2i(3, 20), Vector2i(4, 20), Vector2i(5, 20),
			Vector2i(3, 21), Vector2i(4, 21), Vector2i(5, 21),
			Vector2i(2, 20), Vector2i(1, 20), Vector2i(2, 19), Vector2i(1, 19),
		],
		&"purple": [
			Vector2i(3, 22), Vector2i(4, 22), Vector2i(5, 22),
			Vector2i(3, 23), Vector2i(4, 23), Vector2i(5, 23),
			Vector2i(3, 24), Vector2i(4, 24), Vector2i(5, 24),
			Vector2i(2, 23), Vector2i(1, 23), Vector2i(2, 22), Vector2i(1, 22),
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
		{"mask": 2,  "cell": Vector2i(8, 7),  "flip_v": 0, "flip_h": 0},
		{"mask": 1,  "cell": Vector2i(10, 7), "flip_v": 0, "flip_h": 0},
		{"mask": 8,  "cell": Vector2i(9, 9),  "flip_v": 0, "flip_h": 0},
		{"mask": 10, "cell": Vector2i(8, 9),  "flip_v": 0, "flip_h": 0},
		{"mask": 9,  "cell": Vector2i(10, 9), "flip_v": 0, "flip_h": 0},
		{"mask": 11, "cell": Vector2i(9, 9),  "flip_v": 0, "flip_h": 0},
		{"mask": 4,  "cell": Vector2i(9, 9),  "flip_v": 1, "flip_h": 0},
		{"mask": 6,  "cell": Vector2i(8, 9),  "flip_v": 1, "flip_h": 0},
		{"mask": 5,  "cell": Vector2i(10, 9), "flip_v": 1, "flip_h": 0},
		{"mask": 7,  "cell": Vector2i(9, 9),  "flip_v": 1, "flip_h": 0},
		{"mask": 3,  "cell": Vector2i(9, 9),  "flip_v": 0, "flip_h": 0},
		{"mask": 12, "cell": Vector2i(9, 9),  "flip_v": 0, "flip_h": 0},
		{"mask": 13, "cell": Vector2i(10, 7), "flip_v": 0, "flip_h": 0},
		{"mask": 14, "cell": Vector2i(8, 7),  "flip_v": 0, "flip_h": 0},
		{"mask": 15, "cell": Vector2i(9, 9),  "flip_v": 0, "flip_h": 0},
	]

	m.dungeon_floor_decor = [
		Vector2i(12, 10), Vector2i(13, 10),
		Vector2i(12, 11), Vector2i(13, 11),
		Vector2i(12, 12), Vector2i(13, 12),
		Vector2i(12, 13), Vector2i(13, 13),
		Vector2i(12, 14), Vector2i(13, 14),
	]

	m.dungeon_entrance_pair = [Vector2i(24, 4), Vector2i(25, 4)]

	# Labyrinth terrain defaults — same floor tile as dungeon until the user
	# overrides it in the Game Editor → Labyrinth sections.
	# Note: &"door" and &"water" are intentionally absent — LabyrinthGenerator
	# never emits those codes, so they are not used by the painting path.
	m.labyrinth_terrain = {
		&"floor": [Vector2i(9, 7)],
	}

	m.labyrinth_wall_autotile = [
		{"mask": 2,  "cell": Vector2i(8, 7),  "flip_v": 0, "flip_h": 0},
		{"mask": 1,  "cell": Vector2i(10, 7), "flip_v": 0, "flip_h": 0},
		{"mask": 8,  "cell": Vector2i(9, 9),  "flip_v": 0, "flip_h": 0},
		{"mask": 10, "cell": Vector2i(8, 9),  "flip_v": 0, "flip_h": 0},
		{"mask": 9,  "cell": Vector2i(10, 9), "flip_v": 0, "flip_h": 0},
		{"mask": 11, "cell": Vector2i(9, 9),  "flip_v": 0, "flip_h": 0},
		{"mask": 4,  "cell": Vector2i(9, 9),  "flip_v": 1, "flip_h": 0},
		{"mask": 6,  "cell": Vector2i(8, 9),  "flip_v": 1, "flip_h": 0},
		{"mask": 5,  "cell": Vector2i(10, 9), "flip_v": 1, "flip_h": 0},
		{"mask": 7,  "cell": Vector2i(9, 9),  "flip_v": 1, "flip_h": 0},
		{"mask": 3,  "cell": Vector2i(9, 9),  "flip_v": 0, "flip_h": 0},
		{"mask": 12, "cell": Vector2i(9, 9),  "flip_v": 0, "flip_h": 0},
		{"mask": 13, "cell": Vector2i(10, 7), "flip_v": 0, "flip_h": 0},
		{"mask": 14, "cell": Vector2i(8, 7),  "flip_v": 0, "flip_h": 0},
		{"mask": 15, "cell": Vector2i(9, 9),  "flip_v": 0, "flip_h": 0},
	]

	m.labyrinth_floor_decor = [
		Vector2i(12, 10), Vector2i(13, 10),
		Vector2i(12, 11), Vector2i(13, 11),
		Vector2i(12, 12), Vector2i(13, 12),
		Vector2i(12, 13), Vector2i(13, 13),
		Vector2i(12, 14), Vector2i(13, 14),
	]

	m.labyrinth_chest_pair = [Vector2i(2, 10), Vector2i(3, 10)]

	# Floor-border 3×3: NW N NE / W C E / SW S SE.
	# Defaults to all pointing at the plain floor cell (9,7) — border is
	# invisible until the user picks actual transition tiles in the Game Editor.
	m.dungeon_floor_border_3x3 = [
		Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),  # NW  N  NE
		Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),  # W   C   E
		Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),  # SW  S  SE
	]

	m.labyrinth_floor_border_3x3 = [
		Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),  # NW  N  NE
		Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),  # W   C   E
		Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),  # SW  S  SE
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

	# ── House room-wall autotile — dungeon_sheet.png cols 17-21 ─────────────
	# Stone style: rows 1-4 for walls, row 12 for floor.
	# Wood style: rows 6-9 for walls, row 17 for floor (row_offset = +5).
	# Mask bits: N=8, S=4, E=2, W=1 (floor neighbors, cardinal only).
	# Corner tiles (mask=0) are handled directly by the renderer using
	# diagonal neighbor checks; only mask 1-15 are stored here.
	#
	# Stone wall autotile (base_row = 1):
	m.house_wall_stone_autotile = [
		# mask=4: floor to S only → N-wall center
		{"mask": 4,  "cell": Vector2i(19, 1)},
		# mask=8: floor to N only → S-wall center
		{"mask": 8,  "cell": Vector2i(19, 3)},
		# mask=2: floor to E only → side wall
		{"mask": 2,  "cell": Vector2i(19, 2)},
		# mask=1: floor to W only → side wall
		{"mask": 1,  "cell": Vector2i(19, 2)},
		# mask=6: floor S+E → N-wall, floor to east
		{"mask": 6,  "cell": Vector2i(17, 1)},
		# mask=5: floor S+W → N-wall, floor to west
		{"mask": 5,  "cell": Vector2i(21, 1)},
		# mask=10: floor N+E → S-wall, floor to east
		{"mask": 10, "cell": Vector2i(17, 3)},
		# mask=9: floor N+W → S-wall, floor to west
		{"mask": 9,  "cell": Vector2i(21, 3)},
		# mask=3: floor N+S → side wall (east-facing inner segment)
		{"mask": 3,  "cell": Vector2i(19, 2)},
		# mask=12: floor E+W → NS-passthrough
		{"mask": 12, "cell": Vector2i(19, 4)},
		# mask=14: floor S+E+W → NS-passthrough with S floor
		{"mask": 14, "cell": Vector2i(19, 4)},
		# mask=13: floor N+E+W → NS-passthrough with N floor
		{"mask": 13, "cell": Vector2i(19, 4)},
		# mask=7: floor S+E+N → T-junction
		{"mask": 7,  "cell": Vector2i(19, 4)},
		# mask=11: floor N+S+W → T-junction
		{"mask": 11, "cell": Vector2i(19, 4)},
		# mask=15: floor all → center column
		{"mask": 15, "cell": Vector2i(19, 4)},
	]
	# Wood wall autotile (base_row = 6, same pattern +5 rows):
	m.house_wall_wood_autotile = [
		{"mask": 4,  "cell": Vector2i(19, 6)},
		{"mask": 8,  "cell": Vector2i(19, 8)},
		{"mask": 2,  "cell": Vector2i(19, 7)},
		{"mask": 1,  "cell": Vector2i(19, 7)},
		{"mask": 6,  "cell": Vector2i(17, 6)},
		{"mask": 5,  "cell": Vector2i(21, 6)},
		{"mask": 10, "cell": Vector2i(17, 8)},
		{"mask": 9,  "cell": Vector2i(21, 8)},
		{"mask": 3,  "cell": Vector2i(19, 7)},
		{"mask": 12, "cell": Vector2i(19, 9)},
		{"mask": 14, "cell": Vector2i(19, 9)},
		{"mask": 13, "cell": Vector2i(19, 9)},
		{"mask": 7,  "cell": Vector2i(19, 9)},
		{"mask": 11, "cell": Vector2i(19, 9)},
		{"mask": 15, "cell": Vector2i(19, 9)},
	]
	# Stone floor variants (dungeon_sheet.png cols 17-21, row 12):
	m.house_floor_stone = [
		Vector2i(17, 12), Vector2i(18, 12), Vector2i(19, 12),
		Vector2i(20, 12), Vector2i(21, 12),
	]
	# Wood floor variants (dungeon_sheet.png cols 17-21, row 17):
	m.house_floor_wood = [
		Vector2i(17, 17), Vector2i(18, 17), Vector2i(19, 17),
		Vector2i(20, 17), Vector2i(21, 17),
	]
	# Interior furniture: empty by default — user configures via SpritePicker.
	m.interior_furniture = {}

	# No sheet overrides by default — everything uses the historical sheets.
	m.sheet_overrides = {}

	m.caravan_wagon = [Vector2i(10, 0)]

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
		# Support legacy single `flip` key (treated as flip_v).
		var flip_v: bool = int(entry.get("flip_v", entry.get("flip", 0))) != 0
		var flip_h: bool = int(entry.get("flip_h", 0)) != 0
		out[mask] = [cell, flip_v, flip_h]
	return out


## Same as build_dungeon_wall_autotile_dict but for labyrinth_wall_autotile.
func build_labyrinth_wall_autotile_dict() -> Dictionary:
	var out: Dictionary = {}
	for entry in labyrinth_wall_autotile:
		var mask: int = int(entry.get("mask", -1))
		if mask < 0:
			continue
		var cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
		var flip_v: bool = int(entry.get("flip_v", entry.get("flip", 0))) != 0
		var flip_h: bool = int(entry.get("flip_h", 0)) != 0
		out[mask] = [cell, flip_v, flip_h]
	return out


## Build runtime dict from house_wall_stone_autotile or house_wall_wood_autotile.
## Schema: {mask: Vector2i cell} — room walls never use flip transforms.
func build_house_wall_autotile_dict(style: StringName) -> Dictionary:
	var source: Array[Dictionary] = (
			house_wall_wood_autotile if style == &"wood" else house_wall_stone_autotile)
	var out: Dictionary = {}
	for entry in source:
		var mask: int = int(entry.get("mask", -1))
		if mask < 0:
			continue
		out[mask] = entry.get("cell", Vector2i(-1, -1))
	return out
