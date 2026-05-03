## CooldownWidget
##
## Draws two arc pies showing the attack and dodge cooldown readiness.
## Arc is drawn clockwise from the top; a full circle means the action
## is *ready*. The arc drains as the cooldown counts down.
##
## Ratios are provided via [method update_ratios]; call each frame from Game._process.
extends Control
class_name CooldownWidget

## Size of each arc disc in pixels.
const _DISC_SIZE: float = 18.0
## Gap between the two discs.
const _GAP: float = 6.0

const _COLOR_READY:  Color = Color(0.3, 0.85, 0.35)   # green
const _COLOR_CHARGE: Color = Color(0.9, 0.7, 0.2)     # orange
const _COLOR_COOL:   Color = Color(0.45, 0.45, 0.45)  # gray (cooling)
const _COLOR_BG:     Color = Color(0.0, 0.0, 0.0, 0.5)

# dodge arc colours
const _COLOR_DODGE_READY: Color = Color(0.35, 0.6, 1.0)  # blue

var _atk_ratio: float = 0.0   ## 0 = ready, 1 = full cooldown
var _dodge_ratio: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_DISC_SIZE * 2 + _GAP, _DISC_SIZE)


## [param atk_ratio] and [param dodge_ratio] are each 0.0 (ready) → 1.0 (cooling).
func update_ratios(atk_ratio: float, dodge_ratio: float) -> void:
	if is_equal_approx(_atk_ratio, atk_ratio) and is_equal_approx(_dodge_ratio, dodge_ratio):
		return
	_atk_ratio = atk_ratio
	_dodge_ratio = dodge_ratio
	queue_redraw()


func _draw() -> void:
	var r: float = _DISC_SIZE * 0.5
	# --- Attack disc ---
	var atk_center := Vector2(r, r)
	draw_circle(atk_center, r, _COLOR_BG)
	_draw_filled_arc(atk_center, r, 1.0 - _atk_ratio,
			_COLOR_CHARGE if _atk_ratio > 0.0 else _COLOR_READY)

	# --- Dodge disc ---
	var dodge_center := Vector2(_DISC_SIZE + _GAP + r, r)
	draw_circle(dodge_center, r, _COLOR_BG)
	_draw_filled_arc(dodge_center, r, 1.0 - _dodge_ratio,
			_COLOR_COOL if _dodge_ratio > 0.0 else _COLOR_DODGE_READY)

	# --- Letter labels ---
	_draw_label("A", atk_center)
	_draw_label("D", dodge_center)


func _draw_filled_arc(center: Vector2, r: float, fill: float, col: Color) -> void:
	if fill <= 0.0:
		return
	# Draw a filled wedge using a polygon. 32 points is smooth enough at this size.
	const SEGS: int = 32
	var angle_start: float = -PI * 0.5  # top
	var angle_end: float = angle_start + fill * TAU
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(center)
	var steps: int = maxi(1, int(fill * SEGS))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var angle: float = lerpf(angle_start, angle_end, t)
		pts.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(pts, col)


func _draw_label(txt: String, center: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var sz: int = 9
	var ts: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
	draw_string(font, center - ts * 0.5 + Vector2(0, ts.y * 0.5), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1, 1, 1, 0.9))
