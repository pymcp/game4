# Dungeon Floor Border (3×3) + Autotile Room Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** (A) Add a 3×3 floor-border system so dungeon/labyrinth floors blend into walls with edge tiles (Option C: floor border + keep wall autotile). (B) Replace the flat autotile preview in GameEditor with a synthetic room+hallway scene so the user sees exactly how their wall tiles render in-game.

**Architecture:**
- Floor border: two new `patch3_flat` TileMappings fields (`dungeon_floor_border_3x3`, `labyrinth_floor_border_3x3`), corresponding TilesetCatalog statics, and a second painting pass in `_paint_dungeon_interior` that overwrites each floor cell's Ground tile with the correct border cell based on how many of its 4 orthogonal neighbours are walls. The existing wall-autotile pass is untouched.
- Autotile preview: new `&"autotile_room"` layout in `PreviewView._draw()`. When the active mapping kind is `&"autotile"`, `_refresh_preview()` passes the full autotile dict and a `StringName` layout flag instead of cycling individual cells. `PreviewView` builds a hardcoded 11×11 synthetic map (room + corridor), computes the 4-bit mask for every wall cell, and looks up + draws each cell from the autotile dict exactly as `_paint_dungeon_interior` does.

**Tech Stack:** GDScript, Godot 4.3, `TileMappings` resource, `TilesetCatalog` statics, `game_editor.gd` inner classes.

---

## Files to Create/Modify

| File | Change |
|---|---|
| `scripts/data/tile_mappings.gd` | Add `dungeon_floor_border_3x3` and `labyrinth_floor_border_3x3` `@export` fields + defaults in `default_mappings()` |
| `scripts/world/tileset_catalog.gd` | Add `DUNGEON_FLOOR_BORDER_3X3` and `LABYRINTH_FLOOR_BORDER_3X3` statics; wire in `_ensure_loaded()` |
| `scripts/world/world_root.gd` | Add `_paint_dungeon_floor_border()` helper; call it from `_paint_dungeon_interior()` after the main pass |
| `scripts/tools/game_editor.gd` | Add `_MAPPINGS` entries for the two new fields; add `&"autotile_room"` layout to `PreviewView._draw()`; update `_refresh_preview()` to pass autotile dict when kind is `&"autotile"` |
| `resources/tilesets/tile_mappings.tres` | Reseed via `tools/seed_tile_mappings.gd` |
| `tests/unit/test_tile_mappings_parity.gd` | Add parity assertions for the two new fields |

---

## Task 1: TileMappings — add floor border fields

**Files:**
- Modify: `scripts/data/tile_mappings.gd`

- [ ] **Step 1: Add the two @export fields**

After the existing `@export var dungeon_floor_decor` line (around line 62), add:

```gdscript
## 3×3 border set for dungeon floor cells that are adjacent to walls.
## NW/N/NE/W/C/E/SW/S/SE ordering (same as overworld_terrain_patches_3x3).
## C (index 4) = fully-surrounded "open floor" cell.
## Edge cells = floor meeting wall on one side.
## Corner cells = floor meeting wall on two sides.
## Leave empty to disable floor borders (falls back to plain floor cell).
@export var dungeon_floor_border_3x3: Array[Vector2i] = []

## Same as dungeon_floor_border_3x3 for labyrinth floors.
@export var labyrinth_floor_border_3x3: Array[Vector2i] = []
```

- [ ] **Step 2: Add defaults in `default_mappings()`**

After `m.dungeon_floor_decor = [...]` in `default_mappings()`, add:

```gdscript
# Floor-border 3×3: NW N NE / W C E / SW S SE.
# Defaults to all pointing at the plain floor cell (9,7) — border is
# invisible until the user picks actual transition tiles in the Game Editor.
m.dungeon_floor_border_3x3 = [
    Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),  # NW  N  NE
    Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),  # W   C   E
    Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),  # SW  S  SE
]

m.labyrinth_floor_border_3x3 = [
    Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),
    Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),
    Vector2i(9, 7), Vector2i(9, 7), Vector2i(9, 7),
]
```

