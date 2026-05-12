## seed_farmer_ren.gd
##
## Run once headless:
##   godot --headless -s tools/seed_farmer_ren.gd
##
## Builds and saves Farmer Ren's dialogue tree.
extends SceneTree


func _init() -> void:
	# ─── Post-Edda-quest ──────────────────────────────────────────────────
	var leaf_post_edda := _leaf("Ren",
		"That courier woman came by — asked the same questions you did. At least someone's paying attention. Maybe things will change.")

	# ─── Default (Edda's quest in progress or not started) ────────────────
	var leaf_default := _leaf("Ren",
		"My goat won't eat. Dog won't stop barking at the east pasture. Been like this since the mine started leaking again. Something's wrong with the land.")

	# ─── Root node — routes by phase ──────────────────────────────────────
	var root := DialogueNode.new()
	root.speaker = "Ren"
	root.text = "Aye?"
	root.choices = [
		_choice_require("How are your animals doing?", leaf_post_edda,
			"edda_quest_complete", ""),
		_choice_flag("How are your animals doing?", leaf_default,
			"farmer_ren_spoken"),
	]

	var tree: DialogueTree = DialogueTree.new()
	tree.root = root
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://resources/dialogue"))
	var err: int = ResourceSaver.save(tree, "res://resources/dialogue/farmer_ren.tres")
	if err == OK:
		print("OK -- saved res://resources/dialogue/farmer_ren.tres")
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
