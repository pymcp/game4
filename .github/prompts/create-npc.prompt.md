---
description: Create a new NPC with dialogue, world spawning, and optional quest integration. Use when asked to add an NPC, villager, character, or quest giver.
---

# Create an NPC

You are creating a new NPC for a Godot 4.3 fantasy sandbox game. NPCs are `Villager` instances with dialogue trees, spawned into the world via the scatter system.

## Step 1: Gather Requirements

Before writing any code, ask the user for:
- **Name** and personality/role (e.g. "Bram, a gruff carpenter")
- **Location** — where should they spawn? Near a landmark, pass point, spawn, etc.
- **Dialogue** — what do they say? Is it a one-liner or a branching tree?
- **Quest integration** — do they give or advance a quest? Which one?
- **Appearance seed** — or let it be random? (Villagers use `CharacterBuilder` paper-doll from `npc_seed`)

## Step 2: Understand the Entity Types

There are TWO NPC types in this game. Pick the right one:

| Type | Script | Scene | Purpose | Has Dialogue? |
|------|--------|-------|---------|---------------|
| **Villager** | `scripts/entities/villager.gd` | `scenes/entities/Villager.tscn` | Peaceful NPC, wanders near home | Yes — `@export var dialogue_tree: DialogueTree` |
| **NPC** | `scripts/entities/npc.gd` | Uses `Monster.tscn` | Hostile mob with AI states | No — combat only |

**Quest givers and friendly NPCs are always `Villager` instances.** The `NPC` class is for hostile mobs only.

### Villager Key Properties
```gdscript
@export var npc_seed: int = 0          # Deterministic appearance via CharacterBuilder
@export var home_cell: Vector2i        # Wander center
@export var wander_radius: int = 6     # Tiles from home_cell
@export var dialogue_tree: DialogueTree  # Set at spawn time from .tres path
```

### Villager Interaction
When a player presses interact near a Villager, `Villager.interact(player)` is called:
- If `dialogue_tree != null` → opens branching dialogue via `_world.show_dialogue_tree()`
- Otherwise → shows a one-liner from `VillagerDialogue.pick_line(npc_seed)`

## Step 3: Create or Update the Dialogue Tree

If the NPC has branching dialogue, create a seed script at `tools/seed_<npc_name>.gd`.

See the **create-questline** skill for full dialogue seed script patterns. Key points:
- Extends `SceneTree`, builds tree in `_init()`, saves to `res://resources/dialogue/<npc_name>.tres`
- Use `_leaf()`, `_choice()`, `_choice_stat()`, `_choice_flag()` helpers
- Quest-accepting choices MUST set branch-specific trigger flags
- Use `condition_flag` on DialogueNodes for return-visit state branching
- Run with: `godot --headless -s tools/seed_<npc_name>.gd`

For simple one-liner NPCs, skip the seed script entirely — the Villager will use the fallback dialogue system.

## Step 4: Register the NPC in World Spawning

NPCs spawn via the scatter system in `scripts/world/world_root.gd`. There are two approaches:

### Approach A: Deterministic Injection (for quest-critical NPCs)

Add a method like `_maybe_inject_<npc_name>()` in `world_root.gd`, called from `_spawn_scattered_npcs()`. Follow the Mara pattern:

```gdscript
func _maybe_inject_<npc_name>() -> void:
    # Only on overworld starting region.
    if _interior != null or _region == null:
        return
    var rid: Vector2i = _region.region_id
    if abs(rid.x) > 1 or abs(rid.y) > 1:
        return
    # Check if already in scatter list.
    for entry in _region.npcs_scatter:
        if typeof(entry) == TYPE_DICTIONARY \
                and entry.get("dialogue", "") == "res://resources/dialogue/<npc_name>.tres":
            return
    # Place near a landmark or spawn point.
    if _region.spawn_points.is_empty():
        return
    var centre: Vector2i = _region.spawn_points[0]
    var cell: Vector2i = find_safe_spawn_cell(centre + Vector2i(<offset_x>, <offset_y>), 4, true)
    _region.npcs_scatter.append({
        "kind": &"villager",
        "cell": cell,
        "seed": <deterministic_hex_seed>,
        "dialogue": "res://resources/dialogue/<npc_name>.tres",
    })
```

