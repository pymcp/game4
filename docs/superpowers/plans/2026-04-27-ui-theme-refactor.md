# UI Theme Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract all inline style code into a shared `UITheme` class that generates a project-wide Godot `Theme` resource, rebuild `MainMenu`/`PauseMenu`/`CaravanMenu` as full `.tscn` scene trees, and strip inline style code from all remaining UI scripts.

**Architecture:** A `UITheme` (`RefCounted`) owns all palette constants and builds a `Theme` resource programmatically via `UITheme.build()`. A `@tool` script generates `resources/ui/game_theme.tres` from it. That `.tres` is set as the project-wide theme, so all `Button`, `Label`, and `PanelContainer` nodes inherit it automatically. Dynamically-created nodes use `node.theme_type_variation = &"VariationName"` in GDScript.

**Tech Stack:** Godot 4.3, GDScript, GUT test framework

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| CREATE | `scripts/data/ui_theme.gd` | All palette constants + `build() -> Theme` |
| CREATE | `tools/gen_ui_theme.gd` | `@tool` script, writes `resources/ui/game_theme.tres` |
| CREATE | `resources/ui/game_theme.tres` | Generated project-wide Theme resource |
| CREATE | `tests/unit/test_ui_theme.gd` | Unit tests for UITheme constants and build() |
| MODIFY | `scenes/ui/MainMenu.tscn` | Full node tree (was script-only stub) |
| MODIFY | `scripts/ui/main_menu.gd` | Drop `_build()`, add `@onready` refs |
| MODIFY | `scenes/ui/PauseMenu.tscn` | Rebuild with `WoodPanel`/`WoodButton` type hints |
| MODIFY | `scripts/ui/pause_menu.gd` | Update `_refresh_cursor()` to use `UITheme.COL_CURSOR` |
| MODIFY | `scenes/ui/CaravanMenu.tscn` | Full node tree (was script-only stub) |
| MODIFY | `scripts/ui/caravan_menu.gd` | Drop `_build_ui()`, add `@onready` refs |
| MODIFY | `scripts/ui/inventory_screen.gd` | Delete all `COL_*` consts + all `_make_*_style()` helpers; apply type variations |
| MODIFY | `scripts/ui/hotbar_slot.gd` | Remove inline `StyleBoxFlat`; use `SlotPanel` type variation |
| MODIFY | `scripts/ui/crafter_panel.gd` | Apply `WoodButton` variation to recipe buttons |
| MODIFY | `scripts/ui/crafting_panel.gd` | Apply `WoodButton` variation to recipe buttons |
| MODIFY | `project.godot` | Set `gui/theme/custom = "res://resources/ui/game_theme.tres"` |

---

## Task 1: UITheme class + tests

**Files:**
- Create: `scripts/data/ui_theme.gd`
- Create: `tests/unit/test_ui_theme.gd`

- [ ] **Step 1.1: Write failing tests**

Create `tests/unit/test_ui_theme.gd`:

```gdscript
extends GutTest

func test_col_constants_are_defined() -> void:
	assert_eq(UITheme.COL_BG, Color(0.16, 0.11, 0.09, 0.95))
	assert_eq(UITheme.COL_FRAME, Color(0.62, 0.42, 0.22))
	assert_eq(UITheme.COL_SLOT_BG, Color(0.22, 0.14, 0.09, 0.85))
	assert_eq(UITheme.COL_SLOT_BRD, Color(0.50, 0.34, 0.18))
	assert_eq(UITheme.COL_TITLE_BG, Color(0.34, 0.21, 0.13))
	assert_eq(UITheme.COL_PARCHMENT, Color(0.28, 0.20, 0.14, 0.60))
	assert_eq(UITheme.COL_SILHOUETTE, Color(0.45, 0.34, 0.24, 0.35))
	assert_eq(UITheme.COL_LABEL, Color(0.88, 0.82, 0.70))
	assert_eq(UITheme.COL_LABEL_DIM, Color(0.55, 0.48, 0.38))
	assert_eq(UITheme.COL_TAB_ACTIVE, Color(0.34, 0.21, 0.13))
	assert_eq(UITheme.COL_TAB_INACTIVE, Color(0.20, 0.14, 0.10))
	assert_eq(UITheme.COL_CURSOR, Color(0.95, 0.85, 0.45, 0.9))
	assert_eq(UITheme.COL_TAB_GOLD, Color(0.95, 0.80, 0.40))


func test_slot_sz_is_48() -> void:
	assert_eq(UITheme.SLOT_SZ, 48.0)


func test_build_returns_theme() -> void:
	var t: Theme = UITheme.build()
	assert_not_null(t)
	assert_true(t is Theme)


func test_build_has_wood_panel_variation() -> void:
	var t: Theme = UITheme.build()
	# WoodPanel is a variation of PanelContainer — check its base type
	assert_eq(t.get_type_variation_base(&"WoodPanel"), &"PanelContainer")


func test_build_has_wood_button_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"WoodButton"), &"Button")


func test_build_has_title_label_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"TitleLabel"), &"Label")


func test_build_has_dim_label_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"DimLabel"), &"Label")


func test_build_has_slot_panel_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"SlotPanel"), &"Panel")


func test_build_has_cursor_panel_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"CursorPanel"), &"Panel")
```

- [ ] **Step 1.2: Run tests to confirm they fail**

```bash
cd /home/mpatterson/repos/game4
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_ui_theme.gd -gexit 2>&1 | tail -20
```

Expected: errors about `UITheme` not found.

- [ ] **Step 1.3: Create `scripts/data/ui_theme.gd`**

