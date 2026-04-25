# Worldmap / Atlas View — Design Spec

**Date:** 2026-04-25  
**Status:** Approved for implementation

---

## Overview

Each player gets a per-viewport worldmap overlay that they can open and close with a key. The map shows only tiles that player has personally walked near (fog of war). The visual style evokes looking down from high altitude: a dark sky background, biome-colored tiles, atmospheric vignette, and a zoom-out open animation.

---

## Input

| Player | Action name | Key |
|--------|-------------|-----|
| P1 | `p1_worldmap` | `KEY_TAB` |
| P2 | `p2_worldmap` | `KEY_KP_9` |

Input actions registered in `project.godot`. Handled in `PlayerController._unhandled_input()`: toggles the player's `WorldMapView` open/closed. While the map is open, `InputContext` is set to `MENU` for that player; restored to `GAMEPLAY` on close. The map consumes all other input while open (except the toggle key itself).

---

## Data Layer — `FogOfWarData`

**File:** `scripts/data/fog_of_war.gd`  
**Extends:** `RefCounted`  
**`class_name FogOfWarData`** — needed so `PlayerController` can type `var fog_of_war: FogOfWarData`. Safe: extends `RefCounted`, no static-method-on-Node quirk.

### Storage

```
var _fog: Dictionary  # Vector2i (region_id) → PackedByteArray (2048 bytes = 128×128 bits)
```

Each bit = one tile. Bit index = `y * 128 + x`. 2 KB per visited region per player.

### API

```gdscript
func reveal(region_id: Vector2i, cell: Vector2i, radius: int) -> void
func is_revealed(region_id: Vector2i, cell: Vector2i) -> bool
func has_region(region_id: Vector2i) -> bool
func to_dict() -> Dictionary   # for save serialization
func from_dict(d: Dictionary) -> void
```

`reveal()` iterates cells in a filled circle of `radius` tiles and sets bits. Cells outside 0–127 are clamped/ignored.

### Reveal timing

`PlayerController` holds a `var fog_of_war: FogOfWarData`. A `Timer` child fires every **0.3 seconds** while the player is alive and in gameplay. On tick: reads `_world._region.region_id` (guarded by `_world != null and _world._region != null` — same pattern as `save_game.gd`) then calls `fog_of_war.reveal(region_id, current_cell, 10)` and calls `queue_redraw()` on the player's `WorldMapView` (if it is open). Radius = **10 tiles**.

---

## Save / Load

`PlayerSaveData` gains:

```gdscript
@export var fog_data: Dictionary = {}
```

`SaveGame.capture()` calls `psd.fog_data = p.fog_of_war.to_dict()`.  
`SaveGame.apply()` calls `p.fog_of_war.from_dict(psd.fog_data)`.

---

## UI — `WorldMapView`

**File:** `scripts/ui/world_map_view.gd`  
**Extends:** `Control`

