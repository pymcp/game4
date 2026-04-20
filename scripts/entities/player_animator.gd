## PlayerAnimator
##
## AnimatedSprite2D that renders the Kenney iso miniature character with 8
## facing directions and Idle / Run / Pickup states. SpriteFrames are built
## once per gender at runtime by scanning the asset folder, so adding new
## states is just a matter of dropping more PNGs.
##
## Direction encoding (matches Kenney's `<gender>_<dir>_<state><frame>.png`):
##   dir 0 = +x screen   (east)
##   dir 1 = +x +y       (south-east, default-facing pose)
##   dir 2 = +y          (south)
##   dir 3 = -x +y       (south-west)
##   dir 4 = -x          (west)
##   dir 5 = -x -y       (north-west)
##   dir 6 = -y          (north)
##   dir 7 = +x -y       (north-east)
##
## We pick `dir = round((angle + offset) / 45)` where `offset` aligns the
## player's screen velocity to the asset orientation.
class_name PlayerAnimator
extends AnimatedSprite2D

enum State { IDLE, RUN, PICKUP }

const _GENDERS: Array[String] = ["Male", "Female"]
const _STATES: Dictionary = {
	State.IDLE: "Idle",
	State.RUN: "Run",
	State.PICKUP: "Pickup",
}
const _STATE_FPS: Dictionary = {
	State.IDLE: 4.0,
	State.RUN: 12.0,
	State.PICKUP: 14.0,
}
const _STATE_LOOPS: Dictionary = {
	State.IDLE: true,
	State.RUN: true,
	State.PICKUP: false,
}

## Cache: gender -> SpriteFrames (shared across all players of that gender).
static var _frames_cache: Dictionary = {}

@export var gender: String = "Male"
## Angle offset (radians) applied to the input vector before quantising into
## one of 8 directions. Tweak per asset if the default isn't natural.
@export var direction_offset_rad: float = 0.0

var _state: State = State.IDLE
var _direction: int = 1  # default-facing pose
var _pickup_pending_revert: State = State.IDLE


func _ready() -> void:
	sprite_frames = _get_or_build_frames(gender)
	_apply_anim()
	animation_finished.connect(_on_animation_finished)


## Update facing direction + state from a world-space velocity vector.
## Velocity near zero leaves direction unchanged and switches to IDLE.
func set_facing_velocity(world_vel: Vector2) -> void:
	if world_vel.length_squared() < 0.0001:
		_set_state(State.IDLE)
		return
	_direction = direction_from_velocity(world_vel, direction_offset_rad)
	_set_state(State.RUN)


## Play the Pickup animation once, then revert to the prior state.
func play_pickup_oneshot() -> void:
	_pickup_pending_revert = _state if _state != State.PICKUP else State.IDLE
	_set_state(State.PICKUP, true)


func get_state() -> State:
	return _state


func get_direction() -> int:
	return _direction


## Pure helper: world-velocity (screen-space) -> direction index 0..7.
static func direction_from_velocity(world_vel: Vector2, offset_rad: float = 0.0) -> int:
	var ang: float = atan2(world_vel.y, world_vel.x) + offset_rad
	var d: int = int(round(ang / (PI * 0.25))) & 7
	return d


func _set_state(new_state: State, force_restart: bool = false) -> void:
	if not force_restart and new_state == _state and _is_playing_correct_anim():
		return
	_state = new_state
	_apply_anim()


func _apply_anim() -> void:
	var name: String = _anim_name(_state, _direction)
	if sprite_frames != null and sprite_frames.has_animation(name):
		play(name)


func _is_playing_correct_anim() -> bool:
	return animation == _anim_name(_state, _direction)


func _on_animation_finished() -> void:
	if _state == State.PICKUP:
		_set_state(_pickup_pending_revert, true)


static func _anim_name(s: State, d: int) -> String:
	return "%s_%d" % [_STATES[s], d]


## Build (or fetch from cache) a SpriteFrames covering all 8 directions and
## 3 states for the given gender.
static func _get_or_build_frames(gender_name: String) -> SpriteFrames:
	if _frames_cache.has(gender_name):
		return _frames_cache[gender_name]
	var sf := SpriteFrames.new()
	# Strip default 'default' animation so the cache is clean.
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	var base: String = "res://assets/characters/iso_miniature/%s/%s_" % [gender_name, gender_name]
	for state_id in _STATES.keys():
		var state_name: String = _STATES[state_id]
		var fps: float = _STATE_FPS[state_id]
		var loop: bool = _STATE_LOOPS[state_id]
		for d in 8:
			var anim_name: String = "%s_%d" % [state_name, d]
			sf.add_animation(StringName(anim_name))
			sf.set_animation_speed(StringName(anim_name), fps)
			sf.set_animation_loop(StringName(anim_name), loop)
			var frame: int = 0
			while true:
				var path: String = "%s%d_%s%d.png" % [base, d, state_name, frame]
				if not ResourceLoader.exists(path):
					break
				var tex: Texture2D = load(path) as Texture2D
				if tex == null:
					break
				sf.add_frame(StringName(anim_name), tex)
				frame += 1
			# Fallback: if the requested direction has no frames (e.g. Male
			# only ships dir 0 Idle), borrow direction 0's frames so the
			# sprite never goes blank.
			if sf.get_frame_count(StringName(anim_name)) == 0:
				var fallback_path: String = "%s0_%s0.png" % [base, state_name]
				if ResourceLoader.exists(fallback_path):
					var tex2: Texture2D = load(fallback_path) as Texture2D
					if tex2 != null:
						sf.add_frame(StringName(anim_name), tex2)
	_frames_cache[gender_name] = sf
	return sf
