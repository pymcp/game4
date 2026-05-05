# Death Animations — Design Spec
**Date:** 2026-05-04

## Summary

Add death animations to all non-player entities. The player's existing flop animation is unchanged. Every other living entity (monsters, villagers, warriors, pets) gets a "Shrink & Pop" tween sequence whose scale and color are driven by the entity's tier and the element that delivered the killing blow.

---

## Scope

| Entity | Change |
|--------|--------|
| Player | **No change.** Existing 90° flop + math death screen stays. |
| Monster (tier 0–4) | Shrink & Pop, scaled by tier, ring colored by killing element. |
| Boss (is_boss = true) | Treated as tier 4 regardless of `tier` property. |
| Villager | Shrink & Pop at tier-1 scale. |
| Warrior | Shrink & Pop at tier-1 scale. |
| Pet | Shrink & Pop at tier-1 scale. |

---

## Animation Sequence

All Shrink & Pop animations follow the same two-phase tween:

1. **Puff** — sprite scales from 1.0× to 1.25× over the first 20% of duration.
2. **Collapse** — sprite scales from 1.25× to 0 while opacity fades from 1.0 to 0, over the remaining 80%.
3. **Ring burst** — simultaneously, an expanding circle radiates outward from the entity center and fades to 0. Color is set by killing element (see table below).

Collision, physics processing, and AI are disabled at the start of `_die()`. `queue_free()` fires after the tween completes.

---

## Tier Scaling

| Tier | Name | Duration | Ring max scale | Special |
|------|------|----------|---------------|---------|
| 0 | Normal | 0.28s | 1.8× | — |
| 1 | Uncommon / non-monster | 0.30s | 2.2× | — |
| 2 | Rare | 0.33s | 2.6× | — |
| 3 | Veteran | 0.37s | 3.0× | — |
| 4 | Elite / Boss | 0.42s | 3.5× | Double ring (second ring, 0.06s delay) + viewport shake |

**Viewport shake (tier 4 / boss only):** ±2px offset on both viewports, 0.15s duration, eased out. Implemented via a new `ViewManager.shake()` method.

---

## Element Ring Colors

The killing element is tracked on each entity as `_last_hit_element: int`, updated in `take_hit()`. The ring color at death is looked up from this value.

| Element | Color |
|---------|-------|
| Physical (0) | `#dddddd` |
| Fire | `#ff6600` |
| Ice | `#44ccff` |
| Lightning | `#ffee44` |
| Poison | `#88ff44` |
| Shadow | `#aa44ff` |

---

## Implementation Shape

### New: `DeathVFX` (`scripts/vfx/death_vfx.gd`)

A static utility script (no scene file needed). Single public method:

```gdscript
static func play(entity: Node2D, tier: int, element: int) -> void
```

- Spawns a temporary `Node2D` as a child of `entity` at local origin.
- Runs the shrink tween on the entity's sprite root.
- Draws and tweens the ring(s) on the temporary node.
- On tween completion: frees the temporary node, then calls `entity.queue_free()`.
- For tier 4: calls `ViewManager.shake()` at the moment of pop.

The entity is responsible for disabling AI/collision before calling `play()`. `DeathVFX` owns the `queue_free()` call — entities must not call it themselves.

### Changes to existing scripts

**`monster.gd`**
- Add `var _last_hit_element: int = 0` (physical).
- Update `_last_hit_element` in `take_hit()` from the incoming damage element.
- Emit `died(position, loot)` signal first (unchanged), then replace `queue_free()` with `DeathVFX.play(self, effective_tier, _last_hit_element)`, where `effective_tier = 4 if CreatureSpriteRegistry.is_boss(monster_kind) else tier`.
- Disable `set_physics_process(false)` / AI before the call.

**`villager.gd`**, **`warrior.gd`**, **`pet.gd`**
- Add `var _last_hit_element: int = 0`.
- Update in `take_hit()`.
- Emit any death signals first, then replace `queue_free()` with `DeathVFX.play(self, 1, _last_hit_element)`.

**`autoload/view_manager.gd`**
- Add `func shake(duration: float, magnitude: float) -> void` that tweens both viewport offsets.

---

## Out of Scope

- Sound effects (separate task).
- Corpse/remains on the ground (explicitly excluded — clean vanish).
- Player death animation changes.
- Any death animation for non-living interactables (chests, boats, etc.).
