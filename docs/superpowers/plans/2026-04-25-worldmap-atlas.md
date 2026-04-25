# Worldmap / Atlas View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-player fog-of-war worldmap overlay that reveals tiles as the player explores, rendered as biome-colored regions with a sky/altitude aesthetic.

**Architecture:** `FogOfWarData` (pure RefCounted, per-player bitmask store) feeds `WorldMapView` (Control, per-player viewport overlay, draws `ImageTexture` per region). `PlayerController` owns a `FogOfWarData` instance and a timer that reveals tiles and triggers redraws. `game.gd` builds and wires both.

**Tech Stack:** GDScript, Godot 4.3, `Image` / `ImageTexture` for region textures, `GradientTexture2D` for vignette, `Tween` for open/close animation, GUT for tests.

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `scripts/data/fog_of_war.gd` | Per-player bitmask fog store + serialization |
| Create | `scripts/ui/world_map_view.gd` | Map overlay Control: draw, animate, input |
| Modify | `scripts/entities/player_controller.gd` | Add fog_of_war field, reveal timer, worldmap toggle input |
| Modify | `scripts/main/game.gd` | Build WorldMapView per player, wire to player |
| Modify | `scripts/data/player_save_data.gd` | Add fog_data field |
| Modify | `scripts/data/save_game.gd` | Serialize/restore fog in snapshot/apply |
| Modify | `project.godot` | Register p1_worldmap (KEY_TAB) and p2_worldmap (KEY_KP_6) |
| Create | `tests/unit/test_fog_of_war.gd` | Unit tests for FogOfWarData |
| Create | `tests/integration/test_worldmap_save.gd` | Integration test: fog survives save/load |

---

## Task 1: Register input actions in project.godot

**Files:**
- Modify: `project.godot` (the `[input]` section)

> **Note:** KEY_KP_9 (`4194447`) is already used by `p2_auto_attack`. We use KEY_KP_6 (`4194444`) for p2 instead.

- [ ] **Step 1: Add `p1_worldmap` and `p2_worldmap` actions**

Open `project.godot`. Find the `[input]` section. After the last existing `p2_*` entry (before `[physics]`), insert:

```
p1_worldmap={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194306,"physical_keycode":0,"key_label":0,"unicode":9,"location":0,"echo":false,"script":null)
]
}
p2_worldmap={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194444,"physical_keycode":0,"key_label":0,"unicode":54,"location":3,"echo":false,"script":null)
]
}
```

Key values used:
- `p1_worldmap`: keycode `4194306` = `KEY_TAB`, unicode `9`, location `0` (main keyboard)
- `p2_worldmap`: keycode `4194444` = `KEY_KP_6`, unicode `54` (ASCII '6'), location `3` (numpad)

- [ ] **Step 2: Verify the actions exist**

```bash
grep -c "p1_worldmap\|p2_worldmap" project.godot
```
Expected: `4` (two key names × two occurrences each)

- [ ] **Step 3: Commit**

```bash
git add project.godot
git commit -m "feat(input): add p1_worldmap (Tab) and p2_worldmap (KP_6) actions"
```

---

## Task 2: FogOfWarData — bitmask fog store

**Files:**
- Create: `scripts/data/fog_of_war.gd`
- Create: `tests/unit/test_fog_of_war.gd`

### Step 1 — Write failing tests

- [ ] **Step 1: Create `tests/unit/test_fog_of_war.gd`**

