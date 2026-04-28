## CaravanMenu
##
## Full-keyboard-navigable overlay opened when the player interacts with
## their caravan wagon. Two focus zones: LEFT (member list) and RIGHT (active panel).
##
## LEFT zone: UP/DOWN moves member cursor, INTERACT selects and shifts focus RIGHT.
## RIGHT zone: navigation delegated to the active sub-panel via navigate(verb).
## BACK returns from RIGHT→LEFT, or closes from LEFT.
class_name CaravanMenu
extends CanvasLayer

enum _Focus { LEFT, RIGHT }

var _player: PlayerController = null
var _player_id: int = 0
var _caravan_data: CaravanData = null

@onready var _members_container: VBoxContainer = $Panel/HBox/LeftPanel/MembersContainer
@onready var _inv_list: Label = $Panel/HBox/LeftPanel/InvList
@onready var _left_panel: VBoxContainer = $Panel/HBox/LeftPanel
@onready var _right_panel: Control = $Panel/HBox/RightPanel

var _member_buttons: Array[Button] = []
var _member_ids: Array[StringName] = []
var _current_crafter: CrafterPanel = null

var _member_cursor: int = 0
var _focus: _Focus = _Focus.LEFT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func setup(player: PlayerController, caravan_data: CaravanData) -> void:
	_player = player
	_player_id = player.player_id if player != null else 0
	_caravan_data = caravan_data


func open() -> void:
	if _caravan_data == null:
		return
	_refresh_members()
	_member_cursor = 0
	visible = true
	InputContext.set_context(_player_id, InputContext.Context.INVENTORY)
	_set_focus(_Focus.LEFT)


func close() -> void:
	visible = false
	InputContext.set_context(_player_id, InputContext.Context.GAMEPLAY)


func _is_my_event(event: InputEvent) -> bool:
	for verb: StringName in [PlayerActions.UP, PlayerActions.DOWN, PlayerActions.LEFT,
			PlayerActions.RIGHT, PlayerActions.INTERACT, PlayerActions.BACK,
			PlayerActions.ATTACK, PlayerActions.INVENTORY, PlayerActions.TAB_PREV,
			PlayerActions.TAB_NEXT, PlayerActions.AUTO_MINE, PlayerActions.AUTO_ATTACK]:
		if event.is_action(PlayerActions.action(_player_id, verb)):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_my_event(event):
		get_viewport().set_input_as_handled()

	if _focus == _Focus.LEFT:
		if PlayerActions.just_pressed(event, _player_id, PlayerActions.UP):
			_member_cursor = wrapi(_member_cursor - 1, 0, max(1, _member_buttons.size()))
			_refresh_member_cursor()
			get_viewport().set_input_as_handled()
		elif PlayerActions.just_pressed(event, _player_id, PlayerActions.DOWN):
			_member_cursor = wrapi(_member_cursor + 1, 0, max(1, _member_buttons.size()))
			_refresh_member_cursor()
			get_viewport().set_input_as_handled()
		elif PlayerActions.just_pressed(event, _player_id, PlayerActions.INTERACT):
			if _member_cursor < _member_ids.size():
				_on_member_selected(_member_ids[_member_cursor])
				_set_focus(_Focus.RIGHT)
			get_viewport().set_input_as_handled()
		elif PlayerActions.just_pressed(event, _player_id, PlayerActions.BACK):
			close()
			get_viewport().set_input_as_handled()
	else:  # _Focus.RIGHT
		if PlayerActions.just_pressed(event, _player_id, PlayerActions.BACK) \
				or PlayerActions.just_pressed(event, _player_id, PlayerActions.LEFT):
			_set_focus(_Focus.LEFT)
			get_viewport().set_input_as_handled()
		else:
			var panel: Node = _get_active_right_panel()
			if panel != null and panel.has_method("navigate"):
				for verb: StringName in [PlayerActions.UP, PlayerActions.DOWN,
						PlayerActions.LEFT, PlayerActions.RIGHT, PlayerActions.INTERACT,
						PlayerActions.TAB_PREV, PlayerActions.TAB_NEXT]:
					if PlayerActions.just_pressed(event, _player_id, verb):
						panel.call("navigate", verb)
						get_viewport().set_input_as_handled()
						break


func _set_focus(new_focus: _Focus) -> void:
	_focus = new_focus
	_refresh_member_cursor()
	_refresh_focus_visuals()


func _refresh_focus_visuals() -> void:
	var left_active: bool = (_focus == _Focus.LEFT)
	var dim := Color(0.55, 0.55, 0.55, 1.0)
	if _left_panel != null:
		_left_panel.modulate = Color.WHITE if left_active else dim
	if _right_panel != null:
		_right_panel.modulate = Color.WHITE if not left_active else dim


func _get_active_right_panel() -> Node:
	if _right_panel == null:
		return null
	if _current_crafter != null:
		return _current_crafter
	return _right_panel.get_child(0) if _right_panel.get_child_count() > 0 else null


func _refresh_members() -> void:
	if _caravan_data == null or _members_container == null:
		return
	for child in _members_container.get_children():
		child.queue_free()
	_member_buttons.clear()
	_member_ids.clear()

	for id: StringName in _caravan_data.recruited_ids:
		var def: PartyMemberDef = PartyMemberRegistry.get_member(id)
		if def == null:
			continue
		var btn := Button.new()
		btn.text = def.display_name
		btn.focus_mode = Control.FOCUS_NONE
		btn.theme_type_variation = &"WoodButton"
		btn.pressed.connect(_on_member_selected.bind(id))
		_members_container.add_child(btn)
		_member_buttons.append(btn)
		_member_ids.append(id)

	if _inv_list != null and _caravan_data.inventory != null:
		var lines: Array[String] = []
		for slot in _caravan_data.inventory.slots:
			if slot != null:
				var item_def: ItemDefinition = ItemRegistry.get_item(slot["id"])
				var item_name: String = item_def.display_name if item_def != null else String(slot["id"])
				lines.append("%s ×%d" % [item_name, slot["count"]])
		_inv_list.text = "\n".join(lines) if not lines.is_empty() else "(empty)"


func _refresh_member_cursor() -> void:
	for i in _member_buttons.size():
		var btn: Button = _member_buttons[i]
		var is_selected: bool = (i == _member_cursor and _focus == _Focus.LEFT)
		if is_selected:
			btn.add_theme_color_override("font_color", UITheme.COL_CURSOR)
		else:
			btn.remove_theme_color_override("font_color")


func _on_member_selected(member_id: StringName) -> void:
	for child in _right_panel.get_children():
		child.queue_free()
	_current_crafter = null

	var def: PartyMemberDef = PartyMemberRegistry.get_member(member_id)
	if def == null:
		return

	if def.crafter_domain != &"":
		_current_crafter = CrafterPanel.new()
		_current_crafter.name = "ActiveCrafter"
		_current_crafter.anchor_right = 1.0
		_current_crafter.anchor_bottom = 1.0
		_right_panel.add_child(_current_crafter)
		_current_crafter.set_crafter(def.crafter_domain, _caravan_data)
	elif member_id == &"story_teller":
		var panel := StoryTellerPanel.new()
		panel.name = "StoryTellerPanel"
		panel.anchor_right = 1.0
		panel.anchor_bottom = 1.0
		_right_panel.add_child(panel)
		panel.setup(_player, _caravan_data)
	else:
		var label := Label.new()
		label.theme_type_variation = &"DimLabel"
		var member_name: String = _caravan_data.get_member_name(member_id) \
				if _caravan_data != null else String(member_id)
		label.text = "%s\nHP: Active companion" % member_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		_right_panel.add_child(label)
