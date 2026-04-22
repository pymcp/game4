# Skill: Equipment & Player Rendering

Use this skill when working on equipping/unequipping items, armor defense calculations, weapon/armor sprite rendering on the player, the inventory UI equip/drop flow, or the atlas mapping systems.

---

## Equipment

**File:** `scripts/data/equipment.gd` — `class_name Equipment extends Resource`

- **Signal:** `contents_changed` — emitted on equip/unequip
- **Storage:** `equipped: Dictionary` — maps `ItemDefinition.Slot` enum int → `StringName` item_id

### API

| Method        | Signature                        | Description                                                |
|---------------|----------------------------------|------------------------------------------------------------|
| `equip`       | `(slot, item_id) → StringName`   | Equip item; returns previously equipped id (or `&""`)      |
| `unequip`     | `(slot) → StringName`            | Remove from slot; returns previous id                      |
| `get_equipped` | `(slot) → StringName`           | Current id in slot (or `&""`)                              |
| `total_power` | `(only_slot=NONE) → int`        | Sum `power` of equipped items. `NONE` = grand total.       |
| `to_dict`     | `() → Dictionary`               | Keys = int(slot), values = String(item_id)                 |
| `from_dict`   | `(data) → void`                 | Restore; emits `contents_changed`                          |

### Equipment Slot Order (UI)

`EQUIPMENT_SLOT_ORDER = [HEAD, BODY, FEET, WEAPON, TOOL]` — used by `InventoryScreen`

---

## Atlas Systems

### WeaponAtlas

**File:** `scripts/data/weapon_atlas.gd` — `class_name WeaponAtlas extends RefCounted` (static)

Maps weapon/tool item IDs → character sheet cells. Weapons are **2 tiles tall** (16×33 px).

| Item        | Default Cell | Notes                            |
|-------------|-------------|----------------------------------|
| `&"sword"`  | `(42, 5)`   | Sword variant, first color row   |
| `&"pickaxe"`| `(50, 0)`   | Hammer column                    |
| `&"bow"`    | `(52, 0)`   | First bow variant                |

**API:**
- `cell_for(item_id) → Vector2i` — checks `TileMappings.weapon_sprites` first, then `_DEFAULTS`. Returns `(-1,-1)` if none.
- `region_for(item_id) → Rect2` — `Rect2(cell.x*17, cell.y*17, 16, 33)`. Empty `Rect2()` if no cell.

**TileMappings integration:** `TileMappings` resource at `res://resources/tilesets/tile_mappings.tres` stores `weapon_sprites: Dictionary<StringName, Array[Vector2i]>` edited via SpritePicker. WeaponAtlas reads `[0]` from the array.

### ArmorAtlas

**File:** `scripts/data/armor_atlas.gd` — `class_name ArmorAtlas extends RefCounted` (static)

Maps armor item IDs → `{ "cell": Vector2i, "tint": Color }`. Armor is **single tile** (16×16 px).

| Item         | Default Cell | Tint  | Notes                                        |
|--------------|-------------|-------|----------------------------------------------|
| `&"armor"`   | `(9, 5)`    | white | Torso "armored" variant (style 3, green row) |
| `&"helmet"`  | `(19, 3)`   | white | Hair ACCESSORY cap (brown)                   |
| `&"boots"`   | `(-1, -1)`  | white | Placeholder — user will map cells later      |

**API:**
- `lookup(item_id) → Dictionary` — `{cell, tint}` or `{(-1,-1), white}`
- `cell_for(item_id) → Vector2i`
- `tint_for(item_id) → Color`
- `region_for(item_id) → Rect2` — `Rect2(cell.x*17, cell.y*17, 16, 16)`. Empty if no cell.

**Tint system:** Armor tiers reuse the same base atlas cell with a `Sprite2D.modulate` color overlay (e.g. Leather=white, Tough Leather=brownish). Add new entries to `_DEFAULTS` dict with a non-white tint for tier variants.

---

## Player Scene Structure

**File:** `scenes/entities/Player.tscn`

```
Player (Node2D, player_controller.gd)
├── SpriteRoot (Node2D)
│   ├── Body     (Sprite2D — region (0,0,16,16)     — skin tone)
│   ├── Torso    (Sprite2D — region (102,0,16,16)    — default orange outfit)
│   ├── Hair     (Sprite2D — region (323,0,16,16)    — default brown short)
│   ├── Boots    (Sprite2D — visible=false (0,0,16,16) — hidden until equipped)
│   └── Weapon   (Sprite2D — visible=false (0,0,16,33) — 2 tiles tall)
└── ActionVFX (Node2D, action_vfx.gd)
```

All sprites: `characters_sheet.png`, `region_enabled=true`, `centered=true`, `offset=(0, -8)`.

---

## Player Controller — Equipment Wiring

**File:** `scripts/entities/player_controller.gd`

