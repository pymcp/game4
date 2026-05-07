---
name: world-objects-sprite-sheet
description: Use when adding new quest interactables, world decorations, or interactive environment objects (wells, springs, altars, notice boards, etc.) that need a hires sprite. These are NOT items (not in items.json) and NOT creatures. They go on the world_objects sheet.
---

# Skill: World Objects Sprite Sheet

## What It Is

`world_objects` is a hires sprite sheet for **quest interactables and world decorations** — objects that appear in the world and can be interacted with, but are not inventory items or creatures.

Examples: village well, natural spring, mine entrance marker, altar, campfire, notice board.

## Sheet Location

| File | Purpose |
|------|---------|
| `assets/icons/hires/world_objects.png` | 64×64 px sprites, 1 px gutter, burnt-orange stub sentinel |
| `assets/icons/hires/world_objects_cells.json` | `{id: {"cell": [col, row], "size": [w, h]}}` stable cell map |
| `resources/world_objects.json` | Source of truth: `{id: {"display_name": "...", "description": "..."}}` |

Spec (same as all hires sheets): `assets/icons/hires/_spec.json` → `{ "tile_px": 64, "margin_px": 1 }`

## Adding a New World Object

### 1. Register in `resources/world_objects.json`

```json
{
  "my_object": {
    "display_name": "My Object",
    "description": "What it is and what it does."
  }
}
```

### 2. Regenerate the sheet

```bash
python3 tools/gen_hires_sheet.py world_objects
```

A stub tile (burnt-orange background, labelled with the id) appears in the next free cell.
Check `assets/icons/hires/world_objects_cells.json` to find the assigned `[col, row]`.

### 3. Paint real art (optional)

Open `assets/icons/hires/world_objects.png` in your image editor.
Each cell is 64×64 px with a 1 px gap.  Paint real art into the stub cell.
Re-run the tool — real-art cells are preserved; only stub cells are regenerated.

### 4. Reference the sprite in code

Use `HiresIconRegistry._from_cell("world_objects", col, row)` to get an `AtlasTexture`:

```gdscript
var spr: Sprite2D = $Sprite2D
var tex: Texture2D = HiresIconRegistry._from_cell("world_objects", 6, 0)  # spring
if tex != null:
    spr.texture = tex
    spr.scale = Vector2(0.25, 0.25)  # 64px * 0.25 = 16px in-game
```

Or look up the cell dynamically from the cells JSON at runtime if you prefer not to hardcode:

```gdscript
const _CELLS_PATH := "res://assets/icons/hires/world_objects_cells.json"

static func get_world_object_texture(object_id: String) -> Texture2D:
    var raw: String = FileAccess.get_file_as_string(_CELLS_PATH)
    var cells: Dictionary = JSON.parse_string(raw) as Dictionary
    var info: Dictionary = cells.get(object_id, {})
    if info.is_empty():
        return null
    var cell: Array = info.get("cell", [0, 0])
    return HiresIconRegistry._from_cell("world_objects", int(cell[0]), int(cell[1]))
```

## Current Entries

| id | Cell | Display Name | Notes |
|----|------|--------------|-------|
| `altar` | [0, 0] | Stone Altar | Generic interactable |
| `barrel` | [1, 0] | Barrel | Generic container |
| `campfire` | [2, 0] | Campfire | Flavour/rest point |
| `crate` | [3, 0] | Wooden Crate | Generic container |
| `mine_entrance` | [4, 0] | Mine Entrance | Quest landmark |
| `notice_board` | [5, 0] | Notice Board | Quest hub |
| `spring` | [6, 0] | Natural Spring | `herbalist_remedy` — `get_water` objective |
| `village_well` | [7, 0] | Village Well | `herbalist_remedy` — flavour/clue object |

## Using with QuestInteractable

When placing a `QuestInteractable` for a world object:

```gdscript
const _QuestInteractableScene := preload("res://scenes/entities/QuestInteractable.tscn")

func _place_world_object(cell: Vector2i, object_id: String, quest_id: String, 
                          objective_id: String, text: String) -> void:
    var qi: QuestInteractable = _QuestInteractableScene.instantiate()
    qi.quest_id = quest_id
    qi.objective_id = objective_id
    qi.interact_text = text
    qi.position = (Vector2(cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
    # Apply world_objects sprite
    var spr: Sprite2D = qi.get_node("Sprite2D") as Sprite2D
    if spr != null:
        var cells := JSON.parse_string(
            FileAccess.get_file_as_string("res://assets/icons/hires/world_objects_cells.json"))
        var info: Dictionary = (cells as Dictionary).get(object_id, {})
        var c: Array = info.get("cell", [0, 0])
        var tex := HiresIconRegistry._from_cell("world_objects", int(c[0]), int(c[1]))
        if tex != null:
            spr.texture = tex
            spr.scale = Vector2(0.25, 0.25)
    entities.add_child(qi)
```

## Stub Sentinel

The world_objects category sentinel is `RGB(110, 60, 30)` (burnt orange).  
The tool samples `(col*65+4, row*65+4)` — if within ±30 of the sentinel, the cell is regenerated as a stub.

## Scale Math

Same as all hires sheets:
```
display_px = tile_px × scale × render_zoom
           = 64      × 0.25  × 4           = 64 screen px  ✓
```
`scale = Vector2(0.25, 0.25)` makes a 64 px cell render as exactly 1 game tile (16 px world → 64 px screen at zoom 4).
