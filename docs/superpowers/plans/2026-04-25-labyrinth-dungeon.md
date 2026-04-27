# Labyrinth Dungeon System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `&"labyrinth"` interior type — Gauntlet-style Prim's-maze dungeons with 2-4 tile wide corridors, interactive treasure chests at dead ends, depth-scaled enemies, and boss rooms every 5 floors — all configurable from the Game Editor.

**Architecture:** `LabyrinthGenerator` (new, mirrors `DungeonGenerator`) produces `InteriorMap`s with `chest_scatter` and `boss_data` fields. `MapManager` routes `kind == &"labyrinth"` to the new generator. `WorldRoot` paints labyrinth floors via the existing dungeon autotile system and handles `TreasureChest` interact input. Two new JSON registries (`encounter_tables.json`, `chest_loot.json`) plus two new standalone `GameEditor` panels manage all depth-scaling and loot data.

**Tech Stack:** Godot 4.3 stable, GDScript. All JSON registries follow the `static _ensure_loaded() / reset() / save_data()` pattern established by `DungeonGenerator`, `EncounterRegistry`, and `CreatureSpriteRegistry`.

---

## Pre-flight: Branch Setup

- [ ] **Create feature branch**

```bash
cd /home/mpatterson/repos/game4
git checkout -b feature/labyrinth-dungeon
```

---

## Task 0: Dungeon-Type Skill (write before touching code)

**Files:**
- Create: `docs/skills/game4-dungeon-type.md`

- [ ] **Write the skill**

Create `docs/skills/game4-dungeon-type.md` with this exact content:

```markdown
# Adding a New Dungeon Type to game4

Use when adding a new `InteriorMap`-based dungeon/interior type to this project.

## Checklist: Every New Dungeon Type Touches These Systems

### 1. Generator (`scripts/world/<name>_generator.gd`)
- `class_name <Name>Generator`, extends `RefCounted`
- `static func generate(seed_val: int, width: int, height: int, floor_num: int) -> InteriorMap`
- Fill `InteriorMap.tiles` with `TerrainCodes.INTERIOR_WALL`, carve floor cells
- Set `m.entry_cell`, `m.exit_cell` with `TerrainCodes.INTERIOR_STAIRS_UP/DOWN`
- Populate `m.npcs_scatter`, `m.loot_scatter`, and any new scatter arrays
- Use `EncounterTableRegistry.get_weighted_list("your_kind", floor_num)` for enemies
- `MAX_SIZE` on `InteriorMap` constrains width/height

### 2. MapManager (`scripts/autoload/map_manager.gd`)
- `make_id(rid, cell, floor, kind)` — pass your kind StringName, e.g. `&"labyrinth"`
- `get_or_generate(map_id, rid, cell, floor, size, kind)` — add your kind to the `match kind:` block
- `descend_from(current)` — already extracts kind from map_id prefix via `_kind_from_id()`; no change needed
- Floor ID format: `"<kind>@rx:ry:cx:cy:floor"`

### 3. ViewManager (`scripts/autoload/view_manager.gd`)
- `enter_interior(pid, interior, view_kind)` — no change needed; accepts any StringName
- `get_view_kind(pid)` — returns whatever you passed; no registration required

### 4. WorldRoot (`scripts/world/world_root.gd`)
- `_attach_interior_tilesets(view_kind)`: add a match case for your kind → correct TileSet
- `_paint_interior(interior, view_kind)`: add a match case or fall-through to existing painter
- `_build_door_index(view_kind)`:
  - Overworld branch: add `elif ek == &"your_kind": _doors[c] = {"kind": &"your_kind_enter", "cell": c}`
  - Interior branch: add `or view_kind == &"your_kind"` to the stairs condition
- `_handle_door(player, door, cell)`:
  - Add `&"your_kind_enter"` case — call `MapManager.get_or_generate(mid, rid, cell, 1, size, &"your_kind")`, then `World.instance().transition_player(pid, &"your_kind", region, interior)`
  - `stairs_up` parent transition: uses `_view_kind_from_interior(parent)` — no change needed
- `debug_spawn_interactables_for(player)`: add `_debug_place_entrance(&"your_kind", &"your_kind_enter", centre, offset, "label")`

### 5. WorldGenerator (`scripts/world/world_generator.gd`)
- Add `_place_<name>_entrances(region)` — same structure as `_place_dungeon_entrances()` but appends `{"kind": &"your_kind", "cell": cell}`
- Call it from `generate_region()` after `_place_dungeon_entrances()`
- Control frequency via rate constant (labyrinths: 0–1 per region)

### 6. TileMappings + TilesetCatalog
- Add `@export var <name>_entrance_pair: Array[Vector2i] = []` to `TileMappings`
- Add `&"<name>_entrance_pair": "res://assets/tiles/roguelike/<sheet>.png"` to `TilesetCatalog._DEFAULT_SHEETS`
- Add `static var <NAME>_OVERWORLD_ENTRANCE_CELLS: Array = _DEFAULT_<NAME>_ENTRANCE` to TilesetCatalog
- Load it in `_ensure_loaded()` from `TileMappings`
- Update `_paint_overworld_entrance_markers()` to use the correct cells for your kind
- Add entry to `game_editor.gd` `_MAPPINGS` array so SpritePicker can edit it

### 7. Tests
- Unit: generator connectivity, minimum dead-end count, boss room presence on boss floors
- Integration: descend 3 floors, verify `view_kind == &"your_kind"` and floor IDs increment
```

- [ ] **Commit the skill**

```bash
git add docs/skills/game4-dungeon-type.md
git commit -m "docs: add game4-dungeon-type skill"
```

---

## Task 1: Data Files

**Files:**
- Create: `resources/encounter_tables.json`
- Create: `resources/chest_loot.json`

- [ ] **Create encounter_tables.json**

Create `resources/encounter_tables.json`:

```json
{
	"labyrinth": {
		"boss_interval": 5,
		"enemy_tables": [
			{"creature": "goblin",       "min_floor": 1,  "max_floor": 4,  "weight": 10},
			{"creature": "bat",          "min_floor": 1,  "max_floor": 8,  "weight": 8},
			{"creature": "slime",        "min_floor": 1,  "max_floor": 10, "weight": 6},
			{"creature": "skeleton",     "min_floor": 3,  "max_floor": 99, "weight": 10},
			{"creature": "goblin",       "min_floor": 5,  "max_floor": 99, "weight": 14},
			{"creature": "ogre",         "min_floor": 8,  "max_floor": 99, "weight": 8},
			{"creature": "fire_elemental","min_floor": 12, "max_floor": 99, "weight": 6},
			{"creature": "ice_elemental", "min_floor": 15, "max_floor": 99, "weight": 6}
		]
	}
}
```

- [ ] **Create chest_loot.json**

Create `resources/chest_loot.json`:

```json
{
	"tiers": [
		{
			"min_floor": 1,
			"max_floor": 5,
			"loot": [
				{"id": "wood",     "weight": 10, "min": 2, "max": 5},
				{"id": "stone",    "weight": 10, "min": 2, "max": 5},
				{"id": "iron_ore", "weight": 8,  "min": 1, "max": 2},
				{"id": "fiber",    "weight": 8,  "min": 2, "max": 4},
				{"id": "wooden_sword", "weight": 4, "min": 1, "max": 1}
			]
		},
		{
			"min_floor": 6,
			"max_floor": 15,
			"loot": [
				{"id": "iron_ore",  "weight": 10, "min": 2, "max": 4},
				{"id": "copper_ore","weight": 8,  "min": 1, "max": 3},
				{"id": "gold_ore",  "weight": 4,  "min": 1, "max": 2},
				{"id": "iron_dagger","weight": 6, "min": 1, "max": 1},
				{"id": "helmet",    "weight": 3,  "min": 1, "max": 1}
			]
		},
		{
			"min_floor": 16,
			"max_floor": 999,
			"loot": [
				{"id": "gold_ore",  "weight": 12, "min": 2, "max": 4},
				{"id": "iron_dagger","weight": 8, "min": 1, "max": 1},
				{"id": "helmet",    "weight": 6,  "min": 1, "max": 1},
				{"id": "armor",     "weight": 5,  "min": 1, "max": 1},
				{"id": "sword",     "weight": 4,  "min": 1, "max": 1}
			]
		}
	]
}
```

- [ ] **Add slime_king boss to creature_sprites.json**

Open `resources/creature_sprites.json`. Add the following entry (in alphabetical order, after "skeleton" or wherever fits):

```json
"slime_king": {
	"anchor": [12, 20],
	"footprint": [2, 2],
	"region": [0, 32, 48, 32],
	"scale": [1.6, 1.6],
	"sheet": "res://assets/tiles/roguelike/monster_animals2.png",
	"tint": [0.3, 0.9, 0.3, 1.0],
	"attack_style": "slam",
	"attack_damage": 6,
	"attack_speed": 2.0,
	"attack_range_tiles": 1.5,
	"is_boss": true,
	"boss_adds": [
		{"creature": "slime", "count": 3}
	]
}
```

> Note: The region/anchor may need adjusting after inspecting `monster_animals2.png`. Use a `slime` region as reference and scale up. The SpritePicker creature editor can refine this visually after Task 17.

- [ ] **Commit**

```bash
git add resources/encounter_tables.json resources/chest_loot.json resources/creature_sprites.json
git commit -m "data: add encounter_tables.json, chest_loot.json, slime_king boss"
```

---

## Task 2: EncounterTableRegistry

**Files:**
- Create: `scripts/data/encounter_table_registry.gd`
- Test: `tests/unit/test_encounter_table_registry.gd`

- [ ] **Write failing tests first**

Create `tests/unit/test_encounter_table_registry.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	EncounterTableRegistry.reset()


func test_loads_labyrinth_table() -> void:
	var result: Array = EncounterTableRegistry.get_weighted_list(&"labyrinth", 1)
	assert_true(result.size() > 0, "Should have entries for labyrinth floor 1")


func test_floor_range_filtering() -> void:
	# Floor 1 should include goblin (min_floor 1) but not ogre (min_floor 8)
	var result: Array = EncounterTableRegistry.get_weighted_list(&"labyrinth", 1)
	var kinds: Array = result.map(func(e): return e["creature"])
	assert_true(&"goblin" in kinds, "goblin should appear at floor 1")
	assert_false(&"ogre" in kinds, "ogre should NOT appear at floor 1")


func test_deep_floor_entries() -> void:
	var result: Array = EncounterTableRegistry.get_weighted_list(&"labyrinth", 20)
	var kinds: Array = result.map(func(e): return e["creature"])
	assert_true(&"ogre" in kinds, "ogre should appear at floor 20")
	assert_true(&"fire_elemental" in kinds, "fire_elemental should appear at floor 20")


func test_boss_interval() -> void:
	assert_eq(EncounterTableRegistry.get_boss_interval(&"labyrinth"), 5)


func test_unknown_type_returns_empty() -> void:
	var result: Array = EncounterTableRegistry.get_weighted_list(&"nonexistent", 1)
	assert_eq(result.size(), 0)


func test_weighted_pick() -> void:
	var table: Array = [
		{"creature": &"a", "weight": 1},
		{"creature": &"b", "weight": 9},
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pick: Dictionary = EncounterTableRegistry.weighted_pick(rng, table)
	assert_true(pick.has("creature"))
```

