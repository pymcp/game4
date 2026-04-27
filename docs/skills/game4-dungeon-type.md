# Adding a New Dungeon Type to game4

Use when adding a new `InteriorMap`-based dungeon/interior type to this project.

## Checklist: Every New Dungeon Type Touches These Systems

### 1. Generator (`scripts/world/<name>_generator.gd`)
- `class_name <Name>Generator`, extends `RefCounted`
- `static func generate(seed_val: int, width: int, height: int, floor_num: int) -> InteriorMap`
- Fill `InteriorMap.tiles` with `TerrainCodes.INTERIOR_WALL`, carve floor cells
- Set `m.entry_cell`, `m.exit_cell` with `TerrainCodes.INTERIOR_STAIRS_UP/DOWN`
- Populate `m.npcs_scatter`, `m.loot_scatter`, and any new scatter arrays
- Use `EncounterTableRegistry.get_weighted_list("your_kind", floor_num)` for enemies
- `MAX_SIZE` on `InteriorMap` constrains width/height

### 2. MapManager (`scripts/autoload/map_manager.gd`)
- `make_id(rid, cell, floor, kind)` — pass your kind StringName, e.g. `&"labyrinth"`
- `get_or_generate(map_id, rid, cell, floor, size, kind)` — add your kind to the `if kind ==` block
- `descend_from(current)` — uses `_kind_from_id(map_id)` to extract kind; kind is preserved automatically
- Floor ID format: `"<kind>@rx:ry:cx:cy:floor"`

### 3. ViewManager (`scripts/autoload/view_manager.gd`)
- `enter_interior(pid, interior, view_kind)` — no change needed; accepts any StringName
- `get_view_kind(pid)` — returns whatever view_kind was passed; no registration required

### 4. WorldRoot (`scripts/world/world_root.gd`)
- `_attach_interior_tilesets(view_kind)`: add a match case for your kind → correct TileSet
- `_paint_interior(interior, view_kind)`: add a match case or condition to call the right painter
- `_build_door_index(view_kind)`:
  - Overworld branch: add `elif ek == &"your_kind": _doors[c] = {"kind": &"your_kind_enter", "cell": c}`
  - Interior branch: add `or view_kind == &"your_kind"` to the stairs condition
- `_handle_door(player, door, cell)`:
  - Add `&"your_kind_enter"` case — call `MapManager.get_or_generate(mid, rid, cell, 1, size, &"your_kind")`, then `World.instance().transition_player(pid, &"your_kind", region, interior)`
  - `stairs_up` parent transition: use `WorldRoot._view_kind_from_interior(parent)` helper to preserve kind
- `debug_spawn_interactables_for(player)`: add `_debug_place_entrance(&"your_kind", &"your_kind_enter", centre, offset, "label")`
- `_view_kind_from_interior(interior)` static helper: derives view_kind from map_id prefix via `MapManager._kind_from_id()`

### 5. WorldGenerator (`scripts/world/world_generator.gd`)
- Add `_place_<name>_entrances(region)` — same structure as `_place_dungeon_entrances()` but appends `{"kind": &"your_kind", "cell": cell}`
- Call it from `generate_region()` after `_place_dungeon_entrances()`
- Control frequency via a rate constant (labyrinth: ~35% of regions via `rng.randf() > 0.35`)

### 6. TileMappings + TilesetCatalog
- Add `@export var <name>_entrance_pair: Array[Vector2i] = []` to `scripts/data/tile_mappings.gd`
- Add `&"<name>_entrance_pair": "res://assets/tiles/roguelike/<sheet>.png"` to `TilesetCatalog._DEFAULT_SHEETS`
- Add `const _DEFAULT_<NAME>_ENTRANCE: Array = [Vector2i(x,y), ...]` + `static var <NAME>_OVERWORLD_ENTRANCE_CELLS` to TilesetCatalog
- Load it in `_ensure_loaded()` from `TileMappings`
- Update `_paint_overworld_entrance_markers()` to use the correct cells + tint for your kind
- Add entry to `scripts/tools/game_editor.gd` `_MAPPINGS` array so SpritePicker can edit it

### 7. Depth-Scaled Enemies (if applicable)
- Add your dungeon type to `resources/encounter_tables.json`: `{"your_kind": {"boss_interval": N, "enemy_tables": [...]}}`
- `EncounterTableRegistry.get_weighted_list(&"your_kind", floor_num)` returns filtered, weighted entries
- Editable in GameEditor → "Encounter Tables (Depth)"

### 8. Tests
- Unit: generator connectivity, minimum dead-end count, boss room presence on boss floors
- Integration: `MapManager.make_id(rid, cell, 1, &"your_kind")` → descend 3 floors, verify `_kind_from_id` returns your kind, verify `view_kind` remains correct after transition

## Key Code Patterns

### Preserving kind through `descend_from`
```gdscript
# MapManager.descend_from extracts kind from the current map_id prefix:
var kind: StringName = _kind_from_id(current.map_id)
var new_id: StringName = make_id(rid, origin, next_floor, kind)
var m: InteriorMap = get_or_generate(new_id, rid, origin, next_floor, size, kind)
```

### Deriving view_kind from an InteriorMap
```gdscript
static func _view_kind_from_interior(interior: InteriorMap) -> StringName:
    if interior == null:
        return &"overworld"
    return MapManager._kind_from_id(interior.map_id)
```

### Overworld entrance tint
Dungeon = `Color.WHITE`, house = `Color(1.4, 0.95, 0.6)` (warm yellow), labyrinth = `Color(1.2, 0.6, 1.4)` (purple). Add your kind with a distinct color.
