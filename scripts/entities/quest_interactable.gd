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

var _used: bool = false


func interact(player: Node) -> void:
	if _used:
		return
	_used = true
	if quest_id != "" and objective_id != "":
		QuestTracker.mark_objective_done(quest_id, objective_id)
	if give_item_id != &"" and player is PlayerController:
		var pc := player as PlayerController
		if pc.inventory != null:
			pc.inventory.add(give_item_id, give_item_count)
			QuestTracker.notify_item_collected(give_item_id, give_item_count)
	# Show a one-liner via WorldRoot.
	var wr: Node = self
	while wr != null and not (wr is WorldRoot):
		wr = wr.get_parent()
	if wr != null and player is PlayerController:
		var pc := player as PlayerController
		(wr as WorldRoot).show_dialogue(pc.player_id, interact_speaker, interact_text, self)
	# Visual feedback — fade out and remove.
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