- [ ] **Run tests to confirm FAIL**

```bash
godot --headless -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_encounter_table_registry.gd -gexit 2>&1 | tail -10
```

Expected: `FAILED` (EncounterTableRegistry not defined).

- [ ] **Implement EncounterTableRegistry**

Create `scripts/data/encounter_table_registry.gd`:

```gdscript
## EncounterTableRegistry
##
## Static registry for depth-scaled enemy tables used by interior generators.
## Schema: resources/encounter_tables.json
##   {
##     "<dungeon_type>": {
##       "boss_interval": int,
##       "enemy_tables": [{creature, min_floor, max_floor, weight}, ...]
##     }
##   }
class_name EncounterTableRegistry
extends RefCounted

const _JSON_PATH: String = "res://resources/encounter_tables.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_JSON_PATH):
		push_warning("[EncounterTableRegistry] %s not found" % _JSON_PATH)
		return
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_warning("[EncounterTableRegistry] parse error: %s" % json.get_error_message())
		return
	if json.data is Dictionary:
		_data = json.data


static func reset() -> void:
	_data.clear()
	_loaded = false


## Returns the raw data dict for editing by the GameEditor panel.
static func get_raw_data() -> Dictionary:
	_ensure_loaded()
	return _data.duplicate(true)


## Persist edits from the GameEditor back to disk.
static func save_data(data: Dictionary) -> void:
	_data = data
	_loaded = true
	var f := FileAccess.open(_JSON_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[EncounterTableRegistry] cannot write %s" % _JSON_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


## Returns filtered, weighted enemy entries for `dungeon_type` at `floor_num`.
## Each entry: {creature: StringName, weight: int}
static func get_weighted_list(dungeon_type: StringName, floor_num: int) -> Array:
	_ensure_loaded()
	var type_data: Variant = _data.get(String(dungeon_type), null)
	if not (type_data is Dictionary):
		return []
	var tables: Array = type_data.get("enemy_tables", [])
	var out: Array = []
	for entry in tables:
		var mn: int = int(entry.get("min_floor", 1))
		var mx: int = int(entry.get("max_floor", 999))
		if floor_num >= mn and floor_num <= mx:
			out.append({
				"creature": StringName(entry.get("creature", "")),
				"weight": int(entry.get("weight", 1)),
			})
	return out


## Returns boss_interval for `dungeon_type` (default 5).
static func get_boss_interval(dungeon_type: StringName) -> int:
	_ensure_loaded()
	var type_data: Variant = _data.get(String(dungeon_type), null)
	if not (type_data is Dictionary):
		return 5
	return int(type_data.get("boss_interval", 5))


## Picks a random entry from a weighted table (must have "weight" key).
## Exported so tests and generators can call it directly.
static func weighted_pick(rng: RandomNumberGenerator, table: Array) -> Dictionary:
	if table.is_empty():
		return {}
	var total: int = 0
	for e in table:
		total += int(e.get("weight", 1))
	if total == 0:
		return table[0]
	var roll: int = rng.randi_range(1, total)
	var acc: int = 0
	for e in table:
		acc += int(e.get("weight", 1))
		if roll <= acc:
			return e
	return table[0]
```

- [ ] **Run tests to confirm PASS**

```bash
godot --headless -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_encounter_table_registry.gd -gexit 2>&1 | tail -10
```

Expected: all 6 tests pass.

- [ ] **Commit**

```bash
git add scripts/data/encounter_table_registry.gd tests/unit/test_encounter_table_registry.gd
git commit -m "feat: add EncounterTableRegistry with depth-scaled enemy tables"
```

---

## Task 3: ChestLootRegistry

**Files:**
- Create: `scripts/data/chest_loot_registry.gd`
- Test: `tests/unit/test_chest_loot_registry.gd`

- [ ] **Write failing tests**

Create `tests/unit/test_chest_loot_registry.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	ChestLootRegistry.reset()


func test_rolls_loot_floor_1() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result: Dictionary = ChestLootRegistry.roll_loot(1, rng)
	assert_true(result.has("id"), "Should have id field")
	assert_true(result.has("count"), "Should have count field")
	assert_true(int(result["count"]) >= 1)


func test_rolls_loot_deep_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result: Dictionary = ChestLootRegistry.roll_loot(20, rng)
	assert_true(result.has("id"))


func test_floor_tier_selection() -> void:
	# Floor 1 uses tier 0 (max_floor 5), floor 20 uses tier 2 (min_floor 16)
	var tier1: Dictionary = ChestLootRegistry.get_tier_for_floor(1)
	var tier3: Dictionary = ChestLootRegistry.get_tier_for_floor(20)
	assert_eq(int(tier1.get("max_floor", 0)), 5)
	assert_eq(int(tier3.get("min_floor", 0)), 16)


func test_reset_clears_cache() -> void:
	# Force a load then reset
	ChestLootRegistry.get_tier_for_floor(1)
	ChestLootRegistry.reset()
	assert_false(ChestLootRegistry.is_loaded())
```

- [ ] **Run tests to confirm FAIL**

```bash
godot --headless -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_chest_loot_registry.gd -gexit 2>&1 | tail -10
```

Expected: FAILED.

- [ ] **Implement ChestLootRegistry**

Create `scripts/data/chest_loot_registry.gd`:

```gdscript
## ChestLootRegistry
##
## Static registry for depth-tiered treasure chest loot.
## Schema: resources/chest_loot.json
##   { "tiers": [{ min_floor, max_floor, loot: [{id, weight, min, max}] }] }
class_name ChestLootRegistry
extends RefCounted

const _JSON_PATH: String = "res://resources/chest_loot.json"

static var _tiers: Array = []
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_JSON_PATH):
		push_warning("[ChestLootRegistry] %s not found" % _JSON_PATH)
		return
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_warning("[ChestLootRegistry] parse error: %s" % json.get_error_message())
		return
	if json.data is Dictionary:
		_tiers = json.data.get("tiers", [])


static func reset() -> void:
	_tiers.clear()
	_loaded = false


static func is_loaded() -> bool:
	return _loaded


## Returns the raw tiers array for editing by the GameEditor panel.
static func get_raw_tiers() -> Array:
	_ensure_loaded()
	return _tiers.duplicate(true)


## Persist edits from the GameEditor back to disk.
static func save_data(tiers: Array) -> void:
	_tiers = tiers
	_loaded = true
	var f := FileAccess.open(_JSON_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[ChestLootRegistry] cannot write %s" % _JSON_PATH)
		return
	f.store_string(JSON.stringify({"tiers": tiers}, "\t"))
	f.close()


## Returns the tier dict covering `floor_num`. Falls back to last tier.
static func get_tier_for_floor(floor_num: int) -> Dictionary:
	_ensure_loaded()
	for tier in _tiers:
		var mn: int = int(tier.get("min_floor", 1))
		var mx: int = int(tier.get("max_floor", 999))
		if floor_num >= mn and floor_num <= mx:
			return tier
	return _tiers.back() if not _tiers.is_empty() else {}


## Roll one item from the appropriate depth tier.
## Returns {id: StringName, count: int}.
static func roll_loot(floor_num: int, rng: RandomNumberGenerator) -> Dictionary:
	var tier: Dictionary = get_tier_for_floor(floor_num)
	var table: Array = tier.get("loot", [])
	if table.is_empty():
		return {"id": &"stone", "count": 1}
	var total: int = 0
	for e in table:
		total += int(e.get("weight", 1))
	var roll: int = rng.randi_range(1, max(1, total))
	var acc: int = 0
	for e in table:
		acc += int(e.get("weight", 1))
		if roll <= acc:
			return {
				"id": StringName(e.get("id", "")),
				"count": rng.randi_range(int(e.get("min", 1)), int(e.get("max", 1))),
			}
	return {"id": StringName(table[0].get("id", "")), "count": 1}
```

- [ ] **Run tests to confirm PASS**

```bash
godot --headless -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_chest_loot_registry.gd -gexit 2>&1 | tail -10
```

Expected: all 4 tests pass.

- [ ] **Commit**

```bash
git add scripts/data/chest_loot_registry.gd tests/unit/test_chest_loot_registry.gd
git commit -m "feat: add ChestLootRegistry with depth-tiered chest loot"
```

---

## Task 4: Extend InteriorMap + CreatureSpriteRegistry

**Files:**
- Modify: `scripts/data/interior_map.gd`
- Modify: `scripts/data/creature_sprite_registry.gd`

- [ ] **Extend InteriorMap**

In `scripts/data/interior_map.gd`, make two changes:

Change `MAX_SIZE`:
```gdscript
# OLD:
const MAX_SIZE: int = 64
# NEW:
const MAX_SIZE: int = 96
```

Add new fields after `parent_entrance_cell`:
```gdscript
## Each entry: {cell: Vector2i, floor_num: int} — placed by LabyrinthGenerator at dead ends.
@export var chest_scatter: Array = []
## Floor cells that make up the boss room area (used for boss-room floor decor overlay).
@export var boss_room_cells: Array = []  # Array of Vector2i
## Boss spawn data: {kind: StringName, cell: Vector2i, adds: [{kind, cell}]}.
## Empty dict when this floor has no boss room.
@export var boss_data: Dictionary = {}
```

- [ ] **Add is_boss / get_boss_adds to CreatureSpriteRegistry**

In `scripts/data/creature_sprite_registry.gd`, add these two static functions after `get_entry()`:

```gdscript
## Returns true if the creature is flagged as a boss.
static func is_boss(kind: StringName) -> bool:
	return bool(get_entry(kind).get("is_boss", false))


## Returns the boss_adds array for a boss creature, or empty array.
## Each entry: {creature: StringName, count: int}
static func get_boss_adds(kind: StringName) -> Array:
	var adds: Variant = get_entry(kind).get("boss_adds", null)
	if adds is Array:
		return adds
	return []
```

- [ ] **Refresh class cache**

```bash
timeout 15 godot --headless --editor /home/mpatterson/repos/game4 & sleep 12; kill %1 2>/dev/null; echo "done"
```

- [ ] **Run all unit tests to confirm no regression**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Commit**

```bash
git add scripts/data/interior_map.gd scripts/data/creature_sprite_registry.gd
git commit -m "feat: extend InteriorMap (chest/boss fields, MAX_SIZE 96) and CreatureSpriteRegistry (is_boss, get_boss_adds)"
```

---

## Task 5: LabyrinthGenerator — Maze + Dead Ends

**Files:**
- Create: `scripts/world/labyrinth_generator.gd`
- Test: `tests/unit/test_labyrinth_generator.gd`

- [ ] **Write failing tests first**

