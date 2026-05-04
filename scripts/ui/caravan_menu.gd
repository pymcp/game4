## CaravanMenu
##
## Full-keyboard-navigable overlay opened when the player interacts with
## their caravan wagon. Two focus zones: LEFT (member list) and RIGHT (active panel).
##
## LEFT zone: UP/DOWN moves member cursor, INTERACT selects and shifts focus RIGHT.
## RIGHT zone: navigation delegated to the active sub-panel via navigate(verb).
## BACK returns from RIGHT→LEFT, or closes from LEFT.
class_name CaravanMenu
extends Control

enum _Focus { LEFT, RIGHT }

var _player: PlayerController = null
var _player_id: int = 0
var _caravan_data: CaravanData = null

## Emitted when the player wants to swap their active pet.
signal swap_pet_requested(player_id: int, species: StringName)

## Emitted when the player presses Build in the builder panel.
signal build_requested(player_id: int, structure_id: StringName)

## Reference to the World node, for reading pet roster.
var _world_node: Node = null

var _member_buttons: Array[Button] = []
var _member_ids: Array[StringName] = []
var _current_crafter: CrafterPanel = null

var _member_cursor: int = 0
var _focus: _Focus = _Focus.LEFT

@onready var _members_container: GridContainer = $Panel/HBox/LeftPanel/MembersContainer
@onready var _inv_list: Label = $Panel/HBox/LeftPanel/InvList
@onready var _left_panel: VBoxContainer = $Panel/HBox/LeftPanel
@onready var _right_panel: Control = $Panel/HBox/RightPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func setup(player: PlayerController, caravan_data: CaravanData, world_node: Node = null) -> void:
	_player = player
	_player_id = player.player_id if player != null else 0
	_caravan_data = caravan_data
	_world_node = world_node


func open() -> void:
	if _caravan_data == null:
		return
	# Auto-transfer crafting ingredients from player inventory to caravan.
	if _player != null:
		_player.trigger_overworld_transfer()
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
		const _COLS: int = 2  # matches GridContainer columns
		var count: int = max(1, _member_buttons.size())
		if PlayerActions.just_pressed(event, _player_id, PlayerActions.UP):
			_member_cursor = wrapi(_member_cursor - _COLS, 0, count)
			_refresh_member_cursor()
			get_viewport().set_input_as_handled()
		elif PlayerActions.just_pressed(event, _player_id, PlayerActions.DOWN):
			_member_cursor = wrapi(_member_cursor + _COLS, 0, count)
			_refresh_member_cursor()
			get_viewport().set_input_as_handled()
		elif PlayerActions.just_pressed(event, _player_id, PlayerActions.LEFT):
			_member_cursor = wrapi(_member_cursor - 1, 0, count)
			_refresh_member_cursor()
			get_viewport().set_input_as_handled()
		elif PlayerActions.just_pressed(event, _player_id, PlayerActions.RIGHT):
			_member_cursor = wrapi(_member_cursor + 1, 0, count)
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
		var card := _build_member_card(id, def)
		_members_container.add_child(card)
		_member_buttons.append(card)
		_member_ids.append(id)

	# ─── Pets tab ──────────────────────────────────────────────
	if _world_node != null and _world_node.has_method("get_pet_roster"):
		var pets_card := _build_pets_card()
		_members_container.add_child(pets_card)
		_member_buttons.append(pets_card)
		_member_ids.append(&"__pets_tab__")

	if _inv_list != null and _caravan_data.inventory != null:
		var lines: Array[String] = []
		for slot in _caravan_data.inventory.slots:
			if slot != null:
				var item_def: ItemDefinition = ItemRegistry.get_item(slot["id"])
				var item_name: String = item_def.display_name if item_def != null else String(slot["id"])
				lines.append("%s ×%d" % [item_name, slot["count"]])
		_inv_list.text = "\n".join(lines) if not lines.is_empty() else "(empty)"


