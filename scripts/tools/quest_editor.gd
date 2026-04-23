## QuestEditor
##
## Sub-editor for quest data using a GraphEdit-based visual editor.
## Left panel: quest list. Right: GraphEdit with branch nodes.
## Each branch is a GraphNode showing objectives and rewards.
class_name QuestEditor
extends VBoxContainer

signal dirty_changed

var sheet_path: String = ""
var _dirty: bool = false
var _data: Dictionary = {}  # quest_id -> quest dict
var _selected_id: String = ""
var _next_id: int = 0

# UI
var _split: HSplitContainer
var _quest_list: ItemList
var _add_btn: Button
var _del_btn: Button
var _props_panel: VBoxContainer  # quest-level properties
var _graph: GraphEdit
var _name_edit: LineEdit
var _giver_edit: LineEdit
var _desc_edit: TextEdit
var _prereq_edit: LineEdit

# Branch nodes
var _branch_nodes: Dictionary = {}  # branch_id -> GraphNode


func _ready() -> void:
	_build_ui()
	_load_data()
	_populate_list()


func _build_ui() -> void:
	_split = HSplitContainer.new()
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_split)

	# Left panel
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 200
	_split.add_child(left)

	_quest_list = ItemList.new()
	_quest_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_list.item_selected.connect(_on_quest_selected)
	left.add_child(_quest_list)

	var btn_row := HBoxContainer.new()
	left.add_child(btn_row)
	_add_btn = Button.new()
	_add_btn.text = "Add"
	_add_btn.pressed.connect(_on_add)
	btn_row.add_child(_add_btn)
	_del_btn = Button.new()
	_del_btn.text = "Delete"
	_del_btn.pressed.connect(_on_delete)
	btn_row.add_child(_del_btn)

	# Right panel
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(right)

	# Properties panel
	_props_panel = VBoxContainer.new()
	right.add_child(_props_panel)

	var row1 := HBoxContainer.new()
	_props_panel.add_child(row1)
	row1.add_child(_label("Name:"))
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(_on_prop_changed.bind("display_name"))
	row1.add_child(_name_edit)

	var row2 := HBoxContainer.new()
	_props_panel.add_child(row2)
	row2.add_child(_label("Giver:"))
	_giver_edit = LineEdit.new()
	_giver_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_giver_edit.text_changed.connect(_on_prop_changed.bind("giver"))
	row2.add_child(_giver_edit)

	var row3 := HBoxContainer.new()
	_props_panel.add_child(row3)
	row3.add_child(_label("Prerequisites (comma-sep):"))
	_prereq_edit = LineEdit.new()
	_prereq_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prereq_edit.text_changed.connect(_on_prereq_changed)
	row3.add_child(_prereq_edit)

	_desc_edit = TextEdit.new()
	_desc_edit.custom_minimum_size.y = 60
	_desc_edit.placeholder_text = "Quest description..."
	_desc_edit.text_changed.connect(_on_desc_changed)
	_props_panel.add_child(_desc_edit)

	# Graph edit for branches
	_graph = GraphEdit.new()
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.custom_minimum_size.y = 300
	right.add_child(_graph)

	# Add Branch button
	var add_branch_btn := Button.new()
	add_branch_btn.text = "Add Branch"
	add_branch_btn.pressed.connect(_on_add_branch)
	right.add_child(add_branch_btn)

	_props_panel.visible = false


