class_name DebugFeedbackLogger
extends RefCounted
## Static helper that appends dialogue feedback entries to a JSON log file
## located at res://tmp/dialogue_feedback.json.
##
## Each entry is a Dictionary produced by [method DialogueBox._build_feedback_entry].
## The file contains a JSON array; entries are appended in order.

const LOG_PATH: String = "res://tmp/dialogue_feedback.json"


## Append [param entry] to the log file.  Creates the file if it does not exist.
## Silently drops the write on file-access failure so it never crashes the game.
static func log_entry(entry: Dictionary) -> void:
	var existing: Array = _read_existing()
	existing.append(entry)
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("DebugFeedbackLogger: cannot write to %s" % LOG_PATH)
		return
	f.store_string(JSON.stringify(existing, "\t"))
	f.close()


## Read and return all existing log entries, or an empty array on any error.
static func read_all() -> Array:
	return _read_existing()


## Delete the log file (useful in tests or to start fresh).
static func clear() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))


# ─── Internal ─────────────────────────────────────────────────────────────────

static func _read_existing() -> Array:
	if not FileAccess.file_exists(LOG_PATH):
		return []
	var f := FileAccess.open(LOG_PATH, FileAccess.READ)
	if f == null:
		return []
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		return parsed
	return []