func _build_member_card(id: StringName, def: PartyMemberDef) -> Button:
	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(128, 160)
	card.theme_type_variation = &"WoodButton"
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(_on_member_selected.bind(id))

	var inner := VBoxContainer.new()
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.add_theme_constant_override("separation", 2)
	card.add_child(inner)

	# Portrait.
	var portrait_ctrl := Control.new()
	portrait_ctrl.custom_minimum_size = Vector2(64, 64)
	portrait_ctrl.clip_contents = true
	portrait_ctrl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(portrait_ctrl)

	var member_name: String = _caravan_data.get_member_name(id) \
			if _caravan_data != null else String(id)
	var h: int = member_name.hash() & 0x7fffffff
	var opts: Dictionary = _hash_to_appearance(h)
	var char_node: Node2D = CharacterBuilder.build(opts)
	char_node.scale = Vector2(1.0, 1.0)
	char_node.position = Vector2(32, 48)
	portrait_ctrl.add_child(char_node)

	# Name.
	var name_lbl := Label.new()
	name_lbl.text = member_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.clip_text = true
	inner.add_child(name_lbl)

	# Role.
	var role_lbl := Label.new()
	role_lbl.text = def.display_name
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 11)
	role_lbl.add_theme_color_override("font_color", UITheme.COL_LABEL_DIM)
	inner.add_child(role_lbl)

	return card


func _build_pets_card() -> Button:
	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(128, 160)
	card.theme_type_variation = &"WoodButton"
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(_on_member_selected.bind(&"__pets_tab__"))

	var inner := VBoxContainer.new()
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.add_theme_constant_override("separation", 2)
	card.add_child(inner)

	# Portrait — active pet sprite.
	var portrait_ctrl := Control.new()
	portrait_ctrl.custom_minimum_size = Vector2(64, 64)
	portrait_ctrl.clip_contents = true
	portrait_ctrl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(portrait_ctrl)

	var active_species: StringName = GameSession.p1_active_pet if _player_id == 0 else GameSession.p2_active_pet
	if active_species == &"":
		active_species = &"cat"
	var pet_spr: Sprite2D = CreatureSpriteRegistry.build_sprite(active_species)
	if pet_spr != null:
		pet_spr.scale = Vector2(2.0, 2.0)
		pet_spr.position = Vector2(32, 32)
		portrait_ctrl.add_child(pet_spr)

	var name_lbl := Label.new()
	name_lbl.text = "Pets"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	inner.add_child(name_lbl)

	var role_lbl := Label.new()
	role_lbl.text = "Companions"
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 11)
	role_lbl.add_theme_color_override("font_color", UITheme.COL_LABEL_DIM)
	inner.add_child(role_lbl)

	return card


## Deterministically map an integer hash to CharacterBuilder opts.
## Valid values from CharacterAtlas:
##   skin: "light", "tan", "dark", "goblin"
##   torso_color: "orange", "teal", "purple", "green", "tan", "black"
##   hair_color: "brown", "blonde", "white", "ginger", "gray"
static func _hash_to_appearance(h: int) -> Dictionary:
	var skin_opts: Array[StringName] = [&"light", &"tan", &"dark", &"goblin"]
	var torso_colors: Array[StringName] = [&"orange", &"teal", &"purple", &"green", &"tan", &"black"]
	var hair_colors: Array[StringName] = [&"brown", &"blonde", &"white", &"ginger", &"gray"]
	return {
		"skin": skin_opts[(h >> 0) % skin_opts.size()],
		"torso_color": torso_colors[(h >> 4) % torso_colors.size()],
		"torso_style": (h >> 8) % 4,
		"torso_row": (h >> 10) % 3,
		"hair_color": hair_colors[(h >> 12) % hair_colors.size()],
		"hair_style": (h >> 16) % 4,
		"hair_variant": (h >> 18) % 3,
	}


func _refresh_member_cursor() -> void:
	for i in _member_buttons.size():
		var btn: Button = _member_buttons[i]
		var is_selected: bool = (i == _member_cursor and _focus == _Focus.LEFT)
		btn.modulate = Color(1.4, 1.2, 0.5) if is_selected else Color.WHITE


