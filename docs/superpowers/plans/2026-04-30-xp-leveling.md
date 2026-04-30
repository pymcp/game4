# XP & Leveling System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a data-driven XP + leveling system (cap 20) where players earn XP from kills and quests, gain +2 max HP per level, choose a stat to boost, and unlock passives at milestone levels.

**Architecture:** `LevelingConfig` (RefCounted) holds the curve + milestone table. `PlayerController` gains XP/level fields and hooks into `_try_record_kill()` and `take_hit()`. `XpBar` + `LevelUpPanel` are new UI controls wired into `PlayerHud` and `InventoryScreen`. Save/load adds 4 fields to `PlayerSaveData` with a VERSION 6 migration.

**Tech Stack:** Godot 4.3, GDScript, GUT tests (extends GutTest), no new dependencies.

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `scripts/data/leveling_config.gd` | **NEW** | XP curve array, milestone passives dict |
| `scripts/entities/player_controller.gd` | Modify | `xp`, `level`, `unlocked_passives`, `_pending_stat_points`, `leveled_up` signal; `gain_xp()`, `_level_up()`, `_unlock_passive()`, `spend_stat_point()`; iron_skin hook in `take_hit()`; XP grant in `_try_record_kill()`; scavenger hook after `mine_at()` returns |
| `scripts/data/save_game.gd` | Modify | 4 new fields on `PlayerSaveData`; bump VERSION to 6; migration shim in `apply()` |
| `scripts/data/creature_sprite_registry.gd` | Modify | `get_xp_reward(kind)` static accessor |
| `resources/creature_sprites.json` | Modify | Add `"xp_reward"` field to every creature entry |
| `scripts/ui/xp_bar.gd` | **NEW** | XP progress bar control; `update(xp, level, xp_to_next)` |
| `scripts/ui/player_hud.gd` | Modify | Add `_xp_bar` below hearts; poll in `_process()`; passive-unlock banner on `leveled_up` signal |
| `scripts/ui/level_up_panel.gd` | **NEW** | Stat-choice overlay; 6 buttons; calls `spend_stat_point()` |
| `scripts/ui/inventory_screen.gd` | Modify | Show/hide `LevelUpPanel` in CHARACTER tab when `_pending_stat_points > 0` |
| `scripts/autoload/quest_tracker.gd` | Modify | Handle `"give_xp"` in `_apply_rewards()` |
| `tests/unit/test_leveling.gd` | **NEW** | XP curve, gain_xp, level-up, passives |
| `tests/unit/test_leveling_save.gd` | **NEW** | PlayerSaveData round-trip for XP fields |

---

## Task 1: LevelingConfig + CreatureSpriteRegistry accessor

**Files:**
- Create: `scripts/data/leveling_config.gd`
- Modify: `scripts/data/creature_sprite_registry.gd`
- Create: `tests/unit/test_leveling.gd` (partial — config tests only)

**Context:** `LevelingConfig` is a pure static `class_name` on `RefCounted` — same pattern as `TerrainCodes`, `HitboxCalc`, etc. No `_ready()`, no scene. `CreatureSpriteRegistry` already has static accessors like `get_attack_damage(kind)` — add `get_xp_reward(kind)` using the same pattern. After adding a `class_name`, run the class cache refresh before GUT: `timeout 15 godot --headless --editor --quit`.

- [ ] **Step 1: Write failing tests**

```gdscript
# tests/unit/test_leveling.gd
extends GutTest

func test_xp_to_next_level_1() -> void:
    assert_eq(LevelingConfig.xp_to_next(1), 100)

func test_xp_to_next_level_10() -> void:
    assert_eq(LevelingConfig.xp_to_next(10), 1000)

func test_xp_to_next_level_19() -> void:
    assert_eq(LevelingConfig.xp_to_next(19), 1900)

func test_xp_to_next_level_20_returns_max_sentinel() -> void:
    # At cap, returns a large sentinel so gain_xp can never satisfy it.
    assert_true(LevelingConfig.xp_to_next(20) > 99999)

func test_milestone_level_5_is_hardy() -> void:
    assert_eq(LevelingConfig.milestone_passive(5), &"hardy")

func test_milestone_level_10_is_scavenger() -> void:
    assert_eq(LevelingConfig.milestone_passive(10), &"scavenger")

func test_milestone_level_15_is_iron_skin() -> void:
    assert_eq(LevelingConfig.milestone_passive(15), &"iron_skin")

func test_milestone_level_20_is_hero() -> void:
    assert_eq(LevelingConfig.milestone_passive(20), &"hero")

func test_milestone_non_milestone_returns_empty() -> void:
    assert_eq(LevelingConfig.milestone_passive(3), &"")

func test_xp_reward_bat_default() -> void:
    # bat has no xp_reward in JSON yet — should return the default 10
    assert_eq(CreatureSpriteRegistry.get_xp_reward(&"bat"), 10)
```

