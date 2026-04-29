## PetRegistry
##
## Static cache for resources/pets.json.
## Game data only (display name, special ability, cooldown) — sprite data lives
## in creature_sprites.json, tagged with "is_pet": true.
## Call reload() after editing pets.json to clear the cache.
##
## TODO (FUTURE): charmed creatures can also become pets — pass the creature's
## kind to Pet.make_charmed(kind). Sprite data already lives in
## creature_sprites.json; only ability/display data would need a pets.json
## fallback entry (or a shared "charmed" default).
class_name PetRegistry
extends RefCounted

const _PATH: String = "res://resources/pets.json"

static var _data: Dictionary = {}
static var _loaded: bool = false
static var _species_list: Array[StringName] = []


static func _ensure_loaded() -> void:
	if _loaded:
		return
	var f := FileAccess.open(_PATH, FileAccess.READ)
	if f == null:
		push_error("PetRegistry: cannot open %s" % _PATH)
		_loaded = true
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_data = parsed as Dictionary
	_species_list.clear()
	for k: String in _data.keys():
		_species_list.append(StringName(k))
	_loaded = true


## All pet species StringNames in JSON key order.
static func all_species() -> Array[StringName]:
	_ensure_loaded()
	return _species_list.duplicate()


static func get_display_name(species: StringName) -> String:
	_ensure_loaded()
	var e: Dictionary = _data.get(String(species), {})
	return e.get("display_name", String(species))


static func get_ability(species: StringName) -> StringName:
	_ensure_loaded()
	var e: Dictionary = _data.get(String(species), {})
	return StringName(e.get("special_ability", "none"))


static func get_ability_description(species: StringName) -> String:
	_ensure_loaded()
	var e: Dictionary = _data.get(String(species), {})
	return e.get("ability_description", "")


static func get_ability_cooldown(species: StringName) -> float:
	_ensure_loaded()
	var e: Dictionary = _data.get(String(species), {})
	return float(e.get("ability_cooldown_sec", 0.0))


## Clear cache (call after editing pets.json at runtime).
static func reload() -> void:
	_data = {}
	_species_list.clear()
	_loaded = false