func _on_member_selected(member_id: StringName) -> void:
	if member_id == &"__pets_tab__":
		for child in _right_panel.get_children():
			child.queue_free()
		_current_crafter = null
		var panel := PetsPanel.new()
		panel.setup(_player_id, _world_node)
		panel.pet_follow_requested.connect(func(pid: int, sp: StringName) -> void:
			swap_pet_requested.emit(pid, sp)
		)
		_right_panel.add_child(panel)
		_set_focus(_Focus.RIGHT)
		return
	for child in _right_panel.get_children():
		child.queue_free()
	_current_crafter = null

	var def: PartyMemberDef = PartyMemberRegistry.get_member(member_id)
	if def == null:
		return

	if def.crafter_domain == &"builder":
		for child in _right_panel.get_children():
			child.queue_free()
		_current_crafter = null
		var bp := _BuilderPanel.new()
		bp.anchor_right = 1.0
		bp.anchor_bottom = 1.0
		bp.setup(def, _caravan_data)
		bp.build_pressed.connect(func(sid: StringName) -> void:
			close()
			build_requested.emit(_player_id, sid)
		)
		_right_panel.add_child(bp)
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


# ─── Builder panel ─────────────────────────────────────────────────────────


class _BuilderPanel extends VBoxContainer:
	signal build_pressed(structure_id: StringName)

	var _caravan_data: CaravanData = null
	var _cursor: int = 0
	var _buttons: Array[Button] = []
	var _sids: Array[StringName] = []

	func setup(def: PartyMemberDef, caravan_data: CaravanData) -> void:
		_caravan_data = caravan_data
		add_theme_constant_override("separation", 8)
		var title := Label.new()
		title.text = "Builder"
		title.theme_type_variation = &"TitleLabel"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(title)
		var sep := HSeparator.new()
		add_child(sep)
		var section := Label.new()
		section.text = "Structures"
		section.theme_type_variation = &"DimLabel"
		add_child(section)
		for entry: Dictionary in def.builds:
			_add_build_row(entry)
		_refresh_cursor()

	func _add_build_row(entry: Dictionary) -> void:
		var sid: StringName = StringName(entry.get("id", ""))
		var display: String = entry.get("display_name", String(sid))
		var cost: Dictionary = entry.get("cost", {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		# Name label.
		var name_lbl := Label.new()
		name_lbl.text = display
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		# Cost label (green if affordable, red if not).
		var cost_parts: Array[String] = []
		var can_afford: bool = true
		for item_id in cost:
			var needed: int = int(cost[item_id])
			var have: int = _caravan_data.inventory.count_of(StringName(item_id)) \
					if _caravan_data != null and _caravan_data.inventory != null else 0
			var item_def: ItemDefinition = ItemRegistry.get_item(StringName(item_id))
			var item_name: String = item_def.display_name if item_def != null else item_id
			cost_parts.append("%d %s" % [needed, item_name])
			if have < needed:
				can_afford = false
		var cost_lbl := Label.new()
		cost_lbl.text = ", ".join(cost_parts)
		cost_lbl.add_theme_color_override("font_color",
				Color(0.4, 1.0, 0.4) if can_afford else Color(1.0, 0.4, 0.4))
		cost_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(cost_lbl)
		# Build button.
		var btn := Button.new()
		btn.text = "Build"
		btn.theme_type_variation = &"WoodButton"
		btn.disabled = not can_afford
		btn.pressed.connect(func() -> void: build_pressed.emit(sid))
		row.add_child(btn)
		_buttons.append(btn)
		_sids.append(sid)

	func navigate(verb: StringName) -> void:
		if _buttons.is_empty():
			return
		match verb:
			PlayerActions.UP:
				_cursor = wrapi(_cursor - 1, 0, _buttons.size())
				_refresh_cursor()
			PlayerActions.DOWN:
				_cursor = wrapi(_cursor + 1, 0, _buttons.size())
				_refresh_cursor()
			PlayerActions.INTERACT:
				if not _buttons[_cursor].disabled:
					build_pressed.emit(_sids[_cursor])

	func _refresh_cursor() -> void:
		for i in _buttons.size():
			var btn: Button = _buttons[i]
			if i == _cursor:
				btn.add_theme_color_override("font_color", UITheme.COL_CURSOR)
			else:
				btn.remove_theme_color_override("font_color")

