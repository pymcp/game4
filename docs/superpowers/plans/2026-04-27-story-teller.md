# Story Teller Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Story Teller as a permanent 5th caravan member with a structured recap panel (Quests, Voices Overheard, Last Adventure), backed by a per-player TravelLog, random names from a JSON pool, and a fix to the QuestTracker save gap.

**Architecture:** New data resources (TravelLog, NamesRegistry) extend the existing CaravanData/SaveGame pattern. A StoryTellerPanel Control replaces the warrior-label fallback in CaravanMenu for the story_teller member. Kill/loot/chest/floor hooks are light one-liners inserted at existing call sites in PlayerController, TreasureChest, and world.gd.

**Tech Stack:** Godot 4.3, GDScript, GUT 9.3, JSON data files, existing CaravanData/SaveGame/QuestTracker/GameState autoload patterns.

---

## File Map

| File | Status | Responsibility |
|---|---|---|
| `resources/names.json` | **Create** | Name pools per role |
| `resources/lore_text.json` | **Create** | `lore_*` flag → flavor text map |
| `scripts/data/names_registry.gd` | **Create** | `roll_name(role, rng) -> String` static helper |
| `scripts/data/travel_log.gd` | **Create** | Per-player dungeon run tracker resource |
| `scripts/data/caravan_data.gd` | **Modify** | Add `travel_logs[]`, `member_names`, `get_member_name()` |
| `scripts/data/caravan_save_data.gd` | **Modify** | Add `travel_log_data`, `member_names` fields |
| `scripts/data/save_game.gd` | **Modify** | Add `quest_tracker_data`, VERSION 3→4 |
| `scripts/autoload/game_state.gd` | **Modify** | Add `keys_with_prefix(prefix) -> Array[String]` |
| `scripts/world/world.gd` | **Modify** | Auto-recruit story_teller, roll+assign names, floor transition hook |
| `scripts/entities/player_controller.gd` | **Modify** | Kill hooks in try_attack + auto-attack paths |
| `scripts/entities/loot_pickup.gd` | **Modify** | `record_loot()` hook in pickup path |
| `scripts/entities/treasure_chest.gd` | **Modify** | `record_chest()` hook in `open()` |
| `resources/party_members.json` | **Modify** | Add `story_teller` entry |
| `scripts/ui/story_teller_panel.gd` | **Create** | Three-tab Story Teller panel |
| `scripts/ui/caravan_menu.gd` | **Modify** | Wire story_teller → StoryTellerPanel |
| `tests/unit/test_names_registry.gd` | **Create** | NamesRegistry tests |
| `tests/unit/test_travel_log.gd` | **Create** | TravelLog round-trip and counter tests |
| `tests/unit/test_game_state_prefix.gd` | **Create** | keys_with_prefix tests |
| `tests/unit/test_story_teller_save.gd` | **Create** | Save/load round-trip for new fields |
| `tests/integration/test_story_teller_menu.gd` | **Create** | StoryTellerPanel appears in CaravanMenu |

---

## Task 1 — `names.json` + NamesRegistry

**Files:**
- Create: `resources/names.json`
- Create: `scripts/data/names_registry.gd`
- Create: `tests/unit/test_names_registry.gd`

- [ ] **Step 1: Create `resources/names.json`**

```json
{
  "story_teller": ["Edda", "Lira", "Sorren", "Vael", "Myr"],
  "warrior":      ["Derin", "Kael", "Brynn", "Torva", "Grath"],
  "blacksmith":   ["Gund", "Petra", "Orin", "Mave", "Skor"],
  "cook":         ["Hessie", "Tam", "Brix", "Corla", "Wynn"],
  "alchemist":    ["Syle", "Fenn", "Cress", "Vix", "Nael"]
}
```

- [ ] **Step 2: Write failing test**

```gdscript
# tests/unit/test_names_registry.gd
extends GutTest

func before_each() -> void:
    NamesRegistry.reset()

func test_roll_name_returns_string_from_pool() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    var name: String = NamesRegistry.roll_name(&"story_teller", rng)
    assert_true(name.length() > 0, "Should return a non-empty name")
    assert_true(name in ["Edda", "Lira", "Sorren", "Vael", "Myr"],
            "Name should be from the story_teller pool")

func test_roll_name_unknown_role_returns_role_string() -> void:
    var rng := RandomNumberGenerator.new()
    var name: String = NamesRegistry.roll_name(&"wizard", rng)
    assert_eq(name, "wizard", "Unknown role should return role id as fallback")

func test_all_roles_have_pools() -> void:
    for role in [&"story_teller", &"warrior", &"blacksmith", &"cook", &"alchemist"]:
        var pool := NamesRegistry.get_pool(role)
        assert_true(pool.size() >= 3, "Pool for %s should have at least 3 names" % role)
```

- [ ] **Step 3: Run test — expect FAIL (NamesRegistry not found)**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_names_registry.gd -gexit 2>&1 | tail -10
```

- [ ] **Step 4: Create `scripts/data/names_registry.gd`**

```gdscript
## NamesRegistry
##
## Static loader for res://resources/names.json.
## Provides a pool of names per party member role, used to give each
## caravan member a unique name at game start.
class_name NamesRegistry
extends RefCounted

