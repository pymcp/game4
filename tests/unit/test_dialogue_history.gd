extends GutTest
## Unit tests for DialogueBox conversation history tracking.
## Instantiates a real DialogueBox scene and drives it programmatically.

var _box: DialogueBox = null


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/DialogueBox.tscn")
	_box = scene.instantiate() as DialogueBox
	add_child_autofree(_box)
	await get_tree().process_frame


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_tree(speaker: String, body: String) -> DialogueTree:
	var node := DialogueNode.new()
	node.speaker = speaker
	node.text = body
	var tree := DialogueTree.new()
	tree.root = node
	return tree


func _make_tree_with_choice(label: String) -> DialogueTree:
	var choice := DialogueChoice.new()
	choice.label = label
	var node := DialogueNode.new()
	node.speaker = "Test NPC"
	node.text = "What do you want?"
	node.choices = [choice]
	var tree := DialogueTree.new()
	tree.root = node
	return tree


# ─── Tests ────────────────────────────────────────────────────────────────────

func test_begin_conversation_resets_history() -> void:
	# Put something in history first.
	_box._node_history.append({"speaker": "old", "text": "old", "choices_shown": [], "choice_made": null})
	var tree := _make_tree("Mara", "Hello!")
	_box.begin_conversation(tree, {}, "Mara")
	assert_eq(_box._node_history.size(), 1, "History should be reset to 1 entry")


func test_show_node_appends_to_history() -> void:
	var tree := _make_tree("Guard", "Stop right there!")
	_box.begin_conversation(tree, {}, "Guard")
	assert_eq(_box._node_history.size(), 1, "One node shown → one history entry")
	assert_eq(_box._node_history[0]["speaker"], "Guard")
	assert_eq(_box._node_history[0]["text"], "Stop right there!")


func test_begin_conversation_stores_npc_name() -> void:
	var tree := _make_tree("Innkeeper", "Welcome!")
	_box.begin_conversation(tree, {}, "Innkeeper")
	assert_eq(_box._npc_name, "Innkeeper")


func test_history_choice_made_initially_null() -> void:
	var tree := _make_tree_with_choice("Ask about quest")
	_box.begin_conversation(tree, {}, "NPC")
	assert_null(_box._node_history[0]["choice_made"], "choice_made should be null before selection")


func test_pick_choice_records_choice_label() -> void:
	var tree := _make_tree_with_choice("Buy herbs")
	_box.begin_conversation(tree, {}, "Herbalist")
	# Simulate picking choice 0.
	_box._pick_choice(0)
	assert_eq(_box._node_history[0]["choice_made"], "Buy herbs",
		"choice_made should record the label")


func test_flags_set_recorded() -> void:
	var choice := DialogueChoice.new()
	choice.label = "I'll help"
	choice.set_flag = "quest_help_started"
	var node := DialogueNode.new()
	node.speaker = "Elder"
	node.text = "Will you help us?"
	node.choices = [choice]
	var tree := DialogueTree.new()
	tree.root = node
	_box.begin_conversation(tree, {}, "Elder")
	_box._pick_choice(0)
	assert_true(_box._conversation_flags_set.has("quest_help_started"),
		"Flag set via choice should appear in conversation_flags_set")
