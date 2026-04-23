## CreatureSpriteRegistry
##
## Static registry loading [code]resources/creature_sprites.json[/code].
## Each entry maps a creature kind to sprite metadata:
##   - sheet:     path to the sprite sheet / standalone PNG
##   - region:    [x, y, w, h] pixel region within the sheet (full image if omitted)
##   - anchor:    [x, y] pixel offset from top-left of region to the "feet" point
##   - scale:     [sx, sy] render scale
##   - footprint: [w, h] walkability footprint in tiles (default [1,1])
##   - tint:      [r, g, b, a] modulate colour (default white)
##
## Use [method build_sprite] to get a ready-to-add [Sprite2D] for a kind.
extends RefCounted
class_name CreatureSpriteRegistry

const _JSON_PATH: String = "res://resources/creature_sprites.json"

static var _data: Dictionary = {}
static var _sheets: Dictionary = {}  # path → Texture2D cache
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_JSON_PATH):
		push_warning("[CreatureSpriteRegistry] %s not found" % _JSON_PATH)
		return
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("[CreatureSpriteRegistry] failed to open %s" % _JSON_PATH)
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_warning("[CreatureSpriteRegistry] JSON parse error: %s" % json.get_error_message())
		return
	if json.data is Dictionary:
		_data = json.data


static func reset() -> void:
	_data.clear()
	_sheets.clear()
	_loaded = false


## Return a deep copy of the raw JSON dictionary.
static func get_raw_data() -> Dictionary:
	_ensure_loaded()
	return _data.duplicate(true)


## Replace the in-memory data and write to disk.
static func save_data(data: Dictionary) -> void:
	_data = data
	_loaded = true
	var text: String = JSON.stringify(data, "\t")
	var f := FileAccess.open(_JSON_PATH, FileAccess.WRITE)
	if f == null:
		push_error("CreatureSpriteRegistry: cannot write %s" % _JSON_PATH)
		return
	f.store_string(text)
	f.close()


## Returns true if a sprite entry exists for the given creature kind.
static func has_entry(kind: StringName) -> bool:
	_ensure_loaded()
	return _data.has(String(kind))


## Returns the raw entry dict, or empty dict.
static func get_entry(kind: StringName) -> Dictionary:
	_ensure_loaded()
	return _data.get(String(kind), {})


## All registered creature kind ids.
static func all_kinds() -> Array:
	_ensure_loaded()
	var out: Array = []
	for k in _data:
		out.append(StringName(k))
	return out


## Footprint in tiles as Vector2i. Defaults to (1, 1).
static func get_footprint(kind: StringName) -> Vector2i:
	var entry: Dictionary = get_entry(kind)
	var fp: Array = entry.get("footprint", [1, 1])
	return Vector2i(int(fp[0]), int(fp[1]))


## Anchor (feet point) as Vector2 in pixels, relative to region top-left.
## If `anchor_ratio` is present (e.g. [0.5, 0.95]), the anchor is computed
## as a fraction of the image size — handy for large images where absolute
## pixel coords are tedious.
static func get_anchor(kind: StringName) -> Vector2:
	var entry: Dictionary = get_entry(kind)
	if entry.has("anchor_ratio"):
		var ar: Array = entry["anchor_ratio"]
		var w: float = _image_width(entry)
		var h: float = _image_height(entry)
		return Vector2(w * float(ar[0]), h * float(ar[1]))
	var a: Array = entry.get("anchor", [0, 0])
	return Vector2(float(a[0]), float(a[1]))


## Scale as Vector2. If the entry has `target_width_tiles`, the scale
## is computed so the image fits that many tiles wide (preserving aspect
## ratio). Otherwise uses the explicit `scale` field.
static func get_scale(kind: StringName) -> Vector2:
	var entry: Dictionary = get_entry(kind)
	if entry.has("target_width_tiles"):
		var target_px: float = float(entry["target_width_tiles"]) * float(WorldConst.TILE_PX)
		var img_w: float = _image_width(entry)
		if img_w > 0.0:
			var s: float = target_px / img_w
			return Vector2(s, s)
	var s: Array = entry.get("scale", [1.0, 1.0])
	return Vector2(float(s[0]), float(s[1]))


## Tint / modulate colour.
static func get_tint(kind: StringName) -> Color:
	var entry: Dictionary = get_entry(kind)
	var t: Array = entry.get("tint", [1.0, 1.0, 1.0, 1.0])
	return Color(float(t[0]), float(t[1]), float(t[2]), float(t[3]))


