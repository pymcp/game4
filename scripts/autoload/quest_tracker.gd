## QuestTracker
##
## Autoload that tracks active quest state at runtime.  Supports branching
## quests — when starting a quest the caller specifies which branch the
## player chose, and only that branch's objectives are tracked.
##
## Persisted via [method to_dict] / [method from_dict] inside [SaveManager].
extends Node

## Emitted when a quest begins.  [param quest_id] is the quest,
## [param branch_id] is the chosen branch.
signal quest_started(quest_id: String, branch_id: String)

## Emitted when an objective advances.  [param progress] is the new count.
signal objective_updated(quest_id: String, objective_id: String, progress: int)

## Emitted when a quest is completed and rewards have been applied.
signal quest_completed(quest_id: String)

## Per-quest tracking state.
## Key: quest_id → { "branch": String, "objectives": { obj_id: int }, "complete": bool }
var _active: Dictionary = {}

## Objective world positions registered by WorldRoot.
## Key: "quest_id:obj_id" → { "region_id": Vector2i, "cell": Vector2i, "quest_id": String, "obj_id": String }
var _objective_positions: Dictionary = {}

## Chronological log of world events (location reached, item collected, objective
## directly marked done). Replayed against each quest when it starts so that
## objectives completed before quest acceptance are still credited.
## Entries: { "type": StringName, ...payload }
## Persisted in save data so pre-quest actions survive a reload.
var _event_buffer: Array = []


# ─── Public API ───────────────────────────────────────────────────────

## Start tracking [param quest_id] using [param branch_id].
## Sets the trigger flag in [GameState] and emits [signal quest_started].
## Does nothing if the quest is already active or completed.
func start_quest(quest_id: String, branch_id: String) -> void:
	if _active.has(quest_id):
		return
	var branch: Dictionary = QuestRegistry.get_branch(quest_id, branch_id)
	if branch.is_empty():
		push_warning("QuestTracker: unknown branch '%s' in quest '%s'" % [branch_id, quest_id])
		return
	var obj_progress: Dictionary = {}
	for obj in branch.get("objectives", []):
		obj_progress[obj["id"]] = 0
	_active[quest_id] = {
		"branch": branch_id,
		"objectives": obj_progress,
		"complete": false,
	}
	# Set trigger flag so dialogue / game logic can branch.
	var trigger: String = branch.get("trigger_flag", "")
	if trigger != "":
		GameState.set_flag(trigger)
	GameState.set_flag("quest_%s_started" % quest_id)
	# Credit any objectives the player already completed before accepting the quest.
	_replay_buffer_for(quest_id)
	quest_started.emit(quest_id, branch_id)


## Advance [param objective_id] by [param amount] (default 1).
## Emits [signal objective_updated]. Sets an auto-flag when the objective reaches its target.
func advance_objective(quest_id: String, objective_id: String, amount: int = 1) -> void:
	if not _active.has(quest_id):
		return
	var state: Dictionary = _active[quest_id]
	if state["complete"]:
		return
	var objs: Dictionary = state["objectives"]
	if not objs.has(objective_id):
		return
	var branch: Dictionary = QuestRegistry.get_branch(quest_id, state["branch"])
	var target: int = 1
	for obj in branch.get("objectives", []):
		if obj.get("id", "") == objective_id:
			target = obj.get("count", 1)
			break
	objs[objective_id] = objs[objective_id] + amount
	if objs[objective_id] >= target:
		GameState.set_flag("quest_%s_obj_%s_done" % [quest_id, objective_id])
	objective_updated.emit(quest_id, objective_id, objs[objective_id])


## Called when a player picks up an item.  Scans all active quests for
## "collect" objectives matching [param item_id] and advances them.
## Also buffers the event so quests accepted later can still credit it.
func notify_item_collected(item_id: StringName, count: int = 1) -> void:
	_event_buffer.append({"type": &"collect", "item": String(item_id), "count": count})
	for quest_id in _active:
		var state: Dictionary = _active[quest_id]
		if state["complete"]:
			continue
		var branch: Dictionary = QuestRegistry.get_branch(quest_id, state["branch"])
		for obj in branch.get("objectives", []):
			if obj.get("type", "") != "collect":
				continue
			if StringName(obj.get("item", "")) != item_id:
				continue
			var target: int = obj.get("count", 1)
			var current: int = state["objectives"].get(obj["id"], 0)
			if current < target:
				var add: int = mini(count, target - current)
				advance_objective(quest_id, obj["id"], add)


