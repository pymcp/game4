# Menu Keyboard Consistency + Action Name Constants — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every menu (MainMenu, PauseMenu, CaravanMenu + sub-panels, InventoryScreen) is navigable without a mouse using per-player action keys. All action name strings are centralized in a new `PlayerActions` class — nothing is hardcoded as `"p1_up"` or `"p%d_back"` anywhere except `PlayerActions` itself and `project.godot`.

**Architecture:** `PlayerActions` (`RefCounted`) is the single source of truth for verb constants and action-name building. All UI and entity code calls `PlayerActions.action(pid, VERB)`. Global menus (MainMenu, PauseMenu) use `PlayerActions.either_just_pressed(event, VERB)` so either player's controls work. CaravanMenu delegates nav to sub-panels via a `navigate(verb)` method.

**Tech Stack:** Godot 4.3, GDScript, GUT 9.3. No new dependencies.

---

## File Map

| File | Status | Change |
|---|---|---|
| `scripts/data/player_actions.gd` | **Create** | Verb constants + action builder helpers |
| `scripts/autoload/input_context.gd` | **Modify** | Replace `"p%d_"` strings; add `back` to MENU context; add pre-pause context save/restore |
| `scripts/autoload/pause_manager.gd` | **Modify** | Set MENU context on pause, restore on unpause; also handle `p*_back` pause trigger |
| `scripts/entities/player_controller.gd` | **Modify** | Replace inline action strings; add `BACK` → pause from GAMEPLAY |
| `scripts/world/world_root.gd` | **Modify** | Replace hardcoded `&"p1_interact"` / `&"p2_interact"` |
| `scripts/ui/inventory_screen.gd` | **Modify** | Replace `"p%d_"` inline strings |
| `scripts/ui/caravan_menu.gd` | **Modify** | Full keyboard nav (cursor, INVENTORY context, panel focus delegation) |
| `scripts/ui/crafter_panel.gd` | **Modify** | Add `navigate(verb: StringName)` method |
| `scripts/ui/story_teller_panel.gd` | **Modify** | Add `navigate(verb: StringName)` method |
| `scripts/ui/pause_menu.gd` | **Modify** | Full keyboard nav (cursor, either-player) |
| `scripts/ui/main_menu.gd` | **Modify** | Full keyboard nav (cursor, either-player) |
| `scripts/ui/controls_hud.gd` | **Modify** | Replace `"p%d_"` inline strings |
| `scripts/ui/floor_confirm_menu.gd` | **Modify** | Replace `"p%d_"` inline strings |
| `scripts/ui/dialogue_box.gd` | **Modify** | Replace `"p%d_"` inline strings |
| `scripts/ui/shop_screen.gd` | **Modify** | Replace hardcoded `"p1_inventory"` / `"ui_cancel"` |
| `scripts/main/bootstrap_smoke.gd` | **Modify** | Replace hardcoded action strings |
| `tests/unit/test_player_actions.gd` | **Create** | Unit tests for action builder |

---

## Task 1 — PlayerActions class

**Files:**
- Create: `scripts/data/player_actions.gd`
- Create: `tests/unit/test_player_actions.gd`

- [ ] **Step 1: Write failing test**

```gdscript
# tests/unit/test_player_actions.gd
extends GutTest

func test_verb_constants_exist() -> void:
    assert_eq(PlayerActions.UP, &"up")
    assert_eq(PlayerActions.DOWN, &"down")
    assert_eq(PlayerActions.LEFT, &"left")
    assert_eq(PlayerActions.RIGHT, &"right")
    assert_eq(PlayerActions.INTERACT, &"interact")
    assert_eq(PlayerActions.BACK, &"back")
    assert_eq(PlayerActions.ATTACK, &"attack")
    assert_eq(PlayerActions.INVENTORY, &"inventory")
    assert_eq(PlayerActions.TAB_PREV, &"tab_prev")
    assert_eq(PlayerActions.TAB_NEXT, &"tab_next")
    assert_eq(PlayerActions.AUTO_MINE, &"auto_mine")
    assert_eq(PlayerActions.AUTO_ATTACK, &"auto_attack")
    assert_eq(PlayerActions.WORLDMAP, &"worldmap")

func test_action_builds_correct_name_p1() -> void:
    assert_eq(PlayerActions.action(0, PlayerActions.UP), &"p1_up")
    assert_eq(PlayerActions.action(0, PlayerActions.BACK), &"p1_back")
    assert_eq(PlayerActions.action(0, PlayerActions.INVENTORY), &"p1_inventory")

func test_action_builds_correct_name_p2() -> void:
    assert_eq(PlayerActions.action(1, PlayerActions.UP), &"p2_up")
    assert_eq(PlayerActions.action(1, PlayerActions.INTERACT), &"p2_interact")
    assert_eq(PlayerActions.action(1, PlayerActions.TAB_NEXT), &"p2_tab_next")

func test_prefix_matches_action() -> void:
    # prefix(0) == "p1_", prefix(1) == "p2_"
    assert_eq(PlayerActions.prefix(0), "p1_")
    assert_eq(PlayerActions.prefix(1), "p2_")

func test_either_just_pressed_requires_event() -> void:
    # Smoke: passing a null-equivalent InputEvent doesn't crash.
    var ev := InputEventKey.new()
    ev.keycode = KEY_A
    ev.pressed = false
    assert_false(PlayerActions.either_just_pressed(ev, PlayerActions.UP),
        "Non-pressed event should return false")
```