const _PATH: String = "res://resources/names.json"

static var _cache: Dictionary = {}

## Returns a random name from the pool for [param role].
## Falls back to [code]String(role)[/code] if the role is not found.
static func roll_name(role: StringName, rng: RandomNumberGenerator) -> String:
    var pool: Array = get_pool(role)
    if pool.is_empty():
        return String(role)
    return pool[rng.randi() % pool.size()]

## Returns the full name pool for [param role].
static func get_pool(role: StringName) -> Array:
    _ensure_loaded()
    return _cache.get(String(role), [])

## Clears the cache (call in tests).
static func reset() -> void:
    _cache.clear()

static func _ensure_loaded() -> void:
    if not _cache.is_empty():
        return
    var f := FileAccess.open(_PATH, FileAccess.READ)
    if f == null:
        push_warning("[NamesRegistry] could not open %s" % _PATH)
        return
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()
    if parsed is Dictionary:
        _cache = parsed
```

- [ ] **Step 5: Refresh class cache**

```bash
cd /home/mpatterson/repos/game4 && timeout 15 godot --headless --editor --quit 2>/dev/null; true
```

- [ ] **Step 6: Run test — expect PASS**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_names_registry.gd -gexit 2>&1 | tail -10
```
Expected: `Passing 3` / `Failing 0`

- [ ] **Step 7: Commit**

```bash
git add resources/names.json scripts/data/names_registry.gd tests/unit/test_names_registry.gd
git commit -m "data: NamesRegistry with per-role name pools"
```

---

## Task 2 — `lore_text.json`

**Files:**
- Create: `resources/lore_text.json`

No tests needed — purely data, read by StoryTellerPanel in Task 9.

- [ ] **Step 1: Create `resources/lore_text.json`**

```json
{
  "lore_example": "The locals whisper of strange lights in the northern hills."
}
```

This file grows as quest/dialogue authors add `lore_*` flags via `DialogueChoice.set_flag`. The Story Teller panel does a lookup here at render time; missing keys fall back to a prettified flag name.

- [ ] **Step 2: Commit**

```bash
git add resources/lore_text.json
git commit -m "data: lore_text.json for Story Teller voice lines"
```

---

## Task 3 — TravelLog resource

**Files:**
- Create: `scripts/data/travel_log.gd`
- Create: `tests/unit/test_travel_log.gd`

- [ ] **Step 1: Write failing test**

```gdscript
# tests/unit/test_travel_log.gd
extends GutTest

var _log: TravelLog = null

func before_each() -> void:
    _log = TravelLog.new()

func test_starts_empty() -> void:
    assert_true(_log.current_run.is_empty(), "current_run should start empty")
    assert_true(_log.last_run.is_empty(), "last_run should start empty")

func test_start_run_moves_current_to_last() -> void:
    _log.start_run(&"dungeon", "0_0")
    _log.record_kill()
    _log.record_kill()
    _log.start_run(&"labyrinth", "1_2")
    assert_eq(_log.last_run.get("enemies_killed", 0), 2,
            "last_run should snapshot the previous run kills")
    assert_eq(_log.current_run.get("enemies_killed", 0), 0,
            "current_run should reset after start_run")

func test_record_kill() -> void:
    _log.start_run(&"dungeon", "0_0")
    _log.record_kill()
    _log.record_kill()
    _log.record_kill()
    assert_eq(_log.current_run.get("enemies_killed", 0), 3)

func test_record_floor() -> void:
    _log.start_run(&"dungeon", "0_0")
    _log.record_floor()
    _log.record_floor()
    assert_eq(_log.current_run.get("floors_descended", 0), 2)

func test_record_loot() -> void:
    _log.start_run(&"dungeon", "0_0")
    _log.record_loot(5)
    _log.record_loot(2)
    assert_eq(_log.current_run.get("items_looted", 0), 7)

func test_record_chest() -> void:
    _log.start_run(&"dungeon", "0_0")
    _log.record_chest()
    assert_eq(_log.current_run.get("chests_opened", 0), 1)

func test_to_dict_from_dict_round_trip() -> void:
    _log.start_run(&"dungeon", "0_0")
    _log.record_kill()
    _log.record_loot(3)
    var d: Dictionary = _log.to_dict()
    var log2 := TravelLog.new()
    log2.from_dict(d)
    assert_eq(log2.current_run.get("enemies_killed", 0), 1)
    assert_eq(log2.current_run.get("items_looted", 0), 3)

func test_no_op_before_start_run() -> void:
    # Calling record methods before start_run should not crash.
    _log.record_kill()
    _log.record_floor()
    _log.record_loot(1)
    _log.record_chest()
    assert_true(true, "No crash before start_run")
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_travel_log.gd -gexit 2>&1 | tail -10
```

- [ ] **Step 3: Create `scripts/data/travel_log.gd`**