Create `tests/unit/test_labyrinth_generator.gd`:

```gdscript
extends GutTest

func test_generates_interiormap() -> void:
	var m: InteriorMap = LabyrinthGenerator.generate(12345, 64, 64, 1)
	assert_not_null(m)
	assert_eq(m.width, 64)
	assert_eq(m.height, 64)


func test_entry_and_exit_are_floor() -> void:
	var m: InteriorMap = LabyrinthGenerator.generate(42, 64, 64, 1)
	assert_eq(m.at(m.entry_cell), TerrainCodes.INTERIOR_STAIRS_UP)
	assert_eq(m.at(m.exit_cell), TerrainCodes.INTERIOR_STAIRS_DOWN)
	assert_ne(m.entry_cell, m.exit_cell)


func test_maze_is_connected() -> void:
	# BFS from entry; must reach exit.
	var m: InteriorMap = LabyrinthGenerator.generate(99, 64, 64, 1)
	var visited: Dictionary = {}
	var queue: Array = [m.entry_cell]
	visited[m.entry_cell] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var nb := cur + d
			if visited.has(nb):
				continue
			if m.at(nb) != TerrainCodes.INTERIOR_WALL:
				visited[nb] = true
				queue.append(nb)
	assert_true(visited.has(m.exit_cell), "Exit cell must be reachable from entry")


func test_has_chests_at_dead_ends() -> void:
	var m: InteriorMap = LabyrinthGenerator.generate(7777, 64, 64, 1)
	assert_true(m.chest_scatter.size() >= 2, "Should have at least 2 dead-end chests; got %d" % m.chest_scatter.size())


func test_no_boss_on_non_boss_floor() -> void:
	var m: InteriorMap = LabyrinthGenerator.generate(1, 64, 64, 1)
	assert_true(m.boss_data.is_empty(), "Floor 1 should have no boss")


func test_boss_on_boss_floor() -> void:
	var m: InteriorMap = LabyrinthGenerator.generate(1, 64, 64, 5)
	assert_false(m.boss_data.is_empty(), "Floor 5 should have a boss")
	assert_true(m.boss_room_cells.size() >= 4, "Boss room should have some floor cells")


func test_variable_size() -> void:
	# Width/height should be clamped to MIN_SIZE..MAX_SIZE
	var m_small: InteriorMap = LabyrinthGenerator.generate(1, 10, 10, 1)
	assert_eq(m_small.width, InteriorMap.MIN_SIZE)
	var m_big: InteriorMap = LabyrinthGenerator.generate(1, 200, 200, 1)
	assert_eq(m_big.width, InteriorMap.MAX_SIZE)
```

- [ ] **Run tests to confirm FAIL**

```bash
godot --headless -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_labyrinth_generator.gd -gexit 2>&1 | tail -10
```

Expected: FAILED (LabyrinthGenerator not defined).

- [ ] **Implement LabyrinthGenerator**

Create `scripts/world/labyrinth_generator.gd`:

```gdscript
## LabyrinthGenerator
##
## Generates Gauntlet-style labyrinths using Prim's maze algorithm on a
## coarse junction grid. Corridors are 2-4 tiles wide, producing the dense
## dead-end-rich layout that makes Prim's feel like a true labyrinth.
##
## Output is an [InteriorMap] with INTERIOR_FLOOR / INTERIOR_WALL /
## INTERIOR_STAIRS_UP / INTERIOR_STAIRS_DOWN cells, plus chest_scatter
## at dead-end junctions, and boss_data / boss_room_cells on boss floors.
##
## All randomness is seeded from `seed_val` for determinism.
class_name LabyrinthGenerator
extends RefCounted

## Spacing between junction centres in tiles.
## Corridors fill the gap between junction centres; actual width = stride - 2*wall.
const _MIN_CORRIDOR_WIDTH: int = 2
const _MAX_CORRIDOR_WIDTH: int = 4
## Half-wall thickness on each side of a corridor.
const _WALL_THICKNESS: int = 1
## Stride: distance between adjacent junction centres (corridor + walls on both sides).
const _STRIDE: int = _MAX_CORRIDOR_WIDTH + 2 * _WALL_THICKNESS  ## = 6
## Minimum clearance from map edge to first junction.
const _MARGIN: int = 2
## Size of the boss room in tiles (square).
const _BOSS_ROOM_HALF: int = 4


## Generate an [InteriorMap]. `width`/`height` are clamped to
## [InteriorMap.MIN_SIZE..MAX_SIZE]. `floor_num` drives boss/enemy scaling.
static func generate(seed_val: int, width: int, height: int,
		floor_num: int = 1) -> InteriorMap:
	width  = clampi(width,  InteriorMap.MIN_SIZE, InteriorMap.MAX_SIZE)
	height = clampi(height, InteriorMap.MIN_SIZE, InteriorMap.MAX_SIZE)

	var m := InteriorMap.new()
	m.seed = seed_val
	m.width = width
	m.height = height
	m.tiles = PackedByteArray()
	m.tiles.resize(width * height)
	for i in width * height:
		m.tiles[i] = TerrainCodes.INTERIOR_WALL

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# ── Build junction grid ──────────────────────────────────────────
	# Junctions are the "cells" of the abstract maze.
	var jw: int = (width  - 2 * _MARGIN) / _STRIDE
	var jh: int = (height - 2 * _MARGIN) / _STRIDE
	jw = max(jw, 2)
	jh = max(jh, 2)

	# Each junction centre in tile coords.
	var junctions: Array = []  # Array[Vector2i], row-major
	for jy in jh:
		for jx in jw:
			junctions.append(Vector2i(
				_MARGIN + jx * _STRIDE + _MAX_CORRIDOR_WIDTH / 2,
				_MARGIN + jy * _STRIDE + _MAX_CORRIDOR_WIDTH / 2))

	# Adjacency: up/right/down/left per junction index.
	# direction_delta[d] = Vector2i(djx, djy) in junction grid coords.
	var dir_delta: Array = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]

	# ── Prim's maze ──────────────────────────────────────────────────
	# visited[jidx] = true when junction is carved into the maze.
	var visited: Array = []
	visited.resize(jw * jh)
	visited.fill(false)
	# connection[jidx] = array of connected neighbor jidx.
	var connection: Array = []
	connection.resize(jw * jh)
	for i in connection.size():
		connection[i] = []

	# Frontier: array of [from_jidx, to_jidx] pairs.
	var frontier: Array = []

	# Start from a random border junction.
	var start_j: Vector2i = Vector2i(0, rng.randi_range(0, jh - 1))
	var start_idx: int = start_j.y * jw + start_j.x
	visited[start_idx] = true
	_push_frontier(start_idx, jw, jh, visited, dir_delta, frontier)

	while not frontier.is_empty():
		var fi: int = rng.randi_range(0, frontier.size() - 1)
		var edge: Array = frontier[fi]
		frontier.remove_at(fi)
		var from_idx: int = edge[0]
		var to_idx: int = edge[1]
		if visited[to_idx]:
			continue
		visited[to_idx] = true
		connection[from_idx].append(to_idx)
		connection[to_idx].append(from_idx)
		_push_frontier(to_idx, jw, jh, visited, dir_delta, frontier)
		# Carve corridor between from and to junctions.
		_carve_corridor(rng, m, junctions[from_idx], junctions[to_idx])

	# ── Entry / Exit ─────────────────────────────────────────────────
	# Entry: border junction with fewest connections (= simplest to navigate from).
	# Exit: junction furthest from entry by BFS hop count.
	var entry_idx: int = _pick_border_junction(jw, jh, connection, rng)
	var exit_idx: int = _pick_far_junction(entry_idx, jw * jh, connection)
	var entry_cell: Vector2i = junctions[entry_idx]
	var exit_cell: Vector2i = junctions[exit_idx]
	m.set_at(entry_cell, TerrainCodes.INTERIOR_STAIRS_UP)
	m.set_at(exit_cell,  TerrainCodes.INTERIOR_STAIRS_DOWN)
	m.entry_cell = entry_cell
	m.exit_cell  = exit_cell

	# ── Dead ends → chest scatter ─────────────────────────────────────
	# A dead end has exactly 1 connection. Skip entry & exit junctions.
	for idx in jw * jh:
		if idx == entry_idx or idx == exit_idx:
			continue
		if (connection[idx] as Array).size() == 1:
			m.chest_scatter.append({
				"cell": junctions[idx],
				"floor_num": floor_num,
			})

	# ── Boss room ──────────────────────────────────────────────────────
	var boss_interval: int = EncounterTableRegistry.get_boss_interval(&"labyrinth")
	if floor_num > 0 and (floor_num % boss_interval) == 0:
		_carve_boss_room(rng, m, junctions, exit_idx, floor_num, connection)

	# ── Enemy scatter ─────────────────────────────────────────────────
	_scatter_enemies(rng, m, junctions, entry_idx, floor_num)

	return m


# ─── Prim's helpers ───────────────────────────────────────────────────

static func _push_frontier(jidx: int, jw: int, jh: int,
		visited: Array, dir_delta: Array, frontier: Array) -> void:
	var jx: int = jidx % jw
	var jy: int = jidx / jw
	for d in dir_delta:
		var nx: int = jx + d.x
		var ny: int = jy + d.y
		if nx < 0 or nx >= jw or ny < 0 or ny >= jh:
			continue
		var nidx: int = ny * jw + nx
		if not visited[nidx]:
			frontier.append([jidx, nidx])


# ─── Corridor carving ──────────────────────────────────────────────────

## Carve a variable-width corridor between two junction centres.
static func _carve_corridor(rng: RandomNumberGenerator, m: InteriorMap,
		from: Vector2i, to: Vector2i) -> void:
	var w: int = rng.randi_range(_MIN_CORRIDOR_WIDTH, _MAX_CORRIDOR_WIDTH)
	var half: int = w / 2
	if from.x == to.x:
		# Vertical corridor.
		var y0: int = min(from.y, to.y)
		var y1: int = max(from.y, to.y)
		var cx: int = from.x
		for y in range(y0, y1 + 1):
			for dx in range(-half, half + (w % 2)):
				m.set_at(Vector2i(cx + dx, y), TerrainCodes.INTERIOR_FLOOR)
	else:
		# Horizontal corridor.
		var x0: int = min(from.x, to.x)
		var x1: int = max(from.x, to.x)
		var cy: int = from.y
		for x in range(x0, x1 + 1):
			for dy in range(-half, half + (w % 2)):
				m.set_at(Vector2i(x, cy + dy), TerrainCodes.INTERIOR_FLOOR)


# ─── Entry / Exit selection ────────────────────────────────────────────

static func _pick_border_junction(jw: int, jh: int,
		connection: Array, rng: RandomNumberGenerator) -> int:
	# Collect border junction indices, pick lowest-connectivity one.
	var border: Array = []
	for jy in jh:
		for jx in jw:
			if jx == 0 or jx == jw - 1 or jy == 0 or jy == jh - 1:
				border.append(jy * jw + jx)
	if border.is_empty():
		return 0
	# Shuffle for randomness, then pick minimum connectivity.
	border.shuffle()  # crude; re-seed below is not needed since Prim's already determines layout
	var best: int = border[0]
	var best_conn: int = (connection[best] as Array).size()
	for idx in border:
		var c: int = (connection[idx] as Array).size()
		if c < best_conn:
			best_conn = c
			best = idx
	return best


static func _pick_far_junction(start: int, total: int, connection: Array) -> int:
	# BFS from start, return the index with the greatest hop distance.
	var dist: Array = []
	dist.resize(total)
	dist.fill(-1)
	dist[start] = 0
	var queue: Array = [start]
	var farthest: int = start
	var max_dist: int = 0
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nb in (connection[cur] as Array):
			if dist[nb] == -1:
				dist[nb] = dist[cur] + 1
				if dist[nb] > max_dist:
					max_dist = dist[nb]
					farthest = nb
				queue.append(nb)
	return farthest


# ─── Boss room ──────────────────────────────────────────────────────────

static func _carve_boss_room(rng: RandomNumberGenerator, m: InteriorMap,
		junctions: Array, exit_idx: int,
		floor_num: int, connection: Array) -> void:
	# Pick a deep dead-end near the exit for the boss room.
	# Fall back to the exit junction itself.
	var boss_jidx: int = exit_idx
	var dead_ends: Array = []
	for idx in connection.size():
		if idx == exit_idx:
			continue
		if (connection[idx] as Array).size() == 1:
			dead_ends.append(idx)
	if not dead_ends.is_empty():
		# Pick the one closest (in junction-hop distance) to exit.
		var min_dist: int = 999
		var best_idx: int = exit_idx
		for idx in dead_ends:
			var d: int = abs(junctions[idx].x - junctions[exit_idx].x) \
				+ abs(junctions[idx].y - junctions[exit_idx].y)
			if d < min_dist:
				min_dist = d
				best_idx = idx
		boss_jidx = best_idx

	var centre: Vector2i = junctions[boss_jidx]
	# Carve an 8×8 clearing around the centre.
	var room_cells: Array = []
	for dy in range(-_BOSS_ROOM_HALF, _BOSS_ROOM_HALF + 1):
		for dx in range(-_BOSS_ROOM_HALF, _BOSS_ROOM_HALF + 1):
			var cell := centre + Vector2i(dx, dy)
			m.set_at(cell, TerrainCodes.INTERIOR_FLOOR)
			room_cells.append(cell)
	m.boss_room_cells = room_cells

	# Pick a boss creature.
	var boss_kind: StringName = _pick_boss_kind(rng)

	# Place adds in the corners of the room.
	var adds_data: Array = []
	var adds_list: Array = CreatureSpriteRegistry.get_boss_adds(boss_kind)
	var add_positions: Array = [
		centre + Vector2i(-3, -3),
		centre + Vector2i( 3, -3),
		centre + Vector2i(-3,  3),
		centre + Vector2i( 3,  3),
	]
	var ai: int = 0
	for add_entry in adds_list:
		var add_count: int = int(add_entry.get("count", 1))
		for _i in add_count:
			if ai >= add_positions.size():
				break
			adds_data.append({
				"kind": StringName(add_entry.get("creature", &"slime")),
				"cell": add_positions[ai],
			})
			ai += 1

	m.boss_data = {
		"kind": boss_kind,
		"cell": centre,
		"adds": adds_data,
	}

	# Remove the boss junction from chest_scatter (it's a boss room now).
	m.chest_scatter = m.chest_scatter.filter(
		func(e: Dictionary) -> bool: return e["cell"] != centre)


static func _pick_boss_kind(rng: RandomNumberGenerator) -> StringName:
	# Find all creatures flagged is_boss in the registry.
	var all_kinds: Array = CreatureSpriteRegistry.all_kinds()
	var bosses: Array = all_kinds.filter(
		func(k) -> bool: return CreatureSpriteRegistry.is_boss(StringName(k)))
	if bosses.is_empty():
		return &"slime_king"  # fallback
	return StringName(bosses[rng.randi_range(0, bosses.size() - 1)])


# ─── Enemy scatter ─────────────────────────────────────────────────────

static func _scatter_enemies(rng: RandomNumberGenerator, m: InteriorMap,
		junctions: Array, entry_idx: int, floor_num: int) -> void:
	var table: Array = EncounterTableRegistry.get_weighted_list(&"labyrinth", floor_num)
	if table.is_empty():
		return
	var boss_cells: Dictionary = {}
	for cell in m.boss_room_cells:
		boss_cells[cell] = true

	# ~30% of junctions spawn an enemy; skip entry and boss room junctions.
	for idx in junctions.size():
		if idx == entry_idx:
			continue
		var jcell: Vector2i = junctions[idx]
		if boss_cells.has(jcell):
			continue
		if rng.randf() >= 0.30:
			continue
		var pick: Dictionary = EncounterTableRegistry.weighted_pick(rng, table)
		if pick.is_empty():
			continue
		var kind: StringName = pick.get("creature", &"slime")
		m.npcs_scatter.append({
			"kind": kind,
			"monster_kind": kind,
			"cell": jcell,
			"variant": rng.randi(),
		})
```

