# Housing Construction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Builder party member and a ghost-placement system for constructing houses in the overworld that are immediately enterable and persist through save/load.

**Architecture:** A standalone `HousePlacer` node handles placement input and ghost rendering in `WorldRoot`. `World` coordinates signal handling, material deduction, and entry injection into `region.dungeon_entrances`. `CaravanMenu` gains a `build_requested` signal and a `BuilderPanel` detail view. CaravanMenu member cards are redesigned with portrait thumbnails via `CharacterBuilder`.

**Tech Stack:** Godot 4.3 · GDScript · GUT for tests

---

## File Map

| File | Change |
|------|--------|
| `resources/party_members.json` | Add `builder` entry with `builds` array |
| `scripts/data/party_member_def.gd` | Add `@export var builds: Array = []` |
| `scripts/data/party_member_registry.gd` | Pass through `builds` in `_build_cache()` |
| `scripts/world/world_root.gd` | Add `_last_view_kind`, `has_door()`, `rebuild_door_index()`, `add_house_entrance()` |
| `scripts/entities/house_placer.gd` | **NEW** — ghost, input, validity, signals |
| `scripts/world/world.gd` | Add `start_house_placement()`, `_on_house_confirmed()`, `_on_house_cancelled()` |
| `scripts/ui/controls_hud.gd` | Add `_override_hint` + `set_override_hint()` |
| `scripts/main/game.gd` | Add `get_controls_hud()`, `open_caravan_menu()`, wire `build_requested` signal |
| `scripts/ui/caravan_menu.gd` | Portrait card redesign, `build_requested` signal, `BuilderPanel` inline class |
| `scenes/ui/CaravanMenu.tscn` | Change `MembersContainer` from `VBoxContainer` to `GridContainer` |
| `tests/unit/test_builder_data.gd` | **NEW** — unit tests for data layer |
| `tests/integration/test_house_placement.gd` | **NEW** — integration test for full placement flow |

---

## Task 1: Data layer — `builder` entry + `PartyMemberDef.builds`

**Files:**
- Modify: `resources/party_members.json`
- Modify: `scripts/data/party_member_def.gd`
- Modify: `scripts/data/party_member_registry.gd`
- Create: `tests/unit/test_builder_data.gd`

- [ ] **Step 1: Write failing tests**

Create `tests/unit/test_builder_data.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	PartyMemberRegistry.reset()

func test_builder_is_registered() -> void:
	var def: PartyMemberDef = PartyMemberRegistry.get_member(&"builder")
	assert_not_null(def, "builder should be registered")
	assert_eq(def.id, &"builder")

func test_builder_has_builds_field() -> void:
	var def: PartyMemberDef = PartyMemberDef.new()
	assert_true(def.has_method("get") or "builds" in def,
			"PartyMemberDef should have builds property")

func test_builder_builds_loaded_from_json() -> void:
	var def: PartyMemberDef = PartyMemberRegistry.get_member(&"builder")
	assert_not_null(def)
	assert_true(def.builds.size() > 0, "builder should have at least one build entry")
	var entry: Dictionary = def.builds[0]
	assert_eq(entry.get("id", ""), "house_basic")
	assert_true(entry.has("cost"), "build entry should have cost")

func test_house_basic_costs_10_wood() -> void:
	var def: PartyMemberDef = PartyMemberRegistry.get_member(&"builder")
	assert_not_null(def)
	var entry: Dictionary = def.builds[0]
	var cost: Dictionary = entry.get("cost", {})
	assert_eq(int(cost.get("wood", 0)), 10)

func test_other_members_builds_empty() -> void:
	var warrior: PartyMemberDef = PartyMemberRegistry.get_member(&"warrior")
	assert_not_null(warrior)
	assert_eq(warrior.builds.size(), 0, "warrior should have no builds")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "test_builder|FAILED"
```

Expected: all builder tests fail (builder not registered, builds field missing).

- [ ] **Step 3: Add `builds` field to `PartyMemberDef`**

In `scripts/data/party_member_def.gd`, append after the last `@export` line:

```gdscript
## Buildable structures for members with crafter_domain == "builder".
## Each entry: {id: String, display_name: String, cost: {item_id: count}}.
@export var builds: Array = []
```

- [ ] **Step 4: Wire `builds` through the registry**

In `scripts/data/party_member_registry.gd`, in `_build_cache()`, after `d.can_follow = bool(entry.get("can_follow", false))`, add:

