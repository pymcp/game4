## LootTableRegistry
##
## Static registry that loads `resources/loot_tables.json` and provides
## weighted random drop rolling for monster types.
##
## Each entry is keyed by creature kind (e.g. "slime", "skeleton") and
## contains:
##   - display_name: String
##   - health: int (suggested max_health for spawning)
##   - drops: Array of {item_id, weight, min, max}
##   - drop_count: int (how many independent rolls on death)
##   - drop_chance: float (0.0–1.0, probability per roll of yielding an item)
##   - resistances: Dictionary (optional, Element enum int → float multiplier)
extends RefCounted
class_name LootTableRegistry

const _JSON_PATH: String = "res://resources/loot_tables.json"

static var _data: Dictionary = {}
static var _loaded: bool = false
static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_JSON_PATH):
		push_warning("[LootTableRegistry] %s not found" % _JSON_PATH)
		return
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("[LootTableRegistry] failed to open %s" % _JSON_PATH)
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_warning("[LootTableRegistry] JSON parse error: %s" % json.get_error_message())
		return
	if json.data is Dictionary:
		_data = json.data


static func reset() -> void:
	_data.clear()
	_loaded = false


## Returns true if a loot table exists for the given creature kind.
static func has_table(kind: StringName) -> bool:
	_ensure_loaded()
	return _data.has(String(kind))


## Returns the raw entry dict for a creature kind, or empty dict.
static func get_table(kind: StringName) -> Dictionary:
	_ensure_loaded()
	return _data.get(String(kind), {})


## Returns all registered creature kind ids.
static func all_kinds() -> Array:
	_ensure_loaded()
	var out: Array = []
	for k in _data:
		out.append(StringName(k))
	return out


## Returns the suggested max_health for a creature kind.
static func get_health(kind: StringName) -> int:
	var entry: Dictionary = get_table(kind)
	return int(entry.get("health", 3))


## Returns the resistances dict for a creature kind (Element int → float).
static func get_resistances(kind: StringName) -> Dictionary:
	var entry: Dictionary = get_table(kind)
	var raw: Dictionary = entry.get("resistances", {})
	var out: Dictionary = {}
	for k in raw:
		out[int(k)] = float(raw[k])
	return out


## Roll drops for a creature death. Returns Array of {id: StringName, count: int}.
## Uses the entry's drop_chance and drop_count for independent rolls.
static func roll_drops(kind: StringName, rng: RandomNumberGenerator = null) -> Array:
	var entry: Dictionary = get_table(kind)
	if entry.is_empty():
		return []
	var r: RandomNumberGenerator = rng if rng != null else _rng
	var drops_table: Array = entry.get("drops", [])
	if drops_table.is_empty():
		return []
	var drop_count: int = int(entry.get("drop_count", 1))
	var drop_chance: float = float(entry.get("drop_chance", 1.0))
	var result: Array = []
	for _i in drop_count:
		if r.randf() > drop_chance:
			continue
		var pick: Dictionary = _weighted_pick(r, drops_table)
		if pick.is_empty():
			continue
		var count: int = r.randi_range(int(pick.get("min", 1)), int(pick.get("max", 1)))
		result.append({"id": StringName(pick["item_id"]), "count": count})
	return result


## Weighted random pick from a drop table array.
static func _weighted_pick(rng_inst: RandomNumberGenerator, table: Array) -> Dictionary:
	var total: int = 0
	for entry in table:
		total += int(entry.get("weight", 1))
	if total <= 0:
		return {}
	var roll: int = rng_inst.randi_range(0, total - 1)
	var acc: int = 0
	for entry in table:
		acc += int(entry.get("weight", 1))
		if roll < acc:
			return entry
	return table[table.size() - 1]
