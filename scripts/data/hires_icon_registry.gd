## HiresIconRegistry
##
## Resolves high-resolution item icon textures from three spritesheets:
##   assets/icons/hires/weapons.png  — all weapon-slot items
##   assets/icons/hires/armor.png    — all head/body/feet/off_hand items
##   assets/icons/hires/items.png    — all other items (resources, tools, etc.)
##
## Each item in resources/items.json has `hires_sheet` (e.g. "weapons") and
## `hires_cell` ([col, row]) fields added by tools/seed_hires_sheets.py.
## The registry creates an AtlasTexture per cell and caches it for the session.
##
## Tile size and margin are read from `assets/icons/hires/_spec.json`
## (default: 64 px, no margin — matching the seeded sheets).
##
## Fallback: if sheet/cell fields are absent, checks for a per-item PNG at
## `assets/icons/hires/<id>.png` (legacy path from earlier tooling).
##
## Primary call site: `ItemRegistry._build_definition()` calls
## `get_icon_from_entry(id, entry)` with the resolved JSON entry dict.
class_name HiresIconRegistry
extends RefCounted

const HIRES_DIR: String = "res://assets/icons/hires/"

## Cached base sheet textures keyed by sheet name (e.g. "weapons").
static var _sheets: Dictionary = {}
## Cached AtlasTextures keyed by "sheet:col,row".
static var _atlas_cache: Dictionary = {}
## Cached individual PNG textures keyed by item_id string (legacy fallback).
static var _png_cache: Dictionary = {}


## Primary entry point.
## Reads `hires_sheet` and `hires_cell` from `entry` (the resolved item JSON
## dict) and returns an AtlasTexture for that cell.
## Falls back to a per-item PNG, then to null.
static func get_icon_from_entry(id: StringName, entry: Dictionary) -> Texture2D:
	var sheet_name: String = entry.get("hires_sheet", "")
	var cell_var: Variant = entry.get("hires_cell", null)
	if sheet_name != "" and cell_var is Array and (cell_var as Array).size() >= 2:
		return _from_cell(sheet_name,
				int((cell_var as Array)[0]),
				int((cell_var as Array)[1]))
	# Legacy: individual PNG per item id.
	return _individual(id)


## Return (creating if needed) a cached AtlasTexture for one cell on a sheet.
static func _from_cell(sheet_name: String, col: int, row: int) -> Texture2D:
	var cache_key: String = "%s:%d,%d" % [sheet_name, col, row]
	if _atlas_cache.has(cache_key):
		var v: Variant = _atlas_cache[cache_key]
		return v if v is Texture2D else null
	var sheet_tex: Texture2D = _load_sheet(sheet_name)
	if sheet_tex == null:
		_atlas_cache[cache_key] = false
		return null
	var spec: SheetSpec = SheetSpecReader.read(HIRES_DIR + sheet_name + ".png")
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet_tex
	atlas.region = Rect2(
		float(col * spec.stride),
		float(row * spec.stride),
		float(spec.tile_px),
		float(spec.tile_px))
	_atlas_cache[cache_key] = atlas
	return atlas


## Load (and cache) the base Texture2D for a named sheet.
static func _load_sheet(sheet_name: String) -> Texture2D:
	if _sheets.has(sheet_name):
		var v: Variant = _sheets[sheet_name]
		return v if v is Texture2D else null
	var path: String = HIRES_DIR + sheet_name + ".png"
	if not ResourceLoader.exists(path):
		_sheets[sheet_name] = false
		return null
	var tex: Texture2D = load(path) as Texture2D
	_sheets[sheet_name] = tex if tex != null else false
	return tex


## Legacy fallback: individual PNG at `hires/<id>.png`.
static func _individual(id: StringName) -> Texture2D:
	var key: String = String(id)
	if _png_cache.has(key):
		var v: Variant = _png_cache[key]
		return v if v is Texture2D else null
	var path: String = HIRES_DIR + key + ".png"
	if not ResourceLoader.exists(path):
		_png_cache[key] = false
		return null
	var tex: Texture2D = load(path) as Texture2D
	_png_cache[key] = tex if tex != null else false
	return tex


## Clear all caches (call after hot-reload or spritesheet swap).
static func reset() -> void:
	_sheets.clear()
	_atlas_cache.clear()
	_png_cache.clear()
