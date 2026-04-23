## Mount
##
## Rideable creature. When a nearby player interacts, the player boards
## and the mount tracks the player's position (same pattern as [Boat]).
## While riding, the player's movement speed is multiplied by the mount's
## [member speed_multiplier]. Interact again to dismount.
##
## Mount sprites come from [CreatureSpriteRegistry]; the `mount_kind` key
## selects which creature entry to use. Large images are auto-scaled via
## the entry's `target_width_tiles` field.
##
## Mounts stay in their [WorldRoot] instance (like boats, not like pets).
## Dismount is forced when the player transitions to another view.
extends Node2D
class_name Mount

const _BOB_HZ: float = 4.0
const _BOB_AMP_PX: float = 1.0
const _IDLE_BOB_HZ: float = 2.0
const _IDLE_BOB_AMP_PX: float = 0.5
const _HOP_DURATION_SEC: float = 0.3
const _HOP_COOLDOWN_SEC: float = 1.0
const _HOP_HEIGHT_PX: float = 6.0
const _HOP_DISTANCE_TILES: int = 2
## Rider sprite is shifted by this offset (native pixels) so the player
## appears to sit on top of the mount.  Loaded from registry.
var _rider_offset: Vector2 = Vector2(0, -12)

@export var mount_kind: StringName = &"grasshopper"

var rider: PlayerController = null
var speed_multiplier: float = 1.8
var facing_right: bool = true
var can_jump: bool = true

var _sprite: Sprite2D = null
var _bob_t: float = 0.0
var _hop_t: float = -1.0  ## < 0 means not hopping
var _hop_cooldown: float = 0.0
var _hop_start_pos: Vector2 = Vector2.ZERO
var _hop_end_pos: Vector2 = Vector2.ZERO
var _world: WorldRoot = null


func _ready() -> void:
	_world = WorldRoot.find_from(self)
	_load_from_registry()
	_sprite = CreatureSpriteRegistry.build_sprite(mount_kind)
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.centered = true
	add_child(_sprite)
	# Mount sprite renders in front of the rider at the same y-position.
	_sprite.z_index = 1
	add_to_group(&"scattered_npcs")
	add_to_group(&"mounts")


func _load_from_registry() -> void:
	speed_multiplier = CreatureSpriteRegistry.get_speed_multiplier(mount_kind)
	facing_right = CreatureSpriteRegistry.is_facing_right(mount_kind)
	can_jump = CreatureSpriteRegistry.can_jump(mount_kind)
	_rider_offset = CreatureSpriteRegistry.get_rider_offset(mount_kind)


# ─── Interaction ───────────────────────────────────────────────────────

func interact(player: PlayerController) -> bool:
	if rider == null:
		rider = player
		player.start_riding(self)
		# Shift rider sprite up so the player sits on the mount.
		player._sprite_root.position = _rider_offset
		return true
	if rider == player:
		player._sprite_root.position = Vector2.ZERO
		rider = null
		player.stop_riding()
		return true
	return false


# ─── Hop ───────────────────────────────────────────────────────────────

## Start a hop in the given facing direction. Returns true if the hop
## begins, false if on cooldown or the landing is blocked.
func try_hop(facing_dir: Vector2i) -> bool:
	if not can_jump:
		return false
	if _hop_t >= 0.0 or _hop_cooldown > 0.0:
		return false
	if _world == null:
		return false
	# Compute landing cell: 2 tiles in facing direction.
	var current_cell: Vector2i = Vector2i(
		int(floor(position.x / float(WorldConst.TILE_PX))),
		int(floor(position.y / float(WorldConst.TILE_PX))))
	var landing_cell: Vector2i = current_cell + facing_dir * _HOP_DISTANCE_TILES
	# The landing cell must be walkable (can't hop into solid walls).
	if not _world.is_walkable(landing_cell):
		return false
	_hop_start_pos = position
	_hop_end_pos = (Vector2(landing_cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
	_hop_t = 0.0
	return true


func is_hopping() -> bool:
	return _hop_t >= 0.0


# ─── Frame loop ────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_hop_cooldown = max(0.0, _hop_cooldown - delta)
	_bob_t += delta

	# Mid-hop animation.
	if _hop_t >= 0.0:
		_hop_t += delta
		var t: float = clamp(_hop_t / _HOP_DURATION_SEC, 0.0, 1.0)
		# Horizontal lerp.
		var flat_pos: Vector2 = _hop_start_pos.lerp(_hop_end_pos, t)
		# Parabolic arc for vertical offset.
		var arc: float = sin(t * PI) * _HOP_HEIGHT_PX
		if rider != null:
			rider.position = flat_pos
			rider._sprite_root.position = _rider_offset + Vector2(0, -arc)
		position = flat_pos
		_sprite.position.y = -arc
		if t >= 1.0:
			# Land.
			_hop_t = -1.0
			_hop_cooldown = _HOP_COOLDOWN_SEC
			_sprite.position.y = 0.0
			if rider != null:
				rider._sprite_root.position = _rider_offset
		return

	if rider != null:
		# Track the rider.
		position = rider.position
		# Bob while rider is moving.
		var bob: float = sin(_bob_t * TAU * _BOB_HZ) * _BOB_AMP_PX
		_sprite.position.y = -bob
		# Flip based on rider's facing direction.
		if facing_right:
			_sprite.flip_h = (rider._facing_x < 0)
		else:
			_sprite.flip_h = (rider._facing_x > 0)
	else:
		# Idle: gentle bob in place.
		var bob: float = sin(_bob_t * TAU * _IDLE_BOB_HZ) * _IDLE_BOB_AMP_PX
		_sprite.position.y = -bob
