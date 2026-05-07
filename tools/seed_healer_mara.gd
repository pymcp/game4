## seed_healer_mara.gd
##
## Run once headless:
##   godot --headless -s tools/seed_healer_mara.gd
##
## Builds and saves Mara the Herbalist's dialogue tree.
extends SceneTree


func _init() -> void:
	# Phase 4 -- post-completion
	var leaf_complete := _leaf("Mara",
		"The valley owes you a debt it can never repay. The animals are recovering and the water runs clear again. If you ever need a tonic, you know where to find me.")

	# Phase 3 -- herbs gathering (show_evidence done this visit, not yet complete)
	var herbs_return := _leaf("Mara",
		"Yes! This ore is saturated with corrupted moonstone residue -- just as I feared. I need fennel root, a blue nightcap mushroom, and clean spring water -- not from the village well. The spring east of the birch grove is safe.")

	# Phase 2 -- mine phase (quest started, evidence not yet collected)
	var mine_reminder := _leaf("Mara",
		"The mine entrance is east of here, past the birch grove. Watch for sick wolves -- they don't run from people anymore. Seal whatever is leaking and bring back a piece of contaminated ore as proof.")

	# Phase 1 -- intro terminal leaves
	var leaf_clue := _leaf("Mara",
		"The sickness started near the old mine in the eastern hills. Something seeped into the groundwater. If you go there, be careful -- the animals nearby have gone feral.")

	var leaf_clue_herb := _leaf("Mara",
		"I've been studying the well water. There's a strange residue -- almost like crushed moonstone. The mine used to produce that before it was abandoned. That's your lead.")

	var leaf_clue_doubt := _leaf("Mara",
		"I understand your scepticism. But three villages have lost livestock this moon alone. If you change your mind, you know where to find me.")

	var leaf_accept := _leaf("Mara",
		"Then go -- east past the birch grove. The mine entrance is hard to miss. Come back with ore from inside and I'll know what we're dealing with.")

	var leaf_accept_deal := _leaf("Mara",
		"Fair enough. Bring me proof from the mine -- a piece of contaminated ore -- and I'll craft you a tonic that'll make you tougher than boiled leather.")

	var leaf_accept_push := _leaf("Mara",
		"You drive a hard bargain, traveller. Fine -- bring evidence from the mine and I'll give you my last bottled antidote AND the tonic recipe. But don't dawdle.")

	var leaf_reward_walk := _leaf("Mara",
		"Then we have nothing more to discuss. The animals keep dying and you want coin. I hope your conscience catches up with you.")

	# -- Wisdom path --
	var know_d2 := DialogueNode.new()
	know_d2.speaker = "Mara"
	know_d2.text = "I've traced it to the water. Every sick animal drinks from streams fed by the eastern hills. The old moonstone mine was sealed twenty years ago, but something's broken through."
	know_d2.choices = [
		_choice("Where exactly is this mine?", leaf_clue),
		_choice_stat(&"wisdom", 4, "Could the ore itself be toxic?",
			leaf_clue_herb,
			_leaf("Mara", "Hmm, I'm not sure what you mean. But the mine is east of here, past the birch grove. Start there.")),
		_choice("I'm not sure I believe that.", leaf_clue_doubt),
	]

	# -- Charisma path --
	var deal_d2 := DialogueNode.new()
	deal_d2.speaker = "Mara"
	deal_d2.text = "I don't have much gold, but I can offer something better. I brew tonics that'll harden your skin and sharpen your senses. One batch is worth more than a sack of coin."
	deal_d2.choices = [
		_choice_flag("Sounds fair. What exactly do you need?", leaf_accept_deal, "quest_herbalist_main"),
		_choice_stat_flag(&"charisma", 5, "I want the tonic AND your antidote recipe.",
			leaf_accept_push,
			_leaf("Mara", "That's too much to ask. The tonic or nothing, traveller."),
			"quest_herbalist_pushed_deal"),
		_choice("Forget it, I'm not doing charity work.", leaf_reward_walk),
	]

	# -- Help path --
	var help_d2 := DialogueNode.new()
	help_d2.speaker = "Mara"
	help_d2.text = "The old moonstone mine east of here is the source. Something's leaking into the groundwater. If you get in there, seal the leak, and bring back contaminated ore, I can work out the antidote."
	help_d2.choices = [
		_choice_flag("I'll investigate the mine.", leaf_accept, "quest_herbalist_main"),
	]

	# -- Root: phase router --
	var root := DialogueNode.new()
	root.speaker = "Mara"
	root.text = "Ah, traveller! What brings you back to old Mara?"
	root.choices = [
		_choice_require("How is the valley doing?", leaf_complete,
			"quest_herbalist_remedy_complete", ""),
		_choice_require("Here are the herbs and water you asked for.", herbs_return,
			"quest_herbalist_remedy_obj_show_evidence_done",
			"quest_herbalist_remedy_complete"),
		_choice_require("I'm on my way to the mine.", mine_reminder,
			"quest_herbalist_main",
			"quest_herbalist_remedy_obj_show_evidence_done"),
		_choice_stat_intro(&"wisdom", 3,
			"What do you know about the cause of this sickness?", know_d2),
		_choice_stat_intro(&"charisma", 3,
			"I might help -- but what's in it for me?", deal_d2),
		_choice_intro("Tell me what you need. I'm here to help.", help_d2),
	]

	var tree: DialogueTree = DialogueTree.new()
	tree.root = root
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://resources/dialogue"))
	var err: int = ResourceSaver.save(tree, "res://resources/dialogue/healer_mara.tres")
	if err == OK:
		print("OK -- saved res://resources/dialogue/healer_mara.tres")
	else:
		push_error("Failed to save: error %d" % err)
	quit()


