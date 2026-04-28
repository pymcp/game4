---
name: sprite-sheet-generation
description: Use when adding new entity types, migrating sprites to hires, generating placeholder sprite sheets, or onboarding new art assets for items, weapons, armor, or creatures.
---

# Skill: Hires Sprite Sheet Generation

## What It Does

`tools/gen_hires_sheet.py` generates 64×64 placeholder spritesheets per entity category,
assigns each entity a stable cell, and immediately patches the game JSON files so the
engine renders from the new sheets — no code changes required.

## Sheet Spec

| Property | Value |
|----------|-------|
| Tile size | 64×64 px |
| Gutter | 1 px |
| Stride | 65 px (tile + gutter) |
| Columns | 8 |
| Sheet width | 519 px (8 × 65 − 1) |
| Spec file | `assets/icons/hires/_spec.json` → `{ "tile_px": 64, "margin_px": 1 }` |

`HiresIconRegistry` and `SheetSpecReader` read `_spec.json` to compute cell regions — do not change this file manually.

## Categories & Game File Targets

| Category | Source JSON | Entities included | Patched fields |
|----------|-------------|-------------------|----------------|
| `items` | `resources/items.json` | effective slot: `none` / `""` | `hires_sheet`, `hires_cell` |
| `weapons` | `resources/items.json` | effective slot: `weapon` | `hires_sheet`, `hires_cell` |
| `armor` | `resources/items.json` | effective slot: `head/body/feet/off_hand` | `hires_sheet`, `hires_cell` |
| `creatures` | `resources/creature_sprites.json` | all entries | `sheet`, `region`, `anchor_ratio`, `scale` |

## Usage

```bash
# Single category
python3 tools/gen_hires_sheet.py items
python3 tools/gen_hires_sheet.py creatures

# All categories at once
python3 tools/gen_hires_sheet.py all
```

The tool is idempotent. Re-running it after adding new entities or JSON entries is always safe.

## Cell Assignment File

Each category stores its `{entity_id: [col, row]}` map in:
```
assets/icons/hires/<category>_cells.json
```

Cell assignments are **stable across re-runs** — new entities are appended to the next
available slot; existing assignments never move.  Commit this file alongside the PNG.

## Stub → Real Art Workflow

1. Run the tool → category PNG is generated with labelled placeholder tiles.
2. Open the PNG in your image editor (each cell is 64×64 px, 1 px gutter between).
3. Paint real art into any cells.
4. Re-run the tool for that category → **real-art cells are preserved unchanged**; only stub cells are refreshed.

**Stub detection**: the tool samples the interior pixel at `(col*65+4, row*65+4)`.  Each category uses a unique sentinel background colour:

| Category | Sentinel RGB |
|----------|-------------|
| `items` | (45, 95, 55) forest green |
| `weapons` | (100, 45, 45) dark crimson |
| `armor` | (40, 65, 110) steel blue |
| `creatures` | (70, 30, 100) deep purple |

If the sampled pixel is within ±30 of the sentinel, the cell is regenerated.  Any other colour means real art is present → pixels are copied from the old PNG unmodified.

## Creature Scale Math

64 px tiles at `scale = [0.25, 0.25]` render as 16 px in-game (world tile size):

```
display_px = tile_px × scale × render_zoom
           = 64      × 0.25  × 4           = 64 screen px  ✓
```

`anchor_ratio = [0.5, 0.95]` pins the sprite's feet to the entity's world position
(center-x, 95 % down the tile).  This replaces the old fixed `anchor: [x, y]` key.

## Adding a New Entity

**Item:**
1. Add entry to `resources/items.json` with a `slot` field.
2. Run `python3 tools/gen_hires_sheet.py <category>` — new stub cell appears.
3. Paste real art into that cell; re-run tool to confirm preservation.

**Creature:**
1. Add entry to `resources/creature_sprites.json` (any sheet/region values are fine as placeholders).
2. Run `python3 tools/gen_hires_sheet.py creatures`.
3. The entry now points at `creatures.png`.  Paste real art; re-run.

## Adding a New Category

1. Add the sentinel colour to `SENTINEL` dict in `tools/gen_hires_sheet.py`.
2. Add a dispatch entry to `CATEGORIES` dict (use `_run_item_category` or write a new runner).
3. Run the new category once to generate the PNG + cells file.
4. Update this skill with the new row in the categories table.

## Scope Limitations

- **Tiles (TileMapLayer)**: not in scope.  TileMapLayer requires 16 px source textures; no hires upgrade path exists there.
- **Pets** (`cat`, `dog`): use hardcoded preload paths in `scripts/entities/pet.gd` — migrating them to a hires sheet requires changing that script.
- **Villagers / Players**: use the CharacterBuilder paper-doll system from `characters_sheet.png` — not JSON-driven, outside this tool's scope.
