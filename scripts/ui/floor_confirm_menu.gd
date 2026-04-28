## FloorConfirmMenu
##
## Overlay prompt shown when a player steps on dungeon/labyrinth stairs
## or enters an interior entrance. Presents 2–3 labelled options; the
## player navigates with their movement keys (up/down) and confirms
## with interact. Only responds to the owning player's input bindings.
##
## Created by [Game] and parented to the appropriate player container so
## it lives in the correct pane. [InputContext] is set to MENU while
## visible, which freezes the owning player's movement.
extends Control
class_name FloorConfirmMenu

var _pid: int = 0
var _options: Array = []
var _cursor: int = 0
var _callback: Callable

@onready var _title_label: Label = $PanelWrap/VBox/Title
@onready var _opt0: Label = $PanelWrap/VBox/Option0
@onready var _opt1: Label = $PanelWrap/VBox/Option1
@onready var _opt2: Label = $PanelWrap/VBox/Option2

var _option_labels: Array[Label] = []

## Maximum number of options this menu can display.
const MAX_OPTIONS: int = 3


func _ready() -> void:
	visible = false
	_option_labels = [_opt0, _opt1, _opt2]


## Show the menu for [param pid] with [param title], [param options] and a
## [param callback] receiving the selected index (0-based).
func show_menu(pid: int, title: String, options: Array,
		callback: Callable) -> void:
	_pid = pid
	_options = options
	_cursor = 0
	_callback = callback
	_title_label.text = title
	for i in _option_labels.size():
		if i < options.size():
			_option_labels[i].visible = true
		else:
			_option_labels[i].visible = false
	_update_cursor()
	visible = true
	InputContext.set_context(pid, InputContext.Context.MENU)


func _update_cursor() -> void:
	for i in _option_labels.size():
		if i >= _options.size():
			break
		var lbl: Label = _option_labels[i]
		if i == _cursor:
			lbl.text = "> %s" % _options[i]
			lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.2))
		else:
			lbl.text = "  %s" % _options[i]
			lbl.add_theme_color_override("font_color", Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(PlayerActions.action(_pid, PlayerActions.UP)):
		_cursor = (_cursor - 1 + _options.size()) % _options.size()
		_update_cursor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(PlayerActions.action(_pid, PlayerActions.DOWN)):
		_cursor = (_cursor + 1) % _options.size()
		_update_cursor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(PlayerActions.action(_pid, PlayerActions.INTERACT)):
		_confirm()
		get_viewport().set_input_as_handled()


func _confirm() -> void:
	var selected: int = _cursor
	visible = false
	InputContext.set_context(_pid, InputContext.Context.GAMEPLAY)
	_callback.call(selected)