- [ ] **Step 2: Run test — expect FAIL (PlayerActions not found)**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_player_actions.gd -gexit 2>&1 | tail -10
```

- [ ] **Step 3: Create `scripts/data/player_actions.gd`**

```gdscript
## PlayerActions
##
## Central source of truth for player input action names.
## All code that needs an action name should call PlayerActions.action(pid, VERB)
## instead of building "p1_up" or "p%d_back" inline.
##
## Global menus (MainMenu, PauseMenu) use either_just_pressed / either_pressed
## so either player can operate them.
class_name PlayerActions
extends RefCounted

# ── Verb constants ──────────────────────────────────────────────────
const UP:          StringName = &"up"
const DOWN:        StringName = &"down"
const LEFT:        StringName = &"left"
const RIGHT:       StringName = &"right"
const INTERACT:    StringName = &"interact"
const BACK:        StringName = &"back"
const ATTACK:      StringName = &"attack"
const INVENTORY:   StringName = &"inventory"
const TAB_PREV:    StringName = &"tab_prev"
const TAB_NEXT:    StringName = &"tab_next"
const AUTO_MINE:   StringName = &"auto_mine"
const AUTO_ATTACK: StringName = &"auto_attack"
const WORLDMAP:    StringName = &"worldmap"

# ── Action-name builders ────────────────────────────────────────────

## Returns the action prefix for [param player_id] (e.g. "p1_" or "p2_").
static func prefix(player_id: int) -> String:
    return "p%d_" % (player_id + 1)

## Builds a fully-qualified action name for [param player_id] and [param verb].
## Example: PlayerActions.action(0, PlayerActions.UP) → &"p1_up"
static func action(player_id: int, verb: StringName) -> StringName:
    return StringName(prefix(player_id) + String(verb))

# ── Event helpers ───────────────────────────────────────────────────

## True if [param event] is a just-pressed event for the given [param player_id] + [param verb].
static func just_pressed(event: InputEvent, player_id: int, verb: StringName) -> bool:
    return event.is_action_pressed(action(player_id, verb), true)

## True if the action is currently held for [param player_id] + [param verb].
static func pressed(event: InputEvent, player_id: int, verb: StringName) -> bool:
    return event.is_action_pressed(action(player_id, verb))

## True if either player just pressed [param verb].
## Used by global menus (MainMenu, PauseMenu) that accept input from both players.
static func either_just_pressed(event: InputEvent, verb: StringName) -> bool:
    return just_pressed(event, 0, verb) or just_pressed(event, 1, verb)

## True if either player is holding [param verb].
static func either_pressed(event: InputEvent, verb: StringName) -> bool:
    return pressed(event, 0, verb) or pressed(event, 1, verb)
```

- [ ] **Step 4: Refresh class cache**

```bash
cd /home/mpatterson/repos/game4 && timeout 15 godot --headless --editor --quit 2>/dev/null; true
```

- [ ] **Step 5: Run test — expect all 5 PASS**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_player_actions.gd -gexit 2>&1 | tail -10
```

- [ ] **Step 6: Commit**

```bash
git add scripts/data/player_actions.gd tests/unit/test_player_actions.gd
git commit -m "data: PlayerActions — centralized action name constants and builders"
```

---

## Task 2 — Replace all inline action strings with PlayerActions

This is a mechanical sweep. Every file that builds `"p%d_" % n`, `"p1_back"`, `"p2_interact"` etc. is updated.

**Files (all modify):**
- `scripts/autoload/input_context.gd`
- `scripts/entities/player_controller.gd`
- `scripts/world/world_root.gd`
- `scripts/ui/inventory_screen.gd`
- `scripts/ui/caravan_menu.gd`
- `scripts/ui/controls_hud.gd`
- `scripts/ui/floor_confirm_menu.gd`
- `scripts/ui/dialogue_box.gd`
- `scripts/ui/shop_screen.gd`
- `scripts/main/bootstrap_smoke.gd`

**IMPORTANT:** Read each file in full before editing. The changes are mechanical but must be precise.

### Replacements by file

**`scripts/autoload/input_context.gd`**