```gdscript
## UITheme
##
## Central source of truth for the game's UI palette and Godot Theme resource.
## All colour constants live here. Call [method build] to construct the
## project-wide [Theme] resource programmatically; use
## [code]tools/gen_ui_theme.gd[/code] to serialise it to
## [code]resources/ui/game_theme.tres[/code].
##
## Scripts that need a colour value should read [code]UITheme.COL_*[/code]
## directly — DO NOT duplicate these values inline.
class_name UITheme
extends RefCounted

# ---------------------------------------------------------------------------
# Palette — Pixel Adventure wood tones
# ---------------------------------------------------------------------------
const COL_BG         := Color(0.16, 0.11, 0.09, 0.95)
const COL_FRAME      := Color(0.62, 0.42, 0.22)
const COL_SLOT_BG    := Color(0.22, 0.14, 0.09, 0.85)
const COL_SLOT_BRD   := Color(0.50, 0.34, 0.18)
const COL_TITLE_BG   := Color(0.34, 0.21, 0.13)
const COL_PARCHMENT  := Color(0.28, 0.20, 0.14, 0.60)
const COL_SILHOUETTE := Color(0.45, 0.34, 0.24, 0.35)
const COL_LABEL      := Color(0.88, 0.82, 0.70)
const COL_LABEL_DIM  := Color(0.55, 0.48, 0.38)
const COL_TAB_ACTIVE   := Color(0.34, 0.21, 0.13)
const COL_TAB_INACTIVE := Color(0.20, 0.14, 0.10)
const COL_CURSOR     := Color(0.95, 0.85, 0.45, 0.9)
const COL_TAB_GOLD   := Color(0.95, 0.80, 0.40)

# Slot size shared with InventoryScreen and HotbarSlot.
const SLOT_SZ: float = 48.0


# ---------------------------------------------------------------------------
# Theme builder
# ---------------------------------------------------------------------------

## Build and return the full project-wide [Theme] resource.
## All type variations for the wood-tone fantasy UI are defined here.
## Run [code]tools/gen_ui_theme.gd[/code] to save the result to
## [code]resources/ui/game_theme.tres[/code].
static func build() -> Theme:
	var t := Theme.new()

	_add_wood_panel(t)
	_add_wood_inner_panel(t)
	_add_title_bar(t)
	_add_wood_button(t)
	_add_wood_tab_button(t)
	_add_wood_tab_button_active(t)
	_add_title_label(t)
	_add_dim_label(t)
	_add_hint_label(t)
	_add_slot_panel(t)
	_add_cursor_panel(t)
	_add_wood_sep(t)

	return t


# ---------------------------------------------------------------------------
# Private helpers — one per type variation
# ---------------------------------------------------------------------------

static func _add_wood_panel(t: Theme) -> void:
	t.add_type(&"WoodPanel")
	t.set_type_variation(&"WoodPanel", &"PanelContainer")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.border_color = COL_FRAME
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	t.set_stylebox(&"panel", &"WoodPanel", sb)


static func _add_wood_inner_panel(t: Theme) -> void:
	t.add_type(&"WoodInnerPanel")
	t.set_type_variation(&"WoodInnerPanel", &"PanelContainer")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PARCHMENT
	sb.border_color = COL_FRAME.darkened(0.2)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	t.set_stylebox(&"panel", &"WoodInnerPanel", sb)


static func _add_title_bar(t: Theme) -> void:
	t.add_type(&"TitleBar")
	t.set_type_variation(&"TitleBar", &"PanelContainer")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TITLE_BG
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	t.set_stylebox(&"panel", &"TitleBar", sb)


static func _add_wood_button(t: Theme) -> void:
	t.add_type(&"WoodButton")
	t.set_type_variation(&"WoodButton", &"Button")
	# Normal state.
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = COL_TAB_INACTIVE
	sb_normal.border_color = COL_FRAME
	sb_normal.border_width_left = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_bottom = 2
	sb_normal.corner_radius_top_left = 3
	sb_normal.corner_radius_top_right = 3
	sb_normal.corner_radius_bottom_left = 3
	sb_normal.corner_radius_bottom_right = 3
	sb_normal.content_margin_left = 10.0
	sb_normal.content_margin_right = 10.0
	sb_normal.content_margin_top = 5.0
	sb_normal.content_margin_bottom = 5.0
	t.set_stylebox(&"normal", &"WoodButton", sb_normal)
	# Hover state — slightly lighter.
	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = COL_TAB_ACTIVE
	sb_hover.border_color = COL_FRAME
	t.set_stylebox(&"hover", &"WoodButton", sb_hover)
	# Pressed state — same as hover.
	t.set_stylebox(&"pressed", &"WoodButton", sb_hover)
	# Focus — transparent outline.
	var sb_focus := StyleBoxFlat.new()
	sb_focus.bg_color = Color(0, 0, 0, 0)
	sb_focus.border_color = COL_CURSOR
	sb_focus.border_width_left = 2
	sb_focus.border_width_right = 2
	sb_focus.border_width_top = 2
	sb_focus.border_width_bottom = 2
	sb_focus.corner_radius_top_left = 3
	sb_focus.corner_radius_top_right = 3
	sb_focus.corner_radius_bottom_left = 3
	sb_focus.corner_radius_bottom_right = 3
	t.set_stylebox(&"focus", &"WoodButton", sb_focus)
	# Font color.
	t.set_color(&"font_color", &"WoodButton", COL_LABEL)
	t.set_color(&"font_hover_color", &"WoodButton", Color.WHITE)
	t.set_color(&"font_pressed_color", &"WoodButton", Color.WHITE)
	t.set_color(&"font_disabled_color", &"WoodButton", COL_LABEL_DIM)
	t.set_font_size(&"font_size", &"WoodButton", 13)


static func _add_wood_tab_button(t: Theme) -> void:
	t.add_type(&"WoodTabButton")
	t.set_type_variation(&"WoodTabButton", &"Button")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TAB_INACTIVE
	sb.border_color = COL_FRAME.darkened(0.3)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 3
	sb.corner_radius_bottom_left = 3
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	t.set_stylebox(&"normal", &"WoodTabButton", sb)
	t.set_stylebox(&"hover", &"WoodTabButton", sb)
	t.set_stylebox(&"pressed", &"WoodTabButton", sb)
	t.set_color(&"font_color", &"WoodTabButton", COL_LABEL_DIM)
	t.set_color(&"font_hover_color", &"WoodTabButton", Color.WHITE)
	t.set_font_size(&"font_size", &"WoodTabButton", 13)


static func _add_wood_tab_button_active(t: Theme) -> void:
	t.add_type(&"WoodTabButtonActive")
	t.set_type_variation(&"WoodTabButtonActive", &"Button")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TAB_ACTIVE
	sb.border_color = COL_TAB_GOLD  # Gold left-edge accent.
	sb.border_width_left = 4
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 3
	sb.corner_radius_bottom_left = 3
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	t.set_stylebox(&"normal", &"WoodTabButtonActive", sb)
	t.set_stylebox(&"hover", &"WoodTabButtonActive", sb)
	t.set_stylebox(&"pressed", &"WoodTabButtonActive", sb)
	t.set_color(&"font_color", &"WoodTabButtonActive", Color.WHITE)
	t.set_color(&"font_hover_color", &"WoodTabButtonActive", Color.WHITE)
	t.set_font_size(&"font_size", &"WoodTabButtonActive", 13)


static func _add_title_label(t: Theme) -> void:
	t.add_type(&"TitleLabel")
	t.set_type_variation(&"TitleLabel", &"Label")
	t.set_color(&"font_color", &"TitleLabel", COL_LABEL)
	t.set_font_size(&"font_size", &"TitleLabel", 16)


static func _add_dim_label(t: Theme) -> void:
	t.add_type(&"DimLabel")
	t.set_type_variation(&"DimLabel", &"Label")
	t.set_color(&"font_color", &"DimLabel", COL_LABEL_DIM)
	t.set_font_size(&"font_size", &"DimLabel", 13)


static func _add_hint_label(t: Theme) -> void:
	t.add_type(&"HintLabel")
	t.set_type_variation(&"HintLabel", &"Label")
	t.set_color(&"font_color", &"HintLabel", COL_LABEL_DIM)
	t.set_font_size(&"font_size", &"HintLabel", 11)


static func _add_slot_panel(t: Theme) -> void:
	t.add_type(&"SlotPanel")
	t.set_type_variation(&"SlotPanel", &"Panel")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_SLOT_BG
	sb.border_color = COL_SLOT_BRD
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	t.set_stylebox(&"panel", &"SlotPanel", sb)


static func _add_cursor_panel(t: Theme) -> void:
	t.add_type(&"CursorPanel")
	t.set_type_variation(&"CursorPanel", &"Panel")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = COL_CURSOR
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	t.set_stylebox(&"panel", &"CursorPanel", sb)


static func _add_wood_sep(t: Theme) -> void:
	t.add_type(&"WoodSep")
	t.set_type_variation(&"WoodSep", &"Panel")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_FRAME.darkened(0.3)
	t.set_stylebox(&"panel", &"WoodSep", sb)
```

