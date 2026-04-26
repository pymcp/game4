# Extending the game4 GameEditor

Use when adding a new editor panel, a new tab to an existing panel, or a new tile-mapping category to the GameEditor dev tool.

## GameEditor Architecture

- **Main file:** `scripts/tools/game_editor.gd`
- **Scene:** `scenes/tools/GameEditor.tscn`
- **Panels:** standalone scripts in `scripts/tools/<name>_editor.gd`, extends `VBoxContainer` or `Control`
- **Tile mappings:** `resources/tilesets/tile_mappings.tres` (TileMappings resource)

## Adding a New Tile Mapping Category

1. Add an `@export` field to `scripts/data/tile_mappings.gd`:
   ```gdscript
   @export var my_thing_pair: Array[Vector2i] = []
   ```
2. Add to `TilesetCatalog._DEFAULT_SHEETS`:
   ```gdscript
   &"my_thing_pair": "res://assets/tiles/roguelike/<sheet>.png",
   ```
3. Add a static var + default const to `TilesetCatalog`:
   ```gdscript
   const _DEFAULT_MY_THING: Array = [Vector2i(x, y), ...]
   static var MY_THING_CELLS: Array = _DEFAULT_MY_THING
   ```
4. Load it in `TilesetCatalog._ensure_loaded()` from `TileMappings`.
5. Add to `game_editor.gd` `_MAPPINGS` array:
   ```gdscript
   {"id": &"my_thing_pair", "label": "My Thing", "sheet": "...", "field": &"my_thing_pair", "kind": &"flat_list"},
   ```
   Supported `kind` values: `"single"`, `"list"`, `"patch3"`, `"patch3_flat"`, `"named"`, `"flat_list"`, `"autotile"`.

## Adding a New Editor Panel

1. Create `scripts/tools/my_editor.gd` extending `VBoxContainer`:
   - Emit `signal dirty_changed` (no-arg form — matches existing editor interface) when content changes.
   - Expose `func save() -> void`, `func revert() -> void`, `func is_dirty() -> bool` (required by game_editor.gd).
   - `func _ready()`: load data from registry via `MyRegistry.get_raw_data()` or similar.
   - Save button calls `MyRegistry.save_data(collected_data)`.
   - Mark dirty on any user change; clear dirty after save.

2. In `game_editor.gd`, follow the existing `_mineable_editor` / `_creature_editor` / `_encounter_table_editor` pattern:
   - Add to `_MAPPINGS` array with label, sheet, field, kind.
   - Add `var _my_editor: MyEditor = null` instance variable.
   - Add to `_hide_all_editors()` and `_hide_all_editors_except()`.
   - Add to the `save()` and `revert()` dispatch.
   - Add dispatch case for showing the panel when selected in the tree.

## JSON Registry Pattern

All data-driven registries follow this pattern:

```gdscript
class_name MyRegistry
extends RefCounted

const _JSON_PATH: String = "res://resources/my_data.json"
static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
    if _loaded:
        return
    _loaded = true
    if not FileAccess.file_exists(_JSON_PATH):
        push_warning("[MyRegistry] %s not found" % _JSON_PATH)
        return
    var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
    if f == null:
        push_warning("[MyRegistry] failed to open %s" % _JSON_PATH)
        return
    var json := JSON.new()
    if json.parse(f.get_as_text()) != OK:
        push_warning("[MyRegistry] parse error: %s" % json.get_error_message())
        return
    if json.data is Dictionary:
        _data = json.data

static func reset() -> void:
    _data.clear()
    _loaded = false

static func get_raw_data() -> Dictionary:
    _ensure_loaded()
    return _data.duplicate(true)

static func save_data(data: Dictionary) -> void:
    _data = data
    _loaded = true
    var f := FileAccess.open(_JSON_PATH, FileAccess.WRITE)
    if f == null:
        push_error("[MyRegistry] cannot write %s" % _JSON_PATH)
        return
    f.store_string(JSON.stringify(data, "\t"))
    f.close()
```

Key rules:
- `class_name` + `extends RefCounted` (NOT Node — avoids autoload quirks)
- `reset()` is called in unit test `before_each` to clear state between tests
- `save_data()` writes to disk AND updates `_data` in memory
- Editors call `get_raw_data()` (deep copy) to avoid mutating the cache directly
- Always add `push_warning` on both the `file_exists` and `open == null` paths (not just one)

## Existing Editor Panels

| Panel | File | Registry |
|-------|------|----------|
| Mineable Resources | `scripts/tools/mineable_editor.gd` | `MineableRegistry` |
| Creatures | `scripts/tools/creature_editor.gd` | `CreatureSpriteRegistry` |
| Encounter Tables (Depth) | `scripts/tools/encounter_table_editor.gd` | `EncounterTableRegistry` |
| Chest Loot (Depth Tiers) | `scripts/tools/chest_loot_editor.gd` | `ChestLootRegistry` |

## Save Button Pattern

The GameEditor Save button (for tile mappings) calls `ResourceSaver.save(tile_mappings, MAPPINGS_PATH)`. Individual editor panels call their registry's `save_data()` directly. Both fire `dirty_changed` after saving to clear the dirty indicator in the panel tree.