```gdscript
## TravelLog
##
## Tracks a single player's dungeon run statistics.
## `current_run` accumulates during the active run.
## `start_run()` snapshots `current_run` → `last_run` and resets.
## Called by world.gd on dungeon entry and overworld re-entry.
class_name TravelLog
extends Resource

## Active run counters. Empty dict = no run started yet.
@export var current_run: Dictionary = {}
## Snapshot of the most recently completed run.
@export var last_run: Dictionary = {}

## Begin a new run. Snapshots current_run → last_run, then resets.
## [param kind]: &"dungeon" or &"labyrinth".
## [param region_str]: region_id serialized as "x_y" string.
func start_run(kind: StringName, region_str: String) -> void:
    if not current_run.is_empty():
        last_run = current_run.duplicate()
    current_run = {
        "dungeon_kind": String(kind),
        "region_id": region_str,
        "enemies_killed": 0,
        "floors_descended": 0,
        "items_looted": 0,
        "chests_opened": 0,
    }

func record_kill() -> void:
    if current_run.is_empty():
        return
    current_run["enemies_killed"] = current_run.get("enemies_killed", 0) + 1

func record_floor() -> void:
    if current_run.is_empty():
        return
    current_run["floors_descended"] = current_run.get("floors_descended", 0) + 1

func record_loot(count: int) -> void:
    if current_run.is_empty():
        return
    current_run["items_looted"] = current_run.get("items_looted", 0) + count

func record_chest() -> void:
    if current_run.is_empty():
        return
    current_run["chests_opened"] = current_run.get("chests_opened", 0) + 1

func to_dict() -> Dictionary:
    return {
        "current_run": current_run.duplicate(),
        "last_run": last_run.duplicate(),
    }

func from_dict(d: Dictionary) -> void:
    current_run = d.get("current_run", {}).duplicate()
    last_run = d.get("last_run", {}).duplicate()
```

- [ ] **Step 4: Refresh class cache**

```bash
cd /home/mpatterson/repos/game4 && timeout 15 godot --headless --editor --quit 2>/dev/null; true
```

- [ ] **Step 5: Run test — expect all 8 PASS**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_travel_log.gd -gexit 2>&1 | tail -10
```

- [ ] **Step 6: Commit**

```bash
git add scripts/data/travel_log.gd tests/unit/test_travel_log.gd
git commit -m "data: TravelLog resource for dungeon run tracking"
```

---

## Task 4 — GameState.keys_with_prefix()

**Files:**
- Modify: `scripts/autoload/game_state.gd`
- Create: `tests/unit/test_game_state_prefix.gd`

- [ ] **Step 1: Write failing test**

```gdscript
# tests/unit/test_game_state_prefix.gd
extends GutTest

func before_each() -> void:
    GameState.clear_flags()

func test_keys_with_prefix_returns_matching_keys() -> void:
    GameState.set_flag("met_mara")
    GameState.set_flag("met_the_guard")
    GameState.set_flag("quest_herbalist_started")
    var keys := GameState.keys_with_prefix("met_")
    assert_eq(keys.size(), 2, "Should return only met_ keys")
    assert_true("met_mara" in keys)
    assert_true("met_the_guard" in keys)

func test_keys_with_prefix_empty_when_none_match() -> void:
    GameState.set_flag("quest_herbalist_started")
    var keys := GameState.keys_with_prefix("lore_")
    assert_eq(keys.size(), 0)

func test_keys_with_prefix_only_true_flags() -> void:
    GameState.set_flag("met_guard", true)
    GameState.set_flag("met_bandit", false)
    var keys := GameState.keys_with_prefix("met_")
    assert_true("met_guard" in keys)
    assert_false("met_bandit" in keys,
            "False flags should not appear in prefix list")
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_game_state_prefix.gd -gexit 2>&1 | tail -10
```

- [ ] **Step 3: Add method to `scripts/autoload/game_state.gd`**

Read the file first to find the correct insertion point (after `from_dict()`). Add:

```gdscript
## Returns the keys of all true flags that start with [param prefix].
## Useful for enumerating "met_*" NPC flags or "lore_*" tidbit flags.
func keys_with_prefix(prefix: String) -> Array[String]:
    var result: Array[String] = []
    for key in _flags.keys():
        if key.begins_with(prefix) and _flags[key]:
            result.append(key)
    return result
```

- [ ] **Step 4: Run test — expect all 3 PASS**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_game_state_prefix.gd -gexit 2>&1 | tail -10
```

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/game_state.gd tests/unit/test_game_state_prefix.gd
git commit -m "autoload: GameState.keys_with_prefix() for Story Teller flag enumeration"
```

---

## Task 5 — Update CaravanData + CaravanSaveData

**Files:**
- Modify: `scripts/data/caravan_data.gd`
- Modify: `scripts/data/caravan_save_data.gd`

- [ ] **Step 1: Read `scripts/data/caravan_data.gd` in full**

Understand the current `_init()`, `to_dict()`, `from_dict()` before editing.

- [ ] **Step 2: Add fields and methods to `caravan_data.gd`**

Add after the existing `@export var inventory: Inventory` line:

```gdscript
## Per-player dungeon run tracker. Length 2 (index = player_id).
@export var travel_logs: Array[TravelLog] = []
## Rolled-once names for each party member. StringName → String.
@export var member_names: Dictionary = {}
```

In `_init()`, after `inventory = Inventory.new()`, add:

```gdscript
travel_logs.clear()
travel_logs.append(TravelLog.new())
travel_logs.append(TravelLog.new())
```

Add a new helper method after `has_member()`:

```gdscript
## Returns the rolled name for [param member_id], or the
## member's display_name from [PartyMemberDef] if not yet assigned.
func get_member_name(member_id: StringName) -> String:
    if member_names.has(member_id):
        return member_names[member_id]
    var def: PartyMemberDef = PartyMemberRegistry.get_member(member_id)
    return def.display_name if def != null else String(member_id)
