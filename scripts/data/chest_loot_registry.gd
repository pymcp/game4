## ChestLootRegistry
##
## Static registry for depth-tiered treasure chest loot.
## Schema: resources/chest_loot.json
##   { "tiers": [{ min_floor, max_floor, loot: [{id, weight, min, max}] }] }
class_name ChestLootRegistry
extends RefCounted

const _JSON_PATH: String = "res://resources/chest_loot.json"
const _FALLBACK_ITEM: StringName = &"stone"

static var _tiers: Array = []
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_JSON_PATH):
		push_warning("[ChestLootRegistry] %s not found" % _JSON_PATH)
		return
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("[ChestLootRegistry] failed to open %s" % _JSON_PATH)
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_warning("[ChestLootRegistry] parse error: %s" % json.get_error_message())
		return
	if json.data is Dictionary:
		_tiers = json.data.get("tiers", [])


static func reset() -> void:
	_tiers.clear()
	_loaded = false


## Returns the raw tiers array for editing by the GameEditor panel.
static func get_raw_tiers() -> Array:
	_ensure_loaded()
	return _tiers.duplicate(true)


## Persist edits from the GameEditor back to disk.
static func save_data(tiers: Array) -> void:
	_tiers = tiers
	_loaded = true
	var f := FileAccess.open(_JSON_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[ChestLootRegistry] cannot write %s" % _JSON_PATH)
		return
	f.store_string(JSON.stringify({"tiers": tiers}, "\t"))
	f.close()


## Returns the tier dict covering `floor_num`. Falls back to last tier.
static func get_tier_for_floor(floor_num: int) -> Dictionary:
	_ensure_loaded()
	for tier in _tiers:
		var mn: int = int(tier.get("min_floor", 1))
		var mx: int = int(tier.get("max_floor", 999))
		if floor_num >= mn and floor_num <= mx:
			return tier
	return _tiers.back() if not _tiers.is_empty() else {}


## Roll one item from the appropriate depth tier.
## Returns {id: StringName, count: int}.
static func roll_loot(floor_num: int, rng: RandomNumberGenerator) -> Dictionary:
	var tier: Dictionary = get_tier_for_floor(floor_num)
	var table: Array = tier.get("loot", [])
	if table.is_empty():
		return {"id": _FALLBACK_ITEM, "count": 1}
	var total: int = 0
	for e in table:
		total += int(e.get("weight", 1))
	var roll: int = rng.randi_range(1, max(1, total))
	var acc: int = 0
	for e in table:
		acc += int(e.get("weight", 1))
		if roll <= acc:
			return {
				"id": StringName(e.get("id", "")),
				"count": rng.randi_range(int(e.get("min", 1)), int(e.get("max", 1))),
			}
	return {"id": StringName(table[0].get("id", "")), "count": 1}
