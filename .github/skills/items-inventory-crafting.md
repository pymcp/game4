# Skill: Items, Inventory & Crafting

Use this skill when working on item definitions, the inventory system, crafting recipes, loot pickups, or save/load of player belongings.

---

## Item Definitions

**File:** `scripts/data/item_definition.gd` — `class_name ItemDefinition extends Resource`

### Slot Enum

| Value    | Int | Purpose                        |
|----------|-----|--------------------------------|
| `NONE`   | 0   | Materials / consumables        |
| `WEAPON` | 1   | Weapon slot                    |
| `TOOL`   | 2   | Tool slot                      |
| `HEAD`   | 3   | Helmet / head armor            |
| `BODY`   | 4   | Body armor                     |
| `FEET`   | 5   | Boot armor                     |

### Properties

| Export         | Type         | Default | Notes                                |
|----------------|--------------|---------|--------------------------------------|
| `id`           | StringName   | `&""`   | Unique key (e.g. `&"sword"`)         |
| `display_name` | String       | `""`    | UI label                             |
| `icon`         | Texture2D    | null    | Loaded from icon index               |
| `stack_size`   | int          | 99      | Max per inventory slot               |
| `slot`         | Slot         | NONE    | Which equipment slot, or NONE        |
| `power`        | int          | 0       | Weapon damage bonus / armor defense  |
| `description`  | String       | `""`    | Tooltip text                         |

---

## Item Registry

**File:** `scripts/data/item_registry.gd` — `class_name ItemRegistry extends RefCounted` (static-only)

Icon path formula: `res://assets/icons/generic_items/genericItem_color_%03d.png`

### All Registered Items

| ID             | Display Name    | Icon# | Slot   | Power | Stack | Description                          |
|----------------|-----------------|-------|--------|-------|-------|--------------------------------------|
| `&"wood"`      | Wood            | 1     | NONE   | 0     | 99    | A bundle of sturdy logs.             |
| `&"stone"`     | Stone           | 2     | NONE   | 0     | 99    | A heavy chunk of rock.               |
| `&"fiber"`     | Fiber           | 3     | NONE   | 0     | 99    | Plant fibres for crafting.           |
| `&"iron_ore"`  | Iron Ore        | 4     | NONE   | 0     | 99    | A lump of unrefined iron.            |
| `&"copper_ore"`| Copper Ore      | 5     | NONE   | 0     | 99    | A lump of unrefined copper.          |
| `&"gold_ore"`  | Gold Ore        | 6     | NONE   | 0     | 99    | A gleaming nugget of gold.           |
| `&"pickaxe"`   | Iron Pickaxe    | 22    | TOOL   | 2     | 1     | Doubles mining damage vs rocks/ore.  |
| `&"sword"`     | Iron Sword      | 21    | WEAPON | 4     | 1     | A balanced blade for combat.         |
| `&"bow"`       | Wooden Bow      | 24    | WEAPON | 3     | 1     | Fires arrows at distant targets.     |
| `&"helmet"`    | Leather Helmet  | 31    | HEAD   | 2     | 1     | Reduces head damage.                 |
| `&"armor"`     | Leather Armor   | 32    | BODY   | 3     | 1     | Reduces body damage.                 |
| `&"boots"`     | Leather Boots   | 33    | FEET   | 1     | 1     | Slightly increases movement speed.   |

Designer overrides: `.tres` files in `res://resources/items/` replace code defaults for matching IDs.

### API

- `get_item(id: StringName) → ItemDefinition` — returns def or null
- `has_item(id: StringName) → bool`
- `all_ids() → Array` — all registered StringName keys
- `reset() → void` — clear cache (for tests)

---

## Inventory

**File:** `scripts/data/inventory.gd` — `class_name Inventory extends Resource`

- **Signal:** `contents_changed` — emitted on any mutation
- **Constant:** `DEFAULT_SIZE = 24`
- **Slot structure:** Each slot is `null` (empty) or `{ "id": StringName, "count": int }`

### API

| Method          | Signature                          | Description                                                    |
|-----------------|------------------------------------|----------------------------------------------------------------|
| `add`           | `(item_id, count=1) → int`        | Add items; returns leftover (0=all fit). Stacks first, then fills empties. |
| `remove`        | `(item_id, count=1) → int`        | Remove items; returns actual amount removed.                   |
| `count_of`      | `(item_id) → int`                 | Total count across all slots.                                  |
| `has`           | `(item_id, count=1) → bool`       | Shorthand for `count_of >= count`.                             |
| `is_full`       | `() → bool`                       | No null slots remain.                                          |
| `take_slot`     | `(i: int) → Variant`              | Remove entire slot; returns the dict or null.                  |
| `place_in_slot` | `(i, item_id, count) → void`      | Directly set a slot.                                           |
| `to_dict`       | `() → Dictionary`                 | `{ "size": int, "slots": Array }` — slot ids stored as String. |
| `from_dict`     | `(data) → void`                   | Restore from dict; emits `contents_changed`.                   |

