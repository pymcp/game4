## DialogueBox
##
## Per-viewport dialogue panel anchored to the bottom of one player's
## SubViewport. Supports two modes:
##   1. **One-liner** — `show_line(speaker, body)` for backward compat.
##   2. **Branching** — `show_node(node, player_stats)` renders NPC text
##      plus a numbered choice list. Player selects with 1-9 or arrows+E.
##
## Emits [signal choice_selected] when the player picks a choice, and
## [signal dismissed] when the conversation ends (leaf node or manual close).
extends CanvasLayer
class_name DialogueBox

const _MARGIN_PX: int = 12
const _HOTBAR_CLEARANCE_PX: int = 72

## Emitted when the player selects a [DialogueChoice].
## `passed` is true when any stat check succeeded (or no check).
signal choice_selected(choice: DialogueChoice, passed: bool)

## Emitted when the dialogue closes (leaf dismiss or hide_line).
signal dismissed

var _panel: PanelContainer = null
var _vbox: VBoxContainer = null
var _speaker_label: Label = null
var _body_label: Label = null
var _choices_vbox: VBoxContainer = null
var _hint_label: Label = null
var _open: bool = false

## Currently displayed choices (filtered, in display order).
var _visible_choices: Array = []  # Array[DialogueChoice]
## Player stats dict handed in via show_node (for stat-check colouring).
var _player_stats: Dictionary = {}
## Index of the highlighted choice (keyboard navigation). -1 = none.
var _selected_idx: int = -1
## player_id that owns this box (for reading the right input actions).
var player_id: int = 0

const _COLOR_NORMAL := Color(1.0, 1.0, 1.0)
const _COLOR_DIFFICULT := Color(1.0, 0.55, 0.55)  # soft red
const _COLOR_HIGHLIGHT_BG := Color(0.25, 0.25, 0.35)
const _COLOR_SPEAKER := Color(1.0, 0.92, 0.6)  # gold
const _COLOR_HINT := Color(0.7, 0.7, 0.7)


func _ready() -> void:
	layer = 40
	_build()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = _MARGIN_PX
	_panel.offset_right = -_MARGIN_PX
	_panel.offset_bottom = -_HOTBAR_CLEARANCE_PX
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(_vbox)

	_speaker_label = Label.new()
	_speaker_label.name = "Speaker"
	_speaker_label.add_theme_font_size_override("font_size", 18)
	_speaker_label.add_theme_color_override("font_color", _COLOR_SPEAKER)
	_vbox.add_child(_speaker_label)

	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_vbox.add_child(_body_label)

	_choices_vbox = VBoxContainer.new()
	_choices_vbox.name = "Choices"
	_choices_vbox.add_theme_constant_override("separation", 2)
	_vbox.add_child(_choices_vbox)

	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.text = "[E] close"
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", _COLOR_HINT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_vbox.add_child(_hint_label)

	_panel.visible = false


# ─── One-liner API (backward compat) ──────────────────────────────────

func show_line(speaker: String, body: String) -> void:
	if _speaker_label == null:
		return
	_speaker_label.text = speaker
	_body_label.text = body
	_clear_choices()
	_hint_label.text = "[E] close"
	_hint_label.visible = true
	_resize_panel()
	_panel.visible = true
	_open = true


func hide_line() -> void:
	if _panel != null:
		_panel.visible = false
	_open = false
	dismissed.emit()


func is_open() -> bool:
	return _open


# ─── Branching dialogue API ───────────────────────────────────────────

## Display a [DialogueNode] with its choices. `stats` is the player's
## stat dict (e.g. `{ &"charisma": 3 }`) used to colour stat-gated choices.
func show_node(node: DialogueNode, stats: Dictionary = {}) -> void:
	if _speaker_label == null:
		return
	_player_stats = stats
	_speaker_label.text = node.speaker
	_body_label.text = node.text
	_build_choices(node.choices)

	if _visible_choices.is_empty():
		_hint_label.text = "[E] close"
		_hint_label.visible = true
	else:
		_hint_label.text = "[1-%d] or [↑↓ + E] select" % _visible_choices.size()
		_hint_label.visible = true
		_selected_idx = 0
		_highlight(_selected_idx)

	_resize_panel()
	_panel.visible = true
	_open = true


