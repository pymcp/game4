## CaravanData
##
## Per-player caravan state: which party members have been recruited,
## and the shared caravan inventory (holds crafting ingredients that
## auto-transfer from the player on overworld entry).
##
## NOTE: Do NOT declare `signal changed` — Resource has it built-in.
class_name CaravanData
extends Resource

## IDs of recruited party members.
@export var recruited_ids: Array[StringName] = []
## Shared caravan inventory. Crafters draw from this for crafting.
@export var inventory: Inventory
## Per-player dungeon run tracker. Length 2 (index = player_id).
@export var travel_logs: Array[TravelLog] = []
## Rolled-once names for each party member. StringName → String.
@export var member_names: Dictionary = {}


func _init() -> void:
	inventory = Inventory.new(48)  # 48 slots — larger than player (24)
	travel_logs.append(TravelLog.new())
	travel_logs.append(TravelLog.new())


## Add a party member by ID. Silently ignores duplicates.
func add_member(id: StringName) -> void:
	if not recruited_ids.has(id):
		recruited_ids.append(id)
		changed.emit()


## Remove a party member by ID. Silently ignores if not present.
func remove_member(id: StringName) -> void:
	var idx: int = recruited_ids.find(id)
	if idx >= 0:
		recruited_ids.remove_at(idx)
		changed.emit()


## Returns true if the member with this ID is recruited.
func has_member(id: StringName) -> bool:
	return recruited_ids.has(id)

## Returns the rolled name for [param member_id], or the
## member's display_name from [PartyMemberDef] if not yet assigned.
func get_member_name(member_id: StringName) -> String:
	if member_names.has(member_id):
		return member_names[member_id]
	var def: PartyMemberDef = PartyMemberRegistry.get_member(member_id)
	return def.display_name if def != null else String(member_id)


## Serialize to a Dictionary for save/load.
func to_dict() -> Dictionary:
	return {
		"recruited_ids": recruited_ids.duplicate(),
		"inventory": inventory.to_dict(),
		"travel_logs": [travel_logs[0].to_dict(), travel_logs[1].to_dict()],
		"member_names": member_names.duplicate(),
	}


## Restore from a serialized Dictionary.
func from_dict(d: Dictionary) -> void:
	recruited_ids.clear()
	for id_str in d.get("recruited_ids", []):
		recruited_ids.append(StringName(id_str))
	var inv_data: Dictionary = d.get("inventory", {})
	if not inv_data.is_empty():
		inventory.from_dict(inv_data)
	var tl_data: Array = d.get("travel_logs", [{}, {}])
	for i in 2:
		if i < travel_logs.size() and i < tl_data.size():
			travel_logs[i].from_dict(tl_data[i])
	member_names = d.get("member_names", {}).duplicate()
