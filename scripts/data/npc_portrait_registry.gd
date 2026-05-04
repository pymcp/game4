## NpcPortraitRegistry
##
## Static registry that maps NPC speaker names to portrait cells on
## `assets/icons/hires/portraits.png`.  Loaded from
## `resources/npc_portraits.json`.
##
## Usage:
##   var cell: Vector2i = NpcPortraitRegistry.get_cell("Mara")
##   # Returns Vector2i(-1, -1) when the speaker has no portrait.
class_name NpcPortraitRegistry
extends RefCounted

const _JSON_PATH: String = "res://resources/npc_portraits.json"
const SHEET_PATH: String = "res://assets/icons/hires/portraits.png"
const NO_PORTRAIT: Vector2i = Vector2i(-1, -1)

static var _map: Dictionary = {}   # String → Vector2i
static var _loaded: bool = false


## Returns the atlas cell [col, row] for the given speaker name, or
## NO_PORTRAIT (Vector2i(-1,-1)) if the speaker has no entry.
static func get_cell(speaker: String) -> Vector2i:
	_ensure_loaded()
	return _map.get(speaker, NO_PORTRAIT)


## True when the speaker has a registered portrait.
static func has_portrait(speaker: String) -> bool:
	_ensure_loaded()
	return _map.has(speaker)


## Returns all registered speaker names.
static func all_speakers() -> Array:
	_ensure_loaded()
	return _map.keys()


## Clears the cache (useful in tests).
static func reset() -> void:
	_map.clear()
	_loaded = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_JSON_PATH):
		push_warning("[NpcPortraitRegistry] %s not found" % _JSON_PATH)
		return
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("[NpcPortraitRegistry] cannot open %s" % _JSON_PATH)
		return
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("[NpcPortraitRegistry] failed to parse %s" % _JSON_PATH)
		return
	var portraits: Variant = (parsed as Dictionary).get("portraits", null)
	if portraits == null or not portraits is Dictionary:
		push_warning("[NpcPortraitRegistry] missing 'portraits' key in %s" % _JSON_PATH)
		return
	for speaker: String in (portraits as Dictionary):
		var raw: Variant = (portraits as Dictionary)[speaker]
		if raw is Array and (raw as Array).size() >= 2:
			_map[speaker] = Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
		else:
			push_warning("[NpcPortraitRegistry] bad cell for '%s'" % speaker)
