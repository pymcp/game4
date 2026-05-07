## DeathVFX
##
## Static utility for the Shrink-and-Pop death animation.
## Call DeathVFX.play() from an entity's _die() in place of queue_free().
## DeathVFX owns the queue_free() call.
class_name DeathVFX

## Ring color indexed by ItemDefinition.Element value.
const ELEMENT_COLORS: Dictionary = {
	0: Color("#dddddd"),  # NONE / Physical
	1: Color("#ff6600"),  # FIRE
	2: Color("#44ccff"),  # ICE
	3: Color("#ffee44"),  # LIGHTNING
	4: Color("#88ff44"),  # POISON
}

## [duration_sec, ring_max_radius_px] indexed by tier 0–4.
const TIER_PARAMS: Array = [
	[0.28, 18.0],
	[0.30, 22.0],
	[0.33, 26.0],
	[0.37, 30.0],
	[0.42, 35.0],
]

## Play the death animation on [param entity].
## [param visual] is the sprite or sprite root to shrink (child of entity).
## [param tier] is 0–4; clamped if out of range.
## [param element] is an ItemDefinition.Element int for ring color.
## entity.queue_free() is called when the tween completes — do NOT call it yourself.
static func play(entity: Node2D, visual: Node2D, tier: int, element: int) -> void:
	var p: Array = TIER_PARAMS[clampi(tier, 0, 4)]
	var dur: float = p[0]
	var radius: float = p[1]
	var col: Color = ELEMENT_COLORS.get(element, ELEMENT_COLORS[0])

	_spawn_ring(entity, radius, dur * 1.1, col, 0.0)
	if tier >= 4:
		_spawn_ring(entity, radius * 0.65, dur, col, 0.06)
		_shake_all_cameras(entity, 2.0, 0.15)

	var tw: Tween = entity.create_tween()
	var base_scale: Vector2 = visual.scale
	tw.tween_property(visual, "scale", base_scale * 1.15, dur * 0.2)
	tw.tween_property(visual, "scale", Vector2.ZERO, dur * 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(entity.queue_free)

	var tw_fade: Tween = entity.create_tween()
	tw_fade.tween_interval(dur * 0.4)
	tw_fade.tween_property(visual, "modulate:a", 0.0, dur * 0.6)


static func _spawn_ring(entity: Node2D, radius: float, lifetime: float,
		col: Color, delay: float) -> void:
	var ring := DeathRing.new()
	ring.max_radius = radius
	ring.lifetime = lifetime
	ring.color = col
	ring.delay = delay
	ring.global_position = entity.global_position
	entity.get_parent().add_child(ring)


static func _shake_all_cameras(entity: Node2D, magnitude: float, duration: float) -> void:
	for cam: Node in entity.get_tree().get_nodes_in_group(&"player_cameras"):
		var tw: Tween = cam.create_tween()
		tw.tween_property(cam, "offset", Vector2(magnitude, magnitude), duration * 0.25)
		tw.tween_property(cam, "offset", Vector2(-magnitude, 0.0), duration * 0.25)
		tw.tween_property(cam, "offset", Vector2.ZERO, duration * 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
