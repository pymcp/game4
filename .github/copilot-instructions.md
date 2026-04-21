## Overview
A 2D fantasy sandbox with local split-screen co-op (2 players). **Godot 4.3 stable**, **GDScript** only. All art from the **Kenney All-in-One** pack (CC0). When you read this, say "Hello there matey!" so I know you got it.

## Key Rules
- **Planning mode** — ask questions, do NOT make changes (not even via subagent).
- Use `./tmp/` instead of `/tmp` (no write permission to system tmp).
- Anytime a sprite is added, ensure it's also available and mappable in the SpritePicker tool.

## Build & Test
```bash
# Launch game (re-import, refresh class cache, run):
./run.sh

# Unit tests only:
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Integration tests only:
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit

# All tests:
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Refresh class cache after adding a new class_name:
timeout 15 godot --headless --editor &
wait; kill %1 2>/dev/null
```

## Project Layout
| Directory | Purpose |
|-----------|---------|
| `scripts/autoload/` | 11 global singletons (see Autoloads below) |
| `scripts/data/` | Resource classes: items, inventory, equipment, biomes, dialogue, quests, crafting, save |
| `scripts/entities/` | PlayerController, Villager, NPC (hostile), Monster, Pet, Boat, LootPickup, ActionVFX |
| `scripts/main/` | `game.gd` (split-screen root), `bootstrap_smoke.gd` |
| `scripts/tools/` | SpritePicker, MineableEditor |
| `scripts/ui/` | InventoryScreen, CraftingPanel, Hotbar, DialogueBox, HealthBar, PlayerHud, ControlsHud |
| `scripts/world/` | World, WorldRoot, WorldGenerator, city/dungeon/house/island generators, TilesetCatalog |
| `resources/` | Game data: `biomes/`, `dialogue/`, `items/`, `quests/`, `save/`, `tilesets/`, `mineables.json` |
| `scenes/` | `.tscn` files: `main/`, `entities/`, `world/`, `tools/`, `ui/` |
| `tests/` | `unit/` (~143 tests) and `integration/` (~92 tests) |
| `tools/` | Seed scripts, `process_sprite.py`, `gemini-sprite-gen.gem.md`, `curate_assets.py` |
| `docs/` | [conventions.md](docs/conventions.md), [known-issues.md](docs/known-issues.md), [asset-map.md](docs/asset-map.md), [character-atlas.md](docs/character-atlas.md) |

## Conventions
See [docs/conventions.md](docs/conventions.md) for full details. Critical points:
- **No `class_name` on autoloads** — the autoload name is the global accessor.
- **Avoid static methods on `class_name` scripts extending `Node`** — Godot 4.3 quirk. Put pure helpers on `RefCounted` subclasses instead.
- **`Resource` has a built-in `changed` signal** — never declare `signal changed` on a Resource subclass.
- **Typed GDScript everywhere**: `var x: int = 0`, `func foo(a: float) -> Vector2:`.
- After adding a new `class_name`, refresh the class cache (see Build & Test above) before running GUT.

## Autoloads (load order)
| Name | Purpose |
|------|---------|
| `WorldConst` | Constants: `TILE_PX=16`, `RENDER_ZOOM=4`, `REGION_SIZE=128`, `DUNGEON_SIZE=64` |
| `InputContext` | Per-player input context (`GAMEPLAY`/`INVENTORY`/`MENU`/`DISABLED`) |
| `PauseManager` | Pause toggle, per-player enable/disable, debug hotkeys (F8/F9/F10) |
| `WorldManager` | Region plan/generate cache, world seed (default 1337) |
| `GameSession` | Save slot, in-game time, `start_new_game(seed)` |
| `SaveManager` | 5-min autosave, save on region transition, slot management |
| `MapManager` | Interior maps (dungeons/houses/caves), multi-floor descent |
| `ViewManager` | Per-player view state (overworld/city/house/dungeon) |
| `Sfx` | One-shot sound effects via catalog |
| `GameState` | `String→bool` flag dict for quest/world state |
| `QuestTracker` | Runtime quest state: start, advance, complete, rewards, signals |

