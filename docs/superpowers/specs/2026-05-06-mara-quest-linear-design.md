# Mara's Quest — Linear Rework Design
**Date:** 2026-05-06  
**Branch:** `feature/mara-quest-improvements`  
**Status:** Approved

## Problem

`herbalist_remedy` has a solid design but broken branching. The three-branch structure (herbs / mine / both) lets the player skip the mine entirely, breaking the intended "diagnose then cure" narrative. Additionally, several quest elements assumed to be missing are already implemented.

## Goal

Make the quest fully playable with a single linear narrative arc:  
**talk to Mara → enter mine → defeat boss → seal leak + collect ore → return to Mara with evidence → Mara analyzes ore → gather herbs + spring water → return to Mara**

## What Already Works (Do Not Touch)

| System | Status |
|--------|--------|
| `QuestInteractable` node + scene | ✅ Exists |
| Spring placement near spawn (`_inject_spring`) | ✅ Code present; visual upgraded to `world_objects` sheet |
| Mine leak chest (`_spawn_mine_leak` on boss death) | ✅ Already spawned, wired to `seal_leak` + gives `contaminated_ore` |
| `moonstone_mine` labyrinth entrance injection | ✅ Already placed east of spawn |
| `QuestTracker` API (start/advance/complete/give_item) | ✅ Fully implemented |
| `WorldRoot._on_choice_selected` → auto `start_quest()` | ✅ Triggered by `choice.set_flag` matching a branch `trigger_flag` |
| All 6 quest items in `items.json` | ✅ Present |
| `blue_nightcap_mushroom` in `mineables.json` | ✅ Present |
| Villager `_try_quest_turn_in` (handles `talk` objectives) | ✅ Implemented on Mara — **requires fix for sequential talk objectives** |
| `wolf` creature in `creature_sprites.json` | ✅ Present with full combat data |

## Changes Required

### 1. `resources/quests/herbalist_remedy.json`

Replace the three branches (`herbs`, `mine`, `both`) with a single `main` branch.

**New branch `main` objectives (in order):**

| # | id | type | detail | description |
|---|---|---|---|---|
| 1 | `enter_mine` | reach | `moonstone_mine` | Enter the moonstone mine |
| 2 | `seal_leak` | interact | target: `mine_leak` | Seal the contamination source |
| 3 | `get_evidence` | collect | `contaminated_ore` × 1 | Collect contaminated ore as evidence |
| 4 | `show_evidence` | talk | npc: `Mara` | Return to Mara and show her the ore |
| 5 | `get_fennel` | collect | `fennel_root` × 1 | Gather fennel root |
| 6 | `get_mushroom` | collect | `blue_nightcap` × 1 | Gather blue nightcap mushrooms |
| 7 | `get_water` | collect | `clean_spring_water` × 1 | Collect clean spring water |
| 8 | `return_mara` | talk | npc: `Mara` | Return to Mara with all ingredients |

`trigger_flag: "quest_herbalist_main"`

> **Note on objectives 2+3:** The mine_leak TreasureChest marks `seal_leak` done via `quest_objective_id` and gives `contaminated_ore` via `fixed_loot`. `notify_item_collected` then auto-advances `get_evidence`. Both objectives complete from a single chest interaction.

> **Note on objectives 4 vs 8 (two talk-to-Mara):** `Villager._try_quest_turn_in` needs a 2-line fix to only advance the **first incomplete** talk objective per visit instead of all at once. See §5 below.

> **`QuestTracker.advance_objective` auto-flag:** When any objective reaches its target count, `QuestTracker` sets `GameState.set_flag("quest_<quest_id>_obj_<obj_id>_done")`. Dialogue nodes use this flag in `condition_flag` / `condition_flag_false` to show phase-aware text.

**Reward variants (updated — condition flag changes):**

- `deal_basic`: always applies on completion (remove old `condition_flag: "quest_herbalist_mine"`) — gives `tonic` × 1
- `deal_push`: change condition from `quest_herbalist_mine` → `quest_herbalist_pushed_deal` (CHA≥5 choice during intro) — gives `tonic` × 1 + `antidote_recipe` × 1

**`requires` block:** Mark all previously `NOT_IMPLEMENTED` items as `IMPLEMENTED`. Update `birch_grove` and `village_well` to `IMPLEMENTED` (see §6). Update `sick_wolf` / `feral_animal` to `IMPLEMENTED` (see §7).

---

### 2. `resources/dialogue/healer_mara.tres` + `tools/seed_healer_mara.gd`

Rework the dialogue tree. Remove branch-selection choices. Replace with a linear intro that accepts the quest and optionally sets `quest_herbalist_pushed_deal`. Dialogue is **phase-aware** using auto-flags set by `QuestTracker` on objective completion.

**New dialogue flow:**

