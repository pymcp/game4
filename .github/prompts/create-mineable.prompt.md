---
description: Create a new mineable resource with sprites, biome spawning, drops, and runtime integration. Use when asked to add a mineable, ore vein, harvestable, rock type, tree variant, or destructible terrain feature.
---

# Create a Mineable Resource

You are adding a new mineable resource to a Godot 4.3 fantasy sandbox game. Mineables are terrain decorations the player can hit to destroy and collect drops. They are fully data-driven via `resources/mineables.json`.

## Step 1: Gather Requirements

Before editing any files, ask the user for:
- **ref_id** — unique snake_case identifier (e.g. `silver_vein`, `cactus`, `mushroom`)
- **Display name** — human-readable (e.g. "Silver Vein")
- **HP** — hit points, integer 1–100 (bushes ~1, rocks ~5, ore veins 5–8)
- **Is tall?** — does the decoration occupy two vertical cells? (trees = yes, rocks/ores = no)
- **Pickaxe bonus?** — does a pickaxe deal double damage? (yes for rocks/ores, no for plants)
- **Drops** — list of `{item_id, count}` pairs. If the drop item doesn't exist yet, note it for Step 3.
- **Biome weights** — which biomes should it spawn in and at what density? Available biomes: `grass`, `desert`, `snow`, `swamp`, `rocky`. Typical weights: common = 0.04–0.06, moderate = 0.01–0.02, rare = 0.005–0.01.
- **Sprite description** — what does it look like? The user will pick atlas cells in SpritePicker, or describe what to look for.

## Step 2: Add the Resource Entry to mineables.json

Edit `resources/mineables.json` and add a new key under `"resources"`. Follow this exact schema:

```json
{
  "resources": {
    "<ref_id>": {
      "biome_weights": {
        "<biome_id>": <float>
      },
      "display_name": "<Display Name>",
      "drops": [
        {"count": <int>, "item_id": "<item_id>"}
      ],
      "hp": <int>,
      "is_pickaxe_bonus": <bool>,
      "is_tall": <bool>,
      "ref_id": "<ref_id>",
      "sprites": []
    }
  }
}
```

### Schema Rules
- **ref_id** must match the dictionary key exactly
- **biome_weights** — only include biomes where this resource should spawn. Omitted biomes = zero weight.
- **drops** — array of `{count, item_id}` objects. `item_id` must match an entry in `ItemRegistry` (see Step 3). Can be empty `[]` for decorative-only resources.
- **sprites** — leave as `[]` initially; the user will pick atlas cells via SpritePicker later. Each entry is `[col, row]` — atlas coordinates on `overworld_sheet.png` (16px tiles, 1px gutter, 17px stride). Multiple entries = random variant selection at spawn time.
- **is_tall** — if `true`, the decoration uses two vertically stacked cells (like trees). The bottom cell is the interaction target.
- **is_pickaxe_bonus** — if `true`, the `pickaxe` item doubles mining damage against this resource.
- Keep keys in **alphabetical order** within each resource entry (matching existing entries).

### Existing Resources for Reference

| ref_id | display_name | hp | tall | pickaxe | drops | biomes |
|--------|-------------|----|------|---------|-------|--------|
| bush | Bush | 1 | no | no | fiber ×1 | grass 0.04, desert 0.01, swamp 0.06 |
| copper_vein | Copper Vein | 5 | no | yes | copper_ore ×1 | rocky 0.01 |
| gold_vein | Gold Vein | 8 | no | yes | gold_ore ×1 | rocky 0.005 |
| iron_vein | Iron Vein | 6 | no | yes | iron_ore ×1 | rocky 0.015 |
| rock | Rock | 5 | no | yes | stone ×1 | grass 0.015, desert 0.03, snow 0.02, rocky 0.06 |
| tree | Tall Tree | 2 | yes | no | wood ×1 | grass 0.06, snow 0.04, swamp 0.05, rocky 0.02 |

## Step 3: Create Drop Items (if needed)

If any `item_id` in the drops list doesn't already exist in `ItemRegistry`, create it:

### Option A: Hardcoded Item (simple materials)

Add a `_define()` call in `scripts/data/item_registry.gd` inside the `_define_defaults()` method:

```gdscript
_define(&"<item_id>", "<Display Name>", <icon_idx>, Slot.NONE, 0, 99, "<description>")
```

### Option B: .tres Override (items with custom sprites)

Create `resources/items/<item_id>.tres` following the **import-sprite** skill. This is preferred when the item has a Gemini-generated or custom icon.

### Existing Drop Items

| item_id | display_name |
|---------|-------------|
| fiber | Fiber |
| copper_ore | Copper Ore |
| gold_ore | Gold Ore |
| iron_ore | Iron Ore |
| stone | Stone |
| wood | Wood |

## Step 4: Assign Sprites

There are two approaches depending on whether you're using an existing Kenney sprite or a custom imported sprite.

### Option A: Custom Imported Sprite (e.g. from Gemini)

If the sprite exists as a standalone 16×16 PNG (e.g. in `assets/icons/items/`), use the atlas tool to place it on the overworld sheet:

```bash
python3 tools/add_sprite_to_sheet.py <source_png> <sprite_name>
```

