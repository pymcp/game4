## DeathRing
##
## Self-drawing expanding ring that frees itself when its lifetime expires.
## Added as a sibling of the dying entity (not a child) so it outlives queue_free.
extends Node2D
class_name DeathRing

var max_radius: float = 20.0
var lifetime: float = 0.35
var color: Color = Color.WHITE
var delay: float = 0.0

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t < delay:
		return
	if _t >= delay + lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var f: float = clamp((_t - delay) / lifetime, 0.0, 1.0)
	var r: float = lerp(0.0, max_radius, f)
	var alpha: float = (1.0 - f) * color.a
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48,
			Color(color.r, color.g, color.b, alpha), 2.0, true)