In `get_active_actions()`, replace the `var prefix := "p%d_" % (player_id + 1)` approach with `PlayerActions.action()` calls. The MENU context should also add `back`. Change:
```gdscript
var prefix := "p%d_" % (player_id + 1)
match ctx:
    Context.GAMEPLAY:
        return [
            StringName(prefix + "up"),
            StringName(prefix + "down"),
            ...
        ]
```
To:
```gdscript
match ctx:
    Context.GAMEPLAY:
        return [
            PlayerActions.action(player_id, PlayerActions.UP),
            PlayerActions.action(player_id, PlayerActions.DOWN),
            PlayerActions.action(player_id, PlayerActions.LEFT),
            PlayerActions.action(player_id, PlayerActions.RIGHT),
            PlayerActions.action(player_id, PlayerActions.INTERACT),
            PlayerActions.action(player_id, PlayerActions.ATTACK),
            PlayerActions.action(player_id, PlayerActions.BACK),
            PlayerActions.action(player_id, PlayerActions.INVENTORY),
            PlayerActions.action(player_id, PlayerActions.AUTO_MINE),
            PlayerActions.action(player_id, PlayerActions.AUTO_ATTACK),
        ]
    Context.INVENTORY:
        return [
            PlayerActions.action(player_id, PlayerActions.UP),
            PlayerActions.action(player_id, PlayerActions.DOWN),
            PlayerActions.action(player_id, PlayerActions.LEFT),
            PlayerActions.action(player_id, PlayerActions.RIGHT),
            PlayerActions.action(player_id, PlayerActions.INTERACT),
            PlayerActions.action(player_id, PlayerActions.BACK),
            PlayerActions.action(player_id, PlayerActions.TAB_PREV),
            PlayerActions.action(player_id, PlayerActions.TAB_NEXT),
            PlayerActions.action(player_id, PlayerActions.INVENTORY),
        ]
    Context.MENU:
        return [
            PlayerActions.action(player_id, PlayerActions.UP),
            PlayerActions.action(player_id, PlayerActions.DOWN),
            PlayerActions.action(player_id, PlayerActions.INTERACT),
            PlayerActions.action(player_id, PlayerActions.BACK),
        ]
    Context.DISABLED:
        return []
return []
```

Also replace in `_action_verb()`:
```gdscript
if s.begins_with("p1_") or s.begins_with("p2_"):
    s = s.substr(3)
```
With:
```gdscript
if s.begins_with(PlayerActions.prefix(0)) or s.begins_with(PlayerActions.prefix(1)):
    s = s.substr(3)
```

**`scripts/entities/player_controller.gd`**

Everywhere `var prefix: String = "p%d_" % (player_id + 1)` appears followed by `StringName(prefix + "interact")` etc., replace the pair with `PlayerActions.action(player_id, PlayerActions.INTERACT)` etc.

There are two occurrences of the `prefix` declaration:
1. In the `in_conversation` block (line ~302): replace the two action checks.
2. In the main gameplay block (line ~319): replace all 4 action checks + movement `get_action_strength` calls.

For movement, replace:
```gdscript
Input.get_action_strength(StringName(prefix + "right"))
    - Input.get_action_strength(StringName(prefix + "left")),
Input.get_action_strength(StringName(prefix + "down"))
    - Input.get_action_strength(StringName(prefix + "up")),
```
With:
```gdscript
Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.RIGHT))
    - Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.LEFT)),
Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.DOWN))
    - Input.get_action_strength(PlayerActions.action(player_id, PlayerActions.UP)),
```

In `_unhandled_input()`, replace:
```gdscript
var map_action: StringName = &"p1_worldmap" if player_id == 0 else &"p2_worldmap"
```
With:
```gdscript
var map_action: StringName = PlayerActions.action(player_id, PlayerActions.WORLDMAP)
```

**`scripts/world/world_root.gd` (line 1018)**

Replace:
```gdscript
var action: StringName = &"p1_interact" if pid == 0 else &"p2_interact"
```
With:
```gdscript
var action: StringName = PlayerActions.action(pid, PlayerActions.INTERACT)
```

**`scripts/ui/inventory_screen.gd`**

Replace both occurrences of:
```gdscript
var prefix: String = "p%d_" % (_player.player_id + 1)
```
... followed by `StringName(prefix + "up")` etc., with `PlayerActions.action(_player.player_id, PlayerActions.UP)` etc. Read the file to find all action names used (UP, DOWN, LEFT, RIGHT, INTERACT, BACK, TAB_PREV, TAB_NEXT, INVENTORY).

Also check for `_is_my_event(prefix, event)` helper — if it builds action names internally, update it too.

**`scripts/ui/caravan_menu.gd`**

