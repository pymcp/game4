## Game
##
## Split-screen scene root. Hosts two SubViewports that share a single
## [code]world_2d[/code] sampled from the [World] coordinator instance.
## Each viewport gets its own [Camera2D] that follows the corresponding
## player; cameras are pinned to a viewport via [code]custom_viewport[/code]
## so a single shared world tree renders correctly to both panes.
##
## Per-player UI (HUD, inventory, controls) is wired to whichever player
## the [World] coordinator owns for that pid.
extends Node
class_name Game


## Singleton-style accessor — returns the active [Game] from the scene tree.
static func instance() -> Game:
	var t: SceneTree = Engine.get_main_loop() as SceneTree
	if t == null:
		return null
	return t.get_first_node_in_group(&"game") as Game


@onready var _vp_p1: SubViewport = $Split/P1Container/P1ViewportContainer/P1Viewport
@onready var _vp_p2: SubViewport = $Split/P2Container/P2ViewportContainer/P2Viewport
@onready var _container_p1: Control = $Split/P1Container
@onready var _container_p2: Control = $Split/P2Container
@onready var _disabled_overlay_p1: Control = $Split/P1Container/Overlay
@onready var _disabled_overlay_p2: Control = $Split/P2Container/Overlay

var _world: World = null
var _camera_p1: Camera2D = null
var _camera_p2: Camera2D = null
var _hotbar_p1: Hotbar = null
var _hotbar_p2: Hotbar = null
var _inv_p1: InventoryScreen = null
var _inv_p2: InventoryScreen = null
var _controls_p1: ControlsHud = null
var _controls_p2: ControlsHud = null
var _hearts_p1: HeartDisplay = null
var _hearts_p2: HeartDisplay = null
var _player_p1: PlayerController = null
var _player_p2: PlayerController = null
var _math_death: MathDeathScreen = null
var _map_p1: WorldMapView = null
var _map_p2: WorldMapView = null
var _dungeon_map_p1: DungeonMapView = null
var _dungeon_map_p2: DungeonMapView = null
var _confirm_menu_p1: FloorConfirmMenu = null
var _confirm_menu_p2: FloorConfirmMenu = null
var _caravan_menu_p1: CaravanMenu = null
var _caravan_menu_p2: CaravanMenu = null


func _ready() -> void:
	add_to_group(&"game")
	# Spawn the ONE shared world under P1's viewport.
	_world = World.new()
	_world.name = "World"
	_vp_p1.add_child(_world)
	# P2 samples the same scene tree by sharing world_2d.
	_vp_p2.world_2d = _vp_p1.world_2d

	PauseManager.player_enabled_changed.connect(_on_player_enabled_changed)
	_refresh_overlays()
	_hotbar_p1 = _build_hotbar(_container_p1)
	_hotbar_p2 = _build_hotbar(_container_p2)
	_inv_p1 = _build_inventory_screen(_container_p1)
	_inv_p2 = _build_inventory_screen(_container_p2)
	_controls_p1 = _build_controls_hud(_container_p1, 0)
	_controls_p2 = _build_controls_hud(_container_p2, 1)
	_hearts_p1 = _build_heart_display(_container_p1)
	_hearts_p2 = _build_heart_display(_container_p2)
	_math_death = load("res://scenes/ui/MathDeathScreen.tscn").instantiate() as MathDeathScreen
	_math_death.name = "MathDeathScreen"
	_math_death.answered_correctly.connect(_on_math_answer_correct)
	add_child(_math_death)
	_map_p1 = _build_worldmap_view(_container_p1)
	_map_p2 = _build_worldmap_view(_container_p2)
	_dungeon_map_p1 = _build_dungeon_map_view(_container_p1)
	_dungeon_map_p2 = _build_dungeon_map_view(_container_p2)
	_confirm_menu_p1 = _build_floor_confirm_menu(_container_p1)
	_confirm_menu_p2 = _build_floor_confirm_menu(_container_p2)
	_caravan_menu_p1 = _build_caravan_menu(_container_p1)
	_caravan_menu_p2 = _build_caravan_menu(_container_p2)
	call_deferred("_wire_hud_and_cameras")


## Returns the active world *instance* for [param player_id]. Provided
## for API compatibility with the legacy two-WorldRoot layout; many
## tests still call [code]game.get_world(pid)[/code].
func get_world(player_id: int) -> WorldRoot:
	if _world == null:
		return null
	return _world.get_player_world(player_id)


func _on_player_enabled_changed(player_id: int, is_enabled: bool) -> void:
	_refresh_overlays()
	# Hide/show the actual player entity in the shared world.
	var player: PlayerController = _player_p1 if player_id == 0 else _player_p2
	if player != null:
		_set_player_world_active(player, is_enabled)


