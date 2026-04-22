## MineableRegistry
##
## Loads, caches, and saves the `resources/mineables.json` data file that
## defines every mineable resource type in the game.  The SpritePicker tool
## writes to this file; runtime systems read from it.
##
## Usage:
##   var def: Dictionary = MineableRegistry.get_resource(&"tree")
##   var biome_weights: Dictionary = MineableRegistry.get_biome_weights(&"grass")
class_name MineableRegistry
extends RefCounted

const _PATH: String = "res://resources/mineables.json"

## Cached parsed data: { "resources": { ... }, "items": { ... } }.
static var _data: Dictionary = {}
static var _loaded: bool = false


# ─── Loading ──────────────────────────────────────────────────────────

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_data = _load_from_disk()


static func _load_from_disk() -> Dictionary:
	if not FileAccess.file_exists(_PATH):
		return {"resources": {}, "items": {}}
	var f := FileAccess.open(_PATH, FileAccess.READ)
	if f == null:
		push_warning("MineableRegistry: cannot open %s" % _PATH)
		return {"resources": {}, "items": {}}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("MineableRegistry: failed to parse %s" % _PATH)
		return {"resources": {}, "items": {}}
	return parsed as Dictionary


static func reload() -> void:
	_loaded = false
	_data = {}


# ─── Resource queries ─────────────────────────────────────────────────

## Return the resource definition dict for `id`, or null if unknown.
## Keys: display_name, ref_id, is_tall, is_pickaxe_bonus, hp, sprites,
##        biome_weights, drops.
static func get_resource(id: StringName) -> Variant:
	_ensure_loaded()
	var res: Dictionary = _data.get("resources", {})
	return res.get(String(id), null)


## All resource ids as StringName.
static func all_ids() -> Array[StringName]:
	_ensure_loaded()
	var res: Dictionary = _data.get("resources", {})
	var out: Array[StringName] = []
	for k in res.keys():
		out.append(StringName(k))
	return out


## Compute the merged {resource_id: weight} dict for a single biome.
## Only resources that list this biome in their biome_weights appear.
static func get_biome_weights(biome_id: StringName) -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	var bstr: String = String(biome_id)
	var res: Dictionary = _data.get("resources", {})
	for rid in res:
		var entry: Dictionary = res[rid]
		var bw: Dictionary = entry.get("biome_weights", {})
		if bw.has(bstr):
			out[StringName(rid)] = float(bw[bstr])
	return out


## Build the MINEABLE_HP dict (StringName → int) from all resources.
static func build_hp_table() -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	var res: Dictionary = _data.get("resources", {})
	for rid in res:
		out[StringName(rid)] = int(res[rid].get("hp", 1))
	return out


## Build the MINEABLE_DROPS dict (StringName → Array[{id, count}]) from all resources.
static func build_drops_table() -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	var res: Dictionary = _data.get("resources", {})
	for rid in res:
		var raw_drops: Array = res[rid].get("drops", [])
		var typed: Array = []
		for d in raw_drops:
			typed.append({"id": StringName(d.get("item_id", "")), "count": int(d.get("count", 1))})
		out[StringName(rid)] = typed
	return out


## Build the PICKAXE_BONUS_KINDS dict (StringName → true) from resources
## that have is_pickaxe_bonus == true.
static func build_pickaxe_bonus_set() -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	var res: Dictionary = _data.get("resources", {})
	for rid in res:
		if res[rid].get("is_pickaxe_bonus", false):
			out[StringName(rid)] = true
	return out


## Build the decoration cells dict (StringName → Array[Vector2i]) from
## all resources' sprite arrays. Used by TilesetCatalog.
static func build_decoration_cells() -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	var res: Dictionary = _data.get("resources", {})
	for rid in res:
		var sprites: Array = res[rid].get("sprites", [])
		var cells: Array[Vector2i] = []
		for s in sprites:
			if s is Array and s.size() >= 2:
				cells.append(Vector2i(int(s[0]), int(s[1])))
		out[StringName(rid)] = cells
	return out


## Build the set of tall decoration kind ids (those with is_tall == true).
## DEPRECATED — use get_tile_size() instead. Kept for backward compat.
static func build_tall_kinds() -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	var res: Dictionary = _data.get("resources", {})
	for rid in res:
		if _is_multi_tile(res[rid]):
			out[StringName(rid)] = true
	return out


## Return the tile footprint for a resource (default Vector2i(1, 1)).
## Uses width_tiles / height_tiles fields; falls back to is_tall for compat.
static func get_tile_size(id: StringName) -> Vector2i:
	_ensure_loaded()
	var res: Dictionary = _data.get("resources", {})
	var entry: Variant = res.get(String(id), null)
	if entry == null:
		return Vector2i(1, 1)
	var w: int = int(entry.get("width_tiles", 1))
	var h: int = int(entry.get("height_tiles", 1))
	# Backward compat: if only is_tall exists, treat as 1×2.
	if w == 1 and h == 1 and entry.get("is_tall", false):
		h = 2
	return Vector2i(max(1, w), max(1, h))


## Return the walkability bitmask for a resource (row-major, true = blocks).
## Length should equal width_tiles × height_tiles.
static func get_walkable_mask(id: StringName) -> Array:
	_ensure_loaded()
	var res: Dictionary = _data.get("resources", {})
	var entry: Variant = res.get(String(id), null)
	if entry == null:
		return [true]
	var mask: Variant = entry.get("walkable_mask", null)
	if mask is Array and not mask.is_empty():
		return mask
	# Backward compat: is_tall → [false, true] (top walkable, bottom blocks).
	if entry.get("is_tall", false):
		return [false, true]
	return [true]


## True if a resource occupies more than one tile.
static func is_multi_tile(id: StringName) -> bool:
	var sz: Vector2i = get_tile_size(id)
	return sz.x > 1 or sz.y > 1


## Internal helper — checks if an entry dict is multi-tile.
static func _is_multi_tile(entry: Dictionary) -> bool:
	var w: int = int(entry.get("width_tiles", 1))
	var h: int = int(entry.get("height_tiles", 1))
	if w > 1 or h > 1:
		return true
	return entry.get("is_tall", false)


# ─── Item queries ─────────────────────────────────────────────────────

## Return all custom items from the "items" section.
## Returns { String(id) → { display_name, icon_cell, icon_sheet, ... } }.
static func get_custom_items() -> Dictionary:
	_ensure_loaded()
	return _data.get("items", {})


# ─── Saving ───────────────────────────────────────────────────────────

## Return the raw data dict (for SpritePicker editing).
static func get_raw_data() -> Dictionary:
	_ensure_loaded()
	return _data


## Replace the in-memory data and write to disk.
static func save_data(data: Dictionary) -> void:
	_data = data
	_loaded = true
	var text: String = JSON.stringify(data, "\t")
	var f := FileAccess.open(_PATH, FileAccess.WRITE)
	if f == null:
		push_error("MineableRegistry: cannot write %s" % _PATH)
		return
	f.store_string(text)
	f.close()