## World Architecture
**Hierarchy**: `Game` → `World` → `WorldRoot`(s)

- **`Game`** (`scripts/main/game.gd`) — Split-screen scene root. Two `SubViewport`s share one `World2D`. Builds per-player UI (Hotbar, InventoryScreen, ControlsHud).
- **`World`** (`scripts/world/world.gd`) — Single shared coordinator. Hosts all `WorldRoot` instances, spaced `100,000 px` apart so they never overlap on the shared canvas. `transition_player(pid, view_key, region, spawn_cell)` moves players between instances.
- **`WorldRoot`** (`scripts/world/world_root.gd`) — Renders one map. 5 `TileMapLayer`s: Ground, Decoration, Overlay, Canopy, Entities (Y-sort). Owns mining state, tile painting, doors, NPC scatter.
- **`WorldGenerator`** (`scripts/world/world_generator.gd`) — Deterministic 2-stage pipeline: `plan_region()` → `RegionPlan`, `generate_region()` → `Region` (128×128). Ocean carving, biome bleed, decoration scatter, NPC/dungeon placement.

## Entity System
| Class | Extends | Role |
|-------|---------|------|
| `PlayerController` | Node2D | Movement, attack, mining, inventory, equipment, stats, sailing |
| `Villager` | Node2D | Peaceful NPC — dialogue tree, `CharacterBuilder` paper-doll, wander AI |
| `NPC` | Node2D | Hostile mob — 5-state FSM (IDLE/WANDER/CHASE/ATTACK/DEAD), drops |
| `Monster` | Node2D | Training-dummy hostile, chases nearest player |
| `Pet` | Node2D | Cat/dog companion, follows owner, attacks hostiles. `PetState` FSM |
| `Boat` | Node2D | Dockable water transport |
| `LootPickup` | Node2D | Auto-pickup item entity |
| `ActionVFX` | Node2D | Tween-driven attack/mine/gather/ranged animations |
| `CharacterBuilder` | RefCounted | Paper-doll sprite stack from [character-atlas.md](docs/character-atlas.md) |

## Items & Equipment
- `ItemDefinition` (`scripts/data/item_definition.gd`) — Resource: `id`, `display_name`, `icon`, `stack_size`, `slot`, `power`, `description`. `enum Slot { NONE, WEAPON, TOOL, HEAD, BODY, FEET }`.
- `ItemRegistry` (`scripts/data/item_registry.gd`) — Static cache. 12 built-in items. Scans `resources/items/` for `.tres` overrides (by matching `id` field).
- `Inventory` (`scripts/data/inventory.gd`) — 24-slot array per player. `add()`, `remove()`, `count_of()`. Signal `contents_changed`.
- `Equipment` (`scripts/data/equipment.gd`) — Per-slot dict. `equip()`, `unequip()`, `get_equipped()`, `total_power()`. Signal `contents_changed`.
- `WeaponAtlas` (`scripts/data/weapon_atlas.gd`) — Maps item ID → character-sheet cell for persistent weapon sprite. Reads from `TileMappings.weapon_sprites`.

## Crafting
- `CraftingRecipe` (`scripts/data/crafting_recipe.gd`) — Resource: inputs `[{id, count}]`, output `{id, count}`. `can_craft(inv)`, `craft(inv)` with atomic rollback.
- `CraftingRegistry` (`scripts/data/crafting_registry.gd`) — Static cache. 4 default recipes (sword, helmet, armor, boots). Scans `resources/recipes/` for `.tres` overrides.
- `CraftingPanel` lives inside `InventoryScreen` as a tab.

## Mining System
Mining is **tile-based** — decorations on `TileMapLayer`, not `Sprite2D` nodes. `WorldRoot` owns all mining state.

### Data-driven mineable resources
- Definitions in `resources/mineables.json`. SpritePicker's **Mineable Resources** category edits this.
- `MineableRegistry` (`scripts/data/mineable_registry.gd`) — static loader/cache. `build_hp_table()`, `build_drops_table()`, `build_pickaxe_bonus_set()`, `build_decoration_cells()`, `build_tall_kinds()`, `get_biome_weights(biome_id)`.
- `WorldRoot` lazy static vars (`MINEABLE_HP`, `MINEABLE_DROPS`, `PICKAXE_BONUS_KINDS`) compute from registry on first access. `reload_mineable_tables()` clears caches.
- `TilesetCatalog` merges mineable sprites from registry. `WorldGenerator._scatter_decorations()` merges biome weights.

