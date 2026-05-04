# Interior Door Multi-Tile Rendering

**Date:** 2026-05-03  
**Status:** Approved

## Problem

The `interior_terrain` tab in the Game Editor exposes three keys — `floor`, `wall`, and `door` — but only `door` is used at runtime for house interiors:

- `floor`: Fetched for door cells in `_paint_room_walls` but immediately overwritten on the same layer by the door tile — a dead write.
- `wall`: Never read in the house painting path at all.
- `door`: Used, but rendered as a single-cell sprite with no multi-tile support, even though door sprites are typically two tiles tall.

## Goals

1. Remove `floor` and `wall` from the interior terrain data and editor tab.
2. Replace the single-cell door lookup with the same multi-tile convention used by mineables (store TOP cell, derive BOTTOM as `top + Vector2i(0, 1)`).
3. Restructure the editor entry to a `flat_list` kind for clarity.

## Out of Scope

- The generic non-house interior painting path (`_paint_interior` fallback for unknown view kinds) — no active maps use it.
- `is_tall_tile` / `TALL_TILE_KINDS` in TilesetCatalog — unrelated to house path, leave as-is.
- Dungeon/labyrinth door rendering — unchanged.

---

## Data Layer

### `TileMappings` (tile_mappings.gd)

**Keep** the `interior_terrain: Dictionary` `@export` field so existing `.tres` files remain loadable — but stop populating `floor` and `wall` in `default_mappings()`. The field becomes logically deprecated; `_ensure_loaded()` will no longer read from it.

**Add** a new exported field:

```gdscript
## Top atlas cell for the two-tile-tall house interior door (interior_sheet.png).
## Follows the mineable convention: index 0 = top cell; bottom = top + Vector2i(0, 1).
@export var interior_door: Array[Vector2i] = []
```

Default value in `default_mappings()`:

```gdscript
m.interior_door = [Vector2i(20, 8)]   # top cell; bottom = Vector2i(20, 9)
```

### `TilesetCatalog` (tileset_catalog.gd)

Replace `INTERIOR_TERRAIN_CELLS` with a single cell variable:

```gdscript
const _DEFAULT_INTERIOR_DOOR_CELL: Vector2i = Vector2i(20, 8)
static var INTERIOR_DOOR_CELL: Vector2i = _DEFAULT_INTERIOR_DOOR_CELL
```

In `_ensure_loaded()`:
- Read `m.interior_door[0]` if non-empty → populate `INTERIOR_DOOR_CELL`.
- **Migration fallback:** if `interior_door` is empty but old `interior_terrain[&"door"]` exists, treat that value as the BOTTOM cell and subtract `Vector2i(0, 1)` to recover the top cell.

Remove `INTERIOR_TERRAIN_CELLS`, its `_DEFAULT_INTERIOR_TERRAIN` const, and the `&"interior"` / `&"house"` cases from `cell_for()` and `cell_for_variant()`.

Remove `_DEFAULT_SHEETS[&"interior_terrain"]` entry and replace with `&"interior_door"` pointing at `interior_sheet.png`.

---

## Rendering

### `world_root.gd` — `_paint_room_walls`

Replace the current door block:

```gdscript
# BEFORE (dead floor write + door overwrites it on same layer)
if code == TerrainCodes.INTERIOR_DOOR:
    var gfloor = TilesetCatalog.cell_for(&"house", &"floor")
    if gfloor.x >= 0: ground.set_cell(cell, 0, gfloor, 0)
    var door_atlas = TilesetCatalog.cell_for(&"house", &"door")
    if door_atlas.x >= 0: ground.set_cell(cell, 0, door_atlas, 0)
    continue
```

With:

```gdscript
# AFTER — mineable multi-tile convention
if code == TerrainCodes.INTERIOR_DOOR:
    # 1. Floor tile under the door (same as any floor cell)
    ground.set_cell(cell, 1, floor_cell, 0)
    # 2. Door bottom on Decoration (player walks in front of it)
    var door_top: Vector2i = TilesetCatalog.INTERIOR_DOOR_CELL
    decoration.set_cell(cell, 0, door_top + Vector2i(0, 1), 0)
    # 3. Door top on Canopy (player walks behind it, like tree foliage)
    if cell.y > 0:
        canopy.set_cell(cell + Vector2i(0, -1), 0, door_top, 0)
    continue
```

Layer/source mapping:

| Part | Layer | Source ID | Sheet |
|---|---|---|---|
| Floor under door | `ground` | 1 | dungeon_sheet.png (house floor variant) |
| Door bottom | `decoration` | 0 | interior_sheet.png |
| Door top | `canopy` | 0 | interior_sheet.png |

### `house_interior_preview_editor.gd` — `_compute_draw_data`

Update the door entry to carry actual atlas coordinates instead of just `is_door: true`:

```gdscript
if code == TerrainCodes.INTERIOR_DOOR:
    var door_top: Vector2i = TilesetCatalog.INTERIOR_DOOR_CELL
    data.append({
        "cell": cell,
        "floor_atlas": floor_cell,
        "door_top_atlas": door_top,
        "door_bot_atlas": door_top + Vector2i(0, 1),
        "mask": -1,
        "is_door": true,
    })
    # Also emit a synthetic "top" entry one row above for preview rendering.
    if cell.y > 0:
        var top_cell := cell + Vector2i(0, -1)
        data.append({
            "cell": top_cell,
            "door_top_atlas": door_top,
            "mask": -1,
            "is_door_top": true,
        })
    continue
```

Update `_draw()` to render door tiles from atlas instead of drawing a teal rect — draw bottom at `cell`, top at `cell + Vector2i(0, -1)`, and keep the teal border highlight on the bottom cell only for visual identification.

---

## Editor Tab

### `game_editor.gd`

Replace:

```gdscript
{"id": &"interior_terrain", "label": "Interior terrain",
 "sheet": "res://assets/tiles/roguelike/interior_sheet.png",
 "field": &"interior_terrain", "kind": &"list"},
```

With:

```gdscript
{"id": &"interior_door", "label": "Interior door (top cell)",
 "sheet": "res://assets/tiles/roguelike/interior_sheet.png",
 "field": &"interior_door", "kind": &"flat_list"},
```

---

## Files Changed

| File | Change |
|---|---|
| `scripts/data/tile_mappings.gd` | Add `interior_door` field; remove `floor`/`wall` from `interior_terrain` defaults |
| `scripts/world/tileset_catalog.gd` | Replace `INTERIOR_TERRAIN_CELLS` with `INTERIOR_DOOR_CELL`; update `_ensure_loaded`, `cell_for`, `_DEFAULT_SHEETS` |
| `scripts/world/world_root.gd` | Rewrite door block in `_paint_room_walls` |
| `scripts/tools/house_interior_preview_editor.gd` | Update door draw data and rendering |
| `scripts/tools/game_editor.gd` | Swap `interior_terrain` entry for `interior_door` flat_list entry |
