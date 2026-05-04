# Death Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the immediate-pause-on-death with a cinematic death flow: player falls over (90° tween), world keeps running, a 5-second countdown overlay shows per-player viewport, then the math screen appears for that player only. On correct answer the player respawns with 3 seconds of flashing invincibility.

**Architecture:** `PlayerController` gains `is_dead`, `_invincible_timer` state and `die()` / `respawn()` methods. `game.gd` removes the global pause and instead drives a per-player countdown timer + overlay. `MathDeathScreen` gets `process_mode = ALWAYS` so it runs without a tree pause. Invincibility is checked in `take_hit()`.

**Tech Stack:** Godot 4.3 GDScript, GUT tests, no new scenes required.

---

### Task 1: PlayerController — dead state + invincibility

**Files:**
- Modify: `scripts/entities/player_controller.gd`
- Test: `tests/unit/test_player_death_state.gd` (NEW)

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_player_death_state.gd`:

```gdscript
## Tests for PlayerController death state and invincibility.
extends GutTest

func _make_player() -> PlayerController:
	var p := PlayerController.new()
	add_child_autofree(p)
	return p


func test_is_dead_false_by_default() -> void:
	var p := _make_player()
	assert_false(p.is_dead)


func test_die_sets_is_dead() -> void:
	var p := _make_player()
	p.health = 5
	p.die()
	assert_true(p.is_dead)


func test_respawn_clears_is_dead() -> void:
	var p := _make_player()
	p.health = 5
	p.die()
	p.respawn(10)
	assert_false(p.is_dead)


func test_respawn_restores_health() -> void:
	var p := _make_player()
	p.health = 1
	p.die()
	p.respawn(10)
	assert_eq(p.health, 10)


func test_take_hit_ignored_while_dead() -> void:
	var p := _make_player()
	p.health = 5
	p.die()
	p.take_hit(99)
	assert_eq(p.health, 0)  # health unchanged after die()


func test_take_hit_ignored_during_invincibility() -> void:
	var p := _make_player()
	p.health = 10
	p.respawn(10)  # starts invincibility
	p.take_hit(5)
	assert_eq(p.health, 10)


func test_invincible_timer_starts_after_respawn() -> void:
	var p := _make_player()
	p.respawn(10)
	assert_gt(p._invincible_timer, 0.0)
```

- [ ] **Step 2: Run tests and confirm they fail**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_player_death_state.gd -gexit 2>&1 | grep -E "pass|fail"
```
Expected: all tests fail (symbols not found).

- [ ] **Step 3: Add state vars to PlayerController**

In `scripts/entities/player_controller.gd`, after the existing `var auto_attack: bool = false` line (around line 50), add:

```gdscript
var is_dead: bool = false
var _invincible_timer: float = 0.0
const _INVINCIBLE_DURATION: float = 3.0
const _DEATH_WAIT_SEC: float = 5.0
```

- [ ] **Step 4: Add `die()` and `respawn()` methods**

In `scripts/entities/player_controller.gd`, after the existing `heal()` function (around line 698), add:

```gdscript
## Called when health reaches 0. Enters dead state and tweens sprite to lying-down.
## Does NOT emit player_died — that is emitted from take_hit() as before.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	health = 0
	InputContext.set_context(player_id, InputContext.Context.DISABLED)
	_bob_t = 0.0
	_sprite_root.position = Vector2.ZERO
	# Tween sprite root to 90 degrees (lying on side).
	var tw := create_tween()
	tw.tween_property(_sprite_root, "rotation_degrees", 90.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Restore player from dead state with [param new_health] HP and start invincibility.
func respawn(new_health: int) -> void:
	is_dead = false
	health = mini(new_health, max_health)
	_invincible_timer = _INVINCIBLE_DURATION
	InputContext.set_context(player_id, InputContext.Context.GAMEPLAY)
	# Tween sprite root back upright.
	var tw := create_tween()
	tw.tween_property(_sprite_root, "rotation_degrees", 0.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING)
```

- [ ] **Step 5: Update `take_hit()` to respect `is_dead` and `_invincible_timer`**

In `scripts/entities/player_controller.gd`, find `take_hit()` (around line 654). Replace its opening guard block:

Current code:
```gdscript
func take_hit(damage: int, _attacker: Node = null, element: int = 0) -> void:
	if health <= 0:
		return
	# Invincible while in a conversation.
	if in_conversation:
		return
```

Replace with:
```gdscript
func take_hit(damage: int, _attacker: Node = null, element: int = 0) -> void:
	if health <= 0:
		return
	if is_dead:
		return
	if _invincible_timer > 0.0:
		return
	# Invincible while in a conversation.
	if in_conversation:
		return
```

