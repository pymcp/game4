## seed_edda_courier.gd
##
## Run once headless:
##   godot --headless -s tools/seed_edda_courier.gd
##
## Builds and saves Edda the Courier's dialogue tree.
extends SceneTree


func _init() -> void:
	# ─── Post-completion (return visit) ───────────────────────────────────
	var leaf_return := _leaf("Edda",
		"I'll be moving on soon. Safe roads to you, traveller.")

	# ─── Completion: names Aldric + Tidehaven ─────────────────────────────
	var leaf_complete := _leaf("Edda",
		"The well, the farm, the mine — it's the same story I've heard in a dozen valleys. Something is wrong with the land here, and it's not local. If you're ever heading east, find the docks at Tidehaven. Ask for Aldric Farrow. He knows those waters better than anyone alive. Tell him Edda sent you.")

	# ─── Mid-quest reminder (quest started, not yet returned) ─────────────
	var leaf_mid := _leaf("Edda",
		"I still need both: what you saw at the well, and what the farmer told you. Come back when you have both.")

	# ─── Farmer is done, just need return ────────────────────────────────
	var leaf_ready_return := _leaf("Edda",
		"Good. Now I just need you to tell me what you found. Let's compare notes.")

	# ─── Task node ────────────────────────────────────────────────────────
	var task_node := DialogueNode.new()
	task_node.speaker = "Edda"
	task_node.text = "Two things: examine the village well and tell me what you smell on the water, then find whoever farms nearest to the mine and ask them what's changed with their animals. I'll wait here."
	task_node.choices = [
		_choice_flag("Understood. I'll get both.", leaf_mid, "quest_valley_witness_main"),
		_choice("What's in it for me?", _leaf("Edda",
			"Information. The kind that might keep you alive east of here. Now go.")),
	]

	# ─── Intro ────────────────────────────────────────────────────────────
	var intro_node := DialogueNode.new()
	intro_node.speaker = "Edda"
	intro_node.text = "You. You've come through the wilds recently — I can tell. I've been mapping this sickness across a dozen regions. It's always the same: animals go feral near old mines, the water turns, the farmers start losing livestock. I need this valley documented before I move on. You can help."
	intro_node.choices = [
		_choice("What do you need?", task_node),
		_choice("I'm not interested.", _leaf("Edda",
			"Your loss. The valley will be worse off for it.")),
	]

	# ─── Root node — routes by phase ──────────────────────────────────────
	var root := DialogueNode.new()
	root.speaker = "Edda"
	root.text = "The water in that well tastes wrong. You've noticed, haven't you?"
	root.choices = [
		# Return-visit phase routing.
		_choice_require("Anything else I should know?", leaf_return,
			"edda_quest_complete", ""),
		_choice_require("I've checked the well and spoken to the farmer.", leaf_complete,
			"quest_valley_witness_obj_speak_farmer_done",
			"edda_quest_complete"),
		_choice_require("I spoke to the farmer, but haven't checked the well yet.", leaf_mid,
			"quest_valley_witness_obj_speak_farmer_done",
			"quest_valley_witness_obj_examine_well_done"),
		_choice_require("I checked the well, but haven't spoken to the farmer yet.", leaf_mid,
			"quest_valley_witness_obj_examine_well_done",
			"quest_valley_witness_obj_speak_farmer_done"),
		_choice_require("I'm still working on it.", leaf_mid,
			"quest_valley_witness_main",
			"edda_quest_complete"),
		# First-encounter choices (hidden once quest started).
		_choice_intro("Yes — what's going on?", intro_node),
		_choice_intro("I can't say I have.", intro_node),
	]

	var tree: DialogueTree = DialogueTree.new()
	tree.root = root
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://resources/dialogue"))
	var err: int = ResourceSaver.save(tree, "res://resources/dialogue/edda_courier.tres")
	if err == OK:
		print("OK -- saved res://resources/dialogue/edda_courier.tres")
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
	c.require_flag_false = "quest_valley_witness_main"
	return c
