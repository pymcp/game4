## SheetSpecReader
##
## Reads a `_spec.json` sidecar file from the directory containing a
## spritesheet PNG and returns a populated `SheetSpec`.
##
## The sidecar file is optional — when it is absent, unreadable, or
## malformed the reader silently returns a `SheetSpec` with defaults
## (tile_px=16, margin_px=1), matching the historical Kenney sheet format
## and producing no change in existing rendering behaviour.
##
## JSON schema (all keys optional):
##   { "tile_px": 64, "margin_px": 1 }
class_name SheetSpecReader
extends RefCounted

const _SPEC_FILENAME: String = "_spec.json"


## Returns a `SheetSpec` for the sheet at `sheet_path`.
## Looks for `_spec.json` in the same directory as the PNG.
## Falls back to defaults on any error.
static func read(sheet_path: String) -> SheetSpec:
	if sheet_path.is_empty():
		return SheetSpec.new()
	var dir: String = sheet_path.get_base_dir()
	var spec_path: String = dir + "/" + _SPEC_FILENAME
	if not FileAccess.file_exists(spec_path):
		return SheetSpec.new()
	var f := FileAccess.open(spec_path, FileAccess.READ)
	if f == null:
		return SheetSpec.new()
	var text: String = f.get_as_text()
	f.close()
	return _parse_spec(text)


## Parse a JSON string into a SheetSpec. Returns defaults on any error.
## Exposed as non-private so tests can exercise the parsing logic directly.
static func _parse_spec(text: String) -> SheetSpec:
	var spec := SheetSpec.new()
	if text.is_empty():
		return spec
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return spec
	var d: Dictionary = parsed as Dictionary
	var tile_val: Variant = d.get("tile_px", null)
	if tile_val != null and (tile_val is float or tile_val is int):
		var v: int = int(tile_val)
		if v > 0:
			spec.tile_px = v
	var margin_val: Variant = d.get("margin_px", null)
	if margin_val != null and (margin_val is float or margin_val is int):
		var v: int = int(margin_val)
		if v >= 0:
			spec.margin_px = v
	return spec
