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

@onready var _outer: VBoxContainer = $Outer
@onready var _panel: PanelContainer = $Outer/Panel
@onready var _portrait_rect: TextureRect = $Outer/Portrait
@onready var _speaker_label: Label = $Outer/Panel/VBox/Speaker
@onready var _body_label: Label = $Outer/Panel/VBox/Body
@onready var _choices_vbox: VBoxContainer = $Outer/Panel/VBox/Choices
@onready var _hint_label: Label = $Outer/Panel/VBox/Hint
@onready var _feedback_btn: Button = $Outer/Panel/FeedbackButton
@onready var _feedback_overlay: PanelContainer = $Outer/FeedbackOverlay
@onready var _feedback_input: TextEdit = $Outer/FeedbackOverlay/Margin/VBox/FeedbackInput

var _open: bool = false
## True while the feedback overlay is visible (pauses the game tree).
var _feedback_open: bool = false

## Currently displayed choices (filtered, in display order).
var _visible_choices: Array = []  # Array[DialogueChoice]
## Player stats dict handed in via show_node (for stat-check colouring).
var _player_stats: Dictionary = {}
## Index of the highlighted choice (keyboard navigation). -1 = none.
var _selected_idx: int = -1
## player_id that owns this box (for reading the right input actions).
var player_id: int = 0

# ─── Conversation history (for debug feedback) ───────────────────────
## Ordered list of nodes visited in this conversation.
## Each entry: { "speaker": String, "text": String,
##               "choices_shown": Array[String], "choice_made": Variant }
var _node_history: Array[Dictionary] = []
## Path of the DialogueTree .tres resource currently being shown.
var _dialogue_tree_path: String = ""
## Display name of the NPC driving this conversation (or "").
var _npc_name: String = ""
## Flags set via DialogueChoice.set_flag during this conversation.
var _conversation_flags_set: Array[String] = []

const _COLOR_NORMAL := Color(1.0, 1.0, 1.0)
const _COLOR_DIFFICULT := Color(1.0, 0.55, 0.55)  # soft red
const _COLOR_HIGHLIGHT_BG := Color(0.25, 0.25, 0.35)
const _COLOR_SPEAKER := Color(1.0, 0.92, 0.6)  # gold
const _COLOR_HINT := Color(0.7, 0.7, 0.7)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_feedback_btn.pressed.connect(_on_feedback_btn_pressed)
	_feedback_btn.focus_mode = Control.FOCUS_NONE
	_feedback_btn.visible = false
	_feedback_overlay.visible = false
	# Wire submit / cancel inside the overlay.
	var submit_btn: Button = $Outer/FeedbackOverlay/Margin/VBox/Buttons/Submit
	var cancel_btn: Button = $Outer/FeedbackOverlay/Margin/VBox/Buttons/Cancel
	submit_btn.pressed.connect(_on_feedback_submit)
	cancel_btn.pressed.connect(_on_feedback_cancel)


func _process(_delta: float) -> void:
	if _feedback_btn != null:
		_feedback_btn.visible = GameState.get_flag("debug_mode") and _open

func show_line(speaker: String, body: String) -> void:
	if _speaker_label == null:
		return
	_update_portrait(speaker)
	_speaker_label.text = speaker
	_body_label.text = body
	_clear_choices()
	_hint_label.text = "[H] close"
	_hint_label.visible = true
	_resize_panel()
	_outer.visible = true
	_open = true


func hide_line() -> void:
	if _outer != null:
		_outer.visible = false
	_open = false
	dismissed.emit()


func is_open() -> bool:
	return _open


func is_feedback_open() -> bool:
	return _feedback_open


# ─── Branching dialogue API ───────────────────────────────────────────

## Display a [DialogueNode] with its choices. `stats` is the player's
## stat dict (e.g. `{ &"charisma": 3 }`) used to colour stat-gated choices.
func show_node(node: DialogueNode, stats: Dictionary = {}) -> void:
	if _speaker_label == null:
		return
	_player_stats = stats
	_update_portrait(node.speaker)
	_speaker_label.text = node.speaker
	_body_label.text = node.text
	_build_choices(node.choices)

	if _visible_choices.is_empty():
		_hint_label.text = "[H] close"
		_hint_label.visible = true
	else:
		_hint_label.text = "[1-%d] or [\u2191\u2193 + H] select" % _visible_choices.size()
		_hint_label.visible = true
		_selected_idx = 0
		_highlight(_selected_idx)

	_resize_panel()
	_outer.visible = true
	_open = true

	# Record this node in the conversation history.
	var choice_labels: Array[String] = []
	for c: DialogueChoice in _visible_choices:
		choice_labels.append(c.label)
	_node_history.append({
		"speaker":      node.speaker,
		"text":         node.text,
		"choices_shown": choice_labels,
		"choice_made":  null,
	})


