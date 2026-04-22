# Skill: Character Atlas & Sprite Sheet

Use this skill when working with the Kenney roguelike character sprite sheet — looking up atlas cells, adding new sprite mappings, understanding the sheet layout, or building character appearances.

---

## Sheet Info

**Texture:** `res://assets/characters/roguelike/characters_sheet.png`  
**Grid:** 54 columns × 12 rows  
**Tile size:** 16×16 px  
**Margin:** 1 px between tiles  
**Stride:** 17 px (tile + margin)  
**Region formula:** `Rect2(col * 17, row * 17, 16, 16)`  
**Weapon region:** `Rect2(col * 17, row * 17, 16, 33)` (2 tiles tall)

---

## CharacterAtlas

**File:** `scripts/data/character_atlas.gd` — `class_name CharacterAtlas extends RefCounted` (static)

### Constants

```gdscript
const TILE: int = 16
const STRIDE: int = 17
```

### Section Layout

| Section | Cols  | Rows | Content                              |
|---------|-------|------|--------------------------------------|
| Examples | 0–1  | 0–10 | Pre-assembled sample characters     |
| Belts    | 3–4  | 0–9  | Buckle belt (3) / sash (4)         |
| Torso    | 6–17 | 0–9  | 6 color groups × 4 outfit styles   |
| Hair     | 19–26| 0–11 | 5 color groups × 4 styles × 4 variants |
| Capes    | 28–31| 0–8  | 4 variants × 9 color rows          |
| Shields  | 33–40| 0–8  | 4 shapes × 5 material groups       |
| Weapons  | 42–53| 0–9  | Staves, axes, swords, bows          |

**Spacer columns (empty):** 2, 5, 18, 27, 32, 41

---

## Section 1: Examples & Body (cols 0–1)

### Skin Tones

| Name       | Row | Cell      |
|------------|-----|-----------|
| `&"light"` | 0   | `(0, 0)` |
| `&"tan"`   | 1   | `(0, 1)` |
| `&"dark"`  | 2   | `(0, 2)` |
| `&"goblin"`| 3   | `(0, 3)` |

**API:** `body_cell(skin: StringName) → Vector2i`

---

## Section 2: Belts & Sashes (cols 3–4)

- Col 3 = belt with buckle
- Col 4 = sash (no buckle)
- 10 color rows (0–9)

---

## Section 3: Torso / Outfits (cols 6–17)

12 columns × 10 rows = 120 outfit cells.

### Color Groups (3 per half)

| Color    | Cols  | Rows |
|----------|-------|------|
| orange   | 6–9   | 0–4  |
| teal     | 10–13 | 0–4  |
| purple   | 14–17 | 0–4  |
| green    | 6–9   | 5–9  |
| tan      | 10–13 | 5–9  |
| black    | 14–17 | 5–9  |

### Styles (within each 4-col group)

| Offset | Style          |
|--------|----------------|
| +0     | Plain shirt    |
| +1     | Shirt + sash   |
| +2     | Shirt + apron  |
| **+3** | **Armored / belted** |

**API:** `torso_cell(color: StringName, style: int, body_row: int = 0) → Vector2i`

**For armor rendering:** Style 3 (armored) is used when BODY slot is equipped.

---

## Section 4: Hair / Hoods (cols 19–26)

### Hair Colors

| Color      | Start Col | Start Row |
|------------|-----------|-----------|
| `&"brown"` | 19        | 0         |
| `&"blonde"`| 19        | 4         |
| `&"white"` | 19        | 8         |
| `&"ginger"`| 23        | 0         |
| `&"gray"`  | 23        | 4         |

### HairStyle Enum

| Style       | Row Offset | Description          |
|-------------|------------|----------------------|
| `SHORT`     | 0          | Top of head only     |
| `LONG`      | 1          | Covers ears          |
| `FACIAL`    | 2          | Beard / mustache     |
| `ACCESSORY` | 3          | Bald / cap / helmet  |

4 variant columns per row (different shapes — mohawk, side-part, ponytail, helm-fitting cap).

**API:** `hair_cell(color: StringName, style: int, variant: int = 0) → Vector2i`

