# Roguelike Characters Pack — Atlas Layout

Sheet: `assets/characters/roguelike/characters_sheet.png`
Tile: **16×16**, **1 px margin**, stride = **17 px**, grid = **54 cols × 12 rows**.

The sheet is divided into 7 sections separated by spacer columns
(cols **2, 5, 18, 27, 32, 41** are empty).

| Section            | Cols       | Rows | Content                                                   |
|--------------------|------------|------|-----------------------------------------------------------|
| 1. Examples        | 0–1        | 0–10 | Bare body (skin) samples (rows 0–3) + assembled NPCs (rows 6–10) |
| 2. Belts / sashes  | 3–4        | 0–9  | Col 3 = belt with buckle, col 4 = sash. Row = colour.     |
| 3. Bodies / outfits| 6–17       | 0–9  | 4 outfit styles × 3 colour blocks × 2 row groups          |
| 4. Hair / face     | 19–26      | 0–11 | 5 hair colours × 4 styles × 4 variants                    |
| 5. Capes / cloaks  | 28–31      | 0–8  | 4 cape shapes × 9 colours                                 |
| 6. Shields         | 33–40      | 0–8  | 4 shapes × 5 materials                                    |
| 7. Weapons         | 42–53      | 0–9  | 2-tile-tall sprites: staves/maces (top), swords (bottom), bows (cols 52–53) |

## Building a character

A character is a stack of `Sprite2D`s sharing the same origin. Z-order
(back → front):

1. **Torso** (outfit/shirt) — `CharacterAtlas.torso_cell(color, style, row)`
2. **Belt / sash** — col 3 or 4, row = colour
3. **Cape** — `CharacterAtlas.cape_cell(color, variant)`
4. **Hair** (back of head / hood) — `CharacterAtlas.hair_cell(color, HairStyle.SHORT|LONG, variant)`
5. **Face** (beard / mustache) — `CharacterAtlas.hair_cell(color, HairStyle.FACIAL, variant)`
6. **Shield** — `CharacterAtlas.shield_cell(material, ShieldShape.*)`
7. **Weapon** (2 tiles tall, offset y = -8) — `CharacterAtlas.staff_cell|sword_cell|bow_cell(...)`

`CharacterBuilder.build(opts)` does this composition end-to-end. Example:

```gdscript
var wizard := CharacterBuilder.build({
    "torso_color": &"purple", "torso_style": 0,
    "hair_color":  &"white",  "hair_style": CharacterAtlas.HairStyle.LONG,
    "face_color":  &"gray",   "face_variant": 2,
    "weapon": "staff", "weapon_variant": 0,
})
add_child(wizard)
```

## Notes / gotchas

- The classifications above are the **convention** used by `CharacterAtlas`;
  the underlying sheet is just an artist's grid, so a few rows mix purposes
  (e.g. cape section has a couple of "potion-like" samples in rows 0–1 that
  are out of scope for the builder).
- All weapons are **2 tiles tall** — use a region rect of `(col*17, row*17, 16, 33)` and
  position the sprite so its bottom-half centres on the body (default offset y = −8).
- Piece sprites are pre-aligned within their 16×16 tile, so stacking with a
  shared origin "just works" — no per-piece y-offsets needed for the body parts.