func _set_player_world_active(player: PlayerController, active: bool) -> void:
	player.visible = active
	player.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	# Also hide/disable any pet belonging to this player.
	var wr: WorldRoot = _world.get_player_world(player.player_id) if _world else null
	if wr != null and wr.entities != null:
		for child in wr.entities.get_children():
			if child is Pet and (child as Pet).owner_player == player:
				child.visible = active
				child.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _refresh_overlays() -> void:
	var p1_on: bool = PauseManager.is_player_enabled(0)
	var p2_on: bool = PauseManager.is_player_enabled(1)
	_container_p1.visible = p1_on
	_container_p2.visible = p2_on
	_disabled_overlay_p1.visible = not p1_on
	_disabled_overlay_p2.visible = not p2_on


# --- Hotbar wiring (P10) -----------------------------------------

func _build_hotbar(container: Control) -> Hotbar:
	var hb := Hotbar.new()
	hb.name = "Hotbar"
	hb.visible_slots = 8
	hb.anchor_left = 0.5
	hb.anchor_right = 0.5
	hb.anchor_top = 1.0
	hb.anchor_bottom = 1.0
	var bar_w: float = HotbarSlot.SLOT_SIZE * 8 + 4 * 7
	hb.offset_left = -bar_w * 0.5
	hb.offset_right = bar_w * 0.5
	hb.offset_top = -HotbarSlot.SLOT_SIZE - 12.0
	hb.offset_bottom = -12.0
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 4)
	hb.add_child(row)
	container.add_child(hb)
	return hb


func _wire_hud_and_cameras() -> void:
	if _world == null:
		return
	var p1: PlayerController = _world.get_player(0)
	var p2: PlayerController = _world.get_player(1)
	_player_p1 = p1
	_player_p2 = p2
	if p1 != null:
		p1.apply_appearance(GameSession.get_appearance(0))
		p1.player_died.connect(_on_player_died)
		if _hotbar_p1 != null:
			_hotbar_p1.set_inventory(p1.inventory)
		if _inv_p1 != null:
			_inv_p1.set_player(p1)
		if _controls_p1 != null:
			_controls_p1.set_player(0, p1)
		if _map_p1 != null:
			_map_p1.set_player(p1)
			p1.world_map = _map_p1
		if _dungeon_map_p1 != null:
			_dungeon_map_p1.set_player(p1)
			p1.dungeon_map = _dungeon_map_p1
		_camera_p1 = _make_camera(p1, _vp_p1)
	if p2 != null:
		p2.apply_appearance(GameSession.get_appearance(1))
		p2.player_died.connect(_on_player_died)
		if _hotbar_p2 != null:
			_hotbar_p2.set_inventory(p2.inventory)
		if _inv_p2 != null:
			_inv_p2.set_player(p2)
		if _controls_p2 != null:
			_controls_p2.set_player(1, p2)
		if _map_p2 != null:
			_map_p2.set_player(p2)
			p2.world_map = _map_p2
		if _dungeon_map_p2 != null:
			_dungeon_map_p2.set_player(p2)
			p2.dungeon_map = _dungeon_map_p2
		_camera_p2 = _make_camera(p2, _vp_p2)
	# Wire caravan menu for P1.
	if _caravan_menu_p1 != null and p1 != null:
		_caravan_menu_p1.setup(p1, p1.caravan_data, _world)
		_caravan_menu_p1.swap_pet_requested.connect(_world.swap_active_pet)
		var caravan_p1: Caravan = _world.get_caravan(0)
		if caravan_p1 != null:
			caravan_p1.interacted.connect(
					func(_by: PlayerController): _caravan_menu_p1.open())
	# Wire caravan menu for P2.
	if _caravan_menu_p2 != null and p2 != null:
		_caravan_menu_p2.setup(p2, p2.caravan_data, _world)
		_caravan_menu_p2.swap_pet_requested.connect(_world.swap_active_pet)
		var caravan_p2: Caravan = _world.get_caravan(1)
		if caravan_p2 != null:
			caravan_p2.interacted.connect(
					func(_by: PlayerController): _caravan_menu_p2.open())
	# Apply the enabled state that was set before this scene loaded.
	# The PauseManager signal fired before game.gd existed, so any player
	# that was disabled at startup needs to be hidden/frozen now.
	if p1 != null and not PauseManager.is_player_enabled(0):
		_set_player_world_active(p1, false)
	if p2 != null and not PauseManager.is_player_enabled(1):
		_set_player_world_active(p2, false)


## Creates a [Camera2D] parented to [param player] but pinned (via
## [code]custom_viewport[/code]) to render into [param viewport]. This
## lets the shared world render twice — once per pane — with each pane
## centred on its respective player.
func _make_camera(player: PlayerController, viewport: SubViewport) -> Camera2D:
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.custom_viewport = viewport
	cam.zoom = Vector2.ONE
	cam.position_smoothing_enabled = false
	player.add_child(cam)
	cam.make_current()
	return cam


func _build_inventory_screen(container: Control) -> InventoryScreen:
	var inv := InventoryScreen.new()
	inv.name = "InventoryScreen"
	container.add_child(inv)
	return inv