```gdscript
extends GutTest

var fog: FogOfWarData

func before_each() -> void:
	fog = FogOfWarData.new()

func test_unrevealed_returns_false() -> void:
	assert_false(fog.is_revealed(Vector2i.ZERO, Vector2i(5, 5)))

func test_has_region_false_before_reveal() -> void:
	assert_false(fog.has_region(Vector2i.ZERO))

func test_has_region_true_after_reveal() -> void:
	fog.reveal(Vector2i.ZERO, Vector2i(5, 5), 1)
	assert_true(fog.has_region(Vector2i.ZERO))

func test_reveal_center_cell() -> void:
	fog.reveal(Vector2i.ZERO, Vector2i(10, 10), 0)
	assert_true(fog.is_revealed(Vector2i.ZERO, Vector2i(10, 10)))

func test_reveal_radius_includes_adjacent() -> void:
	fog.reveal(Vector2i.ZERO, Vector2i(10, 10), 2)
	assert_true(fog.is_revealed(Vector2i.ZERO, Vector2i(12, 10)))
	assert_true(fog.is_revealed(Vector2i.ZERO, Vector2i(10, 8)))

func test_reveal_radius_excludes_outside() -> void:
	fog.reveal(Vector2i.ZERO, Vector2i(10, 10), 2)
	# (10,10) + (3,0) = distance 3, outside radius 2
	assert_false(fog.is_revealed(Vector2i.ZERO, Vector2i(13, 10)))

func test_reveal_near_origin_does_not_panic() -> void:
	# Cells with negative coords after subtracting radius must be clamped
	fog.reveal(Vector2i.ZERO, Vector2i(2, 2), 10)
	assert_true(fog.is_revealed(Vector2i.ZERO, Vector2i(0, 0)))

func test_to_dict_from_dict_round_trip() -> void:
	fog.reveal(Vector2i(3, -1), Vector2i(64, 64), 5)
	var d: Dictionary = fog.to_dict()
	var fog2 := FogOfWarData.new()
	fog2.from_dict(d)
	assert_true(fog2.is_revealed(Vector2i(3, -1), Vector2i(64, 64)))
	assert_false(fog2.is_revealed(Vector2i(3, -1), Vector2i(0, 0)))

func test_get_all_region_ids_returns_revealed_regions() -> void:
	fog.reveal(Vector2i(1, 2), Vector2i(10, 10), 1)
	fog.reveal(Vector2i(-1, 0), Vector2i(10, 10), 1)
	var ids: Array = fog.get_all_region_ids()
	assert_eq(ids.size(), 2)
```

- [ ] **Step 2: Run tests — expect failure (class not defined)**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | grep -E "PASS|FAIL|ERROR|test_fog"
```
Expected: errors about `FogOfWarData` not found.

### Step 3 — Implement FogOfWarData

- [ ] **Step 3: Create `scripts/data/fog_of_war.gd`**

```gdscript
## FogOfWarData
##
## Per-player fog-of-war bitmask store. Each visited region gets a
## 2048-byte PackedByteArray (128×128 bits = one bit per tile).
## Bit index = y * 128 + x.
class_name FogOfWarData
extends RefCounted

## region_id (Vector2i) → PackedByteArray (2048 bytes)
var _fog: Dictionary = {}


## Mark all tiles within [param radius] tiles of [param cell] as revealed
## in [param region_id]. Tiles outside 0–127 are silently skipped.
func reveal(region_id: Vector2i, cell: Vector2i, radius: int) -> void:
	if not _fog.has(region_id):
		var data := PackedByteArray()
		data.resize(2048)
		_fog[region_id] = data
	var data: PackedByteArray = _fog[region_id]
	var r2: int = radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var cx: int = cell.x + dx
			var cy: int = cell.y + dy
			if cx < 0 or cx >= 128 or cy < 0 or cy >= 128:
				continue
			var idx: int = cy * 128 + cx
			data[idx >> 3] = data[idx >> 3] | (1 << (idx & 7))


## Returns true if [param cell] in [param region_id] has been revealed.
func is_revealed(region_id: Vector2i, cell: Vector2i) -> bool:
	if not _fog.has(region_id):
		return false
	if cell.x < 0 or cell.x >= 128 or cell.y < 0 or cell.y >= 128:
		return false
	var idx: int = cell.y * 128 + cell.x
	var data: PackedByteArray = _fog[region_id]
	return (data[idx >> 3] & (1 << (idx & 7))) != 0


## Returns true if [param region_id] has any revealed tiles.
func has_region(region_id: Vector2i) -> bool:
	return _fog.has(region_id)


## Returns an Array[Vector2i] of all region IDs with any revealed tiles.
func get_all_region_ids() -> Array:
	return _fog.keys()