- [ ] **Step 3: Verify parse — run seed script (expect "seeded: ..." — will fail until Task 3)**

---

## Task 2: TilesetCatalog — add statics and wire _ensure_loaded

**Files:**
- Modify: `scripts/world/tileset_catalog.gd`

- [ ] **Step 1: Add the two statics**

After the `DUNGEON_FLOOR_DECOR_CELLS` static (around line 275), add:

```gdscript
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
```

- [ ] **Step 2: Wire in `_ensure_loaded()`**

In `_ensure_loaded()`, after the labyrinth floor decor block, add:

```gdscript
if m.dungeon_floor_border_3x3.size() == 9:
    DUNGEON_FLOOR_BORDER_3X3 = m.dungeon_floor_border_3x3
if m.labyrinth_floor_border_3x3.size() == 9:
    LABYRINTH_FLOOR_BORDER_3X3 = m.labyrinth_floor_border_3x3
```

---

## Task 3: Reseed tile_mappings.tres

**Files:**
- Modify: `resources/tilesets/tile_mappings.tres` (via seed script)

- [ ] **Step 1: Run the seed script**

```bash
cd /home/mpatterson/repos/game4
godot --headless -s tools/seed_tile_mappings.gd 2>&1 | tail -3
```

Expected output: `seeded: res://resources/tilesets/tile_mappings.tres`

- [ ] **Step 2: Update parity test to assert the new fields**

In `tests/unit/test_tile_mappings_parity.gd`, after the existing labyrinth assertions, add:

```gdscript
assert_true(loaded.dungeon_floor_border_3x3.size() == 9,
    "dungeon_floor_border_3x3 must have 9 cells")
assert_true(loaded.labyrinth_floor_border_3x3.size() == 9,
    "labyrinth_floor_border_3x3 must have 9 cells")
```

- [ ] **Step 3: Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "All tests|failing"
```

Expected: `---- All tests passed! ----`

- [ ] **Step 4: Commit**

```bash
git add scripts/data/tile_mappings.gd scripts/world/tileset_catalog.gd resources/tilesets/tile_mappings.tres tests/unit/test_tile_mappings_parity.gd
git commit -m "feat: add dungeon/labyrinth floor border 3x3 fields to TileMappings + TilesetCatalog"
```

---

## Task 4: WorldRoot — floor border painting pass

**Files:**
- Modify: `scripts/world/world_root.gd`

The floor-border pass runs *after* the main `_paint_dungeon_interior` loop and overwrites only the Ground layer for floor-like cells. The check mirrors `_patch_index_for_neighbors` from the overworld: for each floor cell, look at its 4 orthogonal neighbours; if all are floor → index 4 (centre, open). If any neighbour is wall → pick NW/N/NE/W/C/E/SW/S/SE from the 3×3 table.

Wall neighbours are detected with the same `_dungeon_neighbour_is_floor` helper (a cell is a "wall neighbour" if `_dungeon_neighbour_is_floor` returns false for it).

- [ ] **Step 1: Add `_dungeon_floor_border_index` static helper**

Add after `_dungeon_neighbour_is_floor`:

```gdscript
## Returns the NW…SE index (0..8) into the floor-border 3×3 for a floor
## cell, based on which orthogonal neighbours are wall (not floor-like).
static func _dungeon_floor_border_index(interior: InteriorMap,
        cell: Vector2i) -> int:
    var n_floor: bool = _dungeon_neighbour_is_floor(interior, cell + Vector2i(0, -1))
    var s_floor: bool = _dungeon_neighbour_is_floor(interior, cell + Vector2i(0,  1))
    var w_floor: bool = _dungeon_neighbour_is_floor(interior, cell + Vector2i(-1, 0))
    var e_floor: bool = _dungeon_neighbour_is_floor(interior, cell + Vector2i( 1, 0))
    # Corner cases first (two open sides meeting a wall corner).
    if not n_floor and not w_floor: return 0  # NW
    if not n_floor and not e_floor: return 2  # NE
    if not s_floor and not w_floor: return 6  # SW
    if not s_floor and not e_floor: return 8  # SE
    # Edge cases (one open side).
    if not n_floor: return 1  # N
    if not s_floor: return 7  # S
    if not w_floor: return 3  # W
    if not e_floor: return 5  # E
    return 4  # fully surrounded by floor — open centre
