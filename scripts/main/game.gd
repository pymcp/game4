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


const _MathDeathScene: PackedScene = preload("res://scenes/ui/MathDeathScreen.tscn")
const _FloorConfirmMenuScene: PackedScene = preload("res://scenes/ui/FloorConfirmMenu.tscn")
const _CaravanMenuScene: PackedScene = preload("res://scenes/ui/CaravanMenu.tscn")

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
var _status_badges_p1: StatusBadges = null
var _status_badges_p2: StatusBadges = null
var _cooldown_p1: CooldownWidget = null
var _cooldown_p2: CooldownWidget = null
var _biome_label_p1: Label = null
var _biome_label_p2: Label = null
var _clock_label_p1: Label = null
var _clock_label_p2: Label = null
var _zone_label_p1: Label = null
var _zone_label_p2: Label = null
var _toast_label_p1: Label = null
var _toast_label_p2: Label = null
var _toast_tween_p1: Tween = null
var _toast_tween_p2: Tween = null
var _player_p1: PlayerController = null
var _player_p2: PlayerController = null
var _math_death: MathDeathScreen = null
var _dying_players: Dictionary = {}  ## Tracks pids currently in death countdown.
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
	_status_badges_p1 = _build_status_badges(_container_p1)
	_status_badges_p2 = _build_status_badges(_container_p2)
	_cooldown_p1 = _build_cooldown_widget(_container_p1)
	_cooldown_p2 = _build_cooldown_widget(_container_p2)
	_build_top_labels(_container_p1, 0)
	_build_top_labels(_container_p2, 1)
	_math_death = _MathDeathScene.instantiate() as MathDeathScreen
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
	_toast_label_p1 = _build_location_toast(_container_p1)
	_toast_label_p2 = _build_location_toast(_container_p2)
	MapManager.active_interior_changed.connect(_on_active_interior_changed_toast)
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
		_caravan_menu_p1.build_requested.connect(_world.start_house_placement)
		var caravan_p1: Caravan = _world.get_caravan(0)
		if caravan_p1 != null:
			caravan_p1.interacted.connect(
					func(_by: PlayerController): _caravan_menu_p1.open())
	# Wire caravan menu for P2.
	if _caravan_menu_p2 != null and p2 != null:
		_caravan_menu_p2.setup(p2, p2.caravan_data, _world)
		_caravan_menu_p2.swap_pet_requested.connect(_world.swap_active_pet)
		_caravan_menu_p2.build_requested.connect(_world.start_house_placement)
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
	var menu := _FloorConfirmMenuScene.instantiate() as FloorConfirmMenu
	menu.name = "FloorConfirmMenu"
	container.add_child(menu)
	return menu


func _build_caravan_menu(container: Control) -> CaravanMenu:
	var menu := _CaravanMenuScene.instantiate() as CaravanMenu
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
## May return null if the HUD has not been built yet. Callers must null-check.
func get_controls_hud(pid: int) -> ControlsHud:
	return _controls_p1 if pid == 0 else _controls_p2


## Opens the caravan menu for [param pid] if it is set up.
## Clears any active ControlsHud override hint before opening.
func open_caravan_menu(pid: int) -> void:
	var hud: ControlsHud = get_controls_hud(pid)
	if hud != null:
		hud.set_override_hint("")
	var menu: CaravanMenu = _caravan_menu_p1 if pid == 0 else _caravan_menu_p2
	if menu != null:
		menu.open()


func _build_heart_display(container: Control) -> HeartDisplay:
	var hd := HeartDisplay.new(47.0)
	hd.name = "HeartDisplay"
	hd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Wide rect whose RIGHT edge is 8px from hotbar. Hearts right-align inside.
	var bar_w: float = HotbarSlot.SLOT_SIZE * 8 + 4 * 7
	hd.anchor_left = 0.5
	hd.anchor_right = 0.5
	hd.anchor_top = 1.0
	hd.anchor_bottom = 1.0
	hd.offset_right = -bar_w * 0.5 - 8.0
	hd.offset_left = hd.offset_right - 400.0
	hd.offset_top = -HotbarSlot.SLOT_SIZE - 12.0
	hd.offset_bottom = -12.0
	container.add_child(hd)
	return hd


func _build_status_badges(container: Control) -> StatusBadges:
	var sb := StatusBadges.new()
	sb.name = "StatusBadges"
	sb.position = Vector2(8, 8)
	sb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(sb)
	return sb


