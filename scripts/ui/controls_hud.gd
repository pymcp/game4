## ControlsHud
##
## Tiny per-player overlay listing the active actions and their key labels.
## Reads `InputContext.get_active_actions(player_id)` so the list updates
## with the player's current context (gameplay vs inventory vs menu).
##
## Pure cosmetics; intentionally Mouse-Filter ignored so it never steals
## input from the gameplay viewport.
extends PanelContainer
class_name ControlsHud

const _ACTION_LABELS: Dictionary = {
	&"up": "Up", &"down": "Down", &"left": "Left", &"right": "Right",
	&"interact": "Interact", &"attack": "Attack", &"back": "Drop",
	&"inventory": "Inventory",
	&"auto_mine": "Auto-Mine", &"auto_attack": "Auto-Attack",
	&"tab_prev": "Tab ◀", &"tab_next": "Tab ▶",
	&"dodge": "Dodge", &"block": "Block",
}

## Actions whose label gets highlighted when their toggle is active.
const _TOGGLE_ACTIONS: Array[StringName] = [&"auto_mine", &"auto_attack"]

var player_id: int = 0
var _label: RichTextLabel = null
var _player: PlayerController = null
var _override_hint: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.custom_minimum_size = Vector2(170, 0)
	_label.add_theme_font_size_override("normal_font_size", 14)
	_label.add_theme_font_size_override("bold_font_size", 14)
	_label.add_theme_color_override("default_color", Color(0.95, 0.92, 0.78))
	add_child(_label)
	# Subtle dark backdrop.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	add_theme_stylebox_override("panel", sb)
	InputContext.context_changed.connect(_on_context_changed)
	_refresh()


func set_player(pid: int, player: PlayerController = null) -> void:
	player_id = pid
	_player = player
	_refresh()


## When non-empty, display this text instead of the normal action list.
## Pass "" to revert to normal display.
func set_override_hint(text: String) -> void:
	_override_hint = text
	_refresh()


func _on_context_changed(pid: int, _ctx: InputContext.Context) -> void:
	if pid == player_id:
		_refresh()


func _process(_delta: float) -> void:
	# Cheap polling so toggle highlights update immediately.
	if _player != null:
		_refresh()


func _is_toggle_active(short_name: StringName) -> bool:
	if _player == null:
		return false
	if short_name == &"auto_mine":
		return _player.auto_mine
	if short_name == &"auto_attack":
		return _player.auto_attack
	return false


func _refresh() -> void:
	if _label == null:
		return
	if _override_hint != "":
		_label.text = _override_hint
		return
	var pfx := PlayerActions.prefix(player_id)
	var lines: Array[String] = ["P%d Controls" % (player_id + 1)]
	for action in InputContext.get_active_actions(player_id):
		var s: String = String(action)
		if s.begins_with(pfx):
			s = s.substr(pfx.length())
		var pretty: String = _ACTION_LABELS.get(StringName(s), s)
		var key_label: String = InputContext.get_key_label(action)
		var short: StringName = StringName(s)
		var is_pressed: bool = Input.is_action_pressed(action)
		if short in _TOGGLE_ACTIONS and _is_toggle_active(short):
			lines.append("[b][color=#5fff5f]%s — %s (ON)[/color][/b]" % [key_label, pretty])
		elif is_pressed:
			lines.append("[b][color=#ffe87c]%s — %s[/color][/b]" % [key_label, pretty])
		else:
			lines.append("%s — %s" % [key_label, pretty])
	_label.text = "\n".join(lines)