Example:
```bash
python3 tools/add_sprite_to_sheet.py assets/icons/items/fennel_root.png fennel_root
# prints: [36, 29]
```

This will:
1. Find an empty cell on `overworld_sheet.png`
2. Paste the 16×16 sprite into that cell
3. Record the mapping in `resources/custom_sprite_cells.json`
4. Print `[col, row]` — use this in the `sprites` array

The tool is idempotent — re-running with the same name re-pastes into the same cell.

Write the returned coordinates into the resource's `sprites` array:
```json
"sprites": [[36, 29]]
```

### Option B: Existing Kenney Atlas Sprite

Tell the user to open the SpritePicker tool in-game and:

1. Select the **Mineable Editor** tab
2. Select the new resource from the resource list
3. Click atlas cells on `overworld_sheet.png` to toggle them as sprite variants
4. Save — this writes the `sprites` array back to `mineables.json`

If the user provides sprite coordinates directly (e.g. "use cells [20,9] and [21,9]"), write them into the `sprites` array as `[[20, 9], [21, 9]]`.

### Atlas Geometry

16×16 pixel tiles with 1px gutter → 17px stride. Cell `[col, row]` maps to pixel position `(col * 17, row * 17)`.

## Step 5: Verify Runtime Integration

The mineable system is fully automatic once the JSON entry exists. Here's how the data flows — no code changes needed:

1. **Spawn weights** — `WorldGenerator._scatter_decorations()` calls `MineableRegistry.get_biome_weights(biome)` which merges all resources' `biome_weights` for that biome into the decoration roll.
2. **Sprite lookup** — `TilesetCatalog` calls `MineableRegistry.build_decoration_cells()` which converts each resource's `sprites` array into `OVERWORLD_DECORATION_CELLS[ref_id]`. Variant is chosen via `entry["variant"] % cells.size()`.
3. **HP table** — `WorldRoot.MINEABLE_HP` is lazily built from `MineableRegistry.build_hp_table()`. The player's mining system reads this.
4. **Drop table** — `WorldRoot.MINEABLE_DROPS` is lazily built from `MineableRegistry.build_drops_table()`. When a resource is destroyed, drops are spawned from this table.
5. **Pickaxe bonus** — `WorldRoot.PICKAXE_BONUS_KINDS` is lazily built from `MineableRegistry.build_pickaxe_bonus_set()`. If the player holds a pickaxe and the resource is in this set, damage is doubled.
6. **Tall flag** — `MineableRegistry.build_tall_kinds()` provides the set of resources that use 2-cell-high decorations.

After adding the JSON entry:
- Existing worlds will show the new resource when regions are generated (not retroactively in already-generated regions)
- `WorldRoot.reload_mineable_tables()` clears all caches, forcing a rebuild on next access (called automatically when SpritePicker saves)

## Step 6: Write Tests (optional but recommended)

Add tests to `tests/unit/test_mineable_registry.gd` or a new file:

```gdscript
func test_<ref_id>_exists() -> void:
    MineableRegistry.reload()
    var def: Variant = MineableRegistry.get_resource(&"<ref_id>")
    assert_not_null(def, "<ref_id> should exist in MineableRegistry")
    assert_eq(def["display_name"], "<Display Name>")
    assert_eq(def["hp"], <hp>)

func test_<ref_id>_in_biome_weights() -> void:
    MineableRegistry.reload()
    var weights: Dictionary = MineableRegistry.get_biome_weights(&"<biome_id>")
    assert_has(weights, &"<ref_id>", "<ref_id> should appear in <biome_id> weights")

func test_<ref_id>_drops() -> void:
    MineableRegistry.reload()
    var drops: Dictionary = MineableRegistry.build_drops_table()
    assert_has(drops, &"<ref_id>", "<ref_id> should have drops")
    assert_eq(drops[&"<ref_id>"].size(), <expected_drop_count>)

func test_<ref_id>_hp_table() -> void:
    MineableRegistry.reload()
    var hp: Dictionary = MineableRegistry.build_hp_table()
    assert_has(hp, &"<ref_id>")
    assert_eq(hp[&"<ref_id>"], <hp>)
```

## Step 7: Update Quest JSON (if applicable)

If this mineable was created for a quest (e.g. as a `terrain_features` entry in `requires`), update the status:

```json
{"id": "<ref_id>", "type": "interactable", "description": "...", "status": "IMPLEMENTED"}
```

Search for it:
```bash
grep -rl '"<ref_id>"' resources/quests/
```

## Step 8: Run Tests

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## Checklist Before Done

- [ ] Entry added to `resources/mineables.json` with all 8 fields
- [ ] `ref_id` matches the dictionary key
- [ ] Keys are in alphabetical order within the entry
- [ ] Drop items exist in `ItemRegistry` (hardcoded or .tres override)
- [ ] Biome weights set for desired spawn biomes
- [ ] Sprites assigned (via SpritePicker or direct coordinates)
- [ ] `is_tall` and `is_pickaxe_bonus` set correctly
- [ ] Quest JSON `requires.terrain_features` updated to `IMPLEMENTED` (if applicable)
- [ ] Tests passing