## Mark a talk / reach / interact objective as done (sets progress to 1).
## Also buffers the event so it is credited if the quest starts later.
func mark_objective_done(quest_id: String, objective_id: String) -> void:
	_event_buffer.append({"type": &"done", "quest_id": quest_id, "obj_id": objective_id})
	advance_objective(quest_id, objective_id, 1)


## Called when a player reaches a location (e.g. enters a labyrinth).
## Scans active quests for "reach" objectives matching [param location_id].
## Also buffers the event so quests accepted later can still credit it.
func notify_location_reached(location_id: String) -> void:
	_event_buffer.append({"type": &"reach", "location": location_id})
	for quest_id in _active:
		var state: Dictionary = _active[quest_id]
		if state["complete"]:
			continue
		var branch: Dictionary = QuestRegistry.get_branch(quest_id, state["branch"])
		for obj in branch.get("objectives", []):
			if obj.get("type", "") != "reach":
				continue
			if obj.get("location", "") != location_id:
				continue
			mark_objective_done(quest_id, obj["id"])


## Return the current progress value for an objective, or -1 if not tracked.
func get_objective_progress(quest_id: String, objective_id: String) -> int:
	if not _active.has(quest_id):
		return -1
	return _active[quest_id]["objectives"].get(objective_id, -1)


## Check whether every objective in the quest meets its target count.
func is_quest_ready_to_complete(quest_id: String) -> bool:
	if not _active.has(quest_id):
		return false
	var state: Dictionary = _active[quest_id]
	if state["complete"]:
		return false
	var branch: Dictionary = QuestRegistry.get_branch(quest_id, state["branch"])
	for obj in branch.get("objectives", []):
		var target: int = obj.get("count", 1)
		var current: int = state["objectives"].get(obj["id"], 0)
		if current < target:
			return false
	return true


## Complete the quest: apply rewards and set completion flags.
## Does nothing if objectives are not all met.
func complete_quest(quest_id: String) -> void:
	if not is_quest_ready_to_complete(quest_id):
		return
	var state: Dictionary = _active[quest_id]
	state["complete"] = true
	# Apply branch rewards.
	var branch: Dictionary = QuestRegistry.get_branch(quest_id, state["branch"])
	_apply_rewards(branch.get("rewards", []))
	# Apply any matching reward variants.
	var quest: Dictionary = QuestRegistry.get_quest(quest_id)
	for variant in quest.get("reward_variants", {}).values():
		var cond: String = variant.get("condition_flag", "")
		if cond != "" and not GameState.get_flag(cond):
			continue
		_apply_rewards(variant.get("rewards", []))
	GameState.set_flag("quest_%s_complete" % quest_id)
	quest_completed.emit(quest_id)


## Returns true if the quest is active (started but not complete).
func is_quest_active(quest_id: String) -> bool:
	if not _active.has(quest_id):
		return false
	return not _active[quest_id]["complete"]


## Returns all quest IDs that are currently active (started but not complete).
func get_all_active_quest_ids() -> Array[String]:
	var result: Array[String] = []
	for qid: String in _active:
		if not _active[qid]["complete"]:
			result.append(qid)
	return result


## Returns true if the quest has been completed.
func is_quest_complete(quest_id: String) -> bool:
	if not _active.has(quest_id):
		return false
	return _active[quest_id]["complete"]


## Return the branch id the player chose for [param quest_id], or "".
func get_active_branch(quest_id: String) -> String:
	if not _active.has(quest_id):
		return ""
	return _active[quest_id]["branch"]


# ─── Private helpers ──────────────────────────────────────────────────

