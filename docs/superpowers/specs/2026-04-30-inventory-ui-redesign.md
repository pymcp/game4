# Inventory UI Redesign

**Date:** 2026-04-30  
**Status:** Approved

---

## Goals

1. Paper doll always visible in the inventory screen (right column, all tabs)
2. Rich item detail panel at the bottom of the content area (name, slot, power, description)
3. Floating tooltip near the slot showing just the item name
4. Character tab: appearance customizer + stats readout + inline level-up stat spending (replaces `LevelUpPanel` overlay)
5. Remove XP bar and passive banner from the HUD; replace with brief "Level Up!" flash label + 1-second yellow character flash

---

## Layout

Panel expands from 720 → 880px wide.

```
┌──────────┬──────────────────────┬──────────────┐
│ Tabs     │  Content (grid etc)  │  Paper Doll  │
│ (120px)  │  (expand-fill)       │  (180px)     │
│          │                      │              │
│          │  [item][item][item]  │  [Head slot] │
│          │  [item][item][item]  │  [silhouette]│
│          │  [item][item][item]  │  [Weapon]    │
│          │─────────────────────│  [Body]      │
│          │  Item Detail Panel  │  [Feet/Tool] │
│          │  (name·power·desc)  │              │
└──────────┴──────────────────────┴──────────────┘
```

The right column is a permanent `VBoxContainer` added to `content_row` after the existing content margin. It contains `_paperdoll` directly (moved out of `_eq_page`). The Equipment tab is removed from the tab list and `Tab` enum.

---

## Tab List (after change)

```
ALL, WEAPONS, ARMOR, TOOLS, MATERIALS, CHARACTER
```

(Equipment tab removed; indices shift accordingly.)

---

## Item Detail Panel

Located at the bottom of `_grid_page` (and visible on the Equipment tab too, but equipment tab is gone so only grid tabs). Replaces the existing `_detail_name_label` + `_detail_desc_label` box.

Shows for the cursor-selected item:
- **Name** — rarity-colored (existing logic)
- **Slot badge** — small dimmed label e.g. "Weapon", "Head", "Material"
- **Power** — shown only when `def.power > 0`, e.g. "Power: 5"
- **Description** — `def.generate_description()`
- **Stack** — shown only for `Slot.NONE` items (materials), e.g. "×3"

When nothing is selected: shows placeholder "(select an item)".

Implementation: upgrade `_detail_name_label` + `_detail_desc_label` into a `VBoxContainer` with 3 labels: name (rarity color), meta (slot + power, dimmed), description.

---

## Floating Tooltip

A single `Label` node parented to the `InventoryScreen` Control (top of scene tree so it renders above everything).

- Appears when cursor lands on a non-empty slot (grid or equipment doll)
- Text: item display name only
- Positioned: 4px above the hovered slot's global position, centered horizontally on the slot
- Clamped to stay within the panel bounds
- Hidden when slot is empty or cursor moves off

Implemented as `_tooltip_label: Label` (theme variation `HintLabel`, font size 11). Updated in `_refresh_cursor()`.

---

## Character Tab

Single tab replaces both the old CHARACTER tab (appearance) and the `LevelUpPanel` overlay.

Layout — two sections stacked with a `HSeparator` between them:

### Section 1: Stats

```
Level 7           [XP bar: 350/700]

Strength    3  [+]   ← [+] only when _pending_stat_points > 0
Dexterity   2  [+]
Defense     1
Charisma    3
Wisdom      3
Speed       0

[2 stat points to spend]   ← shown only when pending > 0
```

- XP bar: reuse `XpBar` control
- Stat rows: `HBoxContainer` per stat — name label (100px), value label (30px), optional `[+]` Button
- `[+]` button calls `_player.spend_stat_point(stat)` then calls `_refresh_char_stats()`
- `[+]` buttons are hidden when `_pending_stat_points == 0`
- Pending points header only visible when `_pending_stat_points > 0`
- Unlocked passives listed below stats: e.g. "Passives: Hardy, Scavenger"

### Section 2: Appearance

Identical to existing character builder (skin, torso, hair, face sliders + preview viewport). No change to logic.

### `LevelUpPanel` retirement

`LevelUpPanel` scene/script is **deleted**. Its logic is absorbed into the Character tab inline. `InventoryScreen._level_up_panel` var and all references removed.

---

## HUD Changes

### Remove from `PlayerHUD`
- `_xp_bar: XpBar` — field, creation in `_build()`, poll in `_process()`
- `_passive_banner: Label` — field, creation in `_build()`, `_on_leveled_up()` tween

### Add to `PlayerHUD`
- `_level_flash_label: Label` — centered horizontally, positioned at ~25% down the viewport height, hidden by default
  - Text: "⬆ LEVEL UP!" (or "LEVEL UP!")
  - Font size 16, bold via theme variation `FlashLabel`
  - On `leveled_up` signal: set visible, tween alpha 1→0 over 2.0 seconds, then hide
- `leveled_up` signal still connected via `set_player()`

### Character yellow flash
In `PlayerController._level_up()`, after incrementing `level`, call a new static helper:
```gdscript
ActionParticles.flash_level_up(self)
```

Add `flash_level_up(node: CanvasItem)` to `ActionParticles`:
- Tween: modulate → `Color(3, 2.5, 0, 1)` (bright yellow) over 0.1s, hold 0.2s, tween back → `Color(1,1,1,1)` over 0.7s
- Total duration: ~1s

---

## Files Changed

| File | Change |
|------|--------|
| `scripts/ui/inventory_screen.gd` | Redesign: right column, remove Equipment tab, tooltip, upgrade detail panel, Character tab with stats+level-up inline |
| `scripts/ui/player_hud.gd` | Remove XpBar + passive banner; add flash label; connect leveled_up → flash |
| `scripts/entities/action_particles.gd` | Add `flash_level_up()` static method |
| `scripts/entities/player_controller.gd` | Call `ActionParticles.flash_level_up(self)` in `_level_up()` |
| `scripts/ui/level_up_panel.gd` | **Deleted** |
| `tests/unit/test_inventory_screen.gd` | Update any tests that reference Tab.EQUIPMENT or LevelUpPanel |

---

## Out of Scope

- No changes to `ItemDefinition`, `ItemRegistry`, or any data files
- No changes to navigation/input handling beyond what's needed for the new Character tab stat rows
- `XpBar` script kept (still used inside the Character tab stat section)

---

## Self-Review

- No placeholder values or "TODO" items
- `LevelUpPanel` retirement is complete (deleted, not just hidden)
- Equipment tab removal shifts Tab enum indices — `_select_tab()` and all `Tab.X` references must be audited
- `flash_level_up` duration (0.1+0.2+0.7=1.0s) fits requirement
- Tooltip clamping prevents overflow on small viewports
- `_on_leveled_up` in HUD only does the text flash; yellow body flash is in `player_controller.gd` so it works even when inventory is closed
