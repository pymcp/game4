## seed_healer_mara.gd
##
## Run once headless:
##   godot --headless -s tools/seed_healer_mara.gd
##
## Builds and saves Mara the Herbalist's dialogue tree.
extends SceneTree


func _init() -> void:
	# ─── Phase 4: post-completion ──────────────────────────────────────────
	var leaf_complete := _leaf("Mara",
		"The valley's breathing easier. Whatever was in that ore, you stopped it from spreading further. Come back when you need a tonic -- I'll always have one ready for you.")

	# ─── Phase 3: herbs gathering (evidence shown, quest not yet complete) ──
	var herbs_return := _leaf("Mara",
		"This ore -- I can smell the contamination from here. Moonstone residue, just as I suspected. To brew the remedy I need three things: fennel root from along the riverbank, a blue nightcap mushroom -- they grow in shaded spots -- and clean spring water. Not from the village well; it's still tainted. There's a spring to the southwest, past the old stone marker.")

	# ─── Phase 2: mine reminder (quest started, evidence not yet shown) ─────
	var mine_reminder := _leaf("Mara",
		"The mine entrance is east of the birch grove. The sick wolves are still prowling nearby -- don't let them surround you. Find what's leaking inside, seal it, and bring back a piece of the ore. Come back to me when you have it.")

	# ─── Terminal leaves ───────────────────────────────────────────────────
	var leaf_accept := _leaf("Mara",
		"East of here, past the birch grove. The mine entrance is hard to miss -- there are sick wolves nearby, so stay ready. Find the leak, seal it, and bring back a piece of the ore. Come back to me when you have it.")

	var leaf_accept_deal := _leaf("Mara",
		"East of here, past the birch grove. Sick wolves near the entrance, so stay sharp. Find the leak, seal it, bring back ore. I'll have your tonic waiting.")

	var leaf_soft_decline := _leaf("Mara",
		"The offer stands. I'm here if you change your mind.")

	var leaf_walk := _leaf("Mara",
		"Then animals keep dying. I hope you sleep well, traveller.")

	var leaf_passing := _leaf("Mara",
		"Then at least be careful east of the birch grove. The wolves there don't behave as wolves should. If you reconsider, you know where to find me.")

	var leaf_push_fail := _leaf("Mara",
		"That recipe is all that's standing between this valley and a real outbreak. The tonic is my offer -- take it or leave it.")

	# ─── CHA≥5 push path (shared by explain and deal paths) ───────────────
	# quest_herbalist_pushed_deal already set by the choice that leads here;
	# this node sets quest_herbalist_main when the player formally accepts.
	var push_node := DialogueNode.new()
	push_node.speaker = "Mara"
	push_node.text = "A hard bargain -- but you've got nerve. Bring me the ore from the mine and I'll give you both the tonic and my antidote recipe. Don't take too long."
	push_node.choices = [
		_choice_flag("Deal. I'll get the ore.", leaf_accept, "quest_herbalist_main"),
	]

	# ─── Task node: what the player needs to do ────────────────────────────
	var task_node := DialogueNode.new()
	task_node.speaker = "Mara"
	task_node.text = "Get into the mine east of here, find what's leaking, and seal it if you can. Then bring me a piece of the contaminated ore -- I need it to identify the compound and brew the antidote. I'll give you one of my tonics as payment. Worth more than most coin on the road."
	task_node.choices = [
		_choice_flag("I'll do it.", leaf_accept, "quest_herbalist_main"),
		_choice_stat_flag(&"charisma", 5, "A tonic isn't enough. I want your recipe too.",
			push_node, leaf_push_fail, "quest_herbalist_pushed_deal"),
		_choice("I'll think about it.", leaf_soft_decline),
	]

	# ─── Explain paths ─────────────────────────────────────────────────────
	# WIS≥3: player noticed something was off before she asked.
	var explain_wise := DialogueNode.new()
	explain_wise.speaker = "Mara"
	explain_wise.text = "So you've noticed too. Good -- I thought I was overreacting. I'm an herbalist; I've been studying this for weeks. The well water has a mineral residue that only comes from moonstone ore. The old mine east of here was sealed twenty years ago, but seals fail. Something's broken through and it's poisoning the groundwater."
	explain_wise.choices = [
		_choice("What do you need from me?", task_node),
		_choice("That's not my problem.", leaf_walk),
	]

	# Neutral: player had no idea.
	var explain_neutral := DialogueNode.new()
	explain_neutral.speaker = "Mara"
	explain_neutral.text = "I'm an herbalist. I've been in this valley most of my life and I've never seen animals behave like this. The well water tastes wrong too -- I've been testing it. I think it's coming from the old moonstone mine east of here. Something's breached the old seal and it's leaking into the groundwater. I need someone who can get inside and stop it."
	explain_neutral.choices = [
		_choice("What do you need me to do?", task_node),
		_choice("That's not my problem.", leaf_walk),
	]

	# ─── CHA≥3 deal path ──────────────────────────────────────────────────
	var deal_d2 := DialogueNode.new()
	deal_d2.speaker = "Mara"
	deal_d2.text = "More than fair to ask. There's something wrong in this valley -- animals going feral, the well water tainted -- and I think it traces back to the old moonstone mine east of here. I need someone to get inside, find what's leaking, and bring me contaminated ore so I can brew an antidote. I'll pay in tonics. I brew them myself; they strengthen the body in ways coin rarely does."
	deal_d2.choices = [
		_choice_flag("Fair enough. Where's this mine?", leaf_accept_deal, "quest_herbalist_main"),
		_choice_stat_flag(&"charisma", 5, "A tonic alone isn't enough. I want the recipe too.",
			push_node, leaf_push_fail, "quest_herbalist_pushed_deal"),
		_choice("Not worth my time.", leaf_walk),
	]

	# ─── Root node ────────────────────────────────────────────────────────
	# Mara flags the player down; routes by phase on return visits.
	var root := DialogueNode.new()
	root.speaker = "Mara"
	root.text = "Traveller -- a moment. You look like you've been through the wilds. Have you seen anything strange east of here? Animals acting wrong -- wolves that won't back down, livestock that won't eat?"
	root.choices = [
		# Return-visit phase routing (shown in place of the intro choices).
		_choice_require("How is the valley doing?", leaf_complete,
			"quest_herbalist_remedy_complete", ""),
		_choice_require("I have the herbs and water you asked for.", herbs_return,
			"quest_herbalist_remedy_obj_show_evidence_done",
			"quest_herbalist_remedy_complete"),
		_choice_require("I haven't reached the mine yet.", mine_reminder,
			"quest_herbalist_main",
			"quest_herbalist_remedy_obj_show_evidence_done"),
		# First-encounter choices (hidden once quest_herbalist_main is set).
		_choice_stat_intro(&"wisdom", 3,
			"Now that you mention it -- yes. What's going on?", explain_wise),
		_choice_intro("Can't say I have. What's wrong?", explain_neutral),
		_choice_stat_intro(&"charisma", 3,
			"Depends. Are you offering something for looking into it?", deal_d2),
		_choice_intro("I'm just passing through.", leaf_passing),
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
