## QuestRegistry
##
## Loads, caches, and queries per-quest JSON files from
## `res://resources/quests/`.  Each file defines one quest with its
## branches, objectives, rewards, and requirements manifest.
##
## Usage:
##   var quest: Dictionary = QuestRegistry.get_quest("herbalist_remedy")
##   var ids: Array[String] = QuestRegistry.all_ids()
##   var missing: Array = QuestRegistry.get_unimplemented_requirements("herbalist_remedy")
class_name QuestRegistry
extends RefCounted

const _DIR: String = "res://resources/quests"

## Cached quest data keyed by quest id.
static var _quests: Dictionary = {}
static var _loaded: bool = false


# ─── Loading ──────────────────────────────────────────────────────────

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_quests = _load_all()


static func _load_all() -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(_DIR)
	if dir == null:
		push_warning("QuestRegistry: cannot open %s" % _DIR)
		return out
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var quest: Dictionary = _load_file(_DIR.path_join(fname))
			if quest.size() > 0 and quest.has("id"):
				out[quest["id"]] = quest
		fname = dir.get_next()
	dir.list_dir_end()
	return out


static func _load_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("QuestRegistry: cannot open %s" % path)
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("QuestRegistry: failed to parse %s" % path)
		return {}
	return parsed as Dictionary


static func reload() -> void:
	_loaded = false
	_quests = {}


# ─── Editor API ───────────────────────────────────────────────────────

## Return the raw quest data for editor display.
static func get_raw_data() -> Dictionary:
	_ensure_loaded()
	return _quests


## Save a single quest's data to its JSON file and update the cache.
static func save_quest(quest_id: String, data: Dictionary) -> void:
	_ensure_loaded()
	var save_data: Dictionary = data.duplicate(true)
	save_data["id"] = quest_id
	_quests[quest_id] = save_data
	var path: String = _DIR.path_join(quest_id + ".json")
	var text: String = JSON.stringify(save_data, "\t")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("QuestRegistry: cannot write %s" % path)
		return
	f.store_string(text)
	f.close()


## Create a new blank quest template and save to disk.
static func create_quest(quest_id: String) -> Dictionary:
	var template: Dictionary = {
		"id": quest_id,
		"display_name": quest_id.capitalize(),
		"giver": "",
		"description": "",
		"prerequisites": [],
		"branches": {},
		"requires": {}
	}
	save_quest(quest_id, template)
	return template


## Delete a quest from cache and disk.
static func delete_quest(quest_id: String) -> void:
	_ensure_loaded()
	_quests.erase(quest_id)
	var path: String = _DIR.path_join(quest_id + ".json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ─── Queries ──────────────────────────────────────────────────────────

## Return the full quest dict for [param id], or an empty Dictionary.
static func get_quest(id: String) -> Dictionary:
	_ensure_loaded()
	return _quests.get(id, {})


## All loaded quest ids.
static func all_ids() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for k in _quests.keys():
		out.append(k)
	return out


## Return the branch dict for [param branch_id] within [param quest_id].
## If the branch uses "includes", the merged objective list is returned in
## an "objectives" key built from the referenced branches.
static func get_branch(quest_id: String, branch_id: String) -> Dictionary:
	var quest: Dictionary = get_quest(quest_id)
	if quest.is_empty():
		return {}
	var branches: Dictionary = quest.get("branches", {})
	if not branches.has(branch_id):
		return {}
	var branch: Dictionary = (branches[branch_id] as Dictionary).duplicate(true)
	# Resolve "includes" — merge objectives from referenced branches.
	if branch.has("includes"):
		var merged: Array = []
		for ref_id in branch["includes"]:
			if branches.has(ref_id):
				var ref: Dictionary = branches[ref_id]
				merged.append_array(ref.get("objectives", []))
		branch["objectives"] = merged
	return branch


## Return the prerequisite quest ids for [param quest_id].
static func get_prerequisites(quest_id: String) -> Array[String]:
	var quest: Dictionary = get_quest(quest_id)
	var out: Array[String] = []
	for p in quest.get("prerequisites", []):
		out.append(str(p))
	return out


## Return an Array of requirement entries whose status is "NOT_IMPLEMENTED".
## Each entry is a Dictionary with at least "id", "status", and "category".
static func get_unimplemented_requirements(quest_id: String) -> Array[Dictionary]:
	var quest: Dictionary = get_quest(quest_id)
	var requires: Dictionary = quest.get("requires", {})
	var out: Array[Dictionary] = []
	for category in requires:
		if category == "notes":
			continue
		var entries: Variant = requires[category]
		if not entries is Array:
			continue
		for entry in entries:
			if entry is Dictionary and entry.get("status", "") == "NOT_IMPLEMENTED":
				var item: Dictionary = entry.duplicate()
				item["category"] = category
				out.append(item)
	return out


## Return the count of all requirements and how many are implemented.
## Returns {"total": int, "implemented": int, "not_implemented": int}.
static func get_requirement_summary(quest_id: String) -> Dictionary:
	var quest: Dictionary = get_quest(quest_id)
	var requires: Dictionary = quest.get("requires", {})
	var total: int = 0
	var done: int = 0
	for category in requires:
		if category == "notes":
			continue
		var entries: Variant = requires[category]
		if not entries is Array:
			continue
		for entry in entries:
			if entry is Dictionary and entry.has("status"):
				total += 1
				if entry["status"] != "NOT_IMPLEMENTED":
					done += 1
	return {"total": total, "implemented": done, "not_implemented": total - done}
