## NamesRegistry
##
## Static loader for res://resources/names.json.
## Provides a pool of names per party member role, used to give each
## caravan member a unique name at game start.
class_name NamesRegistry
extends RefCounted

const _PATH: String = "res://resources/names.json"

static var _cache: Dictionary = {}

## Returns a random name from the pool for [param role].
## Falls back to [code]String(role)[/code] if the role is not found.
static func roll_name(role: StringName, rng: RandomNumberGenerator) -> String:
    var pool: Array = get_pool(role)
    if pool.is_empty():
        return String(role)
    return pool[rng.randi() % pool.size()]

## Returns the full name pool for [param role].
static func get_pool(role: StringName) -> Array:
    _ensure_loaded()
    return _cache.get(String(role), [])

## Clears the cache (call in tests).
static func reset() -> void:
    _cache.clear()

static func _ensure_loaded() -> void:
    if not _cache.is_empty():
        return
    var f := FileAccess.open(_PATH, FileAccess.READ)
    if f == null:
        push_warning("[NamesRegistry] could not open %s" % _PATH)
        return
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()
    if parsed is Dictionary:
        _cache = parsed
