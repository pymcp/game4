# Death Animations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Shrink & Pop death animation to all non-player entities (monsters, villagers, warriors, pets), with ring color driven by the killing element and pop intensity scaled by tier.

**Architecture:** Two new scripts (`DeathRing`, `DeathVFX`) provide a self-contained animation utility. Each entity tracks `_last_hit_element` and calls `DeathVFX.play()` in place of `queue_free()`. The ring node is reparented to the entity's parent so it outlives the entity. Player death is unchanged.

**Tech Stack:** Godot 4.3, GDScript, GUT test framework (`addons/gut`). Tests run headless: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/<file>.gd -gexit`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `scripts/vfx/death_ring.gd` | Self-drawing expanding ring node; frees itself when done |
| Create | `scripts/vfx/death_vfx.gd` | Static `play()` entry point; owns the shrink tween and spawns rings |
| Create | `tests/unit/test_death_animations.gd` | Unit tests for element/tier lookups and element tracking |
| Modify | `scripts/main/game.gd:249` | Add cameras to `"player_cameras"` group for shake |
| Modify | `scripts/entities/monster.gd` | Track `_last_hit_element`, call `DeathVFX.play()` in `_die()` |
| Modify | `scripts/entities/villager.gd` | Track `_last_hit_element`, call `DeathVFX.play()` in `take_hit` death path |
| Modify | `scripts/entities/warrior.gd` | Add element param, track `_last_hit_element`, call `DeathVFX.play()` in `_on_die()` |
| Modify | `scripts/entities/pet.gd` | Fix health floor, add element param, track `_last_hit_element`, call `DeathVFX.play()` |

---

## Task 1: DeathRing node

**Files:**
- Create: `scripts/vfx/death_ring.gd`
- Test: `tests/unit/test_death_animations.gd`

- [ ] **Step 1.1: Write the failing test**

Create `tests/unit/test_death_animations.gd`:

```gdscript
extends GutTest


# ── DeathRing ────────────────────────────────────────────────────────

func test_death_ring_can_instantiate() -> void:
    var ring := DeathRing.new()
    add_child_autofree(ring)
    assert_not_null(ring)


func test_death_ring_default_properties() -> void:
    var ring := DeathRing.new()
    add_child_autofree(ring)
    assert_almost_eq(ring.max_radius, 20.0, 0.01)
    assert_almost_eq(ring.lifetime, 0.35, 0.01)
    assert_eq(ring.color, Color.WHITE)
    assert_almost_eq(ring.delay, 0.0, 0.01)


func test_death_ring_properties_settable() -> void:
    var ring := DeathRing.new()
    ring.max_radius = 30.0
    ring.lifetime = 0.5
    ring.color = Color(1.0, 0.4, 0.0)
    ring.delay = 0.06
    add_child_autofree(ring)
    assert_almost_eq(ring.max_radius, 30.0, 0.01)
    assert_almost_eq(ring.lifetime, 0.5, 0.01)
    assert_eq(ring.color, Color(1.0, 0.4, 0.0))
    assert_almost_eq(ring.delay, 0.06, 0.01)
```

- [ ] **Step 1.2: Run test to confirm failure**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -gtest=res://tests/unit/test_death_animations.gd \
    -gexit 2>&1 | tail -15
```

Expected: FAIL — `DeathRing` class not found.

- [ ] **Step 1.3: Implement DeathRing**

Create `scripts/vfx/death_ring.gd`:

```gdscript
## DeathRing
##
## Self-drawing expanding ring that frees itself when its lifetime expires.
## Added as a sibling of the dying entity (not a child) so it outlives queue_free.
extends Node2D
class_name DeathRing

var max_radius: float = 20.0
var lifetime: float = 0.35
var color: Color = Color.WHITE
var delay: float = 0.0

var _t: float = 0.0


func _process(delta: float) -> void:
    _t += delta
    if _t < delay:
        return
    if _t >= delay + lifetime:
        queue_free()
        return
    queue_redraw()


func _draw() -> void:
    var f: float = clamp((_t - delay) / lifetime, 0.0, 1.0)
    var r: float = lerp(0.0, max_radius, f)
    var alpha: float = (1.0 - f) * color.a
    draw_arc(Vector2.ZERO, r, 0.0, TAU, 48,
            Color(color.r, color.g, color.b, alpha), 2.0, true)
```

