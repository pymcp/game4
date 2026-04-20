## GameSession
##
## Holds per-session game state that isn't world-specific: which save slot is
## loaded, current scene transitions, autosave timer, in-game time, etc.
##
## Phase 0 placeholder.
extends Node

signal new_game_started(seed_value: int)
signal save_loaded(slot: String)

var current_save_slot: String = ""
var in_game_seconds: float = 0.0
## When non-empty, the next time Game._ready runs it will load this slot
## instead of generating a fresh world. Cleared after consumption.
var pending_load_slot: String = ""


func start_new_game(seed_value: int = 0) -> void:
	WorldManager.reset(seed_value)
	in_game_seconds = 0.0
	new_game_started.emit(WorldManager.world_seed)


func _process(delta: float) -> void:
	if not get_tree().paused:
		in_game_seconds += delta