Built programmatically in `game.gd._build_worldmap_view(container, pid) -> WorldMapView` and stored as `_map_p1` / `_map_p2`. Anchored full-rect to its parent container (fills the player's viewport pane). `visible = false` by default.

### Children (added in `_ready()`)

| Node | Purpose |
|------|---------|
| `VignetteRect: TextureRect` | Full-rect radial vignette overlay |

The vignette `TextureRect` uses a `GradientTexture2D` (fill mode `RADIAL`, transparent center to `Color(0, 0, 0, 0.85)` at edges). Anchored full-rect, mouse filter IGNORE, z-order above map content — achieved by adding it as the last child.

### `set_player(player: PlayerController)`

Stores a reference to the player (for `fog_of_war`, `position`, `_current_region_id`).

### `toggle()`

- If closed: `visible = true` → run open tween → set `InputContext.set_context(pid, InputContext.Context.MENU)`.
- If open: run close tween → on tween completion `visible = false` → restore `InputContext.set_context(pid, InputContext.Context.GAMEPLAY)`.

### Open tween

```
pivot_offset = size / 2
scale = Vector2(0.05, 0.05); modulate.a = 0.0
Tween: scale → Vector2(1,1) over 0.4s EASE_OUT
       modulate.a → 1.0 over 0.3s EASE_IN
```

### Close tween (reverse)

```
Tween: scale → Vector2(0.05, 0.05) over 0.25s EASE_IN
       modulate.a → 0.0 over 0.2s
→ visible = false
```

### `_draw()` pipeline

1. **Sky background:** `draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.15, 1.0))`

2. **Compute bounding box:** Collect all `region_id` keys from `fog_of_war._fog` (regions with any revealed tile). Find min/max X and Y. Expand by 0.5 regions on each side for breathing room. Compute `map_origin: Vector2` (top-left pixel) and `tile_px: float` so the full discovered area fits in 90% of `min(size.x, size.y)`.

   - `tile_px = (0.9 * min(size.x, size.y)) / (bbox_tiles_wide)`
   - `tile_px` is clamped to range `[1.0, 6.0]` to keep it readable.
   - Map is centered in the control.

3. **Tile pass:** For each region in bounding box:
   - If region not in `WorldManager.plans`: draw region rect as solid dark (`Color(0.08, 0.08, 0.1, 1.0)`) — region exists in bbox but was never planned.
   - Else: get `planned_biome` from `WorldManager.plans[region_id]`.
   - For each tile 0–127 × 0–127:
     - If `fog_of_war.is_revealed(region_id, cell)`: draw `Rect2` of `tile_px × tile_px` using biome color.
     - Else: draw same `Rect2` with `Color(0, 0, 0, 0.75)` fog overlay on top of biome color (so biome tints through faintly).
   - Performance note: unrevealed tiles in unvisited regions are skipped (region not in `_fog` at all → draw entire region as dark block in one `draw_rect`, no per-tile loop).

4. **Landmark icons:** For each region in `WorldManager.regions` (fully generated):
   - If `region.dungeon_entrances.size() > 0`: draw filled circle radius 3px, `Color(0.8, 0.3, 0.3)` (red) at the first entrance's cell. Each `dungeon_entrances` entry is a `Dictionary` with a `"cell": Vector2i` key.
   - Only drawn if the landmark cell is revealed.
   - City landmarks are out of scope for this spec (no city cell tracked in `Region` yet).

5. **Player marker:** White filled circle radius 3px at player's current tile position. Pulses alpha via `sin(Time.get_ticks_msec() * 0.004)` mapped to 0.5–1.0. Calls `queue_redraw()` from `_process()` only while visible, to animate the pulse.

### Biome color table (inside `WorldMapView`)

```gdscript
const BIOME_COLORS: Dictionary = {
    &"grass":  Color(0.35, 0.65, 0.25),
    &"water":  Color(0.15, 0.40, 0.75),
    &"desert": Color(0.85, 0.75, 0.45),
    &"swamp":  Color(0.30, 0.45, 0.25),
    &"snow":   Color(0.90, 0.93, 0.98),
    &"cave":   Color(0.30, 0.25, 0.20),
    &"ocean":  Color(0.08, 0.25, 0.60),
}
const BIOME_COLOR_FALLBACK: Color = Color(0.25, 0.25, 0.25)
```

---

## `game.gd` Changes

```gdscript
var _map_p1: WorldMapView = null
var _map_p2: WorldMapView = null
```

`_build_worldmap_view(container: Control, pid: int) -> WorldMapView` — creates `WorldMapView`, names it `"WorldMap"`, anchors full-rect, adds to container.

Called in `_ready()` before `_wire_hud_and_cameras`:
```gdscript
_map_p1 = _build_worldmap_view(_container_p1, 0)
_map_p2 = _build_worldmap_view(_container_p2, 1)
```

In `_wire_hud_and_cameras()`:
```gdscript
if p1 != null:
    _map_p1.set_player(p1)
    p1.world_map = _map_p1
if p2 != null:
    _map_p2.set_player(p2)
    p2.world_map = _map_p2
```

---

## `PlayerController` Changes

New fields:
```gdscript
var fog_of_war: FogOfWarData = FogOfWarData.new()
var world_map: WorldMapView = null   # set by game.gd
```

New child node: `Timer` named `"FogRevealTimer"`, `wait_time = 0.3`, `autostart = true`, `one_shot = false`. Connected to `_on_fog_reveal_timer_timeout()`:
```gdscript
func _on_fog_reveal_timer_timeout() -> void:
    if _world == null or _world._region == null:
        return
    fog_of_war.reveal(_world._region.region_id, _get_current_cell(), 10)
    if world_map != null and world_map.visible:
        world_map.queue_redraw()
```

`_get_current_cell() -> Vector2i` — divides world position by `WorldConst.TILE_PX` and floors.

Input handling in `_unhandled_input(event)`:
```gdscript
var map_action: StringName = &"p1_worldmap" if player_id == 0 else &"p2_worldmap"
if event.is_action_pressed(map_action) and world_map != null:
    world_map.toggle()
    get_viewport().set_input_as_handled()
```

---

## Files Changed

| Action | File |
|--------|------|
| **New** | `scripts/data/fog_of_war.gd` |
| **New** | `scripts/ui/world_map_view.gd` |
| **Modified** | `scripts/entities/player_controller.gd` |
| **Modified** | `scripts/main/game.gd` |
| **Modified** | `scripts/data/player_save_data.gd` |
| **Modified** | `scripts/data/save_game.gd` |
| **Modified** | `project.godot` |

---

## Testing

### Unit tests (`tests/unit/test_fog_of_war.gd`)
- `reveal()` marks bits correctly, radius edges are correct
- `is_revealed()` returns false before reveal, true after
- `to_dict()` / `from_dict()` round-trips without data loss
- Reveal on region boundary (cells near 0 or 127) doesn't panic

### Integration tests (`tests/integration/test_worldmap.gd`)
- Opening map sets `InputContext` to MENU, closing restores GAMEPLAY
- Fog data is preserved through `SaveGame.capture()` / `apply()` round-trip
- Player marker position updates match player world position

---

## Out of Scope (this spec)

- Scrolling/panning the map (fixed auto-fit only for now)
- Zoom controls
- Named location labels
- Minimap (persistent small corner map)
- Co-op: sharing fog between players
