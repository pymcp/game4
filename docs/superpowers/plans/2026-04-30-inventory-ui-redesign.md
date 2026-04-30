# Inventory UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the inventory screen to always show the paper doll in a right column, add floating item tooltips, add a rich item detail panel, merge character appearance + stats + level-up into one Character tab, and remove XP/level from the HUD (keeping only a brief level-up flash).

**Architecture:** All changes are isolated to UI scripts and `ActionParticles`. No data classes, autoloads, or test infrastructure change beyond updating tests that reference the removed `Tab.EQUIPMENT` or `LevelUpPanel`. Tasks are ordered so each one leaves the game in a working state.

**Tech Stack:** Godot 4.3, GDScript, GUT test framework.

**Spec:** `docs/superpowers/specs/2026-04-30-inventory-ui-redesign.md`

---

## File Map

| File | Action | Notes |
|------|--------|-------|
| `scripts/entities/action_particles.gd` | Modify | Add `flash_level_up()` static method |
| `scripts/entities/player_controller.gd` | Modify | Call `flash_level_up()` in `_level_up()` |
| `scripts/ui/player_hud.gd` | Modify | Remove XpBar + passive banner; add "LEVEL UP!" flash label |
| `scripts/ui/inventory_screen.gd` | Modify | Right column doll, remove Equipment tab, floating tooltip, upgraded detail panel |
| `scripts/ui/inventory_screen.gd` | Modify | Character tab: stats section + inline level-up, replaces LevelUpPanel |
| `scripts/ui/level_up_panel.gd` | **Delete** | Logic absorbed into Character tab |
| `tests/unit/test_character_builder_ui.gd` | Modify | Update tests that reference removed `Tab.EQUIPMENT`; add Character tab stat tests |

---

## Task 1: Add `flash_level_up` to ActionParticles

**Files:**
- Modify: `scripts/entities/action_particles.gd`
- Test: `tests/unit/test_action_particles.gd` (create if not exists)

- [ ] **Step 1: Write the failing test**

Check if a test file exists first:
```bash
ls tests/unit/test_action_particles.gd 2>/dev/null || echo "missing"
```

If missing, create `tests/unit/test_action_particles.gd`:
```gdscript
extends GutTest

func test_flash_level_up_does_not_crash_on_null() -> void:
	# Must not throw — safe to call with null
	ActionParticles.flash_level_up(null)
	pass

func test_flash_level_up_exists() -> void:
	assert_true(ActionParticles.has_method("flash_level_up"),
		"ActionParticles should have flash_level_up static method")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "test_flash_level_up|FAILED|passed"
```

Expected: FAIL — `flash_level_up` not defined.

- [ ] **Step 3: Implement `flash_level_up` in `action_particles.gd`**

Current file ends after `flash_hit`. Append after line 15:

```gdscript
## Flash a [CanvasItem] bright yellow for ~1 s as level-up feedback.
## Tween: yellow peak over 0.1 s, hold 0.2 s, fade back over 0.7 s.
static func flash_level_up(node: CanvasItem) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "modulate", Color(3.0, 2.5, 0.0, 1.0), 0.1)
	tw.tween_interval(0.2)
	tw.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.7)
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "test_flash_level_up|FAILED|passed"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/entities/action_particles.gd tests/unit/test_action_particles.gd
git commit -m "feat: add flash_level_up to ActionParticles"
```

---

## Task 2: Call `flash_level_up` from `PlayerController._level_up()`

**Files:**
- Modify: `scripts/entities/player_controller.gd` (around line 91–100)

- [ ] **Step 1: Verify the existing test for `_level_up` still passes before touching anything**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "test_level|FAILED|passed"
```

Expected: all leveling tests pass.

- [ ] **Step 2: Add the flash call in `_level_up()`**

Current `_level_up()` in `player_controller.gd` (lines ~91–99):
```gdscript
func _level_up() -> void:
	level += 1
	max_health += 2
	health = min(health + 2, max_health)
	var passive: StringName = LevelingConfig.milestone_passive(level)
	if passive != &"":
		_unlock_passive(passive)
	_pending_stat_points += 1
	leveled_up.emit(player_id, level)
```

Replace with:
```gdscript
func _level_up() -> void:
	level += 1
	max_health += 2
	health = min(health + 2, max_health)
	var passive: StringName = LevelingConfig.milestone_passive(level)
	if passive != &"":
		_unlock_passive(passive)
	_pending_stat_points += 1
	ActionParticles.flash_level_up(self)
	leveled_up.emit(player_id, level)
