# Housing Construction System

**Date:** 2026-04-30  
**Status:** Approved

---

## Overview

Add a Builder party member to the caravan. The builder enables players to construct houses in the overworld by spending resources. Construction uses a ghost-placement flow: the caravan menu closes, the player moves a cursor around to position the house, and confirms with the interact key. The placed house is indistinguishable from world-generated houses — it uses the same door tile, `HouseGenerator`, and `MapManager` interior pipeline.

---

## 1. Data Model

### `resources/party_members.json` — new `builder` entry

```json
"builder": {
  "id": "builder",
  "display_name": "Builder",
  "crafter_domain": "builder",
  "portrait_cell": [0, 0],
  "can_follow": false,
  "builds": [
    {
      "id": "house_basic",
      "display_name": "Basic House",
      "cost": { "wood": 10 }
    }
  ]
}
```

`PartyMemberDef` gains an optional `@export var builds: Array = []` field (plain Array of Dicts — no new Resource class needed). `PartyMemberRegistry._build_cache()` passes it through as-is via `entry.get("builds", [])`.

### `resources/items.json` — no changes needed

`wood` and `stone` already exist as stackable materials.

### Persistence

**No new `SaveGame` field needed.** `Region.dungeon_entrances` is already saved automatically as part of `WorldManager.regions` in `SaveGame.snapshot()`. Appending a house entry to the live region's `dungeon_entrances` persists through the normal save/load cycle without any additional work.

### Debug seeding (F8)

No changes. `World.debug_add_all_party_members()` adds all JSON-registered members — once `builder` is in the JSON it's included automatically.

---

## 2. CaravanMenu UI

### Party roster — vertical portrait cards

Replace the current text-only `Button` list with a `GridContainer` (3 columns) of vertical member cards. Each card is a `Button` with `text = ""` and an inner `VBoxContainer`:

```
[ portrait — 32×32 clipped Control ]
[ Name label ]                        ← rolled name from CaravanData
[ Role label ]                        ← dim color, smaller font (e.g. "Builder")
```

`MembersContainer` in `CaravanMenu.tscn` changes type from `VBoxContainer` to `GridContainer` (columns=3). The `@onready var _members_container` type annotation changes to `GridContainer`.

Portrait sources:
- **All non-pet members**: `CharacterBuilder.build(opts)` with a deterministic appearance seeded from `hash(CaravanData.get_member_name(id))`. Node2D scaled to 0.5 and clipped inside a 32×32 Control (`clip_contents = true`).
- **Active pet**: `CreatureSpriteRegistry.build_sprite(active_species)` Sprite2D, same 32×32 container. Species read from `GameSession.p*_active_pet`.

Clicking a card selects it and populates the existing right-side detail panel.

### Builder detail panel (right side when builder selected)

When `_on_member_selected` receives a member with `crafter_domain == "builder"`, it creates a `BuilderPanel` instead of a `CrafterPanel`:

```
Builder
──────────────────────
Structures

  Basic House          10 wood  [Build]
```

- Cost label: green if caravan inventory has enough, red if not.
- Build button: disabled + grayed if cost not met.
- On "Build" press:
  1. `BuilderPanel` calls a callback/signal back to `CaravanMenu`.
  2. `CaravanMenu.close()`.
  3. `CaravanMenu` emits `build_requested(player_id, structure_id)`.
  4. `Game` connects this signal to `World.start_house_placement(pid, structure_id)`.
  5. `ControlsHud` shows placement hint: `"Move: position | Interact: confirm | Back/Inv: cancel"`.

Materials are **not** deducted until the player confirms placement.

---

## 3. HousePlacer Node

**File:** `scripts/entities/house_placer.gd`  
**Class:** `class_name HousePlacer extends Node2D`

Created by `World.start_house_placement(pid, structure_id)` and added directly to the current `WorldRoot` (not `entities`). Cleaned up on exit.

### Ghost rendering

The overworld representation of a house is always a single entry in `dungeon_entrances`. The ghost shows:
- One `ColorRect` (48×48px = 3×3 tiles, semi-transparent, alpha=0.35) centered on the cursor cell — **green** `Color(0.2, 1.0, 0.2, 0.35)` if valid, **red** `Color(1.0, 0.2, 0.2, 0.35)` if invalid.
- One smaller `ColorRect` (16×16px = 1 tile, alpha=0.6) on the cursor cell tinted **yellow** `Color(1.0, 0.9, 0.1, 0.6)` — marks where the door will land.

