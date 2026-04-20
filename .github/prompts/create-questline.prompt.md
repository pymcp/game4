---
description: Create a new questline with JSON data, dialogue tree seed script, and unit tests. Use when asked to add a quest, questline, or mission.
---

# Create a Questline

You are creating a new questline for a Godot 4.3 fantasy sandbox game. Follow this process exactly.

## Step 1: Gather Requirements

Before writing any code, ask the user for:
- **Quest giver NPC** — name, personality, role
- **Quest hook** — what problem does the NPC present?
- **Branches** — are there multiple ways to complete it? (gather, fight, investigate, etc.)
- **Objectives per branch** — what does the player actually do? Types: `collect`, `talk`, `reach`, `interact`
- **Rewards** — flags, items, passage unlocks?
- **Prerequisites** — must another quest be completed first?
- **Stat gates** — any choices gated by strength/charisma/wisdom?

## Step 2: Create the Quest JSON File

Create `resources/quests/<quest_id>.json` following this schema exactly:

```json
{
  "id": "<quest_id>",
  "display_name": "Human-readable Name",
  "giver": "NPC Name",
  "description": "One-sentence quest summary.",
  "prerequisites": [],
  "branches": {
    "<branch_id>": {
      "display_name": "Branch Name",
      "description": "What this path involves.",
      "trigger_flag": "quest_<quest_id>_<branch_id>",
      "objectives": [
        {"id": "<obj_id>", "type": "collect", "item": "<item_id>", "count": 1, "description": "..."},
        {"id": "<obj_id>", "type": "talk", "npc": "NPC Name", "description": "..."},
        {"id": "<obj_id>", "type": "reach", "location": "<location_id>", "description": "..."},
        {"id": "<obj_id>", "type": "interact", "target": "<target_id>", "description": "..."}
      ],
      "rewards": [
        {"type": "flag", "flag": "<flag_name>"},
        {"type": "give_item", "item": "<item_id>", "count": 1},
        {"type": "unlock_passage", "passage_id": "<passage_id>"}
      ]
    }
  },
  "reward_variants": {},
  "requires": {
    "npcs": [{"id": "Name", "role": "...", "location_hint": "...", "status": "NOT_IMPLEMENTED"}],
    "items": [{"id": "item_id", "source": "how player gets it", "status": "NOT_IMPLEMENTED"}],
    "locations": [{"id": "loc_id", "type": "dungeon|terrain_landmark|interaction_point", "description": "...", "status": "NOT_IMPLEMENTED"}],
    "entities": [{"id": "entity_id", "type": "hostile_mob", "description": "...", "status": "NOT_IMPLEMENTED"}],
    "terrain_features": [{"id": "feature_id", "type": "interactable", "description": "...", "status": "NOT_IMPLEMENTED"}],
    "dialogue_updates": [{"id": "update_id", "description": "...", "status": "NOT_IMPLEMENTED"}],
    "notes": "Free-text notes."
  }
}
```

### Critical Rules for Quest JSON
- `id` must be snake_case, unique across all quests
- `trigger_flag` pattern: `quest_<quest_id>_<branch_id>`
- Every NPC, item, location, entity, and terrain feature referenced ANYWHERE in the quest must have an entry in `requires` with a `status` field
- Items the player needs to collect AND items given as rewards both go in `requires.items`
- If a branch merges objectives from other branches, use `"includes": ["branch_a", "branch_b"]` instead of duplicating objectives
- Stat-gated branches use `"gate": {"stat": "<stat_name>", "min": <int>}`
- Reward variants (stat-gated bonus rewards) go in `reward_variants` with `condition_flag` and optional `gate`

## Step 3: Create the Dialogue Seed Script

Create `tools/seed_<npc_snake_name>.gd` (or update existing one). Pattern:

```gdscript
## seed_<npc_name>.gd
##
## Run once headless:
##   godot --headless -s tools/seed_<npc_name>.gd
##
## Builds and saves <NPC Name>'s dialogue tree to
## `res://resources/dialogue/<npc_name>.tres`.
extends SceneTree

func _init() -> void:
    # Build leaf nodes bottom-up, then intermediate nodes, then root.
    # ...
    var tree := DialogueTree.new()
    tree.root = root
    DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path("res://resources/dialogue"))
    var err: int = ResourceSaver.save(tree, "res://resources/dialogue/<npc_name>.tres")
    if err == OK:
        print("OK — saved res://resources/dialogue/<npc_name>.tres")
    else:
        push_error("Failed to save: error %d" % err)
    quit()