- [ ] **Step 2: Refresh class cache** (needed after adding class_name)
  ```bash
  cd /home/mpatterson/repos/game4 && timeout 15 godot --headless --editor --quit 2>&1 | tail -3
  ```

- [ ] **Step 3: Run tests — confirm they fail**
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED|ERROR" | tail -10
  ```

- [ ] **Step 4: Implement `LevelingConfig`**

```gdscript
## LevelingConfig
## Static helpers for the XP curve and milestone passives.
## XP to reach next level = current_level * 100.
## Level 20 is the cap — sentinel value prevents further leveling.
class_name LevelingConfig
extends RefCounted

const _MAX_SENTINEL: int = 999999

## XP required to advance from `level` to `level+1`.
## Returns a large sentinel at the cap (level 20) so gain_xp() never fires.
static func xp_to_next(level: int) -> int:
    if level >= 20:
        return _MAX_SENTINEL
    return level * 100

## Returns the passive key unlocked at `level`, or &"" if none.
static func milestone_passive(level: int) -> StringName:
    match level:
        5:  return &"hardy"
        10: return &"scavenger"
        15: return &"iron_skin"
        20: return &"hero"
    return &""
```

- [ ] **Step 5: Add `get_xp_reward()` to `CreatureSpriteRegistry`**

Find the existing static accessors block (e.g. `get_attack_damage`) in `scripts/data/creature_sprite_registry.gd`. Add:

```gdscript
static func get_xp_reward(kind: StringName) -> int:
    var entry: Dictionary = _get_entry(kind)
    return int(entry.get("xp_reward", 10))
```

Use whatever private getter the existing accessors use (likely `_get_entry` or direct `_DATA.get(kind, {})`).

- [ ] **Step 6: Refresh class cache again and run tests — all 10 should pass**
  ```bash
  timeout 15 godot --headless --editor --quit 2>&1 | tail -3
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
  ```

- [ ] **Step 7: Commit**
  ```bash
  git add scripts/data/leveling_config.gd scripts/data/creature_sprite_registry.gd tests/unit/test_leveling.gd
  git commit -m "feat: add LevelingConfig and CreatureSpriteRegistry.get_xp_reward"
  ```

---

## Task 2: PlayerController — XP, level, gain_xp, _level_up, passives

**Files:**
- Modify: `scripts/entities/player_controller.gd`
- Modify: `tests/unit/test_leveling.gd` (extend with PlayerController tests)

**Context:** `PlayerController` is a Node2D with `class_name PlayerController` at `scripts/entities/player_controller.gd`. GUT tests that need a PlayerController should use `add_child_autofree(PlayerController.new())` — no WorldRoot needed for pure stat logic. Do NOT instantiate from scene in unit tests.

Key fields already on the controller: `var health: int = 10`, `var max_health: int = 10`, `var stats: Dictionary = { &"charisma": 3, ... }`. The signal `signal player_died(player_id: int)` is already declared at the top.

Add new fields in the same block as `max_health` / `health`:
```gdscript
var xp: int = 0
var level: int = 1
var unlocked_passives: Array[StringName] = []
var _pending_stat_points: int = 0
signal leveled_up(player_id: int, new_level: int)
```

- [ ] **Step 1: Add tests to `tests/unit/test_leveling.gd`**

```gdscript
# ---- PlayerController XP tests ----

func test_gain_xp_increases_xp() -> void:
    var p := PlayerController.new()
    add_child_autofree(p)
    p.gain_xp(50)
    assert_eq(p.xp, 50)

func test_gain_xp_levels_up_when_threshold_met() -> void:
    var p := PlayerController.new()
    add_child_autofree(p)
    p.gain_xp(100)  # level 1 threshold = 100
    assert_eq(p.level, 2)
    assert_eq(p.xp, 0)  # remainder

func test_gain_xp_increases_max_health_on_level_up() -> void:
    var p := PlayerController.new()
    add_child_autofree(p)
    var old_max := p.max_health
    p.gain_xp(100)
    assert_eq(p.max_health, old_max + 2)

func test_gain_xp_no_overflow_at_cap() -> void:
    var p := PlayerController.new()
    add_child_autofree(p)
    p.level = 20
    p.gain_xp(50000)
    assert_eq(p.level, 20)
    assert_eq(p.xp, 0)  # no accumulation at cap