```

- [ ] **Step 3: Run all unit tests**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

Expected: all pass (the flash call is a no-op in headless test context since there's no CanvasItem).

- [ ] **Step 4: Commit**

```bash
git add scripts/entities/player_controller.gd
git commit -m "feat: yellow flash on level-up via ActionParticles"
```

---

## Task 3: Simplify `PlayerHUD` — remove XpBar/passive banner, add "LEVEL UP!" flash

**Files:**
- Modify: `scripts/ui/player_hud.gd`

**Current state of `player_hud.gd` relevant parts:**

Fields to remove:
```gdscript
var _xp_bar: XpBar = null
var _passive_banner: Label = null
```

`_build()` code to remove:
- `_xp_bar = XpBar.new()` block (3 lines, position `MARGIN + 30`)
- `_passive_banner = Label.new()` block (~12 lines)
- `_status_container.position` currently at `MARGIN + 50` — move back to `MARGIN + 30`

`_process()` code to remove:
```gdscript
	if _player != null and _xp_bar != null:
		_xp_bar.update(
			_player.xp,
			_player.level,
			LevelingConfig.xp_to_next(_player.level),
			_player._pending_stat_points > 0
		)
```

`_on_leveled_up()` currently shows `_passive_banner`. Replace entirely.

- [ ] **Step 1: Remove `_xp_bar` and `_passive_banner` fields and all usages**

Edit `player_hud.gd`:

**Field declarations** — replace:
```gdscript
var _xp_bar: XpBar = null
var _passive_banner: Label = null
```
with:
```gdscript
var _level_flash_label: Label = null
```

**In `_build()` — remove the XpBar block:**
```gdscript
	# XP bar below hearts.
	_xp_bar = XpBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.position = Vector2(MARGIN, MARGIN + 30)
	add_child(_xp_bar)
```
Delete those 4 lines entirely.

**In `_build()` — remove the passive banner block:**
```gdscript
	# Passive unlock notification banner (hidden by default).
	_passive_banner = Label.new()
	_passive_banner.name = "PassiveBanner"
	_passive_banner.add_theme_font_size_override("font_size", 14)
	_passive_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_passive_banner.anchor_left = 0.5
	_passive_banner.anchor_right = 0.5
	_passive_banner.offset_left = -150
	_passive_banner.offset_right = 150
	_passive_banner.offset_top = 60
	_passive_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_passive_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_passive_banner.visible = false
	add_child(_passive_banner)
```
Delete those 14 lines entirely.

**In `_build()` — move status container back up** (was pushed to `MARGIN + 50` to make room for XP bar):

Change:
```gdscript
	_status_container.position = Vector2(MARGIN, MARGIN + 50)
```
to:
```gdscript
	_status_container.position = Vector2(MARGIN, MARGIN + 30)
```

**Add `_level_flash_label` creation at end of `_build()`, before the hotbar block:**
```gdscript
	# Level-up flash label — centred horizontally, 25% down.
	_level_flash_label = Label.new()
	_level_flash_label.name = "LevelFlash"
	_level_flash_label.text = "LEVEL UP!"
	_level_flash_label.add_theme_font_size_override("font_size", 18)
	_level_flash_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_level_flash_label.anchor_left = 0.5
	_level_flash_label.anchor_right = 0.5
	_level_flash_label.anchor_top = 0.25
	_level_flash_label.offset_left = -100
	_level_flash_label.offset_right = 100
	_level_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_flash_label.visible = false
	add_child(_level_flash_label)
```

**In `_process()` — remove the XpBar poll block:**
```gdscript
	if _player != null and _xp_bar != null:
		_xp_bar.update(
			_player.xp,
			_player.level,
			LevelingConfig.xp_to_next(_player.level),
			_player._pending_stat_points > 0
		)
```
Delete those 7 lines.

**Replace `_on_leveled_up()` entirely:**

Old:
```gdscript
func _on_leveled_up(_pid: int, new_level: int) -> void:
	var passive: StringName = LevelingConfig.milestone_passive(new_level)
	if passive == &"" or _passive_banner == null:
		return
	var names: Dictionary = {
		&"hardy": "Hardy", &"scavenger": "Scavenger",
		&"iron_skin": "Iron Skin", &"hero": "Hero"
	}
	_passive_banner.text = "PASSIVE UNLOCKED: %s" % names.get(passive, str(passive))
	_passive_banner.visible = true
	_passive_banner.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_passive_banner, "modulate:a", 0.0, 0.5)
```

New:
```gdscript
func _on_leveled_up(_pid: int, _new_level: int) -> void:
	if _level_flash_label == null:
		return
	_level_flash_label.visible = true
	_level_flash_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tw: Tween = create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_level_flash_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _level_flash_label.visible = false)
```

- [ ] **Step 2: Run all unit tests**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/player_hud.gd
git commit -m "feat: replace XP bar on HUD with level-up flash label"
```

---

## Task 4: Inventory screen — add right column paper doll, remove Equipment tab

**Files:**
- Modify: `scripts/ui/inventory_screen.gd`

**Key current code:**

