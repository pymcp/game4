## DebugScreen
##
## Full-viewport debug modal triggered by F4.  Pauses the game and spans
## both SubViewports (CanvasLayer layer 60), navigable by either player's
## controller scheme plus mouse.
##
## Pressing F4 while open (or pressing Back) closes the modal.
## Actions that spawn things call the matching World debug method then close.
extends CanvasLayer
class_name DebugScreen

@onready var _main_buttons_box: VBoxContainer = $Center/Panel/Margin/VBox/MainButtons
@onready var _sub_panel:        VBoxContainer = $Center/Panel/Margin/VBox/SubPanel
@onready var _sub_list:         VBoxContainer = $Center/Panel/Margin/VBox/SubPanel/SubList

@onready var _btn_teleport:    Button = $Center/Panel/Margin/VBox/MainButtons/Teleport
@onready var _btn_items:       Button = $Center/Panel/Margin/VBox/MainButtons/Items
@onready var _btn_monsters:    Button = $Center/Panel/Margin/VBox/MainButtons/Monsters
@onready var _btn_caravan:     Button = $Center/Panel/Margin/VBox/MainButtons/Caravan
@onready var _btn_dungeon:     Button = $Center/Panel/Margin/VBox/MainButtons/Dungeon
@onready var _btn_debug_mode:  Button = $Center/Panel/Margin/VBox/MainButtons/DebugMode
@onready var _btn_hitbox:      Button = $Center/Panel/Margin/VBox/MainButtons/HitboxOverlay
@onready var _btn_tiles:       Button = $Center/Panel/Margin/VBox/MainButtons/TileLabels
@onready var _btn_close:       Button = $Center/Panel/Margin/VBox/MainButtons/Close

var _is_open:      bool  = false
var _caused_pause: bool  = false

## Keyboard/controller cursor index for the main button list.
var _cursor:     int  = 0
## Keyboard/controller cursor index for the objective sub-list.
var _sub_cursor: int  = 0
## True while the quest objective sub-list is showing.
var _in_sub_list: bool = false
## Dynamically created objective buttons (populated each time the sub-list opens).
var _sub_buttons: Array[Button] = []
## Ordered list of main buttons for cursor navigation.
var _main_nav: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_sub_panel.visible = false

	# Wire main button signals.
	_btn_teleport.pressed.connect(_on_teleport_pressed)
	_btn_items.pressed.connect(_on_items_pressed)
	_btn_monsters.pressed.connect(_on_monsters_pressed)
	_btn_caravan.pressed.connect(_on_caravan_pressed)
	_btn_dungeon.pressed.connect(_on_dungeon_pressed)
	_btn_debug_mode.pressed.connect(_on_debug_mode_pressed)
	_btn_hitbox.pressed.connect(_on_hitbox_pressed)
	_btn_tiles.pressed.connect(_on_tiles_pressed)
	_btn_close.pressed.connect(close)

	# Disable Godot built-in focus traversal — we manage cursor manually.
	for btn: Button in [_btn_teleport, _btn_items, _btn_monsters, _btn_caravan,
			_btn_dungeon, _btn_debug_mode, _btn_hitbox, _btn_tiles, _btn_close]:
		btn.focus_mode = Control.FOCUS_NONE

	_main_nav = [_btn_teleport, _btn_items, _btn_monsters, _btn_caravan,
			_btn_dungeon, _btn_debug_mode, _btn_hitbox, _btn_tiles, _btn_close]

	_refresh_debug_mode_label()


func _input(event: InputEvent) -> void:
	# F4 toggles the modal when closed; closes or backs out when open.
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_F4 and key.pressed and not key.echo:
			if not _is_open:
				open()
			elif _in_sub_list:
				_show_main_list()
			else:
				close()
			get_viewport().set_input_as_handled()
			return

	if not _is_open:
		return

	if PlayerActions.either_just_pressed(event, PlayerActions.BACK):
		if _in_sub_list:
			_show_main_list()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif PlayerActions.either_just_pressed(event, PlayerActions.UP):
		if _in_sub_list:
			if _sub_buttons.is_empty():
				return
			_sub_cursor = wrapi(_sub_cursor - 1, 0, _sub_buttons.size())
		else:
			_cursor = wrapi(_cursor - 1, 0, _main_nav.size())
		_refresh_cursor()
		get_viewport().set_input_as_handled()
	elif PlayerActions.either_just_pressed(event, PlayerActions.DOWN):
		if _in_sub_list:
			if _sub_buttons.is_empty():
				return
			_sub_cursor = wrapi(_sub_cursor + 1, 0, _sub_buttons.size())
		else:
			_cursor = wrapi(_cursor + 1, 0, _main_nav.size())
		_refresh_cursor()
		get_viewport().set_input_as_handled()
	elif PlayerActions.either_just_pressed(event, PlayerActions.INTERACT):
		if _in_sub_list:
			if _sub_cursor < _sub_buttons.size():
				_sub_buttons[_sub_cursor].pressed.emit()
		else:
			if _cursor < _main_nav.size():
				_main_nav[_cursor].pressed.emit()
		get_viewport().set_input_as_handled()