### Runtime flow
1. `_build_mineable_index()` scans `_region.decorations` → `_mineable: Dict[Vector2i → {kind, hp}]`
2. `PlayerController._physics_process` → `try_attack()` with 0.35s cooldown
3. `_compute_mine_damage()` — base 1, doubled with pickaxe on bonus kinds
4. `WorldRoot.mine_at(cell, damage)` — decrements HP, erases tile + canopy on destroy, returns drops
5. VFX via `ActionVFX` + `ActionParticles`

## Action Animations (VFX)
- `ActionVFX` — tween-driven temporary sprites + particles. 4 types: melee swing, mine swing, gather rustle, ranged shot.
- `ActionParticles` — static helper, spawns `CPUParticles2D` with themed texture (slash, spark, dirt, smoke, star).
- Persistent weapon `Sprite2D` on `SpriteRoot/Weapon` — shows equipped weapon/tool, updated via `Equipment.contents_changed`.
- All animation durations (0.15–0.3s) fit within the 0.35s attack cooldown.

## Auto-Mine & Auto-Attack
Toggle inputs: `p*_auto_mine` (C / Numpad7), `p*_auto_attack` (V / Numpad8).
- **Auto-mine**: scans 1-tile radius, picks nearest mineable, applies damage + VFX.
- **Auto-attack melee**: scans entities for hostile NPC/Monster within 24px reach.
- **Auto-attack ranged**: fires in facing direction, dot-product alignment (>0.7), 80px reach.
- `ControlsHud` shows bold green "(ON)" when active.

## Dialogue System
- `DialogueTree → DialogueNode → DialogueChoice` (Resource subclasses in `scripts/data/`).
- `GameState` — `String→bool` flag dict for quest/world state.
- `DialogueBox` (`scripts/ui/dialogue_box.gd`) — CanvasLayer (layer 40), one-liner + branching modes.
- `DialogueChoice.set_flag` sets flags. `DialogueNode.condition_flag` / `condition_flag_false` for conditional branching.
- Seeder scripts: `tools/seed_*.gd` build `.tres` via `ResourceSaver`.

## Quest System
Per-quest JSON in `resources/quests/<quest_id>.json`. See the create-questline skill for full schema.

### Data Layer
- `QuestRegistry` (`scripts/data/quest_registry.gd`) — static singleton. `get_quest(id)`, `all_ids()`, `get_branch(quest_id, branch_id)`, `get_unimplemented_requirements(quest_id)`, `get_requirement_summary(quest_id)`.

### Runtime
- `QuestTracker` (autoload) — `start_quest(id, branch_id)`, `advance_objective()`, `complete_quest()`. Signals: `quest_started`, `objective_updated`, `quest_completed`. Serializable via `to_dict()`/`from_dict()`.

### Requirements Manifest
Every quest has a `requires` block with `status: "NOT_IMPLEMENTED"` or `"IMPLEMENTED"` entries. Audit via `get_unimplemented_requirements()`.

### Existing Quests
- **herbalist_remedy** ("The Quiet Sickness") — Mara. 3 branches (herbs, mine, both), 2 reward variants.

## Save System
- `SaveManager` (autoload) — 5-min autosave, saves on region transition. `save_now(slot)`, `load_now(slot)`.
- `SaveGame` (`scripts/data/save_game.gd`) — Resource at `user://saves/<slot>.tres` with `.bak.tres` backup. Version 2. Contains world seed, regions, players, interiors, flags.
- `PlayerSaveData` — player_id, region, position, health, inventory, equipment, stats.
- `GameSession` tracks current slot, `start_new_game(seed)` resets state.