- [ ] **Step 6: Tick `_invincible_timer` and drive invincibility flash in `_physics_process`**

In `scripts/entities/player_controller.gd`, find `_physics_process(delta)` (around line 339). After `tick_effects(delta)` and before the `in_conversation` check, add:

```gdscript
	# Tick invincibility and drive flashing visual.
	if _invincible_timer > 0.0:
		_invincible_timer = max(0.0, _invincible_timer - delta)
		# Flash: visible every other 0.15s window.
		_sprite_root.visible = int(_invincible_timer / 0.15) % 2 == 0
	else:
		_sprite_root.visible = true
```

- [ ] **Step 7: Run tests and confirm they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_player_death_state.gd -gexit 2>&1 | grep -E "pass|fail"
```
Expected: 7/7 passed.

- [ ] **Step 8: Commit**

```bash
git add scripts/entities/player_controller.gd tests/unit/test_player_death_state.gd
git commit -m "feat(death): add is_dead, invincibility, die()/respawn() to PlayerController"
```

---

### Task 2: game.gd — no-pause death flow + countdown overlay

**Files:**
- Modify: `scripts/main/game.gd`
- Test: None (integration logic; covered by Task 3 integration test)

- [ ] **Step 1: Add the knocked-out overlay helper**

In `scripts/main/game.gd`, after the `_ensure_floor_overlay()` function (around line 406), add:

```gdscript
## Build or retrieve the per-player "knocked out" countdown overlay.
## Returns the Label node used for countdown text.
func _ensure_knockout_overlay(container: Control) -> Label:
	var existing: Node = container.get_node_or_null("KnockoutOverlay")
	if existing is Control:
		return existing.get_node("CountdownLabel") as Label
	var overlay := ColorRect.new()
	overlay.name = "KnockoutOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 95
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	var lbl := Label.new()
	lbl.name = "CountdownLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.text = "Knocked out…"
	overlay.add_child(lbl)
	container.add_child(overlay)
	return lbl
```

- [ ] **Step 2: Replace `_on_player_died` and `_on_math_answer_correct`**

In `scripts/main/game.gd`, replace the existing `_on_player_died` and `_on_math_answer_correct` functions:

Current code:
```gdscript
func _on_player_died(pid: int) -> void:
	get_tree().paused = true
	if _math_death != null:
		_math_death.show_for_player(pid)


func _on_math_answer_correct(pid: int) -> void:
	var player: PlayerController = _player_p1 if pid == 0 else _player_p2
	if player != null:
		player.health = player.max_health
	get_tree().paused = false
```

Replace with:
```gdscript
func _on_player_died(pid: int) -> void:
	var player: PlayerController = _player_p1 if pid == 0 else _player_p2
	if player != null:
		player.die()
	var container: Control = _container_p1 if pid == 0 else _container_p2
	var lbl: Label = _ensure_knockout_overlay(container)
	var overlay: Node = lbl.get_parent()
	overlay.visible = true
	# Count down 5 → 1, then show math screen.
	var elapsed: float = 0.0
	var total: float = PlayerController._DEATH_WAIT_SEC
	while elapsed < total:
		var remaining: int = ceili(total - elapsed)
		lbl.text = "Knocked out…\n%d" % remaining
		await get_tree().create_timer(0.2, false, false, true).timeout
		elapsed += 0.2
	overlay.visible = false
	if _math_death != null:
		_math_death.show_for_player(pid)


func _on_math_answer_correct(pid: int) -> void:
	var player: PlayerController = _player_p1 if pid == 0 else _player_p2
	if player != null:
		player.respawn(player.max_health)
```

- [ ] **Step 3: Ensure `MathDeathScreen` runs while tree is unpaused**

The tree is no longer paused on death, so `MathDeathScreen` doesn't need `PROCESS_MODE_ALWAYS`. But its `process_mode = 3` (ALWAYS) in the scene is harmless — leave it as-is.

No code change needed for this step. Just confirm:
```bash
grep "process_mode" scenes/ui/MathDeathScreen.tscn
```
Expected: `process_mode = 3`

- [ ] **Step 4: Commit**

```bash
git add scripts/main/game.gd
git commit -m "feat(death): no-pause death flow with per-player countdown overlay"
```

---

### Task 3: Integration test for the full death → respawn flow

**Files:**
- Test: `tests/integration/test_death_respawn.gd` (NEW)

- [ ] **Step 1: Write the integration tests**

Create `tests/integration/test_death_respawn.gd`:

```gdscript
## Integration tests for death → countdown → respawn → invincibility flow.
extends GutTest

const GameScene := preload("res://scenes/main/Game.tscn")