- [ ] **Refresh class cache**

```bash
timeout 15 godot --headless --editor /home/mpatterson/repos/game4 & sleep 12; kill %1 2>/dev/null; echo "done"
```

- [ ] **Run generator tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_labyrinth_generator.gd -gexit 2>&1 | tail -10
```

Expected: all 7 tests pass.

- [ ] **Commit**

```bash
git add scripts/world/labyrinth_generator.gd tests/unit/test_labyrinth_generator.gd
git commit -m "feat: add LabyrinthGenerator (Prim's maze, dead-end chests, boss rooms)"
```

---

## Task 6: TreasureChest Entity

**Files:**
- Create: `scripts/entities/treasure_chest.gd`
- Create: `scenes/entities/TreasureChest.tscn`

- [ ] **Implement TreasureChest script**

Create `scripts/entities/treasure_chest.gd`:

```gdscript
## TreasureChest
##
## Interactive chest entity placed at labyrinth dead ends. A player within
## interaction range pressing their interact input opens the chest, spawning
## LootPickup nodes and switching to the open sprite frame.
##
## Interaction is handled by WorldRoot._process() which polls nearby players
## against in-range chests using the Area2D body tracking.
##
## After opening the chest stays in the world as a visual landmark (open frame).
class_name TreasureChest
extends Node2D

## Floor depth used to pick the correct chest_loot.json tier.
@export var floor_num: int = 1
## True once the chest has been opened this session.
var is_opened: bool = false

## Players currently in interaction range (tracked by Area2D signals).
var _players_in_range: Array = []

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _area: Area2D = $Area2D

## Atlas cells on dungeon_sheet.png for closed and open frames.
## Adjust these after reviewing the dungeon_sheet visually in the editor.
const _CLOSED_CELL: Vector2i = Vector2i(2, 10)
const _OPEN_CELL:   Vector2i = Vector2i(3, 10)
const _TILE_PX: int = 16
const _MARGIN: int = 1  # 1px gutter between cells on the sheet


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_refresh_sprite(false)


## Called by WorldRoot when a player in range presses their interact input.
func open(player: Node) -> void:
	if is_opened:
		return
	is_opened = true
	_refresh_sprite(true)

	# Roll 2-3 items from the depth-appropriate tier.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 7 + position.y * 13 + floor_num * 97)
	var count: int = rng.randi_range(2, 3)
	for i in count:
		var loot: Dictionary = ChestLootRegistry.roll_loot(floor_num, rng)
		if loot.get("id", &"") == &"":
			continue
		var pickup := LootPickup.new()
		pickup.item_id = loot["id"]
		pickup.count = loot.get("count", 1)
		var scatter := Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
		pickup.position = position + scatter
		get_parent().add_child(pickup)


## Returns the first player in range, or null.
func nearest_player_in_range() -> Node:
	for p in _players_in_range:
		if is_instance_valid(p):
			return p
	return null


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_hit"):  # Is a PlayerController
		_players_in_range.append(body)


func _on_body_exited(body: Node) -> void:
	_players_in_range.erase(body)


func _refresh_sprite(opened: bool) -> void:
	if _sprite == null:
		return
	var atlas: Vector2i = _OPEN_CELL if opened else _CLOSED_CELL
	var tex: Texture2D = load("res://assets/tiles/roguelike/dungeon_sheet.png")
	if tex == null:
		return
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(
		atlas.x * (_TILE_PX + _MARGIN),
		atlas.y * (_TILE_PX + _MARGIN),
		_TILE_PX, _TILE_PX)
	_sprite.centered = true
```

- [ ] **Create TreasureChest scene**

Create `scenes/entities/TreasureChest.tscn` with this content:

```
[gd_scene load_steps=2 format=3 uid="uid://labyrinth_chest"]

[ext_resource type="Script" path="res://scripts/entities/treasure_chest.gd" id="1"]

[node name="TreasureChest" type="Node2D"]
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]

[node name="Area2D" type="Area2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Area2D"]
shape = CircleShape2D(radius=20.0)
```

> After creating the scene, open it in the Godot editor and verify the CollisionShape2D has a CircleShape2D with radius 20 (about 1.25 tiles). If GDScene format gives import errors, create the scene manually in the editor using the script above.

- [ ] **Refresh class cache**

```bash
timeout 15 godot --headless --editor /home/mpatterson/repos/game4 & sleep 12; kill %1 2>/dev/null; echo "done"
```

- [ ] **Commit**

```bash
git add scripts/entities/treasure_chest.gd scenes/entities/TreasureChest.tscn
git commit -m "feat: add TreasureChest entity (interactive, persistent open sprite)"
```

---

## Task 7: MapManager — Kind Preservation + Labyrinth Routing

**Files:**
- Modify: `scripts/autoload/map_manager.gd`

- [ ] **Add `_kind_from_id` helper**

In `scripts/autoload/map_manager.gd`, add this static helper function before `_seed_for`:

```gdscript
## Extract the kind prefix from a map_id (e.g. "labyrinth@1:2:3:4:1" → &"labyrinth").
static func _kind_from_id(map_id: StringName) -> StringName:
	var s: String = String(map_id)
	var at: int = s.find("@")
	if at >= 0:
		return StringName(s.substr(0, at))
	return &"dungeon"
```

- [ ] **Update `descend_from` to preserve kind**

Find `func descend_from` and change the `make_id` and `get_or_generate` calls to preserve kind:

```gdscript
# OLD:
func descend_from(current: InteriorMap, size: int = DEFAULT_FLOOR_SIZE) -> InteriorMap:
	var next_floor: int = current.floor_num + 1
	var rid: Vector2i = current.origin_region_id
	var origin: Vector2i = current.origin_cell
	var new_id: StringName = make_id(rid, origin, next_floor)
	var m: InteriorMap = get_or_generate(new_id, rid, origin, next_floor, size)

