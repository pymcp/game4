## DialogueChoice
##
## One player response option inside a [DialogueNode]. Optionally gated
## by a stat check (e.g. Charisma ≥ 5) and/or a [GameState] flag.
## Selecting this choice can also SET a flag (quest progression).
##
## If [stat_check] is non-empty, the player's stat is compared against
## [stat_threshold]. On success the conversation follows [next_node];
## on failure it follows [failure_node] (or [next_node] if [failure_node]
## is null — treat as "no special failure path").
class_name DialogueChoice
extends Resource

## Text shown in the choice list. Prefix conventions:
##   "[Charisma 5] Convince her"  — stat-gated
##   "Tell me what you need."     — always available
@export var label: String = ""

## If non-empty, the named stat on [PlayerController] is checked.
## Empty string means no check — the choice always succeeds.
@export var stat_check: StringName = &""

## Minimum stat value to pass the check. Ignored when [stat_check] is empty.
@export var stat_threshold: int = 0

## Conversation node reached on success (or when no check is required).
@export var next_node: Resource = null  # DialogueNode

## Conversation node reached on failed stat check. If null, [next_node]
## is used instead (i.e. no distinct failure path).
@export var failure_node: Resource = null  # DialogueNode

## Choice is only visible when this [GameState] flag is true. Empty = always visible.
@export var require_flag: String = ""

## Flag set in [GameState] when the player picks this choice. Empty = no flag set.
@export var set_flag: String = ""