## True if this creature kind is a mountable creature.
static func is_mount(kind: StringName) -> bool:
	return get_entry(kind).get("mount", false)


## True if the creature sprite natively faces right (flip_h when moving left).
static func is_facing_right(kind: StringName) -> bool:
	return get_entry(kind).get("facing_right", false)


## Speed multiplier while riding this mount. Defaults to 1.0.
static func get_speed_multiplier(kind: StringName) -> float:
	return float(get_entry(kind).get("speed_multiplier", 1.0))


## True if this mount can hop over obstacles.
static func can_jump(kind: StringName) -> bool:
	return get_entry(kind).get("can_jump", false)


## Rider offset in native pixels relative to the mount's anchor.
## Defaults to (0, -12) when missing.
static func get_rider_offset(kind: StringName) -> Vector2:
	var entry: Dictionary = get_entry(kind)
	var ro: Array = entry.get("rider_offset", [0, -12])
	return Vector2(float(ro[0]), float(ro[1]))


## All creature kinds that are mounts.
static func all_mount_kinds() -> Array:
	_ensure_loaded()
	var out: Array = []
	for k in _data:
		if _data[k].get("mount", false):
			out.append(StringName(k))
	return out


# ─── Internal helpers ──────────────────────────────────────────────────

## Image width in pixels (from region or full texture). Cached sheets
## must already be loaded for this to work on textures; falls back to
## the region array when present.
static func _image_width(entry: Dictionary) -> float:
	var region: Array = entry.get("region", [])
	if region.size() == 4:
		return float(region[2])
	var sheet_path: String = entry.get("sheet", "")
	var tex: Texture2D = _load_cached_sheet(sheet_path)
	if tex != null:
		return float(tex.get_width())
	return 0.0


static func _image_height(entry: Dictionary) -> float:
	var region: Array = entry.get("region", [])
	if region.size() == 4:
		return float(region[3])
	var sheet_path: String = entry.get("sheet", "")
	var tex: Texture2D = _load_cached_sheet(sheet_path)
	if tex != null:
		return float(tex.get_height())
	return 0.0


static func _load_cached_sheet(sheet_path: String) -> Texture2D:
	if sheet_path == "":
		return null
	var tex: Texture2D = _sheets.get(sheet_path, null) as Texture2D
	if tex != null:
		return tex
	if not ResourceLoader.exists(sheet_path):
		return null
	tex = load(sheet_path) as Texture2D
	if tex != null:
		_sheets[sheet_path] = tex
	return tex


## Build a [Sprite2D] configured for this creature kind.
## Returns null if the kind has no entry or the sheet cannot be loaded.
static func build_sprite(kind: StringName) -> Sprite2D:
	var entry: Dictionary = get_entry(kind)
	if entry.is_empty():
		return null
	var sheet_path: String = entry.get("sheet", "")
	if sheet_path == "":
		return null

	var tex: Texture2D = _load_cached_sheet(sheet_path)
	if tex == null:
		push_warning("[CreatureSpriteRegistry] sheet not found: %s" % sheet_path)
		return null

	var spr := Sprite2D.new()

	# If a region is specified, use AtlasTexture to crop.
	var region: Array = entry.get("region", [])
	if region.size() == 4:
		var region_rect := Rect2(
			float(region[0]), float(region[1]),
			float(region[2]), float(region[3]))
		# Skip atlas if region covers the full texture.
		if region_rect.size.x < tex.get_width() or region_rect.size.y < tex.get_height():
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = region_rect
			spr.texture = atlas
		else:
			spr.texture = tex
	else:
		spr.texture = tex

	# Anchor: offset so the sprite's anchor pixel sits at position (0, 0).
	var anchor: Vector2 = get_anchor(kind)
	var w: float = float(region[2]) if region.size() == 4 else float(tex.get_width())
	var h: float = float(region[3]) if region.size() == 4 else float(tex.get_height())
	spr.centered = false
	spr.offset = -anchor

	# Scale and tint.
	spr.scale = get_scale(kind)
	spr.modulate = get_tint(kind)

	# Large images downscaled via target_width_tiles need linear filtering;
	# nearest-neighbor at 50x+ reduction produces mostly-transparent garbage.
	if entry.has("target_width_tiles"):
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	return spr
