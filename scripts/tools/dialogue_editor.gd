## DialogueEditor
##
## Sub-editor for dialogue trees using a GraphEdit-based visual editor.
## Left panel: dialogue tree list (scans resources/dialogue/*.tres).
## Right: GraphEdit with DialogueNode graph nodes.
class_name DialogueEditor
extends VBoxContainer

signal dirty_changed

var sheet_path: String = ""
var _dirty: bool = false
var _trees: Dictionary = {}  # filename -> DialogueTree resource
var _selected_file: String = ""
var _next_node_id: int = 0

# UI
var _split: HSplitContainer
var _tree_list: ItemList
var _add_btn: Button
var _del_btn: Button
var _graph: GraphEdit
var _graph_nodes: Dictionary = {}  # node_key -> GraphNode

const _DIR: String = "res://resources/dialogue"


func _ready() -> void:
	_build_ui()
	_scan_trees()
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

	_tree_list = ItemList.new()
	_tree_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree_list.item_selected.connect(_on_tree_selected)
	left.add_child(_tree_list)

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

	# Right: graph
	_graph = GraphEdit.new()
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(_graph)


func _scan_trees() -> void:
	_trees.clear()
	var dir := DirAccess.open(_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var path: String = _DIR.path_join(fname)
			var res: Resource = ResourceLoader.load(path)
			if res is DialogueTree:
				_trees[fname] = res
		fname = dir.get_next()
	dir.list_dir_end()


func _populate_list() -> void:
	_tree_list.clear()
	var files: Array = _trees.keys()
	files.sort()
	for f: String in files:
		_tree_list.add_item(f.get_basename())


func _on_tree_selected(idx: int) -> void:
	var files: Array = _trees.keys()
	files.sort()
	if idx < 0 or idx >= files.size():
		return
	_selected_file = files[idx]
	_rebuild_graph()


func _clear_graph() -> void:
	_graph.clear_connections()
	for node: GraphNode in _graph_nodes.values():
		_graph.remove_child(node)
		node.queue_free()
	_graph_nodes.clear()
	_next_node_id = 0


func _rebuild_graph() -> void:
	_clear_graph()
	if _selected_file == "" or not _trees.has(_selected_file):
		return
	var tree: DialogueTree = _trees[_selected_file]
	if tree.root == null:
		return
	_layout_node(tree.root, 0, 0)


func _layout_node(dnode: DialogueNode, depth: int, index: int) -> String:
	if dnode == null:
		return ""
	var key: String = "node_%d" % _next_node_id
	_next_node_id += 1

	var gnode := GraphNode.new()
	gnode.title = dnode.speaker if dnode.speaker != "" else "(no speaker)"
	gnode.name = key
	gnode.position_offset = Vector2(depth * 350.0, index * 200.0)

	# Text
	var text_label := Label.new()
	text_label.text = dnode.text.substr(0, 80) + ("..." if dnode.text.length() > 80 else "")
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.custom_minimum_size.x = 250
	gnode.add_child(text_label)

	# Condition flags
	if dnode.condition_flag != "":
		var flag_label := Label.new()
		flag_label.text = "IF: %s" % dnode.condition_flag
		flag_label.add_theme_font_size_override("font_size", 11)
		gnode.add_child(flag_label)
	if dnode.condition_flag_false != "":
		var flag_label := Label.new()
		flag_label.text = "IF NOT: %s" % dnode.condition_flag_false
		flag_label.add_theme_font_size_override("font_size", 11)
		gnode.add_child(flag_label)

	# Choices
	var child_idx: int = 0
	for choice: DialogueChoice in dnode.choices:
		var choice_label := Label.new()
		var extra: String = ""
		if choice.stat_check != &"":
			extra = " [%s >= %d]" % [choice.stat_check, choice.stat_threshold]
		if choice.set_flag != "":
			extra += " → SET %s" % choice.set_flag
		choice_label.text = "→ %s%s" % [choice.label, extra]
		choice_label.add_theme_font_size_override("font_size", 11)
		gnode.add_child(choice_label)

		# Recurse into next_node
		if choice.next_node != null and choice.next_node is DialogueNode:
			var child_key: String = _layout_node(choice.next_node, depth + 1, child_idx)
			if child_key != "":
				# We'll connect after adding to graph
				call_deferred("_connect_nodes", key, 0, child_key, 0)
		if choice.failure_node != null and choice.failure_node is DialogueNode:
			var fail_key: String = _layout_node(choice.failure_node, depth + 1, child_idx + 1)
			if fail_key != "":
				call_deferred("_connect_nodes", key, 0, fail_key, 0)
			child_idx += 1
		child_idx += 1

	_graph.add_child(gnode)
	_graph_nodes[key] = gnode
	return key


func _connect_nodes(from_key: String, from_port: int, to_key: String, to_port: int) -> void:
	if _graph_nodes.has(from_key) and _graph_nodes.has(to_key):
		_graph.connect_node(from_key, from_port, to_key, to_port)


func _on_add() -> void:
	var new_name: String = "new_dialogue_%d" % _next_node_id
	_next_node_id += 1
	var tree := DialogueTree.new()
	var root := DialogueNode.new()
	root.speaker = "NPC"
	root.text = "Hello!"
	tree.root = root
	var fname: String = new_name + ".tres"
	var path: String = _DIR.path_join(fname)
	ResourceSaver.save(tree, path)
	_trees[fname] = tree
	_mark_dirty()
	_populate_list()


func _on_delete() -> void:
	if _selected_file == "":
		return
	var path: String = _DIR.path_join(_selected_file)
	DirAccess.remove_absolute(path)
	_trees.erase(_selected_file)
	_selected_file = ""
	_mark_dirty()
	_populate_list()
	_clear_graph()


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		dirty_changed.emit()


func is_dirty() -> bool:
	return _dirty


func save() -> void:
	for fname: String in _trees:
		var path: String = _DIR.path_join(fname)
		ResourceSaver.save(_trees[fname], path)
	_dirty = false
	dirty_changed.emit()


func revert() -> void:
	_scan_trees()
	_dirty = false
	dirty_changed.emit()
	_populate_list()
	_selected_file = ""
	_clear_graph()


func get_marks() -> Array:
	return []


func on_atlas_cell_clicked(_cell: Vector2i) -> void:
	pass
