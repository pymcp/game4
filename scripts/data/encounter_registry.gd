## EncounterRegistry
##
## Static registry that scans `resources/encounters/*.json` and provides
## weighted encounter selection for procedural region generation.
##
## Each JSON file defines one encounter template:
##   - id: StringName — unique encounter identifier
##   - size: [w, h] — tile footprint
##   - tiles: 2D array of terrain codes (-1 = keep existing)
##   - decorations: [{offset: [x,y], kind, variant}]
##   - entities: [{offset: [x,y], type, kind, ...}]
##   - placement: {biomes, min_distance_from_center, min_distance_between,
##                  max_per_region, weight}
extends RefCounted
class_name EncounterRegistry

const _DIR_PATH: String = "res://resources/encounters/"

static var _data: Dictionary = {}   # id -> parsed dict
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not DirAccess.dir_exists_absolute(_DIR_PATH):
		return
	var dir := DirAccess.open(_DIR_PATH)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			_load_file(_DIR_PATH + fname)
		fname = dir.get_next()
	dir.list_dir_end()


static func _load_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("[EncounterRegistry] failed to open %s" % path)
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_warning("[EncounterRegistry] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return
	var d: Variant = json.data
	if d is Dictionary:
		var id: String = d.get("id", "")
		if id == "":
			push_warning("[EncounterRegistry] missing 'id' in %s" % path)
			return
		_data[StringName(id)] = d
	elif d is Array:
		for entry in d:
			if entry is Dictionary:
				var id: String = entry.get("id", "")
				if id != "":
					_data[StringName(id)] = entry


static func reset() -> void:
	_data.clear()
	_loaded = false


## Returns true if an encounter with the given id exists.
static func has_encounter(id: StringName) -> bool:
	_ensure_loaded()
	return _data.has(id)


## Returns the raw encounter dict, or empty dict.
static func get_encounter(id: StringName) -> Dictionary:
	_ensure_loaded()
	return _data.get(id, {})


## Returns all registered encounter ids.
static func all_ids() -> Array:
	_ensure_loaded()
	var out: Array = []
	for k in _data:
		out.append(k)
	return out


## Returns encounters whose placement.biomes includes the given biome.
static func get_encounters_for_biome(biome_id: StringName) -> Array:
	_ensure_loaded()
	var out: Array = []
	for id in _data:
		var entry: Dictionary = _data[id]
		var placement: Dictionary = entry.get("placement", {})
		var biomes: Array = placement.get("biomes", [])
		if biomes.is_empty() or String(biome_id) in biomes:
			out.append(entry)
	return out


## Returns the tile footprint size as Vector2i.
static func get_size(encounter: Dictionary) -> Vector2i:
	var s: Array = encounter.get("size", [1, 1])
	return Vector2i(int(s[0]), int(s[1]))


## Returns the 2D tiles array (each row is an Array of ints, -1 = keep).
static func get_tiles(encounter: Dictionary) -> Array:
	return encounter.get("tiles", [])


## Returns the decoration entries for an encounter.
static func get_decorations(encounter: Dictionary) -> Array:
	return encounter.get("decorations", [])


## Returns the entity entries for an encounter.
static func get_entities(encounter: Dictionary) -> Array:
	return encounter.get("entities", [])


## Returns the placement dict for an encounter.
static func get_placement(encounter: Dictionary) -> Dictionary:
	return encounter.get("placement", {})


## Saves encounter data to a JSON file. Used by the encounter editor.
static func save_encounter(encounter: Dictionary) -> void:
	var id: String = encounter.get("id", "")
	if id == "":
		push_warning("[EncounterRegistry] cannot save encounter without id")
		return
	var path: String = _DIR_PATH + id + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("[EncounterRegistry] failed to write %s" % path)
		return
	f.store_string(JSON.stringify(encounter, "\t"))
	f.close()
	# Update in-memory cache.
	_data[StringName(id)] = encounter


## Deletes an encounter JSON file and removes from cache.
static func delete_encounter(id: StringName) -> void:
	var path: String = _DIR_PATH + String(id) + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_data.erase(id)
