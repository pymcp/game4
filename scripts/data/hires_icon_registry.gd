## HiresIconRegistry
##
## Resolves high-resolution item icon textures from `assets/icons/hires/`.
## Falls back to null gracefully when a hires PNG does not exist, so the
## existing low-res icon path in ItemDefinition remains unchanged.
##
## Call order:
##   1. `HiresIconRegistry.get_icon(id)` — returns a Texture2D or null.
##   2. `ItemRegistry._build_cache()` calls this for every item and sets
##      `ItemDefinition.icon` when a hires PNG is found.
##
## Caching: textures are lazy-loaded and held in a static dictionary so each
## PNG is only loaded once per editor/game session. Call `reset()` to evict.
class_name HiresIconRegistry
extends RefCounted

const HIRES_DIR: String = "res://assets/icons/hires/"

## item_id → Texture2D (or null sentinel stored as false to avoid re-checking).
static var _cache: Dictionary = {}


## Return the hires Texture2D for `item_id`, or null if no hires PNG exists.
static func get_icon(item_id: StringName) -> Texture2D:
	var key: String = String(item_id)
	if _cache.has(key):
		var v: Variant = _cache[key]
		return v if v is Texture2D else null
	var path: String = HIRES_DIR + key + ".png"
	if not ResourceLoader.exists(path):
		_cache[key] = false  # negative cache sentinel
		return null
	var tex: Texture2D = load(path) as Texture2D
	_cache[key] = tex if tex != null else false
	return tex


## Clear the cache so textures are re-read on next access (e.g. after hot-reload).
static func reset() -> void:
	_cache.clear()