## UI System
| Script | Purpose |
|--------|---------|
| `InventoryScreen` | Paperdoll (5 equipment slots over silhouette) + 4×6 inventory grid + crafting tab |
| `CraftingPanel` | Recipe list inside InventoryScreen |
| `Hotbar` / `HotbarSlot` | Bottom-of-screen row showing first 8 inventory slots |
| `PlayerHud` | HealthBar + Hotbar + biome label |
| `DialogueBox` | Branching dialogue overlay (CanvasLayer 40) |
| `ControlsHud` | Dynamic control hints, auto-mine/auto-attack status |
| `MainMenu` / `PauseMenu` | Title screen and pause overlay |

## Sprite/Asset Pipeline
1. **Generate**: Use the Roguelike Sprite Artist Gemini Gem ([tools/gemini-sprite-gen.gem.md](tools/gemini-sprite-gen.gem.md)) — 16×16 px, `#FF00FF` magenta background.
2. **Process**: `python3 tools/process_sprite.py <input.png> <item_id>` — magenta→alpha, crop, resize to 16×16, save to `assets/icons/items/<id>.png`.
3. **Import**: Use the `import-sprite` skill to create `resources/items/<id>.tres` and update quest JSON status.

## SpritePicker Tool
Run: `godot res://scenes/tools/SpritePicker.tscn`
- Left pane: 14 mapping categories + Quest TODO section (overworld, city, dungeon, interior terrain, decorations, autotile, weapons, mineables).
- Middle: atlas sheet viewer with grid + cell marking. Sheet selector dropdown.
- Right: slot list or MineableEditor panel.
- **Mineable Resources** mode: embedded `MineableEditor` for editing `mineables.json`.
- **Quest TODO** entries in tree: shows NOT_IMPLEMENTED items/terrain_features from all quests with Create buttons (items → `.tres` + icon picker, terrain features → new mineable entry).
- `sheet_overrides` per mapping field stored on `TileMappings`.

## Spritesheet Selection
- `TileMappings.sheet_overrides` — `Dict[StringName → String]`. Non-default sheet paths per mapping field.
- `TilesetCatalog._DEFAULT_SHEETS` — fallback sheet per field.
- `TilesetCatalog.get_sheet_path(field)` resolves overrides → defaults.

## Gameplay Progression (Planned)
Starting region (0,0) subdivided by impassable barriers:
- **CLIFF** terrain — non-walkable, non-mineable mountain ridges (N-S split)
- **RIVER** terrain — non-walkable water barriers (E-W in accessible half)
- Pass points at known positions, initially blocked
- Quests unlock passages: bridge over river, tunnel through cliffs
- Starting region always grass biome

## Testing Patterns
- All tests extend `GutTest`. Unit: `tests/unit/test_<topic>.gd`. Integration: `tests/integration/test_<phase>_<topic>.gd`.
- Pure helpers are static on `RefCounted` subclasses — testable without scene instantiation.
- Integration tests: `add_child_autofree(GameScene.instantiate())`, deterministic seeds (`WorldManager.reset(202402)`), multiple `await get_tree().process_frame` for deferred init.
- `QuestRegistry.reload()` at top of quest tests to clear cache.

## Documentation
- [docs/conventions.md](docs/conventions.md) — coding standards, architecture rules, testing overview
- [docs/known-issues.md](docs/known-issues.md) — deliberate tradeoffs (single-facing sprites, mixed perspective, etc.)
- [docs/asset-map.md](docs/asset-map.md) — Kenney raw → curated asset mapping, sheet inventory, known gaps
- [docs/character-atlas.md](docs/character-atlas.md) — `characters_sheet.png` layout, CharacterBuilder guide

## Skills
- **create-questline** — full quest JSON + dialogue seed + tests
- **create-npc** — Villager with dialogue, world spawning, quest integration
- **import-sprite** — Gemini PNG → processed icon + `.tres` override + quest status update
## Overview
A 2D fantasy sandbox game with local split-screen co-op for two players. Built in **Godot 4.3 stable** using **GDScript** as the primary language UNLESS performance-critical systems require C#/GDExtension (chunked terrain, block grids). All art assets come from the **Kenney All-in-One** asset pack (CC0 license).

