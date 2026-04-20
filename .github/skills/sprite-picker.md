# Skill: SpritePicker Tool

## What It Is

SpritePicker is a **standalone developer tool** for visually rebinding atlas tile cells to named mapping slots. It edits a single Resource file (`tile_mappings.tres`) that is the **single source of truth** for all atlas cell coordinates used at runtime by `TilesetCatalog`.

**Run it:**
```
godot res://scenes/tools/SpritePicker.tscn
```

## Architecture

```
TileMappings.default_mappings()  ─seed─►  tile_mappings.tres  ◄─edit─►  SpritePicker UI
       (code defaults)                     (on-disk .tres)                   │
                                                  │                          │
                                                  ▼                          │
                                           TilesetCatalog (runtime)          │
                                                                    Save button writes
                                                                    back to .tres
```

### Key Files

| File | Role |
|------|------|
| `scripts/tools/sprite_picker.gd` | Main tool script (~835 lines). Builds all UI from code. |
| `scenes/tools/SpritePicker.tscn` | Minimal scene — root `Control` with the script attached. |
| `scripts/data/tile_mappings.gd` | `TileMappings` Resource class. Defines all `@export` fields + `default_mappings()`. |
| `resources/tilesets/tile_mappings.tres` | The on-disk `.tres` — single source of truth at runtime. |
| `tools/seed_tile_mappings.gd` | One-shot seeder: writes `.tres` from `TileMappings.default_mappings()`. |

## The `_MAPPINGS` Routing Table

Each entry in `sprite_picker.gd`'s `_MAPPINGS` array connects a tree-panel item to a `TileMappings` field and an atlas sheet:

```gdscript
{"id": &"overworld_terrain",  "label": "Overworld terrain",
 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
 "field": &"overworld_terrain",  "kind": &"list"},
```

Fields:
- `id` — internal key (TreeItem metadata)
- `label` — visible name in the left tree panel
- `sheet` — atlas PNG to display in the middle pane
- `field` — `TileMappings` property name to read/write
- `kind` — selection layout for the right pane (see below)

## The 7 Slot Kinds

| Kind | Data Shape | Behavior |
|------|-----------|----------|
| `"single"` | `Dict[StringName → Vector2i]` | Each key = one slot; click rebinds to single cell |
| `"named"` | `Dict[Variant → Vector2i]` | Same as single, allows non-StringName keys (e.g. `Vector2i`) |
| `"list"` | `Dict[StringName → Array[Vector2i]]` | Each key = one slot; clicking **toggles** cells in/out of the array |
| `"patch3"` | `Dict[StringName → Array[Vector2i]]` (len 9) | Expands each 9-cell group into 9 individual NW…SE single-cell slots |
| `"patch3_flat"` | `Array[Vector2i]` (len 9) | Like patch3 but the field itself is the 9-cell array |
| `"flat_list"` | `Array[Vector2i]` | Whole field is one array slot; clicking toggles cells |
| `"autotile"` | `Array[Dict{mask, cell, flip}]` | Each entry = one slot + a flip checkbox |

## How to Add a New Sprite Mapping

### A) Add a new key to an existing category

Example: adding `&"mushroom"` to overworld decorations.

1. **`scripts/data/tile_mappings.gd`** — In `default_mappings()`, add the key with a default cell:
   ```gdscript
   &"mushroom": [Vector2i(x, y)],
   ```
2. **Re-seed** (overwrites `.tres` from defaults — **loses any SpritePicker edits**):
   ```
   godot --headless -s tools/seed_tile_mappings.gd
   ```
   **OR** manually add the key to `resources/tilesets/tile_mappings.tres` in a text editor, then use SpritePicker to visually pick cells.

### B) Add an entirely new mapping category

Example: adding weapon sprites on a new atlas sheet.

1. **`scripts/data/tile_mappings.gd`** — Add a new `@export var`:
   ```gdscript
   @export var weapon_sprites: Dictionary = {}
   ```
2. **`scripts/data/tile_mappings.gd`** — Populate it in `default_mappings()`:
   ```gdscript
   m.weapon_sprites = {
       &"sword": [Vector2i(42, 5)],
       &"pickaxe": [Vector2i(47, 0)],
   }
   ```
