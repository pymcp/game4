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
	quest_started.emit(quest_id, branch_id)


## Advance [param objective_id] by [param amount] (default 1).
## Emits [signal objective_updated].
func advance_objective(quest_id: String, objective_id: String, amount: int = 1) -> void:
	if not _active.has(quest_id):
		return
	var state: Dictionary = _active[quest_id]
	if state["complete"]:
		return
	var objs: Dictionary = state["objectives"]
	if not objs.has(objective_id):
		return
	objs[objective_id] = objs[objective_id] + amount
	objective_updated.emit(quest_id, objective_id, objs[objective_id])


## Mark a talk / reach / interact objective as done (sets progress to 1).
func mark_objective_done(quest_id: String, objective_id: String) -> void:
	advance_objective(quest_id, objective_id, 1)


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


# ─── Serialization ────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return _active.duplicate(true)


func from_dict(d: Dictionary) -> void:
	_active = d.duplicate(true)


func reset() -> void:
	_active.clear()


# ─── Internals ────────────────────────────────────────────────────────

func _apply_rewards(rewards: Array) -> void:
	for reward in rewards:
		match reward.get("type", ""):
			"flag":
				GameState.set_flag(reward["flag"])
			"unlock_passage":
				GameState.set_flag("passage_%s_unlocked" % reward.get("passage_id", "unknown"))
			"give_item":
				# Item system not yet implemented — set a flag as placeholder.
				GameState.set_flag("reward_%s_given" % reward.get("item", "unknown"))
			_:
				push_warning("QuestTracker: unknown reward type '%s'" % reward.get("type", ""))
