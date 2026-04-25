## ActionParticles
##
## Static helper for visual hit feedback.
extends RefCounted
class_name ActionParticles


## Flash a [CanvasItem] bright white for 0.15 s as damage feedback.
## Safe to call on any Sprite2D, Node2D, etc. — creates its own tween.
static func flash_hit(node: CanvasItem) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "modulate", Color(3, 3, 3, 1), 0.05)
	tw.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.1)