- [ ] **Step 1.4: Refresh class cache**

```bash
cd /home/mpatterson/repos/game4
timeout 15 godot --headless --editor & sleep 12; kill %1 2>/dev/null; echo "cache refreshed"
```

- [ ] **Step 1.5: Run tests to confirm they pass**

```bash
cd /home/mpatterson/repos/game4
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_ui_theme.gd -gexit 2>&1 | tail -20
```

Expected: all 9 tests pass, 0 failing.

- [ ] **Step 1.6: Commit**

```bash
cd /home/mpatterson/repos/game4
git add scripts/data/ui_theme.gd tests/unit/test_ui_theme.gd
git commit -m "feat: add UITheme class with palette constants and Theme builder"
```

---

## Task 2: Generator tool + project theme setting

**Files:**
- Create: `tools/gen_ui_theme.gd`
- Create (generated): `resources/ui/game_theme.tres`
- Modify: `project.godot`

- [ ] **Step 2.1: Create `tools/gen_ui_theme.gd`**

```gdscript
## gen_ui_theme.gd
##
## @tool script: run once (or after changing UITheme) to write
## resources/ui/game_theme.tres.
##
## Run from the Godot editor: Scene menu → Run Specific Scene → select this
## file. Or from a headless command:
##   godot --headless -s tools/gen_ui_theme.gd
@tool
extends SceneTree

func _initialize() -> void:
	print("[gen_ui_theme] Building theme...")
	var t: Theme = UITheme.build()
	DirAccess.make_dir_recursive_absolute("res://resources/ui")
	var err: int = ResourceSaver.save(t, "res://resources/ui/game_theme.tres")
	if err == OK:
		print("[gen_ui_theme] Saved to res://resources/ui/game_theme.tres")
	else:
		push_error("[gen_ui_theme] Save failed: %d" % err)
	quit()
```

- [ ] **Step 2.2: Run the generator to produce game_theme.tres**

```bash
cd /home/mpatterson/repos/game4
godot --headless -s tools/gen_ui_theme.gd 2>&1 | tail -10
```

Expected output: `[gen_ui_theme] Saved to res://resources/ui/game_theme.tres`

- [ ] **Step 2.3: Verify the file was created**

```bash
ls -lh /home/mpatterson/repos/game4/resources/ui/game_theme.tres
```

Expected: file exists, non-zero size.

- [ ] **Step 2.4: Set project-wide theme in project.godot**

In `project.godot`, find the `[rendering]` section (or add a `[gui]` section) and add:

```ini
[gui]

theme/custom="res://resources/ui/game_theme.tres"
```

Do this by running:

```bash
cd /home/mpatterson/repos/game4
# Check if [gui] section already exists
grep -n "^\[gui\]" project.godot
```

If `[gui]` section exists, add `theme/custom` under it. If not, append the block to the end of the file before the closing content. Use the file editor to make the change — do NOT use sed on `project.godot`.

- [ ] **Step 2.5: Run all unit tests to confirm nothing broke**

```bash
cd /home/mpatterson/repos/game4
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
```

Expected: same pass count as before, 0 failing.

- [ ] **Step 2.6: Commit**

```bash
cd /home/mpatterson/repos/game4
git add tools/gen_ui_theme.gd resources/ui/game_theme.tres project.godot
git commit -m "feat: generate game_theme.tres and set as project-wide theme"
```

---

## Task 3: Rebuild MainMenu, PauseMenu, and CaravanMenu as full .tscn scenes

**Files:**
- Modify: `scenes/ui/MainMenu.tscn`
- Modify: `scripts/ui/main_menu.gd`
- Modify: `scenes/ui/PauseMenu.tscn`
- Modify: `scripts/ui/pause_menu.gd`
- Modify: `scenes/ui/CaravanMenu.tscn`
- Modify: `scripts/ui/caravan_menu.gd`

### 3A — MainMenu

- [ ] **Step 3A.1: Rewrite `scenes/ui/MainMenu.tscn`**

Replace the entire contents of `scenes/ui/MainMenu.tscn` with:

```
[gd_scene load_steps=2 format=3 uid="uid://maintmenu"]

[ext_resource type="Script" path="res://scripts/ui/main_menu.gd" id="1_main"]

[node name="MainMenu" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 1
script = ExtResource("1_main")

[node name="Bg" type="ColorRect" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.06, 0.06, 0.1, 1)
mouse_filter = 2

[node name="Center" type="CenterContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="Panel" type="PanelContainer" parent="Center"]
custom_minimum_size = Vector2(360, 0)
theme_type_variation = &"WoodPanel"

[node name="Margin" type="MarginContainer" parent="Center/Panel"]
theme_override_constants/margin_left = 24
theme_override_constants/margin_right = 24
theme_override_constants/margin_top = 24
theme_override_constants/margin_bottom = 24

[node name="VBox" type="VBoxContainer" parent="Center/Panel/Margin"]
theme_override_constants/separation = 12

[node name="Title" type="Label" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"TitleLabel"
text = "Fantasy Iso Co-op"
horizontal_alignment = 1

[node name="SeedLabel" type="Label" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"DimLabel"
text = "World seed (optional)"

[node name="SeedInput" type="LineEdit" parent="Center/Panel/Margin/VBox"]
placeholder_text = "leave blank to randomise"

[node name="NewGame2P" type="Button" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"WoodButton"
focus_mode = 0
text = "New Game (2 Players)"

[node name="NewGameP1" type="Button" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"WoodButton"
focus_mode = 0
text = "New Game (Player 1)"

[node name="NewGameP2" type="Button" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"WoodButton"
focus_mode = 0
text = "New Game (Player 2)"

[node name="Continue" type="Button" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"WoodButton"
focus_mode = 0
text = "Continue"

[node name="Quit" type="Button" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"WoodButton"
focus_mode = 0
text = "Quit"
```