`Tab` enum (line ~40):
```gdscript
enum Tab { EQUIPMENT, ALL, WEAPONS, ARMOR, TOOLS, MATERIALS, CHARACTER }
```

`TAB_LABELS` (line ~44):
```gdscript
const TAB_LABELS: Array = [
	"Equipment",
	"All Items",
	"Weapons",
	"Armor",
	"Tools",
	"Materials",
	"Character",
]
```

`_build()` builds `content_row` as:  
`_tab_column` | `vsep` | `content_margin (→ _content_stack)`

`_eq_page` is built by `_build_equipment_page()` which contains `_paperdoll` via `_build_paperdoll()`.

- [ ] **Step 1: Remove `Tab.EQUIPMENT` and shift Tab enum**

Replace:
```gdscript
enum Tab { EQUIPMENT, ALL, WEAPONS, ARMOR, TOOLS, MATERIALS, CHARACTER }

const TAB_LABELS: Array = [
	"Equipment",
	"All Items",
	"Weapons",
	"Armor",
	"Tools",
	"Materials",
	"Character",
]
```
with:
```gdscript
enum Tab { ALL, WEAPONS, ARMOR, TOOLS, MATERIALS, CHARACTER }

const TAB_LABELS: Array = [
	"All Items",
	"Weapons",
	"Armor",
	"Tools",
	"Materials",
	"Character",
]
```

Also update `TAB_SLOT_FILTER` — remove any `Tab.EQUIPMENT` key if present, and fix all other Tab values (they now start at 0=ALL). Current `TAB_SLOT_FILTER`:
```gdscript
const TAB_SLOT_FILTER: Dictionary = {
	Tab.ALL: null,
	Tab.WEAPONS: [ItemDefinition.Slot.WEAPON],
	Tab.ARMOR: [ItemDefinition.Slot.HEAD, ItemDefinition.Slot.BODY, ItemDefinition.Slot.FEET, ItemDefinition.Slot.OFF_HAND],
	Tab.TOOLS: [ItemDefinition.Slot.TOOL],
	Tab.MATERIALS: [ItemDefinition.Slot.NONE],
}
```
This is fine — no `Tab.EQUIPMENT` key present. No change needed here.

- [ ] **Step 2: Add right column to `_build()` and extract paperdoll**

The `_eq_page` field and `_build_equipment_page()` currently wrap `_paperdoll`. We need to:
1. Move paperdoll creation outside `_eq_page` into a permanent right column
2. Remove `_eq_page` from `_content_stack`

In `_build()`, find the block:
```gdscript
	# Right: content stack (only one child visible at a time).
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(content_margin)

	_content_stack = Control.new()
	_content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(_content_stack)

	# Build all content pages.
	_eq_page = _build_equipment_page()
	_eq_page.visible = false
	_content_stack.add_child(_eq_page)

	_grid_page = _build_grid_page()
	_content_stack.add_child(_grid_page)

	_char_page = _build_character_page()
	_char_page.visible = false
	_content_stack.add_child(_char_page)

	_level_up_panel = LevelUpPanel.new()
	_level_up_panel.name = "LevelUpPanel"
	_level_up_panel.visible = false
	_content_stack.add_child(_level_up_panel)
```

Replace with:
```gdscript
	# Middle: content stack (only one child visible at a time).
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(content_margin)

	_content_stack = Control.new()
	_content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(_content_stack)

	# Build content pages (no Equipment page — doll is always visible at right).
	_grid_page = _build_grid_page()
	_content_stack.add_child(_grid_page)

	_char_page = _build_character_page()
	_char_page.visible = false
	_content_stack.add_child(_char_page)

	# Right separator.
	var rsep := Panel.new()
	rsep.custom_minimum_size = Vector2(2, 0)
	rsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rsep.theme_type_variation = &"WoodSep"
	content_row.add_child(rsep)

	# Right column: permanent paper doll.
	var doll_margin := MarginContainer.new()
	doll_margin.add_theme_constant_override("margin_left", 8)
	doll_margin.add_theme_constant_override("margin_right", 8)
	doll_margin.add_theme_constant_override("margin_top", 8)
	doll_margin.add_theme_constant_override("margin_bottom", 8)
	doll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(doll_margin)

	_paperdoll = _build_paperdoll()
	doll_margin.add_child(_paperdoll)
```

Also **expand the panel minimum width** from 720 to 880. Find:
```gdscript
	panel.custom_minimum_size = Vector2(720, 460)
```
Replace with:
```gdscript
	panel.custom_minimum_size = Vector2(880, 460)
```

- [ ] **Step 3: Remove `_eq_page` field and `_build_equipment_page()` method**

Remove the field declaration:
```gdscript
var _eq_page: Control = null
```

Remove the method `_build_equipment_page()`:
```gdscript
func _build_equipment_page() -> HBoxContainer:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.anchor_right = 1.0
	page.anchor_bottom = 1.0

	_paperdoll = _build_paperdoll()
	page.add_child(_paperdoll)
	return page
```

