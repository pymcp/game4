## StatusEffectRegistry
##
## Static registry for status effect definitions.
## Loaded from resources/status_effects.json.
class_name StatusEffectRegistry
extends RefCounted

const _PATH: String = "res://resources/status_effects.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_load_json()
	_loaded = true


static func _load_json() -> void:
	_data = {}
	var f: FileAccess = FileAccess.open(_PATH, FileAccess.READ)
	if f == null:
		return
	var parser := JSON.new()
	if parser.parse(f.get_as_text()) != OK:
		push_error("StatusEffectRegistry: JSON parse error: %s" % parser.get_error_message())
		return
	var raw: Variant = parser.data
	if raw is Dictionary:
		for key: String in raw:
			_data[StringName(key)] = _build_effect(StringName(key), raw[key])


static func _build_effect(id: StringName, d: Dictionary) -> StatusEffect:
	var e := StatusEffect.new()
	e.id = id
	e.display_name = d.get("display_name", String(id))
	e.element = int(d.get("element", 0))
	e.duration_sec = float(d.get("duration_sec", 0.0))
	e.tick_interval = float(d.get("tick_interval", 0.0))
	e.damage_per_tick = int(d.get("damage_per_tick", 0))
	e.speed_multiplier = float(d.get("speed_multiplier", 1.0))
	e.stun = bool(d.get("stun", false))
	return e


static func reset() -> void:
	_data = {}
	_loaded = false


static func all_ids() -> Array:
	_ensure_loaded()
	return _data.keys()


static func has_effect(id: StringName) -> bool:
	_ensure_loaded()
	return _data.has(id)


static func get_effect(id: StringName) -> StatusEffect:
	_ensure_loaded()
	return _data.get(id, null)


## Return the effect whose element matches, or null.
static func get_effect_for_element(element: int) -> StatusEffect:
	_ensure_loaded()
	for eff: StatusEffect in _data.values():
		if eff.element == element:
			return eff
	return null


static func get_raw_data() -> Dictionary:
	_ensure_loaded()
	var out: Dictionary = {}
	for id: StringName in _data:
		var e: StatusEffect = _data[id]
		out[String(id)] = {
			"display_name": e.display_name,
			"element": e.element,
			"duration_sec": e.duration_sec,
			"tick_interval": e.tick_interval,
			"damage_per_tick": e.damage_per_tick,
			"speed_multiplier": e.speed_multiplier,
			"stun": e.stun,
		}
	return out


static func save_data(data: Dictionary) -> void:
	var clean: Dictionary = data.duplicate(true)
	var json_str: String = JSON.stringify(clean, "\t")
	var f: FileAccess = FileAccess.open(_PATH, FileAccess.WRITE)
	if f == null:
		push_error("StatusEffectRegistry: cannot write %s" % _PATH)
		return
	f.store_string(json_str)
	f.close()
	_loaded = false
	_ensure_loaded()