Replace:
```gdscript
var prefix: String = "p%d_" % (_player_id + 1)
if Input.is_action_just_pressed(StringName(prefix + "back")):
```
With:
```gdscript
if Input.is_action_just_pressed(PlayerActions.action(_player_id, PlayerActions.BACK)):
```

**`scripts/ui/controls_hud.gd`**

Read the file. Find the `var prefix := "p%d_" % (player_id + 1)` and replace the action name constructions.

**`scripts/ui/floor_confirm_menu.gd`**

Read the file. Find `var prefix: String = "p%d_" % (_pid + 1)` and replace.

**`scripts/ui/dialogue_box.gd`**

Read the file. Find `var prefix: String = "p%d_" % (player_id + 1)` and replace.

**`scripts/ui/shop_screen.gd`**

Replace:
```gdscript
if event.is_action_pressed("ui_cancel") or event.is_action_pressed("p1_inventory"):
```
With (assuming shop_screen has a `_player_id` or similar — read the file first):
```gdscript
if event.is_action_pressed("ui_cancel") \
        or event.is_action_pressed(PlayerActions.action(_player_id, PlayerActions.INVENTORY)):
```
If `_player_id` is not available, use `PlayerActions.either_pressed(event, PlayerActions.INVENTORY)` instead.

**`scripts/main/bootstrap_smoke.gd`**

Replace the hardcoded `&"p1_attack"`, `&"p2_attack"`, `&"p2_up"` etc. with `PlayerActions.action(0, PlayerActions.ATTACK)`, `PlayerActions.action(1, PlayerActions.ATTACK)` etc. The loop over p2 actions can be built from `PlayerActions` constants.

- [ ] **Step 1: Do all replacements across all 10 files as described above (read each file before editing)**

- [ ] **Step 2: Run full unit tests — expect no new failures**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
```
Expected: ≥690 passing, 0 failing.

- [ ] **Step 3: Verify no hardcoded action strings remain**

```bash
grep -rn '"p[12]_\|"p%d_\|p%d_\b' scripts/ --include="*.gd" | grep -v "player_actions.gd"
```
Expected output: **empty** (zero matches outside player_actions.gd).

- [ ] **Step 4: Commit**

```bash
git add scripts/autoload/input_context.gd scripts/entities/player_controller.gd \
        scripts/world/world_root.gd scripts/ui/inventory_screen.gd \
        scripts/ui/caravan_menu.gd scripts/ui/controls_hud.gd \
        scripts/ui/floor_confirm_menu.gd scripts/ui/dialogue_box.gd \
        scripts/ui/shop_screen.gd scripts/main/bootstrap_smoke.gd
git commit -m "refactor: replace all inline action strings with PlayerActions"
```

---

## Task 3 — p\*\_back triggers pause from GAMEPLAY + PauseManager sets MENU context

**Files:**
- Modify: `scripts/autoload/pause_manager.gd`
- Modify: `scripts/entities/player_controller.gd`

**Design:** 
- `PauseManager` tracks the pre-pause contexts in `_pre_pause_contexts: Array[Context]` so it can restore them on unpause.
- When pausing, it sets both players to MENU context.
- When unpausing, it restores each player's context (GAMEPLAY or DISABLED — never restores INVENTORY/MENU since the inventory should close when pausing).
- `PlayerController` checks `BACK` in GAMEPLAY context before the existing context filter, and calls `PauseManager.toggle_pause()`.

- [ ] **Step 1: Modify `scripts/autoload/pause_manager.gd`**

Read the file. Add field after `_player_enabled`:
```gdscript
var _pre_pause_contexts: Array[int] = [0, 0]  # stores Context enum int values
```

In `set_paused(value: bool)`, after `_is_paused = value` and before `get_tree().paused = value`, add:
```gdscript
if value:
    # Save current contexts and switch all players to MENU.
    for pid in InputContext.PLAYER_COUNT:
        _pre_pause_contexts[pid] = InputContext.get_context(pid)
        InputContext.set_context(pid, InputContext.Context.MENU)
else:
    # Restore pre-pause contexts (but never restore INVENTORY/MENU — go to GAMEPLAY).
    for pid in InputContext.PLAYER_COUNT:
        var saved: int = _pre_pause_contexts[pid]
        if saved == InputContext.Context.GAMEPLAY or saved == InputContext.Context.DISABLED:
            InputContext.set_context(pid, saved as InputContext.Context)
        else:
            InputContext.set_context(pid, InputContext.Context.GAMEPLAY)
```

**Note:** `set_player_enabled()` already calls `InputContext.set_context()` on its own. The restore on unpause only runs if `set_paused(false)` reaches `get_tree().paused = false` (it guards against unpausing with all disabled). Keep ordering careful — set_paused must restore context before emitting `pause_state_changed`.

- [ ] **Step 2: Add `BACK` → pause in `player_controller.gd`**

Read `_physics_process()`. Find the block:
```gdscript
if InputContext.get_context(player_id) != InputContext.Context.GAMEPLAY:
    _bob_t = 0.0
    _sprite_root.position = Vector2.ZERO
    return
