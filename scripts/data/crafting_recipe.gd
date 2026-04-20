## CraftingRecipe
##
## One recipe: a list of (item_id, count) inputs and a single (item_id, count)
## output. Stored as a Resource so designers can override on disk.
class_name CraftingRecipe
extends Resource

@export var id: StringName = &""
@export var inputs: Array = []  # Array of {id: StringName, count: int}
@export var output_id: StringName = &""
@export var output_count: int = 1


## Returns true if `inv` contains every input in the required count.
func can_craft(inv: Inventory) -> bool:
	for ing in inputs:
		if not inv.has(ing["id"], int(ing["count"])):
			return false
	return true


## Consume inputs from `inv` and grant outputs. Returns true on success.
func craft(inv: Inventory) -> bool:
	if not can_craft(inv):
		return false
	for ing in inputs:
		inv.remove(ing["id"], int(ing["count"]))
	var leftover: int = inv.add(output_id, output_count)
	# Roll back if the output didn't fit.
	if leftover > 0:
		inv.remove(output_id, output_count - leftover)
		for ing in inputs:
			inv.add(ing["id"], int(ing["count"]))
		return false
	return true