# ─── Input handling ────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if _visible_choices.size() > 0:
		if event.is_action_pressed(PlayerActions.action(player_id, PlayerActions.UP)):
			_selected_idx = max(0, _selected_idx - 1)
			_highlight(_selected_idx)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(PlayerActions.action(player_id, PlayerActions.DOWN)):
			_selected_idx = min(_visible_choices.size() - 1, _selected_idx + 1)
			_highlight(_selected_idx)
			get_viewport().set_input_as_handled()
			return


# ─── Internal helpers ──────────────────────────────────────────────────

func _clear_choices() -> void:
	for c in _choices_vbox.get_children():
		c.queue_free()
	_visible_choices.clear()
	_selected_idx = -1


func _build_choices(raw_choices: Array) -> void:
	_clear_choices()
	var idx: int = 0
	for res in raw_choices:
		var choice: DialogueChoice = res as DialogueChoice
		if choice == null:
			continue
		# Flag gating: skip choices whose required flag isn't set.
		if choice.require_flag != "" and not GameState.get_flag(choice.require_flag):
			continue
		_visible_choices.append(choice)
		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 14)
		# Build display text: "1. [Charisma 5] Convince her"
		var prefix: String = "%d. " % (idx + 1)
		var stat_tag: String = ""
		var meets_check: bool = true
		if choice.stat_check != &"":
			var val: int = int(_player_stats.get(choice.stat_check, 0))
			meets_check = val >= choice.stat_threshold
			if meets_check:
				stat_tag = "[%s %d] " % [choice.stat_check.capitalize(), choice.stat_threshold]
			else:
				stat_tag = "[Difficult — %s %d] " % [choice.stat_check.capitalize(), choice.stat_threshold]
		lbl.text = prefix + stat_tag + choice.label
		lbl.add_theme_color_override("font_color",
			_COLOR_NORMAL if meets_check else _COLOR_DIFFICULT)
		_choices_vbox.add_child(lbl)
		idx += 1


func _highlight(idx: int) -> void:
	for i in _choices_vbox.get_child_count():
		var lbl: Label = _choices_vbox.get_child(i) as Label
		if lbl == null:
			continue
		# Strip existing marker first (exact prefix, not char set).
		var raw: String = lbl.text.substr(2) if lbl.text.begins_with("▸ ") else lbl.text
		if i == idx:
			lbl.add_theme_constant_override("outline_size", 1)
			lbl.text = "▸ " + raw
		else:
			lbl.add_theme_constant_override("outline_size", 0)
			lbl.text = raw


## True when the player has a choice highlighted and can confirm it.
func has_selected_choice() -> bool:
	return _visible_choices.size() > 0 and _selected_idx >= 0


## Confirm the currently highlighted choice (public entry point for E key).
func confirm_selected_choice() -> void:
	_pick_choice(_selected_idx)


func _pick_choice(idx: int) -> void:
	if idx < 0 or idx >= _visible_choices.size():
		return
	var choice: DialogueChoice = _visible_choices[idx]
	# Stat check
	var passed: bool = true
	if choice.stat_check != &"":
		var val: int = int(_player_stats.get(choice.stat_check, 0))
		passed = val >= choice.stat_threshold
	# Set flag if configured
	if choice.set_flag != "":
		GameState.set_flag(choice.set_flag)
	choice_selected.emit(choice, passed)


func _resize_panel() -> void:
	# Let the VBox dictate the height; just ensure minimum clearance.
	_panel.offset_top = -_HOTBAR_CLEARANCE_PX - 400  # generous max
	# The PanelContainer will shrink-wrap to content via size flags.
	_panel.size_flags_vertical = Control.SIZE_SHRINK_END

