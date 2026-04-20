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
