## MainMenu
##
## First scene shown on game launch. Lets the player start a new world,
## continue from the default save slot, or quit.
##
## "Continue" is disabled when no save file exists for [code]DEFAULT_SLOT[/code].
##
## Pure helpers [code]parse_seed[/code] and [code]has_save[/code] are static
## so they can be unit-tested without instantiating the menu.
extends Control
class_name MainMenu

const GameScene: PackedScene = preload("res://scenes/main/Game.tscn")

var _seed_input: LineEdit = null
var _btn_new_2p: Button = null
var _btn_new_p1: Button = null
var _btn_new_p2: Button = null
var _btn_continue: Button = null
var _btn_quit: Button = null
var _nav_buttons: Array[Button] = []
var _cursor: int = 0


# ---------- Pure helpers ----------

## Parse a seed string. Empty / non-numeric → 0 (which means "use unix time"
## downstream in WorldManager.reset).
static func parse_seed(text: String) -> int:
	var t := text.strip_edges()
	if t.is_empty():
		return 0
	if t.is_valid_int():
		return int(t)
	# Hash arbitrary text to keep "named seeds" working.
	return int(t.hash())


## True if a save exists for the given slot.
static func has_save(slot: String) -> bool:
	return FileAccess.file_exists(SaveGame.slot_path(slot))


# ---------- Lifecycle ----------

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build()
	_refresh_continue_state()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var vp := get_viewport()
	if PlayerActions.either_just_pressed(event, PlayerActions.UP):
		_cursor = wrapi(_cursor - 1, 0, _nav_buttons.size())
		_skip_disabled(-1)
		_refresh_cursor()
		if vp != null:
			vp.set_input_as_handled()
	elif PlayerActions.either_just_pressed(event, PlayerActions.DOWN):
		_cursor = wrapi(_cursor + 1, 0, _nav_buttons.size())
		_skip_disabled(1)
		_refresh_cursor()
		if vp != null:
			vp.set_input_as_handled()
	elif PlayerActions.either_just_pressed(event, PlayerActions.INTERACT):
		if _cursor < _nav_buttons.size() and not _nav_buttons[_cursor].disabled:
			_nav_buttons[_cursor].pressed.emit()
		if vp != null:
			vp.set_input_as_handled()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.10, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	var title := Label.new()
	title.text = "Fantasy Iso Co-op"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	v.add_child(title)

	var seed_label := Label.new()
	seed_label.text = "World seed (optional)"
	v.add_child(seed_label)

	_seed_input = LineEdit.new()
	_seed_input.placeholder_text = "leave blank to randomise"
	v.add_child(_seed_input)

	_btn_new_2p = Button.new()
	_btn_new_2p.text = "New Game (2 Players)"
	_btn_new_2p.pressed.connect(_on_new_game_2p)
	v.add_child(_btn_new_2p)

	_btn_new_p1 = Button.new()
	_btn_new_p1.text = "New Game (Player 1)"
	_btn_new_p1.pressed.connect(_on_new_game_p1)
	v.add_child(_btn_new_p1)

	_btn_new_p2 = Button.new()
	_btn_new_p2.text = "New Game (Player 2)"
	_btn_new_p2.pressed.connect(_on_new_game_p2)
	v.add_child(_btn_new_p2)

	_btn_continue = Button.new()
	_btn_continue.text = "Continue"
	_btn_continue.pressed.connect(_on_continue)
	v.add_child(_btn_continue)

	_btn_quit = Button.new()
	_btn_quit.text = "Quit"
	_btn_quit.pressed.connect(_on_quit)
	v.add_child(_btn_quit)

	for btn: Button in [_btn_new_2p, _btn_new_p1, _btn_new_p2, _btn_continue, _btn_quit]:
		btn.focus_mode = Control.FOCUS_NONE
	_nav_buttons = [_btn_new_2p, _btn_new_p1, _btn_new_p2, _btn_continue, _btn_quit]
	_cursor = 0
	_refresh_cursor()


func _refresh_continue_state() -> void:
	if _btn_continue != null:
		_btn_continue.disabled = not has_save(SaveManager.DEFAULT_SLOT)
	if not _nav_buttons.is_empty():
		_skip_disabled(1)
		_refresh_cursor()


# ---------- Cursor helpers ----------

func _skip_disabled(direction: int) -> void:
	var n := _nav_buttons.size()
	var tries := 0
	while tries < n and _nav_buttons[_cursor].disabled:
		_cursor = wrapi(_cursor + direction, 0, n)
		tries += 1


func _refresh_cursor() -> void:
	for i in _nav_buttons.size():
		var btn: Button = _nav_buttons[i]
		if i == _cursor and not btn.disabled:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			btn.remove_theme_color_override("font_color")


# ---------- Button handlers ----------

func _on_new_game_2p() -> void:
	var seed_value := parse_seed(_seed_input.text if _seed_input != null else "")
	PauseManager.set_player_enabled(0, true)
	PauseManager.set_player_enabled(1, true)
	GameSession.pending_load_slot = ""
	GameSession.start_new_game(seed_value)
	get_tree().change_scene_to_packed(GameScene)


func _on_new_game_p1() -> void:
	var seed_value := parse_seed(_seed_input.text if _seed_input != null else "")
	PauseManager.set_player_enabled(0, true)
	PauseManager.set_player_enabled(1, false)
	GameSession.pending_load_slot = ""
	GameSession.start_new_game(seed_value)
	get_tree().change_scene_to_packed(GameScene)


func _on_new_game_p2() -> void:
	var seed_value := parse_seed(_seed_input.text if _seed_input != null else "")
	PauseManager.set_player_enabled(0, false)
	PauseManager.set_player_enabled(1, true)
	GameSession.pending_load_slot = ""
	GameSession.start_new_game(seed_value)
	get_tree().change_scene_to_packed(GameScene)


func _on_continue() -> void:
	PauseManager.set_player_enabled(0, true)
	PauseManager.set_player_enabled(1, true)
	GameSession.pending_load_slot = SaveManager.DEFAULT_SLOT
	get_tree().change_scene_to_packed(GameScene)


func _on_quit() -> void:
	get_tree().quit()


# ---------- Test helpers ----------

func get_continue_button() -> Button:
	return _btn_continue


func get_seed_input() -> LineEdit:
	return _seed_input


func get_new_game_2p_button() -> Button:
	return _btn_new_2p


func get_new_game_p1_button() -> Button:
	return _btn_new_p1


func get_new_game_p2_button() -> Button:
	return _btn_new_p2