```gdscript
		d.builds = entry.get("builds", [])
```

- [ ] **Step 5: Add `builder` to JSON**

In `resources/party_members.json`, add the `builder` key alongside existing entries:

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

- [ ] **Step 6: Run tests and verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -10
```

Expected: all unit tests pass.

- [ ] **Step 7: Commit**

```bash
git add resources/party_members.json scripts/data/party_member_def.gd scripts/data/party_member_registry.gd tests/unit/test_builder_data.gd
git commit -m "feat: builder party member data layer (PartyMemberDef.builds)"
```

---

## Task 2: `WorldRoot` public wrappers + `add_house_entrance`

**Files:**
- Modify: `scripts/world/world_root.gd`

- [ ] **Step 1: Add `_last_view_kind` field**

Find the `var _doors: Dictionary = {}` declaration in `world_root.gd` (around line 120 area — check with grep). Add after it:

```gdscript
var _last_view_kind: StringName = &"overworld"
```

- [ ] **Step 2: Store view kind in `apply_view`**

In `apply_view()`, as the first line of the function body (after `_clear_layers()`), add:

```gdscript
	_last_view_kind = view_kind
```

- [ ] **Step 3: Add three public methods**

In the `# --- Public API` section (near `is_walkable`, line ~187), add:

```gdscript
## Returns true if a door entry exists at [param cell].
func has_door(cell: Vector2i) -> bool:
	return _doors.has(cell)


## Rebuild the door index for the current view without a full apply_view.
## Call after mutating dungeon_entrances at runtime (e.g. player-built house).
func rebuild_door_index() -> void:
	_build_door_index(_last_view_kind)


## Append a player-built house entrance to this region and update all
## live state (doors + entrance markers) immediately.
func add_house_entrance(cell: Vector2i) -> void:
	if _region == null:
		return
	_region.dungeon_entrances.append({"kind": &"house", "cell": cell})
	_build_door_index(_last_view_kind)
	_paint_overworld_entrance_markers(_region)
```

- [ ] **Step 4: Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

Expected: all pass (no existing tests broken).

- [ ] **Step 5: Commit**

```bash
git add scripts/world/world_root.gd
git commit -m "feat: WorldRoot public wrappers has_door, rebuild_door_index, add_house_entrance"
```

---

## Task 3: `HousePlacer` node

**Files:**
- Create: `scripts/entities/house_placer.gd`

- [ ] **Step 1: Create the file**

Create `scripts/entities/house_placer.gd`:

```gdscript
## HousePlacer
##
## Added to a WorldRoot by World.start_house_placement(). Handles ghost
## rendering and player input for positioning and confirming a new house.
## Emits confirmed(pid, cell) or cancelled(pid) then should be freed by
## the World coordinator.
class_name HousePlacer
extends Node2D

signal confirmed(pid: int, cell: Vector2i)
signal cancelled(pid: int)

## Player ID this placer belongs to (0 = P1, 1 = P2).
var pid: int = 0
## Structure being placed (e.g. &"house_basic").
var structure_id: StringName = &"house_basic"
## Reference to the WorldRoot this placer lives in.
var world_root: WorldRoot = null

const _TILE_PX: float = float(WorldConst.TILE_PX)
const _GHOST_TILES: int = 3        # footprint radius: 3×3 tiles
const _REPEAT_DELAY: float = 0.15  # held-key repeat interval

var _cursor_cell: Vector2i = Vector2i.ZERO
var _ghost_bg: ColorRect = null     # 3×3 semi-transparent overlay
var _ghost_door: ColorRect = null   # 1×1 yellow door marker
var _repeat_timer: float = 0.0
var _last_dir: Vector2i = Vector2i.ZERO

const _COL_VALID:   Color = Color(0.2, 1.0, 0.2, 0.35)
const _COL_INVALID: Color = Color(1.0, 0.2, 0.2, 0.35)
const _COL_DOOR:    Color = Color(1.0, 0.9, 0.1, 0.6)


func _ready() -> void:
	z_index = 50
	# Ghost background (3×3 tiles).
	_ghost_bg = ColorRect.new()
	_ghost_bg.size = Vector2(_TILE_PX * _GHOST_TILES, _TILE_PX * _GHOST_TILES)
	_ghost_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost_bg)
	# Door marker (1×1 tile).
	_ghost_door = ColorRect.new()
	_ghost_door.size = Vector2(_TILE_PX, _TILE_PX)
	_ghost_door.color = _COL_DOOR
	_ghost_door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost_door)
	# Start cursor under the player.
	if world_root != null:
		var player: PlayerController = World.instance().get_player(pid) \
				if World.instance() != null else null
		if player != null:
			_cursor_cell = Vector2i(
				int(floor(player.position.x / _TILE_PX)),
				int(floor(player.position.y / _TILE_PX)))
	_update_ghost()


func _process(delta: float) -> void:
	_handle_input(delta)


func _handle_input(delta: float) -> void:
	# Confirm.
	if PlayerActions.just_pressed_ui(pid, PlayerActions.INTERACT):
		if _is_valid(_cursor_cell):
			confirmed.emit(pid, _cursor_cell)
		return
	# Cancel.
	if PlayerActions.just_pressed_ui(pid, PlayerActions.BACK) \
			or PlayerActions.just_pressed_ui(pid, PlayerActions.INVENTORY):
		cancelled.emit(pid)
		return
	# Movement (with held-key repeat).
	var dir := Vector2i.ZERO
	if Input.is_action_pressed(PlayerActions.action(pid, PlayerActions.UP)):
		dir = Vector2i(0, -1)
	elif Input.is_action_pressed(PlayerActions.action(pid, PlayerActions.DOWN)):
		dir = Vector2i(0, 1)
	elif Input.is_action_pressed(PlayerActions.action(pid, PlayerActions.LEFT)):
		dir = Vector2i(-1, 0)
	elif Input.is_action_pressed(PlayerActions.action(pid, PlayerActions.RIGHT)):
		dir = Vector2i(1, 0)

	if dir != Vector2i.ZERO:
		if dir != _last_dir:
			# Fresh key press — move immediately, start repeat timer.
			_last_dir = dir
			_repeat_timer = _REPEAT_DELAY
			_move_cursor(dir)
		else:
			_repeat_timer -= delta
			if _repeat_timer <= 0.0:
				_repeat_timer = _REPEAT_DELAY
				_move_cursor(dir)
	else:
		_last_dir = Vector2i.ZERO


func _move_cursor(dir: Vector2i) -> void:
	_cursor_cell += dir
	_update_ghost()


func _update_ghost() -> void:
	var valid: bool = _is_valid(_cursor_cell)
	_ghost_bg.color = _COL_VALID if valid else _COL_INVALID
	# Position the 3×3 bg centered on cursor cell.
	var centre: Vector2 = (Vector2(_cursor_cell) + Vector2(0.5, 0.5)) * _TILE_PX
	_ghost_bg.position = centre - Vector2(_ghost_bg.size * 0.5)
	# Door marker sits exactly on the cursor cell.
	_ghost_door.position = Vector2(_cursor_cell) * _TILE_PX


func _is_valid(cell: Vector2i) -> bool:
	if world_root == null:
		return false
	if not world_root.is_walkable(cell):
		return false
	if world_root.has_door(cell):
		return false
	# Check for entities at this cell.
	var cell_pos: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * _TILE_PX
	for child in world_root.entities.get_children():
		if not (child is Node2D):
			continue
		var n: Node2D = child as Node2D
		var nc: Vector2i = Vector2i(
			int(floor(n.position.x / _TILE_PX)),
			int(floor(n.position.y / _TILE_PX)))
		if nc == cell:
			return false
	return true
```

Note: `PlayerActions.just_pressed_ui` may not exist — check below. We use `Input.is_action_just_pressed` for one-shot actions.

- [ ] **Step 2: Check how `PlayerActions` works for just-pressed**

```bash
grep -n "just_pressed" scripts/autoload/player_actions.gd | head -10
```

If `PlayerActions.just_pressed(event, pid, verb)` requires an event, switch to the `Input.is_action_just_pressed(PlayerActions.action(pid, verb))` pattern for the confirm and cancel checks. Replace the `just_pressed_ui` calls:

```gdscript
	if Input.is_action_just_pressed(PlayerActions.action(pid, PlayerActions.INTERACT)):
		if _is_valid(_cursor_cell):
			confirmed.emit(pid, _cursor_cell)
		return
	if Input.is_action_just_pressed(PlayerActions.action(pid, PlayerActions.BACK)) \
			or Input.is_action_just_pressed(PlayerActions.action(pid, PlayerActions.INVENTORY)):
		cancelled.emit(pid)
		return
```