- [ ] **Step 1.4: Refresh class cache**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless --editor --quit-after 30 --path . >/dev/null 2>&1; true
```

- [ ] **Step 1.5: Run test to confirm pass**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -gtest=res://tests/unit/test_death_animations.gd \
    -gexit 2>&1 | tail -15
```

Expected: all 3 tests PASS.

- [ ] **Step 1.6: Commit**

```bash
git add scripts/vfx/death_ring.gd tests/unit/test_death_animations.gd
git commit -m "feat: add DeathRing expanding-ring VFX node"
```

---

## Task 2: DeathVFX utility

**Files:**
- Create: `scripts/vfx/death_vfx.gd`
- Test: `tests/unit/test_death_animations.gd`

- [ ] **Step 2.1: Add failing tests for DeathVFX lookups**

Append to `tests/unit/test_death_animations.gd`:

```gdscript
# ── DeathVFX ─────────────────────────────────────────────────────────

func test_element_color_physical() -> void:
    assert_eq(DeathVFX.ELEMENT_COLORS[ItemDefinition.Element.NONE],
        Color("#dddddd"))


func test_element_color_fire() -> void:
    assert_eq(DeathVFX.ELEMENT_COLORS[ItemDefinition.Element.FIRE],
        Color("#ff6600"))


func test_element_color_ice() -> void:
    assert_eq(DeathVFX.ELEMENT_COLORS[ItemDefinition.Element.ICE],
        Color("#44ccff"))


func test_element_color_lightning() -> void:
    assert_eq(DeathVFX.ELEMENT_COLORS[ItemDefinition.Element.LIGHTNING],
        Color("#ffee44"))


func test_element_color_poison() -> void:
    assert_eq(DeathVFX.ELEMENT_COLORS[ItemDefinition.Element.POISON],
        Color("#88ff44"))


func test_tier0_duration() -> void:
    assert_almost_eq(float(DeathVFX.TIER_PARAMS[0][0]), 0.28, 0.001)


func test_tier4_duration() -> void:
    assert_almost_eq(float(DeathVFX.TIER_PARAMS[4][0]), 0.42, 0.001)


func test_tier0_radius() -> void:
    assert_almost_eq(float(DeathVFX.TIER_PARAMS[0][1]), 18.0, 0.01)


func test_tier4_radius() -> void:
    assert_almost_eq(float(DeathVFX.TIER_PARAMS[4][1]), 35.0, 0.01)


func test_play_does_not_crash_with_node2d() -> void:
    var entity := Node2D.new()
    var visual := Node2D.new()
    entity.add_child(visual)
    add_child(entity)
    # Tier 0, physical — no shake, one ring.
    DeathVFX.play(entity, visual, 0, ItemDefinition.Element.NONE)
    # entity will be queue_freed by DeathVFX; autofree on test teardown is fine.
    assert_true(true, "play() did not crash")
```

- [ ] **Step 2.2: Run to confirm failure**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -gtest=res://tests/unit/test_death_animations.gd \
    -gexit 2>&1 | tail -15
```

Expected: FAIL — `DeathVFX` class not found.

- [ ] **Step 2.3: Implement DeathVFX**

Create `scripts/vfx/death_vfx.gd`:

```gdscript
## DeathVFX
##
## Static utility for the Shrink-and-Pop death animation.
## Call DeathVFX.play() from an entity's _die() in place of queue_free().
## DeathVFX owns the queue_free() call.
class_name DeathVFX

## Ring color indexed by ItemDefinition.Element value.
const ELEMENT_COLORS: Dictionary = {
    0: Color("#dddddd"),  # NONE / Physical
    1: Color("#ff6600"),  # FIRE
    2: Color("#44ccff"),  # ICE
    3: Color("#ffee44"),  # LIGHTNING
    4: Color("#88ff44"),  # POISON
}

## [duration_sec, ring_max_radius_px] indexed by tier 0–4.
const TIER_PARAMS: Array = [
    [0.28, 18.0],
    [0.30, 22.0],
    [0.33, 26.0],
    [0.37, 30.0],
    [0.42, 35.0],
]