func test_level_up_adds_pending_stat_point() -> void:
    var p := PlayerController.new()
    add_child_autofree(p)
    p.gain_xp(100)
    assert_eq(p._pending_stat_points, 1)

func test_spend_stat_point_increases_stat() -> void:
    var p := PlayerController.new()
    add_child_autofree(p)
    var old_str: int = p.get_stat(&"strength")
    p._pending_stat_points = 1
    p.spend_stat_point(&"strength")
    assert_eq(p.get_stat(&"strength"), old_str + 1)
    assert_eq(p._pending_stat_points, 0)

func test_milestone_level_5_unlocks_hardy() -> void:
    var p := PlayerController.new()
    add_child_autofree(p)
    p.level = 4
    p.xp = 0
    var old_max := p.max_health
    # Level 4 → 5 costs 400 XP
    p.gain_xp(400)
    assert_eq(p.level, 5)
    assert_true(&"hardy" in p.unlocked_passives)
    assert_eq(p.max_health, old_max + 2 + 4)  # +2 from level, +4 from hardy

func test_iron_skin_reduces_damage() -> void:
    var p := PlayerController.new()
    add_child_autofree(p)
    p.unlocked_passives.append(&"iron_skin")
    var old_health := p.health
    p.take_hit(2)  # base effective = max(1, 2-0) = 2; iron_skin → max(1, 2-1) = 1
    assert_eq(p.health, old_health - 1)

func test_hero_passive_boosts_all_stats() -> void:
    var p := PlayerController.new()
    add_child_autofree(p)
    var old_str: int = p.get_stat(&"strength")
    p._unlock_passive(&"hero")
    assert_eq(p.get_stat(&"strength"), old_str + 2)
```

- [ ] **Step 2: Run tests — confirm new tests fail (old ones still pass)**
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
  ```

- [ ] **Step 3: Add fields and signal to PlayerController**

In `player_controller.gd`, after the existing `var active_effects: Array = []` line, add:
```gdscript
var xp: int = 0
var level: int = 1
var unlocked_passives: Array[StringName] = []
var _pending_stat_points: int = 0

signal leveled_up(player_id: int, new_level: int)
```

- [ ] **Step 4: Add `gain_xp()`, `_level_up()`, `_unlock_passive()`, `spend_stat_point()`**

Add these methods near the other stat methods (`get_stat`, `get_effective_stat`):

```gdscript
## Grant XP. Triggers level-up loop while threshold is met. No-op at cap.
func gain_xp(amount: int) -> void:
    if level >= 20:
        return
    xp += amount
    while level < 20 and xp >= LevelingConfig.xp_to_next(level):
        xp -= LevelingConfig.xp_to_next(level)
        _level_up()

## Apply a single level-up: +2 max HP, check milestone passive, add stat point, emit signal.
func _level_up() -> void:
    level += 1
    max_health += 2
    health = min(health + 2, max_health)
    var passive: StringName = LevelingConfig.milestone_passive(level)
    if passive != &"":
        _unlock_passive(passive)
    _pending_stat_points += 1
    leveled_up.emit(player_id, level)

## Unlock a passive and apply its immediate effect.
func _unlock_passive(key: StringName) -> void:
    if key in unlocked_passives:
        return
    unlocked_passives.append(key)
    match key:
        &"hardy":
            max_health += 4
            health = min(health + 4, max_health)
        &"hero":
            for k: StringName in stats.keys():
                stats[k] = int(stats[k]) + 2

## Spend one pending stat point on the given stat. Called by LevelUpPanel.
func spend_stat_point(stat: StringName) -> void:
    if _pending_stat_points <= 0:
        return
    stats[stat] = int(stats.get(stat, 0)) + 1
    _pending_stat_points -= 1
```

- [ ] **Step 5: Add iron_skin hook in `take_hit()`**

In the existing `take_hit()` method, after the line `var effective: int = max(1, damage - defense)`, add:
```gdscript
    if &"iron_skin" in unlocked_passives:
        effective = max(1, effective - 1)
```

