# UI Theme & Menu System

Use when:
- Adding any new UI widget, screen, or panel
- Styling dynamically-created nodes in GDScript
- Creating or modifying a menu scene (`.tscn`)
- Adding a new colour constant or type variation
- Debugging theme/cursor/focus issues in menus

---

## Architecture Overview

```
UITheme (scripts/data/ui_theme.gd)        ← single source of truth
    └── UITheme.build() → Theme
            ↓
tools/gen_ui_theme.gd                     ← writes game_theme.tres once
            ↓
resources/ui/game_theme.tres              ← project-wide theme (project.godot)
            ↓
All Button / Label / PanelContainer / Panel nodes inherit it automatically
            ↓
node.theme_type_variation = &"WoodButton"  ← per-node opt-in to a variation
```

**Rule:** Never hardcode `Color(...)` values or construct inline `StyleBoxFlat` in UI scripts. Always use `UITheme.COL_*` constants and `theme_type_variation`.

---

## UITheme — Palette Constants (`scripts/data/ui_theme.gd`)

| Constant | Value | When to use |
|---|---|---|
| `COL_BG` | `Color(0.16, 0.11, 0.09, 0.95)` | Main panel background |
| `COL_FRAME` | `Color(0.62, 0.42, 0.22)` | Panel/slot border, separator |
| `COL_SLOT_BG` | `Color(0.22, 0.14, 0.09, 0.85)` | Inventory slot background |
| `COL_SLOT_BRD` | `Color(0.50, 0.34, 0.18)` | Inventory slot border |
| `COL_TITLE_BG` | `Color(0.34, 0.21, 0.13)` | Title/footer bar background |
| `COL_PARCHMENT` | `Color(0.28, 0.20, 0.14, 0.60)` | Inner panel (paperdoll, content) |
| `COL_SILHOUETTE` | `Color(0.45, 0.34, 0.24, 0.35)` | Equipment slot silhouette parts |
| `COL_LABEL` | `Color(0.88, 0.82, 0.70)` | Primary text (bright parchment) |
| `COL_LABEL_DIM` | `Color(0.55, 0.48, 0.38)` | Secondary text, hints |
| `COL_TAB_ACTIVE` | `Color(0.34, 0.21, 0.13)` | Active tab / hover button bg |
| `COL_TAB_INACTIVE` | `Color(0.20, 0.14, 0.10)` | Inactive tab / normal button bg |
| `COL_CURSOR` | `Color(0.95, 0.85, 0.45, 0.9)` | Keyboard cursor highlight (gold) |
| `COL_TAB_GOLD` | `Color(0.95, 0.80, 0.40)` | Active tab left-edge accent |
| `SLOT_SZ` | `48.0` | Inventory/hotbar slot size in px |

---

## Type Variations (set via `theme_type_variation`)

| Variation | Base type | What it looks like |
|---|---|---|
| `WoodPanel` | `PanelContainer` | Dark bg, amber 3px border, 6px corners, drop shadow — main menu/screen frames |
| `WoodInnerPanel` | `PanelContainer` | Semi-transparent parchment bg, dim border — inner content areas (paperdoll, story content) |
| `TitleBar` | `PanelContainer` | Dark title-bg, rounded top corners, no border — header/footer bars |
| `WoodButton` | `Button` | Dark bg, amber border, parchment label — standard clickable buttons |
| `WoodTabButton` | `Button` | Flat, dim label — inactive tab |
| `WoodTabButtonActive` | `Button` | Dark bg, 4px gold left border, white label — active/selected tab |
| `TitleLabel` | `Label` | 16px, `COL_LABEL` |
| `DimLabel` | `Label` | 13px, `COL_LABEL_DIM` |
| `HintLabel` | `Label` | 11px, `COL_LABEL_DIM` — tiny hints, counts |
| `SlotPanel` | `Panel` | Dark slot bg, amber border, 3px corners — inventory/hotbar cell bg |
| `CursorPanel` | `Panel` | Transparent bg, gold 3px border — keyboard selection ring |
| `WoodSep` | `Panel` | Thin dark separator line |

### Applying in GDScript (dynamic nodes)

```gdscript
var btn := Button.new()
btn.theme_type_variation = &"WoodButton"

var panel := PanelContainer.new()
panel.theme_type_variation = &"WoodInnerPanel"

var lbl := Label.new()
lbl.theme_type_variation = &"DimLabel"
```

### Applying in .tscn scenes

```
[node name="Panel" type="PanelContainer" parent="Center"]
theme_type_variation = &"WoodPanel"
```

### Cursor highlight (keyboard nav)

Use `add_theme_color_override` on top of the variation — it takes precedence:

```gdscript
# Active item:
btn.add_theme_color_override("font_color", UITheme.COL_CURSOR)
# Inactive item:
btn.remove_theme_color_override("font_color")
```

**Never** hardcode `Color(1.0, 0.85, 0.3)` — always use `UITheme.COL_CURSOR`.

### Tab active/inactive swap

```gdscript
btn.theme_type_variation = &"WoodTabButtonActive" if active else &"WoodTabButton"
```

---

## Regenerating the Theme File

Run once after changing `UITheme`:

```bash
godot --headless -s tools/gen_ui_theme.gd
```