func _leaf(speaker: String, text: String) -> DialogueNode:
	var n: DialogueNode = DialogueNode.new()
	n.speaker = speaker
	n.text = text
	return n


func _choice(label: String, next: DialogueNode) -> DialogueChoice:
	var c: DialogueChoice = DialogueChoice.new()
	c.label = label
	c.next_node = next
	return c


func _choice_flag(label: String, next: DialogueNode, flag: String) -> DialogueChoice:
	var c: DialogueChoice = DialogueChoice.new()
	c.label = label
	c.next_node = next
	c.set_flag = flag
	return c


func _choice_stat(stat: StringName, threshold: int, label: String,
		success: DialogueNode, failure: DialogueNode) -> DialogueChoice:
	var c: DialogueChoice = DialogueChoice.new()
	c.label = label
	c.stat_check = stat
	c.stat_threshold = threshold
	c.next_node = success
	if failure != null:
		c.failure_node = failure
	return c


func _choice_stat_flag(stat: StringName, threshold: int, label: String,
		success: DialogueNode, failure: DialogueNode,
		flag: String) -> DialogueChoice:
	var c: DialogueChoice = DialogueChoice.new()
	c.label = label
	c.stat_check = stat
	c.stat_threshold = threshold
	c.next_node = success
	if failure != null:
		c.failure_node = failure
	c.set_flag = flag
	return c


func _choice_require(label: String, next: DialogueNode,
		require: String, require_false: String) -> DialogueChoice:
	var c: DialogueChoice = DialogueChoice.new()
	c.label = label
	c.next_node = next
	c.require_flag = require
	c.require_flag_false = require_false
	return c


func _choice_intro(label: String, next: DialogueNode) -> DialogueChoice:
	var c: DialogueChoice = DialogueChoice.new()
	c.label = label
	c.next_node = next
	c.require_flag_false = "quest_herbalist_main"
	return c


func _choice_stat_intro(stat: StringName, threshold: int, label: String,
		next: DialogueNode) -> DialogueChoice:
	var c: DialogueChoice = DialogueChoice.new()
	c.label = label
	c.stat_check = stat
	c.stat_threshold = threshold
	c.next_node = next
	c.require_flag_false = "quest_herbalist_main"
	return c
