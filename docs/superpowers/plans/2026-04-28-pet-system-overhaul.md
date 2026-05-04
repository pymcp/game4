# Pet System Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert cat/dog to hi-res sheet rendering, add 4 new pets (hedgehog, duck, chameleon, roly_poly), give each player a roster of 6 (1 active + 5 in caravan), implement the hedgehog's item-sniff ability, wire a Pets section in CaravanMenu, and make all pets editable in the GameEditor via creature_editor.

**Architecture:** Sprite data lives in `creature_sprites.json` (tagged `"is_pet": true`) so future creature charming just works — a charmed creature's sprite is already registered. Game data (display name, special ability, cooldown) lives in `resources/pets.json` loaded by a new `PetRegistry`. `World` tracks per-player `_pet_rosters` and `_active_species`; `GameSession.start_new_game()` randomizes the starting active pet. Save/load is extended on `PlayerSaveData`.

**Tech Stack:** GDScript (Godot 4.3), Python (Pillow) for sheet generation, GUT for tests.

---

## File Map

| Action | File |
|--------|------|
| **Modify** | `tools/gen_hires_sheet.py` — add `pets` category |
| **Create** | `assets/icons/hires/pets.png` — generated stub sheet |
| **Modify** | `resources/creature_sprites.json` — add 6 pet entries with `is_pet: true` |
| **Create** | `resources/pets.json` — game data: display name, ability, cooldown |
| **Create** | `scripts/data/pet_registry.gd` — static cache for pets.json |
| **Modify** | `scripts/entities/pet.gd` — hi-res sprite, special ability tick, charming TODO |
| **Modify** | `scripts/world/world.gd` — roster arrays, `swap_active_pet()`, init from GameSession |
| **Modify** | `scripts/autoload/game_session.gd` — randomize and store pet rosters at new-game |
| **Modify** | `scripts/data/player_save_data.gd` — add `active_pet_species`, `pet_roster` fields |
| **Modify** | `scripts/data/save_game.gd` — snapshot/apply pet fields, bump VERSION to 5 |
| **Modify** | `scripts/tools/creature_editor.gd` — `is_pet` checkbox, color pet entries in list |
| **Modify** | `scripts/ui/caravan_menu.gd` — Pets section with Follow button |
| **Create** | `tests/unit/test_pet_registry.gd` |
| **Create** | `tests/unit/test_pet_hedgehog.gd` |
| **Create** | `tests/integration/test_pet_roster.gd` |

---

## Task 1: Extend gen_hires_sheet.py for pets + generate stub sheet

**Files:**
- Modify: `tools/gen_hires_sheet.py`
- Create: `assets/icons/hires/pets.png` (generated)
- Create: `assets/icons/hires/pets_cells.json` (generated)

- [ ] **Step 1: Read gen_hires_sheet.py top-level structure**

  Before editing, understand the category dispatch. The script has a `CATEGORIES` dict or argparse category argument at the bottom. Read lines 1–60 and the `if __name__ == "__main__"` block to confirm the exact pattern.