```

### Dialogue Helpers (copy into each seed script)
```gdscript
func _leaf(speaker: String, text: String) -> DialogueNode:
    var n := DialogueNode.new()
    n.speaker = speaker
    n.text = text
    return n

func _choice(label: String, next: DialogueNode, set_flag: String = "") -> DialogueChoice:
    var c := DialogueChoice.new()
    c.label = label
    c.next_node = next
    c.set_flag = set_flag
    return c

func _choice_stat(stat: StringName, threshold: int, label: String,
        success: DialogueNode, failure: DialogueNode = null,
        flag: String = "") -> DialogueChoice:
    var c := DialogueChoice.new()
    c.label = label
    c.stat_check = stat
    c.stat_threshold = threshold
    c.next_node = success
    if failure != null:
        c.failure_node = failure
    if flag != "":
        c.set_flag = flag
    return c

func _choice_flag(label: String, next: DialogueNode, flag: String) -> DialogueChoice:
    var c := DialogueChoice.new()
    c.label = label
    c.next_node = next
    c.set_flag = flag
    return c
```

### Dialogue Rules
- **Every quest-accepting choice MUST set a branch-specific trigger flag** matching the quest JSON's `trigger_flag` (e.g. `quest_herbalist_herbs`). Never use a generic `quest_X_started` flag — the QuestTracker sets that automatically.
- Stat-gated choices that accept a quest must ALSO set the flag — use the `flag` parameter on `_choice_stat()`.
- Build the tree bottom-up: leaf nodes first, then intermediate, then root.
- Use `condition_flag` / `condition_flag_false` on DialogueNodes for return-visit branching.
- Always provide a stat-check failure path (even if it's just a polite refusal).

## Step 4: Write Unit Tests

Add tests to `tests/unit/test_quest_system.gd` (or a new file) covering:
1. `QuestRegistry.get_quest("<quest_id>")` returns expected fields
2. Each branch resolves correctly via `QuestRegistry.get_branch()`
3. `get_unimplemented_requirements()` returns all NOT_IMPLEMENTED entries
4. `QuestTracker` lifecycle: start → advance objectives → ready check → complete
5. Completion sets expected GameState flags
6. Serialization roundtrip preserves state

### Test Pattern
```gdscript
func test_<quest_id>_loads() -> void:
    QuestRegistry.reload()
    var quest: Dictionary = QuestRegistry.get_quest("<quest_id>")
    assert_eq(quest["id"], "<quest_id>")
    assert_eq(quest["giver"], "<NPC Name>")

func test_<quest_id>_<branch>_objectives() -> void:
    QuestRegistry.reload()
    var branch: Dictionary = QuestRegistry.get_branch("<quest_id>", "<branch_id>")
    assert_eq(branch["objectives"].size(), <expected_count>)

func test_<quest_id>_tracker_lifecycle() -> void:
    GameState.clear_flags()
    QuestRegistry.reload()
    QuestTracker.reset()
    QuestTracker.start_quest("<quest_id>", "<branch_id>")
    assert_true(QuestTracker.is_quest_active("<quest_id>"))
    # Advance all objectives...
    QuestTracker.mark_objective_done("<quest_id>", "<obj_id>")
    # ...
    assert_true(QuestTracker.is_quest_ready_to_complete("<quest_id>"))
    QuestTracker.complete_quest("<quest_id>")
    assert_true(GameState.get_flag("quest_<quest_id>_complete"))
    GameState.clear_flags()
```

## Step 5: Run Tests

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

## Step 6: Update copilot-instructions.md

Add the new quest to the "Existing Quests" list in `.github/copilot-instructions.md` under the Quest System section.

## Checklist Before Done

- [ ] Quest JSON created in `resources/quests/`
- [ ] Every referenced item/NPC/location/entity has a `requires` entry with `status`
- [ ] Dialogue seed script created/updated in `tools/`
- [ ] Every quest-accepting dialogue choice sets the correct branch trigger flag
- [ ] Unit tests written and passing
- [ ] `.github/copilot-instructions.md` updated with new quest entry