```

In `to_dict()`, add to the returned dictionary:

```gdscript
"travel_logs": [travel_logs[0].to_dict(), travel_logs[1].to_dict()],
"member_names": member_names.duplicate(),
```

In `from_dict(d)`, add after restoring inventory:

```gdscript
var tl_data: Array = d.get("travel_logs", [{}, {}])
for i in 2:
    if i < travel_logs.size() and i < tl_data.size():
        travel_logs[i].from_dict(tl_data[i])
member_names = d.get("member_names", {}).duplicate()
```

- [ ] **Step 3: Update `caravan_save_data.gd`**

Add two new `@export` fields:

```gdscript
## Serialized TravelLog data (array of 2 dicts, index = player_id).
@export var travel_log_data: Array[Dictionary] = []
## Rolled member names (StringName string keys → name strings).
@export var member_names: Dictionary = {}
```

- [ ] **Step 4: Run full unit tests — expect no new failures**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] **Step 5: Commit**

```bash
git add scripts/data/caravan_data.gd scripts/data/caravan_save_data.gd
git commit -m "data: add TravelLog and member_names to CaravanData"
```

---

## Task 6 — Fix QuestTracker save gap + SaveGame VERSION 4

**Files:**
- Modify: `scripts/data/save_game.gd`
- Create: `tests/unit/test_story_teller_save.gd`
- Modify: `tests/integration/test_phase9a_save_interiors.gd` (update VERSION assertion)

- [ ] **Step 1: Write failing test**

```gdscript
# tests/unit/test_story_teller_save.gd
extends GutTest

func before_each() -> void:
    QuestTracker.reset()
    GameState.clear_flags()

func test_version_is_4() -> void:
    assert_eq(SaveGame.VERSION, 4)

func test_quest_tracker_data_saved_and_restored() -> void:
    QuestTracker.start_quest("herbalist_remedy", "herbs")
    QuestTracker.advance_objective("herbalist_remedy", "gather_herbs", 2)
    var save := SaveGame.new()
    # Snapshot calls QuestTracker.to_dict() — no world needed for unit test.
    save.quest_tracker_data = QuestTracker.to_dict()
    # Restore into a fresh state.
    QuestTracker.reset()
    assert_false(QuestTracker.is_quest_active("herbalist_remedy"),
            "After reset, quest should not be active")
    QuestTracker.from_dict(save.quest_tracker_data)
    assert_true(QuestTracker.is_quest_active("herbalist_remedy"),
            "After restore, quest should be active")
    assert_eq(QuestTracker.get_objective_progress("herbalist_remedy", "gather_herbs"), 2,
            "Objective progress should survive save/load")

func test_travel_log_data_in_caravan_save_data() -> void:
    var csd := CaravanSaveData.new()
    csd.travel_log_data = [{"current_run": {"enemies_killed": 5}}, {}]
    assert_eq(csd.travel_log_data[0].get("current_run", {}).get("enemies_killed", 0), 5)
```

- [ ] **Step 2: Run test — expect FAIL on version assertion**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_story_teller_save.gd -gexit 2>&1 | tail -15
```

- [ ] **Step 3: Modify `scripts/data/save_game.gd`**

Read the file first. Make these changes:

**a)** Change `const VERSION: int = 3` → `const VERSION: int = 4`

**b)** Add export field after `caravans`:

```gdscript
## Serialized QuestTracker state (branch + objective progress per active quest).
@export var quest_tracker_data: Dictionary = {}
```

**c)** In `snapshot()`, after `save.game_state_flags = GameState.to_dict()`, add:

```gdscript
save.quest_tracker_data = QuestTracker.to_dict()
```

Also update the caravan snapshot loop to include travel logs and member names. Find the loop that builds `CaravanSaveData` and add:

```gdscript
csd.travel_log_data = [
    caravan_data.travel_logs[0].to_dict() if caravan_data.travel_logs.size() > 0 else {},
    caravan_data.travel_logs[1].to_dict() if caravan_data.travel_logs.size() > 1 else {},
]
csd.member_names = caravan_data.member_names.duplicate()
```

**d)** In `apply()`, after `GameState.from_dict(game_state_flags)`, add:

```gdscript
if not quest_tracker_data.is_empty():
    QuestTracker.from_dict(quest_tracker_data)
```

Also update the caravan restore loop to restore travel logs and member names. Find the loop that iterates `caravans` and after restoring `recruited_ids` + `inventory`, add:

```gdscript
if not csd.travel_log_data.is_empty() and caravan_data.travel_logs.size() >= 2:
    caravan_data.travel_logs[0].from_dict(csd.travel_log_data[0] if csd.travel_log_data.size() > 0 else {})
    caravan_data.travel_logs[1].from_dict(csd.travel_log_data[1] if csd.travel_log_data.size() > 1 else {})
caravan_data.member_names = csd.member_names.duplicate()
```

