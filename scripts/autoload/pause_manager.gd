## PauseManager
##
## Owns the global pause state. Listens for the `pause` action and toggles
## `get_tree().paused`. Emits signals so a PauseMenu UI can show/hide itself.
##
## Also tracks whether each player is "enabled" in the session (toggled from the
## pause menu). When a player is disabled, their PlayerController stops reading
## input and their character is hidden, but their viewport remains visible with
## a "Disabled" overlay.
extends Node

signal pause_state_changed(is_paused: bool)
signal player_enabled_changed(player_id: int, is_enabled: bool)

const PLAYER_COUNT := 2

var _is_paused: bool = false
var _player_enabled: Array[bool] = [true, true]


func _ready() -> void:
	# PauseManager itself must process while paused so it can unpause.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	# Debug hotkeys (always available; no Input action so they can't be
	# rebound or accidentally pressed in normal play).
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_F8:
				_dispatch_debug(&"debug_spawn_villager")
				_dispatch_debug(&"debug_spawn_monster")
				_dispatch_debug(&"debug_spawn_mount")
				_dispatch_debug(&"debug_god_mode")
				get_viewport().set_input_as_handled()
			KEY_F9:
				_dispatch_debug(&"debug_spawn_interactables")
				_dispatch_debug(&"debug_spawn_shop_villager")
				get_viewport().set_input_as_handled()
			KEY_F10:
				_dispatch_debug(&"debug_toggle_hitbox_overlay")
				get_viewport().set_input_as_handled()


func _dispatch_debug(method: StringName) -> void:
	# Forward to the single [World] coordinator, which fans out per-player.
	var world: World = World.instance()
	if world != null and world.has_method(method):
		world.call(method)


func is_paused() -> bool:
	return _is_paused


func toggle_pause() -> void:
	set_paused(not _is_paused)


func set_paused(value: bool) -> void:
	if _is_paused == value:
		return
	# Refuse to unpause if every player is disabled — there'd be no one to
	# play and no way back to the pause menu.
	if not value and not _any_player_enabled():
		return
	_is_paused = value
	get_tree().paused = value
	pause_state_changed.emit(value)


func _any_player_enabled() -> bool:
	for enabled in _player_enabled:
		if enabled:
			return true
	return false


func is_player_enabled(player_id: int) -> bool:
	return _player_enabled[player_id]


func set_player_enabled(player_id: int, enabled: bool) -> void:
	if _player_enabled[player_id] == enabled:
		return
	_player_enabled[player_id] = enabled
	player_enabled_changed.emit(player_id, enabled)
	# Update the player's input context to match.
	if enabled:
		InputContext.set_context(player_id, InputContext.Context.GAMEPLAY)
	else:
		InputContext.set_context(player_id, InputContext.Context.DISABLED)