```
[ROOT] "Ah, traveller. The valley is sick and I fear I know why."
  ├─ [require: quest_herbalist_remedy_complete]
  │   "How is the valley?" → completion node
  ├─ [require: quest_herbalist_main_obj_get_evidence_done, NOT show_evidence_done]
  │   "I have something from the mine." → show_evidence node (marks show_evidence done)
  ├─ [require: quest_herbalist_main_obj_show_evidence_done, NOT return_mara_done]
  │   "I have all the ingredients." → turn-in node (marks return_mara done → complete)
  ├─ [require: quest_herbalist_main (active)]
  │   "Any progress on the sickness?" → progress reminder node
  └─ "Tell me more." → lore intro node

[LORE INTRO] "The water is poisoned — moonstone seeping from the old mine east of here.
              Animals drink from the streams and fall ill. Three villages have lost livestock this moon."
  ├─ [WIS≥4] "Could the ore itself be toxic?" → detailed explanation node
  │     → "Precisely. Fractured moonstone leaches into groundwater. Sealed twenty years ago,
  │        but something has broken through." → [OFFER]
  └─ "What needs to be done?" → [OFFER]

[OFFER] "Seal the leak at the source — the old mine east of the birch grove.
         Bring me proof of what you find. I'll know what remedy to brew once I've seen it."
  ├─ [CHA≥3] "What's in it for me?" → negotiate node
  │     ├─ [CHA≥5] "I want the tonic AND your antidote recipe."
  │     │     → set_flag: quest_herbalist_pushed_deal
  │     │     → "You drive a hard bargain. Fine — bring me proof and I'll give you both."
  │     │        → [ACCEPT] set_flag: quest_herbalist_main
  │     └─ "Fair enough. I'll do it."
  │           → [ACCEPT] set_flag: quest_herbalist_main
  └─ "I'll help." → [ACCEPT] set_flag: quest_herbalist_main

[ACCEPT] "The mine is east, past the birch grove. Watch for sick wolves — they don't run
          from people anymore. Bring me what you find."
  → (quest started via WorldRoot._on_choice_selected)

[SHOW EVIDENCE — requires get_evidence done, not show_evidence done]
  Mara examines the ore. "Fractured moonstone, just as I feared. The contamination is clear.
  Now I know what remedy to brew — I need fennel root, blue nightcap mushrooms, and
  clean spring water from the untainted spring south-west of here."
  → marks show_evidence objective done

[PROGRESS REMINDER — requires quest active, no special flag]
  "Have you been to the mine yet? Find the source — seal it and bring me proof."

[COMPLETION — requires return_mara done]
  "The valley owes you a debt it can never repay. The water runs clear again.
   Here — take this." → rewards applied

[POST-COMPLETION — requires quest_herbalist_remedy_complete]
  "If you ever need a tonic, you know where to find me."
```

---

### 3. `tests/unit/test_quest_wiring.gd`

Replace all tests referencing branches `herbs`, `mine`, `both` with `main`-branch equivalents:

| Old test | New test |
|---|---|
| `test_trigger_flag_herbs` | `test_trigger_flag_main` — asserts `quest_herbalist_main` → `("herbalist_remedy", "main")` |
| `test_trigger_flag_mine` | Remove |
| `test_trigger_flag_both` | Remove |
| `test_herbs_branch_collect_flow` | `test_main_branch_full_flow` — start `main`, advance all 8 objectives in order, complete |
| `test_mine_branch_location_reached` | Merge into `test_main_branch_full_flow` |
| `test_both_branch_collects_from_both_branches` | Remove |

New tests to add:
- `test_pushed_deal_reward_variant` — start `main`, set `quest_herbalist_pushed_deal` flag, complete → assert `antidote_recipe` reward active
- `test_sequential_talk_objectives` — two talk objectives to same NPC; confirm first visit advances `show_evidence` only, second visit advances `return_mara`
- `test_auto_objective_flag` — after `get_evidence` target is met, assert `quest_herbalist_remedy_obj_get_evidence_done` flag is set in `GameState`

---

### 4. `scripts/autoload/quest_tracker.gd` — Auto-objective flags

In `advance_objective()`, after incrementing the counter, check if the new value meets the target. If so, set:
```gdscript
GameState.set_flag("quest_%s_obj_%s_done" % [quest_id, objective_id])
```

This enables dialogue nodes to gate on `condition_flag = "quest_herbalist_remedy_obj_get_evidence_done"` without any additional code.

---

### 5. `scripts/entities/villager.gd` — Sequential talk objectives

In `_try_quest_turn_in()`, change the inner loop to **stop after the first incomplete talk objective**:

```gdscript
# Before (marks ALL talk objectives at once):
for obj in branch.get("objectives", []):
    if obj.get("type", "") != "talk": continue
    if obj.get("npc", "") != quest_giver_name: continue
    QuestTracker.mark_objective_done(qid, obj["id"])

# After (advances only the first incomplete one):
for obj in branch.get("objectives", []):
    if obj.get("type", "") != "talk": continue
    if obj.get("npc", "") != quest_giver_name: continue
    if QuestTracker.get_objective_progress(qid, obj["id"]) > 0: continue  # already done
    QuestTracker.mark_objective_done(qid, obj["id"])
    break  # one per visit
```

This makes sequential NPC conversations work correctly for any quest, not just Mara's.

---

### 6. Birch Grove + Village Well

**Birch Grove:**  
`_inject_birch_grove(centre)` in `world_root.gd` — paint ~8 tree decoration tiles (using existing tree mineable sprites from the overworld sheet) at fixed offsets between spawn and mine entrance (`centre + Vector2i(6..10, -2..2)`). These are normal mineable tiles — fully choppable. Placed via `decoration_layer.set_cell()` during `_maybe_inject_quest_interactables()`.

**Village Well:**  
`_inject_village_well(centre)` in `world_root.gd` — place a `QuestInteractable` with:
- `quest_id = ""`, `objective_id = ""` (no quest objective — flavour only)
- `interact_text = "The water has a strange mineral smell — like crushed stone. Whatever is poisoning the streams flows through here too."`
- Sprite from `world_objects` sheet, `village_well` cell `[7, 0]`
- Position: ~2 tiles from spawn (centre of starting area)

---

### 7. Sick Wolf / Feral Animal Spawns

Add `sick_wolf` to `resources/creature_sprites.json` — same sprite region as `wolf`, greenish-grey tint `[0.5, 0.6, 0.4, 1]`, same combat stats. `feral_animal` is handled by reusing `rat` (no new entry needed).

In `world_root.gd`'s `_inject_moonstone_mine(centre)`, after placing the mine entrance, scatter hostile mobs:
- 3–4 `sick_wolf` at cells 8–12 tiles east of spawn (between birch grove and mine)
- 2–3 `rat` interspersed in the same zone

Uses the existing `_spawn_monster(entry)` path. Sets `entry.tier = 0` (normal difficulty).

Update `resources/creature_sprites.json`: run `python3 tools/gen_hires_sheet.py creatures` after adding `sick_wolf` entry.

---

### 8. Quest Objective Marker on World Map

Show a gold 5-point star on `WorldMapView` at the location of the **first incomplete, mappable objective** across all active quests. The marker only appears for objectives that have a known world position and are on the overworld map (not inside a dungeon).

**Architecture — push model:**  
`WorldRoot` calls `QuestTracker.register_objective_position(quest_id, obj_id, region_id, cell)` when it places relevant entities. `WorldMapView._draw()` calls `QuestTracker.get_objective_markers()` to get the list of `{region_id, cell, quest_id, obj_id}` entries and draws a gold star for the first incomplete one.

**New `QuestTracker` methods:**

```gdscript
## Called by WorldRoot when a quest-relevant entity is placed at a world position.
## Persisted in _objective_positions across frames; cleared on reset().
func register_objective_position(quest_id: String, obj_id: String,
                                  region_id: Vector2i, cell: Vector2i) -> void

## Returns a list of {quest_id, obj_id, region_id, cell} for all registered
## positions, ordered: first incomplete objective per active quest first.
## WorldMapView iterates this and draws the first mappable entry.
func get_objective_markers() -> Array[Dictionary]
```

**WorldRoot registration call sites:**

| Trigger | Quest / Objective | Region | Cell source |
|---|---|---|---|
| `_inject_spring()` | `herbalist_remedy` / `get_water` | `(0,0)` | spring placement cell |
| `_inject_village_well()` | `herbalist_remedy` / (no objective — skip) | — | — |
| `_inject_moonstone_mine()` | `herbalist_remedy` / `enter_mine` | `(0,0)` | mine entrance cell |
| `_maybe_inject_mara()` | `herbalist_remedy` / `show_evidence` + `return_mara` | `(0,0)` | Mara's cell |

Since `show_evidence` and `return_mara` share the same position (Mara), both are registered at that cell. `get_objective_markers()` returns the first incomplete one.

**Star drawing in `WorldMapView._draw()`:**