var _game: Node = null
var _p1: PlayerController = null

func before_each() -> void:
	WorldManager.reset(999)
	_game = GameScene.instantiate()
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_p1 = _game.get_node_or_null("World/WorldRoot_0_0/PlayerController_0") as PlayerController
	if _p1 == null:
		# Try alternate path used by game scene.
		for child in _game.get_children():
			if child is PlayerController:
				_p1 = child
				break


func test_player_exists() -> void:
	assert_not_null(_p1, "PlayerController p1 should exist")


func test_die_sets_is_dead() -> void:
	if _p1 == null:
		pass
		return
	_p1.health = 5
	_p1.die()
	assert_true(_p1.is_dead)
	assert_eq(_p1.health, 0)


func test_respawn_restores_and_starts_invincibility() -> void:
	if _p1 == null:
		pass
		return
	_p1.health = 1
	_p1.die()
	_p1.respawn(_p1.max_health)
	assert_false(_p1.is_dead)
	assert_eq(_p1.health, _p1.max_health)
	assert_gt(_p1._invincible_timer, 0.0)


func test_take_hit_ignored_while_invincible() -> void:
	if _p1 == null:
		pass
		return
	_p1.health = _p1.max_health
	_p1.respawn(_p1.max_health)
	_p1.take_hit(5)
	assert_eq(_p1.health, _p1.max_health)


func test_tree_not_paused_after_die() -> void:
	if _p1 == null:
		pass
		return
	_p1.health = 1
	_p1.die()
	assert_false(get_tree().paused, "Tree must not pause on die()")
```

- [ ] **Step 2: Run integration tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gtest=res://tests/integration/test_death_respawn.gd -gexit 2>&1 | grep -E "pass|fail"
```
Expected: 5/5 passed (or 4/5 if the player node path needs adjustment — check the error and fix the path in `before_each`).

- [ ] **Step 3: Run full test suite to check for regressions**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | grep -E "fail|pass" | grep -v "orphan\|leaked\|WARNING" | tail -5
```
Expected: same pre-existing 5 failures, no new failures.

- [ ] **Step 4: Commit**

```bash
git add tests/integration/test_death_respawn.gd
git commit -m "test(death): integration tests for die/respawn flow"
```

---

### Task 4: Sprite flashing polish + regression guard

**Files:**
- Modify: `scripts/entities/player_controller.gd` (guard against flashing persisting across scene reload)
- Test: `tests/unit/test_player_death_state.gd` (add 2 tests)

- [ ] **Step 1: Add two more unit tests**

Append to `tests/unit/test_player_death_state.gd`:

```gdscript
func test_sprite_root_visible_after_invincibility_expires() -> void:
	var p := _make_player()
	p.respawn(10)
	# Manually expire the timer.
	p._invincible_timer = 0.0
	# Call _physics_process with a tiny delta to trigger the else branch.
	p._physics_process(0.001)
	assert_true(p._sprite_root.visible if p._sprite_root != null else true)


func test_invincible_timer_depletes_over_time() -> void:
	var p := _make_player()
	p.respawn(10)
	var before: float = p._invincible_timer
	p._physics_process(1.0)
	assert_lt(p._invincible_timer, before)
```

- [ ] **Step 2: Run the updated unit tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=res://tests/unit/test_player_death_state.gd -gexit 2>&1 | grep -E "pass|fail"
```
Expected: 9/9 passed.

- [ ] **Step 3: Guard `is_dead` and `_sprite_root.visible` on respawn**

In `respawn()` in `scripts/entities/player_controller.gd`, ensure visibility is reset so a sprite that was hidden by the flash is always shown on respawn. The `_sprite_root.visible = true` assignment belongs in `respawn()` directly, not just in `_physics_process`. Add it:

```gdscript
func respawn(new_health: int) -> void:
	is_dead = false
	health = mini(new_health, max_health)
	_invincible_timer = _INVINCIBLE_DURATION
	if _sprite_root != null:
		_sprite_root.visible = true
	InputContext.set_context(player_id, InputContext.Context.GAMEPLAY)
	# Tween sprite root back upright.
	var tw := create_tween()
	tw.tween_property(_sprite_root, "rotation_degrees", 0.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING)
```

- [ ] **Step 4: Run all tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | grep -E "fail|pass" | grep -v "orphan\|leaked\|WARNING" | tail -5
```
Expected: same 5 pre-existing failures, no new failures.

- [ ] **Step 5: Final commit**

```bash
git add scripts/entities/player_controller.gd tests/unit/test_player_death_state.gd
git commit -m "feat(death): ensure sprite visibility reset on respawn"
```