func _build_controls_hud(container: Control, pid: int) -> ControlsHud:
	var hud := ControlsHud.new()
	hud.name = "ControlsHud"
	hud.player_id = pid
	hud.anchor_left = 0.0
	hud.anchor_top = 0.0
	hud.offset_left = 8.0
	hud.offset_top = 36.0
	container.add_child(hud)
	return hud


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


func _build_dungeon_map_view(container: Control) -> DungeonMapView:
	var map := DungeonMapView.new()
	map.name = "DungeonMap"
	map.anchor_left = 0.0
	map.anchor_right = 1.0
	map.anchor_top = 0.0
	map.anchor_bottom = 1.0
	map.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(map)
	return map


func _build_floor_confirm_menu(container: Control) -> FloorConfirmMenu:
	var scene := load("res://scenes/ui/FloorConfirmMenu.tscn") as PackedScene
	var menu := scene.instantiate() as FloorConfirmMenu
	menu.name = "FloorConfirmMenu"
	container.add_child(menu)
	return menu


func _build_caravan_menu(container: Control) -> CaravanMenu:
	var scene := load("res://scenes/ui/CaravanMenu.tscn") as PackedScene
	var menu := scene.instantiate() as CaravanMenu
	menu.name = "CaravanMenu"
	container.add_child(menu)
	return menu


## Show a [FloorConfirmMenu] in [param pid]'s pane with [param title],
## [param options] (Array[String]), and [param callback] receiving the
## chosen index (0-based). Called by [WorldRoot] on stair/entrance events.
func show_floor_confirm_menu(pid: int, title: String, options: Array,
		callback: Callable) -> void:
	var menu: FloorConfirmMenu = _confirm_menu_p1 if pid == 0 else _confirm_menu_p2
	if menu != null:
		menu.show_menu(pid, title, options, callback)


## Returns the ControlsHud for [param pid] (0 = P1, 1 = P2).
func get_controls_hud(pid: int) -> ControlsHud:
	return _controls_p1 if pid == 0 else _controls_p2


## Opens the caravan menu for [param pid] if it is set up.
func open_caravan_menu(pid: int) -> void:
	var menu: CaravanMenu = _caravan_menu_p1 if pid == 0 else _caravan_menu_p2
	if menu != null:
		menu.open()


func _build_heart_display(container: Control) -> HeartDisplay:
	var hd := HeartDisplay.new(12.0)
	hd.name = "HeartDisplay"
	hd.position = Vector2(8, 8)
	hd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(hd)
	return hd


func _process(_delta: float) -> void:
	if _player_p1 != null and _hearts_p1 != null:
		_hearts_p1.update(_player_p1.health, _player_p1.max_health)
	if _player_p2 != null and _hearts_p2 != null:
		_hearts_p2.update(_player_p2.health, _player_p2.max_health)


func _on_player_died(pid: int) -> void:
	get_tree().paused = true
	if _math_death != null:
		_math_death.show_for_player(pid)


func _on_math_answer_correct(pid: int) -> void:
	var player: PlayerController = _player_p1 if pid == 0 else _player_p2
	if player != null:
		player.health = player.max_health
	get_tree().paused = false


# --- Floor transition overlay ----------------------------------------

## Plays a fade-to-black transition in [param pid]'s viewport pane.
## If [param floor_label] is non-empty, a centred label is shown while
## fully faded. [param switch_fn] is invoked at peak darkness (the
## point where the world actually swaps underneath the screen).
func play_floor_transition(pid: int, floor_label: String,
		switch_fn: Callable) -> void:
	var container: Control = _container_p1 if pid == 0 else _container_p2
	var overlay: Control = _ensure_floor_overlay(container)
	var fade_rect: ColorRect = overlay.get_node("Fade") as ColorRect
	var label: Label = overlay.get_node("FloorLabel") as Label
	fade_rect.color.a = 0.0
	label.text = floor_label
	label.visible = false
	overlay.visible = true
	var t_in := create_tween()
	t_in.tween_property(fade_rect, "color:a", 1.0, 0.18)
	await t_in.finished
	if floor_label != "":
		label.visible = true
		await get_tree().create_timer(0.45).timeout
	else:
		await get_tree().create_timer(0.05).timeout
	switch_fn.call()
	var t_out := create_tween()
	t_out.tween_property(fade_rect, "color:a", 0.0, 0.28)
	await t_out.finished
	label.visible = false
	overlay.visible = false


func _ensure_floor_overlay(container: Control) -> Control:
	var existing: Node = container.get_node_or_null("FloorOverlay")
	if existing is Control:
		return existing as Control
	var overlay := Control.new()
	overlay.name = "FloorOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 90
	overlay.visible = false
	var fade := ColorRect.new()
	fade.name = "Fade"
	fade.color = Color(0.0, 0.0, 0.0, 0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(fade)
	var label := Label.new()
	label.name = "FloorLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.visible = false
	overlay.add_child(label)
	container.add_child(overlay)
	return overlay