This writes `resources/ui/game_theme.tres`. Commit the `.tres` file. It is set as the project-wide theme in `project.godot` under `[gui] theme/custom`.

---

## Menu Scenes

All menu screens are `.tscn` files. Scripts use `@onready` to bind node refs — **never call `MenuClass.new()`** for screens that have `.tscn` files; use `load("res://scenes/ui/…").instantiate()` instead. Using `.new()` skips the scene tree so all `@onready` vars are null.

### Scenes with full node trees

| Scene | Root type | Layer | Script |
|---|---|---|---|
| `scenes/ui/MainMenu.tscn` | `Control` | — | `main_menu.gd` |
| `scenes/ui/PauseMenu.tscn` | `CanvasLayer` | 100 | `pause_menu.gd` |
| `scenes/ui/CaravanMenu.tscn` | `CanvasLayer` | 45 | `caravan_menu.gd` |

`InventoryScreen`, `DialogueBox`, `CraftingPanel`, `CrafterPanel`, `StoryTellerPanel`, and `HotbarSlot` remain programmatic (variable/dynamic content).

### Instantiating a menu scene in code

```gdscript
# ✅ Correct — @onready vars are populated
var menu := load("res://scenes/ui/CaravanMenu.tscn").instantiate() as CaravanMenu
container.add_child(menu)

# ❌ Wrong — @onready vars are null, _build_ui() was removed
var menu := CaravanMenu.new()
```

---

## CaravanMenu Focus System (`scripts/ui/caravan_menu.gd`)

Two focus zones: `LEFT` (party list) and `RIGHT` (character/crafter panel).

### Focus state

```gdscript
enum _Focus { LEFT, RIGHT }
var _focus: _Focus = _Focus.LEFT
```

### Always use `_set_focus()` — never assign `_focus` directly

```gdscript
_set_focus(_Focus.RIGHT)   # ✅ updates cursor + dim visuals atomically
_focus = _Focus.RIGHT      # ❌ skips refresh
```

`_set_focus()` calls both `_refresh_member_cursor()` and `_refresh_focus_visuals()`.

### Focus visuals

The **active** panel is full brightness (`Color.WHITE`). The **inactive** panel is dimmed to `Color(0.55, 0.55, 0.55, 1.0)`. Implemented in `_refresh_focus_visuals()` via `modulate` on `_left_panel` and `_right_panel`.

### Input routing

| Focus | Keys | Action |
|---|---|---|
| LEFT | UP/DOWN | Move member cursor |
| LEFT | INTERACT | Select member → `_on_member_selected()` → shift focus RIGHT |
| LEFT | BACK | Close menu |
| RIGHT | BACK / LEFT | Shift focus LEFT |
| RIGHT | All nav verbs | Delegated to active sub-panel via `panel.navigate(verb)` |

---

## DialogueBox (`scripts/ui/dialogue_box.gd`)

`CanvasLayer`, layer 40. One instance per player SubViewport, anchored to the bottom.

### Font sizes

| Part | Size |
|---|---|
| Speaker name | 19 |
| Body text | 17 |
| Choice labels | 15 |
| Hint / prompt | 13 |

### Signals

| Signal | When |
|---|---|
| `choice_selected(choice, passed)` | Player picks a dialogue choice |
| `dismissed` | Conversation closes |

### Showing dialogue

```gdscript
dialogue_box.show_line("Mara", "Welcome, traveller.")           # one-liner
dialogue_box.show_node(dialogue_node, player_stats_dict)        # branching
dialogue_box.hide_line()                                         # manual close
```

---

## HotbarSlot Rarity Borders

`HotbarSlot._apply_polish()` replaces the `$Bg` ColorRect with a Panel. It **reads** the `SlotPanel` stylebox from the theme, **duplicates** it (so mutations don't affect the shared resource), then modifies `border_color` for rarity.

**Critical:** `_make_slot()` in `inventory_screen.gd` must create `ColorRect(name="Bg")` as the background child — `_apply_polish()` looks for `$Bg` by name. If you name it anything else or use a Panel, rarity borders silently break.

```gdscript
# ✅ Correct — _apply_polish() finds this and replaces it
var bg := ColorRect.new()
bg.name = "Bg"
bg.color = UITheme.COL_SLOT_BG
slot.add_child(bg)
```

---

## Adding a New Screen or Panel

1. Build the node tree in a `.tscn` file using `theme_type_variation` for all styled nodes.
2. Write the `.gd` script with `@onready` for all node references.
3. If the script builds nodes dynamically (variable lists), set `theme_type_variation` in code.
4. Use `UITheme.COL_*` for any `add_theme_color_override` calls.
5. Never construct `StyleBoxFlat` inline — add a new type variation to `UITheme` if needed, then regenerate `game_theme.tres`.

## Adding a New Type Variation

1. Add a `static func _add_my_variation(t: Theme) -> void` to `scripts/data/ui_theme.gd`.
2. Call it from `UITheme.build()`.
3. Add a unit test in `tests/unit/test_ui_theme.gd` asserting the base type.
4. Run `godot --headless -s tools/gen_ui_theme.gd` to regenerate `resources/ui/game_theme.tres`.
5. Commit both `ui_theme.gd` and `game_theme.tres`.
