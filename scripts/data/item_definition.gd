## ItemDefinition
##
## Static description of a single item kind. Stored as a Resource so designers
## can drop `.tres` overrides under `res://resources/items/<id>.tres` later.
##
## Equipment items use `slot` (else SLOT_NONE for materials/consumables) and
## may carry `power` (damage bonus for weapons, defense bonus for armor).
class_name ItemDefinition
extends Resource

enum Slot { NONE, WEAPON, TOOL, HEAD, BODY, FEET }

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D = null
@export var stack_size: int = 99
@export var slot: Slot = Slot.NONE
@export var power: int = 0
@export var description: String = ""
