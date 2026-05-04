## CooldownWidget
##
## Two vertical bars side-by-side showing attack and dodge cooldown readiness.
## Bars fill bottom-to-top as cooldown recovers; full bar = ready.
## Same height as the heart display / hotbar row for visual harmony.
## Designed for high contrast / colorblind accessibility: thick borders,
## bright white fill vs dark empty, icon symbols instead of color alone.
##
## Ratios are provided via [method update_ratios]; call each frame from game._process.
extends Control
class_name CooldownWidget

const _BAR_W:    float = 16.0
const _BAR_H:    float = 34.0
const _ICON_W:   float = 16.0
const _COL_GAP:  float = 6.0
const _BORDER:   float = 2.0
const _PAD_Y:    float = 3.0

const _COL_W:    float = _ICON_W + _BAR_W + _BORDER * 2
const _WIDGET_W: float = _COL_W * 2 + _COL_GAP
const _WIDGET_H: float = 48.0

const _COLOR_FILL_READY: Color = Color(1.0, 1.0, 1.0, 0.95)      # bright white when full
const _COLOR_FILL_ATK:   Color = Color(1.0, 0.85, 0.4, 0.9)      # warm yellow fill
const _COLOR_FILL_DGE:   Color = Color(0.6, 0.9, 1.0, 0.9)       # cyan fill
const _COLOR_EMPTY:      Color = Color(0.05, 0.05, 0.05, 0.8)    # near-black empty
const _COLOR_BORDER:     Color = Color(0.9, 0.9, 0.9, 0.95)      # white border
const _COLOR_BORDER_RDY: Color = Color(1.0, 1.0, 0.7, 1.0)       # glow border when ready
const _COLOR_LABEL:      Color = Color(1.0, 1.0, 1.0, 0.95)      # white labels

var _atk_ratio: float = 0.0   ## 0 = ready, 1 = full cooldown
var _dodge_ratio: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_WIDGET_W, _WIDGET_H)


## [param atk_ratio] and [param dodge_ratio] are each 0.0 (ready) → 1.0 (cooling).
func update_ratios(atk_ratio: float, dodge_ratio: float) -> void:
	if is_equal_approx(_atk_ratio, atk_ratio) and is_equal_approx(_dodge_ratio, dodge_ratio):
		return
	_atk_ratio = atk_ratio
	_dodge_ratio = dodge_ratio
	queue_redraw()


func _draw() -> void:
	var atk_fill: float = 1.0 - _atk_ratio
	var dge_fill: float = 1.0 - _dodge_ratio
	_draw_col(0.0, "⚔", atk_fill, _COLOR_FILL_ATK, _atk_ratio <= 0.0)
	_draw_col(_COL_W + _COL_GAP, "◈", dge_fill, _COLOR_FILL_DGE, _dodge_ratio <= 0.0)


func _draw_col(x: float, icon: String, fill: float, fill_col: Color, is_ready: bool) -> void:
	var bar_x: float = x + _ICON_W
	var bar_y: float = _PAD_Y

	# Outer border (thicker + brighter when ready).
	var border_col: Color = _COLOR_BORDER_RDY if is_ready else _COLOR_BORDER
	var bw: float = _BORDER + (1.0 if is_ready else 0.0)
	draw_rect(Rect2(bar_x - bw, bar_y - bw,
			_BAR_W + bw * 2, _BAR_H + bw * 2), border_col)

	# Dark empty track.
	draw_rect(Rect2(bar_x, bar_y, _BAR_W, _BAR_H), _COLOR_EMPTY)

	# Filled portion — fills bottom-to-top; bright white when ready.
	if fill > 0.0:
		var col: Color = _COLOR_FILL_READY if is_ready else fill_col
		var fill_h: float = _BAR_H * fill
		draw_rect(Rect2(bar_x, bar_y + _BAR_H - fill_h, _BAR_W, fill_h), col)

	# Icon label (sword / diamond) — centered vertically to left of bar.
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var sz: int = 13
	var icon_col: Color = _COLOR_FILL_READY if is_ready else _COLOR_LABEL
	draw_string(font, Vector2(x + 1.0, _PAD_Y + _BAR_H * 0.5 + 5.0),
			icon, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, icon_col)