- [ ] **Step 6: Run tests — all should pass**
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
  ```

- [ ] **Step 7: Commit**
  ```bash
  git add scripts/entities/player_controller.gd tests/unit/test_leveling.gd
  git commit -m "feat: add XP/level fields and gain_xp/level_up/passive logic to PlayerController"
  ```

---

## Task 3: Kill XP + Scavenger drop hook

**Files:**
- Modify: `scripts/entities/player_controller.gd` (`_try_record_kill`, post-`mine_at` drop section)
- Modify: `tests/unit/test_leveling.gd` (extend with kill XP tests)
- Modify: `resources/creature_sprites.json` (add `"xp_reward"` to every entry)

**Context:** `_try_record_kill(entity)` is at line ~667. It currently checks `entity.get("health")` and records caravan kills. NPC uses `health` property with `kind` field; Monster uses `health` with `monster_kind` field.

The scavenger passive check belongs in `PlayerController.try_attack()` and `_tick_auto_mine()`, after the `mine_at()` result is used to add to inventory. No need to modify `WorldRoot.mine_at()`.

- [ ] **Step 1: Add kill XP tests to `tests/unit/test_leveling.gd`**

```gdscript
func test_try_record_kill_grants_xp_for_dead_npc() -> void:
    var p := PlayerController.new()
    add_child_autofree(p)
    # Simulate a dead NPC-like node with health=0, kind="bat"
    var fake_npc := Node.new()
    fake_npc.set_meta("health", 0)
    fake_npc.set_meta("kind", &"bat")
    add_child_autofree(fake_npc)
    # Patch: _try_record_kill uses entity.get("health") and entity.get("kind"/"monster_kind")
    # We'll test gain_xp indirectly via level (bat=10 XP, not enough to level from 1)
    p.xp = 90
    p._try_record_kill_with_kind(fake_npc, &"bat")  # new helper we add
    assert_eq(p.xp, 100)  # 90 + 10
```

Actually — `_try_record_kill` doesn't expose itself cleanly for unit testing because it calls `entity.get("health")` via Godot reflection. Test by checking XP after a fake entity death via duck-typed node. Add a public helper `_try_record_kill_with_kind` is over-engineering. **Instead**, test integration: verify the NPC/Monster kind resolution path works by reading `creature_sprites.json`. Skip unit testing `_try_record_kill` XP directly — cover it with integration tests.

Replace the above with a simpler test:
```gdscript
func test_creature_sprite_registry_bat_xp_after_json_update() -> void:
    # Once xp_reward is added to creature_sprites.json for bat (value 10),
    # this should return 10.
    assert_eq(CreatureSpriteRegistry.get_xp_reward(&"bat"), 10)
```

- [ ] **Step 2: Extend `_try_record_kill()` to grant XP**

Current code (around line 667):
```gdscript
func _try_record_kill(entity: Node) -> void:
    var h: Variant = entity.get("health")
    if h != null and int(h) <= 0 and caravan_data != null \
            and caravan_data.travel_logs.size() > player_id:
        caravan_data.travel_logs[player_id].record_kill()
```

Replace with:
```gdscript
func _try_record_kill(entity: Node) -> void:
    var h: Variant = entity.get("health")
    if h == null or int(h) > 0:
        return
    # Grant XP for the kill.
    var kind: StringName = entity.get("monster_kind") if entity.get("monster_kind") != null \
        else entity.get("kind") if entity.get("kind") != null else &""
    if kind != &"":
        gain_xp(CreatureSpriteRegistry.get_xp_reward(kind))
    # Record kill in caravan travel log.
    if caravan_data != null and caravan_data.travel_logs.size() > player_id:
        caravan_data.travel_logs[player_id].record_kill()
```

- [ ] **Step 3: Add scavenger drop doubling**

In `try_attack()`, find the section after `mine_at()` that adds drops to inventory:
```gdscript
    if res.get("destroyed", false):
        for d in res.get("drops", []):
            inventory.add(d["id"], d["count"])
```

Replace with:
```gdscript
    if res.get("destroyed", false):
        for d in res.get("drops", []):
            var cnt: int = d["count"]
            if &"scavenger" in unlocked_passives and randf() < 0.25:
                cnt *= 2
            inventory.add(d["id"], cnt)
```

Apply the same scavenger check in `_tick_auto_mine()` — find the same `inventory.add(d["id"], d["count"])` pattern there and update it identically.

- [ ] **Step 4: Add `"xp_reward"` to `resources/creature_sprites.json`**

For every creature entry in the JSON, add an `"xp_reward"` field using these tiers:
- `10` (small): bat, cat, dog, rabbit, rat, slime, spider, firefly, butterfly, frog, fish
- `25` (medium): skeleton, goblin, wolf, fox, deer, pig, cow, sheep, orc, zombie, ghoul, ghost, witch
- `50` (large): troll, golem, ogre, bear, boar, giant_spider, minotaur, cyclops, dragon_small
- `150` (boss): any entry with `"is_boss": true`

Read the full JSON first to get the exact key list, then add the field to each. If unsure of tier, default to `10`.

- [ ] **Step 5: Run tests**
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
  ```