```

Insert immediately BEFORE that block:
```gdscript
# BACK from GAMEPLAY context triggers the pause menu.
if InputContext.get_context(player_id) == InputContext.Context.GAMEPLAY \
        and Input.is_action_just_pressed(PlayerActions.action(player_id, PlayerActions.BACK)):
    PauseManager.toggle_pause()
    return
```

- [ ] **Step 3: Run full unit tests — expect no new failures**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] **Step 4: Commit**

```bash
git add scripts/autoload/pause_manager.gd scripts/entities/player_controller.gd
git commit -m "input: p*_back triggers pause; PauseManager saves/restores context on pause"
```

---

## Task 4 — PauseMenu keyboard navigation

**Files:**
- Modify: `scripts/ui/pause_menu.gd`

**Design:** Cursor-indexed into `_nav_buttons` array. Either player navigates. `UP`/`DOWN` move cursor, `INTERACT` activates button, `BACK` resumes.

- [ ] **Step 1: Read `scripts/ui/pause_menu.gd` in full (already done above)**

- [ ] **Step 2: Rewrite `pause_menu.gd`**

Replace the file content with:

```gdscript
## PauseMenu
##
## Full-window CanvasLayer shown when PauseManager.pause_state_changed fires.
## Keyboard-navigable by either player using their UP/DOWN/INTERACT/BACK keys.
## A cursor highlight panel tracks the selected button.
extends CanvasLayer
class_name PauseMenu

@onready var _panel: PanelContainer = $Center/Panel
@onready var _btn_resume:    Button = $Center/Panel/Margin/VBox/Resume
@onready var _btn_toggle_p1: Button = $Center/Panel/Margin/VBox/ToggleP1
@onready var _btn_toggle_p2: Button = $Center/Panel/Margin/VBox/ToggleP2
@onready var _btn_save:      Button = $Center/Panel/Margin/VBox/Save
@onready var _btn_exit:      Button = $Center/Panel/Margin/VBox/Exit

## Ordered list of navigable buttons (skip disabled ones in _clamp_cursor).
var _nav_buttons: Array[Button] = []
var _cursor: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    PauseManager.pause_state_changed.connect(_on_pause_state_changed)
    PauseManager.player_enabled_changed.connect(_on_player_enabled_changed)
    _btn_resume.pressed.connect(_on_resume)
    _btn_toggle_p1.pressed.connect(func() -> void: _toggle_player(0))
    _btn_toggle_p2.pressed.connect(func() -> void: _toggle_player(1))
    _btn_save.pressed.connect(_on_save)
    _btn_exit.pressed.connect(_on_exit)
    # Disable all Godot built-in focus traversal — we manage cursor ourselves.
    for btn: Button in [_btn_resume, _btn_toggle_p1, _btn_toggle_p2, _btn_save, _btn_exit]:
        btn.focus_mode = Control.FOCUS_NONE
    _nav_buttons = [_btn_resume, _btn_toggle_p1, _btn_toggle_p2, _btn_save, _btn_exit]
    _refresh_player_labels()


func _input(event: InputEvent) -> void:
    if not visible:
        return
    if PlayerActions.either_just_pressed(event, PlayerActions.UP):
        _cursor = wrapi(_cursor - 1, 0, _nav_buttons.size())
        _skip_disabled(-1)
        _refresh_cursor()
        get_viewport().set_input_as_handled()
    elif PlayerActions.either_just_pressed(event, PlayerActions.DOWN):
        _cursor = wrapi(_cursor + 1, 0, _nav_buttons.size())
        _skip_disabled(1)
        _refresh_cursor()
        get_viewport().set_input_as_handled()
    elif PlayerActions.either_just_pressed(event, PlayerActions.INTERACT):
        if _cursor < _nav_buttons.size() and not _nav_buttons[_cursor].disabled:
            _nav_buttons[_cursor].pressed.emit()
        get_viewport().set_input_as_handled()
    elif PlayerActions.either_just_pressed(event, PlayerActions.BACK):
        _on_resume()
        get_viewport().set_input_as_handled()


func _on_pause_state_changed(is_paused: bool) -> void:
    visible = is_paused
    if is_paused:
        _cursor = 0
        _refresh_cursor()


func _on_player_enabled_changed(_player_id: int, _is_enabled: bool) -> void:
    _refresh_player_labels()
    # Re-clamp cursor in case the button under cursor became disabled.
    _skip_disabled(1)
    _refresh_cursor()