**Call order in `_spawn_scattered_npcs()`:**
```gdscript
func _spawn_scattered_npcs() -> void:
    _maybe_inject_mara()
    _maybe_inject_<npc_name>()   # Add new NPCs here
    # ... rest of scatter loop
```

### Approach B: Biome-driven Random Scatter (for ambient villagers)

Add the NPC kind to `BiomeDefinition.npc_kinds` in the appropriate biome. The `WorldGenerator._scatter_npcs()` will place them randomly. These won't have quest dialogue.

### Scatter Entry Format
```gdscript
{
    "kind": &"villager",        # Must be &"villager" for dialogue NPCs
    "cell": Vector2i(x, y),     # Grid cell position
    "seed": int,                 # Deterministic appearance seed
    "dialogue": "res://resources/dialogue/<name>.tres",  # Optional .tres path
}
```

### How Villagers Are Instantiated
`_spawn_villager(entry)` in `world_root.gd`:
1. Instantiates `Villager.tscn`
2. Sets `npc_seed`, `home_cell`, `position` from the scatter entry
3. If `entry["dialogue"]` is set, loads the `.tres` and assigns `v.dialogue_tree`
4. Adds to `&"scattered_npcs"` group and to `entities` node

## Step 5: Write Tests

### For dialogue-bearing NPCs:
```gdscript
# In tests/unit/ or tests/integration/
func test_<npc_name>_dialogue_tree_builds() -> void:
    # Verify the seed script produces a valid tree
    var tree: DialogueTree = load("res://resources/dialogue/<npc_name>.tres")
    assert_not_null(tree, "dialogue tree should load")
    assert_not_null(tree.root, "should have a root node")
    var root: DialogueNode = tree.root as DialogueNode
    assert_eq(root.speaker, "<NPC Name>")
    assert_true(root.choices.size() > 0, "root should have choices")
```

### For quest-giving NPCs:
Also add quest tests — see the **create-questline** skill.

### For spawn injection:
```gdscript
# In tests/integration/
func test_<npc_name>_injected_in_starting_region() -> void:
    # Generate the starting region and check scatter list
    var region: Region = WorldManager.get_or_generate(Vector2i(0, 0))
    # Trigger injection (via world_root or manually)
    var has_npc: bool = false
    for entry in region.npcs_scatter:
        if typeof(entry) == TYPE_DICTIONARY \
                and entry.get("dialogue", "") == "res://resources/dialogue/<npc_name>.tres":
            has_npc = true
            break
    assert_true(has_npc, "<NPC Name> should be injected in starting region")
```

## Step 6: Run the Seed Script and Tests

```bash
# Generate the .tres dialogue file
godot --headless -s tools/seed_<npc_name>.gd

# Run tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## Step 7: Update Documentation

- Add NPC to `.github/copilot-instructions.md` (Dialogue System section or a new NPCs section)
- If the NPC gives a quest, make sure the quest's `requires.npcs` entry has `"status": "IMPLEMENTED"`
- If the NPC has a sprite, make sure it's available in the sprite tool

## Checklist Before Done

- [ ] NPC type chosen (Villager for friendly, NPC for hostile)
- [ ] Dialogue seed script created (if branching dialogue)
- [ ] `.tres` file generated by running the seed script
- [ ] Spawn injection method added to `world_root.gd` (for quest-critical NPCs)
- [ ] Quest JSON `requires.npcs` entry updated to `IMPLEMENTED` (if quest-giving)
- [ ] Tests written and passing
- [ ] `.github/copilot-instructions.md` updated
