## PlayerActions
##
## Central source of truth for player input action names.
## All code that needs an action name should call PlayerActions.action(pid, VERB)
## instead of building "p1_up" or "p%d_back" inline.
##
## Global menus (MainMenu, PauseMenu) use either_just_pressed / either_pressed
## so either player can operate them.
class_name PlayerActions
extends RefCounted

# ── Verb constants ──────────────────────────────────────────────────
const UP:          StringName = &"up"
const DOWN:        StringName = &"down"
const LEFT:        StringName = &"left"
const RIGHT:       StringName = &"right"
const INTERACT:    StringName = &"interact"
const BACK:        StringName = &"back"
const ATTACK:      StringName = &"attack"
const INVENTORY:   StringName = &"inventory"
const TAB_PREV:    StringName = &"tab_prev"
const TAB_NEXT:    StringName = &"tab_next"
const AUTO_MINE:   StringName = &"auto_mine"
const AUTO_ATTACK: StringName = &"auto_attack"
const WORLDMAP:    StringName = &"worldmap"
const DODGE:       StringName = &"dodge"
const BLOCK:       StringName = &"block"

# ── Action-name builders ────────────────────────────────────────────

## Returns the action prefix for [param player_id] (e.g. "p1_" or "p2_").
static func prefix(player_id: int) -> String:
	return "p%d_" % (player_id + 1)

## Builds a fully-qualified action name for [param player_id] and [param verb].
## Example: PlayerActions.action(0, PlayerActions.UP) → &"p1_up"
static func action(player_id: int, verb: StringName) -> StringName:
	return StringName(prefix(player_id) + String(verb))

# ── Event helpers ───────────────────────────────────────────────────

## True if [param event] is a just-pressed event for the given [param player_id] + [param verb].
static func just_pressed(event: InputEvent, player_id: int, verb: StringName) -> bool:
	return event.is_action_pressed(action(player_id, verb), true)

## True if the action is currently held for [param player_id] + [param verb].
static func pressed(event: InputEvent, player_id: int, verb: StringName) -> bool:
	return event.is_action_pressed(action(player_id, verb))

## True if either player just pressed [param verb].
## Used by global menus (MainMenu, PauseMenu) that accept input from both players.
static func either_just_pressed(event: InputEvent, verb: StringName) -> bool:
	return just_pressed(event, 0, verb) or just_pressed(event, 1, verb)

## True if either player is holding [param verb].
static func either_pressed(event: InputEvent, verb: StringName) -> bool:
	return pressed(event, 0, verb) or pressed(event, 1, verb)
