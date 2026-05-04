# Interior Door Multi-Tile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove dead `floor`/`wall` entries from interior terrain data, restructure the editor tab, and upgrade door rendering to the same two-tile multi-tile convention used by mineables.

**Architecture:** The door's top atlas cell is stored in a new `interior_door` field on `TileMappings`. `TilesetCatalog` exposes it as `INTERIOR_DOOR_CELL`. The house painter in `WorldRoot._paint_room_walls` uses it to paint the bottom tile on `Decoration` and the top on `Canopy` — identical layering to tree foliage in the mineable system.

**Tech Stack:** GDScript / Godot 4.x, TileMapLayer rendering, `TileMappings` resource system

**Spec:** `docs/superpowers/specs/2026-05-03-interior-door-multitile-design.md`

---

### Task 1: Add `interior_door` field to TileMappings and deprecate old entries

**Files:**
- Modify: `scripts/data/tile_mappings.gd:117-149` (interior section) and `scripts/data/tile_mappings.gd:386-390` (default_mappings interior_terrain block)

- [ ] **Step 1: Add the new `interior_door` export field**

In `scripts/data/tile_mappings.gd`, after the existing `interior_terrain` export (line 120), add:

```gdscript
## Top atlas cell for the two-tile-tall house interior door (interior_sheet.png).
## Follows the mineable convention: index 0 = top cell; bottom = top + Vector2i(0, 1).
@export var interior_door: Array[Vector2i] = []
```

- [ ] **Step 2: Strip floor/wall from `interior_terrain` in `default_mappings()`**

In `scripts/data/tile_mappings.gd`, replace the `interior_terrain` block (lines 386-390):

```gdscript
	m.interior_terrain = {
		&"floor": [Vector2i(5, 13)],
		&"wall":  [Vector2i(5, 1)],
		&"door":  [Vector2i(20, 9)],
	}
```

With:

```gdscript
	# interior_terrain kept empty — field is deprecated but retained so
	# existing .tres files still load without errors.
	m.interior_terrain = {}
	# Door top cell: bottom is derived as top + Vector2i(0, 1).
	m.interior_door = [Vector2i(20, 8)]
```

- [ ] **Step 3: Commit**

```
git add scripts/data/tile_mappings.gd
git commit -m "feat: add interior_door field to TileMappings, deprecate interior_terrain entries"
```

---

### Task 2: Replace `INTERIOR_TERRAIN_CELLS` with `INTERIOR_DOOR_CELL` in TilesetCatalog

**Files:**
- Modify: `scripts/world/tileset_catalog.gd`

This task touches four areas of the file: the constants/statics block, `_DEFAULT_SHEETS`, `_ensure_loaded()`, and `cell_for()`/`cell_for_variant()`.

- [ ] **Step 1: Replace the constant and static var**

In `scripts/world/tileset_catalog.gd`, replace lines 450-457:

```gdscript
# Interior sheet: wood floor, wood wall.
# Same `Array[Vector2i]` schema as `OVERWORLD_TERRAIN_CELLS`.
const _DEFAULT_INTERIOR_TERRAIN: Dictionary = {
	&"floor": [Vector2i(5, 13)],
	&"wall":  [Vector2i(5, 1)],
	&"door":  [Vector2i(20, 9)],
}
static var INTERIOR_TERRAIN_CELLS: Dictionary = _DEFAULT_INTERIOR_TERRAIN
```

With:

```gdscript
# Interior door: top atlas cell on interior_sheet.png.
# Bottom cell is derived as top + Vector2i(0, 1) at paint time.
const _DEFAULT_INTERIOR_DOOR_CELL: Vector2i = Vector2i(20, 8)
static var INTERIOR_DOOR_CELL: Vector2i = _DEFAULT_INTERIOR_DOOR_CELL
```

- [ ] **Step 2: Update `_DEFAULT_SHEETS`**

In `scripts/world/tileset_catalog.gd`, replace line 36:

