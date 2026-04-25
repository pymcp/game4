## DamageHeartVFX
##
## Floating damage indicator shown above a PlayerController when they take a hit.
## Draws a heart shape that fills from the bottom up: 1 HP = ¼ heart, 4 HP = full.
## On new damage while still visible, resets the animation and accumulates damage.
## After [const WINDOW_SEC] seconds, fades out over [const FADE_SEC] seconds.
extends Node2D
class_name DamageHeartVFX

const HP_PER_HEART: int = 4

## Native-pixel height of the heart (matches roughly 0.5× the HUD heart size).
const HEART_PX: float = 8.0

## Starting local Y offset above the player origin (native px, negative = up).
const START_Y: float = -20.0
## Y position at the end of the window phase (before fading starts).
const MID_Y: float = -34.0
## Final Y after the fade is complete.
const END_Y: float = -38.0

## How long the heart is fully visible before the fade begins.
const WINDOW_SEC: float = 1.5
## Duration of the fade-out.
const FADE_SEC: float = 0.4

## Base heart polygon at unit scale (7 wide × 6 tall).
## Matches HeartDisplay._BASE_POLY proportions.
static var _BASE_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(3.5, 6.0),
	Vector2(0.0, 2.5),
	Vector2(0.0, 1.5),
	Vector2(1.0, 0.0),
	Vector2(2.5, 0.0),
	Vector2(3.5, 1.2),
	Vector2(4.5, 0.0),
	Vector2(6.0, 0.0),
	Vector2(7.0, 1.5),
	Vector2(7.0, 2.5),
])

var _accumulated: int = 0
var _tween: Tween = null


func _ready() -> void:
	z_index = 2
	visible = false
	position.y = START_Y


## Called by PlayerController.take_hit() with the effective damage dealt.
func show_damage(amount: int) -> void:
	_accumulated = mini(_accumulated + amount, HP_PER_HEART)
	_restart_animation()


func _restart_animation() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	visible = true
	modulate.a = 1.0
	position.y = START_Y
	queue_redraw()
	_tween = create_tween()
	# Phase 1: rise at full opacity for WINDOW_SEC.
	_tween.tween_property(self, "position:y", MID_Y, WINDOW_SEC)
	# Phase 2: continue rising + fade out simultaneously over FADE_SEC.
	_tween.tween_property(self, "position:y", END_Y, FADE_SEC)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, FADE_SEC)
	_tween.tween_callback(_on_animation_done)


func _on_animation_done() -> void:
	visible = false
	_accumulated = 0
	queue_redraw()


func _draw() -> void:
	if _accumulated <= 0:
		return
	var fill: float = clampf(float(_accumulated) / float(HP_PER_HEART), 0.0, 1.0)
	var scale_f: float = HEART_PX / 7.0
	var heart_w: float = 7.0 * scale_f
	var heart_h: float = 6.0 * scale_f
	## Center the heart horizontally above the player.
	var ox: float = -heart_w * 0.5

	var poly := _scaled_poly(ox, scale_f)

	# Dark background heart.
	draw_colored_polygon(poly, Color(0.15, 0.0, 0.0, 0.9))

	if fill <= 0.0:
		return

	var fill_color := Color(0.9, 0.15, 0.15)
	if fill >= 1.0:
		draw_colored_polygon(poly, fill_color)
	else:
		# Fill from the bottom up: clip the heart polygon to the filled fraction.
		var clip_top: float = heart_h * (1.0 - fill)
		var clip_rect := PackedVector2Array([
			Vector2(ox - 1.0, clip_top),
			Vector2(ox + heart_w + 1.0, clip_top),
			Vector2(ox + heart_w + 1.0, heart_h + 1.0),
			Vector2(ox - 1.0, heart_h + 1.0),
		])
		var clipped: Array = Geometry2D.intersect_polygons(poly, clip_rect)
		for part: PackedVector2Array in clipped:
			draw_colored_polygon(part, fill_color)


func _scaled_poly(ox: float, scale_f: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for v: Vector2 in _BASE_POLY:
		result.append(Vector2(ox + v.x * scale_f, v.y * scale_f))
	return result
