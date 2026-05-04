## seed_healer_mara.gd
##
## Run once headless:
##   godot --headless -s tools/seed_healer_mara.gd
##
## Builds and saves Mara the Herbalist's dialogue tree to
## `res://resources/dialogue/healer_mara.tres`.
##
## The tree has 3 layers:
##   1. Router root — checks quest_herbalist_remedy_complete, then quest_started
##   2. Initial conversation — intro → knowledge/deal/help → quest start
##   3. Return-visit leaves — branch-specific completion dialogue
extends SceneTree


func _init() -> void:
	# ════════════════════════════════════════════════════════════════════
	# POST-COMPLETION (quest done)
	# ════════════════════════════════════════════════════════════════════
	var leaf_complete := DialogueNode.new()
	leaf_complete.speaker = "Mara"
	leaf_complete.text = "The valley owes you a debt it can never repay. The animals are recovering and the water runs clear again. If you ever need a tonic, you know where to find me."
	leaf_complete.condition_flag = "quest_herbalist_remedy_complete"

	# ════════════════════════════════════════════════════════════════════
	# RETURN-VISIT (quest in progress)
	# ════════════════════════════════════════════════════════════════════
	# Return: herbs branch active
	var return_herbs := DialogueNode.new()
	return_herbs.speaker = "Mara"
	return_herbs.text = "You're back! Have you found the herbs I need? Fennel root, blue nightcap mushrooms, and clean spring water. The valley grows sicker by the day."
	return_herbs.condition_flag = "quest_herbalist_herbs"
	return_herbs.condition_flag_false = "quest_herbalist_remedy_complete"

	# Return: mine branch active
	var return_mine := DialogueNode.new()
	return_mine.speaker = "Mara"
	return_mine.text = "The mine entrance is east of here. Seal whatever is leaking down there and bring back proof — a piece of that contaminated ore. Be careful."
	return_mine.condition_flag = "quest_herbalist_mine"
	return_mine.condition_flag_false = "quest_herbalist_remedy_complete"

	# Return: both branch active
	var return_both := DialogueNode.new()
	return_both.speaker = "Mara"
	return_both.text = "You've taken on quite a task! The herbs — fennel root, blue nightcap, and spring water — and sealing the mine. The valley is counting on you."
	return_both.condition_flag = "quest_herbalist_both"
	return_both.condition_flag_false = "quest_herbalist_remedy_complete"

	# ════════════════════════════════════════════════════════════════════
	# INITIAL CONVERSATION (quest not yet started)
	# ════════════════════════════════════════════════════════════════════
	var leaf_clue := DialogueNode.new()
	leaf_clue.speaker = "Mara"
	leaf_clue.text = "The sickness started near the old mine in the eastern hills. Something seeped into the groundwater. If you go there, be careful — the animals nearby have gone feral."

	var leaf_clue_herb := DialogueNode.new()
	leaf_clue_herb.speaker = "Mara"
	leaf_clue_herb.text = "I've been studying the well water. There's a strange residue — almost like crushed moonstone. The mine used to produce that before it was abandoned. That's your lead."

	var leaf_clue_doubt := DialogueNode.new()
	leaf_clue_doubt.speaker = "Mara"
	leaf_clue_doubt.text = "I understand your scepticism. But three villages have lost livestock this moon alone. If you change your mind, you know where to find me."

	var leaf_reward_deal := DialogueNode.new()
	leaf_reward_deal.speaker = "Mara"
	leaf_reward_deal.text = "Fair enough. Bring me proof from the mine — a water sample or a piece of the contaminated ore — and I'll craft you a tonic that'll make you tougher than boiled leather."

	var leaf_reward_push := DialogueNode.new()
	leaf_reward_push.speaker = "Mara"
	leaf_reward_push.text = "You drive a hard bargain, traveller. Fine — bring evidence from the mine and I'll give you my last bottled antidote AND the tonic recipe. But don't dawdle."

	var leaf_reward_walk := DialogueNode.new()
	leaf_reward_walk.speaker = "Mara"
	leaf_reward_walk.text = "Then we have nothing more to discuss. The animals keep dying and you want coin. I hope your conscience catches up with you."

	var leaf_help_gather := DialogueNode.new()
	leaf_help_gather.speaker = "Mara"
	leaf_help_gather.text = "Bless you. I need fennel root, blue nightcap mushrooms, and clean spring water — not from the village well. Bring them to me and I can brew enough remedy for the whole valley."

	var leaf_help_mine := DialogueNode.new()
	leaf_help_mine.speaker = "Mara"
	leaf_help_mine.text = "That's brave of you. The mine entrance is east past the birch grove. Watch for sick wolves — they don't run from people anymore. Seal whatever is leaking and the water should clear within a fortnight."

	var leaf_help_both := DialogueNode.new()
	leaf_help_both.speaker = "Mara"
	leaf_help_both.text = "You'd do both? Stars above, you might just save this valley. Gather the herbs first — I'll need the remedy ready before you stir up whatever's in that mine."

	# ── Depth-2 nodes (responses to depth-1 choices) ──────────────────

	# -- Knowledge path depth 2 --
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

	# -- Negotiation path depth 2 --
	var deal_d2 := DialogueNode.new()
	deal_d2.speaker = "Mara"
	deal_d2.text = "I don't have much gold, but I can offer something better. I brew tonics that'll harden your skin and sharpen your senses. One batch is worth more than a sack of coin."
	deal_d2.choices = [
		_choice_flag("Sounds fair. What do you need?", leaf_reward_deal, "quest_herbalist_mine"),
		_choice_stat(&"charisma", 5, "I want the tonic AND your antidote recipe.",
			leaf_reward_push,
			_leaf("Mara", "That's too much to ask. The tonic or nothing, traveller."),
			"quest_herbalist_mine"),
		_choice("Forget it, I'm not doing charity work.", leaf_reward_walk),
	]

	# -- Help path depth 2 --
	var help_d2 := DialogueNode.new()
	help_d2.speaker = "Mara"
	help_d2.text = "Two things would help most: I need rare herbs for the remedy, and someone brave enough to investigate that mine. The herbs I can point you to. The mine... that's dangerous."
	help_d2.choices = [
		_choice_flag("I'll gather the herbs.", leaf_help_gather, "quest_herbalist_herbs"),
		_choice_flag("I'll check out the mine.", leaf_help_mine, "quest_herbalist_mine"),
		_choice_stat(&"strength", 4, "I'll do both — herbs and the mine.",
			leaf_help_both,
			_leaf("Mara", "I admire the spirit, but you'd need to be stronger for that. Pick one for now — herbs or the mine."),
			"quest_herbalist_both"),
	]

	# ── Intro root ────────────────────────────────────────────────────
	var intro := DialogueNode.new()
	intro.speaker = "Mara"
	intro.text = "Traveller! Thank the stars someone's come. The Quiet Sickness is spreading — cattle dropping, dogs going blind, even the wild rabbits are wasting away. I'm running out of remedies and running out of time. Can you help?"
	intro.condition_flag_false = "quest_herbalist_remedy_started"
	intro.choices = [
		_choice_stat(&"wisdom", 3, "What do you know about the cause?", know_d2, null),
		_choice_stat(&"charisma", 3, "I might help — but what's in it for me?", deal_d2, null),
		_choice("Tell me what you need. I'm here to help.", help_d2),
	]

	# ── Router root ───────────────────────────────────────────────────
	# Choices are flag-gated so only relevant options appear.
	# After quest completion, _try_quest_turn_in() fires before dialogue
	# opens, so quest_herbalist_remedy_complete is already set.
	var root := DialogueNode.new()
	root.speaker = "Mara"
	root.text = "Ah, traveller! What brings you back to old Mara?"
	root.choices = [
		# Post-completion (only visible after quest is done)
		_choice_require("How is the valley doing?", leaf_complete, "quest_herbalist_remedy_complete"),
		# Return-visit: herbs branch in progress
		_choice_require("I'm still gathering the herbs.", return_herbs, "quest_herbalist_herbs"),
		# Return-visit: mine branch in progress
		_choice_require("I'm working on the mine.", return_mine, "quest_herbalist_mine"),
		# Return-visit: both branch in progress
		_choice_require("I'm working on it — both tasks.", return_both, "quest_herbalist_both"),
		# Initial conversation (only when quest NOT started)
		_choice_stat(&"wisdom", 3, "What do you know about the cause?", know_d2, null),
		_choice_stat(&"charisma", 3, "I might help — but what's in it for me?", deal_d2, null),
		_choice("Tell me what you need. I'm here to help.", help_d2),
	]

	# ── Tree wrapper ──────────────────────────────────────────────────
	var tree := DialogueTree.new()
	tree.root = root

	# ── Save ──────────────────────────────────────────────────────────
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://resources/dialogue"))
	var err: int = ResourceSaver.save(tree, "res://resources/dialogue/healer_mara.tres")
	if err == OK:
		print("OK — saved res://resources/dialogue/healer_mara.tres")
	else:
		push_error("Failed to save: error %d" % err)
	quit()


# ─── Helpers ──────────────────────────────────────────────────────────

func _leaf(speaker: String, text: String) -> DialogueNode:
	var n := DialogueNode.new()
	n.speaker = speaker
	n.text = text
	return n


func _choice(label: String, next: DialogueNode, set_flag: String = "") -> DialogueChoice:
	var c := DialogueChoice.new()
	c.label = label
	c.next_node = next
	c.set_flag = set_flag
	return c


func _choice_stat(stat: StringName, threshold: int, label: String,
		success: DialogueNode, failure: DialogueNode = null,
		flag: String = "") -> DialogueChoice:
	var c := DialogueChoice.new()
	c.label = label
	c.stat_check = stat
	c.stat_threshold = threshold
	c.next_node = success
	if failure != null:
		c.failure_node = failure
	if flag != "":
		c.set_flag = flag
	return c


func _choice_flag(label: String, next: DialogueNode, flag: String) -> DialogueChoice:
	var c := DialogueChoice.new()
	c.label = label
	c.next_node = next
	c.set_flag = flag
	return c


func _choice_require(label: String, next: DialogueNode, flag: String) -> DialogueChoice:
	var c := DialogueChoice.new()
	c.label = label
	c.next_node = next
	c.require_flag = flag
	return c
