# Equipment, Stats & Combat

## Equipment (`scripts/data/equipment.gd`, 128 lines)

Resource subclass mapping equip slots to item IDs.

**Signal:** `contents_changed`

**Data:** `equipped: Dictionary` — maps `ItemDefinition.Slot` int → `StringName` item_id.

### Public API

| Method | Returns | Notes |
|--------|---------|-------|
| `can_equip(slot, id) → bool` | | Rejects OFF_HAND if WEAPON is 2-handed |
| `equip(slot, id) → Array` | `[[slot, id], ...]` | Displaced pairs returned. 2H weapon auto-unequips OFF_HAND |
| `unequip(slot) → StringName` | Old item ID or `&""` | |
| `get_equipped(slot) → StringName` | Item ID or `&""` | |
| `total_power(only_slot?) → int` | Sum of `power` across equipped items | |
| `equipment_stat_totals() → Dictionary` | `{stat_name: int}` | Includes item `stat_bonuses` + armor set bonuses |
| `get_active_set_bonuses() → Dictionary` | `{stat_name: int}` | Via ArmorSetRegistry |
| `to_dict() / from_dict(data)` | | Serialization |

### Handedness Rules

- `hands == 2`: Two-handed weapon. On equip to WEAPON slot, auto-unequips OFF_HAND (returned as displaced pair).
- `can_equip()` for OFF_HAND returns false if current WEAPON has `hands == 2`.
- Displaced items are returned to inventory by the UI layer.

---

## Armor Sets (`scripts/data/armor_set_registry.gd`, 75 lines)

Static registry loading `resources/armor_sets.json`.

| Method | Returns |
|--------|---------|
| `get_set(set_id) → Dictionary` | Raw set entry |
| `all_ids() → Array` | All set IDs |
| `calc_set_bonuses(set_id, piece_count) → Dictionary` | Cumulative stat bonuses |
| `reset()` | Clear cache |

### Current Sets (`resources/armor_sets.json`)

| Set | 2-piece Bonus | 3-piece Bonus (cumulative) |
|-----|---------------|---------------------------|
| `leather` | +1 speed | +1 speed, +1 defense |
| `iron` | +1 defense | +2 defense, +1 strength |

Thresholds are cumulative — 3pc grants 2pc + 3pc bonuses combined.

---

## Player Stats (`scripts/entities/player_controller.gd`)

### Base Stats

```gdscript
var stats: Dictionary = {
    &"charisma": 3, &"wisdom": 3, &"strength": 3,
    &"speed": 0, &"defense": 0, &"dexterity": 0,
}
```

### Stat Resolution

| Method | Formula |
|--------|---------|
| `get_stat(name) → int` | Raw base value |
| `get_effective_stat(name) → int` | Base + `equipment.equipment_stat_totals().get(name, 0)` |
| `get_move_speed() → float` | `60.0 * (1.0 + effective_speed * 0.05)` |

**Stat effects:**
| Stat | Effect |
|------|--------|
| `strength` | Added to weapon power for attack damage |
| `defense` | Added to armor power sum for damage reduction |
| `speed` | +5% movement speed per point |
| `charisma` | (Future: NPC pricing/dialogue) |
| `wisdom` | (Future: quest/spell effects) |
| `dexterity` | (Future: crit chance / dodge) |

---

## Combat System

### Attack Flow (PlayerController)

**Constants:** `ATTACK_COOLDOWN_SEC = 0.35`, `_MELEE_REACH_PX = 24.0`, `_RANGED_REACH_PX = 80.0`

1. Player has equipped weapon → `_tick_auto_attack()` runs each frame
2. Cooldown check: `attack_speed > 0 ? attack_speed : 0.35` seconds
3. Route by `attack_type`: MELEE → `_auto_attack_melee()`, RANGED → `_auto_attack_ranged()`

**Melee:** Find nearest hostile (Monster/NPC) within `def.reach` pixels. Deal `max(1, def.power + get_effective_stat(&"strength"))`. Apply element from weapon def.

**Ranged:** Fire in facing direction. Dot-product check (>0.7 ≈ 45° cone). One target per shot. Same damage formula.

**VFX dispatch:** Reads `weapon_category` and `element`, calls `action_vfx.play_attack(target, category, element, speed)`.

### Damage Formula

```
attack_power = max(1, weapon.power + get_effective_stat(&"strength"))
```

### Defense Formula (PlayerController.take_hit)

```
armor_defense = HEAD.power + BODY.power + FEET.power + OFF_HAND.power + get_effective_stat(&"defense")
effective_damage = max(1, raw_damage - armor_defense)
```

### Element System

Elements: NONE(0), FIRE(1), ICE(2), LIGHTNING(3), POISON(4).

Resistance is a `Dictionary` mapping `Element` int → `float` multiplier:
- `0.0` = immune (takes 0 damage from that element)
- `0.5` = resistant (half damage)
- `1.0` = normal
- `2.0` = vulnerable (double damage)

Applied via `_apply_resistance(damage, element)`:
```
if element == 0 or no resistance entry → max(1, damage)
else → max(1, ceili(damage * multiplier))
```

This system is identical in Monster and NPC.

---

## ActionVFX (`scripts/entities/action_vfx.gd`, 407 lines)

Visual effects dispatcher for weapon attacks.

### Weapon Category → VFX Mapping

| Category | Method | Motion |
|----------|--------|--------|
| SWORD | `_play_swing` | Arc -60° to +60° |
| AXE | `_play_swing` | Arc -90° to +20° |
| DAGGER | `_play_swing` | Arc -30° to +30°, 60% duration |
| SPEAR | `_play_thrust` | Linear forward thrust |
| BOW | `play_ranged` | Arrow projectile |
| STAFF | `_play_spell` | Colored orb projectile |
| Default | `_play_swing` | Arc -60° to +60° |

**Element colors (spell orb):** FIRE=orange, ICE=cyan, LIGHTNING=yellow, POISON=green, default=purple.

**Duration:** `clampf(attack_speed * 0.6, 0.1, 0.4)` seconds.

**Other VFX:**
- `play_mine_swing(target_cell, kind)` — mining tool animation
- `play_gather(target_cell)` — tile shake + rustle for gathering
- `play_melee_swing(target_cell)` — legacy melee (bare hands)

---

## Adding a New Weapon

1. Add JSON entry in `resources/items.json` (use `"parent": "base_sword"` etc.)
2. Set: `slot`, `power`, `attack_type`, `attack_speed`, `reach`, `weapon_category`, `element` (if any)
3. Set `weapon_sprite` to CharacterAtlas grid coords
4. Set `rarity`, `stat_bonuses`, `knockback` as desired
5. For set bonus items: set `set_id` matching `armor_sets.json`
6. VFX auto-routes based on `weapon_category` — no code changes needed

## Adding New Armor

1. Add JSON entry with `"parent": "base_helmet"` (or base_armor/base_boots)
2. Set: `slot` (HEAD/BODY/FEET), `power`, `armor_sprite`, `armor_tint`
3. For armor sets: set `set_id` and add thresholds to `armor_sets.json`
4. `stat_bonuses` for passive stat boosts
