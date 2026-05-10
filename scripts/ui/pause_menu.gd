## PauseMenu
##
## Full-window CanvasLayer shown when PauseManager.pause_state_changed fires.
## Keyboard-navigable by either player using their UP/DOWN/INTERACT/BACK keys.
## A yellow highlight tracks the selected button.
extends CanvasLayer
class_name PauseMenu

@onready var _panel: PanelContainer = $Center/Panel
@onready var _btn_resume:    Button = $Center/Panel/Margin/VBox/Resume
@onready var _btn_toggle_p1: Button = $Center/Panel/Margin/VBox/ToggleP1
@onready var _btn_toggle_p2: Button = $Center/Panel/Margin/VBox/ToggleP2
@onready var _btn_save:      Button = $Center/Panel/Margin/VBox/Save
@onready var _btn_exit:      Button = $Center/Panel/Margin/VBox/Exit

## Ordered list of navigable buttons.
var _nav: MenuNavigator = MenuNavigator.new()


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
	# Disable Godot built-in focus traversal — we manage cursor ourselves.
	for btn: Button in [_btn_resume, _btn_toggle_p1, _btn_toggle_p2, _btn_save, _btn_exit]:
		btn.focus_mode = Control.FOCUS_NONE
	_nav.setup([_btn_resume, _btn_toggle_p1, _btn_toggle_p2, _btn_save, _btn_exit])
	_refresh_player_labels()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if PlayerActions.either_just_pressed(event, PlayerActions.UP):
		_nav.move(-1)
		get_viewport().set_input_as_handled()
	elif PlayerActions.either_just_pressed(event, PlayerActions.DOWN):
		_nav.move(1)
		get_viewport().set_input_as_handled()
	elif PlayerActions.either_just_pressed(event, PlayerActions.INTERACT):
		_nav.confirm()
		get_viewport().set_input_as_handled()
	elif PlayerActions.either_just_pressed(event, PlayerActions.BACK):
		_on_resume()
		get_viewport().set_input_as_handled()


func _on_pause_state_changed(is_paused: bool) -> void:
	visible = is_paused
	if is_paused:
		_nav.reset()


func _on_player_enabled_changed(_player_id: int, _is_enabled: bool) -> void:
	_refresh_player_labels()
	_nav.skip_disabled(1)
	_nav.refresh()


func _refresh_player_labels() -> void:
	var p1_on := PauseManager.is_player_enabled(0)
	var p2_on := PauseManager.is_player_enabled(1)
	_btn_toggle_p1.text = "Disable Player 1" if p1_on else "Enable Player 1"
	_btn_toggle_p2.text = "Disable Player 2" if p2_on else "Enable Player 2"
	_btn_resume.disabled = not (p1_on or p2_on)


func _toggle_player(player_id: int) -> void:
	PauseManager.set_player_enabled(player_id, not PauseManager.is_player_enabled(player_id))


func _on_resume() -> void:
	PauseManager.set_paused(false)


func _on_save() -> void:
	push_warning("[PauseMenu] Save not yet implemented (Phase 8).")


func _on_exit() -> void:
	get_tree().quit()
