## CharacterAtlas
##
## Maps the Roguelike Characters spritesheet (16x16 tiles, 1px margin,
## 17px stride) into named "paper-doll" pieces. The sheet is 54 cols
## x 12 rows and is divided into 7 sections separated by empty spacer
## columns (cols 2, 5, 18, 27, 32, 41).
##
## A character is built by stacking Sprite2Ds with the same origin in
## this Z-order (back to front):
##   1. body       (skin tone)         [optional torso below]
##   2. torso/outfit (shirt/vest)
##   3. belt/sash  (waist accessory)
##   4. cape       (worn over torso, behind head)
##   5. hair       (back layer of hair / hood)
##   6. face       (beard / mustache)
##   7. weapon     (held in front, 2 tiles tall)
##   8. shield     (held opposite arm)
##
## All cells are Vector2i(col, row) in tile units; Sprite2D should use
## a region_rect of Rect2(col*17, row*17, 16, 16). Weapons are 2 tiles
## tall: Rect2(col*17, row*17, 16, 33).
extends RefCounted
class_name CharacterAtlas

const TILE: int = 16
const STRIDE: int = 17  ## 16px tile + 1px margin
const SHEET_PATH: String = "res://assets/characters/roguelike/characters_sheet.png"

# --- Section 1: pre-assembled examples (cols 0-1) ----------------
# Bare body color samples on rows 0-3, fully assembled NPC examples on
# rows 6-10. Useful as fallback portraits or NPC "blanks".
const EXAMPLES_COL_LEFT: int = 0
const EXAMPLES_COL_RIGHT: int = 1

# Skin-tone bare-body cells. Used as the BASE layer of any character
# (the torso/outfit cells in section 3 are clothing-only and have no
# head/arms/legs underneath, so without a body layer the character
# appears as a floating shirt).
const SKIN_TONE_ROWS: Dictionary = {
	&"light":  0,
	&"tan":    1,
	&"dark":   2,
	&"goblin": 3,
}

static func body_cell(skin: StringName) -> Vector2i:
	var row: Variant = SKIN_TONE_ROWS.get(skin, null)
	if row == null:
		return Vector2i(EXAMPLES_COL_LEFT, 0)  # fallback: light skin
	return Vector2i(EXAMPLES_COL_LEFT, int(row))

# --- Section 2: belts & sashes (cols 3-4) ------------------------
# Col 3 = belt with buckle. Col 4 = sash (no buckle).
# Rows 0..9 = different colors matching torso colors.
const BELT_COL_BUCKLE: int = 3
const BELT_COL_SASH: int = 4

# --- Section 3: bodies / torsos / outfits (cols 6-17) ------------
# 12 cols x 10 rows = 120 outfit cells.
# Layout: 4 STYLES per color group x 3 COLORS per row group.
#   color group A (rows 0-4): orange (cols 6-9), teal (10-13), purple (14-17)
#   color group B (rows 5-9): green (cols 6-9), tan (10-13), dark/black (14-17)
# Within each 4-col group:
#   col +0 = plain shirt with pants
#   col +1 = shirt with sash + pants
#   col +2 = shirt with apron
#   col +3 = armored / belted variant
const TORSO_COL0: int = 6  # first column of bodies section
const TORSO_COLOR_GROUP_WIDTH: int = 4  # 4 outfit cols per color
const TORSO_COLOR_NAMES: Array[StringName] = [
	&"orange", &"teal", &"purple", &"green", &"tan", &"black",
]
# (color_index, style_index, row_in_group) -> Vector2i
static func torso_cell(color: StringName, style: int, body_row: int = 0) -> Vector2i:
	var cidx: int = TORSO_COLOR_NAMES.find(color)
	if cidx < 0:
		return Vector2i(-1, -1)
	var group: int = cidx / 3       # 0 or 1
	var in_group: int = cidx % 3    # 0..2 (which 4-col block)
	var col: int = TORSO_COL0 + in_group * TORSO_COLOR_GROUP_WIDTH + clamp(style, 0, 3)
	var row: int = group * 5 + clamp(body_row, 0, 4)
	return Vector2i(col, row)

# --- Section 4: hair / hoods (cols 19-26) ------------------------
# 4 cols of pieces x (3+2) color groups x 4 piece styles per color.
#   cols 19-22, rows 0-3:  brown
#   cols 19-22, rows 4-7:  blonde
#   cols 19-22, rows 8-11: white
#   cols 23-26, rows 0-3:  ginger / orange
#   cols 23-26, rows 4-7:  gray
# Within each 4-col x 4-row block:
#   row +0: short hair (top of head only)
#   row +1: long hair (covers ears)
#   row +2: beard / mustache
#   row +3: bald / accessory cap
# Within a row, the 4 cols are different shapes (e.g. mohawk, side-part,
# pony-tail, helm-fitting cap).
const HAIR_COLORS: Dictionary = {
	&"brown":   {"col0": 19, "row0": 0},
	&"blonde":  {"col0": 19, "row0": 4},
	&"white":   {"col0": 19, "row0": 8},
	&"ginger":  {"col0": 23, "row0": 0},
	&"gray":    {"col0": 23, "row0": 4},
}
enum HairStyle { SHORT = 0, LONG = 1, FACIAL = 2, ACCESSORY = 3 }

