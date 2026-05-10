## MenuNavigator
##
## Reusable keyboard-cursor helper for button-list menus.
## Owns the cursor index and the highlighted-button visual state.
##
## Usage:
##   var _nav := MenuNavigator.new()
##
##   # In _ready():
##   _nav.setup([_btn_a, _btn_b, _btn_c])
##
##   # In _input():
##   if PlayerActions.either_just_pressed(event, PlayerActions.UP):
##       _nav.move(-1)
##       get_viewport().set_input_as_handled()
##   elif PlayerActions.either_just_pressed(event, PlayerActions.DOWN):
##       _nav.move(1)
##       get_viewport().set_input_as_handled()
##   elif PlayerActions.either_just_pressed(event, PlayerActions.INTERACT):
##       _nav.confirm()
##       get_viewport().set_input_as_handled()
class_name MenuNavigator
extends RefCounted

## Ordered list of navigable buttons.
var buttons: Array[Button] = []
## Current cursor position.
var cursor: int = 0


## Set the button list and reset the cursor to the first enabled entry.
func setup(btns: Array[Button]) -> void:
	buttons = btns
	cursor = 0
	skip_disabled(1)
	refresh()


## Move the cursor by [param direction] (+1 = down, -1 = up).
## Skips disabled buttons.
func move(direction: int) -> void:
	if buttons.is_empty():
		return
	cursor = wrapi(cursor + direction, 0, buttons.size())
	skip_disabled(direction)
	refresh()


## Emit [signal Button.pressed] on the button at the current cursor position.
func confirm() -> void:
	if cursor < buttons.size() and not buttons[cursor].disabled:
		buttons[cursor].pressed.emit()


## Reset the cursor to [param index] (default 0) and refresh highlights.
func reset(index: int = 0) -> void:
	cursor = clampi(index, 0, max(0, buttons.size() - 1))
	refresh()


## Advance [param direction] until landing on an enabled (non-disabled) button.
## Guards against infinite loops when all buttons are disabled.
func skip_disabled(direction: int) -> void:
	var n := buttons.size()
	if n == 0:
		return
	var tries := 0
	while tries < n and buttons[cursor].disabled:
		cursor = wrapi(cursor + direction, 0, n)
		tries += 1


## Apply yellow highlight to the selected button; clear all others.
func refresh() -> void:
	for i: int in buttons.size():
		var btn: Button = buttons[i]
		if i == cursor and not btn.disabled:
			btn.add_theme_color_override("font_color", UITheme.COL_CURSOR)
		else:
			btn.remove_theme_color_override("font_color")