## Play the death animation on [param entity].
## [param visual] is the sprite or sprite root to shrink (child of entity).
## [param tier] is 0–4; clamped if out of range.
## [param element] is an ItemDefinition.Element int for ring color.
## entity.queue_free() is called when the tween completes — do NOT call it yourself.
static func play(entity: Node2D, visual: Node2D, tier: int, element: int) -> void:
    var p: Array = TIER_PARAMS[clampi(tier, 0, 4)]
    var dur: float = p[0]
    var radius: float = p[1]
    var col: Color = ELEMENT_COLORS.get(element, ELEMENT_COLORS[0])

    _spawn_ring(entity, radius, dur * 1.1, col, 0.0)
    if tier >= 4:
        _spawn_ring(entity, radius * 0.65, dur, col, 0.06)
        _shake_all_cameras(entity, 2.0, 0.15)

    var tw: Tween = entity.create_tween()
    tw.tween_property(visual, "scale", Vector2(1.25, 1.25), dur * 0.2)
    tw.tween_property(visual, "scale", Vector2.ZERO, dur * 0.8) \
            .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_callback(entity.queue_free)

    var tw_fade: Tween = entity.create_tween()
    tw_fade.tween_interval(dur * 0.4)
    tw_fade.tween_property(visual, "modulate:a", 0.0, dur * 0.6)


static func _spawn_ring(entity: Node2D, radius: float, lifetime: float,
        col: Color, delay: float) -> void:
    var ring := DeathRing.new()
    ring.max_radius = radius
    ring.lifetime = lifetime
    ring.color = col
    ring.delay = delay
    ring.global_position = entity.global_position
    entity.get_parent().add_child(ring)


static func _shake_all_cameras(entity: Node2D, magnitude: float, duration: float) -> void:
    for cam: Node in entity.get_tree().get_nodes_in_group(&"player_cameras"):
        var tw: Tween = cam.create_tween()
        tw.tween_property(cam, "offset", Vector2(magnitude, magnitude), duration * 0.25)
        tw.tween_property(cam, "offset", Vector2(-magnitude, 0.0), duration * 0.25)
        tw.tween_property(cam, "offset", Vector2.ZERO, duration * 0.5) \
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
```

- [ ] **Step 2.4: Refresh class cache**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless --editor --quit-after 30 --path . >/dev/null 2>&1; true
```

- [ ] **Step 2.5: Run tests to confirm pass**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -gtest=res://tests/unit/test_death_animations.gd \
    -gexit 2>&1 | tail -15
```

Expected: all tests PASS.

- [ ] **Step 2.6: Commit**

```bash
git add scripts/vfx/death_vfx.gd tests/unit/test_death_animations.gd
git commit -m "feat: add DeathVFX shrink-and-pop utility with tier/element params"
```

---

## Task 3: Camera group for shake

**Files:**
- Modify: `scripts/main/game.gd`

- [ ] **Step 3.1: Add cameras to group**

In `scripts/main/game.gd`, find `_make_camera` (around line 248). After `cam.make_current()`, add the group line:

```gdscript
func _make_camera(player: PlayerController, viewport: SubViewport) -> Camera2D:
    var cam := Camera2D.new()
    cam.name = "Camera2D"
    cam.custom_viewport = viewport
    cam.zoom = Vector2.ONE
    cam.position_smoothing_enabled = false
    player.add_child(cam)
    cam.make_current()
    cam.add_to_group(&"player_cameras")  # ← add this line
    return cam
```

- [ ] **Step 3.2: Commit**

```bash
git add scripts/main/game.gd
git commit -m "feat: add player cameras to player_cameras group for death shake"
```

---

## Task 4: Monster death animation

**Files:**
- Modify: `scripts/entities/monster.gd`
- Test: `tests/unit/test_death_animations.gd`

- [ ] **Step 4.1: Add failing test for element tracking**

Append to `tests/unit/test_death_animations.gd`:

```gdscript
# ── Monster element tracking ─────────────────────────────────────────

func test_monster_tracks_last_hit_element() -> void:
    var m := Monster.new()
    add_child_autofree(m)
    m.take_hit(1, null, ItemDefinition.Element.FIRE)
    assert_eq(m._last_hit_element, ItemDefinition.Element.FIRE)