### Sprite References (set in `_ready()`)

```gdscript
_sprite_root   = $SpriteRoot
_weapon_sprite = $SpriteRoot/Weapon
_torso_sprite  = $SpriteRoot/Torso
_hair_sprite   = $SpriteRoot/Hair
_boots_sprite  = $SpriteRoot/Boots
_default_torso_region = _torso_sprite.region_rect   # saved for unequip restore
_default_hair_region  = _hair_sprite.region_rect     # saved for unequip restore
```

### Signal Connections (in `_ready()`)

```gdscript
equipment.contents_changed.connect(_update_weapon_sprite)
equipment.contents_changed.connect(_update_armor_sprites)
```

### `_update_weapon_sprite()`

1. Check WEAPON slot, fallback to TOOL slot
2. Empty → hide `_weapon_sprite`
3. `WeaponAtlas.region_for(item_id)` → `Rect2`
4. Zero-size → hide; else set `region_rect` and show

### `_update_armor_sprites()`

1. **BODY** → `_apply_armor_layer(_torso_sprite, _default_torso_region, body_id)`
2. **HEAD** → `_apply_armor_layer(_hair_sprite, _default_hair_region, head_id)`
3. **FEET** → `ArmorAtlas.region_for(boots_id)` → show/hide `_boots_sprite`, set `modulate`

### `_apply_armor_layer(sprite, default_region, item_id)`

- Empty region → restore `default_region`, `modulate = white`
- Valid region → swap `region_rect`, set `modulate = ArmorAtlas.tint_for(item_id)`

---

## Combat — Armor Defense

### `take_hit(damage: int, _attacker: Node = null)`

```
defense  = _armor_defense()
effective = max(1, damage - defense)
health   = max(0, health - effective)
```

Always deals at least 1 damage. Does nothing if `health <= 0`.

### `_armor_defense() → int`

```gdscript
equipment.total_power(HEAD) + equipment.total_power(BODY) + equipment.total_power(FEET)
```

Only counts HEAD, BODY, FEET slots — **not** WEAPON or TOOL.

---

## Inventory UI — Equip/Drop Flows

**File:** `scripts/ui/inventory_screen.gd`

### Tab System

| Tab        | Int | Shows                                  |
|------------|-----|----------------------------------------|
| EQUIPMENT  | 0   | Paperdoll — 5 equipment slots          |
| ALL        | 1   | All inventory items                    |
| WEAPONS    | 2   | Slot.WEAPON only                       |
| ARMOR      | 3   | Slot.HEAD + BODY + FEET                |
| TOOLS      | 4   | Slot.TOOL only                         |
| MATERIALS  | 5   | Slot.NONE only                         |
| CRAFTING   | 6   | CraftingPanel                          |

### Equip Flow (`_interact_cursor()`)

**From Equipment tab:** unequip selected slot → return item to inventory.

**From Grid tab:**
1. `inventory.take_slot(inv_index)` — remove from bag
2. Check `def.slot != NONE` — must be equippable
3. `equipment.unequip(slot)` — return old item to inventory if any
4. `equipment.equip(slot, item_id)`
5. Signal cascade: `contents_changed` → `_update_weapon_sprite()` + `_update_armor_sprites()`

### Drop Flow (`_drop_cursor()`)

**From Equipment tab:**
1. `equipment.unequip(slot)`
2. `_spawn_loot_pickup(id, 1)`

**From Grid tab:**
1. `inventory.remove(id, 1)`
2. `_spawn_loot_pickup(id, 1)`

### `_spawn_loot_pickup(id, amount)`

```gdscript
var pickup := LootPickup.new()
pickup.item_id = id
pickup.count = amount
pickup.position = player.position + Vector2(player._facing_x * 18, 0)
player._world.entities.add_child(pickup)
```

Spawns 18px in front of the player so it doesn't auto-pickup immediately.

---

## Adding a New Equipment Item — Checklist

1. **Define item:** Add to `ItemRegistry._register_all()` — set `slot`, `power`, icon index
2. **Atlas cell:** Add entry to `ArmorAtlas._DEFAULTS` (for armor) or `WeaponAtlas._DEFAULTS` (for weapons) with the character sheet cell
3. **Crafting recipe** (optional): Add to `CraftingRegistry._register_all()`
4. **TileMappings** (optional): Use SpritePicker to override the atlas cell in `tile_mappings.tres`
5. **Tint variant** (optional): Same cell in `ArmorAtlas._DEFAULTS` with a non-white `tint` Color

---

## Tests

**File:** `tests/unit/test_armor_defense.gd` — ArmorAtlas lookups, take_hit with defense, minimum damage  
**File:** `tests/unit/test_action_vfx.gd` — WeaponAtlas cell/region lookups  
**File:** `tests/integration/test_phase4_player.gd` — Player integration tests
