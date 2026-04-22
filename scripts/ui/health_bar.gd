## HealthBar
##
## A thin Control that displays current/max health as a coloured progress
## fill plus a "12 / 20" label. Designed to be cheap to update — call
## [code]update(curr, max)[/code] when health changes.
##
## The pure computation [code]ratio(curr, max)[/code] is exposed as a static
## method so it can be unit-tested without instantiating the scene.
extends Control
class_name HealthBar

const BAR_WIDTH: float = 160.0
const BAR_HEIGHT: float = 14.0

var _curr: int = 0
var _max: int = 1

@onready var _fill: ColorRect = $Fill
@onready var _label: Label = $Label


## Pure helper: clamp ratio to [0, 1]. Returns 0 if max <= 0.
static func ratio(curr: int, max_value: int) -> float:
	if max_value <= 0:
		return 0.0
	return clampf(float(curr) / float(max_value), 0.0, 1.0)


## Pure helper: pick a fill colour based on the current ratio.
static func fill_color_for(r: float) -> Color:
	if r > 0.5:
		return Color(0.30, 0.78, 0.30)
	if r > 0.25:
		return Color(0.92, 0.78, 0.22)
	return Color(0.85, 0.25, 0.25)


func update(curr: int, max_value: int) -> void:
	_curr = curr
	_max = max_value
	if _fill != null:
		var r := ratio(_curr, _max)
		_fill.size.x = BAR_WIDTH * r
		_fill.color = fill_color_for(r)
	if _label != null:
		_label.text = "%d / %d" % [_curr, _max]