- [ ] **Step 3: Run unit tests (smoke check)**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add scripts/entities/house_placer.gd
git commit -m "feat: HousePlacer node for ghost-based house placement"
```

---

## Task 4: `ControlsHud` override hint + `Game` accessors

**Files:**
- Modify: `scripts/ui/controls_hud.gd`
- Modify: `scripts/main/game.gd`

- [ ] **Step 1: Add override hint to `ControlsHud`**

In `scripts/ui/controls_hud.gd`, add a field after `var _player: PlayerController = null`:

```gdscript
var _override_hint: String = ""
```

Add the public setter (after the existing `set_player` method):

```gdscript
## When non-empty, display this text instead of the normal action list.
## Pass "" to revert to normal display.
func set_override_hint(text: String) -> void:
	_override_hint = text
	_refresh()
```

In `_refresh()`, add at the very top of the method body (after the `if _label == null: return` guard):

```gdscript
	if _override_hint != "":
		_label.text = _override_hint
		return
```

- [ ] **Step 2: Add accessors to `Game`**

In `scripts/main/game.gd`, add after the `show_floor_confirm_menu` function (or at the end of the public API section):

```gdscript
## Returns the ControlsHud for [param pid] (0 = P1, 1 = P2).
func get_controls_hud(pid: int) -> ControlsHud:
	return _controls_p1 if pid == 0 else _controls_p2


## Opens the caravan menu for [param pid] if it is set up.
func open_caravan_menu(pid: int) -> void:
	var menu: CaravanMenu = _caravan_menu_p1 if pid == 0 else _caravan_menu_p2
	if menu != null:
		menu.open()
```

- [ ] **Step 3: Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/controls_hud.gd scripts/main/game.gd
git commit -m "feat: ControlsHud.set_override_hint + Game.get_controls_hud / open_caravan_menu"
```

---

## Task 5: `World` coordination — `start_house_placement` + handlers

**Files:**
- Modify: `scripts/world/world.gd`

- [ ] **Step 1: Add the three methods to `World`**

Find the area in `world.gd` near the `debug_add_all_party_members()` function (around line 459). Add the new methods nearby (e.g., in the `# --- Public API` or debug section):

```gdscript
## Begin house placement for [param pid]. Creates a HousePlacer in the
## player's current WorldRoot and shows a hint in ControlsHud.
func start_house_placement(pid: int, structure_id: StringName) -> void:
	var inst: WorldRoot = get_player_world(pid)
	if inst == null:
		return
	# Remove any existing placer for this player.
	var existing: Node = inst.get_node_or_null("HousePlacer_P%d" % pid)
	if existing != null:
		existing.queue_free()
	var placer := HousePlacer.new()
	placer.name = "HousePlacer_P%d" % pid
	placer.pid = pid
	placer.structure_id = structure_id
	placer.world_root = inst
	placer.confirmed.connect(_on_house_confirmed)
	placer.cancelled.connect(_on_house_cancelled)
	inst.add_child(placer)
	# Show placement hint.
	var game: Game = Game.instance()
	if game != null:
		var hud: ControlsHud = game.get_controls_hud(pid)
		if hud != null:
			hud.set_override_hint("Move: position  Interact: confirm  Back/Inv: cancel")


func _on_house_confirmed(pid: int, cell: Vector2i) -> void:
	# Deduct materials.
	var cd: CaravanData = get_caravan_data(pid)
	if cd != null:
		var builder_def: PartyMemberDef = PartyMemberRegistry.get_member(&"builder")
		if builder_def != null:
			for build_entry in builder_def.builds:
				if StringName(build_entry.get("id", "")) == &"house_basic":
					var cost: Dictionary = build_entry.get("cost", {})
					for item_id in cost:
						cd.inventory.remove(StringName(item_id), int(cost[item_id]))
	# Add entrance and update visuals.
	var inst: WorldRoot = get_player_world(pid)
	if inst != null:
		inst.add_house_entrance(cell)
	# Free placer.
	var placer: Node = inst.get_node_or_null("HousePlacer_P%d" % pid) if inst != null else null
	if placer != null:
		placer.queue_free()
	# Clear hint and reopen menu.
	var game: Game = Game.instance()
	if game != null:
		var hud: ControlsHud = game.get_controls_hud(pid)
		if hud != null:
			hud.set_override_hint("")
		game.open_caravan_menu(pid)


func _on_house_cancelled(pid: int) -> void:
	var inst: WorldRoot = get_player_world(pid)
	var placer: Node = inst.get_node_or_null("HousePlacer_P%d" % pid) if inst != null else null
	if placer != null:
		placer.queue_free()
	var game: Game = Game.instance()
	if game != null:
		var hud: ControlsHud = game.get_controls_hud(pid)
		if hud != null:
			hud.set_override_hint("")
		game.open_caravan_menu(pid)
```