# NEW:
func descend_from(current: InteriorMap, size: int = DEFAULT_FLOOR_SIZE) -> InteriorMap:
	var next_floor: int = current.floor_num + 1
	var rid: Vector2i = current.origin_region_id
	var origin: Vector2i = current.origin_cell
	var kind: StringName = _kind_from_id(current.map_id)
	var new_id: StringName = make_id(rid, origin, next_floor, kind)
	var m: InteriorMap = get_or_generate(new_id, rid, origin, next_floor, size, kind)
```

> Only the two lines for `new_id` and `m` change; keep all the `if m.parent_map_id == "":` logic that follows untouched.

- [ ] **Update `get_or_generate` to route labyrinth kind**

Find the line `m = DungeonGenerator.generate(seed_val, size, size)` inside `get_or_generate` and expand it:

```gdscript
# OLD:
	if kind == &"house":
		m = HouseGenerator.generate(seed_val)
	else:
		m = DungeonGenerator.generate(seed_val, size, size)

# NEW:
	if kind == &"house":
		m = HouseGenerator.generate(seed_val)
	elif kind == &"labyrinth":
		var floor_n: int = floor_num
		m = LabyrinthGenerator.generate(seed_val, size, size, floor_n)
	else:
		m = DungeonGenerator.generate(seed_val, size, size)
```

- [ ] **Run full unit test suite**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Commit**

```bash
git add scripts/autoload/map_manager.gd
git commit -m "feat: MapManager routes labyrinth kind to LabyrinthGenerator, descend_from preserves kind"
```

---

## Task 8: WorldRoot — Labyrinth View Routing + Door Handling

**Files:**
- Modify: `scripts/world/world_root.gd`

- [ ] **Add `_view_kind_from_interior` helper**

Add this helper near the top of WorldRoot's private methods section (after `_paint_interior`):

```gdscript
## Derive the correct view_kind for an InteriorMap from its map_id.
static func _view_kind_from_interior(interior: InteriorMap) -> StringName:
	if interior == null:
		return &"overworld"
	return MapManager._kind_from_id(interior.map_id)
```

- [ ] **Update `_attach_interior_tilesets`**

The labyrinth uses the same dungeon TileSet. Add an explicit case so the intent is clear:

```gdscript
# OLD:
	match view_kind:
		&"city": ts = TilesetCatalog.city()
		&"house": ts = TilesetCatalog.interior()
		_: ts = TilesetCatalog.dungeon()

# NEW:
	match view_kind:
		&"city": ts = TilesetCatalog.city()
		&"house": ts = TilesetCatalog.interior()
		&"dungeon", &"labyrinth": ts = TilesetCatalog.dungeon()
		_: ts = TilesetCatalog.dungeon()
```

- [ ] **Update `_paint_interior` to route labyrinth**

```gdscript
# OLD:
func _paint_interior(interior: InteriorMap, view_kind: StringName) -> void:
	if view_kind == &"dungeon":
		_paint_dungeon_interior(interior)
		return

# NEW:
func _paint_interior(interior: InteriorMap, view_kind: StringName) -> void:
	if view_kind == &"dungeon" or view_kind == &"labyrinth":
		_paint_dungeon_interior(interior)
		if view_kind == &"labyrinth" and not interior.boss_room_cells.is_empty():
			_paint_boss_room_overlay(interior)
		return
```

- [ ] **Add `_paint_boss_room_overlay`**

Add after `_paint_dungeon_interior`:

```gdscript
## Paint a distinct floor decor pattern over boss room cells.
func _paint_boss_room_overlay(interior: InteriorMap) -> void:
	# Use the last few DUNGEON_FLOOR_DECOR_CELLS as boss-room tint tiles.
	var decor: Array = TilesetCatalog.DUNGEON_FLOOR_DECOR_CELLS
	if decor.is_empty():
		return
	var boss_tile: Vector2i = decor[decor.size() - 1]
	for cell_var in interior.boss_room_cells:
		var cell: Vector2i = cell_var
		# Paint every other cell in a checkerboard for a "boss arena" feel.
		if (cell.x + cell.y) % 2 == 0:
			decoration.set_cell(cell, 0, boss_tile, 0)
```

- [ ] **Update `_build_door_index` — overworld labyrinth entrance**

Find the overworld branch inside `_build_door_index`:

```gdscript
# OLD:
		if ek == &"house":
			_doors[c] = {"kind": &"house_enter", "cell": c}
		else:
			_doors[c] = {"kind": &"dungeon_enter", "cell": c}

# NEW:
		if ek == &"house":
			_doors[c] = {"kind": &"house_enter", "cell": c}
		elif ek == &"labyrinth":
			_doors[c] = {"kind": &"labyrinth_enter", "cell": c}
		else:
			_doors[c] = {"kind": &"dungeon_enter", "cell": c}
```

- [ ] **Update `_build_door_index` — interior labyrinth stairs**

Find the interior branch:

```gdscript
# OLD:
	elif _interior != null:
		if view_kind == &"dungeon":
			_doors[_interior.entry_cell] = {"kind": &"stairs_up"}
			_doors[_interior.exit_cell] = {"kind": &"stairs_down"}
		else:
			_doors[_interior.exit_cell] = {"kind": &"interior_exit"}

# NEW:
	elif _interior != null:
		if view_kind == &"dungeon" or view_kind == &"labyrinth":
			_doors[_interior.entry_cell] = {"kind": &"stairs_up"}
			_doors[_interior.exit_cell] = {"kind": &"stairs_down"}
		else:
			_doors[_interior.exit_cell] = {"kind": &"interior_exit"}
```

- [ ] **Add `labyrinth_enter` case to `_handle_door`**

Find the `&"dungeon_enter":` case and add the labyrinth case immediately after it:

```gdscript
		&"labyrinth_enter":
			Sfx.play(&"dungeon_enter")
			var lrid: Vector2i = _region.region_id
			var lsize: int = randi_range(64, 96)
			var lmid: StringName = MapManager.make_id(lrid, cell, 1, &"labyrinth")
			var labyrinth: InteriorMap = MapManager.get_or_generate(
					lmid, lrid, cell, 1, lsize, &"labyrinth")
			World.instance().transition_player(
					player.player_id, &"labyrinth", _region, labyrinth)
```

- [ ] **Fix `stairs_up` parent transition to preserve view_kind**

Find the `stairs_up` handler's parent transition line:

```gdscript
# OLD (inside stairs_up, the else branch with parent != null):
				World.instance().transition_player(pid2, &"dungeon", origin_r, parent, parent_cell))

# NEW:
				var parent_kind: StringName = WorldRoot._view_kind_from_interior(parent)
				World.instance().transition_player(pid2, parent_kind, origin_r, parent, parent_cell))
