## Equipment
##
## One slot per `ItemDefinition.Slot` value (excluding NONE). Tracks equipped
## item ids; the player aggregates `power` totals via `total_power_for()`.
##
## Enforces handedness rules:
##   - 2-handed weapon auto-unequips OFF_HAND (returns displaced id).
##   - Shield/off-hand item rejects equip if weapon is 2-handed.
##   - 1-handed weapon in OFF_HAND = dual-wield.
class_name Equipment
extends Resource

signal contents_changed

@export var equipped: Dictionary = {}  # Slot -> StringName item_id


## Check whether an item can legally go into a slot.
func can_equip(slot: ItemDefinition.Slot, item_id: StringName) -> bool:
	var def: ItemDefinition = ItemRegistry.get_item(item_id)
	if def == null:
		return false
	# OFF_HAND: reject if current weapon is 2-handed.
	if slot == ItemDefinition.Slot.OFF_HAND:
		var wpn_id: StringName = equipped.get(ItemDefinition.Slot.WEAPON, &"")
		if wpn_id != &"":
			var wpn_def: ItemDefinition = ItemRegistry.get_item(wpn_id)
			if wpn_def != null and wpn_def.hands >= 2:
				return false
	return true


## Equip an item to a slot. Returns array of [slot, item_id] pairs that were
## displaced (previous occupant + any forced unequips from handedness rules).
func equip(slot: ItemDefinition.Slot, item_id: StringName) -> Array:
	var displaced: Array = []
	var def: ItemDefinition = ItemRegistry.get_item(item_id)

	# Remove previous occupant of this slot.
	var prev: StringName = equipped.get(slot, &"")
	if prev != &"":
		displaced.append([slot, prev])

	# 2-handed weapon → auto-unequip OFF_HAND.
	if slot == ItemDefinition.Slot.WEAPON and def != null and def.hands >= 2:
		var off_id: StringName = equipped.get(ItemDefinition.Slot.OFF_HAND, &"")
		if off_id != &"":
			displaced.append([ItemDefinition.Slot.OFF_HAND, off_id])
			equipped.erase(ItemDefinition.Slot.OFF_HAND)

	equipped[slot] = item_id
	contents_changed.emit()
	return displaced


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


## Sum stat_bonuses from all equipped items plus active armor set bonuses.
## Returns { StringName → int } e.g. { &"strength": 2, &"speed": 1 }.
func equipment_stat_totals() -> Dictionary:
	var totals: Dictionary = {}
	for slot_key in equipped.keys():
		var def: ItemDefinition = ItemRegistry.get_item(equipped[slot_key])
		if def == null:
			continue
		for stat_key in def.stat_bonuses:
			var sn: StringName = StringName(stat_key)
			totals[sn] = totals.get(sn, 0) + int(def.stat_bonuses[stat_key])
	# Add armor set bonuses.
	var set_bonuses: Dictionary = get_active_set_bonuses()
	for stat_key in set_bonuses:
		totals[stat_key] = totals.get(stat_key, 0) + int(set_bonuses[stat_key])
	return totals


## Count equipped pieces per set_id, then sum up qualifying set bonuses.
## Returns { StringName → int } of cumulative set stat bonuses.
func get_active_set_bonuses() -> Dictionary:
	# Count pieces per set.
	var set_counts: Dictionary = {}
	for slot_key in equipped.keys():
		var def: ItemDefinition = ItemRegistry.get_item(equipped[slot_key])
		if def == null or def.set_id == "":
			continue
		set_counts[def.set_id] = set_counts.get(def.set_id, 0) + 1
	# Sum bonuses from each set.
	var totals: Dictionary = {}
	for sid in set_counts:
		var bonuses: Dictionary = ArmorSetRegistry.calc_set_bonuses(sid, set_counts[sid])
		for stat_key in bonuses:
			totals[stat_key] = totals.get(stat_key, 0) + int(bonuses[stat_key])
	return totals


func from_dict(data: Dictionary) -> void:
	equipped.clear()
	for k in data.keys():
		equipped[int(k)] = StringName(data[k])
	contents_changed.emit()