func _refresh_player_labels() -> void:
    var p1_on := PauseManager.is_player_enabled(0)
    var p2_on := PauseManager.is_player_enabled(1)
    _btn_toggle_p1.text = "Disable Player 1" if p1_on else "Enable Player 1"
    _btn_toggle_p2.text = "Disable Player 2" if p2_on else "Enable Player 2"
    _btn_resume.disabled = not (p1_on or p2_on)


## Advance cursor in [param direction] (+1 or -1) until it lands on an enabled button.
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
            btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
        else:
            btn.remove_theme_color_override("font_color")


func _toggle_player(player_id: int) -> void:
    PauseManager.set_player_enabled(player_id, not PauseManager.is_player_enabled(player_id))


func _on_resume() -> void:
    PauseManager.set_paused(false)


func _on_save() -> void:
    push_warning("[PauseMenu] Save not yet implemented (Phase 8).")


func _on_exit() -> void:
    get_tree().quit()
```

- [ ] **Step 3: Run unit tests — expect no new failures**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/pause_menu.gd
git commit -m "ui: PauseMenu keyboard navigation via cursor (either player)"
```

---

## Task 5 — MainMenu keyboard navigation

**Files:**
- Modify: `scripts/ui/main_menu.gd`

**Design:** Same cursor pattern as PauseMenu. Five nav buttons (2P/P1/P2/Continue/Quit). Seed LineEdit excluded from cursor (still Tab-accessible). Either player controls navigate.

- [ ] **Step 1: Add cursor navigation to `main_menu.gd`**

Add after the existing field declarations:
```gdscript
var _nav_buttons: Array[Button] = []
var _cursor: int = 0
```

Add `_input(event: InputEvent)` method:
```gdscript
func _input(event: InputEvent) -> void:
    if not visible:
        return
    if PlayerActions.either_just_pressed(event, PlayerActions.UP):
        _cursor = wrapi(_cursor - 1, 0, _nav_buttons.size())
        _skip_disabled(-1)
        _refresh_cursor()
        get_viewport().set_input_as_handled()
    elif PlayerActions.either_just_pressed(event, PlayerActions.DOWN):
        _cursor = wrapi(_cursor + 1, 0, _nav_buttons.size())
        _skip_disabled(1)
        _refresh_cursor()
        get_viewport().set_input_as_handled()
    elif PlayerActions.either_just_pressed(event, PlayerActions.INTERACT):
        if _cursor < _nav_buttons.size() and not _nav_buttons[_cursor].disabled:
            _nav_buttons[_cursor].pressed.emit()
        get_viewport().set_input_as_handled()
```

Add helpers (after the existing `_refresh_continue_state()` method):
```gdscript
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
            btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
        else:
            btn.remove_theme_color_override("font_color")
```

In `_build()`, after all buttons are created and before `_btn_new_2p.grab_focus()`:
1. Disable Godot focus traversal on all buttons:
```gdscript
for btn: Button in [_btn_new_2p, _btn_new_p1, _btn_new_p2, _btn_continue, _btn_quit]:
    btn.focus_mode = Control.FOCUS_NONE
```
2. Populate `_nav_buttons`:
```gdscript
_nav_buttons = [_btn_new_2p, _btn_new_p1, _btn_new_p2, _btn_continue, _btn_quit]
```
3. Replace `_btn_new_2p.grab_focus()` with:
```gdscript
_cursor = 0
_refresh_cursor()
```

In `_refresh_continue_state()`, after setting `_btn_continue.disabled`, add:
```gdscript
if _btn_continue.disabled and _cursor == _nav_buttons.find(_btn_continue):
    _skip_disabled(1)
_refresh_cursor()
```

- [ ] **Step 2: Run unit tests — expect no new failures**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/main_menu.gd
git commit -m "ui: MainMenu keyboard navigation via cursor (either player)"
```

---

## Task 6 — CrafterPanel.navigate() + StoryTellerPanel.navigate()

**Files:**
- Modify: `scripts/ui/crafter_panel.gd`
- Modify: `scripts/ui/story_teller_panel.gd`

These panels add a `navigate(verb: StringName) -> void` method that CaravanMenu calls when the right panel has focus. They do NOT add their own `_input()` handlers.

### CrafterPanel

- [ ] **Step 1: Add cursor fields and `navigate()` to `crafter_panel.gd`**

Read the file. Add after `_buttons: Array[Button]`:
```gdscript
var _cursor: int = 0
```

Add after `_on_pressed()`:
```gdscript
## Called by CaravanMenu when this panel has keyboard focus.
## [param verb] is a PlayerActions verb constant.
func navigate(verb: StringName) -> void:
    match verb:
        PlayerActions.UP:
            _cursor = wrapi(_cursor - 1, 0, _buttons.size())
            _refresh_cursor()
        PlayerActions.DOWN:
            _cursor = wrapi(_cursor + 1, 0, _buttons.size())
            _refresh_cursor()
        PlayerActions.INTERACT:
            if _cursor < _ordered_ids.size():
                _on_pressed(_ordered_ids[_cursor])