```gdscript
	&"interior_terrain": "res://assets/tiles/roguelike/interior_sheet.png",
```

With:

```gdscript
	&"interior_door": "res://assets/tiles/roguelike/interior_sheet.png",
```

- [ ] **Step 3: Update `_sheet_for_view` for interior**

In `scripts/world/tileset_catalog.gd`, replace lines 85-86:

```gdscript
		&"interior":
			return get_sheet_path(&"interior_terrain")
```

With:

```gdscript
		&"interior":
			return get_sheet_path(&"interior_door")
```

- [ ] **Step 4: Update `_ensure_loaded()` — interior section**

In `scripts/world/tileset_catalog.gd`, replace lines 620-622:

```gdscript
	# Interior
	if not m.interior_terrain.is_empty():
		INTERIOR_TERRAIN_CELLS = m.interior_terrain
```

With:

```gdscript
	# Interior door (mineable convention: top cell stored, bottom derived)
	if not m.interior_door.is_empty():
		INTERIOR_DOOR_CELL = m.interior_door[0]
	elif not m.interior_terrain.is_empty():
		# Migration fallback: old interior_terrain stored the BOTTOM cell.
		var old_door: Variant = m.interior_terrain.get(&"door", null)
		if old_door is Array and not (old_door as Array).is_empty():
			INTERIOR_DOOR_CELL = (old_door as Array)[0] + Vector2i(0, -1)
```

- [ ] **Step 5: Update `interior()` TileSet builder**

In `scripts/world/tileset_catalog.gd`, replace lines 688-691:

```gdscript
	if _interior_ts == null:
		var sheet := _sheet_for_view(&"interior")
		_interior_ts = _build(sheet, INTERIOR_TERRAIN_CELLS, false,
				SheetSpecReader.read(sheet))
```

With:

```gdscript
	if _interior_ts == null:
		var sheet := _sheet_for_view(&"interior")
		# Pass a minimal terrain dict so door cells get walkable=true tagging.
		var door_bottom: Vector2i = INTERIOR_DOOR_CELL + Vector2i(0, 1)
		var terrain_for_build: Dictionary = {
			&"door": [INTERIOR_DOOR_CELL, door_bottom],
		}
		_interior_ts = _build(sheet, terrain_for_build, false,
				SheetSpecReader.read(sheet))
```

- [ ] **Step 6: Remove `&"interior"` / `&"house"` from `cell_for()` and `cell_for_variant()`**

In `scripts/world/tileset_catalog.gd`, delete line 907:

```gdscript
		&"interior", &"house": d = INTERIOR_TERRAIN_CELLS
```

And delete line 932:

```gdscript
		&"interior", &"house": d = INTERIOR_TERRAIN_CELLS
```

Both functions already fall through to `return Vector2i(-1, -1)` for unmatched view kinds, so no replacement is needed — the removed arms were the only consumers of `INTERIOR_TERRAIN_CELLS`.

- [ ] **Step 7: Commit**

```
git add scripts/world/tileset_catalog.gd
git commit -m "refactor: replace INTERIOR_TERRAIN_CELLS with INTERIOR_DOOR_CELL in TilesetCatalog"
```

---

### Task 3: Rewrite door rendering in `_paint_room_walls`

**Files:**
- Modify: `scripts/world/world_root.gd:553-561`

- [ ] **Step 1: Replace the door block**

In `scripts/world/world_root.gd`, replace lines 553-561:

```gdscript
			if code == TerrainCodes.INTERIOR_DOOR:
				# Door: use interior_sheet floor on ground + door sprite on decoration.
				var gfloor: Vector2i = TilesetCatalog.cell_for(&"house", &"floor")
				if gfloor.x >= 0:
					ground.set_cell(cell, 0, gfloor, 0)
				var door_atlas: Vector2i = TilesetCatalog.cell_for(&"house", &"door")
				if door_atlas.x >= 0:
					ground.set_cell(cell, 0, door_atlas, 0)
				continue
```

With:

