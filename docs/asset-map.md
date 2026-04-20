# Asset Map (Kenney All-in-One → curated paths)

Raw pack: `kenney_raw/` (gdignored from Godot — never imported directly).
Curated copies: `assets/` (stable paths used in `.tres`).

Curation is performed by `tools/curate_assets.py` (run once, idempotent).

## Top-down Tile Format

All Kenney roguelike tile sheets share the same layout:

- **Tile size**: 16 × 16 pixels
- **Separator (gutter)**: 1 px between tiles, **no outer margin**
- Sheet size formula: `width = cols*16 + (cols-1)`, `height = rows*16 + (rows-1)`

Render scale is set in `WorldConst.RENDER_ZOOM` (default 4×, so each tile occupies
64 screen pixels).

| Sheet | Source | Cols × Rows | Use |
|-------|--------|-------------|-----|
| Roguelike Base | `assets/tiles/roguelike/overworld_sheet.png` | 57 × 31 | Overworld terrain (grass/sand/dirt/stone/water/snow/ice + trees, bushes, doors) |
| Roguelike City | `assets/tiles/roguelike/city_sheet.png` | 37 × 28 | City map (roads, sidewalks, building exteriors) |
| Roguelike Dungeon | `assets/tiles/roguelike/dungeon_sheet.png` | 29 × 18 | Dungeon view (stone floors, walls, doors) |
| Roguelike Interior | `assets/tiles/roguelike/interior_sheet.png` | 27 × 18 | House interior (wood floors, walls, furniture) |
| Roguelike Characters | `assets/characters/roguelike/characters_sheet.png` | 54 × 12 | Players, NPCs, monsters (16×16 facing-down sprites) |

## Rune Overlay

Decorative/interactable runes painted on top of terrain.

- `assets/tiles/runes/runes_black_tile.png`
- `assets/tiles/runes/runes_grey_tile.png`
- `assets/tiles/runes/runes_blue_tile.png`

(Each is a multi-tile sheet of single rune glyphs; rendered on the `overlay`
TileMapLayer.)

## UI

`UI Pack - Pixel Adventure` — pixel-art panels, buttons, frames, 9-slice borders.

- `assets/ui/pixel_adventure/small_thin.png`, `small_thick.png`
- `assets/ui/pixel_adventure/large_thin.png`, `large_thick.png`
- `assets/ui/pixel_adventure/tiles/` (per-piece PNGs for individual 9-slices)

## Monsters

- `assets/characters/monsters/slime.png` — green slime, 16×16, cropped from
  Tiny Dungeon `Tilemap/tilemap_packed.png` tile (0, 9). Used by [Monster].

## Particles

Mining VFX, smoke, sparks.

- `assets/particles/pack/` — sparks, smoke, slashes, magic
- `assets/particles/smoke/` — additional smoke variants

## Item icons

`assets/icons/generic_items/` — colored generic item icons for inventory
display (wood, stone, fiber, berries, iron, potions, etc).

## Audio

Unchanged from previous build:

- `assets/audio/impact/` — footsteps, mining hits
- `assets/audio/rpg/` — combat, doors, coins
- `assets/audio/interface/` — UI clicks, confirmations

## Fonts

`assets/fonts/` — Kenney Pixel, High, Mini, Bold.

## Known Gaps

- **Character animation**: Roguelike Characters Pack provides only static
  facings. Locomotion = vertical bob (1–2 px sine while moving). 4-direction
  facing not used; left/right = horizontal flip.
- **Pier sprites**: built from `assets/tiles/roguelike/overworld_sheet.png`
  wood-plank tiles.
- **Boats**: also from the overworld sheet (Roguelike Base Pack contains a
  small sailboat / raft icon).
- **Music**: not yet curated.
