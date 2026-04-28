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

var _title_label: Label = null
var _option_labels: Array[Label] = []

## Maximum number of options this menu can display.
const MAX_OPTIONS: int = 3


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	visible = false
	_build_ui()


func _build_ui() -> void:
	# Dim background.
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Centred panel — 80 % wide, vertically centred.
	var panel_wrap := Control.new()
	panel_wrap.name = "PanelWrap"
	panel_wrap.anchor_left = 0.1
	panel_wrap.anchor_right = 0.9
	panel_wrap.anchor_top = 0.28
	panel_wrap.anchor_bottom = 0.72
	panel_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_wrap)

	var panel_bg := ColorRect.new()
	panel_bg.name = "PanelBg"
	panel_bg.color = Color(0.06, 0.06, 0.10, 0.92)
	panel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_wrap.add_child(panel_bg)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12.0
	vbox.offset_right = -12.0
	vbox.offset_top = 10.0
	vbox.offset_bottom = -10.0
	vbox.add_theme_constant_override("separation", 10)
	panel_wrap.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_title_label.add_theme_constant_override("outline_size", 1)
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	for _i in MAX_OPTIONS:
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.visible = false
		vbox.add_child(lbl)
		_option_labels.append(lbl)

	var hint := Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.text = "↑↓ Move   Interact / E Confirm"
	vbox.add_child(hint)


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