```

- [ ] **Step 2: Add `_paint_dungeon_floor_border` helper**

Add after `_paint_dungeon_interior`:

```gdscript
## Overwrite the Ground layer for every floor-like cell with the
## matching 3×3 border cell so floors that meet walls get edge art.
## Cells whose border resolves to index 4 (open centre) keep the plain
## floor cell — the border and floor cell are the same when no 3×3 is
## configured, so this is always safe to call.
func _paint_dungeon_floor_border(interior: InteriorMap,
        border_cells: Array) -> void:
    if border_cells.size() < 9:
        return
    for y in interior.height:
        for x in interior.width:
            var cell := Vector2i(x, y)
            var code: int = interior.at(cell)
            var is_floor_like: bool = (
                    code == TerrainCodes.INTERIOR_FLOOR
                    or code == TerrainCodes.INTERIOR_STAIRS_UP
                    or code == TerrainCodes.INTERIOR_STAIRS_DOWN)
            if not is_floor_like:
                continue
            var bidx: int = _dungeon_floor_border_index(interior, cell)
            var atlas: Vector2i = border_cells[bidx]
            ground.set_cell(cell, 0, atlas, 0)
```

- [ ] **Step 3: Call `_paint_dungeon_floor_border` from `_paint_dungeon_interior`**

At the end of `_paint_dungeon_interior`, just before `_paint_dungeon_corridor_frames(interior)`, add:

```gdscript
# Floor border pass — overwrites Ground with edge/corner tiles where
# floor meets wall. No-op when border_cells are all the plain floor cell.
var floor_border: Array = (TilesetCatalog.LABYRINTH_FLOOR_BORDER_3X3
        if view_kind == &"labyrinth" else TilesetCatalog.DUNGEON_FLOOR_BORDER_3X3)
_paint_dungeon_floor_border(interior, floor_border)
```

- [ ] **Step 4: Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "All tests|failing"
```

Expected: `---- All tests passed! ----`

- [ ] **Step 5: Commit**

```bash
git add scripts/world/world_root.gd
git commit -m "feat: dungeon/labyrinth floor border painting pass (3x3)"
```

---

## Task 5: GameEditor — two new mapping entries

**Files:**
- Modify: `scripts/tools/game_editor.gd`

- [ ] **Step 1: Add entries to `_MAPPINGS`**

In `_MAPPINGS`, after the `dungeon_floor_decor` entry (and before the `labyrinth_entrance_pair` entry), insert:

```gdscript
{"id": &"dungeon_floor_border_3x3",        "label": "Dungeon floor border (3×3)",
 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
 "field": &"dungeon_floor_border_3x3",     "kind": &"patch3_flat"},
```

After the `labyrinth_floor_decor` entry and before `labyrinth_chest_pair`, insert:

```gdscript
{"id": &"labyrinth_floor_border_3x3",      "label": "Labyrinth floor border (3×3)",
 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
 "field": &"labyrinth_floor_border_3x3",   "kind": &"patch3_flat"},
```