func _refresh_cursor() -> void:
    for i in _buttons.size():
        var btn: Button = _buttons[i]
        if i == _cursor:
            btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
        else:
            btn.remove_theme_color_override("font_color")
```

In `_build()`, after the first button is added, call `_refresh_cursor()` at the end of `_build()` so the initial cursor position is visible.

In `_buttons.clear()` at the start of `_build()`, also reset `_cursor = 0`.

### StoryTellerPanel

- [ ] **Step 2: Add `navigate()` to `story_teller_panel.gd`**

Read the file. Add after `_show_view()`:
```gdscript
## Called by CaravanMenu when this panel has keyboard focus.
## [param verb] is a PlayerActions verb constant.
func navigate(verb: StringName) -> void:
    match verb:
        PlayerActions.TAB_PREV:
            var v: int = wrapi(int(_current_view) - 1, 0, 3)
            _show_view(v as View)
        PlayerActions.TAB_NEXT:
            var v: int = wrapi(int(_current_view) + 1, 0, 3)
            _show_view(v as View)
        PlayerActions.UP:
            if _content != null and _content.get_parent() is ScrollContainer:
                var sc := _content.get_parent() as ScrollContainer
                sc.scroll_vertical = max(0, sc.scroll_vertical - 32)
        PlayerActions.DOWN:
            if _content != null and _content.get_parent() is ScrollContainer:
                var sc := _content.get_parent() as ScrollContainer
                sc.scroll_vertical += 32
```

- [ ] **Step 3: Run unit tests — expect no new failures**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/crafter_panel.gd scripts/ui/story_teller_panel.gd
git commit -m "ui: CrafterPanel and StoryTellerPanel add navigate(verb) for CaravanMenu delegation"
```

---

## Task 7 — CaravanMenu full keyboard navigation

**Files:**
- Modify: `scripts/ui/caravan_menu.gd`

**Design:**
- Switch to INVENTORY context (gives UP/DOWN/LEFT/RIGHT/INTERACT/BACK/TAB_PREV/TAB_NEXT).
- Two focus zones: LEFT (member list) and RIGHT (active panel). Enum `_Focus { LEFT, RIGHT }`.
- LEFT zone: UP/DOWN cycles member cursor; INTERACT selects and shifts focus to RIGHT.
- RIGHT zone: TAB_PREV/TAB_NEXT/UP/DOWN/INTERACT delegated to active right panel via `navigate(verb)`.
- RIGHT → LEFT: `BACK` or `LEFT` arrow returns focus to LEFT zone.
- LEFT, pressing BACK: closes the menu.
- `_refresh_member_cursor()` highlights the selected member button.

- [ ] **Step 1: Read `scripts/ui/caravan_menu.gd` in full (done above)**

- [ ] **Step 2: Rewrite `caravan_menu.gd`**

Replace the entire file with:

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
extends Control

enum _Focus { LEFT, RIGHT }

var _player: PlayerController = null
var _player_id: int = 0
var _caravan_data: CaravanData = null

var _root_panel: PanelContainer = null
var _member_buttons: Array[Button] = []
var _member_ids: Array[StringName] = []
var _right_panel: Control = null
var _current_crafter: CrafterPanel = null

var _member_cursor: int = 0
var _focus: _Focus = _Focus.LEFT


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 45
    visible = false


func setup(player: PlayerController, caravan_data: CaravanData) -> void:
    _player = player
    _player_id = player.player_id if player != null else 0
    _caravan_data = caravan_data
    _build_ui()


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