func _build_cooldown_widget(container: Control) -> CooldownWidget:
	var cw := CooldownWidget.new()
	cw.name = "CooldownWidget"
	# Anchored beside the hotbar on the right — same bottom row.
	var bar_w: float = HotbarSlot.SLOT_SIZE * 8 + 4 * 7
	var widget_w: float = CooldownWidget._WIDGET_W
	cw.anchor_left = 0.5
	cw.anchor_right = 0.5
	cw.anchor_top = 1.0
	cw.anchor_bottom = 1.0
	cw.offset_left = bar_w * 0.5 + 8.0
	cw.offset_right = bar_w * 0.5 + 8.0 + widget_w
	cw.offset_top = -HotbarSlot.SLOT_SIZE - 12.0
	cw.offset_bottom = -12.0
	container.add_child(cw)
	return cw


## Build the centred location toast label for one player's container.
## The label starts invisible; _show_location_toast animates it.
func _build_location_toast(container: Control) -> Label:
	var lbl := Label.new()
	lbl.name = "LocationToast"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.anchor_left = 0.5
	lbl.anchor_right = 0.5
	lbl.anchor_top = 0.5
	lbl.anchor_bottom = 0.5
	lbl.offset_left = -200.0
	lbl.offset_right = 200.0
	lbl.offset_top = -60.0
	lbl.offset_bottom = -20.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	container.add_child(lbl)
	return lbl


## Animate the location toast for [param lbl], killing any running tween first.
func _show_location_toast(lbl: Label, tween_ref: Array, text: String) -> void:
	if lbl == null:
		return
	lbl.text = text
	if tween_ref[0] != null and (tween_ref[0] as Tween).is_valid():
		(tween_ref[0] as Tween).kill()
	lbl.modulate.a = 0.0
	var tw: Tween = create_tween()
	tween_ref[0] = tw
	tw.tween_property(lbl, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)


## Called when MapManager.active_interior_changed fires.
func _on_active_interior_changed_toast(interior: InteriorMap) -> void:
	if interior == null:
		return
	# Build toast text: prefer location_name, fall back to kind + floor.
	var name_text: String = interior.location_name
	if name_text == "":
		var map_str: String = String(interior.map_id)
		var at_idx: int = map_str.find("@")
		var kind_str: String = map_str.substr(0, at_idx) if at_idx >= 0 else "dungeon"
		name_text = kind_str.capitalize()
	var floor_suffix: String = " — Floor %d" % interior.floor_num
	var toast_text: String = name_text + floor_suffix
	var ref1: Array = [_toast_tween_p1]
	var ref2: Array = [_toast_tween_p2]
	_show_location_toast(_toast_label_p1, ref1, toast_text)
	_toast_tween_p1 = ref1[0]
	_show_location_toast(_toast_label_p2, ref2, toast_text)
	_toast_tween_p2 = ref2[0]


## Build the top-right info labels (biome, clock) and top-centre zone badge
## for one player's container. Stores refs in p1 or p2 member vars via [param pid].
func _build_top_labels(container: Control, pid: int) -> void:
	const MARGIN: float = 12.0
	# Zone badge — top-centre.
	var zone := Label.new()
	zone.name = "ZoneBadge"
	zone.add_theme_font_size_override("font_size", 15)
	zone.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	zone.add_theme_constant_override("outline_size", 2)
	zone.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	zone.anchor_left = 0.5
	zone.anchor_right = 0.5
	zone.offset_left = -150
	zone.offset_right = 150
	zone.offset_top = MARGIN
	zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.visible = false
	container.add_child(zone)
	# Biome label — top-right.
	var biome := Label.new()
	biome.name = "BiomeLabel"
	biome.add_theme_font_size_override("font_size", 13)
	biome.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	biome.anchor_left = 1.0
	biome.anchor_right = 1.0
	biome.offset_left = -160
	biome.offset_top = MARGIN
	biome.offset_right = -MARGIN
	biome.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	biome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(biome)
	# Clock label — below biome label.
	var clock := Label.new()
	clock.name = "ClockLabel"
	clock.add_theme_font_size_override("font_size", 13)
	clock.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	clock.anchor_left = 1.0
	clock.anchor_right = 1.0
	clock.offset_left = -160
	clock.offset_top = MARGIN + 18
	clock.offset_right = -MARGIN
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(clock)
	if pid == 0:
		_zone_label_p1 = zone
		_biome_label_p1 = biome
		_clock_label_p1 = clock
	else:
		_zone_label_p2 = zone
		_biome_label_p2 = biome
		_clock_label_p2 = clock


