## HeartDisplay
##
## Procedural heart-based health indicator. Each heart represents
## [constant HP_PER_HEART] hit-points. Partial fills are shown as a
## red-to-black gradient within the heart shape.  When a heart empties
## completely a brief break animation plays.
##
## Two sizes: [code]heart_px = 12[/code] for the player HUD,
## [code]heart_px = 6[/code] for the entity overhead strip.
##
## Pure helpers [method heart_count] and [method heart_fill] are static
## so they can be unit-tested without a scene tree.
extends Control
class_name HeartDisplay

const HP_PER_HEART: int = 4
const SPACING_FRAC: float = 0.35  ## gap between hearts as fraction of heart width

## Base heart polygon at unit scale (≈7×6, same proportions as Pet heart).
## Scaled by [member _heart_px] at draw time.
static var _BASE_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(3.5, 6.0),  # bottom tip
	Vector2(0.0, 2.5),  # left edge
	Vector2(0.0, 1.5),  # left top-curve
	Vector2(1.0, 0.0),  # left lobe
	Vector2(2.5, 0.0),  # inner left
	Vector2(3.5, 1.2),  # center dip
	Vector2(4.5, 0.0),  # inner right
	Vector2(6.0, 0.0),  # right lobe
	Vector2(7.0, 1.5),  # right top-curve
	Vector2(7.0, 2.5),  # right edge
])

var _heart_px: float = 12.0
var _curr: int = 0
var _max: int = 1
var _prev_fills: Array = []  ## float per heart — tracks previous fill for break detect


func _init(heart_px: float = 12.0) -> void:
	_heart_px = heart_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Pure helpers ---------------------------------------------------

## How many hearts to display for [param max_hp].
static func heart_count(max_hp: int) -> int:
	if max_hp <= 0:
		return 0
	return ceili(float(max_hp) / float(HP_PER_HEART))


## Fill ratio [code][0..1][/code] for heart at [param idx] (0-based).
## A heart covers HP range [code][idx*4 .. (idx+1)*4][/code].
static func heart_fill(curr_hp: int, max_hp: int, idx: int) -> float:
	var lo: int = idx * HP_PER_HEART
	var hi: int = lo + HP_PER_HEART
	# Cap hi at max_hp so the last heart only fills to its true max.
	if hi > max_hp:
		hi = max_hp
	var span: int = hi - lo
	if span <= 0:
		return 0.0
	var filled: int = clampi(curr_hp - lo, 0, span)
	return float(filled) / float(span)


# --- Update ---------------------------------------------------------

func update(curr: int, max_value: int) -> void:
	if curr == _curr and max_value == _max:
		return
	var old_count: int = heart_count(_max)
	var new_count: int = heart_count(max_value)
	# Detect break: a heart went from >0 fill to 0 fill.
	for i in range(mini(old_count, new_count)):
		var old_fill: float = _prev_fills[i] if i < _prev_fills.size() else 0.0
		var new_fill: float = heart_fill(curr, max_value, i)
		if old_fill > 0.0 and new_fill <= 0.0:
			_spawn_break(i)
	_curr = curr
	_max = max_value
	# Rebuild prev_fills.
	_prev_fills.resize(new_count)
	for i in range(new_count):
		_prev_fills[i] = heart_fill(_curr, _max, i)
	# Resize control to fit hearts.
	var scale_f: float = _heart_px / 7.0
	var w: float = float(new_count) * _heart_px + float(maxi(new_count - 1, 0)) * _heart_px * SPACING_FRAC
	var h: float = 6.0 * scale_f
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	queue_redraw()


# --- Drawing --------------------------------------------------------

func _draw() -> void:
	var count: int = heart_count(_max)
	if count <= 0:
		return
	var scale_f: float = _heart_px / 7.0
	var stride: float = _heart_px + _heart_px * SPACING_FRAC
	for i in range(count):
		var ox: float = float(i) * stride
		var fill: float = heart_fill(_curr, _max, i)
		_draw_heart(ox, scale_f, fill)


func _draw_heart(ox: float, scale_f: float, fill: float) -> void:
	var bg_color := Color(0.15, 0.1, 0.1, 0.85)
	var fill_color := Color(0.85, 0.15, 0.15)
	# Full background heart.
	var poly := _scaled_poly(ox, 0.0, scale_f)
	draw_colored_polygon(poly, bg_color)
	if fill <= 0.0:
		return
	# Filled portion — clip by drawing only the left slice of the heart.
	if fill >= 1.0:
		draw_colored_polygon(poly, fill_color)
	else:
		# Clip: use Geometry2D to intersect the heart with a rect covering
		# the filled fraction from the left.
		var heart_w: float = 7.0 * scale_f
		var heart_h: float = 6.0 * scale_f
		var clip_w: float = heart_w * fill
		var clip_rect: PackedVector2Array = PackedVector2Array([
			Vector2(ox, -1.0),
			Vector2(ox + clip_w, -1.0),
			Vector2(ox + clip_w, heart_h + 1.0),
			Vector2(ox, heart_h + 1.0),
		])
		var clipped: Array = Geometry2D.intersect_polygons(poly, clip_rect)
		for part: PackedVector2Array in clipped:
			draw_colored_polygon(part, fill_color)
	# Thin dark outline around the heart.
	draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.08, 0.05, 0.05, 0.9), 1.0)


func _scaled_poly(ox: float, oy: float, scale_f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(_BASE_POLY.size())
	for i in range(_BASE_POLY.size()):
		out[i] = Vector2(ox + _BASE_POLY[i].x * scale_f, oy + _BASE_POLY[i].y * scale_f)
	return out


# --- Break animation ------------------------------------------------

func _spawn_break(heart_idx: int) -> void:
	var scale_f: float = _heart_px / 7.0
	var stride: float = _heart_px + _heart_px * SPACING_FRAC
	var cx: float = float(heart_idx) * stride + _heart_px * 0.5
	var cy: float = 3.0 * scale_f
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 6
	particles.lifetime = 0.35
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 30.0
	particles.gravity = Vector2(0, 60)
	particles.scale_amount_min = 0.4 * scale_f
	particles.scale_amount_max = 0.8 * scale_f
	particles.color = Color(0.85, 0.15, 0.15)
	particles.position = Vector2(cx, cy)
	add_child(particles)
	# Auto-free after particles finish.
	get_tree().create_timer(0.7).timeout.connect(particles.queue_free)