- [ ] **Step 4: Fix `_select_tab()` — remove Equipment references**

Current `_select_tab()` has:
```gdscript
	_eq_page.visible = (tab_idx == Tab.EQUIPMENT)
	_grid_page.visible = (tab_idx not in [Tab.EQUIPMENT, Tab.CHARACTER])
	_char_page.visible = (tab_idx == Tab.CHARACTER) and (_player == null or _player._pending_stat_points <= 0)
	if tab_idx == Tab.CHARACTER:
		# Show level-up panel instead of character builder if stat points pending.
		var has_points: bool = _player != null and _player._pending_stat_points > 0
		if has_points:
			if _level_up_panel != null and _player != null:
				_level_up_panel.setup(_player)
				_level_up_panel.visible = true
			_char_page.visible = false
		else:
			if _level_up_panel != null:
				_level_up_panel.visible = false
			_load_char_opts_from_session()
			_refresh_char_preview()
			_refresh_char_labels()
```

Replace with:
```gdscript
	_grid_page.visible = (tab_idx != Tab.CHARACTER)
	_char_page.visible = (tab_idx == Tab.CHARACTER)
	if tab_idx == Tab.CHARACTER:
		_load_char_opts_from_session()
		_refresh_char_preview()
		_refresh_char_labels()
		_refresh_char_stats()
```

Also remove `_level_up_panel` field declaration:
```gdscript
var _level_up_panel: LevelUpPanel = null
```

- [ ] **Step 5: Fix `_move_cursor()` — remove Equipment branch**

Current:
```gdscript
func _move_cursor(dx: int, dy: int) -> void:
	if _current_tab == Tab.EQUIPMENT:
		# Navigate equipment slots (5 slots, vertical list).
		_cursor = clampi(_cursor + dy + dx, 0, EQUIPMENT_SLOT_ORDER.size() - 1)
		_refresh_cursor()
		return
	if _current_tab == Tab.CHARACTER:
```

Remove the Equipment branch:
```gdscript
func _move_cursor(dx: int, dy: int) -> void:
	if _current_tab == Tab.CHARACTER:
```

- [ ] **Step 6: Fix `_refresh_cursor()` — remove Equipment branch**

Current:
```gdscript
func _refresh_cursor() -> void:
	if _current_tab == Tab.EQUIPMENT:
		# Highlight the equipment slot.
		if _cursor >= 0 and _cursor < _eq_slots.size():
			var slot: HotbarSlot = _eq_slots[_cursor]
			_cursor_panel.visible = true
			_cursor_panel.global_position = slot.global_position - Vector2(2, 2)
			_cursor_panel.size = slot.size + Vector2(4, 4)
		_update_detail_equipment()
		return

	if _current_tab == Tab.CHARACTER:
```

Remove the Equipment branch entirely so it starts with:
```gdscript
func _refresh_cursor() -> void:
	if _current_tab == Tab.CHARACTER:
```

- [ ] **Step 7: Fix `_interact_cursor()` and `_drop_cursor()` — remove Equipment branches**

In `_interact_cursor()`, remove:
```gdscript
	if _current_tab == Tab.EQUIPMENT:
		# Unequip the selected slot.
		if _cursor >= 0 and _cursor < EQUIPMENT_SLOT_ORDER.size():
			var slot_type: int = EQUIPMENT_SLOT_ORDER[_cursor]
			var eq_id: StringName = _player.equipment.get_equipped(slot_type)
			if eq_id != &"":
				_player.equipment.unequip(slot_type)
				_player.inventory.add(eq_id, 1)
		return
```

In `_drop_cursor()`, remove:
```gdscript
	if _current_tab == Tab.EQUIPMENT:
		# Drop equipped item.
		if _cursor >= 0 and _cursor < EQUIPMENT_SLOT_ORDER.size():
			var slot_type: int = EQUIPMENT_SLOT_ORDER[_cursor]
			var eq_id: StringName = _player.equipment.get_equipped(slot_type)
			if eq_id != &"":
				_player.equipment.unequip(slot_type)
				_spawn_loot_pickup(eq_id, 1)
		return
```

- [ ] **Step 8: Run all unit tests**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

Expected: all pass (some tests in `test_character_builder_ui.gd` may fail if they reference `Tab.EQUIPMENT` — those will be fixed in Task 7).

- [ ] **Step 9: Commit**

```bash
git add scripts/ui/inventory_screen.gd
git commit -m "feat: permanent right-column paper doll, remove Equipment tab"
```

---

## Task 5: Floating tooltip for item slots

**Files:**
- Modify: `scripts/ui/inventory_screen.gd`

- [ ] **Step 1: Add `_tooltip_label` field**

