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

@onready var _seed_input: LineEdit = $Center/Panel/Margin/VBox/SeedInput
@onready var _btn_new_2p: Button = $Center/Panel/Margin/VBox/NewGame2P
@onready var _btn_new_p1: Button = $Center/Panel/Margin/VBox/NewGameP1
@onready var _btn_new_p2: Button = $Center/Panel/Margin/VBox/NewGameP2
@onready var _btn_continue: Button = $Center/Panel/Margin/VBox/Continue
@onready var _btn_quit: Button = $Center/Panel/Margin/VBox/Quit

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
	_btn_new_2p.pressed.connect(_on_new_game_2p)
	_btn_new_p1.pressed.connect(_on_new_game_p1)
	_btn_new_p2.pressed.connect(_on_new_game_p2)
	_btn_continue.pressed.connect(_on_continue)
	_btn_quit.pressed.connect(_on_quit)
	_nav_buttons = [_btn_new_2p, _btn_new_p1, _btn_new_p2, _btn_continue, _btn_quit]
	_cursor = 0
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
			btn.add_theme_color_override("font_color", UITheme.COL_CURSOR)
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