```gdscript
## Draw quest objective star markers.
const OBJECTIVE_STAR_COLOR: Color = Color(1.0, 0.85, 0.1, 1.0)  # gold

func _draw_objective_markers(map_origin: Vector2, tile_px: float) -> void:
    var markers: Array[Dictionary] = QuestTracker.get_objective_markers()
    for m in markers:
        var quest_id: String = m["quest_id"]
        var obj_id: String = m["obj_id"]
        if QuestTracker.get_objective_progress(quest_id, obj_id) > 0:
            continue  # already completed
        var rid: Vector2i = m["region_id"]
        var cell: Vector2i = m["cell"]
        var spos: Vector2 = map_origin + Vector2(rid.x * 128 + cell.x, rid.y * 128 + cell.y) * tile_px
        _draw_star(spos, 6.0, OBJECTIVE_STAR_COLOR)
        break  # only the first active marker

func _draw_star(center: Vector2, radius: float, color: Color) -> void:
    var points: PackedVector2Array = PackedVector2Array()
    for i in 10:
        var angle: float = (float(i) * PI / 5.0) - PI / 2.0
        var r: float = radius if i % 2 == 0 else radius * 0.45
        points.append(center + Vector2(cos(angle), sin(angle)) * r)
    draw_polygon(points, PackedColorArray([color]))
```

**Drawn on top of fog:** The star renders after the fog layer, always visible regardless of whether the player has explored that area. Quest knowledge (Mara directing you to the mine) is separate from map exploration — the player knows *where* to go, they just can't see the surrounding terrain yet.

**No dungeon map markers for now** — `seal_leak` and `get_evidence` are inside the labyrinth; the dungeon map is a separate `DungeonMapView` and out of scope for this spec.

---

## Files Changed

| File | Change |
|---|---|
| `resources/quests/herbalist_remedy.json` | Replace 3 branches → 1 `main` branch (8 objectives); update `requires` block |
| `resources/dialogue/healer_mara.tres` | Phase-aware linear rework (regenerated from seed script) |
| `tools/seed_healer_mara.gd` | Rework dialogue tree to match new flow |
| `scripts/autoload/quest_tracker.gd` | Auto-flags on objective completion; `register_objective_position` + `get_objective_markers` API |
| `scripts/entities/villager.gd` | `_try_quest_turn_in` advances only first incomplete talk objective per visit |
| `scripts/world/world_root.gd` | `_inject_birch_grove`, `_inject_village_well`, sick wolf/rat scatter; register positions with QuestTracker |
| `scripts/ui/world_map_view.gd` | `_draw_objective_markers()` + `_draw_star()` for active quest objectives |
| `resources/creature_sprites.json` | Add `sick_wolf` entry (wolf sprite, greenish-grey tint) |
| `tests/unit/test_quest_wiring.gd` | Replace branch-specific tests with `main`-branch + sequential-talk + auto-flag tests |

**Already done (this session):**
| File | Change |
|---|---|
| `scripts/world/world_root.gd` `_inject_spring` | Switched from blue placeholder to `world_objects` sheet cell [6, 0] |
| `resources/world_objects.json` | Created with 8 entries (spring, village_well, mine_entrance, etc.) |
| `assets/icons/hires/world_objects.png` | Generated (8 stub tiles, burnt-orange sentinel) |
| `assets/icons/hires/world_objects_cells.json` | Generated (stable cell assignments) |
| `tools/gen_hires_sheet.py` | Added `world_objects` category |
| `.github/skills/world-objects-sprite-sheet/SKILL.md` | New skill |
| `.github/skills/*/SKILL.md` | Converted 5 flat files → directory/SKILL.md format |
| `.github/copilot-instructions.md` | Added `<skills>` XML block registering all 6 project skills |

**No changes needed to:**
- `items.json` / `.tres` files (all quest items exist)
- `mineables.json` (`blue_nightcap_mushroom` exists)
- `labyrinth_generator.gd`
- `quest_tracker.gd` reward `give_item` (already works)

## Out of Scope

- Spring or mine_leak visual art (stub tiles remain until art is created; `world_objects` sheet is ready)
- `birch_grove` exact tile cell selection (needs SpritePicker to pick the right overworld tree tile variant)

## Success Criteria

1. Quest starts when player accepts via any dialogue path (auto via `quest_herbalist_main` trigger flag)
2. Entering the labyrinth advances `enter_mine`
3. Opening the boss-room chest advances `seal_leak` and `get_evidence` simultaneously
4. Returning to Mara with ore advances `show_evidence` only (not `return_mara`)
5. `GameState` flag `quest_herbalist_remedy_obj_show_evidence_done` is set after step 4
6. Collecting herbs/water via mineables and spring advances their collect objectives
7. Returning to Mara with all ingredients advances `return_mara` → `complete_quest()` fires
8. `tonic` given to player; `antidote_recipe` only given if `quest_herbalist_pushed_deal` is set
9. Sick wolves and rats are present between birch grove and mine entrance
10. Village well gives flavour text on interact
11. World map shows a gold star at the first incomplete objective location, drawn on top of fog
12. Star advances to next objective location as objectives complete (mine → Mara → spring → Mara)
14. All unit tests in `test_quest_wiring.gd` pass