func _label(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	return l


func _load_data() -> void:
	_data = QuestRegistry.get_raw_data().duplicate(true)
	var max_id: int = 0
	for qid: String in _data:
		var num: int = qid.hash() & 0x7FFFFFFF
		if num > max_id:
			max_id = num
	_next_id = max_id + 1


func _populate_list() -> void:
	_quest_list.clear()
	var ids: Array = _data.keys()
	ids.sort()
	for qid: String in ids:
		var q: Dictionary = _data[qid]
		_quest_list.add_item(q.get("display_name", qid))


func _on_quest_selected(idx: int) -> void:
	var ids: Array = _data.keys()
	ids.sort()
	if idx < 0 or idx >= ids.size():
		return
	_selected_id = ids[idx]
	_refresh_quest()


func _refresh_quest() -> void:
	if _selected_id == "" or not _data.has(_selected_id):
		_props_panel.visible = false
		_clear_graph()
		return
	_props_panel.visible = true
	var q: Dictionary = _data[_selected_id]

	_name_edit.text = q.get("display_name", "")
	_giver_edit.text = q.get("giver", "")
	_desc_edit.text = q.get("description", "")
	var prereqs: Array = q.get("prerequisites", [])
	_prereq_edit.text = ", ".join(prereqs)

	_rebuild_graph()


func _clear_graph() -> void:
	_graph.clear_connections()
	for node: GraphNode in _branch_nodes.values():
		_graph.remove_child(node)
		node.queue_free()
	_branch_nodes.clear()


func _rebuild_graph() -> void:
	_clear_graph()
	if _selected_id == "" or not _data.has(_selected_id):
		return
	var q: Dictionary = _data[_selected_id]
	var branches: Dictionary = q.get("branches", {})
	var x_offset: float = 0.0
	for branch_id: String in branches:
		var branch: Dictionary = branches[branch_id]
		var node := _create_branch_node(branch_id, branch)
		node.position_offset = Vector2(x_offset, 0)
		_graph.add_child(node)
		_branch_nodes[branch_id] = node
		x_offset += 320.0


func _create_branch_node(branch_id: String, branch: Dictionary) -> GraphNode:
	var node := GraphNode.new()
	node.title = branch_id
	node.name = "branch_%s" % branch_id

	# Branch display name
	var name_row := HBoxContainer.new()
	name_row.add_child(_label("ID: %s" % branch_id))
	node.add_child(name_row)

	# Objectives
	var obj_label := Label.new()
	obj_label.text = "Objectives:"
	obj_label.add_theme_font_size_override("font_size", 12)
	node.add_child(obj_label)

	var objectives: Array = branch.get("objectives", [])
	for obj: Dictionary in objectives:
		var obj_row := Label.new()
		var obj_type: String = obj.get("type", "")
		var obj_target: String = obj.get("id", obj.get("item", obj.get("npc", "")))
		var obj_count: int = int(obj.get("count", 1))
		obj_row.text = "  %s: %s ×%d" % [obj_type, obj_target, obj_count]
		obj_row.add_theme_font_size_override("font_size", 11)
		node.add_child(obj_row)

	# Rewards (from includes or direct)
	var rewards_label := Label.new()
	rewards_label.text = "Includes: %s" % str(branch.get("includes", []))
	rewards_label.add_theme_font_size_override("font_size", 11)
	node.add_child(rewards_label)

	return node


func _on_add_branch() -> void:
	if _selected_id == "" or not _data.has(_selected_id):
		return
	var q: Dictionary = _data[_selected_id]
	if not q.has("branches"):
		q["branches"] = {}
	var bid: String = "branch_%d" % _next_id
	_next_id += 1
	q["branches"][bid] = {"objectives": [], "includes": []}
	_mark_dirty()
	_rebuild_graph()


func _on_add() -> void:
	var new_id: String = "new_quest_%d" % _next_id
	_next_id += 1
	_data[new_id] = QuestRegistry.create_quest(new_id)
	_mark_dirty()
	_populate_list()
	# Select the new one
	var ids: Array = _data.keys()
	ids.sort()
	var idx: int = ids.find(new_id)
	if idx >= 0:
		_quest_list.select(idx)
		_on_quest_selected(idx)


func _on_delete() -> void:
	if _selected_id == "":
		return
	QuestRegistry.delete_quest(_selected_id)
	_data.erase(_selected_id)
	_selected_id = ""
	_mark_dirty()
	_populate_list()
	_props_panel.visible = false
	_clear_graph()


func _on_prop_changed(_new_text: String, field: String) -> void:
	if _selected_id == "" or not _data.has(_selected_id):
		return
	_data[_selected_id][field] = _new_text
	_mark_dirty()
	# Update list label
	_populate_list()


func _on_prereq_changed(text: String) -> void:
	if _selected_id == "" or not _data.has(_selected_id):
		return
	var arr: Array = []
	for p: String in text.split(","):
		var trimmed: String = p.strip_edges()
		if trimmed != "":
			arr.append(trimmed)
	_data[_selected_id]["prerequisites"] = arr
	_mark_dirty()


func _on_desc_changed() -> void:
	if _selected_id == "" or not _data.has(_selected_id):
		return
	_data[_selected_id]["description"] = _desc_edit.text
	_mark_dirty()


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		dirty_changed.emit()


func is_dirty() -> bool:
	return _dirty


func save() -> void:
	for qid: String in _data:
		QuestRegistry.save_quest(qid, _data[qid])
	_dirty = false
	dirty_changed.emit()


func revert() -> void:
	_data = QuestRegistry.get_raw_data().duplicate(true)
	_dirty = false
	dirty_changed.emit()
	_populate_list()
	_selected_id = ""
	_props_panel.visible = false
	_clear_graph()


func get_marks() -> Array:
	return []


func on_atlas_cell_clicked(_cell: Vector2i) -> void:
	pass
