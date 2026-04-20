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
	&"interact": "Interact", &"attack": "Attack", &"inventory": "Inventory",
	&"auto_mine": "Auto-Mine", &"auto_attack": "Auto-Attack",
	&"tab_prev": "Tab ◀", &"tab_next": "Tab ▶",
}

var player_id: int = 0
var _label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 2)
	add_child(_label)
	# Subtle dark backdrop.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	add_theme_stylebox_override("panel", sb)
	InputContext.context_changed.connect(_on_context_changed)
	_refresh()


func set_player(pid: int) -> void:
	player_id = pid
	_refresh()


func _on_context_changed(pid: int, _ctx: InputContext.Context) -> void:
	if pid == player_id:
		_refresh()


func _refresh() -> void:
	if _label == null:
		return
	var prefix := "p%d_" % (player_id + 1)
	var lines: Array[String] = ["P%d Controls" % (player_id + 1)]
	for action in InputContext.get_active_actions(player_id):
		var s: String = String(action)
		if s.begins_with(prefix):
			s = s.substr(prefix.length())
		var pretty: String = _ACTION_LABELS.get(StringName(s), s)
		lines.append("%s — %s" % [InputContext.get_key_label(action), pretty])
	_label.text = "\n".join(lines)
