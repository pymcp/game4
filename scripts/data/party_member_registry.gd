## PartyMemberRegistry
##
## Static registry of PartyMemberDef objects loaded from
## `resources/party_members.json`. Follows the same load/cache pattern
## as CraftingRegistry.
class_name PartyMemberRegistry
extends RefCounted

const _JSON_PATH: String = "res://resources/party_members.json"

static var _cache: Dictionary = {}   # StringName → PartyMemberDef
static var _raw: Dictionary = {}
static var _loaded: bool = false


static func get_member(id: StringName) -> PartyMemberDef:
	_ensure_loaded()
	return _cache.get(id, null)


static func get_all() -> Array:
	_ensure_loaded()
	return _cache.values()


static func all_ids() -> Array:
	_ensure_loaded()
	return _cache.keys()


static func reset() -> void:
	_cache.clear()
	_raw.clear()
	_loaded = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_raw = _load_json()
	_build_cache()


static func _load_json() -> Dictionary:
	if not FileAccess.file_exists(_JSON_PATH):
		push_warning("[PartyMemberRegistry] %s not found" % _JSON_PATH)
		return {}
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("[PartyMemberRegistry] cannot open %s" % _JSON_PATH)
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("[PartyMemberRegistry] failed to parse %s" % _JSON_PATH)
		return {}
	return parsed as Dictionary


static func _build_cache() -> void:
	for id_str in _raw:
		var id := StringName(id_str)
		var entry: Dictionary = _raw[id_str]
		var d := PartyMemberDef.new()
		d.id = id
		d.display_name = entry.get("display_name", id_str)
		d.crafter_domain = StringName(entry.get("crafter_domain", ""))
		var pc: Array = entry.get("portrait_cell", [0, 0])
		d.portrait_cell = Vector2i(int(pc[0]), int(pc[1]))
		d.can_follow = bool(entry.get("can_follow", false))
		d.builds.assign(entry.get("builds", []))
		_cache[id] = d
