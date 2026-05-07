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


## Flash a [CanvasItem] bright yellow for ~1 s as level-up feedback,
## then burst 10 shooting-star particles outward from the node's position.
## Tween: yellow peak over 0.1 s, hold 0.2 s, fade back over 0.7 s.
static func flash_level_up(node: CanvasItem) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "modulate", Color(3.0, 2.5, 0.0, 1.0), 0.1)
	tw.tween_interval(0.2)
	tw.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.7)
	# Shoot 10 star particles outward from the node.
	var parent: Node = node.get_parent()
	if parent == null:
		return
	var star_colors: Array[Color] = [
		Color(1.0, 0.9, 0.2, 1.0),  # Gold
		Color(1.0, 1.0, 1.0, 1.0),  # White
		Color(1.0, 0.7, 0.0, 1.0),  # Orange
		Color(0.9, 1.0, 0.4, 1.0),  # Yellow-green
	]
	for i: int in 10:
		var star := ColorRect.new()
		star.size = Vector2(3, 3)
		star.color = star_colors[i % star_colors.size()]
		star.position = node.position - Vector2(1.5, 1.5)
		parent.add_child(star)
		var angle: float = (float(i) / 10.0) * TAU
		var dist: float = randf_range(16.0, 32.0)
		var target: Vector2 = node.position + Vector2(cos(angle), sin(angle)) * dist
		var stw: Tween = star.create_tween()
		stw.set_parallel(true)
		stw.tween_property(star, "position", target - Vector2(1.5, 1.5), 0.5)
		stw.tween_property(star, "modulate:a", 0.0, 0.5)
		stw.set_parallel(false)
		stw.tween_callback(star.queue_free)