func _process(_delta: float) -> void:
	# Hearts.
	if _player_p1 != null and _hearts_p1 != null:
		_hearts_p1.update(_player_p1.health, _player_p1.max_health)
	if _player_p2 != null and _hearts_p2 != null:
		_hearts_p2.update(_player_p2.health, _player_p2.max_health)
	# Status badges.
	if _player_p1 != null and _status_badges_p1 != null:
		_status_badges_p1.set_effects(_player_p1.active_effects)
	if _player_p2 != null and _status_badges_p2 != null:
		_status_badges_p2.set_effects(_player_p2.active_effects)
	# Cooldown bars.
	if _player_p1 != null and _cooldown_p1 != null:
		_cooldown_p1.update_ratios(
				_player_p1.get_attack_cooldown_ratio(),
				_player_p1.get_dodge_cooldown_ratio())
	if _player_p2 != null and _cooldown_p2 != null:
		_cooldown_p2.update_ratios(
				_player_p2.get_attack_cooldown_ratio(),
				_player_p2.get_dodge_cooldown_ratio())
	# Active hotbar slot highlight.
	if _player_p1 != null and _hotbar_p1 != null:
		_hotbar_p1.set_active_slot(_player_p1.active_slot)
	if _player_p2 != null and _hotbar_p2 != null:
		_hotbar_p2.set_active_slot(_player_p2.active_slot)
	# Top-right labels (biome, clock, zone).
	_update_top_labels()


## Update top-right/top-centre labels each frame.
func _update_top_labels() -> void:
	# Clock (shared — same time for both players).
	var h: int = int(TimeManager.time_of_day)
	var m: int = int((TimeManager.time_of_day - h) * 60.0)
	var period: String = String(TimeManager.get_period()).capitalize()
	var clock_text: String = "%02d:%02d %s" % [h, m, period]
	if _clock_label_p1 != null:
		_clock_label_p1.text = clock_text
	if _clock_label_p2 != null:
		_clock_label_p2.text = clock_text
	# Biome (shared — same overworld region).
	var biome_text: String = ""
	if MapManager.active_interior == null:
		var reg: Region = WorldManager.active_region
		if reg != null:
			biome_text = "Biome: %s" % String(reg.biome).capitalize()
	if _biome_label_p1 != null:
		_biome_label_p1.text = biome_text
		_biome_label_p1.visible = biome_text != ""
	if _biome_label_p2 != null:
		_biome_label_p2.text = biome_text
		_biome_label_p2.visible = biome_text != ""
	# Zone badge — derived from active interior.
	var zone_text: String = ""
	if MapManager.active_interior != null:
		var map_id: String = String(MapManager.active_interior.map_id)
		var floor_n: int = MapManager.active_interior.floor_num
		if map_id.begins_with("labyrinth"):
			zone_text = "LABYRINTH F%d" % floor_n
		elif map_id.begins_with("house"):
			zone_text = "HOUSE"
		elif map_id.begins_with("city"):
			zone_text = "CITY"
		else:
			zone_text = "DUNGEON F%d" % floor_n
	if _zone_label_p1 != null:
		_zone_label_p1.text = zone_text
		_zone_label_p1.visible = zone_text != ""
	if _zone_label_p2 != null:
		_zone_label_p2.text = zone_text
		_zone_label_p2.visible = zone_text != ""


func _on_player_died(pid: int) -> void:
	if _dying_players.has(pid):
		return
	_dying_players[pid] = true
	var player: PlayerController = _player_p1 if pid == 0 else _player_p2
	if player != null:
		player.die()
	var container: Control = _container_p1 if pid == 0 else _container_p2
	var lbl: Label = _ensure_knockout_overlay(container)
	var overlay: ColorRect = lbl.get_parent() as ColorRect
	overlay.visible = true
	# Count down 5 → 1, then show math screen.
	var elapsed: float = 0.0
	var total: float = PlayerController._DEATH_WAIT_SEC
	while elapsed < total:
		if not is_instance_valid(lbl):
			return
		var remaining: int = ceili(total - elapsed)
		lbl.text = "Knocked out…\n%d" % remaining
		await get_tree().create_timer(0.2, false, false, true).timeout
		elapsed += 0.2
	if is_instance_valid(lbl):
		overlay.visible = false
	_dying_players.erase(pid)
	# Skip math screen if player was already revived.
	var check_player: PlayerController = _player_p1 if pid == 0 else _player_p2
	if check_player == null or not check_player.is_dead:
		return
	if _math_death != null:
		_math_death.show_for_player(pid)


func _on_math_answer_correct(pid: int) -> void:
	var player: PlayerController = _player_p1 if pid == 0 else _player_p2
	if player != null:
		player.respawn(player.max_health)


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


## Build or retrieve the per-player "knocked out" countdown overlay.
## Returns the Label node used for countdown text.
func _ensure_knockout_overlay(container: Control) -> Label:
	var existing: Node = container.get_node_or_null("KnockoutOverlay")
	if existing is ColorRect:
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
