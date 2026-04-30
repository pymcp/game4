## LevelUpPanel
## Shown inside InventoryScreen when the player has unspent stat points.
## Presents 6 stat buttons; pressing one calls player.spend_stat_point(stat).
extends PanelContainer
class_name LevelUpPanel

const _STAT_DESCS: Dictionary = {
	&"strength":  "Increases melee & tool damage",
	&"dexterity": "Speeds up attack rate",
	&"defense":   "Reduces damage taken",
	&"charisma":  "Unlocks better dialogue options",
	&"wisdom":    "Required for some quest paths",
	&"speed":     "Increases movement speed",
}

var _player: PlayerController = null
var _header: Label = null
var _buttons: Dictionary = {}  # StringName stat -> Button

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func setup(player: PlayerController) -> void:
	_player = player
	_rebuild()

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	_header = null

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(vb)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 16)
	_header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_header)

	var hint := Label.new()
	hint.text = "Choose one stat to improve:"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

	for stat: StringName in _STAT_DESCS.keys():
		var btn := Button.new()
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_buttons[stat] = btn
		vb.add_child(btn)
		var s: StringName = stat  # capture for closure
		btn.pressed.connect(func() -> void: _on_stat_chosen(s))

	_refresh()

func _refresh() -> void:
	if _player == null or _header == null:
		return
	_header.text = "Level %d — Choose a Stat" % _player.level
	for stat: StringName in _buttons.keys():
		var btn: Button = _buttons[stat]
		var val: int = _player.get_stat(stat)
		var desc: String = str(_STAT_DESCS.get(stat, ""))
		btn.text = "%s (%d) — %s" % [String(stat).capitalize(), val, desc]
		btn.disabled = (_player._pending_stat_points <= 0)

func _on_stat_chosen(stat: StringName) -> void:
	if _player == null:
		return
	_player.spend_stat_point(stat)
	if _player._pending_stat_points <= 0:
		visible = false
	else:
		_refresh()
