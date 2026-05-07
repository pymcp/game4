# Mara's Quest — Linear Rework Design
**Date:** 2026-05-06  
**Branch:** `feature/mara-quest-improvements`  
**Status:** Approved

## Problem

`herbalist_remedy` has a solid design but broken branching. The three-branch structure (herbs / mine / both) lets the player skip the mine entirely, breaking the intended "diagnose then cure" narrative. Additionally, several quest elements assumed to be missing are already implemented.

## Goal

Make the quest fully playable with a single linear narrative arc:  
**talk to Mara → enter mine → defeat boss → collect contaminated ore (evidence) → gather cure herbs + spring water → return to Mara**

## What Already Works (Do Not Touch)

| System | Status |
|--------|--------|
| `QuestInteractable` node + scene | ✅ Exists |
| Spring placement near spawn (`_inject_spring`) | ✅ Already placed with correct quest/objective wiring |
| Mine leak chest (`_spawn_mine_leak` on boss death) | ✅ Already spawned, wired to `seal_leak` + gives `contaminated_ore` |
| `moonstone_mine` labyrinth entrance injection | ✅ Already placed east of spawn |
| `QuestTracker` API (start/advance/complete/give_item) | ✅ Fully implemented |
| `WorldRoot._on_choice_selected` → auto `start_quest()` | ✅ Triggered by `choice.set_flag` matching a branch `trigger_flag` |
| All 6 quest items in `items.json` | ✅ Present |
| `blue_nightcap_mushroom` in `mineables.json` | ✅ Present |
| Villager `_try_quest_turn_in` (handles `talk` objectives) | ✅ Implemented on Mara |

## Changes Required

### 1. `resources/quests/herbalist_remedy.json`

Replace the three branches (`herbs`, `mine`, `both`) with a single `main` branch.

**New branch `main` objectives (in order):**

| # | id | type | detail | description |
|---|---|---|---|---|
| 1 | `enter_mine` | reach | `moonstone_mine` | Enter the moonstone mine |
| 2 | `seal_leak` | interact | target: `mine_leak` | Seal the contamination source |
| 3 | `get_evidence` | collect | `contaminated_ore` × 1 | Collect contaminated ore as evidence |
| 4 | `get_fennel` | collect | `fennel_root` × 1 | Gather fennel root |
| 5 | `get_mushroom` | collect | `blue_nightcap` × 1 | Gather blue nightcap mushrooms |
| 6 | `get_water` | collect | `clean_spring_water` × 1 | Collect clean spring water |
| 7 | `return_mara` | talk | npc: `Mara` | Return to Mara |

`trigger_flag: "quest_herbalist_main"`

> **Note on objectives 2+3:** The mine_leak TreasureChest marks `seal_leak` done via `quest_objective_id` and gives `contaminated_ore` via `fixed_loot`. `notify_item_collected` then auto-advances `get_evidence`. Both objectives complete from a single chest interaction.

**Reward variants (updated — condition flag changes):**

- `deal_basic`: always applies on completion (remove old `condition_flag: "quest_herbalist_mine"`) — gives `tonic` × 1
- `deal_push`: change condition from `quest_herbalist_mine` → `quest_herbalist_pushed_deal` (CHA≥5 choice during intro) — gives `tonic` × 1 + `antidote_recipe` × 1

**`requires` block:** Mark all previously `NOT_IMPLEMENTED` items as `IMPLEMENTED`. Remove `birch_grove` and `village_well` (cosmetic, out of scope). Retain `sick_wolf` / `feral_animal` as `NOT_IMPLEMENTED` (flavour enemies, future work).

---

### 2. `resources/dialogue/healer_mara.tres` + `tools/seed_healer_mara.gd`

Rework the dialogue tree. Remove branch-selection choices. Replace with a linear intro that accepts the quest and optionally sets `quest_herbalist_pushed_deal`.

**New dialogue flow:**

