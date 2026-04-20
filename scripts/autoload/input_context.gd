## InputContext
##
## Tracks each player's current input context (GAMEPLAY, INVENTORY, MENU, DISABLED)
## and tells the rest of the game which actions are currently active for each player.
##
## The HUD reads from this to render dynamic control hints. The PlayerController
## reads from this to know whether to consume movement/attack input or yield to UI.
extends Node

signal context_changed(player_id: int, new_context: Context)

enum Context {
	GAMEPLAY,
	INVENTORY,
	MENU,
	DISABLED,
}

const PLAYER_COUNT := 2

var _contexts: Array[Context] = [Context.GAMEPLAY, Context.GAMEPLAY]


func get_context(player_id: int) -> Context:
	return _contexts[player_id]


func set_context(player_id: int, ctx: Context) -> void:
	if _contexts[player_id] == ctx:
		return
	_contexts[player_id] = ctx
	context_changed.emit(player_id, ctx)


## Returns the list of action ids currently bound for this player based on context.
## Used by HUD to render dynamic control hints.
func get_active_actions(player_id: int) -> Array[StringName]:
	var ctx := _contexts[player_id]
	var prefix := "p%d_" % (player_id + 1)
	match ctx:
		Context.GAMEPLAY:
			return [
				StringName(prefix + "up"),
				StringName(prefix + "down"),
				StringName(prefix + "left"),
				StringName(prefix + "right"),
				StringName(prefix + "interact"),
				StringName(prefix + "attack"),
				StringName(prefix + "inventory"),
				StringName(prefix + "auto_mine"),
				StringName(prefix + "auto_attack"),
			]
		Context.INVENTORY:
			return [
				StringName(prefix + "up"),
				StringName(prefix + "down"),
				StringName(prefix + "left"),
				StringName(prefix + "right"),
				StringName(prefix + "interact"),
				StringName(prefix + "tab_prev"),
				StringName(prefix + "tab_next"),
				StringName(prefix + "inventory"),
			]
		Context.MENU:
			return [
				StringName(prefix + "up"),
				StringName(prefix + "down"),
				StringName(prefix + "interact"),
			]
		Context.DISABLED:
			return []
	return []


## Returns a short human label for an action (e.g. "E", "Numpad +").
func get_key_label(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "?"
	for ev in events:
		if ev is InputEventKey:
			var keycode := (ev as InputEventKey).keycode
			return OS.get_keycode_string(keycode)
	return "?"


## Returns a list of [label, action_name] pairs for HUD rendering.
func get_active_hint_pairs(player_id: int) -> Array:
	var hints: Array = []
	for action in get_active_actions(player_id):
		var label := get_key_label(action)
		var verb := _action_verb(action)
		hints.append([label, verb])
	return hints


func _action_verb(action: StringName) -> String:
	var s := String(action)
	# Strip p1_/p2_ prefix.
	if s.begins_with("p1_") or s.begins_with("p2_"):
		s = s.substr(3)
	match s:
		"up", "down", "left", "right":
			return "Move"
		"interact":
			return "Interact"
		"inventory":
			return "Inventory"
		"attack":
			return "Attack"
		"auto_mine":
			return "Auto-Mine"
		"auto_attack":
			return "Auto-Atk"
		"tab_prev":
			return "Prev Tab"
		"tab_next":
			return "Next Tab"
	return s.capitalize()
