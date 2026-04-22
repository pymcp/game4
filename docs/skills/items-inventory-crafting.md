# Items, Inventory & Crafting

## ItemDefinition (`scripts/data/item_definition.gd`, 87 lines)

Resource subclass describing one item type. Every property has a sane default.

### Enums

| Enum | Values |
|------|--------|
| `Slot` | `NONE=0, WEAPON=1, TOOL=2, HEAD=3, BODY=4, FEET=5, OFF_HAND=6` |
| `Rarity` | `COMMON=0, UNCOMMON=1, RARE=2, EPIC=3, LEGENDARY=4` |
| `AttackType` | `NONE=0, MELEE=1, RANGED=2` |
| `WeaponCategory` | `NONE=0, SWORD=1, AXE=2, SPEAR=3, BOW=4, STAFF=5, DAGGER=6` |
| `Element` | `NONE=0, FIRE=1, ICE=2, LIGHTNING=3, POISON=4` |

### Fields (@export)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `id` | `StringName` | `&""` | Unique key, matches JSON key |
| `display_name` | `String` | `""` | Human label |
| `icon` | `Texture2D` | `null` | Inventory icon |
| `stack_size` | `int` | `99` | Max per slot |
| `slot` | `Slot` | `NONE` | Equip slot (NONE = not equippable) |
| `power` | `int` | `0` | Base ATK (weapons) or DEF (armor) |
| `rarity` | `Rarity` | `COMMON` | Drives border/label color |
| `hands` | `int` | `1` | 2 = two-handed (blocks OFF_HAND) |
| `attack_type` | `AttackType` | `NONE` | MELEE or RANGED |
| `attack_speed` | `float` | `0.0` | Seconds between swings (0 → default 0.35) |
| `reach` | `float` | `0.0` | Pixel radius for hit detection |
| `knockback` | `float` | `0.0` | Push-back pixels on hit |
| `weapon_category` | `WeaponCategory` | `NONE` | Drives VFX (swing/thrust/ranged/spell) |
| `tier` | `String` | `""` | Flavor grouping (e.g. "iron", "steel") |
| `element` | `Element` | `NONE` | Elemental damage type |
| `set_id` | `String` | `""` | Armor set key (see ArmorSetRegistry) |
| `stat_bonuses` | `Dictionary` | `{}` | e.g. `{"strength": 1, "speed": 1}` |
| `weapon_sprite` | `Vector2i` | `(-1,-1)` | CharacterAtlas grid coords |
| `armor_sprite` | `Vector2i` | `(-1,-1)` | CharacterAtlas grid coords |
| `armor_tint` | `Color` | white | Tint for armor sprite |
| `shield_sprite` | `Vector2i` | `(-1,-1)` | CharacterAtlas grid coords |
| `description_flavor` | `String` | `""` | Second line in item detail panel |

### Rarity Colors

`RARITY_COLORS` constant: COMMON=white, UNCOMMON=green, RARE=blue, EPIC=purple, LEGENDARY=orange.

### `generate_description() -> String`

Builds stat summary: `"4 ATK · 0.35s · Melee · Fire · +1 STR · Iron Set"` + newline + `description_flavor`.

---

## ItemRegistry (`scripts/data/item_registry.gd`, 296 lines)

Static registry loading `resources/items.json`. Uses **Type Object inheritance** — child items specify `"parent"` and inherit all unspecified fields via topological-sort copy-down.

### Public API

| Method | Returns |
|--------|---------|
| `get_item(id: StringName)` | `ItemDefinition` (cached) |
| `has_item(id: StringName)` | `bool` |
| `all_ids()` | `Array` of all registered StringNames |
| `reset()` | Clears cache, forces reload on next access |
| `get_raw_data()` | `Dictionary` (pre-inheritance JSON) |
| `get_resolved_entry(id: String)` | `Dictionary` (post-inheritance) |
| `save_data(data: Dictionary)` | Writes to items.json |
| `reload()` | Force reload from disk |

### Enum Maps

String→enum lookups: `_SLOT_MAP`, `_RARITY_MAP`, `_ATTACK_TYPE_MAP`, `_WEAPON_CAT_MAP`, `_ELEMENT_MAP`. JSON uses lowercase string keys (e.g. `"weapon"`, `"rare"`, `"fire"`).