```
[ROOT] "Ah, traveller. The valley is sick and I fear I know why."
  ├─ [require: quest_herbalist_remedy_complete]
  │   "How is the valley?" → completion node
  ├─ [require: quest_herbalist_main (active)]
  │   "Any progress on the sickness?" → progress reminder node
  └─ "Tell me more." → lore intro node

[LORE INTRO] "The water is poisoned — moonstone seeping from the old mine east of here.
              Animals drink from the streams and fall ill. Three villages have lost livestock this moon."
  ├─ [WIS≥4] "Could the ore itself be toxic?" → detailed explanation node
  │     → "Precisely. Fractured moonstone leaches into groundwater. The mine was sealed
  │        twenty years ago, but something has broken through."
  │        → [OFFER]
  └─ "What needs to be done?" → [OFFER]

[OFFER] "I need someone to seal the leak at its source and gather a few ingredients for the remedy.
         Fennel root, blue nightcap mushrooms, and spring water — once the mine is sealed."
  ├─ [CHA≥3] "What's in it for me?" → negotiate node
  │     ├─ [CHA≥5] "I want the tonic AND your antidote recipe."
  │     │     → set_flag: quest_herbalist_pushed_deal
  │     │     → "You drive a hard bargain. Fine — bring me proof and I'll give you both."
  │     │        → [ACCEPT] set_flag: quest_herbalist_main
  │     └─ "Fair enough. I'll do it."
  │           → [ACCEPT] set_flag: quest_herbalist_main
  └─ "I'll help." → [ACCEPT] set_flag: quest_herbalist_main

[ACCEPT] "Start with the mine — it's east past the birch grove.
          Watch for sick wolves; they don't run from people anymore.
          Once the leak is sealed, gather the herbs and return to me."
  → (dialogue ends, quest started via WorldRoot._on_choice_selected)

[PROGRESS REMINDER — requires quest_herbalist_main, not complete]
  "Have you sealed the mine yet? The herbs won't cure a thing if the water stays poisoned."

[COMPLETION — requires quest_herbalist_remedy_complete]
  "The valley owes you a debt it can never repay. The animals are recovering
   and the water runs clear again. If you ever need a tonic, you know where to find me."
```

---

### 3. `tests/unit/test_quest_wiring.gd`

Replace all tests referencing branches `herbs`, `mine`, `both` with `main`-branch equivalents:

| Old test | New test |
|---|---|
| `test_trigger_flag_herbs` | `test_trigger_flag_main` — asserts `quest_herbalist_main` → `("herbalist_remedy", "main")` |
| `test_trigger_flag_mine` | Remove |
| `test_trigger_flag_both` | Remove |
| `test_herbs_branch_collect_flow` | `test_main_branch_collect_flow` — start `main`, advance all 7 objectives, complete |
| `test_mine_branch_location_reached` | Merge into `test_main_branch_collect_flow` |
| `test_both_branch_collects_from_both_branches` | Remove |

New tests to add:
- `test_pushed_deal_reward_variant` — start `main`, set `quest_herbalist_pushed_deal` flag, complete → assert `antidote_recipe` reward path active
- `test_mine_leak_advances_two_objectives` — `mark_objective_done("seal_leak")` + `notify_item_collected("contaminated_ore")` both advance correctly in a single pass

---

## Files Changed

| File | Change |
|---|---|
| `resources/quests/herbalist_remedy.json` | Replace 3 branches → 1 `main` branch; update `requires` block |
| `resources/dialogue/healer_mara.tres` | Linear rework (regenerated from seed script) |
| `tools/seed_healer_mara.gd` | Rework dialogue tree to match new flow |
| `tests/unit/test_quest_wiring.gd` | Replace branch-specific tests with `main`-branch tests |

**No changes needed to:**
- `items.json` / `.tres` files
- `mineables.json`
- `world_root.gd` (spring + mine_leak already correct)
- `labyrinth_generator.gd`
- `quest_tracker.gd`
- `quest_interactable.gd`

## Out of Scope

- `birch_grove` and `village_well` landmark placement
- `sick_wolf` / `feral_animal` hostile mobs
- Spring or mine_leak visual polish (placeholder sprites remain)

## Success Criteria

1. Quest starts when player accepts via any dialogue path (auto via `quest_herbalist_main` trigger flag)
2. Entering the labyrinth advances `enter_mine`
3. Opening the boss-room chest advances `seal_leak` and `get_evidence` simultaneously
4. Collecting herbs/water via mineables and spring advances their collect objectives
5. Returning to Mara completes all objectives and triggers `complete_quest()`
6. `tonic` is given; `antidote_recipe` only given if `quest_herbalist_pushed_deal` is set
7. All unit tests in `test_quest_wiring.gd` pass