**e)** In the version migration block (where `if version < 3:` lives), add:

```gdscript
if version < 4:
    quest_tracker_data = {}
```

- [ ] **Step 4: Update `tests/integration/test_phase9a_save_interiors.gd`**

Find `assert_eq(SaveGame.VERSION, 3)` and change `3` → `4`.

- [ ] **Step 5: Run test — expect all 3 PASS**

```bash
cd /home/mpatterson/repos/game4 && timeout 15 godot --headless --editor --quit 2>/dev/null; true
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_story_teller_save.gd -gexit 2>&1 | tail -10
```

- [ ] **Step 6: Run all unit tests — expect no new failures**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] **Step 7: Commit**

```bash
git add scripts/data/save_game.gd tests/unit/test_story_teller_save.gd tests/integration/test_phase9a_save_interiors.gd
git commit -m "save: VERSION 4 — quest tracker + travel log + member names in SaveGame"
```

---

## Task 7 — story_teller in party_members.json + world.gd wiring

**Files:**
- Modify: `resources/party_members.json`
- Modify: `scripts/world/world.gd`

- [ ] **Step 1: Add `story_teller` to `resources/party_members.json`**

Read the file first. Add a 5th entry following the same JSON structure as the others:

```json
"story_teller": {
    "id": "story_teller",
    "display_name": "Story Teller",
    "crafter_domain": "",
    "portrait_cell": [0, 0],
    "can_follow": false
}
```

- [ ] **Step 2: Modify `scripts/world/world.gd` — auto-recruit + roll names**

Read `_ready()` in world.gd. Find the section that initializes `_caravan_datas` (the loop doing `_caravan_datas.append(CaravanData.new())`). After each `CaravanData` is created, add the story_teller auto-recruit and name rolling.

Replace the existing caravan data init block (which currently just appends a new `CaravanData`) with this expanded version:

```gdscript
# Existing: _caravan_datas.append(CaravanData.new())
# Replace with:
for pid_inner in range(2):
    var cd := CaravanData.new()
    cd.add_member(&"story_teller")
    # Roll names for all known party members using the world seed + pid.
    var name_rng := RandomNumberGenerator.new()
    name_rng.seed = (WorldManager.get_seed() if WorldManager.has_method("get_seed") \
            else 1337) + pid_inner * 1000
    for member_id in PartyMemberRegistry.all_ids():
        cd.member_names[member_id] = NamesRegistry.roll_name(member_id, name_rng)
    _caravan_datas.append(cd)
```

**NOTE:** Read `scripts/autoload/world_manager.gd` to confirm the exact method name for getting the current seed (it may be `WorldManager.seed` property or `WorldManager.get_seed()` or similar). Use the correct accessor.

- [ ] **Step 3: Run full unit + integration tests — expect no new failures**

```bash
cd /home/mpatterson/repos/game4 && timeout 15 godot --headless --editor --quit 2>/dev/null; true
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] **Step 4: Commit**

```bash
git add resources/party_members.json scripts/world/world.gd
git commit -m "world: auto-recruit story_teller and roll member names at game start"
```

---

## Task 8 — TravelLog data capture hooks

**Files:**
- Modify: `scripts/entities/player_controller.gd`
- Modify: `scripts/entities/loot_pickup.gd`
- Modify: `scripts/entities/treasure_chest.gd`
- Modify: `scripts/world/world.gd`

Each hook is a one-liner guard: check `caravan_data != null`, call the relevant `TravelLog` method.

- [ ] **Step 1: Kill hook in `player_controller.gd`**

Read `try_attack()` (around line 663). After `hit_entity.call("take_hit", power, self, elem)`, add:

```gdscript
# TravelLog kill tracking.
var entity_health: Variant = hit_entity.get("health")
if entity_health != null and int(entity_health) <= 0 and caravan_data != null \
        and caravan_data.travel_logs.size() > player_id:
    caravan_data.travel_logs[player_id].record_kill()
```

Repeat the same pattern after the `best.call("take_hit", power, self, elem)` in `_auto_attack_melee()` (around line 558) and after `n.call("take_hit", power, self, elem)` in `_auto_attack_ranged()` (around line 591). Each uses `best` or `n` as the entity reference respectively.

- [ ] **Step 2: Loot pickup hook in `loot_pickup.gd`**

Read the `_process()` method — find where `_consumed = true` is set after inventory.add(). After `p.inventory.add(item_id, count)`, add:

```gdscript
if p.caravan_data != null and p.caravan_data.travel_logs.size() > p.player_id:
    p.caravan_data.travel_logs[p.player_id].record_loot(count)
```

- [ ] **Step 3: Chest open hook in `treasure_chest.gd`**

Read `open(player: Node)`. Find where loot pickups are spawned. Add at the start of the loot loop (before or after spawning pickups, but once per chest open):

```gdscript
if player is PlayerController:
    var pc := player as PlayerController
    if pc.caravan_data != null and pc.caravan_data.travel_logs.size() > pc.player_id:
        pc.caravan_data.travel_logs[pc.player_id].record_chest()