```

> The exact context is: `_play_cave_transition(func() -> void:` → inside it, `World.instance().transition_player(pid2, &"dungeon", ...)`. Replace just that `&"dungeon"` string.

- [ ] **Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Commit**

```bash
git add scripts/world/world_root.gd
git commit -m "feat: WorldRoot routes labyrinth view_kind — paint, doors, stair transitions"
```

---

## Task 9: WorldRoot — Chest Scatter + Interact

**Files:**
- Modify: `scripts/world/world_root.gd`

- [ ] **Add `_TreasureChestScene` preload**

Near the top of `world_root.gd` where other preloads live (e.g. `_BoatScene`):

```gdscript
const _TreasureChestScene: PackedScene = preload("res://scenes/entities/TreasureChest.tscn")
```

- [ ] **Add `_materialize_chest_scatter`**

Add after `_materialize_loot_scatter`:

```gdscript
func _materialize_chest_scatter() -> void:
	if _interior == null or _interior.chest_scatter.is_empty():
		return
	for entry in _interior.chest_scatter:
		var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
		var floor_n: int = int(entry.get("floor_num", _interior.floor_num))
		var chest: TreasureChest = _TreasureChestScene.instantiate()
		chest.floor_num = floor_n
		chest.position = (Vector2(cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
		entities.add_child(chest)
```

- [ ] **Call `_materialize_chest_scatter` from `apply_view`**

Find `_materialize_loot_scatter()` call in `apply_view` and add the chest call directly after it:

```gdscript
	_materialize_loot_scatter()
	_materialize_chest_scatter()
```

- [ ] **Add chest interact polling to `_process`**

Find the `_process` function in `world_root.gd`. Add chest interaction handling. Look for the area where per-player input is checked (likely near dialogue or the door-step logic). Add this block:

```gdscript
	# Chest interaction — check each player's interact input.
	for pid in range(2):
		var input_ctx: int = InputContext.get_context(pid)
		if input_ctx != InputContext.GAMEPLAY:
			continue
		var action: StringName = &"p1_interact" if pid == 0 else &"p2_interact"
		if not Input.is_action_just_pressed(action):
			continue
		var player: PlayerController = get_player(pid)
		if player == null or not is_instance_valid(player):
			continue
		# Find the nearest open-able chest to this player.
		for child in entities.get_children():
			if not (child is TreasureChest):
				continue
			var chest: TreasureChest = child
			if chest.is_opened:
				continue
			if chest.nearest_player_in_range() == player:
				chest.open(player)
				break
```

> Place this block at the top of `_process` after null/mode guards, before the existing per-player loops.

- [ ] **Spawn boss enemies from boss_data**

In `_spawn_scattered_npcs`, add boss spawning after the regular entries loop:

```gdscript
	# Boss room — spawn boss + adds if this is a labyrinth boss floor.
	if _interior != null and not _interior.boss_data.is_empty():
		var bd: Dictionary = _interior.boss_data
		var boss_entry: Dictionary = {
			"monster_kind": bd.get("kind", &"slime_king"),
			"cell": bd.get("cell", Vector2i.ZERO),
			"kind": bd.get("kind", &"slime_king"),
		}
		_spawn_monster(boss_entry)
		for add in bd.get("adds", []):
			var add_entry: Dictionary = {
				"monster_kind": StringName(add.get("kind", &"slime")),
				"cell": add.get("cell", Vector2i.ZERO),
				"kind": StringName(add.get("kind", &"slime")),
			}
			_spawn_monster(add_entry)
```

- [ ] **Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Commit**

```bash
git add scripts/world/world_root.gd
git commit -m "feat: WorldRoot materializes chest scatter and polls chest interact input"
```

---

## Task 10: F9 Debug — Labyrinth Entrance

**Files:**
- Modify: `scripts/world/world_root.gd`

- [ ] **Add labyrinth entrance to `debug_spawn_interactables_for`**

Find the block inside `debug_spawn_interactables_for` that places the dungeon and house entrances:

```gdscript
	_debug_place_entrance(&"dungeon", &"dungeon_enter",
			centre, Vector2i(-2, 0), "cave entrance")
	_debug_place_entrance(&"house", &"house_enter",
			centre, Vector2i(2, 0), "house entrance")
```

Add the labyrinth line immediately after:

```gdscript
	_debug_place_entrance(&"labyrinth", &"labyrinth_enter",
			centre, Vector2i(4, 0), "labyrinth entrance")
```

- [ ] **Run a quick smoke test**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Commit**

```bash
git add scripts/world/world_root.gd
git commit -m "feat: F9 debug spawns labyrinth entrance at offset (4,0)"
```

---

## Task 11: WorldGenerator — Labyrinth Overworld Entrances

**Files:**
- Modify: `scripts/world/world_generator.gd`

- [ ] **Add `_place_labyrinth_entrances`**

Find `_place_dungeon_entrances` in `world_generator.gd`. Add a new function immediately after it:

```gdscript
## Place 0–1 labyrinth entrances per land region. Same placement rules as
## dungeon entrances but rarer (0–1 vs 0–3) to make labyrinths feel special.
static func _place_labyrinth_entrances(region: Region) -> void:
	if region.is_ocean:
		return
	var occupied: Dictionary = {}
	for entry in region.decorations:
		occupied[entry["cell"]] = true
	for entry in region.npcs_scatter:
		occupied[entry["cell"]] = true
	for entry in region.dungeon_entrances:
		occupied[entry["cell"]] = true  # Don't overlap existing dungeon entrances.

	var rng := RandomNumberGenerator.new()
	rng.seed = region.seed ^ 0xAB7C3F1E  # Different seed mask from dungeon variant.
	if rng.randf() > 0.35:  # ~35% chance of a labyrinth per region.
		return

	var size := Region.SIZE
	var center := Vector2i(size / 2, size / 2)
	var candidates: Array[Vector2i] = []
	for y in size:
		for x in size:
			var cell := Vector2i(x, y)
			if occupied.has(cell):
				continue
			var code: int = region.at(cell)
			if code != TerrainCodes.ROCK and code != TerrainCodes.DIRT:
				continue
			if not TerrainCodes.is_walkable(code):
				continue
			if abs(cell.x - center.x) + abs(cell.y - center.y) < 20:
				continue
			candidates.append(cell)
	if candidates.is_empty():
		return
	# Deterministic shuffle.
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	region.dungeon_entrances.append({
		"kind": &"labyrinth",
		"cell": candidates[0],
	})
```

- [ ] **Call `_place_labyrinth_entrances` from `generate_region`**

Find the call to `_place_dungeon_entrances(region)` in `generate_region`. Add the labyrinth call immediately after it:

```gdscript
	_place_dungeon_entrances(region)
	_place_labyrinth_entrances(region)
```

- [ ] **Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Commit**

```bash
git add scripts/world/world_generator.gd
git commit -m "feat: WorldGenerator places labyrinth entrances on overworld (~35% of regions)"
```

---

## Task 12: TileMappings + TilesetCatalog — Labyrinth Entrance Tile

**Files:**
- Modify: `scripts/data/tile_mappings.gd`
- Modify: `scripts/world/tileset_catalog.gd`

- [ ] **Add `labyrinth_entrance_pair` to TileMappings**

In `scripts/data/tile_mappings.gd`, find the `dungeon_entrance_pair` field and add the labyrinth field immediately after it:

```gdscript
## Two side-by-side labyrinth entrance marker tiles on the dungeon sheet.
## Painted on the overworld to mark labyrinth entrances with a tint.
@export var labyrinth_entrance_pair: Array[Vector2i] = []
```

- [ ] **Add default constant and static var to TilesetCatalog**

In `scripts/world/tileset_catalog.gd`, find `_DEFAULT_DUNGEON_ENTRANCE` and add immediately after the `DUNGEON_OVERWORLD_ENTRANCE_CELLS` static var:

```gdscript
# Labyrinth entrance marker — uses the same pair but with a purple tint.
# Default reuses dungeon entrance cells; SpritePicker can override to distinct tiles.
const _DEFAULT_LABYRINTH_ENTRANCE: Array = [
	Vector2i(24, 4), Vector2i(25, 4),
]
static var LABYRINTH_OVERWORLD_ENTRANCE_CELLS: Array = _DEFAULT_LABYRINTH_ENTRANCE
```

- [ ] **Load labyrinth_entrance_pair in `_ensure_loaded`**

In `TilesetCatalog._ensure_loaded()`, find where `DUNGEON_OVERWORLD_ENTRANCE_CELLS` is set and add the labyrinth load immediately after:

```gdscript
	if not m.dungeon_entrance_pair.is_empty():
		DUNGEON_OVERWORLD_ENTRANCE_CELLS = m.dungeon_entrance_pair
	# NEW:
	if not m.labyrinth_entrance_pair.is_empty():
		LABYRINTH_OVERWORLD_ENTRANCE_CELLS = m.labyrinth_entrance_pair
```

- [ ] **Add to `_DEFAULT_SHEETS`**

In TilesetCatalog, add to the `_DEFAULT_SHEETS` dictionary:

```gdscript
	&"labyrinth_entrance_pair": "res://assets/tiles/roguelike/dungeon_sheet.png",
```

- [ ] **Update `_paint_overworld_entrance_markers` to use labyrinth cells with purple tint**

Find the tint selection line inside `_paint_overworld_entrance_markers`:

```gdscript
# OLD:
		var tint: Color = Color(1.4, 0.95, 0.6) if ek == &"house" else Color.WHITE
		for i in cells.size():
			var atlas: Vector2i = cells[i]

# NEW:
		var tint: Color
		var cells_to_use: Array
		if ek == &"house":
			tint = Color(1.4, 0.95, 0.6)  # warm yellow
			cells_to_use = cells
		elif ek == &"labyrinth":
			tint = Color(1.2, 0.6, 1.4)   # purple
			cells_to_use = TilesetCatalog.LABYRINTH_OVERWORLD_ENTRANCE_CELLS
		else:
			tint = Color.WHITE
			cells_to_use = cells
		for i in cells_to_use.size():
			var atlas: Vector2i = cells_to_use[i]
```

> Also update the `spr.modulate = tint` line below to use `tint` (it already should).

- [ ] **Add labyrinth_entrance_pair to `game_editor.gd` `_MAPPINGS`**

In `scripts/tools/game_editor.gd`, find the `dungeon_entrance_pair` entry and add the labyrinth entry immediately after:

```gdscript
	{"id": &"labyrinth_entrance_pair",           "label": "Labyrinth entrance marker pair",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"labyrinth_entrance_pair",            "kind": &"flat_list"},
```

- [ ] **Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -5
```

Expected: all tests pass.

- [ ] **Commit**

```bash
git add scripts/data/tile_mappings.gd scripts/world/tileset_catalog.gd scripts/tools/game_editor.gd
git commit -m "feat: add labyrinth_entrance_pair to TileMappings, TilesetCatalog, and GameEditor"
```

---

## Task 13: GameEditor — EncounterTableEditor Panel

**Files:**
- Create: `scripts/tools/encounter_table_editor.gd`
- Modify: `scripts/tools/game_editor.gd`

- [ ] **Implement EncounterTableEditor**

Create `scripts/tools/encounter_table_editor.gd`:

```gdscript
## EncounterTableEditor
##
## GameEditor panel for editing resources/encounter_tables.json.
## Shows per-dungeon-type depth-scaling tables:
##   - Enemy rows: creature, min_floor, max_floor, weight (inline edit)
##   - Boss interval field
## Save writes directly via EncounterTableRegistry.save_data().
extends VBoxContainer

signal dirty_changed(is_dirty: bool)

var _data: Dictionary = {}
var _dirty: bool = false
var _type_selector: OptionButton
var _boss_interval_spin: SpinBox
var _table_container: VBoxContainer
var _current_type: String = "labyrinth"


func _ready() -> void:
	_data = EncounterTableRegistry.get_raw_data()
	_build_ui()
	_load_type(_current_type)


func _build_ui() -> void:
	# Top bar: type selector + boss interval
	var top := HBoxContainer.new()
	add_child(top)

	var type_label := Label.new()
	type_label.text = "Dungeon type:"
	top.add_child(type_label)

	_type_selector = OptionButton.new()
	for t in _data.keys():
		_type_selector.add_item(String(t))
	_type_selector.item_selected.connect(_on_type_selected)
	top.add_child(_type_selector)

	var interval_label := Label.new()
	interval_label.text = "  Boss interval:"
	top.add_child(interval_label)

	_boss_interval_spin = SpinBox.new()
	_boss_interval_spin.min_value = 1
	_boss_interval_spin.max_value = 99
	_boss_interval_spin.value = 5
	_boss_interval_spin.value_changed.connect(_on_boss_interval_changed)
	top.add_child(_boss_interval_spin)

	# Column headers
	var headers := HBoxContainer.new()
	add_child(headers)
	for h in ["Creature", "Min Floor", "Max Floor", "Weight", ""]:
		var l := Label.new()
		l.text = h
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		headers.add_child(l)

	# Scroll area for table rows
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	add_child(scroll)

	_table_container = VBoxContainer.new()
	scroll.add_child(_table_container)

	# Bottom bar: Add row + Save
	var bottom := HBoxContainer.new()
	add_child(bottom)

	var add_btn := Button.new()
	add_btn.text = "+ Add Row"
	add_btn.pressed.connect(_on_add_row)
	bottom.add_child(add_btn)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save)
	bottom.add_child(save_btn)


func _load_type(type_name: String) -> void:
	_current_type = type_name
	for c in _table_container.get_children():
		c.queue_free()
	var type_data: Variant = _data.get(type_name, null)
	if not (type_data is Dictionary):
		return
	_boss_interval_spin.value = float(type_data.get("boss_interval", 5))
	var rows: Array = type_data.get("enemy_tables", [])
	for row in rows:
		_add_row_widget(row)


func _add_row_widget(row: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	_table_container.add_child(hbox)

	var creature_edit := LineEdit.new()
	creature_edit.text = String(row.get("creature", ""))
	creature_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	creature_edit.text_changed.connect(func(_t): _mark_dirty())
	hbox.add_child(creature_edit)

	for key in ["min_floor", "max_floor", "weight"]:
		var spin := SpinBox.new()
		spin.min_value = 1 if key != "max_floor" else 1
		spin.max_value = 999
		spin.value = float(row.get(key, 1))
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(_v): _mark_dirty())
		hbox.add_child(spin)

	var del_btn := Button.new()
	del_btn.text = "X"
	del_btn.pressed.connect(func(): hbox.queue_free(); _mark_dirty())
	hbox.add_child(del_btn)


func _collect_data() -> void:
	var rows: Array = []
	for hbox in _table_container.get_children():
		var children: Array = hbox.get_children()
		if children.size() < 4:
			continue
		rows.append({
			"creature": (children[0] as LineEdit).text,
			"min_floor": int((children[1] as SpinBox).value),
			"max_floor": int((children[2] as SpinBox).value),
			"weight":    int((children[3] as SpinBox).value),
		})
	if not _data.has(_current_type):
		_data[_current_type] = {}
	(_data[_current_type] as Dictionary)["enemy_tables"] = rows
	(_data[_current_type] as Dictionary)["boss_interval"] = int(_boss_interval_spin.value)


func _on_type_selected(idx: int) -> void:
	_collect_data()
	_load_type(_type_selector.get_item_text(idx))


func _on_boss_interval_changed(_v: float) -> void:
	_mark_dirty()


func _on_add_row() -> void:
	_add_row_widget({"creature": "slime", "min_floor": 1, "max_floor": 10, "weight": 5})
	_mark_dirty()


func _on_save() -> void:
	_collect_data()
	EncounterTableRegistry.save_data(_data)
	_dirty = false
	dirty_changed.emit(false)


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		dirty_changed.emit(true)
```

- [ ] **Register EncounterTableEditor in game_editor.gd**

In `scripts/tools/game_editor.gd`, find the `_MAPPINGS` array and add the encounter table entry after the existing `"encounter_editor"` entry:

```gdscript
	{"id": &"encounter_table_editor", "label": "Encounter Tables (Depth)",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"_encounter_table_editor",    "kind": &"encounter_table_editor"},
```

Then find the section where editor panel instances are stored (where `_mineable_editor`, `_encounter_editor`, etc. are declared) and add:

```gdscript
var _encounter_table_editor: EncounterTableEditor = null
```

Find the match/dispatch logic where panels are created on tree selection (look for `&"encounter_editor":` case) and add:

```gdscript
		&"encounter_table_editor":
			if _encounter_table_editor == null:
				_encounter_table_editor = EncounterTableEditor.new()
				_encounter_table_editor.dirty_changed.connect(_on_panel_dirty_changed)
			_set_right_panel(_encounter_table_editor)
```

> The exact function and structure depends on how game_editor.gd dispatches panel selection. Search for `&"mineable"` or `&"creature_editor"` to find the pattern and follow it exactly.

- [ ] **Commit**

```bash
git add scripts/tools/encounter_table_editor.gd scripts/tools/game_editor.gd
git commit -m "feat: add EncounterTableEditor panel for depth-scaled enemy tables"
```

---

## Task 14: GameEditor — ChestLootEditor Panel

**Files:**
- Create: `scripts/tools/chest_loot_editor.gd`
- Modify: `scripts/tools/game_editor.gd`

- [ ] **Implement ChestLootEditor**

Create `scripts/tools/chest_loot_editor.gd`:

```gdscript
## ChestLootEditor
##
## GameEditor panel for editing resources/chest_loot.json.
## Shows 3 depth tiers, each with floor-range fields and a weighted item list.
## Save writes via ChestLootRegistry.save_data().
extends VBoxContainer

signal dirty_changed(is_dirty: bool)

var _dirty: bool = false
var _tier_containers: Array = []


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Chest Loot Tiers (depth-scaled)"
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox := VBoxContainer.new()
	scroll.add_child(vbox)

	var tiers: Array = ChestLootRegistry.get_raw_tiers()
	_tier_containers.clear()
	for t_idx in tiers.size():
		var tier: Dictionary = tiers[t_idx]
		var panel := _build_tier_panel(tier, t_idx)
		vbox.add_child(panel)
		_tier_containers.append(panel)

	var save_btn := Button.new()
	save_btn.text = "Save Chest Loot"
	save_btn.pressed.connect(_on_save)
	add_child(save_btn)


func _build_tier_panel(tier: Dictionary, t_idx: int) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.set_meta("tier_idx", t_idx)

	var header := HBoxContainer.new()
	panel.add_child(header)

	var tier_label := Label.new()
	tier_label.text = "Tier %d — floors " % (t_idx + 1)
	header.add_child(tier_label)

	var min_spin := SpinBox.new()
	min_spin.name = "MinFloor"
	min_spin.min_value = 1
	min_spin.max_value = 999
	min_spin.value = float(tier.get("min_floor", 1))
	min_spin.value_changed.connect(func(_v): _mark_dirty())
	header.add_child(min_spin)

	var to_label := Label.new()
	to_label.text = " to "
	header.add_child(to_label)

	var max_spin := SpinBox.new()
	max_spin.name = "MaxFloor"
	max_spin.min_value = 1
	max_spin.max_value = 999
	max_spin.value = float(tier.get("max_floor", 5))
	max_spin.value_changed.connect(func(_v): _mark_dirty())
	header.add_child(max_spin)

	# Loot rows for this tier.
	var row_container := VBoxContainer.new()
	row_container.name = "Rows"
	panel.add_child(row_container)

	for loot_entry in tier.get("loot", []):
		_add_loot_row(row_container, loot_entry)

	var add_row_btn := Button.new()
	add_row_btn.text = "+ Add Item"
	add_row_btn.pressed.connect(func(): _add_loot_row(row_container, {}); _mark_dirty())
	panel.add_child(add_row_btn)

	return panel


func _add_loot_row(container: VBoxContainer, entry: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	container.add_child(hbox)

	var id_edit := LineEdit.new()
	id_edit.placeholder_text = "item_id"
	id_edit.text = String(entry.get("id", ""))
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.text_changed.connect(func(_t): _mark_dirty())
	hbox.add_child(id_edit)

	for key_default in [["weight", 5], ["min", 1], ["max", 3]]:
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = 999
		spin.value = float(entry.get(key_default[0], key_default[1]))
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(func(_v): _mark_dirty())
		hbox.add_child(spin)

	var del_btn := Button.new()
	del_btn.text = "X"
	del_btn.pressed.connect(func(): hbox.queue_free(); _mark_dirty())
	hbox.add_child(del_btn)


func _collect_tiers() -> Array:
	var result: Array = []
	for panel in _tier_containers:
		if not is_instance_valid(panel):
			continue
		var min_spin: SpinBox = panel.find_child("MinFloor", false, false)
		var max_spin: SpinBox = panel.find_child("MaxFloor", false, false)
		var row_container: VBoxContainer = panel.find_child("Rows", false, false)
		var loot: Array = []
		if row_container != null:
			for hbox in row_container.get_children():
				var children: Array = hbox.get_children()
				if children.size() < 4:
					continue
				loot.append({
					"id": (children[0] as LineEdit).text,
					"weight": int((children[1] as SpinBox).value),
					"min": int((children[2] as SpinBox).value),
					"max": int((children[3] as SpinBox).value),
				})
		result.append({
			"min_floor": int(min_spin.value) if min_spin else 1,
			"max_floor": int(max_spin.value) if max_spin else 5,
			"loot": loot,
		})
	return result


func _on_save() -> void:
	ChestLootRegistry.save_data(_collect_tiers())
	_dirty = false
	dirty_changed.emit(false)


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		dirty_changed.emit(true)
```

- [ ] **Register ChestLootEditor in game_editor.gd**

Follow the same pattern as Task 13. Add to `_MAPPINGS` after the encounter table entry:

```gdscript
	{"id": &"chest_loot_editor", "label": "Chest Loot (Depth Tiers)",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"_chest_loot_editor",            "kind": &"chest_loot_editor"},
```

Add instance variable and dispatch case (following the same pattern as `_encounter_table_editor`):

```gdscript
var _chest_loot_editor: ChestLootEditor = null
```

And in the dispatch:
```gdscript
		&"chest_loot_editor":
			if _chest_loot_editor == null:
				_chest_loot_editor = ChestLootEditor.new()
				_chest_loot_editor.dirty_changed.connect(_on_panel_dirty_changed)
			_set_right_panel(_chest_loot_editor)
```

- [ ] **Commit**

```bash
git add scripts/tools/chest_loot_editor.gd scripts/tools/game_editor.gd
git commit -m "feat: add ChestLootEditor panel for depth-tiered chest loot"
```

---

## Task 15: GameEditor — CreatureEditor Boss Fields

**Files:**
- Modify: `scripts/tools/creature_editor.gd`

- [ ] **Add is_boss and boss_adds to creature detail view**

Open `scripts/tools/creature_editor.gd`. Find where the creature combat stats section is displayed (look for `attack_style`, `attack_damage`, etc. in the detail panel). After the last combat stat field, add:

```gdscript
	# ── Boss fields ──────────────────────────────────────────────────────
	var boss_sep := HSeparator.new()
	detail.add_child(boss_sep)

	var boss_header := Label.new()
	boss_header.text = "Boss Settings"
	detail.add_child(boss_header)

	var is_boss_hbox := HBoxContainer.new()
	detail.add_child(is_boss_hbox)
	var is_boss_label := Label.new()
	is_boss_label.text = "is_boss:"
	is_boss_hbox.add_child(is_boss_label)
	var is_boss_check := CheckBox.new()
	is_boss_check.name = "IsBossCheck"
	is_boss_check.button_pressed = bool(_current_entry.get("is_boss", false))
	is_boss_check.toggled.connect(func(v: bool): _current_entry["is_boss"] = v; _mark_dirty())
	is_boss_hbox.add_child(is_boss_check)

	var adds_label := Label.new()
	adds_label.text = "boss_adds (one per line: 'creature count'):"
	detail.add_child(adds_label)

	var adds_edit := TextEdit.new()
	adds_edit.name = "BossAddsEdit"
	adds_edit.custom_minimum_size = Vector2(0, 60)
	var adds_list: Array = _current_entry.get("boss_adds", [])
	var adds_text: String = ""
	for add in adds_list:
		adds_text += "%s %d\n" % [add.get("creature", ""), int(add.get("count", 1))]
	adds_edit.text = adds_text.strip_edges()
	adds_edit.text_changed.connect(func():
		_parse_boss_adds(adds_edit.text)
		_mark_dirty())
	detail.add_child(adds_edit)
```

Add the `_parse_boss_adds` helper method:

```gdscript
func _parse_boss_adds(text: String) -> void:
	var result: Array = []
	for line in text.split("\n"):
		var parts: Array = line.strip_edges().split(" ")
		if parts.size() >= 2:
			result.append({
				"creature": parts[0],
				"count": int(parts[1]),
			})
	_current_entry["boss_adds"] = result
```

> The exact insertion point depends on how the creature detail panel is built. Look for the block that builds the right-hand detail panel when a creature is selected. The `_current_entry` variable name may differ — check the file and match its naming.

- [ ] **Commit**

```bash
git add scripts/tools/creature_editor.gd
git commit -m "feat: CreatureEditor shows is_boss and boss_adds fields"
```

---

## Task 16: Integration Tests

**Files:**
- Create: `tests/integration/test_labyrinth_descent.gd`

- [ ] **Write integration tests**

Create `tests/integration/test_labyrinth_descent.gd`:

```gdscript
extends GutTest

var _game: Node = null
const _GameScene: PackedScene = preload("res://scenes/main/Game.tscn")


func before_each() -> void:
	WorldManager.reset(20260425)
	MapManager.reset()
	ViewManager.reset()
	EncounterTableRegistry.reset()
	ChestLootRegistry.reset()
	_game = _GameScene.instantiate()
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	MapManager.reset()
	ViewManager.reset()


func test_labyrinth_entrance_enter_and_floor1() -> void:
	# Manually generate a labyrinth map_id and verify it creates a labyrinth interior.
	var rid := Vector2i(0, 0)
	var cell := Vector2i(20, 20)
	var mid: StringName = MapManager.make_id(rid, cell, 1, &"labyrinth")
	var m: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 1, 64, &"labyrinth")
	assert_not_null(m)
	assert_eq(m.floor_num, 1)
	assert_true(m.width >= 16 and m.width <= 96)
	assert_eq(MapManager._kind_from_id(m.map_id), &"labyrinth")


func test_labyrinth_descent_preserves_kind() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(30, 30)
	var mid: StringName = MapManager.make_id(rid, cell, 1, &"labyrinth")
	var floor1: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 1, 64, &"labyrinth")
	var floor2: InteriorMap = MapManager.descend_from(floor1, 64)
	assert_eq(floor2.floor_num, 2)
	assert_eq(MapManager._kind_from_id(floor2.map_id), &"labyrinth")
	var floor3: InteriorMap = MapManager.descend_from(floor2, 64)
	assert_eq(floor3.floor_num, 3)
	assert_eq(MapManager._kind_from_id(floor3.map_id), &"labyrinth")


func test_labyrinth_has_chest_scatter() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(40, 20)
	var mid: StringName = MapManager.make_id(rid, cell, 1, &"labyrinth")
	var m: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 1, 64, &"labyrinth")
	assert_true(m.chest_scatter.size() >= 1, "Floor 1 labyrinth should have chest(s)")


func test_boss_floor_has_boss_data() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(50, 20)
	var mid: StringName = MapManager.make_id(rid, cell, 5, &"labyrinth")
	var m: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 5, 64, &"labyrinth")
	assert_false(m.boss_data.is_empty(), "Floor 5 labyrinth should have boss_data")
	assert_true(m.boss_room_cells.size() >= 4, "Boss room should have cells")


func test_non_boss_floor_has_no_boss() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(60, 20)
	var mid: StringName = MapManager.make_id(rid, cell, 1, &"labyrinth")
	var m: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 1, 64, &"labyrinth")
	assert_true(m.boss_data.is_empty(), "Floor 1 should have no boss")


func test_labyrinth_map_is_connected() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(70, 20)
	var mid: StringName = MapManager.make_id(rid, cell, 1, &"labyrinth")
	var m: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 1, 64, &"labyrinth")
	# BFS from entry to exit.
	var visited: Dictionary = {}
	var queue: Array = [m.entry_cell]
	visited[m.entry_cell] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var nb := cur + d
			if not visited.has(nb) and m.at(nb) != TerrainCodes.INTERIOR_WALL:
				visited[nb] = true
				queue.append(nb)
	assert_true(visited.has(m.exit_cell), "Exit must be reachable from entry via floor tiles")
```

- [ ] **Run integration tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/integration/test_labyrinth_descent.gd -gexit 2>&1 | tail -10
```

Expected: all 6 tests pass.

- [ ] **Run full test suite**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -5
```

Expected: all tests pass. Note any failures and fix before continuing.

- [ ] **Commit**

```bash
git add tests/integration/test_labyrinth_descent.gd
git commit -m "test: labyrinth integration tests — descent, boss floor, chest scatter, connectivity"
```

---

## Task 17: Post-Implementation Skills

**Files:**
- Modify: `docs/skills/game4-dungeon-type.md`
- Create: `docs/skills/game4-game-editor.md`

- [ ] **Update game4-dungeon-type skill with as-built corrections**

Open `docs/skills/game4-dungeon-type.md` (written in Task 0). Review each checklist item against what was actually implemented and correct any inaccuracies. Pay special attention to:
- Exact function signatures (e.g. `_paint_overworld_entrance_markers` tint pattern)
- The `_view_kind_from_interior` helper (new, not in original spec)
- `EncounterTableRegistry.get_weighted_list` (actual API)

- [ ] **Write game4-game-editor skill**

Create `docs/skills/game4-game-editor.md`:

```markdown
# Extending the game4 GameEditor

Use when adding a new editor panel, a new tab to an existing panel, or a new tile-mapping category to the GameEditor dev tool.

## GameEditor Architecture

- **Main file:** `scripts/tools/game_editor.gd`
- **Scene:** `scenes/tools/GameEditor.tscn`
- **Panels:** standalone scripts in `scripts/tools/<name>_editor.gd`, extends `VBoxContainer` or `Control`
- **Tile mappings:** `resources/tilesets/tile_mappings.tres` (TileMappings resource)

## Adding a New Tile Mapping Category

1. Add an `@export` field to `scripts/data/tile_mappings.gd`:
   ```gdscript
   @export var my_thing_pair: Array[Vector2i] = []
   ```
2. Add to `TilesetCatalog._DEFAULT_SHEETS`:
   ```gdscript
   &"my_thing_pair": "res://assets/tiles/roguelike/<sheet>.png",
   ```
3. Add a static var + default const to `TilesetCatalog`:
   ```gdscript
   const _DEFAULT_MY_THING: Array = [Vector2i(x, y), ...]
   static var MY_THING_CELLS: Array = _DEFAULT_MY_THING
   ```
4. Load it in `TilesetCatalog._ensure_loaded()` from `TileMappings`.
5. Add to `game_editor.gd` `_MAPPINGS` array:
   ```gdscript
   {"id": &"my_thing_pair", "label": "My Thing", "sheet": "...", "field": &"my_thing_pair", "kind": &"flat_list"},
   ```
   Supported `kind` values: `"single"`, `"list"`, `"patch3"`, `"patch3_flat"`, `"named"`, `"flat_list"`, `"autotile"`.

## Adding a New Editor Panel

1. Create `scripts/tools/my_editor.gd` extending `VBoxContainer`:
   - Emit `signal dirty_changed(is_dirty: bool)` when content changes.
   - `func _ready()`: load data from registry.
   - Save button calls `MyRegistry.save_data(collected_data)`.

2. Add to `game_editor.gd`:
   ```gdscript
   # In _MAPPINGS:
   {"id": &"my_editor", "label": "My Feature", "sheet": "...", "field": &"_my_editor", "kind": &"my_editor"},
   # As instance variable:
   var _my_editor: MyEditor = null
   # In the panel dispatch (find the match/if-chain for "kind"):
   &"my_editor":
       if _my_editor == null:
           _my_editor = MyEditor.new()
           _my_editor.dirty_changed.connect(_on_panel_dirty_changed)
       _set_right_panel(_my_editor)
   ```

## JSON Registry Pattern

All data-driven registries follow this pattern:

```gdscript
class_name MyRegistry
extends RefCounted

const _JSON_PATH: String = "res://resources/my_data.json"
static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
    if _loaded: return
    _loaded = true
    # ... load JSON into _data

static func reset() -> void:
    _data.clear()
    _loaded = false

static func get_raw_data() -> Dictionary:
    _ensure_loaded()
    return _data.duplicate(true)

static func save_data(data: Dictionary) -> void:
    _data = data
    _loaded = true
    # ... write JSON to _JSON_PATH
```

Key rules:
- `class_name` + `extends RefCounted` (NOT Node — avoids autoload quirks)
- `reset()` is called in unit test `before_each` to clear state
- `save_data()` writes to disk AND updates `_data` in memory
- Editors call `get_raw_data()` (deep copy) to avoid mutating the cache

## Save Button Pattern

The GameEditor Save button (for tile mappings) calls `ResourceSaver.save(tile_mappings, MAPPINGS_PATH)`. Individual editors call their registry's `save_data()` directly. Both fire `dirty_changed(false)` after saving to clear the dirty indicator in the tree.
```

- [ ] **Commit**

```bash
git add docs/skills/game4-dungeon-type.md docs/skills/game4-game-editor.md
git commit -m "docs: update game4-dungeon-type skill and add game4-game-editor skill"
```

---

## Task 18: Update copilot-instructions.md

**Files:**
- Modify: `.github/copilot-instructions.md`

- [ ] **Add labyrinth system documentation to the instructions**

In `.github/copilot-instructions.md`, find the section "## Autoloads (load order)" or near the dungeon description. Add a new section:

```markdown
## Labyrinth System

A second interior type (`&"labyrinth"`) alongside the BSP dungeon. Gauntlet-style Prim's maze with 2-4 tile wide corridors.

### Key classes
- `LabyrinthGenerator` (`scripts/world/labyrinth_generator.gd`) — Prim's maze generator. `generate(seed, w, h, floor_num)`. Boss room on `floor_num % boss_interval == 0`. Dead-end junctions → `chest_scatter`.
- `TreasureChest` (`scripts/entities/treasure_chest.gd`) — Interactive chest. Player presses `p*_interact` when in range. Rolls loot via `ChestLootRegistry`, spawns `LootPickup` nodes. Stays in world as open sprite after looting.
- `EncounterTableRegistry` (`scripts/data/encounter_table_registry.gd`) — Depth-scaled enemy tables. `get_weighted_list(dungeon_type, floor_num)`, `get_boss_interval(dungeon_type)`. Editable in GameEditor → "Encounter Tables (Depth)".
- `ChestLootRegistry` (`scripts/data/chest_loot_registry.gd`) — Depth-tiered chest loot. `roll_loot(floor_num, rng)`. Editable in GameEditor → "Chest Loot (Depth Tiers)".

### Labyrinth entrances
- Overworld: auto-placed (~35% of land regions) in `WorldGenerator._place_labyrinth_entrances()`. Purple tint on the entrance marker.
- F9 debug: spawns a labyrinth entrance at `(4, 0)` offset from player (right of house entrance).

### Boss floors
- Every `boss_interval` floors (default 5, configurable per dungeon type in `encounter_tables.json`).
- Boss creature: entry in `creature_sprites.json` with `"is_boss": true` and `"boss_adds": [{creature, count}]`.
- Editable via GameEditor → "Creatures" → boss section.
```

- [ ] **Commit**

```bash
git add .github/copilot-instructions.md
git commit -m "docs: document labyrinth system in copilot-instructions.md"
```

---

## Final Verification

- [ ] **Run full test suite**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -10
```

Expected: all tests pass (unit + integration).

- [ ] **Launch game and smoke test F9**

```bash
./run.sh
```

Press F9 in-game. Verify three entrance markers appear (dungeon white, house yellow, labyrinth purple). Step into the labyrinth entrance. Verify floor 1 loads. Descend to floor 2. Verify chests appear at dead ends (press E near one). Descend to floor 5. Verify boss and adds are present.

- [ ] **Open GameEditor and verify new panels**

```bash
godot res://scenes/tools/GameEditor.tscn
```

Verify: "Encounter Tables (Depth)", "Chest Loot (Depth Tiers)", and "Labyrinth entrance marker pair" all appear in the tree. Edit a value, save, reload — verify the JSON file updated.

---

## Completion

Once all tasks are checked and tests pass, follow the **finishing-a-development-branch** skill to merge or create a PR.
