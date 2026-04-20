## Hittable
##
## Attach as a child Node of a decoration Sprite2D to make it minable / chop-
## able. Holds HP and emits `destroyed(kind, world_position)` when reduced
## to zero, then queue_frees the parent decoration node.
##
## Phase 5 will hook the destroyed signal into the inventory system to drop
## items (wood, stone, ...).
class_name Hittable
extends Node

signal damaged(remaining_hp: int, attacker: Node)
signal destroyed(kind: StringName, world_position: Vector2)

const HP_BY_KIND: Dictionary = {
	&"tree": 3,
	&"rock": 5,
	&"bush": 1,
}

@export var kind: StringName = &"tree"
@export var hp: int = 1


func _ready() -> void:
	if hp <= 0:
		hp = HP_BY_KIND.get(kind, 1)


func take_hit(damage: int, attacker: Node = null) -> void:
	hp -= damage
	if hp > 0:
		damaged.emit(hp, attacker)
		return
	var parent_pos: Vector2 = (get_parent() as Node2D).position if get_parent() is Node2D else Vector2.ZERO
	destroyed.emit(kind, parent_pos)
	if get_parent() != null:
		get_parent().queue_free()


## Convenience for systems that want to query mineable kinds.
static func is_mineable_kind(k: StringName) -> bool:
	return HP_BY_KIND.has(k)