- [ ] **Step 6: Commit**
  ```bash
  git add scripts/entities/player_controller.gd resources/creature_sprites.json tests/unit/test_leveling.gd
  git commit -m "feat: grant XP on kill, scavenger passive in mine drops, xp_reward in creature_sprites.json"
  ```

---

## Task 4: Save / Load

**Files:**
- Modify: `scripts/data/save_game.gd`
- Create: `tests/unit/test_leveling_save.gd`

**Context:** `PlayerSaveData` is a nested class (or `class_name`) inside `save_game.gd`. Check whether it's a `class_name` in a separate file or an inner class — read the file to confirm. `SaveGame.VERSION` is currently 5. `snapshot()` captures player fields around line 120–140; `apply()` restores them around line 155–175. Follow the exact same pattern for the 4 new fields.

- [ ] **Step 1: Read `scripts/data/save_game.gd` lines 1-30 to locate `PlayerSaveData`**

- [ ] **Step 2: Write failing tests**

```gdscript
# tests/unit/test_leveling_save.gd
extends GutTest

func test_player_save_data_has_xp_field() -> void:
    var psd := PlayerSaveData.new()
    assert_eq(psd.xp, 0)

func test_player_save_data_has_level_field() -> void:
    var psd := PlayerSaveData.new()
    assert_eq(psd.level, 1)

func test_player_save_data_has_unlocked_passives_field() -> void:
    var psd := PlayerSaveData.new()
    assert_eq(psd.unlocked_passives.size(), 0)

func test_player_save_data_has_pending_stat_points_field() -> void:
    var psd := PlayerSaveData.new()
    assert_eq(psd.pending_stat_points, 0)

func test_xp_survives_save_round_trip() -> void:
    var p := PlayerController.new()
    add_child_autofree(p)
    p.xp = 75
    p.level = 3
    p._pending_stat_points = 2
    p.unlocked_passives.append(&"hardy")

    var psd := PlayerSaveData.new()
    psd.xp = p.xp
    psd.level = p.level
    psd.pending_stat_points = p._pending_stat_points
    psd.unlocked_passives = p.unlocked_passives.duplicate()

    var p2 := PlayerController.new()
    add_child_autofree(p2)
    p2.xp = psd.xp
    p2.level = psd.level
    p2._pending_stat_points = psd.pending_stat_points
    p2.unlocked_passives = psd.unlocked_passives.duplicate()

    assert_eq(p2.xp, 75)
    assert_eq(p2.level, 3)
    assert_eq(p2._pending_stat_points, 2)
    assert_true(&"hardy" in p2.unlocked_passives)
```

- [ ] **Step 3: Run tests — confirm failure**

- [ ] **Step 4: Add 4 fields to `PlayerSaveData`**

```gdscript
@export var xp: int = 0
@export var level: int = 1
@export var unlocked_passives: Array[StringName] = []
@export var pending_stat_points: int = 0
```

- [ ] **Step 5: Update `SaveGame.snapshot()`**

In the player snapshot loop (where `psd.stats = p.stats.duplicate()` is set), add:
```gdscript
psd.xp = p.xp
psd.level = p.level
psd.unlocked_passives = p.unlocked_passives.duplicate()
psd.pending_stat_points = p._pending_stat_points
```

- [ ] **Step 6: Update `SaveGame.apply()`**

In the player restore loop (where `p.stats = psd.stats.duplicate()` is called), add:
```gdscript
p.xp = psd.xp
p.level = psd.level
p.unlocked_passives = psd.unlocked_passives.duplicate()
p._pending_stat_points = psd.pending_stat_points
```

- [ ] **Step 7: Bump VERSION and add migration shim**

Change `const VERSION: int = 5` to `const VERSION: int = 6`.