## Replay the event buffer against [param quest_id] (which must already be in
## _active). Called immediately after a quest is initialised so any objectives
## completed before the quest was accepted are retroactively credited.
func _replay_buffer_for(quest_id: String) -> void:
	var state: Dictionary = _active[quest_id]
	var branch: Dictionary = QuestRegistry.get_branch(quest_id, state["branch"])
	var objectives: Array = branch.get("objectives", [])
	for event in _event_buffer:
		match event["type"]:
			&"reach":
				for obj in objectives:
					if obj.get("type") == "reach" and obj.get("location", "") == event["location"]:
						advance_objective(quest_id, obj["id"])
			&"collect":
				var ev_item: StringName = StringName(event.get("item", ""))
				var ev_count: int = event.get("count", 1)
				for obj in objectives:
					if obj.get("type") != "collect":
						continue
					if StringName(obj.get("item", "")) != ev_item:
						continue
					var target: int = obj.get("count", 1)
					var current: int = state["objectives"].get(obj["id"], 0)
					if current < target:
						advance_objective(quest_id, obj["id"], mini(ev_count, target - current))
			&"done":
				if event.get("quest_id", "") == quest_id:
					advance_objective(quest_id, event.get("obj_id", ""))


# ─── Serialization ────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"active": _active.duplicate(true),
		"event_buffer": _event_buffer.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	# Support old saves that stored _active directly (no "active" key).
	if d.has("active"):
		_active = d["active"].duplicate(true)
		_event_buffer = d.get("event_buffer", []).duplicate(true)
	else:
		_active = d.duplicate(true)
		_event_buffer = []


func reset() -> void:
	_active.clear()
	_event_buffer.clear()
	_objective_positions.clear()


## Register the world position of a quest objective so the map can display a marker.
## Called by WorldRoot when placing quest-relevant entities.
func register_objective_position(quest_id: String, obj_id: String,
		region_id: Vector2i, cell: Vector2i) -> void:
	var key: String = "%s:%s" % [quest_id, obj_id]
	_objective_positions[key] = {
		"quest_id": quest_id,
		"obj_id": obj_id,
		"region_id": region_id,
		"cell": cell,
	}


## Returns all registered objective positions ordered so the first incomplete
## objective of any active quest comes first. WorldMapView draws the first entry.
func get_objective_markers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in _objective_positions:
		var entry: Dictionary = _objective_positions[key]
		var qid: String = entry["quest_id"]
		var oid: String = entry["obj_id"]
		if not is_quest_active(qid):
			continue
		if get_objective_progress(qid, oid) > 0:
			continue  # already done
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# Order by the objective's position in the quest branch.
		var qa: String = a["quest_id"]; var qb: String = b["quest_id"]
		var branch_a: Dictionary = QuestRegistry.get_branch(qa, get_active_branch(qa))
		var branch_b: Dictionary = QuestRegistry.get_branch(qb, get_active_branch(qb))
		var objs_a: Array = branch_a.get("objectives", [])
		var objs_b: Array = branch_b.get("objectives", [])
		var idx_a: int = 999; var idx_b: int = 999
		for i in objs_a.size():
			if objs_a[i].get("id", "") == a["obj_id"]:
				idx_a = i; break
		for i in objs_b.size():
			if objs_b[i].get("id", "") == b["obj_id"]:
				idx_b = i; break
		return idx_a < idx_b
	)
	return result


# ─── Internals ────────────────────────────────────────────────────────

func _apply_rewards(rewards: Array) -> void:
	for reward in rewards:
		match reward.get("type", ""):
			"flag":
				GameState.set_flag(reward["flag"])
			"unlock_passage":
				GameState.set_flag("passage_%s_unlocked" % reward.get("passage_id", "unknown"))
			"give_item":
				var item_id: StringName = StringName(reward.get("item", ""))
				var item_count: int = int(reward.get("count", 1))
				if item_id == &"":
					break
				var world_node: World = World.instance()
				if world_node != null:
					for pid in 2:
						var p: PlayerController = world_node.get_player(pid)
						if p != null and p.inventory != null:
							p.inventory.add(item_id, item_count)
							break  # give to first valid player only
			"give_xp":
				var xp_amount: int = int(reward.get("amount", 0))
				if xp_amount > 0:
					var world_node: World = World.instance()
					if world_node != null:
						for pid in 2:
							var p: PlayerController = world_node.get_player(pid)
							if p != null:
								p.gain_xp(xp_amount)
			_:
				push_warning("QuestTracker: unknown reward type '%s'" % reward.get("type", ""))
