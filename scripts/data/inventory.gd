## Inventory
##
## Fixed-size slot array. Each slot is either null or a Dictionary with keys
## `id: StringName` and `count: int`. Stack rules come from the item's
## `stack_size` in `ItemRegistry`.
##
## Emits `changed` whenever any slot mutates. Save/load via `to_dict` /
## `from_dict` keeps the API stable while the storage layout evolves.
class_name Inventory
extends Resource

signal contents_changed

const DEFAULT_SIZE: int = 24

@export var size: int = DEFAULT_SIZE
@export var slots: Array = []  # Array of null | {id, count}


func _init(slot_count: int = DEFAULT_SIZE) -> void:
	size = slot_count
	slots.resize(size)
	for i in size:
		slots[i] = null


## Add `count` of `item_id` to the inventory, stacking onto existing slots
## first then filling empty slots. Returns the leftover count (0 on full
## success).
func add(item_id: StringName, count: int = 1) -> int:
	if count <= 0:
		return 0
	if not ItemRegistry.has_item(item_id):
		return count
	var stack_size: int = ItemRegistry.get_item(item_id).stack_size
	var remaining: int = count
	# Top up existing stacks first.
	for i in size:
		if remaining <= 0:
			break
		var s = slots[i]
		if s == null or s["id"] != item_id:
			continue
		var room: int = stack_size - s["count"]
		if room <= 0:
			continue
		var add_amt: int = min(room, remaining)
		s["count"] += add_amt
		remaining -= add_amt
	# Then drop into empty slots.
	for i in size:
		if remaining <= 0:
			break
		if slots[i] != null:
			continue
		var add_amt: int = min(stack_size, remaining)
		slots[i] = {"id": item_id, "count": add_amt}
		remaining -= add_amt
	if remaining != count:
		contents_changed.emit()
	return remaining


## Remove up to `count` of `item_id`. Returns the actual amount removed.
func remove(item_id: StringName, count: int = 1) -> int:
	if count <= 0:
		return 0
	var removed: int = 0
	for i in size:
		if removed >= count:
			break
		var s = slots[i]
		if s == null or s["id"] != item_id:
			continue
		var take: int = min(s["count"], count - removed)
		s["count"] -= take
		removed += take
		if s["count"] <= 0:
			slots[i] = null
	if removed > 0:
		contents_changed.emit()
	return removed


func count_of(item_id: StringName) -> int:
	var n: int = 0
	for s in slots:
		if s != null and s["id"] == item_id:
			n += s["count"]
	return n


func has(item_id: StringName, count: int = 1) -> bool:
	return count_of(item_id) >= count



## Remove the item in slot `i` entirely; returns the dict (or null).
func take_slot(i: int) -> Variant:
	if i < 0 or i >= size:
		return null
	var s = slots[i]
	if s == null:
		return null
	slots[i] = null
	contents_changed.emit()
	return s



func to_dict() -> Dictionary:
	var out: Dictionary = {"size": size, "slots": []}
	for s in slots:
		if s == null:
			out["slots"].append(null)
		else:
			# Copy so future mutations on the live inventory don't leak.
			out["slots"].append({"id": String(s["id"]), "count": int(s["count"])})
	return out


func from_dict(data: Dictionary) -> void:
	size = int(data.get("size", DEFAULT_SIZE))
	slots.resize(size)
	var arr: Array = data.get("slots", [])
	for i in size:
		var entry = arr[i] if i < arr.size() else null
		if entry == null:
			slots[i] = null
		else:
			slots[i] = {
				"id": StringName(entry["id"]),
				"count": int(entry["count"]),
			}
	contents_changed.emit()
