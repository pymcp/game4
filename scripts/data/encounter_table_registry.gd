## EncounterTableRegistry
##
## Static registry for depth-scaled enemy tables used by interior generators.
## Schema: resources/encounter_tables.json
##   {
##     "<dungeon_type>": {
##       "boss_interval": int,
##       "enemy_tables": [{creature, min_floor, max_floor, weight}, ...]
##     }
##   }
class_name EncounterTableRegistry
extends RefCounted

const _JSON_PATH: String = "res://resources/encounter_tables.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_JSON_PATH):
		push_warning("[EncounterTableRegistry] %s not found" % _JSON_PATH)
		return
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("[EncounterTableRegistry] failed to open %s" % _JSON_PATH)
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_warning("[EncounterTableRegistry] parse error: %s" % json.get_error_message())
		return
	if json.data is Dictionary:
		_data = json.data


static func reset() -> void:
	_data.clear()
	_loaded = false


## Returns the raw data dict for editing by the GameEditor panel.
static func get_raw_data() -> Dictionary:
	_ensure_loaded()
	return _data.duplicate(true)


## Persist edits from the GameEditor back to disk.
static func save_data(data: Dictionary) -> void:
	_data = data
	_loaded = true
	var f := FileAccess.open(_JSON_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[EncounterTableRegistry] cannot write %s" % _JSON_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


## Returns filtered, weighted enemy entries for `dungeon_type` at `floor_num`.
## Each entry: {creature: StringName, weight: int}
static func get_weighted_list(dungeon_type: StringName, floor_num: int) -> Array:
	_ensure_loaded()
	var type_data: Variant = _data.get(String(dungeon_type), null)
	if not (type_data is Dictionary):
		return []
	var tables: Array = type_data.get("enemy_tables", [])
	var out: Array = []
	for entry in tables:
		var mn: int = int(entry.get("min_floor", 1))
		var mx: int = int(entry.get("max_floor", 999))
		if floor_num >= mn and floor_num <= mx:
			out.append({
				"creature": StringName(entry.get("creature", "")),
				"weight": int(entry.get("weight", 1)),
			})
	return out


## Returns boss_interval for `dungeon_type` (default 5).
static func get_boss_interval(dungeon_type: StringName) -> int:
	_ensure_loaded()
	var type_data: Variant = _data.get(String(dungeon_type), null)
	if not (type_data is Dictionary):
		return 5
	return int(type_data.get("boss_interval", 5))


## Picks a random entry from a weighted table (must have "weight" key).
## Exported so tests and generators can call it directly.
static func weighted_pick(rng: RandomNumberGenerator, table: Array) -> Dictionary:
	if table.is_empty():
		return {}
	var total: int = 0
	for e in table:
		total += int(e.get("weight", 1))
	if total == 0:
		return table[0]
	var roll: int = rng.randi_range(1, total)
	var acc: int = 0
	for e in table:
		acc += int(e.get("weight", 1))
		if roll <= acc:
			return e
	return table[0]