```

Place this **once** per `open()` call, not per item drop (one chest = one `record_chest()` call).

- [ ] **Step 4: Dungeon entry + floor descent + overworld snapshot in `world.gd`**

Read `_enter_view()`. The current view tracking for the player is in `_player_instance_key[pid]`. We need to know the *previous* view_kind to detect transitions.

Add a `_player_view_kind: Array` initialized to `[&"", &""]` alongside `_player_instance_key` in `_ready()`. At the end of `_enter_view()`, before updating the key, store:

```gdscript
var prev_view_kind: StringName = _player_view_kind[pid] if pid < _player_view_kind.size() else &""
```

Then at the bottom of `_enter_view()`, after all the placement logic:

```gdscript
# TravelLog: track dungeon entry, floor descent, and overworld return.
var cd: CaravanData = _caravan_datas[pid] if pid < _caravan_datas.size() else null
if cd != null and cd.travel_logs.size() > pid:
    var tlog: TravelLog = cd.travel_logs[pid]
    var is_dungeon: bool = (view_kind == &"dungeon" or view_kind == &"labyrinth")
    var was_dungeon: bool = (prev_view_kind == &"dungeon" or prev_view_kind == &"labyrinth")
    if is_dungeon and not was_dungeon:
        # Fresh dungeon entry — start a new run.
        var rid: String = "%d_%d" % [region.region_id.x, region.region_id.y] \
                if region != null else "0_0"
        tlog.start_run(view_kind, rid)
    elif is_dungeon and was_dungeon:
        # Floor-to-floor descent within the dungeon.
        tlog.record_floor()
    elif view_kind == &"overworld" and was_dungeon:
        # Returned to overworld — snapshot current run without starting new.
        if not tlog.current_run.is_empty():
            tlog.last_run = tlog.current_run.duplicate()

# Update tracked view kind.
if pid < _player_view_kind.size():
    _player_view_kind[pid] = view_kind
```

Add `_player_view_kind.append(&"")` in the existing per-player init loop in `_ready()`.

- [ ] **Step 5: Run full unit tests — expect no new failures**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] **Step 6: Commit**

```bash
git add scripts/entities/player_controller.gd scripts/entities/loot_pickup.gd \
        scripts/entities/treasure_chest.gd scripts/world/world.gd
git commit -m "gameplay: TravelLog data capture hooks (kills, loot, chests, floors)"
```

---

## Task 9 — StoryTellerPanel UI

**Files:**
- Create: `scripts/ui/story_teller_panel.gd`
- Modify: `scripts/ui/caravan_menu.gd`

- [ ] **Step 1: Read `scripts/ui/caravan_menu.gd`**

Find `_on_member_selected()` — this is where we swap the right panel content. The warrior currently shows a plain label. We replace that fallback with the StoryTellerPanel.

- [ ] **Step 2: Create `scripts/ui/story_teller_panel.gd`**

```gdscript
## StoryTellerPanel
##
## Three-tab recap panel shown in the CaravanMenu when the player
## selects their Story Teller. Views:
##   Quests          — active objectives and completed quest list.
##   Voices Overheard — NPCs met and lore tidbits from GameState flags.
##   Last Adventure  — stats from the player's most recent dungeon run.
extends Control
class_name StoryTellerPanel

const _LORE_TEXT_PATH: String = "res://resources/lore_text.json"

var _player: PlayerController = null
var _caravan_data: CaravanData = null
var _teller_name: String = "The Story Teller"
var _content: VBoxContainer = null
var _lore_text: Dictionary = {}

enum View { QUESTS, VOICES, ADVENTURE }
var _current_view: View = View.QUESTS


func setup(player: PlayerController, caravan_data: CaravanData) -> void:
    _player = player
    _caravan_data = caravan_data
    if caravan_data != null:
        _teller_name = caravan_data.get_member_name(&"story_teller")
    _load_lore_text()
    _build_ui()
    _show_view(View.QUESTS)


func _load_lore_text() -> void:
    var f := FileAccess.open(_LORE_TEXT_PATH, FileAccess.READ)
    if f == null:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()
    if parsed is Dictionary:
        _lore_text = parsed


func _build_ui() -> void:
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL

    var vbox := VBoxContainer.new()
    vbox.anchor_right = 1.0
    vbox.anchor_bottom = 1.0
    vbox.add_theme_constant_override("separation", 6)
    add_child(vbox)

    # Tab row.
    var tab_row := HBoxContainer.new()
    tab_row.add_theme_constant_override("separation", 4)
    vbox.add_child(tab_row)

    var tab_labels: Array = ["Quests", "Voices Overheard", "Last Adventure"]
    var tab_views: Array = [View.QUESTS, View.VOICES, View.ADVENTURE]
    for i in 3:
        var btn := Button.new()
        btn.text = tab_labels[i]
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.pressed.connect(_show_view.bind(tab_views[i]))
        tab_row.add_child(btn)

    vbox.add_child(HSeparator.new())

    # Scrollable content area.
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(scroll)

    _content = VBoxContainer.new()
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 6)
    scroll.add_child(_content)


func _show_view(view: View) -> void:
    _current_view = view
    for child in _content.get_children():
        child.queue_free()
    match view:
        View.QUESTS:
            _build_quests_view()
        View.VOICES:
            _build_voices_view()
        View.ADVENTURE:
            _build_adventure_view()


