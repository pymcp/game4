## Unit tests for the dialogue tree data layer (DialogueNode, DialogueChoice,
## DialogueTree) and the GameState autoload.
extends GutTest


# ─── DialogueNode / DialogueChoice / DialogueTree creation ─────────

func test_dialogue_node_creation() -> void:
	var node := DialogueNode.new()
	node.speaker = "TestNPC"
	node.text = "Hello, adventurer."
	assert_eq(node.speaker, "TestNPC")
	assert_eq(node.text, "Hello, adventurer.")
	assert_eq(node.choices.size(), 0)


func test_dialogue_choice_creation() -> void:
	var choice := DialogueChoice.new()
	choice.label = "Say hello"
	choice.stat_check = &"charisma"
	choice.stat_threshold = 5
	choice.set_flag = "greeted_npc"
	assert_eq(choice.label, "Say hello")
	assert_eq(choice.stat_check, &"charisma")
	assert_eq(choice.stat_threshold, 5)
	assert_eq(choice.set_flag, "greeted_npc")


func test_dialogue_tree_holds_root_node() -> void:
	var root := DialogueNode.new()
	root.speaker = "Root"
	root.text = "Root text"
	var tree := DialogueTree.new()
	tree.root = root
	assert_not_null(tree.root)
	assert_eq((tree.root as DialogueNode).speaker, "Root")
	root.free()


func test_choice_links_to_next_node() -> void:
	var leaf := DialogueNode.new()
	leaf.speaker = "NPC"
	leaf.text = "Thanks for helping!"
	var choice := DialogueChoice.new()
	choice.label = "Help out"
	choice.next_node = leaf
	assert_eq((choice.next_node as DialogueNode).text, "Thanks for helping!")
	leaf.free()


func test_choice_links_failure_node() -> void:
	var success := DialogueNode.new()
	success.speaker = "NPC"
	success.text = "Impressive!"
	var failure := DialogueNode.new()
	failure.speaker = "NPC"
	failure.text = "Not quite..."
	var choice := DialogueChoice.new()
	choice.label = "Try something"
	choice.stat_check = &"strength"
	choice.stat_threshold = 5
	choice.next_node = success
	choice.failure_node = failure
	assert_eq((choice.next_node as DialogueNode).text, "Impressive!")
	assert_eq((choice.failure_node as DialogueNode).text, "Not quite...")
	success.free()


# ─── Stat check logic (pure) ──────────────────────────────────────

func test_stat_check_pass() -> void:
	var choice := DialogueChoice.new()
	choice.stat_check = &"wisdom"
	choice.stat_threshold = 3
	var stats: Dictionary = { &"wisdom": 5 }
	var val: int = int(stats.get(choice.stat_check, 0))
	assert_true(val >= choice.stat_threshold, "should pass: 5 >= 3")


func test_stat_check_fail() -> void:
	var choice := DialogueChoice.new()
	choice.stat_check = &"wisdom"
	choice.stat_threshold = 6
	var stats: Dictionary = { &"wisdom": 3 }
	var val: int = int(stats.get(choice.stat_check, 0))
	assert_false(val >= choice.stat_threshold, "should fail: 3 < 6")


func test_stat_check_exact_threshold() -> void:
	var choice := DialogueChoice.new()
	choice.stat_check = &"charisma"
	choice.stat_threshold = 4
	var stats: Dictionary = { &"charisma": 4 }
	var val: int = int(stats.get(choice.stat_check, 0))
	assert_true(val >= choice.stat_threshold, "should pass at exact threshold")


func test_no_stat_check_always_passes() -> void:
	var choice := DialogueChoice.new()
	# stat_check is empty StringName
	var stats: Dictionary = {}
	var has_check: bool = choice.stat_check != &""
	assert_false(has_check, "empty stat_check means no check")


# ─── GameState autoload ───────────────────────────────────────────

func test_game_state_set_and_get_flag() -> void:
	GameState.clear_flags()
	assert_false(GameState.get_flag("test_flag"))
	GameState.set_flag("test_flag")
	assert_true(GameState.get_flag("test_flag"))
	GameState.clear_flags()


