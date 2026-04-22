# Monsters & Loot

## Monster (`scripts/entities/monster.gd`, 110 lines)

Lightweight hostile entity with naive chase AI.

**Signal:** `died(world_position: Vector2, drops: Array)`

**Groups:** `&"monsters"`, `&"scattered_npcs"`

### Properties

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `max_health` | `int` | `3` | Set from LootTableRegistry at spawn |
| `health` | `int` | `3` | Current HP |
| `drops` | `Array` | `[]` | Explicit drops (override loot table) |
| `resistances` | `Dictionary` | `{}` | Element int → float multiplier |
| `monster_kind` | `StringName` | `&"slime"` | Key into LootTableRegistry |

**Constants:** `SIGHT_RADIUS_TILES = 8.0`, `_MOVE_SPEED_PX_PER_S = 32.0`

### Behavior

- **Chase AI:** Steps directly toward nearest player within `SIGHT_RADIUS_TILES`. No pathfinding (unlike NPC).
- **`take_hit(damage, attacker, element)`:** Applies resistance, reduces health, calls `_die()` at 0.
- **`_die()`:** Emits `died` with position + drops. If `drops` array is empty, rolls from `LootTableRegistry.roll_drops(monster_kind)`.
- **Resistance:** `_apply_resistance(damage, element)` — see Equipment-Stats-Combat skill for formula.

---

## NPC (`scripts/entities/npc.gd`, 267 lines)

More complex hostile/neutral entity with pathfinding and state machine.

**Signal:** `died(world_position: Vector2, drops: Array)`

**Enum:** `State { IDLE, WANDER, CHASE, ATTACK, DEAD }`

### Key Properties

| Field | Default | Notes |
|-------|---------|-------|
| `kind` | — | Creature identifier |
| `hostile` | `false` | Attacks on sight if true |
| `max_health` | `5` | |
| `attack_damage` | `1` | |
| `sight_radius_tiles` | `6.0` | |
| `attack_range_tiles` | `1.25` | |
| `leash_radius_tiles` | `10.0` | Returns to origin beyond this |
| `drops` | `[]` | |
| `resistances` | `{}` | Same system as Monster |

### State Machine

`decide_state()` is static and pure (testable). Transitions:
- IDLE → WANDER (after 1.5s)
- WANDER → CHASE (hostile + player in sight)
- CHASE → ATTACK (player in attack range)
- CHASE → IDLE (player beyond leash)
- ATTACK → CHASE (player leaves range)
- Any → DEAD (health ≤ 0)

Uses `Pathfinder.find_path()` for CHASE movement (contrast: Monster uses naive direct walk).

---

## LootTableRegistry (`scripts/data/loot_table_registry.gd`, 122 lines)

Static registry loading `resources/loot_tables.json`.

### Public API

| Method | Returns | Notes |
|--------|---------|-------|
| `has_table(kind: StringName)` | `bool` | |
| `get_table(kind: StringName)` | `Dictionary` | Full entry |
| `all_kinds()` | `Array` | All registered creature kinds |
| `get_health(kind)` | `int` | Default HP for this kind |
| `get_resistances(kind)` | `Dictionary` | Element → multiplier |
| `roll_drops(kind, rng?)` | `Array[{id, count}]` | Weighted random rolls |
| `reset()` | | Clear cache |

### Roll Algorithm

`roll_drops(kind, rng)`:
1. Reads `drop_count` (how many independent rolls) and `drop_chance` (probability per roll)
2. For each roll: random float < `drop_chance` → `_weighted_pick(rng, table)` → append `{id, count: 1}`
3. Returns array of dropped items (may be empty)

`_weighted_pick(rng, table)`: Standard cumulative weight selection over `{id, weight}` entries.

---

## Creature Kinds (`resources/loot_tables.json`)

8 creature kinds defined:

| Kind | HP | Drops | Chance | Resistances |
|------|----|-------|--------|-------------|
| `slime` | 3 | 1 | 70% | — |
| `skeleton` | 5 | 1 | 80% | — |
| `goblin` | 4 | 1 | 75% | — |
| `bat` | 2 | 1 | 40% | — |
| `wolf` | 5 | 1 | 60% | — |
| `ogre` | 12 | 2 | 90% | Poison 0.5× |
| `fire_elemental` | 8 | 1 | 85% | Fire immune, Ice 2× |
| `ice_elemental` | 8 | 1 | 85% | Ice immune, Fire 2× |

### Adding a New Creature Kind

1. Add entry to `resources/loot_tables.json`:
   ```json
   "my_creature": {
     "display_name": "My Creature",
     "health": 6,
     "resistances": {},
     "drop_count": 1,
     "drop_chance": 0.7,
     "table": [
       {"id": "iron_ore", "weight": 20},
       {"id": "gold_ore", "weight": 5}
     ]
   }
   ```
2. Ensure all `id` values in `table` exist in `resources/items.json`
3. `LootTableRegistry.reset()` to pick up changes
4. Use `monster_kind = &"my_creature"` on Monster instances
5. World spawning auto-routes unknown creature kinds through LootTableRegistry fallback in `_spawn_scattered_npcs()`

---

## Dungeon Loot (`resources/dungeon_loot.json`)

Flat weighted table for dungeon floor scatter (not creature-keyed):

| Item | Weight | Count Range |
|------|-------:|-------------|
| wood | 25 | 1-3 |
| stone | 25 | 1-3 |
| fiber | 20 | 1-4 |
| iron_ore | 10 | 1-2 |
| copper_ore | 10 | 1-2 |
| gold_ore | 3 | 1-1 |
| fennel_root | 5 | 1-2 |
| wooden_sword | 4 | 1-1 |
| iron_dagger | 3 | 1-1 |

Loaded by `DungeonGenerator._get_loot_table()`. Scattered via `_scatter_loot(rng, m, rooms)` — 60% chance per non-entry room.

---

## World Integration (`scripts/world/world_root.gd`)

### Monster Spawning

1. `_spawn_scattered_npcs()` iterates npc scatter list
2. Kind `&"monster"` or any kind with `LootTableRegistry.has_table(kind)` → `_spawn_monster(entry)`
3. `_spawn_monster()`:
   - Instantiates Monster scene at `cell * TILE_PX`
   - Sets `monster_kind`, `max_health`, `health`, `resistances` from LootTableRegistry
   - Connects `died` signal

### Monster Death → Loot Drops

`_on_monster_died(world_position, drops)`:
- For each `{id, count}` in drops: creates `LootPickup`, positions at `world_position` ± random 8px scatter
- Adds to `entities` node

### Dungeon Floor Loot

`_materialize_loot_scatter()`:
- Called during interior/dungeon loading
- Iterates `_interior.loot_scatter`
- Creates `LootPickup` per entry

---

## Test Considerations

- `LootTableRegistry.reset()` between tests
- Seeded `RandomNumberGenerator` for deterministic `roll_drops` testing
- Monster `died` signal carries `(Vector2, Array)` — connect in tests to capture drops
- NPC `decide_state()` is static/pure — test state transitions without scene tree