func _build_quests_view() -> void:
    var active_ids: Array = []
    var complete_ids: Array = []
    for qid in QuestRegistry.all_ids():
        if QuestTracker.is_quest_complete(qid):
            complete_ids.append(qid)
        elif QuestTracker.is_quest_active(qid):
            active_ids.append(qid)

    if active_ids.is_empty() and complete_ids.is_empty():
        _add_flavor_line("*%s taps her quill. 'No tales yet to tell — but the road lies ahead.'*"
                % _teller_name)
        return

    for qid in active_ids:
        _add_quest_entry(qid, false)
    if not complete_ids.is_empty():
        _add_label("─── Completed ───", true)
        for qid in complete_ids:
            _add_quest_entry(qid, true)


func _add_quest_entry(quest_id: String, completed: bool) -> void:
    var quest: Dictionary = QuestRegistry.get_quest(quest_id)
    if quest.is_empty():
        return
    var header := Label.new()
    header.text = quest.get("display_name", quest_id)
    header.modulate = Color(0.7, 0.7, 0.7) if completed else Color(1, 1, 1)
    _content.add_child(header)

    if not completed:
        var branch_id: String = QuestTracker.get_active_branch(quest_id)
        var branch: Dictionary = QuestRegistry.get_branch(quest_id, branch_id)
        for obj in branch.get("objectives", []):
            var obj_id: String = obj.get("id", "")
            var progress: int = QuestTracker.get_objective_progress(quest_id, obj_id)
            var target: int = obj.get("count", 1)
            var done: bool = progress >= target
            var line := Label.new()
            var check: String = "✓ " if done else "• "
            line.text = "  %s%s (%d/%d)" % [check, obj.get("description", obj_id),
                    progress, target]
            line.modulate = Color(0.5, 0.9, 0.5) if done else Color(0.85, 0.85, 0.85)
            _content.add_child(line)
    _content.add_child(HSeparator.new())


func _build_voices_view() -> void:
    var met_keys := GameState.keys_with_prefix("met_")
    var lore_keys := GameState.keys_with_prefix("lore_")

    if met_keys.is_empty() and lore_keys.is_empty():
        _add_flavor_line("*%s flips through blank pages. 'We've kept to ourselves so far.'*"
                % _teller_name)
        return

    if not met_keys.is_empty():
        _add_label("People Met", true)
        for key in met_keys:
            var display: String = key.trim_prefix("met_").replace("_", " ").capitalize()
            _add_label("  • " + display)

    if not lore_keys.is_empty():
        _add_label("Things Overheard", true)
        for key in lore_keys:
            var text: String = _lore_text.get(key, key.trim_prefix("lore_").replace("_", " ").capitalize())
            _add_label("  " + text)


func _build_adventure_view() -> void:
    var pid: int = _player.player_id if _player != null else 0
    var tlog: TravelLog = null
    if _caravan_data != null and _caravan_data.travel_logs.size() > pid:
        tlog = _caravan_data.travel_logs[pid]

    if tlog == null or tlog.last_run.is_empty():
        _add_flavor_line("*%s looks up expectantly. 'Tell me about your first dungeon — I'll take notes.'*"
                % _teller_name)
        return

    var run: Dictionary = tlog.last_run
    var kind: String = run.get("dungeon_kind", "dungeon")
    var region_str: String = run.get("region_id", "unknown region")
    var enemies: int = run.get("enemies_killed", 0)
    var floors: int = run.get("floors_descended", 0)
    var items: int = run.get("items_looted", 0)
    var chests: int = run.get("chests_opened", 0)

    var summary: String = (
        "*%s leans forward and reads aloud:*\n\n" % _teller_name +
        "'You descended %d floor%s into a %s near region %s, " % [
                floors, "s" if floors != 1 else "", kind, region_str] +
        "slaying %d %s, looting %d item%s from %d chest%s.'" % [
                enemies, "enemies" if enemies != 1 else "enemy",
                items, "s" if items != 1 else "",
                chests, "s" if chests != 1 else ""]
    )
    _add_flavor_line(summary)


# ─── Helpers ────────────────────────────────────────────────────────

func _add_label(text: String, bold: bool = false) -> void:
    var lbl := Label.new()
    lbl.text = text
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    if bold:
        lbl.modulate = Color(1.0, 0.85, 0.4)
    _content.add_child(lbl)


func _add_flavor_line(text: String) -> void:
    var lbl := RichTextLabel.new()
    lbl.bbcode_enabled = true
    lbl.fit_content = true
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    lbl.text = text
    _content.add_child(lbl)
