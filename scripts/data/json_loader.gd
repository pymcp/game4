## JsonLoader
##
## Static utility for loading and saving JSON files used by all registries.
## Centralises file-not-found / parse-error handling so each registry only
## needs one line to load its data.
##
## Usage:
##   var data: Dictionary = JsonLoader.load_dict("res://resources/foo.json")
##   JsonLoader.save_dict("res://resources/foo.json", data)
class_name JsonLoader
extends RefCounted


## Load a JSON file and return its top-level value as a [Dictionary].
## Returns an empty [Dictionary] on any error (file missing, parse failure).
static func load_dict(path: String) -> Dictionary:
	var raw: Variant = _parse(path)
	if raw is Dictionary:
		return raw as Dictionary
	return {}


## Load a JSON file and return the value at [param key] as an [Array].
## Returns an empty [Array] on any error.
static func load_array(path: String, key: String = "") -> Array:
	var raw: Variant = _parse(path)
	if key == "":
		if raw is Array:
			return raw as Array
		return []
	if raw is Dictionary:
		var v: Variant = (raw as Dictionary).get(key, [])
		if v is Array:
			return v as Array
	return []


## Write [param data] to [param path] as formatted JSON (tab-indented).
## Logs a push_error on failure.
static func save_dict(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[JsonLoader] cannot write %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


## Write [param data] wrapped in [code]{"<key>": data}[/code] to [param path].
static func save_array_under_key(path: String, key: String, data: Array) -> void:
	save_dict(path, {key: data})


# ─── internal ─────────────────────────────────────────────────────────────────

static func _parse(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("[JsonLoader] file not found: %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("[JsonLoader] cannot open: %s" % path)
		return null
	var text: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("[JsonLoader] parse error in %s: %s" % [path, json.get_error_message()])
		return null
	return json.data
