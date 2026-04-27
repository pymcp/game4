## TravelLog
##
## Tracks a single player's dungeon run statistics.
## `current_run` accumulates during the active run.
## `start_run()` snapshots `current_run` → `last_run` and resets.
## Called by world.gd on dungeon entry and overworld re-entry.
class_name TravelLog
extends Resource

## Active run counters. Empty dict = no run started yet.
@export var current_run: Dictionary = {}
## Snapshot of the most recently completed run.
@export var last_run: Dictionary = {}

## Begin a new run. Snapshots current_run → last_run, then resets.
## [param kind]: &"dungeon" or &"labyrinth".
## [param region_str]: region_id serialized as "x_y" string.
func start_run(kind: StringName, region_str: String) -> void:
	if not current_run.is_empty():
		last_run = current_run.duplicate()
	current_run = {
		"dungeon_kind": String(kind),
		"region_id": region_str,
		"enemies_killed": 0,
		"floors_descended": 0,
		"items_looted": 0,
		"chests_opened": 0,
	}

func record_kill() -> void:
	if current_run.is_empty():
		return
	current_run["enemies_killed"] = current_run.get("enemies_killed", 0) + 1

func record_floor() -> void:
	if current_run.is_empty():
		return
	current_run["floors_descended"] = current_run.get("floors_descended", 0) + 1

func record_loot(count: int) -> void:
	if current_run.is_empty():
		return
	current_run["items_looted"] = current_run.get("items_looted", 0) + count

func record_chest() -> void:
	if current_run.is_empty():
		return
	current_run["chests_opened"] = current_run.get("chests_opened", 0) + 1

func to_dict() -> Dictionary:
	return {
		"current_run": current_run.duplicate(),
		"last_run": last_run.duplicate(),
	}

func from_dict(d: Dictionary) -> void:
	current_run = d.get("current_run", {}).duplicate()
	last_run = d.get("last_run", {}).duplicate()
