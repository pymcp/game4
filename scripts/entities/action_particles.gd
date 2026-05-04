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


## Flash a [CanvasItem] bright yellow for ~1 s as level-up feedback.
## Tween: yellow peak over 0.1 s, hold 0.2 s, fade back over 0.7 s.
static func flash_level_up(node: CanvasItem) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "modulate", Color(3.0, 2.5, 0.0, 1.0), 0.1)
	tw.tween_interval(0.2)
	tw.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.7)
