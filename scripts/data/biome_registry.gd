## BiomeRegistry
##
## Data-driven registry of `BiomeDefinition`s loaded from
## `resources/biomes.json`. Follows the same load/save pattern as
## ItemRegistry and LootTableRegistry.
class_name BiomeRegistry
extends RefCounted

const _JSON_PATH: String = "res://resources/biomes.json"

## Cached BiomeDefinition objects keyed by StringName id.
static var _cache: Dictionary = {}
## Raw JSON data as loaded.
static var _raw: Dictionary = {}
static var _loaded: bool = false


static func get_biome(id: StringName) -> BiomeDefinition:
	_ensure_loaded()
	return _cache.get(id, null)


static func all_ids() -> Array[StringName]:
	_ensure_loaded()
	var out: Array[StringName] = []
	for k in _raw:
		out.append(StringName(k))
	return out


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
		push_error("[BiomeRegistry] cannot write %s" % _JSON_PATH)
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
		push_warning("[BiomeRegistry] %s not found" % _JSON_PATH)
		return {}
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("[BiomeRegistry] cannot open %s" % _JSON_PATH)
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("[BiomeRegistry] failed to parse %s" % _JSON_PATH)
		return {}
	return parsed as Dictionary


static func _build_cache() -> void:
	for id_str in _raw:
		var id := StringName(id_str)
		var entry: Dictionary = _raw[id_str]
		var b := BiomeDefinition.new()
		b.id = id
		b.primary_terrain = int(entry.get("primary_terrain", TerrainCodes.GRASS))
		b.secondary_terrain = int(entry.get("secondary_terrain", TerrainCodes.DIRT))
		b.secondary_chance = float(entry.get("secondary_chance", 0.08))
		var gm: Variant = entry.get("ground_modulate", null)
		if gm is Array and gm.size() >= 4:
			b.ground_modulate = Color(float(gm[0]), float(gm[1]),
				float(gm[2]), float(gm[3]))
		elif gm is Array and gm.size() >= 3:
			b.ground_modulate = Color(float(gm[0]), float(gm[1]), float(gm[2]))
		var dw: Variant = entry.get("decoration_weights", null)
		if dw is Dictionary:
			var typed: Dictionary = {}
			for k in dw:
				typed[StringName(k)] = float(dw[k])
			b.decoration_weights = typed
		b.bleed_chance = float(entry.get("bleed_chance", 0.25))
		b.npc_density = float(entry.get("npc_density", 0.002))
		var nk: Variant = entry.get("npc_kinds", null)
		if nk is Array:
			var typed_nk: Array = []
			for k in nk:
				typed_nk.append(StringName(k))
			b.npc_kinds = typed_nk
		_cache[id] = b
