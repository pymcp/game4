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


func _ready() -> void:
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
	call_deferred("_wire_hud_and_cameras")


## Returns the active world *instance* for [param player_id]. Provided
## for API compatibility with the legacy two-WorldRoot layout; many
## tests still call [code]game.get_world(pid)[/code].
func get_world(player_id: int) -> WorldRoot:
	if _world == null:
		return null
	return _world.get_player_world(player_id)


func _on_player_enabled_changed(_player_id: int, _is_enabled: bool) -> void:
	_refresh_overlays()


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
	if p1 != null:
		if _hotbar_p1 != null:
			_hotbar_p1.set_inventory(p1.inventory)
		if _inv_p1 != null:
			_inv_p1.set_player(p1)
		_camera_p1 = _make_camera(p1, _vp_p1)
	if p2 != null:
		if _hotbar_p2 != null:
			_hotbar_p2.set_inventory(p2.inventory)
		if _inv_p2 != null:
			_inv_p2.set_player(p2)
		_camera_p2 = _make_camera(p2, _vp_p2)


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
	hud.offset_top = 8.0
	container.add_child(hud)
	return hud
