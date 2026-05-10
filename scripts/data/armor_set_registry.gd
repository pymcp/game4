## ArmorSetRegistry
##
## Loads armor set definitions from `resources/armor_sets.json`. Each set
## defines threshold-based stat bonuses granted when enough pieces of the
## set are equipped.
##
## JSON schema:
##   "leather": {
##     "display_name": "Leather Set",
##     "thresholds": [
##       { "pieces": 2, "stat_bonuses": { "speed": 1 } },
##       { "pieces": 3, "stat_bonuses": { "speed": 1, "defense": 1 } }
##     ]
##   }
##
## Thresholds are cumulative — if you meet threshold N, you get bonuses from
## all thresholds ≤ N.
class_name ArmorSetRegistry
extends RefCounted

const _PATH: String = "res://resources/armor_sets.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_data = JsonLoader.load_dict(_PATH)


## Return the full set definition dict, or empty dict if not found.
static func get_set(set_id: String) -> Dictionary:
	_ensure_loaded()
	return _data.get(set_id, {})


## Return all registered set ids.
static func all_ids() -> Array:
	_ensure_loaded()
	return _data.keys()


# ─── Editor API ───────────────────────────────────────────────────────

## Return the raw JSON data for editor display.
static func get_raw_data() -> Dictionary:
	_ensure_loaded()
	return _data


## Replace in-memory data, write to disk.
static func save_data(data: Dictionary) -> void:
	_data = data.duplicate(true)
	_loaded = true
	JsonLoader.save_dict(_PATH, _data)


## Calculate cumulative stat bonuses for a set given equipped piece count.
## Returns { StringName → int } of bonuses, or empty dict.
static func calc_set_bonuses(set_id: String, piece_count: int) -> Dictionary:
	_ensure_loaded()
	var set_def: Dictionary = _data.get(set_id, {})
	var thresholds: Array = set_def.get("thresholds", [])
	var totals: Dictionary = {}
	for t in thresholds:
		if piece_count >= int(t.get("pieces", 999)):
			var bonuses: Dictionary = t.get("stat_bonuses", {})
			for stat_key in bonuses:
				var sn: StringName = StringName(stat_key)
				totals[sn] = totals.get(sn, 0) + int(bonuses[stat_key])
	return totals


## Force reload from disk.
static func reset() -> void:
	_data.clear()
	_loaded = false