---

## Crafting

### CraftingRecipe

**File:** `scripts/data/crafting_recipe.gd` — `class_name CraftingRecipe extends Resource`

| Property       | Type                                    | Description         |
|----------------|-----------------------------------------|---------------------|
| `id`           | StringName                              | Recipe key          |
| `inputs`       | Array of `{id: StringName, count: int}` | Required ingredients|
| `output_id`    | StringName                              | Item produced       |
| `output_count` | int                                     | Quantity produced   |

- `can_craft(inv) → bool` — checks all inputs present
- `craft(inv) → bool` — consume inputs, grant output. **Rolls back** if output doesn't fit.

### CraftingRegistry

**File:** `scripts/data/crafting_registry.gd` — `class_name CraftingRegistry extends RefCounted` (static-only)

| Recipe ID   | Inputs                       | Output           |
|-------------|------------------------------|------------------|
| `&"sword"`  | 1× Wood + 4× Stone + 1× Fiber | 1× Iron Sword  |
| `&"helmet"` | 4× Fiber                    | 1× Leather Helmet |
| `&"armor"`  | 6× Fiber                    | 1× Leather Armor |
| `&"boots"`  | 3× Fiber                    | 1× Leather Boots |

Designer overrides: `.tres` files in `res://resources/recipes/`

### CraftingPanel

**File:** `scripts/ui/crafting_panel.gd` — `class_name CraftingPanel extends Control`

Renders a vertical list of recipe buttons. Disabled when `!recipe.can_craft(inv)`. Pressing calls `recipe.craft(player.inventory)`. Refreshes via `inventory.contents_changed`.

---

## LootPickup

**File:** `scripts/entities/loot_pickup.gd` — `class_name LootPickup extends Node2D`

| Export    | Type       | Default |
|-----------|------------|---------|
| `item_id` | StringName | `&""`   |
| `count`   | int        | 1       |

- `_ready()`: Walks tree to find `WorldRoot`. Creates `Sprite2D` showing `ItemDefinition.icon` (fallback: yellow 48×48 square). Adds `Label` with `"DisplayName x{count}"`.
- `_process()`: Per-frame distance check against both players. Radius = `0.7 × TILE_PX`. On proximity → `player.inventory.add()` → `queue_free()` + SFX.
- No Area2D — purely deterministic distance check for testability.

### Spawning a LootPickup

```gdscript
var pickup := LootPickup.new()
pickup.item_id = id
pickup.count = amount
pickup.position = player.position + Vector2(player._facing_x * 18, 0)
player._world.entities.add_child(pickup)
```

---

## Save / Load

### PlayerSaveData

**File:** `scripts/data/player_save_data.gd` — `class_name PlayerSaveData extends Resource`

Contains `inventory_data: Dictionary` and `equipment_data: Dictionary`, among other player fields.

### SaveGame

**File:** `scripts/data/save_game.gd` — `class_name SaveGame extends Resource`

- **Save:** `player.inventory.to_dict()` → `psd.inventory_data`, `player.equipment.to_dict()` → `psd.equipment_data`
- **Load:** `player.inventory.from_dict(psd.inventory_data)`, `player.equipment.from_dict(psd.equipment_data)` — emits `contents_changed` which triggers sprite updates.

### SaveManager (Autoload)

**File:** `scripts/autoload/save_manager.gd`

- Autosaves every 300s and on region change
- `save_now(slot)`, `load_now(slot)`, `attach_world(world)`, `detach_world()`

---

## End-to-End Flows

### Acquire item (loot pickup)
```
LootPickup._process() proximity check
  → player.inventory.add(item_id, count)
    → contents_changed → UI refresh
  → queue_free() + SFX
```

### Craft item
```
CraftingPanel button press
  → recipe.craft(player.inventory)
    → inventory.remove() each input
    → inventory.add(output_id, output_count)
    → contents_changed → UI refresh
```

### Drop item to world
```
InventoryScreen._drop_cursor()
  → inventory.remove(id, 1) or equipment.unequip(slot)
  → _spawn_loot_pickup(id, 1)
    → LootPickup added to world.entities
```

### Save
```
SaveGame.snapshot(world)
  → player.inventory.to_dict() → psd.inventory_data
  → player.equipment.to_dict() → psd.equipment_data
  → ResourceSaver.save()
```

### Load
```
SaveGame.apply(world)
  → player.inventory.from_dict(psd.inventory_data)
  → player.equipment.from_dict(psd.equipment_data)
    → contents_changed → sprite updates
```
