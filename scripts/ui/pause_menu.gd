## PauseMenu
##
## Full-window CanvasLayer that fades in/out on PauseManager.pause_state_changed.
## Buttons: Resume, Toggle P1, Toggle P2, Save (placeholder), Exit.
extends CanvasLayer
class_name PauseMenu

@onready var _panel: PanelContainer = $Center/Panel
@onready var _btn_resume: Button = $Center/Panel/Margin/VBox/Resume
@onready var _btn_toggle_p1: Button = $Center/Panel/Margin/VBox/ToggleP1
@onready var _btn_toggle_p2: Button = $Center/Panel/Margin/VBox/ToggleP2
@onready var _btn_save: Button = $Center/Panel/Margin/VBox/Save
@onready var _btn_exit: Button = $Center/Panel/Margin/VBox/Exit


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
	_refresh_player_labels()


func _on_pause_state_changed(is_paused: bool) -> void:
	visible = is_paused
	if is_paused:
		_btn_resume.grab_focus()


func _on_player_enabled_changed(_player_id: int, _is_enabled: bool) -> void:
	_refresh_player_labels()


func _refresh_player_labels() -> void:
	var p1_on := PauseManager.is_player_enabled(0)
	var p2_on := PauseManager.is_player_enabled(1)
	_btn_toggle_p1.text = "Disable Player 1" if p1_on else "Enable Player 1"
	_btn_toggle_p2.text = "Disable Player 2" if p2_on else "Enable Player 2"
	# Can't resume if every player is disabled — re-enable someone first.
	_btn_resume.disabled = not (p1_on or p2_on)


func _toggle_player(player_id: int) -> void:
	PauseManager.set_player_enabled(player_id, not PauseManager.is_player_enabled(player_id))


func _on_resume() -> void:
	PauseManager.set_paused(false)


func _on_save() -> void:
	# Phase 8 will implement persistence. For now, just log.
	push_warning("[PauseMenu] Save not yet implemented (Phase 8).")


func _on_exit() -> void:
	get_tree().quit()