Add after the other UI ref fields (near `_detail_label`):
```gdscript
var _tooltip_label: Label = null
```

- [ ] **Step 2: Create the tooltip label in `_build()`**

Add at the end of `_build()` (after all other children, so it renders on top):
```gdscript
	# Floating tooltip — rendered above all other children.
	_tooltip_label = Label.new()
	_tooltip_label.name = "Tooltip"
	_tooltip_label.add_theme_font_size_override("font_size", 11)
	_tooltip_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85))
	_tooltip_label.add_theme_stylebox_override("normal", _make_tooltip_style())
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.z_index = 100
	_tooltip_label.visible = false
	add_child(_tooltip_label)
```

- [ ] **Step 3: Add `_make_tooltip_style()` helper**

Add as a private method:
```gdscript
func _make_tooltip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb
```

- [ ] **Step 4: Add `_show_tooltip()` and `_hide_tooltip()` helpers**

```gdscript
func _show_tooltip(item_name: String, near_slot: Control) -> void:
	if _tooltip_label == null or near_slot == null:
		return
	_tooltip_label.text = item_name
	# Force layout to get correct size.
	_tooltip_label.reset_size()
	var slot_pos: Vector2 = near_slot.global_position - global_position
	var tip_x: float = slot_pos.x + near_slot.size.x * 0.5 - _tooltip_label.size.x * 0.5
	var tip_y: float = slot_pos.y - _tooltip_label.size.y - 4.0
	# Clamp within our own rect.
	tip_x = clampf(tip_x, 0.0, size.x - _tooltip_label.size.x)
	tip_y = maxf(tip_y, 0.0)
	_tooltip_label.position = Vector2(tip_x, tip_y)
	_tooltip_label.visible = true


func _hide_tooltip() -> void:
	if _tooltip_label != null:
		_tooltip_label.visible = false
```

- [ ] **Step 5: Call `_show_tooltip` / `_hide_tooltip` from `_refresh_cursor()`**

In `_refresh_cursor()`, at the point where a non-empty grid slot is confirmed (after the `if entry["id"] != &"":` block), add tooltip call. Also add `_hide_tooltip()` to the empty/else branches.

Find the detail update block at the end of `_refresh_cursor()`:
```gdscript
	# Update detail text.
	if _cursor >= 0 and _cursor < _filtered_view.size():
		var entry: Dictionary = _filtered_view[_cursor]
		if entry["id"] != &"":
			var def: ItemDefinition = ItemRegistry.get_item(entry["id"])
			if def != null:
				_show_item_detail(def)
			else:
				_clear_detail(String(entry["id"]))
		else:
			_clear_detail("(empty)")
	else:
		_clear_detail("(empty)")
```

Replace with:
```gdscript
	# Update detail text and tooltip.
	if _cursor >= 0 and _cursor < _filtered_view.size():
		var entry: Dictionary = _filtered_view[_cursor]
		if entry["id"] != &"":
			var def: ItemDefinition = ItemRegistry.get_item(entry["id"])
			if def != null:
				_show_item_detail(def)
				if _cursor < _inv_slots.size():
					_show_tooltip(def.display_name, _inv_slots[_cursor])
			else:
				_clear_detail(String(entry["id"]))
				_hide_tooltip()
		else:
			_clear_detail("(empty)")
			_hide_tooltip()
	else:
		_clear_detail("(empty)")
		_hide_tooltip()
```

Also add `_hide_tooltip()` at the start of the `Tab.CHARACTER` branch in `_refresh_cursor()`:
```gdscript
	if _current_tab == Tab.CHARACTER:
		_cursor_panel.visible = false
		_clear_detail("")
		_hide_tooltip()
		return
```

- [ ] **Step 6: Run all unit tests**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/inventory_screen.gd
git commit -m "feat: floating tooltip for inventory item slots"
```

---

## Task 6: Upgrade item detail panel (name + slot/power meta + description)

**Files:**
- Modify: `scripts/ui/inventory_screen.gd`

Currently `_build_grid_page()` builds a `detail_box` with `_detail_name_label` and `_detail_desc_label`. We add a third label for slot+power metadata.

- [ ] **Step 1: Add `_detail_meta_label` field**

Add alongside `_detail_name_label`:
```gdscript
var _detail_meta_label: Label = null
```

- [ ] **Step 2: Update `_build_grid_page()` to include the meta label**

Find the `detail_box` block in `_build_grid_page()`:
```gdscript
	# Detail panel below grid: name (rarity colored) + generated description.
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 2)
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.custom_minimum_size = Vector2(0, 48)

	_detail_name_label = Label.new()
	_detail_name_label.theme_type_variation = &"DimLabel"
	_detail_name_label.text = ""
	detail_box.add_child(_detail_name_label)

	_detail_desc_label = Label.new()
	_detail_desc_label.theme_type_variation = &"HintLabel"
	_detail_desc_label.text = "(empty)"
	_detail_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_detail_desc_label)

	# Keep _detail_label pointing at desc for legacy compatibility.
	_detail_label = _detail_desc_label
	page.add_child(detail_box)
