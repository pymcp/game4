## CraftingRegistry
##
## Data-driven registry of `CraftingRecipe`s loaded from
## `resources/recipes.json`. Follows the same load/save pattern as
## ItemRegistry and LootTableRegistry.
class_name CraftingRegistry
extends RefCounted

const _JSON_PATH: String = "res://resources/recipes.json"

## Cached CraftingRecipe objects keyed by StringName id.
static var _cache: Dictionary = {}
## Raw JSON data as loaded.
static var _raw: Dictionary = {}
static var _loaded: bool = false


static func get_recipe(id: StringName) -> CraftingRecipe:
	_ensure_loaded()
	return _cache.get(id, null)


static func all_recipes() -> Array:
	_ensure_loaded()
	return _cache.values()


static func all_ids() -> Array:
	_ensure_loaded()
	return _cache.keys()


static func reset() -> void:
	_cache.clear()
	_raw.clear()
	_loaded = false


# ─── Editor API ───────────────────────────────────────────────────────

## Return the raw JSON data for editor display.
static func get_raw_data() -> Dictionary:
	_ensure_loaded()
	return _raw


## Replace in-memory data, write to disk, and rebuild cache.
static func save_data(data: Dictionary) -> void:
	_raw = data.duplicate(true)
	var text: String = JSON.stringify(_raw, "\t")
	var f := FileAccess.open(_JSON_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[CraftingRegistry] cannot write %s" % _JSON_PATH)
		return
	f.store_string(text)
	f.close()
	_loaded = true
	_cache.clear()
	_build_cache()


# ─── Loading ──────────────────────────────────────────────────────────

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_raw = _load_json()
	_build_cache()


static func _load_json() -> Dictionary:
	if not FileAccess.file_exists(_JSON_PATH):
		push_warning("[CraftingRegistry] %s not found" % _JSON_PATH)
		return {}
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("[CraftingRegistry] cannot open %s" % _JSON_PATH)
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("[CraftingRegistry] failed to parse %s" % _JSON_PATH)
		return {}
	return parsed as Dictionary


static func _build_cache() -> void:
	for id_str in _raw:
		var id := StringName(id_str)
		var entry: Dictionary = _raw[id_str]
		var r := CraftingRecipe.new()
		r.id = id
		r.output_id = StringName(entry.get("output_id", id_str))
		r.output_count = int(entry.get("output_count", 1))
		var raw_inputs: Array = entry.get("inputs", [])
		var inputs: Array = []
		for inp in raw_inputs:
			inputs.append({"id": StringName(inp.get("id", "")),
				"count": int(inp.get("count", 1))})
		r.inputs = inputs
		_cache[id] = r