func _input(event: InputEvent) -> void:
    if not visible:
        return

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
            # Delegate navigation verbs to the active right-panel widget.
            var panel: Node = _get_active_right_panel()
            if panel != null and panel.has_method("navigate"):
                for verb in [PlayerActions.UP, PlayerActions.DOWN, PlayerActions.LEFT,
                             PlayerActions.RIGHT, PlayerActions.INTERACT,
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


func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.name = "Background"
    bg.color = Color(0.0, 0.0, 0.0, 0.6)
    bg.anchor_right = 1.0
    bg.anchor_bottom = 1.0
    add_child(bg)

    _root_panel = PanelContainer.new()
    _root_panel.name = "RootPanel"
    _root_panel.anchor_left = 0.1
    _root_panel.anchor_top = 0.1
    _root_panel.anchor_right = 0.9
    _root_panel.anchor_bottom = 0.9
    add_child(_root_panel)

    var hbox := HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 8)
    _root_panel.add_child(hbox)

    var left := VBoxContainer.new()
    left.name = "LeftPanel"
    left.custom_minimum_size = Vector2(140, 0)
    hbox.add_child(left)

    var title := Label.new()
    title.text = "Party"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    left.add_child(title)

    var members_container := VBoxContainer.new()
    members_container.name = "MembersContainer"
    members_container.add_theme_constant_override("separation", 4)
    left.add_child(members_container)
    left.add_child(HSeparator.new())

    var inv_label := Label.new()
    inv_label.name = "InvLabel"
    inv_label.text = "Caravan Inventory"
    inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    left.add_child(inv_label)

    var inv_list := Label.new()
    inv_list.name = "InvList"
    inv_list.autowrap_mode = TextServer.AUTOWRAP_WORD
    left.add_child(inv_list)

    _right_panel = Control.new()
    _right_panel.name = "RightPanel"
    _right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(_right_panel)

    var placeholder := Label.new()
    placeholder.name = "Placeholder"
    placeholder.text = "Select a party member."
    placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    placeholder.anchor_right = 1.0
    placeholder.anchor_bottom = 1.0
    _right_panel.add_child(placeholder)


func _refresh_members() -> void:
    if _caravan_data == null or _root_panel == null:
        return
    var hbox: Node = _root_panel.get_child(0) if _root_panel.get_child_count() > 0 else null
    if hbox == null:
        return
    var left_panel: Node = hbox.get_node_or_null("LeftPanel")
    if left_panel == null:
        return
    var members_container: Node = left_panel.get_node_or_null("MembersContainer")
    if members_container == null:
        return
    for child in members_container.get_children():
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
        btn.pressed.connect(_on_member_selected.bind(id))
        members_container.add_child(btn)
        _member_buttons.append(btn)
        _member_ids.append(id)

    var inv_list: Label = left_panel.get_node_or_null("InvList") as Label
    if inv_list != null and _caravan_data.inventory != null:
        var lines: Array[String] = []
        for slot in _caravan_data.inventory.slots:
            if slot != null:
                var item_def: ItemDefinition = ItemRegistry.get_item(slot["id"])
                var item_name: String = item_def.display_name if item_def != null else String(slot["id"])
                lines.append("%s ×%d" % [item_name, slot["count"]])
        inv_list.text = "\n".join(lines) if not lines.is_empty() else "(empty)"


func _refresh_member_cursor() -> void:
    for i in _member_buttons.size():
        var btn: Button = _member_buttons[i]
        var is_selected: bool = (i == _member_cursor and _focus == _Focus.LEFT)
        if is_selected:
            btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
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
        var member_name: String = _caravan_data.get_member_name(member_id) \
                if _caravan_data != null else String(member_id)
        label.text = "%s\nHP: Active companion" % member_name
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.anchor_right = 1.0
        label.anchor_bottom = 1.0
        _right_panel.add_child(label)
```

- [ ] **Step 3: Run unit tests — expect no new failures**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
```

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/caravan_menu.gd
git commit -m "ui: CaravanMenu full keyboard navigation with LEFT/RIGHT focus zones"
```

---

## Task 8 — Final verification

- [ ] **Step 1: Run full test suite**

```bash
cd /home/mpatterson/repos/game4 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "Passing|Failing"
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit 2>&1 | grep -E "Passing|Failing"
```
Expected: unit ≥690 passing / 0 failing; integration ≥107 passing / ≤5 failing.

- [ ] **Step 2: Zero hardcoded action strings**

```bash
grep -rn '"p[12]_\|"p%d_\|p%d_\b' scripts/ --include="*.gd" | grep -v "player_actions.gd"
```
Expected: **empty**.

- [ ] **Step 3: Commit if clean**

```bash
git add -p  # review any uncommitted changes
git commit -m "chore: menu keyboard consistency final cleanup"
```

---

## Self-Review Checklist

- [x] `PlayerActions` constants cover all 13 verbs in project.godot
- [x] `action()`, `prefix()`, `just_pressed()`, `pressed()`, `either_just_pressed()`, `either_pressed()` helpers
- [x] All 10 files with inline action strings replaced (Task 2)
- [x] MENU context gets `back` added (Task 2, input_context.gd)
- [x] PauseManager saves/restores contexts on pause/unpause (Task 3)
- [x] `p*_back` in GAMEPLAY triggers pause (Task 3)
- [x] PauseMenu cursor nav + either-player (Task 4)
- [x] MainMenu cursor nav + either-player (Task 5)
- [x] CrafterPanel.navigate() (Task 6)
- [x] StoryTellerPanel.navigate() (Task 6)
- [x] CaravanMenu LEFT/RIGHT focus zones + delegation (Task 7)
- [x] Tests: PlayerActions unit tests (Task 1)
- [x] All tests pass after each task
- [x] Grep confirms zero hardcoded strings (Task 8)
