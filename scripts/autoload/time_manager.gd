## TimeManager
##
## Autoload that tracks in-game time of day and day count.
## 10 real minutes = 1 game day (configurable via DAY_DURATION_SEC).
## Periods: dawn (5-7), day (7-19), dusk (19-21), night (21-5).
extends Node

const DAY_DURATION_SEC: float = 600.0  ## Real seconds per game day.

## Current hour (0.0–24.0).
var time_of_day: float = 8.0
## Day counter (increments at midnight rollover).
var day_count: int = 0
## Set to false to pause time (e.g. in menus).
var ticking: bool = true

signal time_changed(hour: float)
signal period_changed(period: StringName)

var _last_period: StringName = &""


func _ready() -> void:
	_last_period = get_period()


func _process(delta: float) -> void:
	if not ticking:
		return
	var hours_per_sec: float = 24.0 / DAY_DURATION_SEC
	time_of_day += delta * hours_per_sec
	if time_of_day >= 24.0:
		time_of_day -= 24.0
		day_count += 1
	time_changed.emit(time_of_day)
	var p: StringName = get_period()
	if p != _last_period:
		_last_period = p
		period_changed.emit(p)


## Returns the current period name.
func get_period() -> StringName:
	if time_of_day >= 5.0 and time_of_day < 7.0:
		return &"dawn"
	elif time_of_day >= 7.0 and time_of_day < 19.0:
		return &"day"
	elif time_of_day >= 19.0 and time_of_day < 21.0:
		return &"dusk"
	else:
		return &"night"


## Period color for ambient light.
func get_period_color() -> Color:
	match get_period():
		&"dawn":
			return Color(0.95, 0.90, 0.75)
		&"day":
			return Color.WHITE
		&"dusk":
			return Color(0.95, 0.75, 0.55)
		&"night":
			return Color(0.25, 0.25, 0.45)
	return Color.WHITE


## Smooth interpolated ambient color based on exact hour.
func get_ambient_color() -> Color:
	# Lerp between period boundary colors for smooth transitions.
	var h: float = time_of_day
	if h >= 5.0 and h < 7.0:
		var t: float = (h - 5.0) / 2.0
		return Color(0.25, 0.25, 0.45).lerp(Color(0.95, 0.90, 0.75), t)
	elif h >= 7.0 and h < 8.0:
		var t: float = h - 7.0
		return Color(0.95, 0.90, 0.75).lerp(Color.WHITE, t)
	elif h >= 8.0 and h < 18.0:
		return Color.WHITE
	elif h >= 18.0 and h < 19.0:
		var t: float = h - 18.0
		return Color.WHITE.lerp(Color(0.95, 0.75, 0.55), t)
	elif h >= 19.0 and h < 21.0:
		var t: float = (h - 19.0) / 2.0
		return Color(0.95, 0.75, 0.55).lerp(Color(0.25, 0.25, 0.45), t)
	else:
		return Color(0.25, 0.25, 0.45)


## Save/load support.
func get_save_data() -> Dictionary:
	return {"time_of_day": time_of_day, "day_count": day_count}


func load_save_data(data: Dictionary) -> void:
	time_of_day = float(data.get("time_of_day", 8.0))
	day_count = int(data.get("day_count", 0))
	_last_period = get_period()