# ─── Input handling ────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _feedback_open:
		if event is InputEventKey and (event as InputEventKey).pressed:
			var key := event as InputEventKey
			if key.keycode == KEY_ESCAPE:
				_on_feedback_cancel()
				get_viewport().set_input_as_handled()
				return
			if key.keycode == KEY_ENTER and key.ctrl_pressed:
				_on_feedback_submit()
				get_viewport().set_input_as_handled()
				return
		return
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
		# Flag gating: skip choices whose required flag isn't set or exclusion flag is set.
		if choice.require_flag != "" and not GameState.get_flag(choice.require_flag):
			continue
		if choice.require_flag_false != "" and GameState.get_flag(choice.require_flag_false):
			continue
		_visible_choices.append(choice)
		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 15)
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
		_conversation_flags_set.append(choice.set_flag)
	# Record the choice in history.
	if not _node_history.is_empty():
		_node_history[_node_history.size() - 1]["choice_made"] = choice.label
	choice_selected.emit(choice, passed)


func _update_portrait(speaker: String) -> void:
	if not NpcPortraitRegistry.has_portrait(speaker):
		_portrait_rect.visible = false
		return
	var cell: Vector2i = NpcPortraitRegistry.get_cell(speaker)
	var tex: Texture2D = load(NpcPortraitRegistry.SHEET_PATH)
	if tex == null:
		_portrait_rect.visible = false
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(cell.x * 65, cell.y * 65, 64, 64)
	_portrait_rect.texture = atlas
	_portrait_rect.visible = true


func _resize_panel() -> void:
	pass  # Layout handled by VBoxContainer.alignment = ALIGNMENT_END in the scene.


# ─── Conversation entry point (debug-aware) ───────────────────────────────────

## Start a new branching conversation, resetting history state.
## Prefer calling this over [method show_node] directly so the conversation
## path is captured for debug feedback.
func begin_conversation(tree: DialogueTree, stats: Dictionary,
		npc_name: String) -> void:
	_node_history = []
	_conversation_flags_set = []
	_dialogue_tree_path = tree.resource_path if tree != null else ""
	_npc_name = npc_name
	if tree != null and tree.root != null:
		show_node(tree.root as DialogueNode, stats)


# ─── Feedback button handlers ─────────────────────────────────────────────────

func _on_feedback_btn_pressed() -> void:
	if _feedback_overlay == null:
		return
	# Hide the dialogue panel so the overlay isn't pushed off-screen.
	_panel.visible = false
	_feedback_overlay.visible = true
	_feedback_open = true
	# Block player input without pausing the tree.
	for pid: int in InputContext.PLAYER_COUNT:
		InputContext.set_context(pid, InputContext.Context.MENU)
	if _feedback_input != null:
		_feedback_input.text = ""
		_feedback_input.placeholder_text = "Type your notes here... (Ctrl+Enter to submit, Esc to cancel)"
		_feedback_input.grab_focus()


func _on_feedback_submit() -> void:
	if _feedback_input == null or _feedback_overlay == null:
		return
	var text: String = _feedback_input.text.strip_edges()
	if text != "":
		DebugFeedbackLogger.log_entry(_build_feedback_entry(text))
	_close_feedback_overlay()


func _on_feedback_cancel() -> void:
	_close_feedback_overlay()


func _close_feedback_overlay() -> void:
	if _feedback_overlay != null:
		_feedback_overlay.visible = false
	if _feedback_input != null:
		_feedback_input.text = ""
	_panel.visible = true
	_feedback_open = false
	# Restore both players to gameplay context.
	for pid: int in InputContext.PLAYER_COUNT:
		InputContext.set_context(pid, InputContext.Context.GAMEPLAY)


func _build_feedback_entry(feedback_text: String) -> Dictionary:
	# Collect active quests at time of feedback.
	var active_quests: Array[Dictionary] = []
	for qid: String in QuestTracker.get_all_active_quest_ids():
		active_quests.append({
			"quest_id": qid,
			"branch":   QuestTracker.get_active_branch(qid),
		})

	return {
		"timestamp":                   Time.get_datetime_string_from_system(),
		"npc_name":                    _npc_name,
		"dialogue_tree_path":          _dialogue_tree_path,
		"active_quests":               active_quests,
		"flags_set_this_conversation": _conversation_flags_set.duplicate(),
		"conversation_path":           _node_history.duplicate(true),
		"feedback":                    feedback_text,
	}