- [ ] **Step 2: Run unit tests to verify no regressions**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "All tests|failing"
```

---

## Task 6: GameEditor — autotile room preview

**Files:**
- Modify: `scripts/tools/game_editor.gd`

The autotile preview currently cycles individual atlas cells in a flat 5×5 grid. Replace this for the `&"autotile"` kind with a synthetic 11×11 "room + hallway" scene. `PreviewView` receives a pre-built autotile dict (`{mask_int: [atlas_cell, flip_v]}`) instead of a flat cell list, and uses the new `&"autotile_room"` layout.

### 6A — Extend PreviewView to accept autotile dict

- [ ] **Step 1: Add `autotile_dict` field and `set_autotile_data` method to `PreviewView`**

In the `PreviewView extends Control:` inner class, add after `var layout: StringName = &"tile"`:

```gdscript
## Autotile mask→[cell, flip_v] dict. Only used when layout == &"autotile_room".
var autotile_dict: Dictionary = {}
```

Add a new method after `set_data`:

```gdscript
func set_autotile_data(tex: Texture2D, at_dict: Dictionary) -> void:
    texture = tex
    autotile_dict = at_dict
    cells = []  # not used for autotile_room layout
    layout = &"autotile_room"
    _resize()
    queue_redraw()
```

- [ ] **Step 2: Add room constants and `_draw_autotile_room` to `PreviewView`**

Add after `_resize()`:

```gdscript
# Synthetic 11×11 map used for the autotile room preview.
# 0 = wall, 1 = floor. Layout: a 5×5 room (cols 1-5, rows 1-5) connected
# by a 2-wide corridor (cols 3-4, rows 6-9) exiting south.
const _ROOM_W: int = 11
const _ROOM_H: int = 11
const _ROOM_MAP: Array = [
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
    [0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
]

func _neighbour_is_floor(gx: int, gy: int) -> bool:
    if gx < 0 or gx >= _ROOM_W or gy < 0 or gy >= _ROOM_H:
        return false
    return _ROOM_MAP[gy][gx] == 1

func _draw_autotile_room(src_step: int, dest_step: float) -> void:
    var floor_entry: Variant = autotile_dict.get(15, null)  # mask 15 = all floors → use as floor tile
    # Fallback: pick any entry's cell for floor if mask-15 absent
    var floor_atlas: Vector2i = Vector2i(0, 0)
    if floor_entry is Array and (floor_entry as Array).size() >= 1:
        floor_atlas = (floor_entry as Array)[0]
    elif not autotile_dict.is_empty():
        var first: Variant = autotile_dict.values()[0]
        if first is Array and (first as Array).size() >= 1:
            floor_atlas = (first as Array)[0]
    var bg_floor := Color(0.18, 0.16, 0.14)
    for gy in _ROOM_H:
        for gx in _ROOM_W:
            var dest := Rect2(
                Vector2(float(gx) * dest_step, float(gy) * dest_step),
                Vector2(dest_step, dest_step))
            if _ROOM_MAP[gy][gx] == 1:
                # Floor cell — draw floor atlas tile
                var src := Rect2(
                    float(floor_atlas.x * src_step),
                    float(floor_atlas.y * src_step),
                    float(tile_px), float(tile_px))
                draw_texture_rect_region(texture, dest, src)
            else:
                # Wall cell — compute 4-bit mask and look up autotile
                var mask: int = 0
                if _neighbour_is_floor(gx, gy - 1): mask |= 8  # N
                if _neighbour_is_floor(gx, gy + 1): mask |= 4  # S
                if _neighbour_is_floor(gx + 1, gy): mask |= 2  # E
                if _neighbour_is_floor(gx - 1, gy): mask |= 1  # W
                if mask == 0:
                    # Isolated wall — dark background only
                    draw_rect(dest, bg_floor, true)
                    continue
                var entry: Variant = autotile_dict.get(mask, null)
                if entry == null or not (entry is Array):
                    draw_rect(dest, bg_floor, true)
                    continue
                var arr: Array = entry
                var atlas: Vector2i = arr[0]
                var flip_v: bool = arr[1] if arr.size() > 1 else false
                var src := Rect2(
                    float(atlas.x * src_step),
                    float(atlas.y * src_step),
                    float(tile_px), float(tile_px))
                if flip_v:
                    # Draw flipped: draw normal then flip vertically via transform
                    draw_set_transform(
                        Vector2(dest.position.x, dest.position.y + dest_step),
                        0.0,
                        Vector2(1.0, -1.0) * dest_step / float(tile_px))
                    draw_texture_rect_region(texture,
                        Rect2(Vector2.ZERO, Vector2(float(tile_px), float(tile_px))),
                        src)
                    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
                else:
                    draw_texture_rect_region(texture, dest, src)
```

- [ ] **Step 3: Add the `&"autotile_room"` case to `_draw()`**

In `_draw()`, in the `match layout:` block, add before the `_:` fallthrough:

```gdscript
&"autotile_room":
    if autotile_dict.is_empty():
        return
    var dest_step: float = float(tile_px * PREVIEW_ZOOM)
    var src_step: int = tile_px + gutter
    _resize_for_room()
    _draw_autotile_room(src_step, dest_step)
```

And add `_resize_for_room()` to handle the larger frame:

```gdscript
func _resize_for_room() -> void:
    custom_minimum_size = Vector2(
        float(_ROOM_W * tile_px * PREVIEW_ZOOM),
        float(_ROOM_H * tile_px * PREVIEW_ZOOM))
```

Update `_resize()` to branch on layout:

```gdscript
func _resize() -> void:
    if layout == &"autotile_room":
        custom_minimum_size = Vector2(
            float(_ROOM_W * tile_px * PREVIEW_ZOOM),
            float(_ROOM_H * tile_px * PREVIEW_ZOOM))
    else:
        custom_minimum_size = Vector2(
            float(FRAME * tile_px * PREVIEW_ZOOM),
            float(FRAME * tile_px * PREVIEW_ZOOM))
```

### 6B — Wire _refresh_preview for autotile kind

- [ ] **Step 4: Update `_refresh_preview()` to call `set_autotile_data` for autotile kind**

In `_refresh_preview()`, at the top of the `match kind:` block, add a new case:

```gdscript
&"autotile":
    var field: StringName = _current_mapping["field"]
    var arr: Array = _mappings_resource.get(field)
    var at_dict: Dictionary = {}
    for entry in arr:
        var mask: int = int(entry.get("mask", -1))
        if mask < 0:
            continue
        var cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
        var flip_v: bool = int(entry.get("flip", 0)) != 0
        at_dict[mask] = [cell, flip_v]
    _preview.set_autotile_data(tex, at_dict)
    return
```

This must appear before the existing `match kind:` cases (or be inserted into the match as a named case), so it returns before the general loop.

- [ ] **Step 5: Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "All tests|failing"
```

Expected: `---- All tests passed! ----`

- [ ] **Step 6: Commit**

```bash
git add scripts/tools/game_editor.gd
git commit -m "feat: autotile room preview in GameEditor; floor border mapping entries"
```

---

## Task 7: Final integration commit

- [ ] **Step 1: Run all tests (unit + integration)**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | grep -E "All tests|failing"
```

Expected: `---- All tests passed! ----`

- [ ] **Step 2: Commit everything not yet committed**

```bash
git add -A
git commit -m "feat: dungeon/labyrinth floor border 3x3 + autotile room preview complete"
```

---

## Self-Review Checklist

- [x] TileMappings fields added with correct typed exports
- [x] `default_mappings()` populated with 9-cell arrays pointing at the plain floor cell (safe no-op default)
- [x] TilesetCatalog statics initialised from the same defaults; `_ensure_loaded()` guards on `.size() == 9`
- [x] `_paint_dungeon_floor_border` only touches the Ground layer — wall autotile (Decoration layer) untouched
- [x] `_dungeon_floor_border_index` uses same `_dungeon_neighbour_is_floor` helper as the wall pass — consistent definition of "is floor"
- [x] `set_autotile_data` + `set_data` are independent methods — no existing callers broken
- [x] flip_v rendering in `_draw_autotile_room` uses `draw_set_transform` (Godot 4 CanvasItem approach)
- [x] Parity test covers both new fields
- [x] Default all-same-cell border means zero visual change until the user picks distinct tiles