## Serialize to a Dictionary safe for storage in a .tres Resource field.
## Keys are "x,y" strings; values are PackedByteArray.
func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for rid: Vector2i in _fog.keys():
		result["%d,%d" % [rid.x, rid.y]] = _fog[rid].duplicate()
	return result


## Restore from a dictionary produced by [method to_dict].
func from_dict(d: Dictionary) -> void:
	_fog.clear()
	for key: String in d.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() != 2:
			continue
		var rid := Vector2i(int(parts[0]), int(parts[1]))
		_fog[rid] = (d[key] as PackedByteArray).duplicate()
```

- [ ] **Step 4: Refresh the class cache**

```bash
timeout 15 godot --headless --editor 2>/dev/null; true
```

- [ ] **Step 5: Run tests — expect all pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit 2>&1 | grep -E "PASS|FAIL|ERROR|test_fog"
```
Expected: all `test_fog_of_war` tests PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/data/fog_of_war.gd tests/unit/test_fog_of_war.gd
git commit -m "feat(fog): FogOfWarData bitmask store with unit tests"
```

---

## Task 3: WorldMapView Control

**Files:**
- Create: `scripts/ui/world_map_view.gd`

No automated test for rendering (visual). Manual smoke test in Task 7.

- [ ] **Step 1: Create `scripts/ui/world_map_view.gd`**

```gdscript
## WorldMapView
##
## Per-player worldmap overlay. Fills the player's viewport pane.
## Renders one ImageTexture per discovered region (rebuilt when fog changes).
## Open/close animation: scale zoom-in from center + alpha fade.
## Vignette TextureRect overlaid for altitude effect.
extends Control
class_name WorldMapView

const BIOME_COLORS: Dictionary = {
	&"grass":  Color(0.35, 0.65, 0.25),
	&"water":  Color(0.15, 0.40, 0.75),
	&"desert": Color(0.85, 0.75, 0.45),
	&"swamp":  Color(0.30, 0.45, 0.25),
	&"snow":   Color(0.90, 0.93, 0.98),
	&"cave":   Color(0.30, 0.25, 0.20),
	&"ocean":  Color(0.08, 0.25, 0.60),
}
const BIOME_COLOR_FALLBACK: Color = Color(0.25, 0.25, 0.25)
const FOG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.75)
const SKY_COLOR: Color = Color(0.05, 0.08, 0.15, 1.0)
const LANDMARK_COLOR: Color = Color(0.8, 0.3, 0.3)

var _player: PlayerController = null
var _player_id: int = 0
## Cached ImageTexture per region. Rebuilt by _rebuild_all_textures().
var _region_textures: Dictionary = {}  # Vector2i → ImageTexture
var _textures_dirty: bool = true
var _is_animating: bool = false


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_vignette()


func _build_vignette() -> void:
	var vignette := TextureRect.new()
	vignette.name = "VignetteRect"
	vignette.anchor_left = 0.0
	vignette.anchor_right = 1.0
	vignette.anchor_top = 0.0
	vignette.anchor_bottom = 1.0
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.0, 0.0, 0.0, 0.85))
	grad.gradient = g
	vignette.texture = grad
	add_child(vignette)


## Call from game.gd after the player is created.
func set_player(p: PlayerController) -> void:
	_player = p
	_player_id = p.player_id


## Mark textures as needing rebuild on next draw. Called by PlayerController
## fog reveal timer.
func mark_dirty() -> void:
	_textures_dirty = true


## Toggle open/closed. Re-entrant calls during animation are ignored.
func toggle() -> void:
	if _is_animating:
		return
	if not visible:
		_open()
	else:
		_close()


func _open() -> void:
	_is_animating = true
	_textures_dirty = true
	visible = true
	pivot_offset = size / 2.0
	scale = Vector2(0.05, 0.05)
	modulate.a = 0.0
	InputContext.set_context(_player_id, InputContext.Context.MENU)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: _is_animating = false)


func _close() -> void:
	_is_animating = true
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.05, 0.05), 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(_on_close_finished)