func test_monster_element_updates_on_repeated_hits() -> void:
    var m := Monster.new()
    add_child_autofree(m)
    m.take_hit(1, null, ItemDefinition.Element.FIRE)
    m.take_hit(1, null, ItemDefinition.Element.ICE)
    assert_eq(m._last_hit_element, ItemDefinition.Element.ICE)


func test_monster_element_defaults_to_physical() -> void:
    var m := Monster.new()
    add_child_autofree(m)
    assert_eq(m._last_hit_element, ItemDefinition.Element.NONE)
```

- [ ] **Step 4.2: Run to confirm failure**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -gtest=res://tests/unit/test_death_animations.gd \
    -gexit 2>&1 | tail -15
```

Expected: FAIL — `_last_hit_element` not a member of Monster.

- [ ] **Step 4.3: Add `_last_hit_element` and update `take_hit`**

In `scripts/entities/monster.gd`, after the existing `var _attack_element: int = 0` line (around line 43), add:

```gdscript
var _last_hit_element: int = 0  ## Element that last dealt damage; used by DeathVFX.
```

In `take_hit` (around line 268), after the resistance check and before the `_die()` call, record the element:

```gdscript
func take_hit(damage: int, _attacker: Node = null, element: int = 0) -> void:
    if _lod_sleeping:
        _lod_sleeping = false
        set_process(true)
    if in_conversation:
        return
    var effective: int = _apply_resistance(damage, element)
    health = max(0, health - effective)
    _last_hit_element = element  # ← add this line
    ActionParticles.flash_hit(self)
    if element != 0:
        _apply_status_from_element(element)
    if health <= 0:
        _die()
```

- [ ] **Step 4.4: Run to confirm test passes**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -gtest=res://tests/unit/test_death_animations.gd \
    -gexit 2>&1 | tail -15
```

Expected: all tests PASS.

- [ ] **Step 4.5: Update `_die()` to call DeathVFX**

Replace `_die()` in `scripts/entities/monster.gd` (around line 292):

```gdscript
func _die() -> void:
    set_process(false)
    set_physics_process(false)
    var loot: Array = drops.duplicate()
    if loot.is_empty():
        loot = LootTableRegistry.roll_drops(monster_kind)
    died.emit(position, loot)
    var effective_tier: int = 4 if CreatureSpriteRegistry.is_boss(monster_kind) else tier
    DeathVFX.play(self, _sprite, effective_tier, _last_hit_element)
```

- [ ] **Step 4.6: Run full test suite to confirm no regressions**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -gexit 2>&1 | tail -20
```

Expected: all tests PASS.

- [ ] **Step 4.7: Commit**

```bash
git add scripts/entities/monster.gd tests/unit/test_death_animations.gd
git commit -m "feat: monster death uses DeathVFX shrink-and-pop"
```

---

## Task 5: Villager death animation

**Files:**
- Modify: `scripts/entities/villager.gd`

- [ ] **Step 5.1: Add `_last_hit_element` variable**

In `scripts/entities/villager.gd`, find the variable declarations near the top. Add after the health variables:

```gdscript
var _last_hit_element: int = 0  ## Element that last dealt damage; used by DeathVFX.
```

- [ ] **Step 5.2: Update `take_hit` to track element and call DeathVFX**

In `scripts/entities/villager.gd`, find `take_hit` (around line 293). Change the parameter name from `_element` to `element` and add tracking + DeathVFX call:

```gdscript
func take_hit(damage: int, attacker: Node = null, element: int = 0) -> void:
    if health <= 0:
        return
    if _lod_sleeping:
        _lod_sleeping = false
        set_physics_process(true)
    if in_conversation:
        return
    var effective: int = max(1, damage)
    health = max(0, health - effective)
    _last_hit_element = element  # ← add this line
    ActionParticles.flash_hit(self)
    if health <= 0:
        set_physics_process(false)
        DeathVFX.play(self, _sprite_root, 1, _last_hit_element)  # ← replace queue_free()
        return
    if attacker is Node2D:
        _threat_target = attacker as Node2D
        _state_timer = 0.0
        _path = []
        if is_cowardly:
            state = State.FLEE
```