> **Note on UIDs:** The `uid=` value in `[gd_scene]` must be unique. If Godot rejects the file, remove the `uid=` attribute entirely — Godot will assign one on import.

- [ ] **Step 3A.2: Rewrite `scripts/ui/main_menu.gd`**

Replace the entire file with:

```gdscript
## MainMenu
##
## First scene shown on game launch. Lets the player start a new world,
## continue from the default save slot, or quit.
##
## "Continue" is disabled when no save file exists for [code]DEFAULT_SLOT[/code].
##
## Pure helpers [code]parse_seed[/code] and [code]has_save[/code] are static
## so they can be unit-tested without instantiating the menu.
extends Control
class_name MainMenu

const GameScene: PackedScene = preload("res://scenes/main/Game.tscn")

@onready var _seed_input: LineEdit = $Center/Panel/Margin/VBox/SeedInput
@onready var _btn_new_2p: Button = $Center/Panel/Margin/VBox/NewGame2P
@onready var _btn_new_p1: Button = $Center/Panel/Margin/VBox/NewGameP1
@onready var _btn_new_p2: Button = $Center/Panel/Margin/VBox/NewGameP2
@onready var _btn_continue: Button = $Center/Panel/Margin/VBox/Continue
@onready var _btn_quit: Button = $Center/Panel/Margin/VBox/Quit

var _nav_buttons: Array[Button] = []
var _cursor: int = 0


# ---------- Pure helpers ----------

## Parse a seed string. Empty / non-numeric → 0 (which means "use unix time"
## downstream in WorldManager.reset).
static func parse_seed(text: String) -> int:
	var t := text.strip_edges()
	if t.is_empty():
		return 0
	if t.is_valid_int():
		return int(t)
	return int(t.hash())


## True if a save exists for the given slot.
static func has_save(slot: String) -> bool:
	return FileAccess.file_exists(SaveGame.slot_path(slot))


# ---------- Lifecycle ----------

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	anchor_right = 1.0
	anchor_bottom = 1.0
	_btn_new_2p.pressed.connect(_on_new_game_2p)
	_btn_new_p1.pressed.connect(_on_new_game_p1)
	_btn_new_p2.pressed.connect(_on_new_game_p2)
	_btn_continue.pressed.connect(_on_continue)
	_btn_quit.pressed.connect(_on_quit)
	_nav_buttons = [_btn_new_2p, _btn_new_p1, _btn_new_p2, _btn_continue, _btn_quit]
	_cursor = 0
	_refresh_continue_state()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var vp := get_viewport()
	if PlayerActions.either_just_pressed(event, PlayerActions.UP):
		_cursor = wrapi(_cursor - 1, 0, _nav_buttons.size())
		_skip_disabled(-1)
		_refresh_cursor()
		if vp != null:
			vp.set_input_as_handled()
	elif PlayerActions.either_just_pressed(event, PlayerActions.DOWN):
		_cursor = wrapi(_cursor + 1, 0, _nav_buttons.size())
		_skip_disabled(1)
		_refresh_cursor()
		if vp != null:
			vp.set_input_as_handled()
	elif PlayerActions.either_just_pressed(event, PlayerActions.INTERACT):
		if _cursor < _nav_buttons.size() and not _nav_buttons[_cursor].disabled:
			_nav_buttons[_cursor].pressed.emit()
		if vp != null:
			vp.set_input_as_handled()


func _refresh_continue_state() -> void:
	if _btn_continue != null:
		_btn_continue.disabled = not has_save(SaveManager.DEFAULT_SLOT)
	if not _nav_buttons.is_empty():
		_skip_disabled(1)
		_refresh_cursor()


# ---------- Cursor helpers ----------

func _skip_disabled(direction: int) -> void:
	var n := _nav_buttons.size()
	var tries := 0
	while tries < n and _nav_buttons[_cursor].disabled:
		_cursor = wrapi(_cursor + direction, 0, n)
		tries += 1


func _refresh_cursor() -> void:
	for i in _nav_buttons.size():
		var btn: Button = _nav_buttons[i]
		if i == _cursor and not btn.disabled:
			btn.add_theme_color_override("font_color", UITheme.COL_CURSOR)
		else:
			btn.remove_theme_color_override("font_color")


# ---------- Button handlers ----------

func _on_new_game_2p() -> void:
	var seed_value := parse_seed(_seed_input.text if _seed_input != null else "")
	PauseManager.set_player_enabled(0, true)
	PauseManager.set_player_enabled(1, true)
	GameSession.pending_load_slot = ""
	GameSession.start_new_game(seed_value)
	get_tree().change_scene_to_packed(GameScene)


func _on_new_game_p1() -> void:
	var seed_value := parse_seed(_seed_input.text if _seed_input != null else "")
	PauseManager.set_player_enabled(0, true)
	PauseManager.set_player_enabled(1, false)
	GameSession.pending_load_slot = ""
	GameSession.start_new_game(seed_value)
	get_tree().change_scene_to_packed(GameScene)


func _on_new_game_p2() -> void:
	var seed_value := parse_seed(_seed_input.text if _seed_input != null else "")
	PauseManager.set_player_enabled(0, false)
	PauseManager.set_player_enabled(1, true)
	GameSession.pending_load_slot = ""
	GameSession.start_new_game(seed_value)
	get_tree().change_scene_to_packed(GameScene)


func _on_continue() -> void:
	PauseManager.set_player_enabled(0, true)
	PauseManager.set_player_enabled(1, true)
	GameSession.pending_load_slot = SaveManager.DEFAULT_SLOT
	get_tree().change_scene_to_packed(GameScene)


func _on_quit() -> void:
	get_tree().quit()


# ---------- Test helpers ----------

func get_continue_button() -> Button:
	return _btn_continue

func get_seed_input() -> LineEdit:
	return _seed_input

func get_new_game_2p_button() -> Button:
	return _btn_new_2p

func get_new_game_p1_button() -> Button:
	return _btn_new_p1

func get_new_game_p2_button() -> Button:
	return _btn_new_p2
```