```

Replace with:
```gdscript
	# Detail panel below grid: name + slot/power meta + description.
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 2)
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.custom_minimum_size = Vector2(0, 60)

	_detail_name_label = Label.new()
	_detail_name_label.theme_type_variation = &"DimLabel"
	_detail_name_label.text = ""
	detail_box.add_child(_detail_name_label)

	_detail_meta_label = Label.new()
	_detail_meta_label.add_theme_font_size_override("font_size", 11)
	_detail_meta_label.add_theme_color_override("font_color", UITheme.COL_LABEL_DIM)
	_detail_meta_label.text = ""
	_detail_meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_detail_meta_label)

	_detail_desc_label = Label.new()
	_detail_desc_label.theme_type_variation = &"HintLabel"
	_detail_desc_label.text = "(select an item)"
	_detail_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_detail_desc_label)

	# Keep _detail_label pointing at desc for legacy compatibility.
	_detail_label = _detail_desc_label
	page.add_child(detail_box)
```

- [ ] **Step 3: Update `_show_item_detail()` to populate the meta label**

Current:
```gdscript
func _show_item_detail(def: ItemDefinition, prefix: String = "") -> void:
	var rarity_color: Color = ItemDefinition.RARITY_COLORS.get(def.rarity, Color.WHITE)
	var rarity_name: String = ItemDefinition.Rarity.keys()[def.rarity].capitalize()
	var name_text: String = def.display_name
	if prefix != "":
		name_text = "%s — %s" % [prefix, name_text]
	if def.rarity != ItemDefinition.Rarity.COMMON:
		name_text += " [%s]" % rarity_name
	_detail_name_label.text = name_text
	_detail_name_label.add_theme_color_override("font_color", rarity_color)
	_detail_desc_label.text = def.generate_description()
```

Replace with:
```gdscript
func _show_item_detail(def: ItemDefinition, prefix: String = "") -> void:
	var rarity_color: Color = ItemDefinition.RARITY_COLORS.get(def.rarity, Color.WHITE)
	var rarity_name: String = ItemDefinition.Rarity.keys()[def.rarity].capitalize()
	var name_text: String = def.display_name
	if prefix != "":
		name_text = "%s — %s" % [prefix, name_text]
	if def.rarity != ItemDefinition.Rarity.COMMON:
		name_text += " [%s]" % rarity_name
	_detail_name_label.text = name_text
	_detail_name_label.add_theme_color_override("font_color", rarity_color)

	# Meta line: slot + power.
	if _detail_meta_label != null:
		var meta_parts: Array[String] = []
		var slot_name: String = slot_label(int(def.slot))
		if slot_name != "?":
			meta_parts.append(slot_name)
		if def.power > 0:
			meta_parts.append("Power: %d" % def.power)
		if def.slot == ItemDefinition.Slot.NONE:
			meta_parts.append("Stack: %d" % def.stack_size)
		_detail_meta_label.text = "  ·  ".join(meta_parts)

	_detail_desc_label.text = def.generate_description()
```

- [ ] **Step 4: Update `_clear_detail()` to also clear meta label**

Current:
```gdscript
func _clear_detail(text: String = "(empty)") -> void:
	_detail_name_label.text = ""
	_detail_name_label.add_theme_color_override("font_color", UITheme.COL_LABEL)
	_detail_desc_label.text = text
```

Replace with:
```gdscript
func _clear_detail(text: String = "(select an item)") -> void:
	_detail_name_label.text = ""
	_detail_name_label.add_theme_color_override("font_color", UITheme.COL_LABEL)
	if _detail_meta_label != null:
		_detail_meta_label.text = ""
	_detail_desc_label.text = text
```

- [ ] **Step 5: Run all unit tests**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/inventory_screen.gd
git commit -m "feat: upgrade item detail panel with slot and power metadata"
```

---

## Task 7: Character tab — add stats section + inline level-up

**Files:**
- Modify: `scripts/ui/inventory_screen.gd`
- Delete: `scripts/ui/level_up_panel.gd`

The Character tab currently has two sections: left preview panel + right appearance rows. We prepend a stats section above both.

- [ ] **Step 1: Add stat UI fields**

Add near the other UI ref fields:
```gdscript
var _char_stats_container: VBoxContainer = null
var _char_xp_bar: XpBar = null
var _char_stat_value_labels: Dictionary = {}   # StringName stat -> Label
var _char_stat_plus_buttons: Dictionary = {}   # StringName stat -> Button
var _char_pending_label: Label = null
var _char_passives_label: Label = null
```

- [ ] **Step 2: Update `_build_character_page()` to prepend stats section**