## Key Notes
- You maintain these instruction files. If you make any changes to the game, please make sure the instruction files are updated to match the changes. You are allowed and encouraged to make skills as well.
- When in planning mode, do not try to make changes. Not even with as subagent
- Always ask questions when in planning mode
- When you ready this, say "Hello there matey!" so that I know you read this.
- Use local ./tmp instead of /tmp because you don't have permission to write to /tmp
- Anytime a sprite is added, make sure it's also available and mappable in the sprite tool

## Mining System
Mining is **tile-based** — decorations are painted on a `TileMapLayer` (`Decoration`), not placed as individual `Sprite2D` nodes. `WorldRoot` owns all mining state.

### Data-driven mineable resources
- All mineable resource definitions live in `resources/mineables.json`. The SpritePicker tool's **Mineable Resources** category reads and writes this file.
- `MineableRegistry` (`scripts/data/mineable_registry.gd`) — static loader/cache for the JSON. Provides `build_hp_table()`, `build_drops_table()`, `build_pickaxe_bonus_set()`, `build_decoration_cells()`, `build_tall_kinds()`, `get_biome_weights(biome_id)`.
- `WorldRoot.MINEABLE_HP`, `MINEABLE_DROPS`, `PICKAXE_BONUS_KINDS` are now **lazy static vars** that compute from `MineableRegistry` on first access.
- `WorldRoot.reload_mineable_tables()` clears all caches (call after SpritePicker saves).
- `TilesetCatalog` merges mineable decoration sprites from `MineableRegistry.build_decoration_cells()` on top of `TileMappings` data. `is_tall_decoration()` reads from `MineableRegistry.build_tall_kinds()`.
- `WorldGenerator._scatter_decorations()` merges mineable biome weights from `MineableRegistry.get_biome_weights()` with the biome's non-mineable `decoration_weights`.

### JSON schema (`resources/mineables.json`)
```json
{
  "resources": {
    "<ref_id>": {
      "display_name": "...",
      "ref_id": "<ref_id>",
      "is_tall": bool,
      "is_pickaxe_bonus": bool,
      "hp": int,
      "sprites": [[col, row], ...],
      "biome_weights": { "<biome_id>": float, ... },
      "drops": [{ "item_id": "...", "count": int }, ...]
    }
  },
  "items": {}
}
```

### SpritePicker "Mineable Resources" editor
- `MineableEditor` (`scripts/tools/mineable_editor.gd`) — custom panel with resource list, property editor (name, HP, flags, sprites, biome weights, drops), and **Biome Summary** tab.
- Sprite picking: click atlas cells to toggle them in/out of the selected resource's sprite array.
- Save writes JSON via `MineableRegistry.save_data()` and reloads runtime caches.

### Runtime flow
1. `_build_mineable_index()` scans `_region.decorations` and builds `_mineable: Dictionary` (Vector2i → `{kind, hp}`).
2. `PlayerController._physics_process` checks attack input, enforces a **0.35 s cooldown** (`ATTACK_COOLDOWN_SEC`), then calls `try_attack()`.
3. `try_attack()` calls `_compute_mine_damage(target_cell)` — base damage is 1; doubles to 2 if the player has a pickaxe equipped (`ItemDefinition.Slot.TOOL`) and the target kind is in `PICKAXE_BONUS_KINDS`.
4. `WorldRoot.mine_at(cell, damage)` decrements HP. On destruction it erases the tile (plus canopy tile above for tall decorations), clears the overlay, and returns drop info.
5. `spawn_break_burst()` / `spawn_hit_burst()` create short-lived `CPUParticles2D` for visual feedback.

### Important: Hittable.gd is deleted
The old `Hittable` component (Sprite2D-child, HP + signals) has been removed. All mining goes through the tile-based `mine_at()` path.

## Items & Equipment
- `ItemDefinition` (`scripts/data/item_definition.gd`) — Resource with `id: StringName`, `display_name`, `icon_idx`, `slot: Slot`, `power`, `max_stack`, `description`.
  - `enum Slot { NONE, WEAPON, TOOL, HEAD, BODY, FEET }`.