## Open the debug modal.  Pauses the game tree directly (without triggering
## PauseManager, so the pause menu does not appear).
func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_caused_pause = not get_tree().paused
	if _caused_pause:
		get_tree().paused = true
	_show_main_list()
	_refresh_debug_mode_label()


## Close the debug modal.  Unpauses the game tree only if this modal caused it.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	if _caused_pause:
		_caused_pause = false
		get_tree().paused = false


# ─── List transitions ─────────────────────────────────────────────────────────

func _show_main_list() -> void:
	_in_sub_list = false
	_sub_panel.visible = false
	_main_buttons_box.visible = true
	_cursor = 0
	_refresh_cursor()


func _show_sub_list() -> void:
	_in_sub_list = true
	_main_buttons_box.visible = false
	_sub_panel.visible = true
	_populate_sub_list()
	_sub_cursor = 0
	_refresh_cursor()


func _populate_sub_list() -> void:
	# Clear any previously created buttons.
	for child in _sub_list.get_children():
		child.queue_free()
	_sub_buttons.clear()

	var markers: Array[Dictionary] = QuestTracker.get_objective_markers()
	if markers.is_empty():
		var lbl := Label.new()
		lbl.text = "(No active objectives with known locations)"
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_sub_list.add_child(lbl)
		return

	for entry: Dictionary in markers:
		var quest_id: String = entry.get("quest_id", "")
		var obj_id:   String = entry.get("obj_id",   "")
		var region_id: Vector2i = entry.get("region_id", Vector2i.ZERO)
		var cell:      Vector2i = entry.get("cell",      Vector2i.ZERO)

		# Build a human-readable label for the button.
		var quest: Dictionary    = QuestRegistry.get_quest(quest_id)
		var quest_name: String   = quest.get("display_name", quest_id)
		var branch_id: String    = QuestTracker.get_active_branch(quest_id)
		var branch: Dictionary   = QuestRegistry.get_branch(quest_id, branch_id)
		var obj_desc: String = obj_id
		for obj: Dictionary in branch.get("objectives", []):
			if obj.get("id", "") == obj_id:
				obj_desc = obj.get("description", obj_id)
				break

		var btn := Button.new()
		btn.text = "%s — %s" % [quest_name, obj_desc]
		btn.focus_mode = Control.FOCUS_NONE
		btn.theme_type_variation = &"WoodButton"
		btn.pressed.connect(_on_objective_selected.bind(region_id, cell))
		_sub_list.add_child(btn)
		_sub_buttons.append(btn)


# ─── Cursor highlight ─────────────────────────────────────────────────────────

func _refresh_cursor() -> void:
	if _in_sub_list:
		for i: int in _sub_buttons.size():
			var btn: Button = _sub_buttons[i]
			if i == _sub_cursor:
				btn.add_theme_color_override("font_color", Color.YELLOW)
			else:
				btn.remove_theme_color_override("font_color")
	else:
		for i: int in _main_nav.size():
			var btn: Button = _main_nav[i]
			if i == _cursor:
				btn.add_theme_color_override("font_color", Color.YELLOW)
			else:
				btn.remove_theme_color_override("font_color")


func _refresh_debug_mode_label() -> void:
	var is_on: bool = GameState.get_flag("debug_mode")
	_btn_debug_mode.text = "Debug Mode: %s" % ("ON" if is_on else "OFF")


# ─── Main button handlers ─────────────────────────────────────────────────────

func _on_teleport_pressed() -> void:
	_show_sub_list()


func _on_items_pressed() -> void:
	var world: World = World.instance()
	if world != null:
		world.debug_give_all_items()
	close()


func _on_monsters_pressed() -> void:
	var world: World = World.instance()
	if world != null:
		world.debug_spawn_monster()
		world.debug_boost_player_health(1000)
	close()


func _on_caravan_pressed() -> void:
	var world: World = World.instance()
	if world != null:
		world.debug_add_all_party_members()
	close()


func _on_dungeon_pressed() -> void:
	var world: World = World.instance()
	if world != null:
		world.debug_spawn_dungeon_and_maze()
	close()


func _on_debug_mode_pressed() -> void:
	GameState.set_flag("debug_mode", not GameState.get_flag("debug_mode"))
	_refresh_debug_mode_label()
	_refresh_cursor()


func _on_hitbox_pressed() -> void:
	var world: World = World.instance()
	if world != null:
		world.debug_toggle_hitbox_overlay()


func _on_tiles_pressed() -> void:
	var world: World = World.instance()
	if world != null:
		world.debug_toggle_tile_labels()


# ─── Sub-list handler ─────────────────────────────────────────────────────────

func _on_objective_selected(region_id: Vector2i, cell: Vector2i) -> void:
	var world: World = World.instance()
	if world != null:
		world.debug_teleport_to_objective(region_id, cell)
	close()