The current `_build_character_page()` builds a `VBoxContainer` named `page` that contains a `HBoxContainer` named `content`. Prepend a stats section to `page` before `content`.

Find the start of `_build_character_page()`:
```gdscript
func _build_character_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	page.add_child(content)
```

Replace with:
```gdscript
func _build_character_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# --- Stats section ---
	_char_stats_container = _build_char_stats_section()
	page.add_child(_char_stats_container)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	page.add_child(sep)

	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	page.add_child(content)
```

- [ ] **Step 3: Add `_build_char_stats_section()` method**

Add this new method to `inventory_screen.gd`:

```gdscript
const _STAT_ORDER: Array[StringName] = [
	&"strength", &"dexterity", &"defense", &"charisma", &"wisdom", &"speed"
]

func _build_char_stats_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Level + XP row.
	var lv_row := HBoxContainer.new()
	lv_row.add_theme_constant_override("separation", 8)
	section.add_child(lv_row)

	var lv_label := Label.new()
	lv_label.text = "Level —"
	lv_label.add_theme_font_size_override("font_size", 13)
	lv_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	lv_label.custom_minimum_size.x = 60
	lv_row.add_child(lv_label)
	# Store ref so we can update it.
	_char_stats_container = section  # Assigned after return; temp ref ok.
	# Actually store the level label separately.
	var lv_val := Label.new()
	lv_val.add_theme_font_size_override("font_size", 13)
	lv_val.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	lv_row.add_child(lv_val)
	_char_stat_value_labels[&"_level"] = lv_val

	_char_xp_bar = XpBar.new()
	_char_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv_row.add_child(_char_xp_bar)

	# Pending points label (hidden when 0).
	_char_pending_label = Label.new()
	_char_pending_label.add_theme_font_size_override("font_size", 12)
	_char_pending_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_char_pending_label.visible = false
	section.add_child(_char_pending_label)

	# Stat rows.
	for stat: StringName in _STAT_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		section.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = String(stat).capitalize()
		name_lbl.custom_minimum_size.x = 90
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", UITheme.COL_LABEL)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.custom_minimum_size.x = 28
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		row.add_child(val_lbl)
		_char_stat_value_labels[stat] = val_lbl

		var plus_btn := Button.new()
		plus_btn.text = "[+]"
		plus_btn.flat = true
		plus_btn.custom_minimum_size = Vector2(32, 20)
		plus_btn.add_theme_font_size_override("font_size", 11)
		plus_btn.visible = false
		plus_btn.pressed.connect(_on_stat_plus_pressed.bind(stat))
		row.add_child(plus_btn)
		_char_stat_plus_buttons[stat] = plus_btn

	# Passives row.
	_char_passives_label = Label.new()
	_char_passives_label.add_theme_font_size_override("font_size", 11)
	_char_passives_label.add_theme_color_override("font_color", UITheme.COL_LABEL_DIM)
	_char_passives_label.text = ""
	section.add_child(_char_passives_label)

	return section
```

- [ ] **Step 4: Add `_refresh_char_stats()` and `_on_stat_plus_pressed()`**

```gdscript
func _refresh_char_stats() -> void:
	if _player == null or _char_stat_value_labels.is_empty():
		return

	# Level label.
	var lv_lbl: Label = _char_stat_value_labels.get(&"_level")
	if lv_lbl != null:
		lv_lbl.text = str(_player.level)

	# XP bar.
	if _char_xp_bar != null:
		_char_xp_bar.update(
			_player.xp,
			_player.level,
			LevelingConfig.xp_to_next(_player.level),
			_player._pending_stat_points > 0
		)

	# Stat rows.
	var has_points: bool = _player._pending_stat_points > 0
	for stat: StringName in _STAT_ORDER:
		var val_lbl: Label = _char_stat_value_labels.get(stat)
		if val_lbl != null:
			val_lbl.text = str(_player.get_stat(stat))
		var btn: Button = _char_stat_plus_buttons.get(stat)
		if btn != null:
			btn.visible = has_points

	# Pending points header.
	if _char_pending_label != null:
		if has_points:
			_char_pending_label.text = "[%d stat point%s to spend — press [+]]" % [
				_player._pending_stat_points,
				"s" if _player._pending_stat_points > 1 else ""
			]
			_char_pending_label.visible = true
		else:
			_char_pending_label.visible = false

	# Passives.
	if _char_passives_label != null:
		if _player.unlocked_passives.is_empty():
			_char_passives_label.text = ""
		else:
			var names: Array[String] = []
			for p: StringName in _player.unlocked_passives:
				names.append(String(p).capitalize().replace("_", " "))
			_char_passives_label.text = "Passives: %s" % ", ".join(names)


func _on_stat_plus_pressed(stat: StringName) -> void:
	if _player == null:
		return
	_player.spend_stat_point(stat)
	_refresh_char_stats()
```