```gdscript
			if code == TerrainCodes.INTERIOR_DOOR:
				# Floor under the door (same house floor as regular floor cells).
				ground.set_cell(cell, 1, floor_cell, 0)
				# Door bottom on Decoration (player walks in front of it).
				var door_top: Vector2i = TilesetCatalog.INTERIOR_DOOR_CELL
				decoration.set_cell(cell, 0, door_top + Vector2i(0, 1), 0)
				# Door top on Canopy (player walks behind it, like tree foliage).
				if cell.y > 0:
					canopy.set_cell(cell + Vector2i(0, -1), 0, door_top, 0)
				continue
```

- [ ] **Step 2: Commit**

```
git add scripts/world/world_root.gd
git commit -m "feat: render interior doors as two-tile sprites using mineable convention"
```

---

### Task 4: Update the house interior preview editor

**Files:**
- Modify: `scripts/tools/house_interior_preview_editor.gd`

The preview editor needs two changes: (a) `_compute_draw_data` must emit door atlas cells for both the bottom and the synthetic top entry, and (b) `_draw()` must render them from the atlas instead of just drawing a teal highlight box.

The preview uses `_texture` which is loaded from `dungeon_sheet.png` (source_id=1 of the interior TileSet). Door sprites live on `interior_sheet.png` (source_id=0). We need a second texture reference.

- [ ] **Step 1: Add a second texture for door sprites**

In `scripts/tools/house_interior_preview_editor.gd`, after line 30 (`var _texture: Texture2D = null`), add:

```gdscript
var _door_texture: Texture2D = null
```

In `_ready()`, after line 150 (`_texture = load(DUNGEON_PNG) as Texture2D`), add:

```gdscript
	var int_src := ts.get_source(0) as TileSetAtlasSource
	if int_src != null:
		_door_texture = int_src.texture
```

- [ ] **Step 2: Update `_compute_draw_data` door handling**

In `scripts/tools/house_interior_preview_editor.gd`, replace lines 261-263:

```gdscript
			if code == TerrainCodes.INTERIOR_DOOR:
				data.append({"cell": cell, "floor_atlas": floor_cell, "mask": -1, "is_door": true})
				continue
```

With:

```gdscript
			if code == TerrainCodes.INTERIOR_DOOR:
				var door_top: Vector2i = TilesetCatalog.INTERIOR_DOOR_CELL
				data.append({
					"cell": cell,
					"floor_atlas": floor_cell,
					"door_bot_atlas": door_top + Vector2i(0, 1),
					"mask": -1,
					"is_door": true,
				})
				if cell.y > 0:
					data.append({
						"cell": cell + Vector2i(0, -1),
						"door_top_atlas": door_top,
						"mask": -1,
						"is_door_top": true,
					})
				continue
```

- [ ] **Step 3: Update `_draw()` to render door sprites**

In `scripts/tools/house_interior_preview_editor.gd`, in the `_HouseView._draw()` method, replace lines 130-131:

```gdscript
			if d.get("is_door", false):
				draw_rect(dest, Color(0.0, 0.8, 0.8, 0.7), false, 2.0)
```

With:

```gdscript
			var dba: Vector2i = d.get("door_bot_atlas", Vector2i(-1, -1))
			if dba.x >= 0 and door_texture != null:
				var src := Rect2(float(dba.x * src_step), float(dba.y * src_step),
					float(tile_px), float(tile_px))
				draw_texture_rect_region(door_texture, dest, src)
			var dta: Vector2i = d.get("door_top_atlas", Vector2i(-1, -1))
			if dta.x >= 0 and door_texture != null:
				var src := Rect2(float(dta.x * src_step), float(dta.y * src_step),
					float(tile_px), float(tile_px))
				draw_texture_rect_region(door_texture, dest, src)
			if d.get("is_door", false):
				draw_rect(dest, Color(0.0, 0.8, 0.8, 0.7), false, 2.0)
```

- [ ] **Step 4: Pass `_door_texture` into `_HouseView`**

