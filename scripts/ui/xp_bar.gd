## XpBar
## Compact XP progress bar drawn below the hearts in PlayerHUD.
## Shows: [Lv.N] [filled bar] [xp/threshold] — or "MAX" at cap.
extends Control
class_name XpBar

const BAR_H: float = 5.0
const BAR_W: float = 120.0
const LABEL_W: float = 38.0
const GAP: float = 4.0

const COLOR_FILL: Color = Color(0.35, 0.75, 0.35)
const COLOR_EMPTY: Color = Color(0.15, 0.15, 0.15)
const COLOR_TEXT: Color = Color(0.9, 0.9, 0.9)
const COLOR_PULSE: Color = Color(1.0, 0.9, 0.2)

var _xp: int = 0
var _level: int = 1
var _xp_to_next: int = 100
var _pending: bool = false
var _pulse_t: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(LABEL_W + GAP + BAR_W + GAP + 50, 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update(xp: int, level: int, xp_to_next: int, pending_stat: bool = false) -> void:
	_xp = xp
	_level = level
	_xp_to_next = xp_to_next
	_pending = pending_stat
	queue_redraw()

func _process(delta: float) -> void:
	if _pending:
		_pulse_t += delta * TAU / 0.6
		queue_redraw()

func _draw() -> void:
	var lv_text: String = "Lv.%d" % _level
	var lv_color: Color = Color(
		COLOR_PULSE.r, COLOR_PULSE.g, COLOR_PULSE.b,
		0.7 + 0.3 * sin(_pulse_t)
	) if _pending else COLOR_TEXT
	draw_string(ThemeDB.fallback_font, Vector2(0, 11), lv_text,
		HORIZONTAL_ALIGNMENT_LEFT, int(LABEL_W), 11, lv_color)

	var bar_x: float = LABEL_W + GAP
	draw_rect(Rect2(bar_x, 3, BAR_W, BAR_H), COLOR_EMPTY)

	if _level >= 20:
		draw_rect(Rect2(bar_x, 3, BAR_W, BAR_H), COLOR_FILL)
		draw_string(ThemeDB.fallback_font, Vector2(bar_x + BAR_W + GAP, 11),
			"MAX", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_TEXT)
	else:
		var ratio: float = float(_xp) / float(max(1, _xp_to_next))
		draw_rect(Rect2(bar_x, 3, BAR_W * ratio, BAR_H), COLOR_FILL)
		var xp_text: String = "%d/%d" % [_xp, _xp_to_next]
		draw_string(ThemeDB.fallback_font, Vector2(bar_x + BAR_W + GAP, 11),
			xp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_TEXT)