func _on_close_finished() -> void:
	visible = false
	_is_animating = false
	InputContext.set_context(_player_id, InputContext.Context.GAMEPLAY)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY_COLOR)
	if _player == null:
		return
	if _textures_dirty:
		_rebuild_all_textures()
		_textures_dirty = false
	if _region_textures.is_empty():
		return
	var bbox: Rect2i = _compute_bbox()
	if bbox.size.x == 0 or bbox.size.y == 0:
		return
	var tile_px: float = _compute_tile_px(bbox)
	var map_origin: Vector2 = _compute_map_origin(bbox, tile_px)
	# Draw region textures.
	for region_id: Vector2i in _region_textures.keys():
		var tex: ImageTexture = _region_textures[region_id]
		var rpos: Vector2 = map_origin + Vector2(region_id.x * 128, region_id.y * 128) * tile_px
		var rsz: Vector2 = Vector2(128.0, 128.0) * tile_px
		draw_texture_rect(tex, Rect2(rpos, rsz), false)
	# Draw dungeon landmark icons.
	for rid: Vector2i in WorldManager.regions.keys():
		if not _region_textures.has(rid):
			continue
		var region: Region = WorldManager.regions[rid]
		for entry: Dictionary in region.dungeon_entrances:
			var cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
			if cell.x < 0:
				continue
			if not _player.fog_of_war.is_revealed(rid, cell):
				continue
			var spos: Vector2 = map_origin + Vector2(rid.x * 128 + cell.x, rid.y * 128 + cell.y) * tile_px
			draw_circle(spos, 3.0, LANDMARK_COLOR)
	# Draw player marker (pulsing).
	if _player._world != null and _player._world._region != null:
		var rid: Vector2i = _player._world._region.region_id
		var cx: int = int(floor(_player.position.x / float(WorldConst.TILE_PX)))
		var cy: int = int(floor(_player.position.y / float(WorldConst.TILE_PX)))
		var pulse: float = sin(Time.get_ticks_msec() * 0.004) * 0.25 + 0.75
		var mpos: Vector2 = map_origin + Vector2(rid.x * 128 + cx, rid.y * 128 + cy) * tile_px
		draw_circle(mpos, 3.0, Color(1.0, 1.0, 1.0, pulse))


func _rebuild_all_textures() -> void:
	_region_textures.clear()
	if _player == null:
		return
	for region_id: Vector2i in _player.fog_of_war.get_all_region_ids():
		_region_textures[region_id] = _build_region_texture(region_id)


func _build_region_texture(region_id: Vector2i) -> ImageTexture:
	var biome_color: Color = BIOME_COLOR_FALLBACK
	if WorldManager.plans.has(region_id):
		var plan: RegionPlan = WorldManager.plans[region_id]
		biome_color = BIOME_COLORS.get(plan.planned_biome, BIOME_COLOR_FALLBACK)
	var img: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var cell := Vector2i(x, y)
			if _player.fog_of_war.is_revealed(region_id, cell):
				img.set_pixel(x, y, biome_color)
			else:
				img.set_pixel(x, y, biome_color.lerp(Color(0.0, 0.0, 0.0, 1.0), 0.75))
	return ImageTexture.create_from_image(img)