3. **`scripts/tools/sprite_picker.gd`** — Append to `_MAPPINGS`:
   ```gdscript
   {"id": &"weapon_sprites",  "label": "Weapon sprites",
    "sheet": "res://assets/characters/roguelike/characters_sheet.png",
    "field": &"weapon_sprites",  "kind": &"list"},
   ```
4. **Re-seed** or manually update the `.tres`.

### C) Non-atlas sprites (individual PNGs)

SpritePicker only handles **atlas-based** mappings (cell coordinates on a sheet). Systems that use individual PNG files (like `ItemRegistry` icons at `assets/icons/generic_items/genericItem_color_NNN.png`) are **separate** and not managed by SpritePicker.

If you need to make individual-PNG sprites configurable in SpritePicker, you would need to either:
- Combine them into an atlas sheet first, or
- Extend SpritePicker to support a new kind (significant work).

## Important Rules

1. **Every new sprite reference must be in SpritePicker.** Per project convention, anytime a sprite is added to the game, it must also be available and rebindable in the sprite tool.
2. **SpritePicker v1 cannot add/rename slots from the UI** — only rebind existing ones to different atlas cells. New slots must be added in source code, then re-seeded.
3. **Re-seeding overwrites manual edits.** If you've customized cells in SpritePicker, adding a new key via re-seed will reset everything to defaults. Prefer manually editing the `.tres` for incremental additions.
4. **The `default_mappings()` function is the fallback.** If the `.tres` is missing (fresh checkout), `TilesetCatalog` falls back to these coded defaults. Keep them in sync.
5. **Cell coordinates are `Vector2i(column, row)`** in tile units (16×16 px tiles with 1px gutter, stride = 17px).

## Existing Mapping Categories

| `_MAPPINGS` id | Field | Sheet | Kind |
|----------------|-------|-------|------|
| `overworld_terrain` | `overworld_terrain` | overworld_sheet.png | list |
| `overworld_decoration` | `overworld_decoration` | overworld_sheet.png | list |
| `overworld_terrain_patches_3x3` | `overworld_terrain_patches_3x3` | overworld_sheet.png | patch3 |
| `overworld_water_border_grass_3x3` | `overworld_water_border_grass_3x3` | overworld_sheet.png | patch3_flat |
| `overworld_water_outer_corners` | `overworld_water_outer_corners` | overworld_sheet.png | named |
| `city_terrain` | `city_terrain` | city_sheet.png | list |
| `dungeon_terrain` | `dungeon_terrain` | dungeon_sheet.png | list |
| `dungeon_wall_autotile` | `dungeon_wall_autotile` | dungeon_sheet.png | autotile |
| `dungeon_floor_decor` | `dungeon_floor_decor` | dungeon_sheet.png | flat_list |
| `dungeon_entrance_pair` | `dungeon_entrance_pair` | dungeon_sheet.png | flat_list |
| `dungeon_doorframe` | `dungeon_doorframe` | dungeon_sheet.png | named |
| `interior_terrain` | `interior_terrain` | interior_sheet.png | list |

## Tile Geometry

- Tile size: 16×16 px
- Gutter: 1 px between tiles
- Stride: 17 px (TILE_PX + TILE_GUTTER)
- Sheet zoom in SpritePicker UI: 3×
- Cell coordinate formula: pixel `(col * 17, row * 17)` for top-left corner

## Character Sheet Weapons (for weapon_sprites)

The character sheet (`characters_sheet.png`) uses the same 16px tile / 17px stride geometry. Weapons are **2 tiles tall** (16×33 region). Layout at columns 42–53:

| Columns | Rows 0–4 | Rows 5–9 |
|---------|----------|----------|
| 42–46 | Staves (5 tip variants) | Swords (5 color variants) |
| 47 | One-handed axe | Swords cont. |
| 48 | Two-handed axe | Swords cont. |
| 49 | Mace | Swords cont. |
| 50 | Hammer | Swords cont. |
| 51 | Long polearm | Swords cont. |
| 52–53 | Bows (2 variants) | — |

Region rect for a 2-tall weapon: `Rect2(col * 17, row * 17, 16, 33)`.