### Item Count

**42 items** total: 10 base types (not directly obtainable), 24 tier variants, 8 standalone materials/tools.

### Inheritance Tree

```
base_sword → wooden_sword, sword, fire_sword, steel_sword, mithril_sword
base_axe → iron_axe, steel_axe
base_spear → iron_spear
base_bow → bow, longbow
base_staff → fire_staff, ice_staff, lightning_staff
base_dagger → iron_dagger, poison_dagger
base_shield → wooden_shield, iron_shield, steel_shield
base_helmet → helmet, iron_helmet
base_armor → armor, iron_armor
base_boots → boots, iron_boots
(no parent) → wood, stone, fiber, iron_ore, copper_ore, gold_ore, fennel_root, pickaxe
```

### Adding a New Item

1. Add entry to `resources/items.json` with `"parent"` if applicable
2. Optionally add `.tres` override in `resources/items/<id>.tres` for icon
3. `ItemRegistry.reset()` or restart to pick up changes
4. If equippable, set `slot`, `power`, `weapon_sprite`/`armor_sprite`/`shield_sprite`

---

## Inventory (`scripts/data/inventory.gd`, 135 lines)

Resource subclass. Fixed-size slot array. Each slot is `null` or `{id: StringName, count: int}`.

**Signal:** `contents_changed` — emitted on any mutation.

**Default size:** 24 slots.

| Method | Behavior |
|--------|----------|
| `add(id, count=1) → int` | Tops up existing stacks first, then fills empties. Returns leftover. |
| `remove(id, count=1) → int` | Returns actual amount removed. |
| `count_of(id) → int` | Total across all slots. |
| `has(id, count=1) → bool` | Shorthand for `count_of >= count`. |
| `take_slot(i) → Variant` | Removes entire slot, returns the dict or null. |
| `to_dict() / from_dict(data)` | Serialization for save/load. |

---

## Crafting (`scripts/data/crafting_recipe.gd` + `crafting_registry.gd`)

### CraftingRecipe (35 lines)

| Field | Type |
|-------|------|
| `id` | `StringName` |
| `inputs` | `Array` of `{id, count}` |
| `output_id` | `StringName` |
| `output_count` | `int` (default 1) |

- `can_craft(inv) → bool` — checks all inputs available
- `craft(inv) → bool` — consumes inputs, adds output. Rolls back if output doesn't fit.

### CraftingRegistry (67 lines)

Static, loads hardcoded defaults + `.tres` overrides from `resources/recipes/`.

| Method | Returns |
|--------|---------|
| `get_recipe(id)` | `CraftingRecipe` |
| `all_recipes()` | `Array` |
| `reset()` | Clears cache |

**Current recipes (4):**

| Recipe | Inputs | Output |
|--------|--------|--------|
| sword | 1 wood + 4 stone + 1 fiber | 1 sword |
| helmet | 4 fiber | 1 helmet |
| armor | 6 fiber | 1 armor |
| boots | 3 fiber | 1 boots |

---

## LootPickup (`scripts/entities/loot_pickup.gd`, 108 lines)

Lightweight world entity. Auto-collects when player walks within 0.7 tiles.

| Property | Default |
|----------|---------|
| `item_id` | `&""` |
| `count` | `1` |

**Behavior:**
- Creates visual: equipment sprite (weapon/armor/shield) → icon texture → fallback yellow square
- Floating label: `"Name x1"`, tinted by rarity color
- Bob animation: sine wave ±2px at 1Hz
- Proximity check every frame: `< 0.7 * TILE_PX` → add to player inventory, play SFX, queue_free

**Spawned by:**
- `WorldRoot._on_monster_died()` — from monster drops
- `WorldRoot._materialize_loot_scatter()` — from dungeon floor loot
- `InventoryScreen._drop_cursor()` — player drops item

---

## Test Considerations

- Tests calling `ItemRegistry.save_data()` must backup `items.json` in `before_all()` and restore in `after_all()` to avoid corruption.
- `ItemRegistry.reset()` between tests to clear cached definitions.
- `CraftingRegistry.reset()` between tests.
- Inventory slot structure: `{id: StringName, count: int}` or `null`.
