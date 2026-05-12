## QuestInteractable
##
## World entity that advances a quest objective when a player interacts.
## Place in the entities layer; the player's interact scan picks it up
## automatically (duck-typed via [method interact]).
##
## After interaction the node shows a one-liner via the WorldRoot dialogue
## system, optionally gives an item, and then removes itself.
class_name QuestInteractable
extends Node2D

## Quest to advance on interact.
@export var quest_id: String = ""
## Objective id to mark done.
@export var objective_id: String = ""
## Speaker name shown in the one-liner.
@export var interact_speaker: String = ""
## Text shown as a one-liner after interacting.
@export var interact_text: String = "Done."
## Optional item to give the player on interact.
@export var give_item_id: StringName = &""
@export var give_item_count: int = 1
## When true the node is NOT removed after interaction (use for permanent fixtures).
@export var persistent: bool = false
## Additional quest objectives to advance on interact (beyond the primary quest_id/objective_id pair).
## Each entry: {quest_id: String, objective_id: String}
@export var advances: Array = []
## Optional GameState flag: if set and true, show [member conditional_text] instead of [member interact_text].
@export var condition_flag: String = ""
## Text shown when [member condition_flag] is set and true.
@export var conditional_text: String = ""

var _used: bool = false


func interact(player: Node) -> void:
	if _used:
		return
	_used = true
	if quest_id != "" and objective_id != "":
		QuestTracker.mark_objective_done(quest_id, objective_id)
	# Advance any additional quest objectives.
	for entry in advances:
		var qid: String = entry.get("quest_id", "")
		var oid: String = entry.get("objective_id", "")
		if qid != "" and oid != "":
			QuestTracker.mark_objective_done(qid, oid)
	if give_item_id != &"" and player is PlayerController:
		var pc := player as PlayerController
		if pc.inventory != null:
			pc.inventory.add(give_item_id, give_item_count)
			QuestTracker.notify_item_collected(give_item_id, give_item_count)
	# Pick the appropriate display text.
	var display_text: String = interact_text
	if condition_flag != "" and GameState.get_flag(condition_flag):
		display_text = conditional_text
	# Show a one-liner via WorldRoot.
	var wr: Node = self
	while wr != null and not (wr is WorldRoot):
		wr = wr.get_parent()
	if wr != null and player is PlayerController:
		var pc := player as PlayerController
		(wr as WorldRoot).show_dialogue(pc.player_id, interact_speaker, display_text, self)
	if persistent:
		_used = false  # Allow re-interaction on next visit
		return
	# Visual feedback — fade out and remove.
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