- [ ] **Step 2: Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add scripts/world/world.gd
git commit -m "feat: World.start_house_placement + confirmed/cancelled handlers"
```

---

## Task 6: `CaravanMenu` — `BuilderPanel` + `build_requested` signal

**Files:**
- Modify: `scripts/ui/caravan_menu.gd`
- Modify: `scripts/main/game.gd`

- [ ] **Step 1: Add `build_requested` signal and `BuilderPanel` to caravan_menu**

In `scripts/ui/caravan_menu.gd`, add after the `signal swap_pet_requested` line:

```gdscript
## Emitted when the player presses Build in the builder panel.
signal build_requested(player_id: int, structure_id: StringName)
```

Then, in `_on_member_selected()`, find the block that handles `def.crafter_domain != &""`:

```gdscript
	if def.crafter_domain != &"":
		_current_crafter = CrafterPanel.new()
		...
```

Change it to:

```gdscript
	if def.crafter_domain == &"builder":
		for child in _right_panel.get_children():
			child.queue_free()
		_current_crafter = null
		var bp := _BuilderPanel.new()
		bp.anchor_right = 1.0
		bp.anchor_bottom = 1.0
		bp.setup(def, _caravan_data)
		bp.build_pressed.connect(func(sid: StringName) -> void:
			close()
			build_requested.emit(_player_id, sid)
		)
		_right_panel.add_child(bp)
		return
	if def.crafter_domain != &"":
		_current_crafter = CrafterPanel.new()
```

Add `_BuilderPanel` as an inner class at the bottom of `caravan_menu.gd` (after the PetsPanel section):

```gdscript
# ─── BuilderPanel (inner class) ────────────────────────────────────