### 3B — PauseMenu

- [ ] **Step 3B.1: Rewrite `scenes/ui/PauseMenu.tscn`**

Replace the entire contents of `scenes/ui/PauseMenu.tscn` with:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/pause_menu.gd" id="1_pause"]

[node name="PauseMenu" type="CanvasLayer"]
layer = 100
script = ExtResource("1_pause")

[node name="Dim" type="ColorRect" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.55)
mouse_filter = 0

[node name="Center" type="CenterContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="Panel" type="PanelContainer" parent="Center"]
custom_minimum_size = Vector2(320, 0)
theme_type_variation = &"WoodPanel"

[node name="Margin" type="MarginContainer" parent="Center/Panel"]
theme_override_constants/margin_left = 24
theme_override_constants/margin_right = 24
theme_override_constants/margin_top = 24
theme_override_constants/margin_bottom = 24

[node name="VBox" type="VBoxContainer" parent="Center/Panel/Margin"]
theme_override_constants/separation = 10

[node name="Title" type="Label" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"TitleLabel"
text = "Paused"
horizontal_alignment = 1

[node name="Resume" type="Button" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"WoodButton"
focus_mode = 0
text = "Resume"

[node name="ToggleP1" type="Button" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"WoodButton"
focus_mode = 0
text = "Disable Player 1"

[node name="ToggleP2" type="Button" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"WoodButton"
focus_mode = 0
text = "Disable Player 2"

[node name="Save" type="Button" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"WoodButton"
focus_mode = 0
text = "Save"

[node name="Exit" type="Button" parent="Center/Panel/Margin/VBox"]
theme_type_variation = &"WoodButton"
focus_mode = 0
text = "Exit"
```

- [ ] **Step 3B.2: Update `scripts/ui/pause_menu.gd` — fix cursor color**

The `@onready` node paths are unchanged. Only update `_refresh_cursor()` to use `UITheme.COL_CURSOR` instead of the hardcoded `Color(1.0, 0.85, 0.3)`:

```gdscript
func _refresh_cursor() -> void:
	for i in _nav_buttons.size():
		var btn: Button = _nav_buttons[i]
		if i == _cursor and not btn.disabled:
			btn.add_theme_color_override("font_color", UITheme.COL_CURSOR)
		else:
			btn.remove_theme_color_override("font_color")
```

### 3C — CaravanMenu

- [ ] **Step 3C.1: Rewrite `scenes/ui/CaravanMenu.tscn`**

Replace the entire contents of `scenes/ui/CaravanMenu.tscn` with:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/caravan_menu.gd" id="1_caravan"]

[node name="CaravanMenu" type="CanvasLayer"]
layer = 45
script = ExtResource("1_caravan")

[node name="Bg" type="ColorRect" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.6)
mouse_filter = 2

[node name="Panel" type="PanelContainer" parent="."]
anchor_left = 0.1
anchor_top = 0.1
anchor_right = 0.9
anchor_bottom = 0.9
theme_type_variation = &"WoodPanel"

[node name="HBox" type="HBoxContainer" parent="Panel"]
theme_override_constants/separation = 0
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="LeftPanel" type="VBoxContainer" parent="Panel/HBox"]
custom_minimum_size = Vector2(160, 0)
theme_override_constants/separation = 6

[node name="TitleBar" type="PanelContainer" parent="Panel/HBox/LeftPanel"]
theme_type_variation = &"TitleBar"

[node name="Title" type="Label" parent="Panel/HBox/LeftPanel/TitleBar"]
theme_type_variation = &"TitleLabel"
text = "Party"
horizontal_alignment = 1

[node name="MembersContainer" type="VBoxContainer" parent="Panel/HBox/LeftPanel"]
name = "MembersContainer"
theme_override_constants/separation = 4

[node name="Sep" type="HSeparator" parent="Panel/HBox/LeftPanel"]

[node name="InvTitle" type="Label" parent="Panel/HBox/LeftPanel"]
theme_type_variation = &"DimLabel"
text = "Caravan Inventory"
horizontal_alignment = 1

[node name="InvList" type="Label" parent="Panel/HBox/LeftPanel"]
name = "InvList"
theme_type_variation = &"HintLabel"
autowrap_mode = 3

[node name="VSep" type="Panel" parent="Panel/HBox"]
custom_minimum_size = Vector2(2, 0)
size_flags_vertical = 3
theme_type_variation = &"WoodSep"

[node name="RightPanel" type="Control" parent="Panel/HBox"]
name = "RightPanel"
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="Placeholder" type="Label" parent="Panel/HBox/RightPanel"]
anchor_right = 1.0
anchor_bottom = 1.0
theme_type_variation = &"DimLabel"
text = "Select a party member."
horizontal_alignment = 1
vertical_alignment = 1
```

- [ ] **Step 3C.2: Rewrite `scripts/ui/caravan_menu.gd`**

Replace the entire file with this version that drops `_build_ui()` and uses `@onready`:

```gdscript
## CaravanMenu
##
## Full-keyboard-navigable overlay opened when the player interacts with
## their caravan wagon. Two focus zones: LEFT (member list) and RIGHT (active panel).
##
## LEFT zone: UP/DOWN moves member cursor, INTERACT selects and shifts focus RIGHT.
## RIGHT zone: navigation delegated to the active sub-panel via navigate(verb).
## BACK returns from RIGHT→LEFT, or closes from LEFT.
class_name CaravanMenu
extends CanvasLayer

enum _Focus { LEFT, RIGHT }

var _player: PlayerController = null
var _player_id: int = 0
var _caravan_data: CaravanData = null

@onready var _members_container: VBoxContainer = $Panel/HBox/LeftPanel/MembersContainer
@onready var _inv_list: Label = $Panel/HBox/LeftPanel/InvList
@onready var _right_panel: Control = $Panel/HBox/RightPanel

var _member_buttons: Array[Button] = []
var _member_ids: Array[StringName] = []
var _current_crafter: CrafterPanel = null

var _member_cursor: int = 0
var _focus: _Focus = _Focus.LEFT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func setup(player: PlayerController, caravan_data: CaravanData) -> void:
	_player = player
	_player_id = player.player_id if player != null else 0
	_caravan_data = caravan_data


func open() -> void:
	if _caravan_data == null:
		return
	_refresh_members()
	_member_cursor = 0
	_focus = _Focus.LEFT
	visible = true
	InputContext.set_context(_player_id, InputContext.Context.INVENTORY)
	_refresh_member_cursor()


func close() -> void:
	visible = false
	InputContext.set_context(_player_id, InputContext.Context.GAMEPLAY)


func _is_my_event(event: InputEvent) -> bool:
	for verb: StringName in [PlayerActions.UP, PlayerActions.DOWN, PlayerActions.LEFT,
			PlayerActions.RIGHT, PlayerActions.INTERACT, PlayerActions.BACK,
			PlayerActions.ATTACK, PlayerActions.INVENTORY, PlayerActions.TAB_PREV,
			PlayerActions.TAB_NEXT, PlayerActions.AUTO_MINE, PlayerActions.AUTO_ATTACK]:
		if event.is_action(PlayerActions.action(_player_id, verb)):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_my_event(event):
		get_viewport().set_input_as_handled()

	if _focus == _Focus.LEFT:
		if PlayerActions.just_pressed(event, _player_id, PlayerActions.UP):
			_member_cursor = wrapi(_member_cursor - 1, 0, max(1, _member_buttons.size()))
			_refresh_member_cursor()
			get_viewport().set_input_as_handled()
		elif PlayerActions.just_pressed(event, _player_id, PlayerActions.DOWN):
			_member_cursor = wrapi(_member_cursor + 1, 0, max(1, _member_buttons.size()))
			_refresh_member_cursor()
			get_viewport().set_input_as_handled()
		elif PlayerActions.just_pressed(event, _player_id, PlayerActions.INTERACT):
			if _member_cursor < _member_ids.size():
				_on_member_selected(_member_ids[_member_cursor])
				_focus = _Focus.RIGHT
			get_viewport().set_input_as_handled()
		elif PlayerActions.just_pressed(event, _player_id, PlayerActions.BACK):
			close()
			get_viewport().set_input_as_handled()
	else:  # _Focus.RIGHT
		if PlayerActions.just_pressed(event, _player_id, PlayerActions.BACK) \
				or PlayerActions.just_pressed(event, _player_id, PlayerActions.LEFT):
			_focus = _Focus.LEFT
			_refresh_member_cursor()
			get_viewport().set_input_as_handled()
		else:
			var panel: Node = _get_active_right_panel()
			if panel != null and panel.has_method("navigate"):
				for verb: StringName in [PlayerActions.UP, PlayerActions.DOWN,
						PlayerActions.LEFT, PlayerActions.RIGHT, PlayerActions.INTERACT,
						PlayerActions.TAB_PREV, PlayerActions.TAB_NEXT]:
					if PlayerActions.just_pressed(event, _player_id, verb):
						panel.call("navigate", verb)
						get_viewport().set_input_as_handled()
						break


func _get_active_right_panel() -> Node:
	if _right_panel == null:
		return null
	if _current_crafter != null:
		return _current_crafter
	return _right_panel.get_child(0) if _right_panel.get_child_count() > 0 else null


func _refresh_members() -> void:
	if _caravan_data == null or _members_container == null:
		return
	for child in _members_container.get_children():
		child.queue_free()
	_member_buttons.clear()
	_member_ids.clear()

	for id: StringName in _caravan_data.recruited_ids:
		var def: PartyMemberDef = PartyMemberRegistry.get_member(id)
		if def == null:
			continue
		var btn := Button.new()
		btn.text = def.display_name
		btn.focus_mode = Control.FOCUS_NONE
		btn.theme_type_variation = &"WoodButton"
		btn.pressed.connect(_on_member_selected.bind(id))
		_members_container.add_child(btn)
		_member_buttons.append(btn)
		_member_ids.append(id)

	if _inv_list != null and _caravan_data.inventory != null:
		var lines: Array[String] = []
		for slot in _caravan_data.inventory.slots:
			if slot != null:
				var item_def: ItemDefinition = ItemRegistry.get_item(slot["id"])
				var item_name: String = item_def.display_name if item_def != null else String(slot["id"])
				lines.append("%s ×%d" % [item_name, slot["count"]])
		_inv_list.text = "\n".join(lines) if not lines.is_empty() else "(empty)"


func _refresh_member_cursor() -> void:
	for i in _member_buttons.size():
		var btn: Button = _member_buttons[i]
		var is_selected: bool = (i == _member_cursor and _focus == _Focus.LEFT)
		if is_selected:
			btn.add_theme_color_override("font_color", UITheme.COL_CURSOR)
		else:
			btn.remove_theme_color_override("font_color")


func _on_member_selected(member_id: StringName) -> void:
	for child in _right_panel.get_children():
		child.queue_free()
	_current_crafter = null

	var def: PartyMemberDef = PartyMemberRegistry.get_member(member_id)
	if def == null:
		return

	if def.crafter_domain != &"":
		_current_crafter = CrafterPanel.new()
		_current_crafter.name = "ActiveCrafter"
		_current_crafter.anchor_right = 1.0
		_current_crafter.anchor_bottom = 1.0
		_right_panel.add_child(_current_crafter)
		_current_crafter.set_crafter(def.crafter_domain, _caravan_data)
	elif member_id == &"story_teller":
		var panel := StoryTellerPanel.new()
		panel.name = "StoryTellerPanel"
		panel.anchor_right = 1.0
		panel.anchor_bottom = 1.0
		_right_panel.add_child(panel)
		panel.setup(_player, _caravan_data)
	else:
		var label := Label.new()
		label.theme_type_variation = &"DimLabel"
		var member_name: String = _caravan_data.get_member_name(member_id) \
				if _caravan_data != null else String(member_id)
		label.text = "%s\nHP: Active companion" % member_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		_right_panel.add_child(label)
```

- [ ] **Step 3D: Run all unit + integration tests**

```bash
cd /home/mpatterson/repos/game4
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | grep -E "Passing|Failing"
```

Expected: 0 failing tests.

- [ ] **Step 3E: Commit**

```bash
cd /home/mpatterson/repos/game4
git add scenes/ui/MainMenu.tscn scripts/ui/main_menu.gd \
        scenes/ui/PauseMenu.tscn scripts/ui/pause_menu.gd \
        scenes/ui/CaravanMenu.tscn scripts/ui/caravan_menu.gd
git commit -m "feat: rebuild MainMenu, PauseMenu, CaravanMenu as full .tscn with WoodTheme"
```

---

## Task 4: Strip style code from inventory_screen.gd and supporting panels

**Files:**
- Modify: `scripts/ui/inventory_screen.gd`
- Modify: `scripts/ui/hotbar_slot.gd`
- Modify: `scripts/ui/crafter_panel.gd`
- Modify: `scripts/ui/crafting_panel.gd`

### 4A — inventory_screen.gd

The inventory screen stays programmatic (variable slot count). This task removes all `COL_*` constants, replaces `_make_*_style()` helper calls with `theme_type_variation` assignments, and switches `COL_*` references to `UITheme.COL_*`.

- [ ] **Step 4A.1: Delete `COL_*` constants block**

In `inventory_screen.gd`, delete these 12 lines (they now live in `UITheme`):

```gdscript
# Fantasy UI colour palette (Pixel Adventure wood tones).
const COL_BG        := Color(0.16, 0.11, 0.09, 0.95)
const COL_FRAME     := Color(0.62, 0.42, 0.22)
const COL_SLOT_BG   := Color(0.22, 0.14, 0.09, 0.85)
const COL_SLOT_BRD  := Color(0.50, 0.34, 0.18)
const COL_TITLE_BG  := Color(0.34, 0.21, 0.13)
const COL_PARCHMENT := Color(0.28, 0.20, 0.14, 0.60)
const COL_SILHOUETTE := Color(0.45, 0.34, 0.24, 0.35)
const COL_LABEL     := Color(0.88, 0.82, 0.70)
const COL_LABEL_DIM := Color(0.55, 0.48, 0.38)
const COL_TAB_ACTIVE   := Color(0.34, 0.21, 0.13)
const COL_TAB_INACTIVE := Color(0.20, 0.14, 0.10)
const COL_CURSOR    := Color(0.95, 0.85, 0.45, 0.9)
```

- [ ] **Step 4A.2: Delete all `_make_*_style()` helpers**

Delete these entire functions from `inventory_screen.gd`:
- `_make_frame_style() -> StyleBoxFlat`
- `_make_paperdoll_bg_style() -> StyleBoxFlat`
- `_make_vtab_style(active: bool) -> StyleBoxFlat`
- `_make_cursor_style() -> StyleBoxFlat`
- `_make_vsep() -> Panel`

- [ ] **Step 4A.3: Update `_build()` — main panel**

Replace the main panel `add_theme_stylebox_override` call:

```gdscript
# OLD:
panel.add_theme_stylebox_override("panel", _make_frame_style())

# NEW:
panel.theme_type_variation = &"WoodPanel"
```

- [ ] **Step 4A.4: Update `_build_title_bar()`**

Replace the function body:

```gdscript
func _build_title_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"TitleBar"
	# top corners only — override just those radius values to round top
	var lbl := Label.new()
	lbl.text = "Equipment & Inventory"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.theme_type_variation = &"TitleLabel"
	bar.add_child(lbl)
	return bar
```

- [ ] **Step 4A.5: Update `_build_tab_column()` — tab buttons**

Replace the per-button style code in the `for` loop:

```gdscript
# OLD:
btn.add_theme_color_override("font_color", Color.WHITE if is_default else COL_LABEL_DIM)
btn.add_theme_color_override("font_hover_color", Color.WHITE)
btn.add_theme_font_size_override("font_size", 13)
btn.add_theme_stylebox_override("normal", _make_vtab_style(is_default))
btn.add_theme_stylebox_override("hover", _make_vtab_style(true))
btn.add_theme_stylebox_override("pressed", _make_vtab_style(true))

# NEW:
btn.theme_type_variation = &"WoodTabButtonActive" if is_default else &"WoodTabButton"
```

- [ ] **Step 4A.6: Update `_select_tab()` — swap active/inactive tab style**

```gdscript
# OLD:
_tab_buttons[i].add_theme_stylebox_override("normal", _make_vtab_style(active))
_tab_buttons[i].add_theme_color_override("font_color",
    Color.WHITE if active else COL_LABEL_DIM)

# NEW:
_tab_buttons[i].theme_type_variation = \
    &"WoodTabButtonActive" if active else &"WoodTabButton"
```

- [ ] **Step 4A.7: Update `_build_controls_bar()`**

```gdscript
func _build_controls_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"TitleBar"
	_controls_label = RichTextLabel.new()
	_controls_label.bbcode_enabled = true
	_controls_label.fit_content = true
	_controls_label.scroll_active = false
	_controls_label.custom_minimum_size = Vector2(0, 18)
	_controls_label.add_theme_font_size_override("normal_font_size", 13)
	_controls_label.add_theme_color_override("default_color", UITheme.COL_LABEL_DIM)
	bar.add_child(_controls_label)
	_update_controls_text()
	return bar
```

- [ ] **Step 4A.8: Update `_build_paperdoll()` — paperdoll bg and silhouette**

```gdscript
# OLD paperdoll background:
bg.add_theme_stylebox_override("panel", _make_paperdoll_bg_style())

# NEW:
bg.theme_type_variation = &"WoodInnerPanel"
```

For `_silhouette_part()`, the silhouette color is `UITheme.COL_SILHOUETTE`. Update all references:

```gdscript
# OLD:
sb.bg_color = COL_SILHOUETTE

# NEW:
sb.bg_color = UITheme.COL_SILHOUETTE
```

- [ ] **Step 4A.9: Update `_build_grid_page()` — cursor panel**

```gdscript
# OLD:
_cursor_panel.add_theme_stylebox_override("panel", _make_cursor_style())

# NEW:
_cursor_panel.theme_type_variation = &"CursorPanel"
```

- [ ] **Step 4A.10: Update `_build_grid_page()` — detail labels**

```gdscript
# OLD:
_detail_name_label.add_theme_color_override("font_color", COL_LABEL)
_detail_name_label.add_theme_font_size_override("font_size", 13)
...
_detail_desc_label.add_theme_color_override("font_color", COL_LABEL_DIM)
_detail_desc_label.add_theme_font_size_override("font_size", 11)

# NEW:
_detail_name_label.theme_type_variation = &"DimLabel"
# (name label gets DimLabel base size, then color-overridden per-item by _show_item_detail)
_detail_desc_label.theme_type_variation = &"HintLabel"
```

- [ ] **Step 4A.11: Update `_make_slot()` — use SlotPanel variation**

Replace `_make_slot()` entirely:

```gdscript
func _make_slot() -> HotbarSlot:
	var slot := HotbarSlot.new()
	slot.custom_minimum_size = Vector2(UITheme.SLOT_SZ, UITheme.SLOT_SZ)
	var bg := Panel.new()
	bg.name = "BgPanel"
	bg.theme_type_variation = &"SlotPanel"
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	var count_label := Label.new()
	count_label.name = "Count"
	count_label.theme_type_variation = &"HintLabel"
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 1.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count_label)
	return slot
```

- [ ] **Step 4A.12: Update `_build_character_page()` — preview panel and char rows**

```gdscript
# OLD preview panel:
preview_panel.add_theme_stylebox_override("panel", _make_paperdoll_bg_style())

# NEW:
preview_panel.theme_type_variation = &"WoodInnerPanel"
```

For char row labels:
```gdscript
# OLD:
name_label.add_theme_color_override("font_color", COL_LABEL_DIM)
name_label.add_theme_font_size_override("font_size", 13)
...
value_label.add_theme_color_override("font_color", COL_LABEL)
value_label.add_theme_font_size_override("font_size", 13)

# NEW:
name_label.theme_type_variation = &"DimLabel"
value_label.theme_type_variation = &"DimLabel"
```

- [ ] **Step 4A.13: Update all remaining `COL_*` references to `UITheme.COL_*`**

Search for any remaining `COL_` references in `inventory_screen.gd` and prefix them with `UITheme.`. Specifically:
- `COL_LABEL` → `UITheme.COL_LABEL`
- `COL_LABEL_DIM` → `UITheme.COL_LABEL_DIM`
- `COL_CURSOR` → `UITheme.COL_CURSOR`
- `COL_FRAME` → `UITheme.COL_FRAME` (used in `_make_vsep` which is deleted, but check for others)
- `COL_SILHOUETTE` → `UITheme.COL_SILHOUETTE`

Confirm with:
```bash
grep -n "COL_" /home/mpatterson/repos/game4/scripts/ui/inventory_screen.gd
```
Expected: 0 matches.

- [ ] **Step 4A.14: Update vertical separator**

The old `_make_vsep()` function is deleted. Replace its call site in `_build()`:

```gdscript
# OLD:
content_row.add_child(_make_vsep())

# NEW:
var vsep := Panel.new()
vsep.custom_minimum_size = Vector2(2, 0)
vsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
vsep.theme_type_variation = &"WoodSep"
content_row.add_child(vsep)
```

### 4B — hotbar_slot.gd

`HotbarSlot` currently builds a `StyleBoxFlat` in `_apply_polish()`. Replace this with a `SlotPanel` type variation, but keep the rarity border-color override (rarity tinting must still work by directly modifying the stylebox on `SlotPanel`).

- [ ] **Step 4B.1: Update `hotbar_slot.gd` — replace `_apply_polish()`**

The rarity override must still work. The approach: set `theme_type_variation = &"SlotPanel"` on the Panel, but store a reference to a **duplicated** stylebox on the panel so rarity can modify it without mutating the shared theme resource.

Replace `_apply_polish()`:

```gdscript
func _apply_polish() -> void:
	if _bg == null or not is_instance_valid(_bg):
		return
	var panel := Panel.new()
	panel.name = "BgPanel"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Duplicate the theme stylebox so rarity can modify border color per-instance.
	var base_sb: StyleBoxFlat = get_theme_stylebox(&"panel", &"SlotPanel") as StyleBoxFlat
	var sb: StyleBoxFlat
	if base_sb != null:
		sb = base_sb.duplicate() as StyleBoxFlat
	else:
		# Fallback if theme not loaded yet (e.g. tests).
		sb = StyleBoxFlat.new()
		sb.bg_color = UITheme.COL_SLOT_BG
		sb.border_color = UITheme.COL_SLOT_BRD
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 3
		sb.corner_radius_top_right = 3
		sb.corner_radius_bottom_left = 3
		sb.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", sb)
	_bg.add_sibling(panel)
	_bg.queue_free()
	_bg = nil
	_bg_panel = panel
```

Also update `_DEFAULT_BORDER` constant:

```gdscript
# OLD:
const _DEFAULT_BORDER := Color(0.62, 0.42, 0.22)

# NEW — delegate to UITheme:
static var _DEFAULT_BORDER: Color:
	get: return UITheme.COL_FRAME
```

### 4C — crafter_panel.gd and crafting_panel.gd

These build `Button` nodes at runtime. Apply `WoodButton` variation.

- [ ] **Step 4C.1: Update `crafter_panel.gd` — recipe buttons**

In `_build()`, after creating each recipe button:

```gdscript
# OLD:
var btn := Button.new()
btn.text = CraftingPanel.format_recipe_label(recipe)
btn.pressed.connect(_on_pressed.bind(recipe.id))
v.add_child(btn)
_buttons.append(btn)

# NEW:
var btn := Button.new()
btn.theme_type_variation = &"WoodButton"
btn.text = CraftingPanel.format_recipe_label(recipe)
btn.pressed.connect(_on_pressed.bind(recipe.id))
v.add_child(btn)
_buttons.append(btn)
```

Also update `_refresh_cursor()` to use `UITheme.COL_CURSOR`:

```gdscript
# OLD:
btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

# NEW:
btn.add_theme_color_override("font_color", UITheme.COL_CURSOR)
```

- [ ] **Step 4C.2: Update `crafting_panel.gd` — recipe buttons**

In `_build()`:

```gdscript
# OLD:
var btn := Button.new()
btn.text = format_recipe_label(recipe)
btn.pressed.connect(_on_pressed.bind(recipe.id))
_list.add_child(btn)
_buttons.append(btn)

# NEW:
var btn := Button.new()
btn.theme_type_variation = &"WoodButton"
btn.text = format_recipe_label(recipe)
btn.pressed.connect(_on_pressed.bind(recipe.id))
_list.add_child(btn)
_buttons.append(btn)
```

- [ ] **Step 4D: Run all tests**

```bash
cd /home/mpatterson/repos/game4
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | grep -E "Passing|Failing"
```

Expected: 0 failing.

- [ ] **Step 4E: Commit**

```bash
cd /home/mpatterson/repos/game4
git add scripts/ui/inventory_screen.gd scripts/ui/hotbar_slot.gd \
        scripts/ui/crafter_panel.gd scripts/ui/crafting_panel.gd
git commit -m "refactor: strip inline style code from UI scripts, apply UITheme type variations"
```

---

## Final verification

- [ ] Run game via `./run.sh` and confirm:
  - Main menu shows WoodPanel frame, WoodButton styled buttons, gold cursor highlight
  - Pause menu matches inventory style exactly
  - Caravan menu matches inventory style exactly
  - Inventory screen looks identical to before (no regression)
  - Gold cursor ring color is consistent across all screens
  - Tab highlight on inventory left column still works (gold left border)
  - Rarity border colors on hotbar slots still work

- [ ] Run full test suite:

```bash
cd /home/mpatterson/repos/game4
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] Final commit tag:

```bash
cd /home/mpatterson/repos/game4
git log --oneline -6
```