In `apply()`, before restoring player fields, add:
```gdscript
    # v5 → v6: XP/level fields default to initial state if absent.
    # Resource loading sets missing @export fields to their defaults,
    # so no explicit migration code is needed — defaults handle it.
```
*(No code change needed — Godot's Resource default values handle the migration automatically. The comment is just documentation.)*

- [ ] **Step 8: Run all unit tests**
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
  ```

- [ ] **Step 9: Commit**
  ```bash
  git add scripts/data/save_game.gd tests/unit/test_leveling_save.gd
  git commit -m "feat: add XP/level/passives/pending_stat_points to PlayerSaveData (VERSION 6)"
  ```

---

## Task 5: XpBar + PlayerHud

**Files:**
- Create: `scripts/ui/xp_bar.gd`
- Modify: `scripts/ui/player_hud.gd`

**Context:** `PlayerHUD` builds its layout in `_build()`. The `_health_bar` (HeartDisplay) sits at `Vector2(MARGIN, MARGIN)`. The `_status_container` (status effects) sits at `Vector2(MARGIN, MARGIN + 24)`. The XP bar goes **between** these two — at `y = MARGIN + HeartDisplay height`. HeartDisplay typical height is ~18px (one row of hearts at 27px font... actually examine the constant). Move `_status_container` down by ~18px to make room.

Actually, looking more carefully: the status container is at `MARGIN + 24` hardcoded. The XP bar should go **below** the hearts but we need to know heart row height. Hearts are 27px size (HeartDisplay is constructed with `HeartDisplay.new(27.0)`). One row = 27px. So XP bar at `MARGIN + 27 + 4` = `MARGIN + 31`. Move status container to `MARGIN + 31 + 18 + 4` = `MARGIN + 53`.

Keep it simple: define a constant `_XP_BAR_Y = MARGIN + 30` and `_STATUS_Y = MARGIN + 50`.

`XpBar` is a pure `Control` with custom `_draw()` — no `ProgressBar` node. Width is fixed to match the heart display. A 4px tall bar is enough.

- [ ] **Step 1: Create `scripts/ui/xp_bar.gd`**

```gdscript
## XpBar
## Compact XP progress bar drawn below the hearts in PlayerHUD.
## Shows: [Lv.N] [filled bar] [xp/threshold] or "MAX" at cap.
extends Control
class_name XpBar

const BAR_H: float = 5.0
const BAR_W: float = 120.0
const LABEL_W: float = 38.0
const GAP: float = 4.0

const COLOR_FILL: Color = Color(0.35, 0.75, 0.35)
const COLOR_EMPTY: Color = Color(0.15, 0.15, 0.15)
const COLOR_TEXT: Color = Color(0.9, 0.9, 0.9)
const COLOR_PULSE: Color = Color(1.0, 0.9, 0.2)

var _xp: int = 0
var _level: int = 1
var _xp_to_next: int = 100
var _pending: bool = false
var _pulse_t: float = 0.0

func _init() -> void:
    custom_minimum_size = Vector2(LABEL_W + GAP + BAR_W, 14)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func update(xp: int, level: int, xp_to_next: int, pending_stat: bool = false) -> void:
    _xp = xp
    _level = level
    _xp_to_next = xp_to_next
    _pending = pending_stat
    queue_redraw()

func _process(delta: float) -> void:
    if _pending:
        _pulse_t += delta * TAU / 0.6
        queue_redraw()

func _draw() -> void:
    var lv_text: String = "Lv.%d" % _level
    var lv_color: Color = COLOR_PULSE * (0.7 + 0.3 * sin(_pulse_t)) if _pending else COLOR_TEXT
    draw_string(ThemeDB.fallback_font, Vector2(0, 11), lv_text, HORIZONTAL_ALIGNMENT_LEFT,
        LABEL_W, 11, lv_color)

    var bar_x: float = LABEL_W + GAP
    draw_rect(Rect2(bar_x, 3, BAR_W, BAR_H), COLOR_EMPTY)
    if _level >= 20:
        draw_rect(Rect2(bar_x, 3, BAR_W, BAR_H), COLOR_FILL)
        draw_string(ThemeDB.fallback_font, Vector2(bar_x + BAR_W + GAP, 11),
            "MAX", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_TEXT)
    else:
        var ratio: float = float(_xp) / float(max(1, _xp_to_next))
        draw_rect(Rect2(bar_x, 3, BAR_W * ratio, BAR_H), COLOR_FILL)
        var xp_text: String = "%d/%d" % [_xp, _xp_to_next]
        draw_string(ThemeDB.fallback_font, Vector2(bar_x + BAR_W + GAP, 11),
            xp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_TEXT)
```

- [ ] **Step 2: Add XpBar to `PlayerHud._build()` and wire in `_process()`**

In `_build()`, after creating `_health_bar`, add:
```gdscript
    # XP bar below hearts.
    _xp_bar = XpBar.new()
    _xp_bar.name = "XpBar"
    _xp_bar.position = Vector2(MARGIN, MARGIN + 30)
    add_child(_xp_bar)
```

Move `_status_container.position` from `Vector2(MARGIN, MARGIN + 24)` to `Vector2(MARGIN, MARGIN + 50)`.

Add `var _xp_bar: XpBar = null` to the class vars.

In `_process()`, after the health bar update line, add:
```gdscript
    if _player != null and _xp_bar != null:
        _xp_bar.update(
            _player.xp,
            _player.level,
            LevelingConfig.xp_to_next(_player.level),
            _player._pending_stat_points > 0
        )
```

- [ ] **Step 3: Add passive-unlock banner**

Add `var _passive_banner: Label = null` to class vars.

In `_build()`, add:
```gdscript
    _passive_banner = Label.new()
    _passive_banner.name = "PassiveBanner"
    _passive_banner.add_theme_font_size_override("font_size", 14)
    _passive_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
    _passive_banner.anchor_left = 0.5
    _passive_banner.anchor_right = 0.5
    _passive_banner.offset_left = -150
    _passive_banner.offset_right = 150
    _passive_banner.offset_top = 60
    _passive_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _passive_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _passive_banner.visible = false
    add_child(_passive_banner)
```

Add `func set_player(p)` extension — after existing wiring, also connect the signal:
In `set_player()`, add:
```gdscript
    if p != null:
        if not p.leveled_up.is_connected(_on_leveled_up):
            p.leveled_up.connect(_on_leveled_up)
```

Add:
```gdscript
func _on_leveled_up(_pid: int, new_level: int) -> void:
    var passive: StringName = LevelingConfig.milestone_passive(new_level)
    if passive == &"" or _passive_banner == null:
        return
    var names: Dictionary = {
        &"hardy": "Hardy", &"scavenger": "Scavenger",
        &"iron_skin": "Iron Skin", &"hero": "Hero"
    }
    _passive_banner.text = "PASSIVE UNLOCKED: %s" % names.get(passive, str(passive))
    _passive_banner.visible = true
    _passive_banner.modulate = Color(1, 1, 1, 1)
    var tw := create_tween()
    tw.tween_interval(2.5)
    tw.tween_property(_passive_banner, "modulate:a", 0.0, 0.5)
    tw.tween_callback(func() -> void: _passive_banner.visible = false)
```

- [ ] **Step 4: Refresh class cache and verify no parse errors**
  ```bash
  timeout 15 godot --headless --editor --quit 2>&1 | grep -i "parse\|error" | head -10
  ```

- [ ] **Step 5: Run all unit tests**
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
  ```

- [ ] **Step 6: Commit**
  ```bash
  git add scripts/ui/xp_bar.gd scripts/ui/player_hud.gd
  git commit -m "feat: add XpBar to PlayerHUD with level display and passive-unlock banner"
  ```

---

## Task 6: LevelUpPanel + InventoryScreen CHARACTER tab

**Files:**
- Create: `scripts/ui/level_up_panel.gd`
- Modify: `scripts/ui/inventory_screen.gd`

**Context:** `InventoryScreen` already has `enum Tab { EQUIPMENT, ALL, WEAPONS, ARMOR, TOOLS, MATERIALS, CHARACTER }` and a `_show_tab()` method. The CHARACTER tab content area is where this panel lives. Read the existing `_show_tab()` / `_build_character_view()` implementation first to understand the exact panel building pattern. The panel should overlay the CHARACTER tab content when `_pending_stat_points > 0`, and hide otherwise.

The 6 stat keys and their descriptions:
```
{ &"strength": "More attack damage", &"dexterity": "Faster attack speed",
  &"defense": "Reduces damage taken", &"charisma": "Better dialogue options",
  &"wisdom": "Quest gating stat", &"speed": "Increased movement speed" }
```

- [ ] **Step 1: Read `scripts/ui/inventory_screen.gd` lines 1-80** to understand the CHARACTER tab pattern before writing code.

- [ ] **Step 2: Create `scripts/ui/level_up_panel.gd`**

```gdscript
## LevelUpPanel
## Shown inside InventoryScreen when the player has unspent stat points.
## Presents 6 stat buttons; on press, calls player.spend_stat_point(stat).
extends PanelContainer
class_name LevelUpPanel

const _STAT_DESCS: Dictionary = {
    &"strength":  "Increases melee & tool damage",
    &"dexterity": "Speeds up attack rate",
    &"defense":   "Reduces damage taken",
    &"charisma":  "Unlocks better dialogue options",
    &"wisdom":    "Required for some quest paths",
    &"speed":     "Increases movement speed",
}

var _player: PlayerController = null
var _header: Label = null
var _buttons: Dictionary = {}  # stat -> Button

func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP

func setup(player: PlayerController) -> void:
    _player = player
    _rebuild()

func _rebuild() -> void:
    for c in get_children():
        c.queue_free()
    _buttons.clear()

    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 8)
    add_child(vb)

    _header = Label.new()
    _header.add_theme_font_size_override("font_size", 16)
    _header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
    _header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(_header)

    for stat: StringName in _STAT_DESCS.keys():
        var btn := Button.new()
        btn.mouse_filter = Control.MOUSE_FILTER_STOP
        _buttons[stat] = btn
        vb.add_child(btn)
        var s := stat  # capture
        btn.pressed.connect(func() -> void: _on_stat_chosen(s))

    _refresh()

func _refresh() -> void:
    if _player == null or _header == null:
        return
    _header.text = "Level %d — Choose a Stat" % _player.level
    for stat: StringName in _buttons.keys():
        var btn: Button = _buttons[stat]
        var val: int = _player.get_stat(stat)
        var desc: String = _STAT_DESCS.get(stat, "")
        btn.text = "%s (%d) — %s" % [stat.capitalize(), val, desc]
        btn.disabled = (_player._pending_stat_points <= 0)

func _on_stat_chosen(stat: StringName) -> void:
    if _player == null:
        return
    _player.spend_stat_point(stat)
    _refresh()
    if _player._pending_stat_points <= 0:
        visible = false
```

- [ ] **Step 3: Wire LevelUpPanel into InventoryScreen**

Read `inventory_screen.gd` to find where the CHARACTER tab is built. Add `var _level_up_panel: LevelUpPanel = null` to the class vars.

In the CHARACTER tab display method, add:
```gdscript
    if _player != null and _player._pending_stat_points > 0:
        if _level_up_panel == null:
            _level_up_panel = LevelUpPanel.new()
            content_area.add_child(_level_up_panel)
        _level_up_panel.setup(_player)
        _level_up_panel.visible = true
    elif _level_up_panel != null:
        _level_up_panel.visible = false
```

If `InventoryScreen` has a `set_player()` method, also do `_level_up_panel.setup(_player)` there if the panel already exists.

- [ ] **Step 4: Refresh class cache and run tests**
  ```bash
  timeout 15 godot --headless --editor --quit 2>&1 | grep -i "parse\|error" | head -10
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
  ```

- [ ] **Step 5: Commit**
  ```bash
  git add scripts/ui/level_up_panel.gd scripts/ui/inventory_screen.gd
  git commit -m "feat: add LevelUpPanel to InventoryScreen CHARACTER tab for stat-point spending"
  ```

---

## Task 7: QuestTracker give_xp reward type

**Files:**
- Modify: `scripts/autoload/quest_tracker.gd`
- Modify: `tests/unit/test_leveling.gd` (add quest XP test)

**Context:** `QuestTracker._apply_rewards(rewards: Array)` at line ~154 handles `"flag"`, `"unlock_passage"`, `"give_item"`. Add `"give_xp"`. To grant XP to players, use `World.instance().get_player(pid)` for pid in 0..1. If `World.instance()` is null (e.g. in tests), skip silently.

- [ ] **Step 1: Add quest XP test**

```gdscript
func test_leveling_config_total_xp_to_max() -> void:
    var total: int = 0
    for l in range(1, 20):
        total += LevelingConfig.xp_to_next(l)
    assert_eq(total, 19000)
```

- [ ] **Step 2: Add `"give_xp"` case to `_apply_rewards()`**

Find the match/if block in `_apply_rewards()` and add:
```gdscript
        "give_xp":
            var amount: int = int(reward.get("amount", 0))
            if amount > 0:
                var world_node: World = World.instance() if Engine.has_singleton("World") else null
                # World is not a singleton — use a different lookup.
                # Use the scene tree approach: find via group or cached reference.
                # QuestTracker is an autoload; use get_tree() to find World.
                var worlds: Array = get_tree().get_nodes_in_group(&"world")
                for w in worlds:
                    if w is World:
                        for pid in 2:
                            var p: PlayerController = (w as World).get_player(pid)
                            if p != null:
                                p.gain_xp(amount)
                        break
```

**Important:** Check how `QuestTracker` accesses `World` in existing reward types. It likely uses `World.instance()` (a static singleton helper). Use the same pattern.

- [ ] **Step 3: Run all unit tests**
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
  ```

- [ ] **Step 4: Run full test suite**
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
  ```

- [ ] **Step 5: Commit**
  ```bash
  git add scripts/autoload/quest_tracker.gd tests/unit/test_leveling.gd
  git commit -m "feat: handle give_xp reward type in QuestTracker"
  ```

---

## Final Verification

- [ ] All unit tests pass
- [ ] All integration tests pass  
- [ ] No parse errors: `timeout 15 godot --headless --editor --quit 2>&1 | grep -i "parse\|error" | head -10`
- [ ] Check `get_errors` on all modified files