- [ ] **Step 5.3: Run full suite**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -gexit 2>&1 | tail -20
```

Expected: all tests PASS.

- [ ] **Step 5.4: Commit**

```bash
git add scripts/entities/villager.gd
git commit -m "feat: villager death uses DeathVFX shrink-and-pop"
```

---

## Task 6: Warrior death animation

**Files:**
- Modify: `scripts/entities/warrior.gd`

- [ ] **Step 6.1: Add `_last_hit_element` and `_dying` guard**

In `scripts/entities/warrior.gd`, find the variable declarations. Add alongside the health variable:

```gdscript
var _last_hit_element: int = 0  ## Element that last dealt damage; used by DeathVFX.
var _dying: bool = false         ## Prevents _on_die() from firing twice.
```

- [ ] **Step 6.2: Update `take_hit` to accept and track element**

Find `take_hit` in `scripts/entities/warrior.gd` (around line 145). Add the element parameter and tracking:

```gdscript
func take_hit(damage: int, _attacker: Node = null, element: int = 0) -> void:
    health -= max(1, damage)
    _last_hit_element = element  # ← add this line
    if _sprite != null:
        ActionParticles.flash_hit(_sprite)
    if health <= 0:
        health = 0
```

- [ ] **Step 6.3: Update `_on_die()` to use DeathVFX**

Find `_on_die()` in `scripts/entities/warrior.gd` (around line 153). Replace its body:

```gdscript
func _on_die() -> void:
    if _dying:
        return
    _dying = true
    set_process(false)
    warrior_died.emit(position)
    DeathVFX.play(self, _sprite, 1, _last_hit_element)
```

- [ ] **Step 6.4: Run full suite**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -gexit 2>&1 | tail -20
```

Expected: all tests PASS.

- [ ] **Step 6.5: Commit**

```bash
git add scripts/entities/warrior.gd
git commit -m "feat: warrior death uses DeathVFX shrink-and-pop"
```

---

## Task 7: Pet death animation

**Files:**
- Modify: `scripts/entities/pet.gd`

- [ ] **Step 7.1: Add `_last_hit_element` variable**

In `scripts/entities/pet.gd`, find the variable declarations near the top (near `health`). Add:

```gdscript
var _last_hit_element: int = 0  ## Element that last dealt damage; used by DeathVFX.
```

- [ ] **Step 7.2: Update `take_hit` to accept element, allow death, and call DeathVFX**

Find `take_hit` in `scripts/entities/pet.gd` (around line 360). The comment above it notes pets can't die in v1 — that's intentional up to now, but pets are now killable. Replace the function:

```gdscript
func take_hit(damage: int, _attacker: Node = null, element: int = 0) -> void:
    _last_hit_element = element
    health = max(0, health - damage)
    ActionParticles.flash_hit(self)
    if health <= 0:
        set_physics_process(false)
        DeathVFX.play(self, _sprite, 1, _last_hit_element)
```

- [ ] **Step 7.3: Run full suite**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -gexit 2>&1 | tail -20
```

Expected: all tests PASS.

- [ ] **Step 7.4: Commit**

```bash
git add scripts/entities/pet.gd
git commit -m "feat: pet death uses DeathVFX shrink-and-pop"
```

---

## Task 8: Final regression check

- [ ] **Step 8.1: Run entire test suite one last time**

```bash
cd /home/mpatterson/repos/game4/.claude/worktrees/quiet-bubbling-avalanche && \
  godot --headless -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit \
    -gexit 2>&1 | tail -20
```

Expected: all tests PASS, zero failures.

- [ ] **Step 8.2: Audit checklist**

Review all changed files for:
- Dead code left behind (old `queue_free()` calls that should have been removed)
- Any entity that still directly calls `queue_free()` in its death path instead of `DeathVFX.play()`
- `TIER_PARAMS` and `ELEMENT_COLORS` constants match the spec exactly

---

## Notes

- **Player death is unchanged.** `player_controller.gd` is not touched.
- **Tests for tween behavior are not written** — tweens require a running scene process loop and can't be meaningfully asserted headlessly. The visual result is verified by playtesting.
- **Pet death is a behavior change.** Pets were intentionally unkillable in v1 (`max(1, ...)` floor). This plan removes that floor. If you want to preserve the v1 behavior and only add VFX for future use, keep `max(1, ...)` and skip the `if health <= 0` block in Task 7.
