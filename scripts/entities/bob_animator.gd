## BobAnimator
##
## Reusable vertical bob animation helper used by all in-world entities
## (Player, Monster, Villager, Pet).
##
## Usage:
##   var _bob := BobAnimator.new()          # default 4 Hz, 1 px
##   var _bob := BobAnimator.new(6.0, 1.0)  # player uses 6 Hz
##
##   # In _process() / _physics_process():
##   if not _action_vfx.is_playing():
##       _sprite.position.y = _bob.tick(delta)
##   else:
##       _bob.reset()
class_name BobAnimator
extends RefCounted

## Oscillation frequency in Hz.
var hz: float
## Amplitude in native (pre-zoom) pixels.
var amplitude: float

var _t: float = 0.0


func _init(p_hz: float = 4.0, p_amplitude: float = 1.0) -> void:
	hz = p_hz
	amplitude = p_amplitude


## Advance time by [param delta] and return the new Y offset in pixels.
## A negative value means upward displacement (consistent with Godot's Y-down axis).
func tick(delta: float) -> float:
	_t += delta
	return -sin(_t * TAU * hz) * amplitude


## Reset the animation timer (call when the entity is interrupted, e.g. during
## an attack lunge, to avoid a visible position jump when the lunge ends).
func reset() -> void:
	_t = 0.0
