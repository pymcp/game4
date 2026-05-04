## CooldownWidget
##
## Two labeled horizontal bars showing attack and dodge cooldown readiness.
## Bar drains left-to-right as the cooldown counts down; full bar = ready.
##
## Ratios are provided via [method update_ratios]; call each frame from game._process.
extends Control
class_name CooldownWidget

const _BAR_W:    float = 60.0
const _BAR_H:    float = 7.0
const _LABEL_W:  float = 24.0
const _GAP:      float = 6.0
const _ROW_H:    float = 18.0

const _COLOR_ATK_READY:  Color = Color(0.9,  0.55, 0.2)   # orange
const _COLOR_ATK_COOL:   Color = Color(0.45, 0.3,  0.1)   # dim orange
const _COLOR_DGE_READY:  Color = Color(0.3,  0.65, 1.0)   # blue
const _COLOR_DGE_COOL:   Color = Color(0.15, 0.3,  0.5)   # dim blue
const _COLOR_TRACK:      Color = Color(0.0,  0.0,  0.0, 0.45)
const _COLOR_LABEL:      Color = Color(0.75, 0.75, 0.75)

var _atk_ratio: float = 0.0   ## 0 = ready, 1 = full cooldown
var _dodge_ratio: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_LABEL_W + _BAR_W, _ROW_H * 2 + _GAP)


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
	_draw_row(0.0,           "ATK", atk_fill,
			_COLOR_ATK_READY if _atk_ratio <= 0.0 else _COLOR_ATK_COOL)
	_draw_row(_ROW_H + _GAP, "DGE", dge_fill,
			_COLOR_DGE_READY if _dodge_ratio <= 0.0 else _COLOR_DGE_COOL)


func _draw_row(y: float, label: String, fill: float, col: Color) -> void:
	var bar_y: float = y + (_ROW_H - _BAR_H) * 0.5
	# Track
	draw_rect(Rect2(_LABEL_W, bar_y, _BAR_W, _BAR_H), _COLOR_TRACK)
	# Fill
	if fill > 0.0:
		draw_rect(Rect2(_LABEL_W, bar_y, _BAR_W * fill, _BAR_H), col)
	# Label
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var sz: int = 9
	var ts: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
	draw_string(font, Vector2(_LABEL_W - ts.x - 3.0, y + _ROW_H * 0.5 + ts.y * 0.35),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, _COLOR_LABEL)