```

- [ ] **Step 3: Wire into `caravan_menu.gd`**

Read `_on_member_selected()`. Find the `else:` branch (currently shows the warrior label). Change it so story_teller gets `StoryTellerPanel` and warrior keeps its label:

```gdscript
func _on_member_selected(member_id: StringName) -> void:
    for child in _right_panel.get_children():
        child.queue_free()
    _current_crafter = null

    var def: PartyMemberDef = PartyMemberRegistry.get_member(member_id)
    if def == null:
        return

    if def.crafter_domain != &"":
        _current_crafter = CrafterPanel.new()
        _current_crafter.name = "ActiveCrafter"
        _current_crafter.anchor_right = 1.0
        _current_crafter.anchor_bottom = 1.0
        _right_panel.add_child(_current_crafter)
        _current_crafter.set_crafter(def.crafter_domain, _caravan_data)
    elif member_id == &"story_teller":
        var panel := StoryTellerPanel.new()
        panel.name = "StoryTellerPanel"
        panel.anchor_right = 1.0
        panel.anchor_bottom = 1.0
        _right_panel.add_child(panel)
        panel.setup(_player, _caravan_data)
    else:
        var label := Label.new()
        var teller_name: String = _caravan_data.get_member_name(member_id) \
                if _caravan_data != null else String(member_id)
        label.text = "%s\nHP: Active companion" % teller_name
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.anchor_right = 1.0
        label.anchor_bottom = 1.0
        _right_panel.add_child(label)
```

- [ ] **Step 4: Refresh class cache**

```bash
cd /home/mpatterson/repos/game4 && timeout 15 godot --headless --editor --quit 2>/dev/null; true
```

- [ ] **Step 5: Run all unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/story_teller_panel.gd scripts/ui/caravan_menu.gd
git commit -m "ui: StoryTellerPanel with Quests, Voices Overheard, and Last Adventure views"
```

---

## Task 10 — Integration test + final smoke

**Files:**
- Create: `tests/integration/test_story_teller_menu.gd`

- [ ] **Step 1: Create integration test**

```gdscript
# tests/integration/test_story_teller_menu.gd
extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")
var _game: Game = null

func before_each() -> void:
    WorldManager.reset(202402)
    _game = _GameScene.instantiate()
    add_child_autofree(_game)
    await get_tree().process_frame
    await get_tree().process_frame

func after_each() -> void:
    _game = null

func test_story_teller_recruited_at_start() -> void:
    var world := World.instance()
    if world == null:
        pending("World not available")
        return
    var cd := world.get_caravan_data(0)
    assert_not_null(cd, "CaravanData should exist")
    assert_true(cd.has_member(&"story_teller"),
            "Story teller should be auto-recruited at game start")

func test_story_teller_has_name_assigned() -> void:
    var world := World.instance()
    if world == null:
        pending("World not available")
        return
    var cd := world.get_caravan_data(0)
    if cd == null:
        pending("CaravanData not available")
        return
    var name: String = cd.get_member_name(&"story_teller")
    assert_true(name.length() > 0, "Story teller should have a non-empty name")
    assert_ne(name, "story_teller", "Name should be from pool, not fall back to id")

func test_both_players_get_story_teller() -> void:
    var world := World.instance()
    if world == null:
        pending("World not available")
        return
    for pid in [0, 1]:
        var cd := world.get_caravan_data(pid)
        assert_not_null(cd)
        assert_true(cd.has_member(&"story_teller"),
                "P%d should have story_teller recruited" % (pid + 1))

func test_travel_logs_initialized_per_player() -> void:
    var world := World.instance()
    if world == null:
        pending("World not available")
        return
    for pid in [0, 1]:
        var cd := world.get_caravan_data(pid)
        if cd == null:
            pending("CaravanData not available for P%d" % (pid + 1))
            return
        assert_eq(cd.travel_logs.size(), 2, "Should have 2 TravelLog slots")
        assert_not_null(cd.travel_logs[pid], "TravelLog for P%d should not be null" % (pid + 1))
```

- [ ] **Step 2: Run integration tests**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] **Step 3: Run all tests (unit + integration)**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit 2>&1 | grep -E "Passing|Failing"
```

Expected: unit ≥643 passing / 1 pre-existing failure; integration ≥106 passing / 5 pre-existing failures.

- [ ] **Step 4: Commit**

```bash
git add tests/integration/test_story_teller_menu.gd
git commit -m "tests: Story Teller integration tests"
```

---

## Self-Review Checklist

- [x] **names.json** → Task 1
- [x] **lore_text.json** → Task 2
- [x] **NamesRegistry.roll_name()** → Task 1; used in Task 7
- [x] **TravelLog** (start_run, record_*, to/from_dict) → Task 3; hooked in Task 8
- [x] **CaravanData.travel_logs[] + member_names + get_member_name()** → Task 5; used in Tasks 7, 8, 9
- [x] **CaravanSaveData.travel_log_data + member_names** → Task 5; serialized in Task 6
- [x] **QuestTracker save gap fixed** → Task 6
- [x] **SaveGame VERSION 4** → Task 6; integration test updated
- [x] **GameState.keys_with_prefix()** → Task 4; used in Task 9
- [x] **story_teller in party_members.json** → Task 7
- [x] **Auto-recruit + name roll in world._ready()** → Task 7
- [x] **Kill hooks** (try_attack + auto melee + auto ranged) → Task 8
- [x] **Loot pickup hook** → Task 8
- [x] **Chest open hook** → Task 8
- [x] **Dungeon entry / floor / overworld snapshot in _enter_view** → Task 8
- [x] **_player_view_kind tracking array** → Task 8
- [x] **StoryTellerPanel (3 views)** → Task 9
- [x] **caravan_menu wired for story_teller** → Task 9
- [x] **Integration test** → Task 10
- [x] **VERSION assertion in test_phase9a_save_interiors** → Task 6