static func hair_cell(color: StringName, style: int, variant: int = 0) -> Vector2i:
	var info: Dictionary = HAIR_COLORS.get(color, {})
	if info.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(info["col0"]) + clamp(variant, 0, 3),
		int(info["row0"]) + clamp(style, 0, 3))

# --- Section 5: capes & cloaks (cols 28-31) ----------------------
# Worn over the torso, behind the head. 4 cols of cape variants
# (small, square, kite, wide) x 9 rows of colors.
const CAPE_COL0: int = 28
const CAPE_COLOR_ROWS: Dictionary = {
	&"steel":  0,
	&"gold":   1,
	&"orange": 2,
	&"teal":   3,
	&"purple": 4,
	&"green":  5,
	&"silver": 6,
	&"red":    7,  # mixed-color row near bottom
	&"banner": 8,
}
static func cape_cell(color: StringName, variant: int = 0) -> Vector2i:
	if not CAPE_COLOR_ROWS.has(color):
		return Vector2i(-1, -1)
	return Vector2i(CAPE_COL0 + clamp(variant, 0, 3), int(CAPE_COLOR_ROWS[color]))

# --- Section 6: shields (cols 33-40) -----------------------------
# 8 cols x ~9 rows. 4 shield SHAPES per material:
#   col +0 = small round buckler
#   col +1 = kite (heater) shield
#   col +2 = square buckler
#   col +3 = hourglass / banded shield
# Materials by column block:
#   cols 33-36: wood (rows 0-2), gold (rows 3-5), steel (rows 6-8)
#   cols 37-40: painted/red+green (rows 3-5), painted/blue+steel (rows 6-8)
const SHIELD_COL0: int = 33
const SHIELD_MATERIAL_ROWS: Dictionary = {
	&"wood":      {"col0": 33, "row0": 0},
	&"gold":      {"col0": 33, "row0": 3},
	&"steel":     {"col0": 33, "row0": 6},
	&"painted_r": {"col0": 37, "row0": 3},
	&"painted_b": {"col0": 37, "row0": 6},
}
enum ShieldShape { ROUND = 0, KITE = 1, SQUARE = 2, HOURGLASS = 3 }

static func shield_cell(material: StringName, shape: int) -> Vector2i:
	var info: Dictionary = SHIELD_MATERIAL_ROWS.get(material, {})
	if info.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(info["col0"]) + clamp(shape, 0, 3), int(info["row0"]))

# --- Section 7: weapons (cols 42-53) -----------------------------
# Each weapon is **2 tiles tall** (16x33 region). Its top tile is at
# (col, row) and its bottom at (col, row+1).
# Top half of grid (rows 0-4):  staves/maces (one per col, color per row)
# Bottom half (rows 5-9):       swords / daggers (color per row)
# Cols 52-53 (rows 0-4 only):  bows
const WEAPON_COL0: int = 42

enum WeaponKind { STAFF, AXE, MACE, HAMMER, SWORD, DAGGER, BOW }

# Weapon col layout (top half of grid):
#   42-46 = STAVES (5 staff-tip color variants per row of staves)
#   47    = AXE one-handed
#   48    = AXE two-handed
#   49    = MACE
#   50    = HAMMER
#   51    = STAFF (long polearm)
#   52-53 = BOW (2 variants)
# Bottom half (rows 5-9): same cols 42-51 hold swords/daggers in 5 colors.

static func staff_cell(variant: int, color_row: int) -> Vector2i:
	return Vector2i(WEAPON_COL0 + clamp(variant, 0, 4), clamp(color_row, 0, 4) * 1)

static func sword_cell(variant: int, color_row: int) -> Vector2i:
	return Vector2i(WEAPON_COL0 + clamp(variant, 0, 9), 5 + clamp(color_row, 0, 4))

static func bow_cell(color_row: int) -> Vector2i:
	return Vector2i(52, clamp(color_row, 0, 4))

# --- Geometry helpers --------------------------------------------

static func tile_rect(cell: Vector2i, height_tiles: int = 1) -> Rect2i:
	return Rect2i(cell.x * STRIDE, cell.y * STRIDE, TILE, TILE * height_tiles + (height_tiles - 1))