**For helmet rendering:** `ACCESSORY` style (row +3) is used when HEAD slot is equipped.

---

## Section 5: Capes (cols 28–31)

4 shape variants × 9 color rows.

| Color   | Row |
|---------|-----|
| steel   | 0   |
| gold    | 1   |
| orange  | 2   |
| teal    | 3   |
| purple  | 4   |
| green   | 5   |
| silver  | 6   |
| red     | 7   |
| banner  | 8   |

**API:** `cape_cell(color: StringName, variant: int = 0) → Vector2i`

---

## Section 6: Shields (cols 33–40)

### Materials

| Material    | Cols  | Rows |
|-------------|-------|------|
| wood        | 33–36 | 0–2  |
| gold        | 33–36 | 3–5  |
| steel       | 33–36 | 6–8  |
| painted_r   | 37–40 | 3–5  |
| painted_b   | 37–40 | 6–8  |

### ShieldShape Enum

`ROUND=0`, `KITE=1`, `SQUARE=2`, `HOURGLASS=3`

**API:** `shield_cell(material: StringName, shape: int, variant: int = 0) → Vector2i`

---

## Section 7: Weapons (cols 42–53)

**Two tiles tall** — region height is 33px (16+1+16).

### Top Half (rows 0–4)

| Cols  | Weapon Type |
|-------|-------------|
| 42–46 | Staves      |
| 47    | Axe (1h)    |
| 48    | Axe (2h)    |
| 49    | Mace        |
| 50    | Hammer      |
| 51    | Polearm     |
| 52–53 | Bows        |

### Bottom Half (rows 5–9)

Swords/daggers in cols 42–51, 5 color rows.

### WeaponKind Enum

`STAFF`, `AXE`, `MACE`, `HAMMER`, `SWORD`, `DAGGER`, `BOW`

**API:** `weapon_cell(kind: int, variant: int = 0) → Vector2i`

---

## Geometry Helper

```gdscript
static func tile_rect(cell: Vector2i, height_tiles: int = 1) -> Rect2i:
    return Rect2i(cell.x * STRIDE, cell.y * STRIDE, TILE, TILE * height_tiles + (height_tiles - 1))
```

---

## Z-Order (back to front)

1. Body (skin tone)
2. Torso / outfit
3. Belt / sash
4. Cape (behind head)
5. Hair (back layer)
6. Face (beard)
7. Weapon (2 tiles tall, in front)
8. Shield

---

## Player Default Appearance

| Layer  | Cell          | Region Rect          | Description      |
|--------|---------------|----------------------|------------------|
| Body   | `(0, 0)`      | `(0, 0, 16, 16)`    | Light skin       |
| Torso  | `(6, 0)`      | `(102, 0, 16, 16)`  | Orange plain     |
| Hair   | `(19, 0)`     | `(323, 0, 16, 16)`  | Brown short      |
| Boots  | hidden        | —                    | Only when equipped |
| Weapon | hidden        | —                    | Only when equipped |

---

## Current Atlas Mappings (Equipment)

### WeaponAtlas defaults (`scripts/data/weapon_atlas.gd`)

| Item ID      | Cell       | Region               |
|--------------|------------|-----------------------|
| `&"sword"`   | `(42, 5)` | `(714, 85, 16, 33)` |
| `&"pickaxe"` | `(50, 0)` | `(850, 0, 16, 33)`  |
| `&"bow"`     | `(52, 0)` | `(884, 0, 16, 33)`  |

### ArmorAtlas defaults (`scripts/data/armor_atlas.gd`)

| Item ID      | Cell       | Tint  | Region              | Renders On  |
|--------------|------------|-------|---------------------|-------------|
| `&"armor"`   | `(9, 5)`  | white | `(153, 85, 16, 16)` | Torso sprite |
| `&"helmet"`  | `(19, 3)` | white | `(323, 51, 16, 16)` | Hair sprite  |
| `&"boots"`   | `(-1, -1)`| white | (none — placeholder) | Boots sprite |

### Overrides via TileMappings

`res://resources/tilesets/tile_mappings.tres` → `weapon_sprites` dictionary. Editable via SpritePicker tool. `WeaponAtlas.cell_for()` checks this before falling back to `_DEFAULTS`.