class _BuilderPanel extends VBoxContainer:
	signal build_pressed(structure_id: StringName)

	var _caravan_data: CaravanData = null

	func setup(def: PartyMemberDef, caravan_data: CaravanData) -> void:
		_caravan_data = caravan_data
		add_theme_constant_override("separation", 8)
		var title := Label.new()
		title.text = "Builder"
		title.theme_type_variation = &"TitleLabel"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(title)
		var sep := HSeparator.new()
		add_child(sep)
		var section := Label.new()
		section.text = "Structures"
		section.theme_type_variation = &"DimLabel"
		add_child(section)
		for entry in def.builds:
			_add_build_row(entry)

	func _add_build_row(entry: Dictionary) -> void:
		var sid: StringName = StringName(entry.get("id", ""))
		var display: String = entry.get("display_name", String(sid))
		var cost: Dictionary = entry.get("cost", {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		# Name label.
		var name_lbl := Label.new()
		name_lbl.text = display
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		# Cost label.
		var cost_parts: Array[String] = []
		var can_afford: bool = true
		for item_id in cost:
			var needed: int = int(cost[item_id])
			var have: int = _caravan_data.inventory.count_of(StringName(item_id)) \
					if _caravan_data != null and _caravan_data.inventory != null else 0
			var item_def: ItemDefinition = ItemRegistry.get_item(StringName(item_id))
			var item_name: String = item_def.display_name if item_def != null else item_id
			cost_parts.append("%d %s" % [needed, item_name])
			if have < needed:
				can_afford = false
		var cost_lbl := Label.new()
		cost_lbl.text = ", ".join(cost_parts)
		cost_lbl.add_theme_color_override("font_color",
				Color(0.4, 1.0, 0.4) if can_afford else Color(1.0, 0.4, 0.4))
		cost_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(cost_lbl)
		# Build button.
		var btn := Button.new()
		btn.text = "Build"
		btn.theme_type_variation = &"WoodButton"
		btn.disabled = not can_afford
		btn.pressed.connect(func() -> void: build_pressed.emit(sid))
		row.add_child(btn)
```

- [ ] **Step 2: Wire `build_requested` in `Game`**

In `scripts/main/game.gd`, in `_wire_hud_and_cameras()`, after the line:
```gdscript
		_caravan_menu_p1.swap_pet_requested.connect(_world.swap_active_pet)
```
add:
```gdscript
		_caravan_menu_p1.build_requested.connect(_world.start_house_placement)
```

And after:
```gdscript
		_caravan_menu_p2.swap_pet_requested.connect(_world.swap_active_pet)
```
add:
```gdscript
		_caravan_menu_p2.build_requested.connect(_world.start_house_placement)
```

- [ ] **Step 3: Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/caravan_menu.gd scripts/main/game.gd
git commit -m "feat: CaravanMenu build_requested signal + BuilderPanel inner class"
```

---

## Task 7: CaravanMenu portrait card redesign

**Files:**
- Modify: `scenes/ui/CaravanMenu.tscn`
- Modify: `scripts/ui/caravan_menu.gd`

- [ ] **Step 1: Change `MembersContainer` to `GridContainer` in the scene**

In `scenes/ui/CaravanMenu.tscn`, find:
```
[node name="MembersContainer" type="VBoxContainer" parent="Panel/HBox/LeftPanel"]
theme_override_constants/separation = 4
```
Replace with:
```
[node name="MembersContainer" type="GridContainer" parent="Panel/HBox/LeftPanel"]
columns = 3
theme_override_constants/h_separation = 4
theme_override_constants/v_separation = 4
```

- [ ] **Step 2: Update the `@onready` type annotation**

In `scripts/ui/caravan_menu.gd`, find:
```gdscript
@onready var _members_container: VBoxContainer = $Panel/HBox/LeftPanel/MembersContainer
```
Replace with:
```gdscript
@onready var _members_container: GridContainer = $Panel/HBox/LeftPanel/MembersContainer
```

- [ ] **Step 3: Rewrite `_refresh_members()` to produce portrait cards**

Replace the entire `_refresh_members()` function body with:

```gdscript
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
		var card := _build_member_card(id, def)
		_members_container.add_child(card)
		_member_buttons.append(card)
		_member_ids.append(id)

	# ─── Pets tab ──────────────────────────────────────────────
	if _world_node != null and _world_node.has_method("get_pet_roster"):
		var pets_card := _build_pets_card()
		_members_container.add_child(pets_card)
		_member_buttons.append(pets_card)
		_member_ids.append(&"__pets_tab__")

	if _inv_list != null and _caravan_data.inventory != null:
		var lines: Array[String] = []
		for slot in _caravan_data.inventory.slots:
			if slot != null:
				var item_def: ItemDefinition = ItemRegistry.get_item(slot["id"])
				var item_name: String = item_def.display_name if item_def != null else String(slot["id"])
				lines.append("%s ×%d" % [item_name, slot["count"]])
		_inv_list.text = "\n".join(lines) if not lines.is_empty() else "(empty)"
```

Add two new helpers after `_refresh_members()`:

```gdscript
func _build_member_card(id: StringName, def: PartyMemberDef) -> Button:
	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(64, 80)
	card.theme_type_variation = &"WoodButton"
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(_on_member_selected.bind(id))

	var inner := VBoxContainer.new()
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.add_theme_constant_override("separation", 2)
	card.add_child(inner)

	# Portrait.
	var portrait_ctrl := Control.new()
	portrait_ctrl.custom_minimum_size = Vector2(32, 32)
	portrait_ctrl.clip_contents = true
	portrait_ctrl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(portrait_ctrl)

	var member_name: String = _caravan_data.get_member_name(id) \
			if _caravan_data != null else String(id)
	var h: int = member_name.hash() & 0x7fffffff
	var opts: Dictionary = _hash_to_appearance(h)
	var char_node: Node2D = CharacterBuilder.build(opts)
	char_node.scale = Vector2(0.5, 0.5)
	char_node.position = Vector2(16, 20)
	portrait_ctrl.add_child(char_node)

	# Name.
	var name_lbl := Label.new()
	name_lbl.text = member_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.clip_text = true
	inner.add_child(name_lbl)

	# Role.
	var role_lbl := Label.new()
	role_lbl.text = def.display_name
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 10)
	role_lbl.add_theme_color_override("font_color", UITheme.COL_LABEL_DIM)
	inner.add_child(role_lbl)

	return card


func _build_pets_card() -> Button:
	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(64, 80)
	card.theme_type_variation = &"WoodButton"
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(_on_member_selected.bind(&"__pets_tab__"))

	var inner := VBoxContainer.new()
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.add_theme_constant_override("separation", 2)
	card.add_child(inner)

	# Portrait — active pet sprite.
	var portrait_ctrl := Control.new()
	portrait_ctrl.custom_minimum_size = Vector2(32, 32)
	portrait_ctrl.clip_contents = true
	portrait_ctrl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(portrait_ctrl)

	var active_species: StringName = GameSession.get("p%d_active_pet" % (_player_id + 1), &"cat")
	if active_species == &"":
		active_species = &"cat"
	var pet_spr: Sprite2D = CreatureSpriteRegistry.build_sprite(active_species)
	if pet_spr != null:
		pet_spr.position = Vector2(16, 16)
		portrait_ctrl.add_child(pet_spr)

	var name_lbl := Label.new()
	name_lbl.text = "Pets"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	inner.add_child(name_lbl)

	var role_lbl := Label.new()
	role_lbl.text = "Companions"
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 10)
	role_lbl.add_theme_color_override("font_color", UITheme.COL_LABEL_DIM)
	inner.add_child(role_lbl)

	return card


## Deterministically map an integer hash to CharacterBuilder opts.
static func _hash_to_appearance(h: int) -> Dictionary:
	var skin_opts: Array[StringName] = [&"light", &"medium", &"dark", &"tan"]
	var torso_colors: Array[StringName] = [&"orange", &"blue", &"green", &"red", &"purple"]
	var hair_colors: Array[StringName] = [&"brown", &"black", &"blonde", &"red", &"grey"]
	return {
		"skin": skin_opts[(h >> 0) % skin_opts.size()],
		"torso_color": torso_colors[(h >> 4) % torso_colors.size()],
		"torso_style": (h >> 8) % 4,
		"torso_row": (h >> 10) % 3,
		"hair_color": hair_colors[(h >> 12) % hair_colors.size()],
		"hair_style": (h >> 16) % 4,
		"hair_variant": (h >> 18) % 3,
	}
```

- [ ] **Step 4: Update `_refresh_member_cursor()` for card-based highlight**

Find `_refresh_member_cursor()` and replace it with:

```gdscript
func _refresh_member_cursor() -> void:
	for i in _member_buttons.size():
		var btn: Button = _member_buttons[i]
		var is_selected: bool = (i == _member_cursor and _focus == _Focus.LEFT)
		btn.modulate = Color(1.4, 1.2, 0.5) if is_selected else Color.WHITE
```

- [ ] **Step 5: Verify `CharacterAtlas` skin/hair/torso values are correct**

```bash
grep -n "skin_opts\|SKIN\|light.*medium\|torso_color\|ORANGE\|orange" scripts/data/character_atlas.gd | head -15
```

Adjust `skin_opts`, `torso_colors`, `hair_colors` in `_hash_to_appearance` to match valid values from `CharacterAtlas`. If the file is `scripts/entities/character_atlas.gd` or `scripts/data/character_atlas.gd`, check for constants named `SKINS`, `TORSO_COLORS`, etc.

- [ ] **Step 6: Run unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add scenes/ui/CaravanMenu.tscn scripts/ui/caravan_menu.gd
git commit -m "feat: CaravanMenu portrait card redesign (CharacterBuilder thumbnails)"
```

---

## Task 8: Integration test

**Files:**
- Create: `tests/integration/test_house_placement.gd`

- [ ] **Step 1: Create the integration test**

Create `tests/integration/test_house_placement.gd`:

```gdscript
extends GutTest

var _game: Game = null
var _world: World = null

func before_each() -> void:
	WorldManager.reset(99991)
	PartyMemberRegistry.reset()
	var scene := load("res://scenes/main/Game.tscn") as PackedScene
	_game = scene.instantiate() as Game
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_world = _game.get_node_or_null("World") as World
	if _world == null:
		_world = World.instance()

func test_builder_registered_after_f8() -> void:
	assert_not_null(_world, "World should exist")
	_world.debug_add_all_party_members()
	var cd: CaravanData = _world.get_caravan_data(0)
	assert_not_null(cd)
	assert_true(cd.has_member(&"builder"), "builder should be recruited after F8")

func test_start_house_placement_creates_placer() -> void:
	assert_not_null(_world)
	_world.debug_add_all_party_members()
	# Give P1 enough wood.
	var cd: CaravanData = _world.get_caravan_data(0)
	assert_not_null(cd)
	cd.inventory.add(&"wood", 10)
	# Start placement.
	_world.start_house_placement(0, &"house_basic")
	await get_tree().process_frame
	var inst: WorldRoot = _world.get_player_world(0)
	assert_not_null(inst)
	var placer: Node = inst.get_node_or_null("HousePlacer_P0")
	assert_not_null(placer, "HousePlacer_P0 should exist after start_house_placement")

func test_cancel_removes_placer() -> void:
	assert_not_null(_world)
	_world.debug_add_all_party_members()
	_world.start_house_placement(0, &"house_basic")
	await get_tree().process_frame
	# Simulate cancel signal.
	var inst: WorldRoot = _world.get_player_world(0)
	assert_not_null(inst)
	_world._on_house_cancelled(0)
	await get_tree().process_frame
	var placer: Node = inst.get_node_or_null("HousePlacer_P0")
	assert_null(placer, "placer should be freed after cancel")

func test_confirm_adds_house_to_region() -> void:
	assert_not_null(_world)
	_world.debug_add_all_party_members()
	var cd: CaravanData = _world.get_caravan_data(0)
	assert_not_null(cd)
	cd.inventory.add(&"wood", 10)
	var inst: WorldRoot = _world.get_player_world(0)
	assert_not_null(inst)
	var region: Region = WorldManager.get_or_generate(Vector2i.ZERO)
	var before_count: int = region.dungeon_entrances.size()
	# Place at a known walkable cell far from existing entrances.
	var cell := Vector2i(10, 10)
	_world.start_house_placement(0, &"house_basic")
	await get_tree().process_frame
	_world._on_house_confirmed(0, cell)
	await get_tree().process_frame
	assert_eq(region.dungeon_entrances.size(), before_count + 1,
			"region should have one more entrance after placement")
	var last: Dictionary = region.dungeon_entrances.back()
	assert_eq(last.get("kind", &""), &"house")
	assert_eq(last.get("cell", Vector2i(-1, -1)), cell)

func test_confirm_deducts_wood() -> void:
	assert_not_null(_world)
	_world.debug_add_all_party_members()
	var cd: CaravanData = _world.get_caravan_data(0)
	assert_not_null(cd)
	cd.inventory.add(&"wood", 10)
	assert_eq(cd.inventory.count_of(&"wood"), 10)
	_world.start_house_placement(0, &"house_basic")
	await get_tree().process_frame
	_world._on_house_confirmed(0, Vector2i(10, 10))
	await get_tree().process_frame
	assert_eq(cd.inventory.count_of(&"wood"), 0, "10 wood should be consumed on confirm")
```

- [ ] **Step 2: Run integration tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -10
```

Expected: all new integration tests pass.

- [ ] **Step 3: Run full test suite**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -10
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add tests/integration/test_house_placement.gd
git commit -m "test: integration tests for house placement flow"
```

---

## Task 9: Refresh class cache + final smoke test

- [ ] **Step 1: Refresh class cache (new `class_name HousePlacer`)**

```bash
timeout 15 godot --headless --editor & sleep 10; kill %1 2>/dev/null; echo "cache refreshed"
```

- [ ] **Step 2: Run full test suite**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | grep -E "passed|failed|FAILED" | tail -10
```

Expected: all tests pass.

- [ ] **Step 3: Final commit**

```bash
git add .
git commit -m "chore: refresh class cache after HousePlacer class_name"
```

---

## Verification Checklist (manual)

After all tasks pass:

1. **F8 in-game**: Press F8, open caravan, see portrait cards in a 3-column grid including Builder card.
2. **Builder detail**: Click Builder card → right panel shows "Structures / Basic House / 10 wood / [Build]" with red cost (no wood). Give yourself 10 wood via F9 (or cheat), reopen — cost turns green, button enabled.
3. **Placement mode**: Press Build → caravan menu closes → green/red ghost appears → move with WASD/arrows → ghost tracks cursor.
4. **Invalid cells**: Walk ghost over water or cliff — ghost turns red.
5. **Confirm**: Press interact on valid cell → ghost disappears, warm-tinted house marker appears at that tile, caravan menu reopens, wood inventory reduced by 10.
6. **Enter house**: Walk into the new door tile → transitions into a house interior identical to generated houses.
7. **Cancel**: Start placement, press inventory or back → caravan menu reopens, no entrance added.
8. **Save/reload**: Build a house, save, reload — house entrance still present in the region.
