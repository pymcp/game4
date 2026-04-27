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


func _init() -> void:
	inventory = Inventory.new(48)  # 48 slots — larger than player (24)


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


## Serialize to a Dictionary for save/load.
func to_dict() -> Dictionary:
	return {
		"recruited_ids": recruited_ids.duplicate(),
		"inventory": inventory.to_dict(),
	}


## Restore from a serialized Dictionary.
func from_dict(d: Dictionary) -> void:
	recruited_ids.clear()
	for id_str in d.get("recruited_ids", []):
		recruited_ids.append(StringName(id_str))
	var inv_data: Dictionary = d.get("inventory", {})
	if not inv_data.is_empty():
		inventory.from_dict(inv_data)