The inner `_HouseView` class needs access to the door texture. Add a `door_texture` property to `_HouseView`.

In `scripts/tools/house_interior_preview_editor.gd`, after line 49 (`var texture: Texture2D = null`), add:

```gdscript
		var door_texture: Texture2D = null
```

In the `setup()` function (line 64), update the signature and body. Replace lines 64-73:

```gdscript
	func setup(tex: Texture2D, im: InteriorMap, data: Array) -> void:
		texture = tex
		interior = im
		draw_data = data
		_hovered = Vector2i(-1, -1)
		if im != null:
			custom_minimum_size = Vector2(
				float(im.width * tile_px * zoom),
				float(im.height * tile_px * zoom))
		queue_redraw()
```

With:

```gdscript
	func setup(tex: Texture2D, door_tex: Texture2D, im: InteriorMap, data: Array) -> void:
		texture = tex
		door_texture = door_tex
		interior = im
		draw_data = data
		_hovered = Vector2i(-1, -1)
		if im != null:
			custom_minimum_size = Vector2(
				float(im.width * tile_px * zoom),
				float(im.height * tile_px * zoom))
		queue_redraw()
```

- [ ] **Step 5: Update `_refresh` to pass the door texture**

In `scripts/tools/house_interior_preview_editor.gd`, replace line 233:

```gdscript
		_view.setup(_texture, interior, data)
```

With:

```gdscript
		_view.setup(_texture, _door_texture, interior, data)
```

- [ ] **Step 6: Commit**

```
git add scripts/tools/house_interior_preview_editor.gd
git commit -m "feat: render door sprites in house interior preview editor"
```

---

### Task 5: Swap the Game Editor tab from `interior_terrain` to `interior_door`

**Files:**
- Modify: `scripts/tools/game_editor.gd:89-91`

- [ ] **Step 1: Replace the editor mapping entry**

In `scripts/tools/game_editor.gd`, replace lines 89-91:

```gdscript
	{"id": &"interior_terrain",                  "label": "Interior terrain",
	 "sheet": "res://assets/tiles/roguelike/interior_sheet.png",
	 "field": &"interior_terrain",                  "kind": &"list"},
```

With:

```gdscript
	{"id": &"interior_door",                     "label": "Interior door (top cell)",
	 "sheet": "res://assets/tiles/roguelike/interior_sheet.png",
	 "field": &"interior_door",                     "kind": &"flat_list"},
```

- [ ] **Step 2: Commit**

```
git add scripts/tools/game_editor.gd
git commit -m "refactor: replace interior_terrain editor tab with interior_door flat_list"
```

---

### Task 6: Final audit

- [ ] **Step 1: Grep for stale references**

Run:

```bash
cd /home/mpatterson/repos/game4 && grep -rn "INTERIOR_TERRAIN_CELLS\|interior_terrain\|cell_for.*house.*floor\|cell_for.*house.*wall\|cell_for.*interior" scripts/ --include="*.gd"
```

Expected results should show ONLY:
- `tile_mappings.gd` — the deprecated `@export var interior_terrain` field declaration and the empty assignment in `default_mappings()`
- `tileset_catalog.gd` — the migration fallback in `_ensure_loaded()` reading `m.interior_terrain`
- `game_editor.gd` — no hits (replaced with `interior_door`)

Any other hits are stale references that need cleanup.

- [ ] **Step 2: Verify no circular or missing references**

Check that `TilesetCatalog.INTERIOR_DOOR_CELL` is referenced in:
- `world_root.gd` `_paint_room_walls` (door rendering)
- `house_interior_preview_editor.gd` `_compute_draw_data` (door preview)
- `tileset_catalog.gd` `interior()` (TileSet builder terrain dict)

```bash
cd /home/mpatterson/repos/game4 && grep -rn "INTERIOR_DOOR_CELL" scripts/ --include="*.gd"
```

- [ ] **Step 3: Commit any fixups found in steps 1-2**

Only if needed:

```
git add -p
git commit -m "fix: clean up stale interior_terrain references"
```