func test_game_state_has_all_flags() -> void:
	GameState.clear_flags()
	GameState.set_flag("a")
	GameState.set_flag("b")
	assert_true(GameState.has_all_flags(["a", "b"]))
	assert_false(GameState.has_all_flags(["a", "b", "c"]))
	GameState.clear_flags()


func test_game_state_clear_flags() -> void:
	GameState.set_flag("temp")
	assert_true(GameState.get_flag("temp"))
	GameState.clear_flags()
	assert_false(GameState.get_flag("temp"))


func test_game_state_to_dict_from_dict() -> void:
	GameState.clear_flags()
	GameState.set_flag("quest_started")
	GameState.set_flag("met_mara")
	var d: Dictionary = GameState.to_dict()
	assert_true(d.has("quest_started"))
	assert_true(d.has("met_mara"))
	GameState.clear_flags()
	assert_false(GameState.get_flag("quest_started"))
	GameState.from_dict(d)
	assert_true(GameState.get_flag("quest_started"))
	assert_true(GameState.get_flag("met_mara"))
	GameState.clear_flags()


# ─── Flag gating on choices ───────────────────────────────────────

func test_choice_require_flag_filters_when_unset() -> void:
	GameState.clear_flags()
	var choice := DialogueChoice.new()
	choice.label = "Gated option"
	choice.require_flag = "special_flag"
	# Simulate the filtering logic from DialogueBox._build_choices
	var visible: bool = choice.require_flag == "" or GameState.get_flag(choice.require_flag)
	assert_false(visible, "choice should be hidden when flag is unset")


func test_choice_require_flag_shows_when_set() -> void:
	GameState.clear_flags()
	GameState.set_flag("special_flag")
	var choice := DialogueChoice.new()
	choice.label = "Gated option"
	choice.require_flag = "special_flag"
	var visible: bool = choice.require_flag == "" or GameState.get_flag(choice.require_flag)
	assert_true(visible, "choice should be visible when flag is set")
	GameState.clear_flags()


# ─── Healer Mara .tres loads correctly ────────────────────────────

func test_healer_mara_tres_loads() -> void:
	var tree: DialogueTree = load("res://resources/dialogue/healer_mara.tres") as DialogueTree
	assert_not_null(tree, "healer_mara.tres should load as DialogueTree")
	assert_not_null(tree.root, "tree should have a root node")
	var root: DialogueNode = tree.root as DialogueNode
	assert_eq(root.speaker, "Mara")
	assert_true(root.text.length() > 0, "root text is non-empty")
	assert_eq(root.choices.size(), 3, "Mara has 3 root choices")


func test_healer_mara_root_choices_have_labels() -> void:
	var tree: DialogueTree = load("res://resources/dialogue/healer_mara.tres") as DialogueTree
	var root: DialogueNode = tree.root as DialogueNode
	for i in root.choices.size():
		var c: DialogueChoice = root.choices[i] as DialogueChoice
		assert_true(c.label.length() > 0, "choice %d has a label" % i)


func test_healer_mara_stat_checks_present() -> void:
	var tree: DialogueTree = load("res://resources/dialogue/healer_mara.tres") as DialogueTree
	var root: DialogueNode = tree.root as DialogueNode
	# First choice should have wisdom check, second charisma
	var c0: DialogueChoice = root.choices[0] as DialogueChoice
	var c1: DialogueChoice = root.choices[1] as DialogueChoice
	assert_eq(c0.stat_check, &"wisdom", "first choice checks wisdom")
	assert_eq(c1.stat_check, &"charisma", "second choice checks charisma")


func test_healer_mara_branching_depth() -> void:
	# Verify at least one branch goes two levels deep.
	var tree: DialogueTree = load("res://resources/dialogue/healer_mara.tres") as DialogueTree
	var root: DialogueNode = tree.root as DialogueNode
	var c0: DialogueChoice = root.choices[0] as DialogueChoice
	assert_not_null(c0.next_node, "first choice has a next_node")
	var lvl2: DialogueNode = c0.next_node as DialogueNode
	assert_true(lvl2.choices.size() > 0, "level-2 node has sub-choices")
