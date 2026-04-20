## Equipment
##
## One slot per `ItemDefinition.Slot` value (excluding NONE). Tracks equipped
## item ids; the player aggregates `power` totals via `total_power_for()`.
##
## Phase 5 keeps this minimal. Phase 6 wires it to the inventory UI; Phase 7
## consults equipment for damage/defense math.
class_name Equipment
extends Resource

signal contents_changed

@export var equipped: Dictionary = {}  # Slot -> StringName item_id


func equip(slot: ItemDefinition.Slot, item_id: StringName) -> StringName:
	var prev: StringName = equipped.get(slot, &"")
	equipped[slot] = item_id
	contents_changed.emit()
	return prev


func unequip(slot: ItemDefinition.Slot) -> StringName:
	var prev: StringName = equipped.get(slot, &"")
	equipped.erase(slot)
	contents_changed.emit()
	return prev


func get_equipped(slot: ItemDefinition.Slot) -> StringName:
	return equipped.get(slot, &"")


## Sum of `power` across all equipped items, optionally filtered by slot kind.
## Pass `Slot.NONE` for the grand total.
func total_power(only_slot: ItemDefinition.Slot = ItemDefinition.Slot.NONE) -> int:
	var total: int = 0
	for slot_key in equipped.keys():
		if only_slot != ItemDefinition.Slot.NONE and slot_key != only_slot:
			continue
		var def: ItemDefinition = ItemRegistry.get_item(equipped[slot_key])
		if def != null:
			total += def.power
	return total


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for slot_key in equipped.keys():
		out[int(slot_key)] = String(equipped[slot_key])
	return out


func from_dict(data: Dictionary) -> void:
	equipped.clear()
	for k in data.keys():
		equipped[int(k)] = StringName(data[k])
	contents_changed.emit()