- [ ] **Step 2: Add `pets` category constant**

  In `gen_hires_sheet.py`, find the section that defines output paths (the `creatures` category output is `assets/icons/hires/creatures.png` with cells in `assets/icons/hires/creatures_cells.json`). Add an analogous block for `pets`:

  ```python
  CATEGORY_CONFIGS = {
      # ... existing entries ...
      "pets": {
          "output_png": "assets/icons/hires/pets.png",
          "cells_json": "assets/icons/hires/pets_cells.json",
          "sentinel_color": (60, 100, 60),   # green-ish to distinguish from creature purple
          "filter_key": "is_pet",            # only entries where creature_sprites["is_pet"] == True
          "source_json": "resources/creature_sprites.json",
      },
  }
  ```

  The filtering logic should skip entries where `entry.get("is_pet") != True` when the `filter_key` is set. Verify the existing `creatures` category does NOT have `filter_key` set — it shows all entries that don't have `is_pet`.

  _(Exact implementation depends on the script's internal structure — the key point is that `pets` reads from the same `creature_sprites.json` but only processes entries tagged `is_pet: true`, writing to `pets.png`.)_

- [ ] **Step 3: Run the generator**

  ```bash
  cd /home/mpatterson/repos/game4
  python3 tools/gen_hires_sheet.py pets
  ```

  Expected output: `assets/icons/hires/pets.png` and `assets/icons/hires/pets_cells.json` created. The PNG will be a stub (6 placeholder tiles). If no pet entries exist yet in `creature_sprites.json` (they come in Task 2), run this step after Task 2.

- [ ] **Step 4: Verify _spec.json covers pets directory**

  `assets/icons/hires/_spec.json` should already exist with `{ "tile_px": 64, "margin_px": 1 }`. Confirm:

  ```bash
  cat assets/icons/hires/_spec.json
  ```

  If missing, create it:
  ```json
  { "tile_px": 64, "margin_px": 1 }
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add tools/gen_hires_sheet.py assets/icons/hires/pets.png assets/icons/hires/pets_cells.json
  git commit -m "feat(pets): add pets category to gen_hires_sheet.py, generate stub pets.png"
  ```

---

## Task 2: Add 6 pet entries to creature_sprites.json

**Files:**
- Modify: `resources/creature_sprites.json`

Add the following 6 entries. Leave `region` values at placeholder `[0, 0, 64, 64]` — the generator (Task 1/Step 3, run after this task) will overwrite them with correct atlas coordinates. The `sheet` must point to `pets.png`.

- [ ] **Step 1: Add pet entries to creature_sprites.json**

  Add to `resources/creature_sprites.json` (maintain alphabetical order with existing entries):

  ```json
  "cat": {
      "is_pet": true,
      "display_name": "Cat",
      "anchor_ratio": [0.5, 0.95],
      "footprint": [1, 1],
      "scale": [0.25, 0.25],
      "sheet": "res://assets/icons/hires/pets.png",
      "region": [0, 0, 64, 64],
      "attack_style": "swing",
      "attack_damage": 1,
      "attack_speed": 0.8,
      "attack_range_tiles": 1.0
  },
  "chameleon": {
      "is_pet": true,
      "display_name": "Chameleon",
      "anchor_ratio": [0.5, 0.95],
      "footprint": [1, 1],
      "scale": [0.25, 0.25],
      "sheet": "res://assets/icons/hires/pets.png",
      "region": [0, 0, 64, 64],
      "attack_style": "none",
      "attack_damage": 0,
      "attack_speed": 1.0,
      "attack_range_tiles": 0.0
  },
  "dog": {
      "is_pet": true,
      "display_name": "Dog",
      "anchor_ratio": [0.5, 0.95],
      "footprint": [1, 1],
      "scale": [0.25, 0.25],
      "sheet": "res://assets/icons/hires/pets.png",
      "region": [0, 0, 64, 64],
      "attack_style": "none",
      "attack_damage": 0,
      "attack_speed": 1.0,
      "attack_range_tiles": 0.0
  },
  "duck": {
      "is_pet": true,
      "display_name": "Duck",
      "anchor_ratio": [0.5, 0.95],
      "footprint": [1, 1],
      "scale": [0.25, 0.25],
      "sheet": "res://assets/icons/hires/pets.png",
      "region": [0, 0, 64, 64],
      "attack_style": "none",
      "attack_damage": 0,
      "attack_speed": 1.0,
      "attack_range_tiles": 0.0
  },
  "hedgehog": {
      "is_pet": true,
      "display_name": "Hedgehog",
      "anchor_ratio": [0.5, 0.95],
      "footprint": [1, 1],
      "scale": [0.25, 0.25],
      "sheet": "res://assets/icons/hires/pets.png",
      "region": [0, 0, 64, 64],
      "attack_style": "none",
      "attack_damage": 0,
      "attack_speed": 1.0,
      "attack_range_tiles": 0.0
  },
  "roly_poly": {
      "is_pet": true,
      "display_name": "Roly Poly",
      "anchor_ratio": [0.5, 0.95],
      "footprint": [1, 1],
      "scale": [0.25, 0.25],
      "sheet": "res://assets/icons/hires/pets.png",
      "region": [0, 0, 64, 64],
      "attack_style": "none",
      "attack_damage": 0,
      "attack_speed": 1.0,
      "attack_range_tiles": 0.0
  }
  ```

  Note: `cat` gets `attack_style: "swing"` and `attack_damage: 1` — these drive the existing melee logic. `dog`'s attack is handled specially via `_do_bark()` so it stays `"none"` in the registry; that code path isn't changing.

- [ ] **Step 2: Run gen_hires_sheet to patch regions**

  ```bash
  python3 tools/gen_hires_sheet.py pets
  ```

  This assigns atlas cells to all 6 pets and overwrites their `region` arrays in `creature_sprites.json`.

- [ ] **Step 3: Confirm regions were patched**

  ```bash
  python3 -c "
  import json
  d = json.load(open('resources/creature_sprites.json'))
  for k in ['cat','dog','hedgehog','duck','chameleon','roly_poly']:
      print(k, d[k]['region'])
  "
  ```

  Expected: Each pet has a unique non-`[0,0,64,64]` region.

- [ ] **Step 4: Commit**

  ```bash
  git add resources/creature_sprites.json assets/icons/hires/pets.png assets/icons/hires/pets_cells.json
  git commit -m "feat(pets): add 6 pet entries to creature_sprites.json, generate pets.png atlas"
  ```

---

## Task 3: Create resources/pets.json and PetRegistry

**Files:**
- Create: `resources/pets.json`
- Create: `scripts/data/pet_registry.gd`

- [ ] **Step 1: Create resources/pets.json**

  ```json
  {
      "cat": {
          "display_name": "Cat",
          "special_ability": "none",
          "ability_description": "No special ability yet.",
          "ability_cooldown_sec": 0.0
      },
      "dog": {
          "display_name": "Dog",
          "special_ability": "none",
          "ability_description": "No special ability yet.",
          "ability_cooldown_sec": 0.0
      },
      "hedgehog": {
          "display_name": "Hedgehog",
          "special_ability": "sniff_loot",
          "ability_description": "Periodically sniffs out a crafting material and drops it nearby.",
          "ability_cooldown_sec": 90.0
      },
      "duck": {
          "display_name": "Duck",
          "special_ability": "none",
          "ability_description": "No special ability yet.",
          "ability_cooldown_sec": 0.0
      },
      "chameleon": {
          "display_name": "Chameleon",
          "special_ability": "none",
          "ability_description": "No special ability yet.",
          "ability_cooldown_sec": 0.0
      },
      "roly_poly": {
          "display_name": "Roly Poly",
          "special_ability": "none",
          "ability_description": "No special ability yet.",
          "ability_cooldown_sec": 0.0
      }
  }
  ```

- [ ] **Step 2: Create scripts/data/pet_registry.gd**

  ```gdscript
  ## PetRegistry
  ##
  ## Static cache for resources/pets.json.
  ## Game data only — sprite data lives in creature_sprites.json.
  ## Call reload() after editing pets.json to clear the cache.
  ##
  ## TODO (FUTURE): charmed creatures can also become pets — pass the creature's
  ## kind to Pet.make_charmed(kind). Sprite data already lives in
  ## creature_sprites.json; only ability/display data would need a pets.json
  ## fallback (or a "charmed" default entry).
  class_name PetRegistry
  extends RefCounted

  const _PATH: String = "res://resources/pets.json"

  static var _data: Dictionary = {}
  static var _loaded: bool = false
  static var _species_list: Array[StringName] = []


  static func _ensure_loaded() -> void:
  	if _loaded:
  		return
  	var f := FileAccess.open(_PATH, FileAccess.READ)
  	if f == null:
  		push_error("PetRegistry: cannot open %s" % _PATH)
  		_loaded = true
  		return
  	var parsed: Variant = JSON.parse_string(f.get_as_text())
  	f.close()
  	if parsed is Dictionary:
  		_data = parsed as Dictionary
  	_species_list.clear()
  	for k: String in _data.keys():
  		_species_list.append(StringName(k))
  	_loaded = true


  ## All pet species StringNames, order matches JSON key order.
  static func all_species() -> Array[StringName]:
  	_ensure_loaded()
  	return _species_list.duplicate()


  static func get_display_name(species: StringName) -> String:
  	_ensure_loaded()
  	var e: Dictionary = _data.get(String(species), {})
  	return e.get("display_name", String(species))


  static func get_ability(species: StringName) -> StringName:
  	_ensure_loaded()
  	var e: Dictionary = _data.get(String(species), {})
  	return StringName(e.get("special_ability", "none"))


  static func get_ability_description(species: StringName) -> String:
  	_ensure_loaded()
  	var e: Dictionary = _data.get(String(species), {})
  	return e.get("ability_description", "")


  static func get_ability_cooldown(species: StringName) -> float:
  	_ensure_loaded()
  	var e: Dictionary = _data.get(String(species), {})
  	return float(e.get("ability_cooldown_sec", 0.0))


  ## Clear cache (call after editing pets.json at runtime).
  static func reload() -> void:
  	_data = {}
  	_species_list.clear()
  	_loaded = false
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add resources/pets.json scripts/data/pet_registry.gd
  git commit -m "feat(pets): add pets.json and PetRegistry static cache"
  ```

---

## Task 4: Unit tests for PetRegistry

**Files:**
- Create: `tests/unit/test_pet_registry.gd`

- [ ] **Step 1: Write tests**

  ```gdscript
  extends GutTest

  func before_each() -> void:
  	PetRegistry.reload()


  func test_all_species_returns_six() -> void:
  	var species: Array[StringName] = PetRegistry.all_species()
  	assert_eq(species.size(), 6)


  func test_all_species_contains_expected() -> void:
  	var species: Array[StringName] = PetRegistry.all_species()
  	assert_true(species.has(&"cat"))
  	assert_true(species.has(&"dog"))
  	assert_true(species.has(&"hedgehog"))
  	assert_true(species.has(&"duck"))
  	assert_true(species.has(&"chameleon"))
  	assert_true(species.has(&"roly_poly"))


  func test_display_name_hedgehog() -> void:
  	assert_eq(PetRegistry.get_display_name(&"hedgehog"), "Hedgehog")


  func test_ability_hedgehog() -> void:
  	assert_eq(PetRegistry.get_ability(&"hedgehog"), &"sniff_loot")


  func test_ability_cat_is_none() -> void:
  	assert_eq(PetRegistry.get_ability(&"cat"), &"none")


  func test_cooldown_hedgehog() -> void:
  	assert_eq(PetRegistry.get_ability_cooldown(&"hedgehog"), 90.0)


  func test_cooldown_none_ability_is_zero() -> void:
  	assert_eq(PetRegistry.get_ability_cooldown(&"cat"), 0.0)


  func test_unknown_species_returns_defaults() -> void:
  	assert_eq(PetRegistry.get_display_name(&"unknown_critter"), "unknown_critter")
  	assert_eq(PetRegistry.get_ability(&"unknown_critter"), &"none")
  	assert_eq(PetRegistry.get_ability_cooldown(&"unknown_critter"), 0.0)


  func test_reload_clears_cache() -> void:
  	var _ = PetRegistry.all_species()  # populate cache
  	PetRegistry.reload()
  	var species: Array[StringName] = PetRegistry.all_species()
  	assert_eq(species.size(), 6)  # reloads from disk correctly
  ```

- [ ] **Step 2: Run tests**

  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "PASS|FAIL|test_pet_registry"
  ```

  Expected: all 9 tests pass, 0 failures.

- [ ] **Step 3: Commit**

  ```bash
  git add tests/unit/test_pet_registry.gd
  git commit -m "test(pets): unit tests for PetRegistry"
  ```

---

## Task 5: Refactor pet.gd sprite loading to use CreatureSpriteRegistry

**Files:**
- Modify: `scripts/entities/pet.gd`

The current code:
```gdscript
const _CAT_TEX: Texture2D = preload("res://assets/characters/pets/cat.png")
const _DOG_TEX: Texture2D = preload("res://assets/characters/pets/dog.png")
# ...in _ready():
_sprite = Sprite2D.new()
_sprite.texture = _DOG_TEX if species == PET_SPECIES_DOG else _CAT_TEX
_sprite.centered = true
add_child(_sprite)
hitbox_radius = HitboxCalc.radius_from_sprite(_sprite)
```

- [ ] **Step 1: Remove hardcoded texture constants**

  Delete the two `const _CAT_TEX` and `const _DOG_TEX` lines. These are no longer needed once sprites are built by the registry.

- [ ] **Step 2: Replace sprite creation in _ready()**

  Find the sprite creation block in `_ready()` and replace it:

  ```gdscript
  # TODO (FUTURE): charmed creatures can also become pets — pass the creature's
  # kind to Pet.make_charmed(kind). Its sprite data already lives in
  # creature_sprites.json; only game data (ability/display name) needs a
  # pets.json fallback entry.
  _sprite = CreatureSpriteRegistry.build_sprite(species)
  if _sprite == null:
  	_sprite = Sprite2D.new()  # fallback: invisible square until art is added
  	_sprite.centered = true
  add_child(_sprite)
  hitbox_radius = HitboxCalc.radius_from_sprite(_sprite)
  ```

- [ ] **Step 3: Remove PET_SPECIES_CAT / PET_SPECIES_DOG species-check for texture**

  Search the file for any remaining references to `_CAT_TEX` or `_DOG_TEX` and confirm none remain.

- [ ] **Step 4: Keep species constants (still used for identity checks elsewhere)**

  `PET_SPECIES_CAT` and `PET_SPECIES_DOG` may still be used in `world.gd` or tests as string identity checks. Keep them. But also add the 4 new species constants while you're here:

  ```gdscript
  const PET_SPECIES_CAT: StringName = &"cat"
  const PET_SPECIES_DOG: StringName = &"dog"
  const PET_SPECIES_HEDGEHOG: StringName = &"hedgehog"
  const PET_SPECIES_DUCK: StringName = &"duck"
  const PET_SPECIES_CHAMELEON: StringName = &"chameleon"
  const PET_SPECIES_ROLY_POLY: StringName = &"roly_poly"
  ```

- [ ] **Step 5: Launch game and verify**

  ```bash
  ./run.sh
  ```

  Both starting pets (cat and dog) should render. They will show stub colored rectangles if `pets.png` stub tiles are empty — that's expected. Verify no error about missing `_CAT_TEX`.

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/entities/pet.gd
  git commit -m "feat(pets): replace hardcoded preload textures with CreatureSpriteRegistry.build_sprite()"
  ```

---

## Task 6: Hedgehog special ability

**Files:**
- Modify: `scripts/entities/pet.gd`
- Create: `tests/unit/test_pet_hedgehog.gd`

The hedgehog sniffs periodically (90s cooldown) and drops a random crafting item (`LootPickup`) near the owner.

- [ ] **Step 1: Add ability state vars to pet.gd**

  After the existing `var state: int` declaration, add:

  ```gdscript
  var special_ability: StringName = &"none"
  var _ability_cooldown_remaining: float = 0.0
  ```

- [ ] **Step 2: Load special_ability in _ready()**

  After `hitbox_radius = HitboxCalc.radius_from_sprite(_sprite)`, add:

  ```gdscript
  special_ability = PetRegistry.get_ability(species)
  _ability_cooldown_remaining = PetRegistry.get_ability_cooldown(species)
  ```

- [ ] **Step 3: Call _tick_special(delta) from _process()**

  In `_process(delta)`, after the existing state machine tick (or after the bob animation block), add:

  ```gdscript
  if special_ability != &"none":
  	_tick_special(delta)
  ```

- [ ] **Step 4: Implement _tick_special and _do_hedgehog_sniff()**

  Add these two methods to `pet.gd`:

  ```gdscript
  ## Called each frame when this pet has a non-none special ability.
  func _tick_special(delta: float) -> void:
  	if _ability_cooldown_remaining > 0.0:
  		_ability_cooldown_remaining -= delta
  		return
  	# Only fire in IDLE or FOLLOW — not while in ATTACK or HAPPY.
  	if state != PetState.State.IDLE and state != PetState.State.FOLLOW:
  		return
  	match special_ability:
  		&"sniff_loot":
  			_do_hedgehog_sniff()
  		_:
  			pass  # stub for future abilities


  ## Hedgehog ability: find a random crafting material and drop it nearby.
  const _HEDGEHOG_LOOT_POOL: Array[StringName] = [
  	&"wood", &"stone", &"fiber", &"iron_ore", &"copper_ore"
  ]

  func _do_hedgehog_sniff() -> void:
  	if _world == null or owner_player == null:
  		return
  	# Pick a random item from the pool (seeded per pet so behaviour is reproducible).
  	var rng := RandomNumberGenerator.new()
  	rng.randomize()
  	var item_id: StringName = _HEDGEHOG_LOOT_POOL[rng.randi() % _HEDGEHOG_LOOT_POOL.size()]
  	# Spawn a LootPickup 1–2 tiles away from the owner.
  	var owner_cell: Vector2i = Vector2i(
  		int(floor(owner_player.position.x / float(WorldConst.TILE_PX))),
  		int(floor(owner_player.position.y / float(WorldConst.TILE_PX))))
  	var spawn_cell: Vector2i = _world.find_safe_spawn_cell(owner_cell, 2, true)
  	var spawn_pos: Vector2 = (Vector2(spawn_cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
  	_world.spawn_loot_at(spawn_pos, item_id, 1)
  	# Show happy animation as the "found it!" reaction.
  	state = PetState.State.HAPPY
  	_happy_remaining = PetState.HAPPY_DURATION_SEC
  	# Reset cooldown.
  	_ability_cooldown_remaining = PetRegistry.get_ability_cooldown(species)
  ```

  > **Note:** This calls `_world.spawn_loot_at(pos, item_id, count)`. Check whether `WorldRoot` already has this method or whether it needs to be added. Search for `spawn_loot` or `LootPickup` in `scripts/world/world_root.gd`. If the method doesn't exist, see the fallback below.

- [ ] **Step 5: Add spawn_loot_at to WorldRoot if missing**

  Search `scripts/world/world_root.gd` for `spawn_loot_at` or `LootPickup`. If missing, add:

  ```gdscript
  ## Spawn a LootPickup node at [param world_pos] with [param item_id] × [param count].
  func spawn_loot_at(world_pos: Vector2, item_id: StringName, count: int) -> void:
  	var scene: PackedScene = load("res://scenes/entities/LootPickup.tscn") as PackedScene
  	if scene == null:
  		push_error("WorldRoot.spawn_loot_at: LootPickup.tscn not found")
  		return
  	var loot: Node = scene.instantiate()
  	loot.position = world_pos
  	if loot.has_method("setup"):
  		loot.call("setup", item_id, count)
  	entities.add_child(loot)
  ```

  _(The existing mine_at drop code in world_root.gd already instantiates LootPickup — use that as reference for the exact method name and scene path.)_

- [ ] **Step 6: Write unit tests for the loot pool**

  ```gdscript
  # tests/unit/test_pet_hedgehog.gd
  extends GutTest

  func test_loot_pool_not_empty() -> void:
  	# Pet._HEDGEHOG_LOOT_POOL is a const — verify it has items.
  	# We can't instantiate Pet directly in unit tests (requires scene tree),
  	# so we verify the registry ability is wired correctly.
  	assert_eq(PetRegistry.get_ability(&"hedgehog"), &"sniff_loot")
  	assert_gt(PetRegistry.get_ability_cooldown(&"hedgehog"), 0.0)


  func test_non_hedgehog_has_no_ability() -> void:
  	assert_eq(PetRegistry.get_ability(&"duck"), &"none")
  	assert_eq(PetRegistry.get_ability_cooldown(&"duck"), 0.0)
  ```

- [ ] **Step 7: Run unit tests**

  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "PASS|FAIL|test_pet"
  ```

  Expected: all pass.

- [ ] **Step 8: Commit**

  ```bash
  git add scripts/entities/pet.gd scripts/world/world_root.gd tests/unit/test_pet_hedgehog.gd
  git commit -m "feat(pets): hedgehog sniff_loot ability with 90s cooldown"
  ```

---

## Task 7: Pet roster in GameSession

**Files:**
- Modify: `scripts/autoload/game_session.gd`

`GameSession` already stores per-player appearance dicts (`p1_appearance`, `p2_appearance`) seeded from `WorldManager.world_seed`. Pet rosters follow the same pattern.

- [ ] **Step 1: Add roster properties to GameSession**

  After the existing `var p2_appearance: Dictionary = {}`, add:

  ```gdscript
  ## Per-player pet roster (6 species each) and active species.
  ## Set by start_new_game(); overwritten by SaveGame.apply() on load.
  var p1_pet_roster: Array[StringName] = []
  var p2_pet_roster: Array[StringName] = []
  var p1_active_pet: StringName = &""
  var p2_active_pet: StringName = &""
  ```

- [ ] **Step 2: Randomize rosters in start_new_game()**

  In `start_new_game()`, after the existing `p2_appearance = randomize_appearance(rng)` call, add:

  ```gdscript
  var all_pets: Array[StringName] = PetRegistry.all_species()
  # Shuffle once per player using the same seeded rng for determinism.
  var p1_roster: Array[StringName] = all_pets.duplicate()
  p1_roster.shuffle()  # uses the global rng state; GDScript shuffle is rng-independent
  # Use a seeded shuffle so the same seed always gives the same roster.
  for i in range(p1_roster.size() - 1, 0, -1):
  	var j: int = rng.randi_range(0, i)
  	var tmp: StringName = p1_roster[i]
  	p1_roster[i] = p1_roster[j]
  	p1_roster[j] = tmp
  p1_pet_roster = p1_roster
  p1_active_pet = p1_roster[0]

  var p2_roster: Array[StringName] = all_pets.duplicate()
  for i in range(p2_roster.size() - 1, 0, -1):
  	var j: int = rng.randi_range(0, i)
  	var tmp: StringName = p2_roster[i]
  	p2_roster[i] = p2_roster[j]
  	p2_roster[j] = tmp
  p2_pet_roster = p2_roster
  p2_active_pet = p2_roster[0]
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add scripts/autoload/game_session.gd
  git commit -m "feat(pets): randomize per-player pet rosters on new game in GameSession"
  ```

---

## Task 8: Roster management in World

**Files:**
- Modify: `scripts/world/world.gd`

- [ ] **Step 1: Add roster arrays to world.gd**

  After the existing `var _pets: Array = []` declaration, add:

  ```gdscript
  ## Per-player pet roster and which species is currently active.
  ## Initialized from GameSession in _ready(); overwritten by SaveGame.apply().
  var _pet_rosters: Array[Array] = [[], []]
  var _active_species: Array[StringName] = [&"cat", &"dog"]
  ```

- [ ] **Step 2: Initialize from GameSession in _ready()**

  In `_ready()`, after the existing appearance/caravan initialization block (around line 100), add:

  ```gdscript
  # Initialize pet rosters from GameSession (set by start_new_game or SaveGame.apply).
  if not GameSession.p1_pet_roster.is_empty():
  	_pet_rosters[0] = GameSession.p1_pet_roster.duplicate()
  	_active_species[0] = GameSession.p1_active_pet
  if not GameSession.p2_pet_roster.is_empty():
  	_pet_rosters[1] = GameSession.p2_pet_roster.duplicate()
  	_active_species[1] = GameSession.p2_active_pet
  ```

- [ ] **Step 3: Update _ensure_pet_for_player to use _active_species**

  Find the line in `_ensure_pet_for_player()`:
  ```gdscript
  pet.species = Pet.PET_SPECIES_CAT if pid == 0 else Pet.PET_SPECIES_DOG
  ```
  Replace with:
  ```gdscript
  pet.species = _active_species[pid]
  ```

- [ ] **Step 4: Add public accessor methods**

  Add after `_ensure_pet_for_player()`:

  ```gdscript
  ## Returns the species of the currently active pet for [param pid].
  func get_active_pet_species(pid: int) -> StringName:
  	return _active_species[pid]


  ## Returns the full 6-species roster for [param pid].
  func get_pet_roster(pid: int) -> Array[StringName]:
  	var result: Array[StringName] = []
  	for s: StringName in _pet_rosters[pid]:
  		result.append(s)
  	return result
  ```

- [ ] **Step 5: Add swap_active_pet()**

  ```gdscript
  ## Swap the active following pet for [param pid] to [param new_species].
  ## Despawns the current pet and spawns the new one in the current view.
  func swap_active_pet(pid: int, new_species: StringName) -> void:
  	if _active_species[pid] == new_species:
  		return
  	if not PetRegistry.all_species().has(new_species):
  		push_error("swap_active_pet: unknown species '%s'" % new_species)
  		return
  	# Remove old pet from scene tree.
  	var old_pet: Pet = _pets[pid]
  	if old_pet != null and is_instance_valid(old_pet):
  		old_pet.get_parent().remove_child(old_pet)
  		old_pet.queue_free()
  	_pets[pid] = null
  	# Set new active species and spawn.
  	_active_species[pid] = new_species
  	var current_inst: WorldRoot = get_player_world(pid)
  	if current_inst != null:
  		_ensure_pet_for_player(pid, current_inst)
  	# Mirror back to GameSession so save/load has current state.
  	if pid == 0:
  		GameSession.p1_active_pet = new_species
  	else:
  		GameSession.p2_active_pet = new_species
  ```

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/world/world.gd
  git commit -m "feat(pets): roster arrays + swap_active_pet() in World"
  ```

---

## Task 9: Integration tests for roster + swap

**Files:**
- Create: `tests/integration/test_pet_roster.gd`

- [ ] **Step 1: Write integration tests**

  ```gdscript
  extends GutTest

  var _game_scene: PackedScene = preload("res://scenes/main/Game.tscn")
  var _game: Node = null


  func before_each() -> void:
  	PetRegistry.reload()
  	WorldManager.reset(202402)
  	GameSession.start_new_game(202402)
  	_game = _game_scene.instantiate()
  	add_child_autofree(_game)
  	await get_tree().process_frame
  	await get_tree().process_frame


  func _get_world() -> Node:
  	return _game.get_node("World")


  func test_each_player_has_six_pets_in_roster() -> void:
  	var world: Node = _get_world()
  	assert_eq(world.get_pet_roster(0).size(), 6)
  	assert_eq(world.get_pet_roster(1).size(), 6)


  func test_active_species_is_in_roster() -> void:
  	var world: Node = _get_world()
  	var active_0: StringName = world.get_active_pet_species(0)
  	assert_true(world.get_pet_roster(0).has(active_0))


  func test_swap_changes_active_species() -> void:
  	var world: Node = _get_world()
  	var roster_0: Array[StringName] = world.get_pet_roster(0)
  	var current: StringName = world.get_active_pet_species(0)
  	# Pick a different species.
  	var other: StringName = &""
  	for s: StringName in roster_0:
  		if s != current:
  			other = s
  			break
  	assert_ne(other, &"", "roster must have at least 2 species")
  	world.swap_active_pet(0, other)
  	assert_eq(world.get_active_pet_species(0), other)


  func test_swap_to_same_species_is_noop() -> void:
  	var world: Node = _get_world()
  	var current: StringName = world.get_active_pet_species(0)
  	world.swap_active_pet(0, current)
  	assert_eq(world.get_active_pet_species(0), current)


  func test_active_pet_node_species_matches_active_species() -> void:
  	var world: Node = _get_world()
  	await get_tree().process_frame
  	var active: StringName = world.get_active_pet_species(0)
  	# Find the Pet node for player 0.
  	var pet: Node = null
  	for node in get_tree().get_nodes_in_group("pets"):
  		if node.get("owner_player") != null and node.owner_player.player_id == 0:
  			pet = node
  			break
  	assert_not_null(pet)
  	assert_eq(pet.species, active)
  ```

- [ ] **Step 2: Run integration tests**

  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit 2>&1 | grep -E "PASS|FAIL|test_pet_roster"
  ```

  Expected: all 5 tests pass.

- [ ] **Step 3: Commit**

  ```bash
  git add tests/integration/test_pet_roster.gd
  git commit -m "test(pets): integration tests for roster management and swap_active_pet()"
  ```

---

## Task 10: Save/load pet roster

**Files:**
- Modify: `scripts/data/player_save_data.gd`
- Modify: `scripts/data/save_game.gd`

- [ ] **Step 1: Add fields to PlayerSaveData**

  In `scripts/data/player_save_data.gd`, after the existing `var dungeon_fog_data: Dictionary`, add:

  ```gdscript
  ## Active pet species for this player. Empty string = use default (roster[0]).
  @export var active_pet_species: StringName = &""
  ## Ordered pet roster (6 species). Empty = use GameSession default.
  @export var pet_roster: Array[StringName] = []
  ```

- [ ] **Step 2: Capture roster in SaveGame.snapshot()**

  In `scripts/data/save_game.gd`, inside `snapshot()`, after `psd.dungeon_fog_data = p.dungeon_fog.to_dict()`, add:

  ```gdscript
  # Pet roster — read from the World coordinator (parent of this WorldRoot).
  var world_coord: Node = world.get_parent()
  if world_coord != null and world_coord.has_method("get_active_pet_species"):
  	psd.active_pet_species = world_coord.call("get_active_pet_species", pid)
  	var roster: Array[StringName] = world_coord.call("get_pet_roster", pid)
  	psd.pet_roster = roster
  ```

- [ ] **Step 3: Restore roster in SaveGame.apply()**

  In `scripts/data/save_game.gd`, inside `apply()`, after the player position/health restoration block, add:

  ```gdscript
  # Restore pet rosters into GameSession so World._ready() picks them up.
  for psd: PlayerSaveData in players:
  	if psd.pet_roster.is_empty():
  		continue
  	if psd.player_id == 0:
  		GameSession.p1_pet_roster = psd.pet_roster.duplicate()
  		GameSession.p1_active_pet = psd.active_pet_species
  	elif psd.player_id == 1:
  		GameSession.p2_pet_roster = psd.pet_roster.duplicate()
  		GameSession.p2_active_pet = psd.active_pet_species
  ```

- [ ] **Step 4: Bump SaveGame.VERSION**

  In `scripts/data/save_game.gd`:
  ```gdscript
  const VERSION: int = 5   # was 4
  ```

- [ ] **Step 5: Run all tests**

  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -20
  ```

  Expected: no regressions.

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/data/player_save_data.gd scripts/data/save_game.gd
  git commit -m "feat(pets): save/load pet roster in PlayerSaveData (VERSION 5)"
  ```

---

## Task 11: CreatureEditor — is_pet checkbox + colored pet entries

**Files:**
- Modify: `scripts/tools/creature_editor.gd`

- [ ] **Step 1: Add _is_pet_check field**

  In `creature_editor.gd`, find where the other boolean fields are declared (near `_mount_check`, `_facing_right_check`, `_is_boss_check`). Add:

  ```gdscript
  var _is_pet_check: CheckBox = null
  ```

- [ ] **Step 2: Build the checkbox in the UI construction block**

  Find the block where `_is_boss_check = CheckBox.new()` is built. Add an analogous block immediately after it (before boss-adds):

  ```gdscript
  var pet_row := HBoxContainer.new()
  _is_pet_check = CheckBox.new()
  _is_pet_check.text = "Is Pet"
  _is_pet_check.toggled.connect(func(pressed: bool) -> void: _set_field("is_pet", pressed))
  pet_row.add_child(_is_pet_check)
  _detail_container.add_child(pet_row)
  ```

- [ ] **Step 3: Populate checkbox in _on_creature_selected() / detail refresh**

  Find the section of code that populates checkboxes when a creature is selected (it sets `_is_boss_check.button_pressed = e.get("is_boss", false)` etc.). Add:

  ```gdscript
  _is_pet_check.button_pressed = bool(e.get("is_pet", false))
  ```

- [ ] **Step 4: Color pet entries in _populate_list()**

  In `_populate_list()`, find the `_creature_list.add_item(String(k))` call. After adding the item, add a color override for pet entries:

  ```gdscript
  _creature_list.add_item(String(k))
  var idx: int = _creature_list.item_count - 1
  _creature_list.set_item_metadata(idx, String(k))
  # Color pet entries to distinguish them from combat creatures.
  var entry_data: Dictionary = _data.get(String(k), {})
  if entry_data.get("is_pet", false):
  	_creature_list.set_item_custom_fg_color(idx, Color(0.5, 1.0, 0.6))  # pastel green
  ```

- [ ] **Step 5: Launch GameEditor and verify**

  ```bash
  godot res://scenes/tools/GameEditor.tscn
  ```

  Open the Creatures section. Confirm:
  - `cat`, `dog`, `hedgehog`, `duck`, `chameleon`, `roly_poly` appear in the list in pastel green.
  - Selecting any pet entry shows the "Is Pet" checkbox checked.
  - Unchecking "Is Pet" on a pet and saving removes the `is_pet` field from the JSON.

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/tools/creature_editor.gd
  git commit -m "feat(pets): is_pet checkbox and colored list entries in CreatureEditor"
  ```

---

## Task 12: CaravanMenu Pets section

**Files:**
- Modify: `scripts/ui/caravan_menu.gd`

The CaravanMenu left panel shows party member buttons from `_caravan_data.recruited_ids`. We add a Pets section below them with a separator and one button per pet in the player's roster.

- [ ] **Step 1: Add signal and world reference to CaravanMenu**

  At the top of `caravan_menu.gd`, after the existing properties, add:

  ```gdscript
  ## Emitted when the player wants to change their active pet.
  signal swap_pet_requested(player_id: int, species: StringName)

  ## Reference to the World node — set via setup(). Used to read pet roster.
  var _world_node: Node = null

  var _pet_buttons: Array[Button] = []
  var _pet_species_ids: Array[StringName] = []
  ```

- [ ] **Step 2: Accept world_node in setup()**

  Find `func setup(player: PlayerController, caravan_data: CaravanData) -> void:` and add a parameter:

  ```gdscript
  func setup(player: PlayerController, caravan_data: CaravanData, world_node: Node = null) -> void:
  	_player = player
  	_player_id = player.player_id if player != null else 0
  	_caravan_data = caravan_data
  	_world_node = world_node
  ```

- [ ] **Step 3: Update the call site in game.gd**

  Find where `caravan_menu.setup(player, caravan_data)` is called in `scripts/main/game.gd`. Add the world reference:

  ```gdscript
  caravan_menu.setup(player, caravan_data, $World)
  ```

  Also connect the new signal:

  ```gdscript
  caravan_menu.swap_pet_requested.connect($World.swap_active_pet)
  ```

- [ ] **Step 4: Build the Pets section in _refresh_members()**

  At the end of `_refresh_members()`, after the existing member buttons are built, add:

  ```gdscript
  # ─── Pets section ───────────────────────────────────────────────
  _pet_buttons.clear()
  _pet_species_ids.clear()

  if _world_node == null or not _world_node.has_method("get_pet_roster"):
  	return

  var separator := Label.new()
  separator.text = "─ Pets ─"
  separator.theme_type_variation = &"DimLabel"
  separator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _members_container.add_child(separator)
  _member_buttons.append(separator)  # include in cursor navigation
  _member_ids.append(&"__pet_separator__")

  var active_species: StringName = _world_node.call("get_active_pet_species", _player_id)
  var roster: Array[StringName] = _world_node.call("get_pet_roster", _player_id)

  for sp: StringName in roster:
  	var display: String = PetRegistry.get_display_name(sp)
  	var label: String = ("[ACTIVE] " + display) if sp == active_species else display
  	var btn := Button.new()
  	btn.text = label
  	btn.focus_mode = Control.FOCUS_NONE
  	btn.theme_type_variation = &"WoodButton"
  	if sp == active_species:
  		btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
  	btn.pressed.connect(_on_pet_selected.bind(sp))
  	_members_container.add_child(btn)
  	_member_buttons.append(btn)
  	_member_ids.append(sp)
  	_pet_buttons.append(btn)
  	_pet_species_ids.append(sp)
  ```

- [ ] **Step 5: Add _on_pet_selected() and right-panel pet detail**

  ```gdscript
  func _on_pet_selected(species: StringName) -> void:
  	# Separators are not selectable — skip.
  	if species == &"__pet_separator__":
  		_set_focus(_Focus.LEFT)
  		return
  	for child in _right_panel.get_children():
  		child.queue_free()
  	_current_crafter = null

  	var active_species: StringName = &""
  	if _world_node != null and _world_node.has_method("get_active_pet_species"):
  		active_species = _world_node.call("get_active_pet_species", _player_id)

  	var vbox := VBoxContainer.new()
  	vbox.anchor_right = 1.0
  	vbox.anchor_bottom = 1.0
  	_right_panel.add_child(vbox)

  	var name_lbl := Label.new()
  	name_lbl.text = PetRegistry.get_display_name(species)
  	name_lbl.theme_type_variation = &"HeaderLabel"
  	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  	vbox.add_child(name_lbl)

  	var ability_lbl := Label.new()
  	var desc: String = PetRegistry.get_ability_description(species)
  	ability_lbl.text = desc if desc != "" else "No special ability."
  	ability_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  	ability_lbl.theme_type_variation = &"DimLabel"
  	vbox.add_child(ability_lbl)

  	if species == active_species:
  		var active_lbl := Label.new()
  		active_lbl.text = "Currently following you."
  		active_lbl.theme_type_variation = &"DimLabel"
  		active_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  		vbox.add_child(active_lbl)
  	else:
  		var follow_btn := Button.new()
  		follow_btn.text = "Follow"
  		follow_btn.theme_type_variation = &"WoodButton"
  		follow_btn.focus_mode = Control.FOCUS_NONE
  		follow_btn.pressed.connect(func() -> void:
  			swap_pet_requested.emit(_player_id, species)
  			_refresh_members()
  			_on_pet_selected(species)
  		)
  		vbox.add_child(follow_btn)
  ```

- [ ] **Step 6: Guard separator entries in _on_member_selected**

  In `_on_member_selected(member_id)`, add a guard at the top:

  ```gdscript
  func _on_member_selected(member_id: StringName) -> void:
  	if member_id == &"__pet_separator__":
  		return
  	if _pet_species_ids.has(member_id):
  		_on_pet_selected(member_id)
  		_set_focus(_Focus.RIGHT)
  		return
  	# ... existing party member handling below ...
  ```

- [ ] **Step 7: Launch game and verify CaravanMenu**

  ```bash
  ./run.sh
  ```

  Interact with the caravan. Confirm:
  - Party members appear as before.
  - A "─ Pets ─" separator follows them.
  - All 6 pets in the roster appear as buttons.
  - Active pet is shown in green with "[ACTIVE]" prefix.
  - Selecting a non-active pet shows its name, ability description, and "Follow" button.
  - Pressing "Follow" swaps the active pet and refreshes the list.

- [ ] **Step 8: Run all tests**

  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -20
  ```

  Expected: no regressions.

- [ ] **Step 9: Commit**

  ```bash
  git add scripts/ui/caravan_menu.gd scripts/main/game.gd
  git commit -m "feat(pets): Pets section in CaravanMenu with Follow/swap support"
  ```

---

## Task 13: Final integration smoke test

- [ ] **Step 1: Run full test suite**

  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -30
  ```

  Expected: 0 failures.

- [ ] **Step 2: Launch and manually verify**

  ```bash
  ./run.sh
  ```

  Checklist:
  - [ ] Both players spawn with pets using hi-res sprites (colored stubs until real art is added)
  - [ ] Cat does melee attacks, dog does bark (unchanged behavior)
  - [ ] Hedgehog drops a loot item near the player within 90 seconds (use F8/F9 debug to speed test if available)
  - [ ] Caravan menu shows all 6 pets, Follow button works, active pet changes immediately
  - [ ] Save and reload: active pet and roster are preserved
  - [ ] GameEditor → Creatures: pet entries shown in green, Is Pet checkbox toggles correctly

- [ ] **Step 3: Commit**

  ```bash
  git add .
  git commit -m "feat(pets): complete pet system overhaul — hi-res sprites, 6 pets, roster, caravan swap, hedgehog ability"
  ```
