## DialogueTree
##
## Thin wrapper that holds the root [DialogueNode] of a conversation.
## NPCs reference one of these via `@export var dialogue_tree`.
class_name DialogueTree
extends Resource

## Entry point of the conversation.
@export var root: Resource = null  # DialogueNode
