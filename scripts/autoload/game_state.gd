## GameState
##
## Global singleton that tracks quest flags and world-state variables.
## Flags are simple `String → bool` pairs. The dialogue system reads
## them to gate choices/nodes; picking certain dialogue choices sets them.
##
## Persisted inside [SaveGame] so progress survives save/load.
extends Node

var _flags: Dictionary = {}


## Set a flag (defaults to true). Overwrites any previous value.
func set_flag(key: String, value: bool = true) -> void:
	_flags[key] = value


## Returns true if the flag exists and is true; false otherwise.
func get_flag(key: String) -> bool:
	return _flags.get(key, false)


## Bulk-check: returns true only if ALL listed flags are true.
func has_all_flags(keys: Array[String]) -> bool:
	for k in keys:
		if not get_flag(k):
			return false
	return true


## Wipe all flags (new-game reset).
func clear_flags() -> void:
	_flags.clear()


## Snapshot for serialization into [SaveGame].
func to_dict() -> Dictionary:
	return _flags.duplicate()


## Restore from a save snapshot.
func from_dict(d: Dictionary) -> void:
	_flags = d.duplicate()


## Returns the keys of all true flags that start with [param prefix].
## Useful for enumerating "met_*" NPC flags or "lore_*" tidbit flags.
func keys_with_prefix(prefix: String) -> Array[String]:
	var result: Array[String] = []
	for key: String in _flags.keys():
		if key.begins_with(prefix) and _flags[key]:
			result.append(key)
	return result
