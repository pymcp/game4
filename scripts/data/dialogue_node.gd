## DialogueNode
##
## A single beat in a conversation: one speaker line plus zero or more
## [DialogueChoice]s the player can pick. When [choices] is empty the
## node is a leaf — the UI shows "[E] close" and the conversation ends.
##
## World-state gating: if [condition_flag] is set the node is only
## reachable when that flag is true in [GameState]. If
## [condition_flag_false] is set the node is only reachable when that
## flag is *false* (or absent). Both can be empty (no condition).
class_name DialogueNode
extends Resource

## Display name of the speaker (NPC name, or "" for narration).
@export var speaker: String = ""

## The line of dialogue shown to the player.
@export_multiline var text: String = ""

## Player responses. Empty array = leaf node (conversation ends).
@export var choices: Array[Resource] = []  # Array[DialogueChoice]

## Node is only reachable when this [GameState] flag is true. Empty = no gate.
@export var condition_flag: String = ""

## Node is only reachable when this flag is false/absent. Empty = no gate.
@export var condition_flag_false: String = ""