Both rects use `z_index = 50`. They are children of `HousePlacer`.

### Input handling

Reads `p1_*` or `p2_*` actions based on `pid`:
- Movement keys → move cursor one tile per press (with held-key repeat at 0.15s interval using `_repeat_timer`).
- `p*_interact` → confirm if cell valid; no-op if invalid.
- `p*_inventory` OR `p*_back` → cancel.

### Validity check

A cell is valid if all of:
1. `WorldRoot.is_walkable(cell)` returns true.
2. `WorldRoot.has_door(cell)` returns false.
3. No entity in `WorldRoot.entities` is positioned at this cell (checked by tile coordinate, not pixel position).

### Signals

```gdscript
signal confirmed(pid: int, cell: Vector2i)
signal cancelled(pid: int)
```

---

## 4. WorldRoot additions

**`has_door(cell: Vector2i) -> bool`** — thin public wrapper around `_doors.has(cell)`.

**`rebuild_door_index() -> void`** — public wrapper that calls `_build_door_index(_last_view_kind)`. Requires storing `_last_view_kind: StringName` when `apply_view` is called.

**`add_house_entrance(cell: Vector2i) -> void`** — appends `{"kind": &"house", "cell": cell}` to `_region.dungeon_entrances`, calls `_build_door_index(_last_view_kind)`, and calls `_paint_overworld_entrance_markers(_region)` to show the warm-tint marker immediately.

---

## 5. World coordination

**`start_house_placement(pid: int, structure_id: StringName) -> void`**:
1. Creates `HousePlacer` node in current `WorldRoot`.
2. Connects `confirmed` → `_on_house_confirmed`.
3. Connects `cancelled` → `_on_house_cancelled`.
4. Sets `ControlsHud` override hint via `Game.instance()`.

**`_on_house_confirmed(pid: int, cell: Vector2i) -> void`**:
1. Look up cost from `PartyMemberRegistry.get_member(&"builder").builds`.
2. Deduct materials from `CaravanData.inventory`.
3. Call `WorldRoot.add_house_entrance(cell)`.
4. Free the `HousePlacer` node.
5. Clear `ControlsHud` hint.
6. Reopen CaravanMenu via `Game.instance().open_caravan_menu(pid)`.

**`_on_house_cancelled(pid: int) -> void`**:
1. Free the `HousePlacer` node.
2. Clear `ControlsHud` hint.
3. Reopen CaravanMenu.

---

## 6. ControlsHud + Game additions

**`ControlsHud.set_override_hint(text: String) -> void`**: When `text != ""`, displays it instead of the normal action list. When `""`, reverts to normal display. Uses a `_override_hint: String` field checked in `_refresh()`.

**`Game.get_controls_hud(pid: int) -> ControlsHud`**: Returns `_controls_p1` or `_controls_p2`.

**`Game.open_caravan_menu(pid: int) -> void`**: Calls `_caravan_menu_p1.open()` or `_caravan_menu_p2.open()`.

---

## 7. Scope

**Included:**
- `builder` party member JSON entry + `PartyMemberDef.builds` field
- CaravanMenu portrait redesign (all member cards, vertical layout, CharacterBuilder + pet portraits)
- `CaravanMenu.build_requested` signal + `BuilderPanel` detail panel
- `HousePlacer` node (ghost, input, validity, signals)
- `WorldRoot.has_door()`, `rebuild_door_index()`, `add_house_entrance()`, `_last_view_kind`
- `World.start_house_placement()` + confirmed/cancelled handlers
- `ControlsHud.set_override_hint()`
- `Game.get_controls_hud()`, `Game.open_caravan_menu()`
- F8 debug includes builder automatically

**Excluded:**
- Multiple structure types beyond `house_basic` (data supports it, UI lists it, only one structure for now)
- Builder NPC visual on the overworld (builder is a caravan party member, not a world entity)
- Upgrading or demolishing placed houses
- House ownership / locking (any player can enter any house)
- Interior customization (uses standard `HouseGenerator` output)
