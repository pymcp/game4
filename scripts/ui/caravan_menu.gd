## CaravanMenu
##
## CanvasLayer (layer 45) overlay opened when the player interacts with
## their caravan wagon. Shows party member panels and caravan inventory.
##
## Opened via Caravan.interacted signal or by game.gd directly.
## Closed by pressing p*_back.
class_name CaravanMenu
extends Control

## The player who owns this menu.
var _player: PlayerController = null
var _player_id: int = 0
var _caravan_data: CaravanData = null

var _root_panel: PanelContainer = null
var _member_buttons: Array[Button] = []
var _right_panel: Control = null
var _current_crafter: CrafterPanel = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 45
	visible = false


func setup(player: PlayerController, caravan_data: CaravanData) -> void:
	_player = player
	_player_id = player.player_id if player != null else 0
	_caravan_data = caravan_data
	_build_ui()


func open() -> void:
	if _caravan_data == null:
		return
	_refresh_members()
	visible = true
	InputContext.set_context(_player_id, InputContext.Context.MENU)


func close() -> void:
	visible = false
	InputContext.set_context(_player_id, InputContext.Context.GAMEPLAY)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var prefix: String = "p%d_" % (_player_id + 1)
	if Input.is_action_just_pressed(StringName(prefix + "back")):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	# Full-screen semi-transparent background.
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Main container — centered panel.
	_root_panel = PanelContainer.new()
	_root_panel.name = "RootPanel"
	_root_panel.anchor_left = 0.1
	_root_panel.anchor_top = 0.1
	_root_panel.anchor_right = 0.9
	_root_panel.anchor_bottom = 0.9
	add_child(_root_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_root_panel.add_child(hbox)

	# Left panel — party member list.
	var left := VBoxContainer.new()
	left.name = "LeftPanel"
	left.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(left)

	var title := Label.new()
	title.text = "Party"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(title)

	# Member buttons go here — built in _refresh_members().
	var members_container := VBoxContainer.new()
	members_container.name = "MembersContainer"
	members_container.add_theme_constant_override("separation", 4)
	left.add_child(members_container)
	left.add_child(HSeparator.new())

	# Caravan inventory summary.
	var inv_label := Label.new()
	inv_label.name = "InvLabel"
	inv_label.text = "Caravan Inventory"
	inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(inv_label)

	var inv_list := Label.new()
	inv_list.name = "InvList"
	inv_list.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(inv_list)

	# Right panel — crafter or warrior status.
	_right_panel = Control.new()
	_right_panel.name = "RightPanel"
	_right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_right_panel)

	var placeholder := Label.new()
	placeholder.name = "Placeholder"
	placeholder.text = "Select a party member."
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.anchor_right = 1.0
	placeholder.anchor_bottom = 1.0
	_right_panel.add_child(placeholder)


func _refresh_members() -> void:
	if _caravan_data == null or _root_panel == null:
		return
	# Navigate: RootPanel → HBoxContainer → LeftPanel → MembersContainer
	var hbox: Node = _root_panel.get_child(0) if _root_panel.get_child_count() > 0 else null
	if hbox == null:
		return
	var left_panel: Node = hbox.get_node_or_null("LeftPanel")
	if left_panel == null:
		return
	var members_container: Node = left_panel.get_node_or_null("MembersContainer")
	if members_container == null:
		return
	# Clear existing buttons.
	for child in members_container.get_children():
		child.queue_free()
	_member_buttons.clear()

	# Show buttons only for recruited members.
	for id: StringName in _caravan_data.recruited_ids:
		var def: PartyMemberDef = PartyMemberRegistry.get_member(id)
		if def == null:
			continue
		var btn := Button.new()
		btn.text = def.display_name
		btn.pressed.connect(_on_member_selected.bind(id))
		members_container.add_child(btn)
		_member_buttons.append(btn)

	# Refresh caravan inventory display.
	var inv_list: Label = left_panel.get_node_or_null("InvList") as Label
	if inv_list != null and _caravan_data.inventory != null:
		var lines: Array[String] = []
		for slot in _caravan_data.inventory.slots:
			if slot != null:
				var item_def: ItemDefinition = ItemRegistry.get_item(slot["id"])
				var item_name: String = item_def.display_name if item_def != null else String(slot["id"])
				lines.append("%s ×%d" % [item_name, slot["count"]])
		inv_list.text = "\n".join(lines) if not lines.is_empty() else "(empty)"


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
		var member_name: String = _caravan_data.get_member_name(member_id) \
				if _caravan_data != null else String(member_id)
		label.text = "%s\nHP: Active companion" % member_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		_right_panel.add_child(label)