func _compute_bbox() -> Rect2i:
	var ids: Array = _player.fog_of_war.get_all_region_ids()
	if ids.is_empty():
		return Rect2i()
	var min_x: int = (ids[0] as Vector2i).x
	var max_x: int = min_x
	var min_y: int = (ids[0] as Vector2i).y
	var max_y: int = min_y
	for rid: Vector2i in ids:
		min_x = mini(min_x, rid.x)
		max_x = maxi(max_x, rid.x)
		min_y = mini(min_y, rid.y)
		max_y = maxi(max_y, rid.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _compute_tile_px(bbox: Rect2i) -> float:
	var avail: float = minf(size.x, size.y) * 0.9
	var px_wide: float = avail / float(bbox.size.x * 128)
	var px_tall: float = avail / float(bbox.size.y * 128)
	return clampf(minf(px_wide, px_tall), 1.0, 6.0)


func _compute_map_origin(bbox: Rect2i, tile_px: float) -> Vector2:
	var total_w: float = float(bbox.size.x * 128) * tile_px
	var total_h: float = float(bbox.size.y * 128) * tile_px
	return Vector2(
		(size.x - total_w) * 0.5 - float(bbox.position.x * 128) * tile_px,
		(size.y - total_h) * 0.5 - float(bbox.position.y * 128) * tile_px
	)
```

- [ ] **Step 2: Refresh the class cache**

```bash
timeout 15 godot --headless --editor 2>/dev/null; true
```

- [ ] **Step 3: Run full test suite — must still pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -5
```
Expected: existing test count passes, no new failures.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/world_map_view.gd
git commit -m "feat(worldmap): WorldMapView Control with draw, animate, vignette"
```

---

## Task 4: PlayerController — fog reveal timer + worldmap toggle input

**Files:**
- Modify: `scripts/entities/player_controller.gd`

Three changes: add fields, add fog reveal Timer child, add `_unhandled_input`.

- [ ] **Step 1: Add fields after the existing `stats` block**

Find this block (around line 58):
```gdscript
var stats: Dictionary = {
	&"charisma": 3, &"wisdom": 3, &"strength": 3,
	&"speed": 0, &"defense": 0, &"dexterity": 0,
}
```

Add immediately after it (before the `get_stat` func or `active_effects` line):
```gdscript
var fog_of_war: FogOfWarData = FogOfWarData.new()
var world_map: WorldMapView = null
```

- [ ] **Step 2: Add the fog reveal Timer in `_ready()`**

Find the end of `_ready()` — the last line is:
```gdscript
	equipment.contents_changed.connect(_update_shield_sprite)
```

Add after it (still inside `_ready()`):
```gdscript
	var fog_timer := Timer.new()
	fog_timer.name = "FogRevealTimer"
	fog_timer.wait_time = 0.3
	fog_timer.autostart = true
	fog_timer.one_shot = false
	fog_timer.timeout.connect(_on_fog_reveal_timer_timeout)
	add_child(fog_timer)
```

- [ ] **Step 3: Add the timer callback and `_unhandled_input`**

Find this function (around line 315):
```gdscript
func _step(delta_pos: Vector2) -> void:
```

Insert before `_step` (as new top-level functions):
```gdscript
func _unhandled_input(event: InputEvent) -> void:
	var map_action: StringName = &"p1_worldmap" if player_id == 0 else &"p2_worldmap"
	if event.is_action_pressed(map_action) and world_map != null:
		world_map.toggle()
		get_viewport().set_input_as_handled()


func _on_fog_reveal_timer_timeout() -> void:
	if _world == null or _world._region == null:
		return
	fog_of_war.reveal(_world._region.region_id, _cell_of(position), 10)
	if world_map != null and world_map.visible:
		world_map.mark_dirty()


```

- [ ] **Step 4: Run full test suite — must still pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -5
```
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/entities/player_controller.gd
git commit -m "feat(player): fog reveal timer and worldmap toggle input"
```

---

## Task 5: game.gd — build and wire WorldMapView

**Files:**
- Modify: `scripts/main/game.gd`

Two changes: declare fields + `_build_worldmap_view()`, and wire in `_ready()` / `_wire_hud_and_cameras()`.

- [ ] **Step 1: Add fields**

Find this block in `game.gd`:
```gdscript
var _math_death: MathDeathScreen = null
```

Add after it:
```gdscript
var _map_p1: WorldMapView = null
var _map_p2: WorldMapView = null
```

- [ ] **Step 2: Build the maps in `_ready()`**

Find this block in `_ready()`:
```gdscript
	_math_death = MathDeathScreen.new()
	_math_death.name = "MathDeathScreen"
	_math_death.answered_correctly.connect(_on_math_answer_correct)
	add_child(_math_death)
	call_deferred("_wire_hud_and_cameras")
```

Add two lines before `call_deferred(...)`:
```gdscript
	_map_p1 = _build_worldmap_view(_container_p1)
	_map_p2 = _build_worldmap_view(_container_p2)
```

So the block becomes:
```gdscript
	_math_death = MathDeathScreen.new()
	_math_death.name = "MathDeathScreen"
	_math_death.answered_correctly.connect(_on_math_answer_correct)
	add_child(_math_death)
	_map_p1 = _build_worldmap_view(_container_p1)
	_map_p2 = _build_worldmap_view(_container_p2)
	call_deferred("_wire_hud_and_cameras")
```

- [ ] **Step 3: Wire players to their maps in `_wire_hud_and_cameras()`**

Find this block inside `_wire_hud_and_cameras()`:
```gdscript
		if _controls_p1 != null:
			_controls_p1.set_player(0, p1)
		_camera_p1 = _make_camera(p1, _vp_p1)
```

Add one line before `_camera_p1 = ...`:
```gdscript
		if _controls_p1 != null:
			_controls_p1.set_player(0, p1)
		if _map_p1 != null:
			_map_p1.set_player(p1)
			p1.world_map = _map_p1
		_camera_p1 = _make_camera(p1, _vp_p1)
```

Do the same for p2. Find:
```gdscript
		if _controls_p2 != null:
			_controls_p2.set_player(1, p2)
		_camera_p2 = _make_camera(p2, _vp_p2)
```

Add:
```gdscript
		if _controls_p2 != null:
			_controls_p2.set_player(1, p2)
		if _map_p2 != null:
			_map_p2.set_player(p2)
			p2.world_map = _map_p2
		_camera_p2 = _make_camera(p2, _vp_p2)
```

- [ ] **Step 4: Add `_build_worldmap_view()` helper**

Find the `_build_heart_display` function:
```gdscript
func _build_heart_display(container: Control) -> HeartDisplay:
```

Insert before it:
```gdscript
func _build_worldmap_view(container: Control) -> WorldMapView:
	var map := WorldMapView.new()
	map.name = "WorldMap"
	map.anchor_left = 0.0
	map.anchor_right = 1.0
	map.anchor_top = 0.0
	map.anchor_bottom = 1.0
	map.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(map)
	return map


```

- [ ] **Step 5: Run full test suite**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -5
```
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/main/game.gd
git commit -m "feat(game): build and wire WorldMapView per player"
```

---

## Task 6: Save / Load fog data

**Files:**
- Modify: `scripts/data/player_save_data.gd`
- Modify: `scripts/data/save_game.gd`
- Create: `tests/integration/test_worldmap_save.gd`

### Step 1 — Failing integration test

- [ ] **Step 1: Create `tests/integration/test_worldmap_save.gd`**

```gdscript
extends GutTest

func test_fog_survives_save_load_round_trip() -> void:
	# Arrange: set up WorldManager with a known seed and region.
	WorldManager.reset(202402)
	var region: Region = WorldManager.get_or_generate(Vector2i.ZERO)
	assert_not_null(region)

	# Arrange: create a player with some fog revealed.
	var player := PlayerController.new()
	player.player_id = 0
	add_child_autofree(player)
	player.fog_of_war.reveal(Vector2i.ZERO, Vector2i(20, 20), 5)
	assert_true(player.fog_of_war.is_revealed(Vector2i.ZERO, Vector2i(20, 20)))
	assert_false(player.fog_of_war.is_revealed(Vector2i.ZERO, Vector2i(0, 0)))

	# Act: snapshot to PlayerSaveData.
	var psd := PlayerSaveData.new()
	psd.fog_data = player.fog_of_war.to_dict()

	# Act: restore to a fresh player.
	var player2 := PlayerController.new()
	player2.player_id = 0
	add_child_autofree(player2)
	player2.fog_of_war.from_dict(psd.fog_data)

	# Assert: fog state is identical.
	assert_true(player2.fog_of_war.is_revealed(Vector2i.ZERO, Vector2i(20, 20)))
	assert_false(player2.fog_of_war.is_revealed(Vector2i.ZERO, Vector2i(0, 0)))
```

- [ ] **Step 2: Run test — expect failure (fog_data field doesn't exist yet)**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -ginclude_subdirs -gexit 2>&1 | grep -E "test_fog_survives|FAIL|ERROR"
```
Expected: error that `fog_data` is not a property of `PlayerSaveData`.

### Step 3 — Implement

- [ ] **Step 3: Add `fog_data` field to `PlayerSaveData`**

Find the last line:
```gdscript
@export var stats: Dictionary = {}
```

Add after it:
```gdscript
## Serialized FogOfWarData for this player. Keys are "x,y" region strings;
## values are PackedByteArray (2048 bytes per region).
@export var fog_data: Dictionary = {}
```

- [ ] **Step 4: Serialize fog in `SaveGame.snapshot()`**

In `save_game.gd`, inside the `for pid in 2:` loop in `snapshot()`, find:
```gdscript
			psd.stats = p.stats.duplicate()
			save.players.append(psd)
```

Add the fog line before `save.players.append(psd)`:
```gdscript
			psd.stats = p.stats.duplicate()
			psd.fog_data = p.fog_of_war.to_dict()
			save.players.append(psd)
```

- [ ] **Step 5: Restore fog in `SaveGame.apply()`**

In `save_game.gd`, inside the `for psd in players:` loop in `apply()`, find:
```gdscript
		if not psd.stats.is_empty():
			p.stats = psd.stats.duplicate()
```

Add after it:
```gdscript
		if not psd.fog_data.is_empty():
			p.fog_of_war.from_dict(psd.fog_data)
```

- [ ] **Step 6: Run full test suite — must all pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -5
```
Expected: all tests pass, including `test_fog_survives_save_load_round_trip`.

- [ ] **Step 7: Commit**

```bash
git add scripts/data/player_save_data.gd scripts/data/save_game.gd tests/integration/test_worldmap_save.gd
git commit -m "feat(save): persist fog-of-war data per player in SaveGame"
```

---

## Task 7: Smoke test

Manual validation. No automated test for visual rendering.

- [ ] **Step 1: Run the game**

```bash
./run.sh
```

- [ ] **Step 2: Verify fog reveal**

Walk around with Player 1. Press **Tab**. Expected:
- Map overlay opens with a smooth zoom-in animation from the viewport center.
- Visited tiles show the biome color (green for grass).
- Unvisited tiles are dark with a slight biome tint.
- A white pulsing dot marks the player position.
- Atmospheric vignette darkens the edges.

- [ ] **Step 3: Verify close**

Press **Tab** again. Expected: zoom-out animation, map disappears, gameplay resumes.

- [ ] **Step 4: Verify Player 2**

Move Player 2. Press **Numpad 6**. Expected: Player 2 sees their own map (different fog) in their viewport pane.

- [ ] **Step 5: Verify gameplay input blocked**

While map is open, movement keys should not move the player. Confirm via `InputContext` (MENU state prevents `_physics_process` from acting on input).

- [ ] **Step 6: Final commit**

```bash
git add .
git commit -m "feat(worldmap): worldmap atlas view complete — smoke tested"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** FogOfWarData ✓, WorldMapView draw ✓, biome colors ✓, open/close animation ✓, vignette ✓, input actions ✓, player marker pulse ✓, dungeon landmarks ✓, fog reveal timer ✓, save/load ✓
- [x] **No placeholders:** All tasks have complete code blocks
- [x] **Type consistency:** `FogOfWarData`, `WorldMapView`, `mark_dirty()`, `toggle()`, `set_player()` used consistently across all tasks
- [x] **KEY_KP_9 conflict documented:** Task 1 explicitly notes the conflict and uses KEY_KP_6
- [x] **`_cell_of` vs `_get_current_cell`:** Plan uses `_cell_of(position)` (correct name from line 330)
- [x] **`dungeon_entrances: Array` (not `.dungeon_entrance`):** WorldMapView iterates the array correctly
- [x] **`InputContext.Context.MENU` / `.GAMEPLAY`:** Correct enum path used throughout
