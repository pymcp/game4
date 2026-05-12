## Storyteller
##
## A party NPC who serves as the player's narrative memory. Placed near the
## caravan in the starting region. On interact, speaks the highest-priority
## recall line corresponding to flags the player has set.
##
## Scope: recall-only. No quest giving. No knowledge the player hasn't earned.
class_name Storyteller
extends Node2D

## Pixel radius within which a player can interact.
const INTERACT_RADIUS_PX: float = 24.0

## Each entry: {flag: String, text: String}
## Ordered highest priority first. First matching flag wins.
const _RECALL: Array = [
	{
		"flag": "aldric_known",
		"text": "That courier — Edda — mentioned a captain in Tidehaven. Aldric Farrow. Said he knew the eastern waters better than anyone alive.",
	},
	{
		"flag": "rune_tile_touched",
		"text": "Those ancient symbols in the mine. Angular, precise. Blue light in the stone. Nothing from any living script I've encountered.",
	},
	{
		"flag": "mara_crystalline_hint",
		"text": "Mara said the ore was crystalline — not just contaminated. Structured. Like something had refined it.",
	},
	{
		"flag": "edda_quest_complete",
		"text": "The courier charted this sickness across a dozen regions. It follows the same pattern every time — always near the old mines.",
	},
	{
		"flag": "farmer_ren_spoken",
		"text": "The farmer's animals won't eat. He said it started near the mine. Same story everywhere.",
	},
	{
		"flag": "valley_remedy_brewed",
		"text": "The herbalist's remedy is brewed. The valley will heal slowly. But the source...",
	},
]

const _DEFAULT_TEXT: String = "This valley feels wrong. Something is leaking into the land. Keep your eyes open."


func interact(player: Node) -> void:
	var wr: Node = self
	while wr != null and not (wr is WorldRoot):
		wr = wr.get_parent()
	if wr == null or not (player is PlayerController):
		return
	var pc := player as PlayerController
	var text: String = _DEFAULT_TEXT
	for entry in _RECALL:
		if GameState.get_flag(entry["flag"] as String):
			text = entry["text"] as String
			break
	(wr as WorldRoot).show_dialogue(pc.player_id, "Storyteller", text, self)