- [ ] **Step 5: Call `_refresh_char_stats()` from `_refresh()`**

In `_refresh()`, add at the end before the final `_refresh_cursor()` call:
```gdscript
	if _current_tab == Tab.CHARACTER:
		_refresh_char_stats()
```

- [ ] **Step 6: Delete `level_up_panel.gd`**

```bash
rm /home/mpatterson/repos/game4/scripts/ui/level_up_panel.gd
```

Remove the import/reference from `inventory_screen.gd` — the field `_level_up_panel` was already removed in Task 4. Double-check no remaining references:
```bash
grep -r "LevelUpPanel\|level_up_panel" /home/mpatterson/repos/game4/scripts/ /home/mpatterson/repos/game4/tests/
```

If any remain, remove them.

- [ ] **Step 7: Run all unit tests**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add scripts/ui/inventory_screen.gd
git rm scripts/ui/level_up_panel.gd
git commit -m "feat: Character tab stats section with inline level-up, remove LevelUpPanel"
```

---

## Task 8: Fix tests — update references to removed Tab.EQUIPMENT and LevelUpPanel

**Files:**
- Modify: `tests/unit/test_character_builder_ui.gd`

- [ ] **Step 1: Find all broken test references**

```bash
cd /home/mpatterson/repos/game4 && grep -n "EQUIPMENT\|LevelUpPanel\|level_up_panel" tests/unit/test_character_builder_ui.gd
```

- [ ] **Step 2: Update or remove Equipment references**

Any test asserting `Tab.EQUIPMENT` exists should be removed or changed to assert it does NOT exist (since we removed it). Any test asserting `Tab.ALL == 0` should be verified — after the enum change, `Tab.ALL` is now 0, `Tab.WEAPONS` is 1, etc.

Expected changes in `test_character_builder_ui.gd`:
- Remove any test that does `Tab.EQUIPMENT` — the tab no longer exists.
- `test_character_tab_exists_in_enum()` — still valid, CHARACTER is still in the enum.
- `test_character_tab_label()` — still valid, label is still "Character".
- Add a test confirming the tab list no longer contains "Equipment":

```gdscript
func test_equipment_tab_removed() -> void:
	assert_false(InventoryScreen.Tab.has("EQUIPMENT"),
		"Equipment tab should be removed from Tab enum")

func test_all_tab_is_index_zero() -> void:
	assert_eq(int(InventoryScreen.Tab.ALL), 0,
		"ALL tab should be index 0 after Equipment removal")
```

- [ ] **Step 3: Run all unit tests — must be clean**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add tests/unit/test_character_builder_ui.gd
git commit -m "test: update inventory screen tests for Equipment tab removal"
```

---

## Task 9: Code Review

**Files:** All files touched in Tasks 1–8.

- [ ] **Step 1: Read through each changed file looking for bugs**

Check for:
- Off-by-one errors in tab index handling (Tab enum shifted — any hardcoded int comparisons?)
- Tooltip position wrong when inventory opens for the first time (size may be zero before layout)
- Tween for `_level_flash_label` not killed before creating a new one (rapid leveling → multiple tweens)
- `_char_stat_plus_buttons` and `_char_stat_value_labels` not cleared/rebuilt if `set_player()` is called again
- `_refresh_char_stats()` called before player is set (null check in place?)

- [ ] **Step 2: Read through looking for enhancements**

Check for:
- Can `flash_level_up` reuse `flash_hit` with a parameter? If the implementations are near-identical except for color, consolidate.
- Is `_refresh_char_stats()` doing redundant work that overlaps with `_refresh()`? Remove duplication.
- `_show_tooltip()` calls `reset_size()` which may not work before the label is in the tree — verify or use `get_minimum_size()` instead.

- [ ] **Step 3: Verify typed GDScript throughout**

```bash
grep -n "var [a-z_]* =" scripts/ui/inventory_screen.gd scripts/ui/player_hud.gd scripts/entities/action_particles.gd | grep -v ": " | head -20
```

Any untyped `var x =` (without `: Type`) in new code should be typed.

- [ ] **Step 4: Fix any issues found**

Make targeted fixes. Commit per logical group of fixes.

```bash
git add <files>
git commit -m "fix: code review corrections for inventory UI redesign"
```

- [ ] **Step 5: Run full test suite (unit + integration)**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

Expected: all unit tests pass; the 5 pre-existing integration failures (unrelated `p1`/`origin_cell` issues) are acceptable.

- [ ] **Step 6: Check for parse errors**

```bash
timeout 15 godot --headless --editor --quit 2>&1 | grep -i "parse\|error" | head -10
```

Expected: no parse errors.

- [ ] **Step 7: Final commit if any cleanup was done**

```bash
git add -p  # stage only changed files explicitly
git commit -m "refactor: post-review cleanup for inventory UI redesign"
```