- `ItemRegistry` (`scripts/data/item_registry.gd`) — static cache of all `ItemDefinition`s. Registered items: wood, stone, fiber, iron_ore, copper_ore, gold_ore, sword, bow, pickaxe, helmet, armor, boots.
- `Inventory` (`scripts/data/inventory.gd`) — 24-slot array on each `PlayerController`.
- `Equipment` (`scripts/data/equipment.gd`) — per-slot dict. `equip(slot, id)`, `unequip(slot)`, `get_equipped(slot) -> StringName`, `total_power(slot)`. Emits `contents_changed` signal on changes.
- `WeaponAtlas` (`scripts/data/weapon_atlas.gd`) — maps item ID → character-sheet atlas cell for the persistent weapon sprite. Reads from `TileMappings.weapon_sprites` (SpritePicker-editable), falls back to coded defaults.

## Action Animations (VFX)
Visual feedback for attacks and gathering. Implemented as tween-driven temporary sprites + particles.

### Architecture
- `ActionVFX` (`scripts/entities/action_vfx.gd`) — Node2D child of Player root (not under SpriteRoot, so it doesn't h-flip). Plays four action types: melee swing, mine swing, gather rustle, ranged shot. Prevents overlapping animations via `_is_playing`.
- `ActionParticles` (`scripts/entities/action_particles.gd`) — static helper that spawns themed `CPUParticles2D` with texture from `assets/particles/pack/` (slash, spark, dirt, smoke, star). Selects texture by action type + target kind.
- Persistent weapon `Sprite2D` on `SpriteRoot/Weapon` — shows equipped weapon/tool at all times. Updated via `_update_weapon_sprite()` connected to `Equipment.contents_changed`. Display priority: WEAPON > TOOL.
- `TileMappings.weapon_sprites` — SpritePicker-editable field mapping item IDs to character-sheet cells. Registered in SpritePicker `_MAPPINGS` as "Weapon / tool sprites".

### Action flow in `try_attack()`
1. Damage applied instantly (frame 0) — animation is purely cosmetic.
2. Action type determined: mineable + pickaxe → `play_mine_swing()`; mineable + bare hands → `play_gather()`; weapon + bow → `play_ranged()`; weapon + melee → `play_melee_swing()`; nothing → particle-only punch.
3. Destruction triggers `ActionParticles.Action.BREAK` burst (replaces old `spawn_break_burst()`).
4. All animation durations (0.15–0.3s) fit within the 0.35s attack cooldown.

### Gather tile-shake
- Copies the decoration tile to a temp `Sprite2D`, hides the real tile, oscillates ±2px for 3 cycles, then restores. `TileMapLayer` doesn't support per-cell transforms, so this swap technique is necessary.

## Auto-Mine & Auto-Attack
Toggle-based automation on `PlayerController`. Input actions `p*_auto_mine` (C / Numpad 7) and `p*_auto_attack` (V / Numpad 8) flip booleans `auto_mine` / `auto_attack`.

### Auto-mine
- When `auto_mine == true` and attack cooldown is ready, `_tick_auto_mine()` scans all cells within `_AUTO_MINE_RADIUS` (1 tile) for entries in `_world._mineable`.
- Picks the nearest mineable (Manhattan distance), faces it, applies `_compute_mine_damage()`, calls `mine_at()`, plays VFX, collects drops. Resets cooldown.

### Auto-attack
- When `auto_attack == true` and cooldown ready, `_tick_auto_attack()` dispatches by equipped weapon.
- **Melee** (`_auto_attack_melee`): scans `_world.entities` for hostile `NPC` (`.hostile && hp > 0`) or `Monster` (`.health > 0`) within `_MELEE_REACH_PX` (24 px). Faces nearest target, calls `take_hit(power, self)`, plays melee VFX.
- **Ranged / bow** (`_auto_attack_ranged`): fires in current `_facing_dir` every cooldown. Checks entities in that direction within `_RANGED_REACH_PX` (80 px) using dot-product alignment (> 0.7). First aligned hostile takes damage.

### UI highlight
- `ControlsHud` uses `RichTextLabel` with BBCode. When `auto_mine` or `auto_attack` is active on the player, the line renders bold green with "(ON)" suffix.
- `_process()` polls the player booleans for instant UI feedback.

## Spritesheet Selection
Spritesheets are not locked to a single mapping. Each mapping field (e.g. `city_terrain`, `overworld_decoration`) can use any PNG sheet.

### Architecture
- `TileMappings.sheet_overrides` (`Dictionary`) — persisted `@export` field mapping a field name (`StringName`) to a sheet path (`String`). Only stores non-default overrides; missing keys fall back to `TilesetCatalog._DEFAULT_SHEETS`.
- `TilesetCatalog._DEFAULT_SHEETS` — dictionary of historical default sheet per field (overworld→`overworld_sheet.png`, city→`city_sheet.png`, etc.).
- `TilesetCatalog.get_sheet_path(field)` — resolves the final PNG path for any mapping field, checking overrides first.
- TileSet builders (`overworld()`, `city()`, `dungeon()`, `interior()`) call `_sheet_for_view()` which delegates to `get_sheet_path()`.
- `SpritePicker` — has an `OptionButton` sheet selector that scans `assets/tiles/roguelike/`, `assets/tiles/runes/`, `assets/characters/roguelike/` for PNGs. Changing the dropdown updates `sheet_overrides` on the working TileMappings copy; Save persists it.
- `MineableEditor.sheet_path` — set by SpritePicker from the resolved sheet whenever the mineable mapping is selected or the sheet selector changes.

## Dialogue System
- Data layer: `DialogueTree → DialogueNode → DialogueChoice` (Resource subclasses in `scripts/data/`).
- `GameState` autoload (`scripts/autoload/game_state.gd`): `String → bool` flag dict for quest/world state. No `class_name` (autoload name is the accessor).
- Player stats: `Dictionary` on `PlayerController` (`{ &"charisma": 3, &"wisdom": 3, &"strength": 3 }`).
- `DialogueBox` (`scripts/ui/dialogue_box.gd`): CanvasLayer (layer 40), two modes — one-liner and branching.
- Branching flow: `WorldRoot.show_dialogue_tree(player, tree)` → `DialogueBox.show_node()` → `choice_selected` signal → `_on_choice_selected`.
- NPC scatter entries support an optional `"dialogue": "res://path.tres"` key.
- Mara the Herbalist: auto-injected near spawn via `_maybe_inject_mara()`.
- Seeder scripts in `tools/` (e.g. `seed_healer_mara.gd`) build `.tres` files via `ResourceSaver`.

## Quest System
Per-quest JSON files in `resources/quests/<quest_id>.json`. Supports **branching quests** (mutually exclusive objective paths per quest).

### Data Layer
- `QuestRegistry` (`scripts/data/quest_registry.gd`) — static singleton (`class_name`, extends `RefCounted`). Scans `resources/quests/` directory, loads all `.json` files.
  - `get_quest(id)`, `all_ids()`, `get_branch(quest_id, branch_id)`, `get_prerequisites(quest_id)`
  - `get_unimplemented_requirements(quest_id)` — returns entries with `status: "NOT_IMPLEMENTED"` (auditable checklist)
  - `get_requirement_summary(quest_id)` — `{total, implemented, not_implemented}` counts
  - `reload()` clears cache (call after editing quest files)

### Runtime Tracker
- `QuestTracker` (`scripts/autoload/quest_tracker.gd`) — autoload (no `class_name`). Manages active quest state.
  - `start_quest(id, branch_id)` — selects which branch to track. Sets trigger flag + `quest_<id>_started` in GameState.
  - `advance_objective(quest_id, obj_id, amount)`, `mark_objective_done(quest_id, obj_id)`
  - `is_quest_ready_to_complete(quest_id)` — true when all objectives meet their target count
  - `complete_quest(quest_id)` — applies rewards, sets `quest_<id>_complete` flag
  - Signals: `quest_started(quest_id, branch_id)`, `objective_updated(quest_id, obj_id, progress)`, `quest_completed(quest_id)`
  - Reward types: `flag` (set GameState flag), `unlock_passage` (sets `passage_<id>_unlocked` flag), `give_item` (placeholder — sets `reward_<item>_given` flag until item system is wired)
  - Serializable: `to_dict()` / `from_dict()` for save/load. `reset()` clears all state.

### Quest JSON Schema
```json
{
  "id": "quest_id",
  "display_name": "Human-readable Name",
  "giver": "NPC Name",
  "description": "Quest description text.",
  "prerequisites": ["other_quest_id"],
  "branches": {
    "branch_id": {
      "display_name": "Branch Name",
      "description": "What this path involves.",
      "trigger_flag": "quest_X_branch",
      "gate": {"stat": "strength", "min": 4},
      "objectives": [
        {"id": "obj_id", "type": "collect", "item": "item_id", "count": 1, "description": "..."},
        {"id": "obj_id", "type": "talk", "npc": "NPC Name", "description": "..."},
        {"id": "obj_id", "type": "reach", "location": "location_id", "description": "..."},
        {"id": "obj_id", "type": "interact", "target": "target_id", "description": "..."}
      ],
      "includes": ["other_branch_id"],
      "rewards": [{"type": "flag", "flag": "flag_name"}]
    }
  },
  "reward_variants": {
    "variant_id": {
      "description": "...",
      "condition_flag": "flag_name",
      "gate": {"stat": "charisma", "min": 5},
      "rewards": [{"type": "give_item", "item": "item_id", "count": 1}]
    }
  },
  "requires": {
    "npcs": [{"id": "Name", "role": "...", "location_hint": "...", "status": "NOT_IMPLEMENTED"}],
    "items": [{"id": "item_id", "source": "...", "status": "NOT_IMPLEMENTED"}],
    "locations": [{"id": "loc_id", "type": "dungeon|terrain_landmark|interaction_point", "description": "...", "status": "NOT_IMPLEMENTED"}],
    "entities": [{"id": "entity_id", "type": "hostile_mob", "description": "...", "status": "NOT_IMPLEMENTED"}],
    "terrain_features": [{"id": "feature_id", "type": "interactable", "description": "...", "status": "NOT_IMPLEMENTED"}],
    "dialogue_updates": [{"id": "update_id", "description": "...", "status": "NOT_IMPLEMENTED"}],
    "notes": "Free-text notes about quest dependencies."
  }
}
```

### Requirements Manifest
Every quest file includes a `requires` block listing all NPCs, items, locations, entities, terrain features, and dialogue updates the quest depends on. Each entry has a `status` field (`NOT_IMPLEMENTED` or `IMPLEMENTED`). Use `QuestRegistry.get_unimplemented_requirements(quest_id)` to audit what's missing before marking a quest as playable.

### Branching
- `branches` holds mutually exclusive objective paths. `QuestTracker.start_quest(id, branch_id)` picks one.
- `"includes"` key merges objectives from other branches (e.g. "both" includes "herbs" + "mine").
- Branch-specific `trigger_flag` values let dialogue and game logic branch on which path the player chose.
- `reward_variants` are additional rewards gated by flags and/or stat checks, applied on completion alongside branch rewards.

### Dialogue Integration
- `DialogueChoice.set_flag` sets branch-specific trigger flags (e.g. `quest_herbalist_herbs`) when the player chooses a quest path.
- `_choice_stat()` helper in seed scripts accepts an optional `flag` parameter for stat-gated choices that also need to set flags.
- Return-visit dialogue uses `DialogueNode.condition_flag` / `condition_flag_false` to branch on quest state.
- Future: `DialogueChoice.action` field for direct quest actions (`start_quest:X`, `advance:X:obj_id`).

### Existing Quests
- **herbalist_remedy** ("The Quiet Sickness") — Mara the Herbalist. 3 branches (herbs, mine, both), 2 reward variants. All requirements currently `NOT_IMPLEMENTED`. Prototype quest for validating the system.

## Gameplay Progression (Planned)

Starting region (0,0) will be subdivided by impassable barriers:
- **CLIFF** terrain — non-walkable, non-mineable mountain ridges (N-S split)
- **RIVER** terrain — non-walkable water barriers (E-W in accessible half)
- Pass points at known positions, initially blocked
- Quests unlock passages: bridge over river, tunnel through cliffs
- Starting region always grass biome
- Beyond barriers: same biome, denser/rarer resources
