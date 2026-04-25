## HitboxCalc
##
## Static helpers for computing and retrieving entity hitbox radii.
## All hit detection in this game is distance-based (no Area2D / physics).
## A hitbox radius makes entities hittable before the attack reaches
## their exact centre point — the Gungeon-style "body core" approach.
##
## [method radius_from_sprite] analyses opaque pixels and returns the
## 75th-percentile distance from centre, clamped to [MIN_RADIUS, MAX_RADIUS].
## Results are cached per unique texture+region so the scan runs at most once.
##
## [method get_radius] is a duck-typing accessor that reads [code]hitbox_radius[/code]
## from any node that exposes it, returning [code]0.0[/code] otherwise.
extends RefCounted
class_name HitboxCalc

const MIN_RADIUS: float = 2.0
const MAX_RADIUS: float = 7.0

## Cache: "path::x,y,w,h" → radius
static var _cache: Dictionary = {}


## Analyse the opaque pixels of a [Sprite2D] and return the 75th-percentile
## distance from the texture centre, clamped to [[const MIN_RADIUS], [const MAX_RADIUS]].
## Handles both plain [Texture2D] and [AtlasTexture].
static func radius_from_sprite(sprite: Sprite2D) -> float:
	if sprite == null or sprite.texture == null:
		return MIN_RADIUS
	var tex: Texture2D = sprite.texture
	var region := Rect2()
	if tex is AtlasTexture:
		region = (tex as AtlasTexture).region
		tex = (tex as AtlasTexture).atlas
	return radius_from_texture(tex, region)


## Analyse the opaque pixels of a texture (optionally cropped to [param region])
## and return the 75th-percentile distance from the region centre.
static func radius_from_texture(tex: Texture2D, region: Rect2 = Rect2()) -> float:
	if tex == null:
		return MIN_RADIUS
	var key: String = _cache_key(tex, region)
	if _cache.has(key):
		return _cache[key] as float
	var r: float = _compute(tex, region)
	_cache[key] = r
	return r


## Read [code]hitbox_radius[/code] from any node via duck typing.
## Returns [code]0.0[/code] when the property does not exist.
static func get_radius(entity: Node) -> float:
	if entity == null:
		return 0.0
	var val: Variant = entity.get(&"hitbox_radius")
	return float(val) if val != null else 0.0


## Clear the computation cache (for testing or after hot-reload).
static func reset() -> void:
	_cache.clear()


# ─── Internals ─────────────────────────────────────────────────────────

static func _cache_key(tex: Texture2D, region: Rect2) -> String:
	var path: String = tex.resource_path if tex.resource_path != "" else str(tex.get_rid().get_id())
	if region.size == Vector2.ZERO:
		return path
	return "%s::%d,%d,%d,%d" % [path, int(region.position.x), int(region.position.y),
			int(region.size.x), int(region.size.y)]


static func _compute(tex: Texture2D, region: Rect2) -> float:
	var img: Image = tex.get_image()
	if img == null:
		return MIN_RADIUS
	# Determine scan area.
	var rx: int = 0
	var ry: int = 0
	var rw: int = img.get_width()
	var rh: int = img.get_height()
	if region.size != Vector2.ZERO:
		rx = int(region.position.x)
		ry = int(region.position.y)
		rw = int(region.size.x)
		rh = int(region.size.y)
	var cx: float = float(rw) * 0.5
	var cy: float = float(rh) * 0.5
	# Collect distances of all opaque pixels from centre.
	var distances: PackedFloat32Array = PackedFloat32Array()
	for y in rh:
		for x in rw:
			var c: Color = img.get_pixel(rx + x, ry + y)
			if c.a > 0.1:
				var dx: float = float(x) - cx
				var dy: float = float(y) - cy
				distances.append(sqrt(dx * dx + dy * dy))
	if distances.is_empty():
		return MIN_RADIUS
	# Sort and take 75th percentile.
	distances.sort()
	var idx: int = int(float(distances.size()) * 0.75)
	idx = clampi(idx, 0, distances.size() - 1)
	var radius: float = distances[idx]
	return clampf(radius, MIN_RADIUS, MAX_RADIUS)
