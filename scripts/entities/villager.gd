## Villager
##
## NPC built from a deterministic CharacterBuilder paper-doll.
## Wanders within `wander_radius` tiles of `home_cell`, picking a fresh
## random walkable cell every few seconds and pathing there via
## [Pathfinder]. On `interact` opens the local player's dialogue box
## with one of [VillagerDialogue]'s one-liners (also seed-deterministic).
##
## When attacked, cowardly villagers FLEE; brave ones DEFEND by fighting
## back. Returns to WANDER when the threat is gone.
##
## Coordinate system mirrors [PlayerController]: positions are native
## pixels (16-px tiles), the cell of a position is
## `Vector2i(floor(p.x / 16), floor(p.y / 16))`.
##
## State machine:
##   IDLE   — stand still for IDLE_DURATION_SEC, then pick a wander goal
##   WANDER — walk along the planned path until reached or stuck
##   DEFEND — face attacker, fight back on cooldown (brave villagers)
##   FLEE   — run away from attacker (cowardly villagers)
extends Node2D
class_name Villager

enum State { IDLE, WANDER, DEFEND, FLEE }

const IDLE_DURATION_SEC: float = 2.5
const WANDER_DURATION_SEC: float = 4.0
const MOVE_SPEED: float = 32.0  ## native px/sec
const PATH_REPATH_SEC: float = 0.75
const STUCK_EPSILON: float = 0.5
const STUCK_TIMEOUT_SEC: float = 0.8
const _BOB_HZ: float = 4.0
const _BOB_AMP_PX: float = 1.0
const _DEFEND_ATTACK_DAMAGE: int = 1
const _DEFEND_COOLDOWN_SEC: float = 1.0
const _THREAT_FORGET_TILES: float = 8.0
const _FLEE_SPEED_MULT: float = 1.5

@export var npc_seed: int = 0
@export var home_cell: Vector2i = Vector2i.ZERO
@export var wander_radius: int = 6
## Optional branching dialogue tree. If null, falls back to one-liner.
@export var dialogue_tree: DialogueTree = null
## Optional shop ID. If set, interaction opens the shop screen instead of dialogue.
@export var shop_id: StringName = &""
## If true, this villager flees when attacked instead of fighting back.
@export var is_cowardly: bool = false
@export var max_health: int = 5
@export var health: int = 5

var in_conversation: bool = false  ## Set by WorldRoot during dialogue.
var hitbox_radius: float = 5.0  ## Gungeon-style body-core radius (native px).
var state: State = State.IDLE
var _world: WorldRoot = null
var _sprite_root: Node2D = null
var _state_timer: float = 0.0
var _path: Array[Vector2i] = []
var _path_target_cell: Vector2i = Vector2i.ZERO
var _path_repath_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _bob_t: float = 0.0
var _threat_target: Node2D = null
var _attack_cooldown: float = 0.0
var _heart_display: HeartDisplay = null
var _action_vfx: ActionVFX = null
## LOD / performance.
var _lod_sleeping: bool = false
var _lod_index: int = 0


# ---------- Pure helpers (testable without a scene) ----------

## Pick a walkable cell within `radius` tiles of `home`. Returns `home`
## if no candidate exists. `walkable_cb` is `Callable(Vector2i) -> bool`.
static func pick_wander_target(rng: RandomNumberGenerator, home: Vector2i,
		radius: int, walkable_cb: Callable) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			if abs(dx) + abs(dy) > radius:
				continue
			var c := home + Vector2i(dx, dy)
			if walkable_cb.call(c):
				candidates.append(c)
	if candidates.is_empty():
		return home
	return candidates[rng.randi() % candidates.size()]


## Step a position one frame toward `dest`, bounded by `speed * delta`.
static func step_toward(curr: Vector2, dest: Vector2, speed: float,
		delta: float) -> Vector2:
	var to: Vector2 = dest - curr
	var d: float = to.length()
	if d <= 0.001:
		return dest
	var step: float = speed * delta
	if step >= d:
		return dest
	return curr + to / d * step


## Build the CharacterBuilder option dict for a villager seed. Pure
## function so tests can verify determinism without instantiating any
## sprites.
static func roll_appearance(npc_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = ((npc_seed << 1) | 1) & 0x7fffffff
	var torso_colors: Array[StringName] = [
		&"orange", &"teal", &"purple", &"green", &"tan", &"black",
	]
	var hair_colors: Array[StringName] = [
		&"brown", &"blonde", &"white", &"ginger", &"gray",
	]
	var hair_styles: Array[int] = [
		CharacterAtlas.HairStyle.SHORT,
		CharacterAtlas.HairStyle.LONG,
		CharacterAtlas.HairStyle.ACCESSORY,
	]
	var skin_tones: Array[StringName] = [&"light", &"tan", &"dark"]
	var opts: Dictionary = {
		"skin": skin_tones[rng.randi() % skin_tones.size()],
		"torso_color": torso_colors[rng.randi() % torso_colors.size()],
		"torso_style": rng.randi() % 4,
		"torso_row": rng.randi() % 5,
		"hair_color": hair_colors[rng.randi() % hair_colors.size()],
		"hair_style": hair_styles[rng.randi() % hair_styles.size()],
		"hair_variant": rng.randi() % 4,
	}
	# 1-in-4 villagers get a beard accessory.
	if (rng.randi() % 4) == 0:
		opts["face_color"] = hair_colors[rng.randi() % hair_colors.size()]
		opts["face_variant"] = rng.randi() % 4
	return opts


# ---------- Lifecycle ----------

func _ready() -> void:
	# Find the owning WorldRoot so we can query walkability.
	var n: Node = self
	while n != null and not (n is WorldRoot):
		n = n.get_parent()
	_world = n as WorldRoot
	_sprite_root = get_node_or_null("SpriteRoot") as Node2D
	if _sprite_root == null:
		_sprite_root = Node2D.new()
		_sprite_root.name = "SpriteRoot"
		add_child(_sprite_root)
	_build_appearance()
	_last_pos = position
	# Overhead heart display — visible only when damaged.
	_heart_display = HeartDisplay.new(6.0)
	_heart_display.position = Vector2(-10, -18)
	_heart_display.visible = false
	add_child(_heart_display)
	# Attack VFX — lunges the sprite root toward the target.
	_action_vfx = ActionVFX.new()
	add_child(_action_vfx)
	_action_vfx.setup(self, null, _world, _sprite_root)


func _build_appearance() -> void:
	# Clear any leftover children (defensive — scene may already have a
	# Character child if instantiated more than once).
	for c in _sprite_root.get_children():
		c.queue_free()
	var opts: Dictionary = roll_appearance(npc_seed)
	var character: Node2D = CharacterBuilder.build(opts)
	# Lift the sprite up so its feet land on the cell centre rather than
	# its midpoint. The sheet is 16×16 with the body filling the bottom
	# ~12px; -6 puts the feet near y=0 (the Villager's origin).
	character.position = Vector2(0, -6)
	_sprite_root.add_child(character)


func _physics_process(delta: float) -> void:
	if _world == null:
		return
	# Update overhead hearts.
	if _heart_display != null:
		_heart_display.update(health, max_health)
		_heart_display.visible = health > 0 and health < max_health
	if health <= 0:
		return
	# Freeze while in a conversation.
	if in_conversation:
		return
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	_state_timer += delta
	_path_repath_timer -= delta
	match state:
		State.IDLE:
			if _state_timer > IDLE_DURATION_SEC:
				_enter_wander()
		State.WANDER:
			_tick_wander(delta)
		State.DEFEND:
			_tick_defend(delta)
		State.FLEE:
			_tick_flee(delta)
	# Bob sprite while moving.
	if _action_vfx != null and _action_vfx.is_playing():
		pass  # Skip bob during lunge.
	elif state in [State.WANDER, State.FLEE] and _sprite_root != null:
		_bob_t += delta
		_sprite_root.position.y = -sin(_bob_t * TAU * _BOB_HZ) * _BOB_AMP_PX
	elif _sprite_root != null:
		_bob_t = 0.0
		_sprite_root.position.y = 0.0


func _enter_wander() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (npc_seed ^ Time.get_ticks_msec()) & 0x7fffffff
	var goal: Vector2i = pick_wander_target(rng, home_cell, wander_radius,
		func(c: Vector2i) -> bool: return _world.is_walkable(c))
	_path = Pathfinder.find_path(_current_cell(), goal,
		func(c: Vector2i) -> bool: return _world.is_walkable(c))
	_path_target_cell = goal
	_path_repath_timer = PATH_REPATH_SEC + _lod_index * 0.125
	_state_timer = 0.0
	_stuck_timer = 0.0
	_last_pos = position
	state = State.WANDER


func _enter_idle() -> void:
	_state_timer = 0.0
	_path = []
	state = State.IDLE


func _tick_wander(delta: float) -> void:
	if _state_timer > WANDER_DURATION_SEC or _path.is_empty():
		_enter_idle()
		return
	var here: Vector2i = _current_cell()
	var nxt: Vector2i = Pathfinder.next_step(_path, here)
	if nxt == here and here == _path_target_cell:
		_enter_idle()
		return
	var dest: Vector2 = (Vector2(nxt) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
	var new_pos: Vector2 = step_toward(position, dest, MOVE_SPEED, delta)
	# Only commit the move if the destination tile remains walkable
	# (something might have changed while we were on the way).
	var new_cell: Vector2i = Vector2i(
		int(floor(new_pos.x / float(WorldConst.TILE_PX))),
		int(floor(new_pos.y / float(WorldConst.TILE_PX))))
	if _world.is_walkable(new_cell) or new_cell == here:
		# Face left/right based on travel direction.
		if abs(new_pos.x - position.x) > 0.05 and _sprite_root != null:
			_sprite_root.scale.x = -1.0 if new_pos.x < position.x else 1.0
		position = new_pos
	# Stuck detection: re-path if we haven't moved meaningfully in a while.
	if position.distance_to(_last_pos) < STUCK_EPSILON:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
		_last_pos = position
	if _stuck_timer > STUCK_TIMEOUT_SEC or _path_repath_timer <= 0.0:
		_path = Pathfinder.find_path(here, _path_target_cell,
			func(c: Vector2i) -> bool: return _world.is_walkable(c))
		_path_repath_timer = PATH_REPATH_SEC
		_stuck_timer = 0.0
		if _path.is_empty():
			_enter_idle()


func _current_cell() -> Vector2i:
	return Vector2i(
		int(floor(position.x / float(WorldConst.TILE_PX))),
		int(floor(position.y / float(WorldConst.TILE_PX))))


# ---------- Combat ----------

func take_hit(damage: int, attacker: Node = null, _element: int = 0) -> void:
	if health <= 0:
		return
	# Wake from LOD sleep so the villager can respond.
	if _lod_sleeping:
		_lod_sleeping = false
		set_physics_process(true)
	if in_conversation:
		return
	var effective: int = max(1, damage)
	health = max(0, health - effective)
	ActionParticles.flash_hit(self)
	if health <= 0:
		set_physics_process(false)
		queue_free()
		return
	# Acquire threat.
	if attacker is Node2D:
		_threat_target = attacker as Node2D
		_state_timer = 0.0
		_path = []
		if is_cowardly:
			state = State.FLEE
		else:
			state = State.DEFEND


func _is_threat_valid() -> bool:
	if _threat_target == null or not is_instance_valid(_threat_target):
		return false
	var dist_tiles: float = position.distance_to(_threat_target.position) / float(WorldConst.TILE_PX)
	return dist_tiles <= _THREAT_FORGET_TILES


func _tick_defend(delta: float) -> void:
	if not _is_threat_valid():
		_threat_target = null
		_enter_idle()
		return
	# Face the attacker.
	var to: Vector2 = _threat_target.position - position
	if abs(to.x) > 0.05 and _sprite_root != null:
		_sprite_root.scale.x = -1.0 if to.x < 0.0 else 1.0
	# Move toward if > 1 tile away.
	var dist_px: float = to.length()
	if dist_px > float(WorldConst.TILE_PX):
		var new_pos: Vector2 = step_toward(position, _threat_target.position,
				MOVE_SPEED, delta)
		var new_cell: Vector2i = Vector2i(
			int(floor(new_pos.x / float(WorldConst.TILE_PX))),
			int(floor(new_pos.y / float(WorldConst.TILE_PX))))
		if _world.is_walkable(new_cell):
			position = new_pos
	# Attack on cooldown.
	var melee_range: float = float(WorldConst.TILE_PX) * 1.5 + HitboxCalc.get_radius(_threat_target)
	if _attack_cooldown <= 0.0 and dist_px <= melee_range:
		_attack_cooldown = _DEFEND_COOLDOWN_SEC
		if _threat_target.has_method("take_hit"):
			_threat_target.call("take_hit", _DEFEND_ATTACK_DAMAGE, self)
		# Lunge + particle VFX.
		if _action_vfx != null:
			var to_norm: Vector2 = to.normalized() if to.length() > 0.01 else Vector2(1, 0)
			var target_cell := Vector2i(
					int(floor(_threat_target.position.x / float(WorldConst.TILE_PX))),
					int(floor(_threat_target.position.y / float(WorldConst.TILE_PX))))
			_action_vfx.play_creature_attack(target_cell, to_norm, &"swing")


func _tick_flee(delta: float) -> void:
	if not _is_threat_valid():
		_threat_target = null
		_enter_idle()
		return
	# Run away from the attacker.
	var away: Vector2 = position - _threat_target.position
	if away.length() < 0.01:
		away = Vector2(1, 0)
	var flee_dir: Vector2 = away.normalized()
	var flee_speed: float = MOVE_SPEED * _FLEE_SPEED_MULT
	var new_pos: Vector2 = position + flee_dir * flee_speed * delta
	var new_cell: Vector2i = Vector2i(
		int(floor(new_pos.x / float(WorldConst.TILE_PX))),
		int(floor(new_pos.y / float(WorldConst.TILE_PX))))
	if _world.is_walkable(new_cell):
		position = new_pos
		if abs(flee_dir.x) > 0.05 and _sprite_root != null:
			_sprite_root.scale.x = -1.0 if flee_dir.x < 0.0 else 1.0
	else:
		# Blocked — try perpendicular directions.
		var perp: Vector2 = Vector2(flee_dir.y, -flee_dir.x)
		var alt_pos: Vector2 = position + perp * flee_speed * delta
		var alt_cell: Vector2i = Vector2i(
			int(floor(alt_pos.x / float(WorldConst.TILE_PX))),
			int(floor(alt_pos.y / float(WorldConst.TILE_PX))))
		if _world.is_walkable(alt_cell):
			position = alt_pos


# ---------- Interaction ----------

## Called by [PlayerController._try_interact] when the player presses
## the interact key while standing in range. Opens this player's
## dialogue box (per-viewport, so the other player isn't affected).
func interact(player: PlayerController) -> bool:
	if _world == null or player == null:
		return false
	if shop_id != &"" and ShopRegistry.has_shop(String(shop_id)):
		_world.open_shop(player, String(shop_id), self)
		return true
	if dialogue_tree != null:
		_world.show_dialogue_tree(player, dialogue_tree, self)
		return true
	# Fallback: one-liner dialogue.
	var speaker: String = VillagerDialogue.pick_name(npc_seed)
	var line: String = VillagerDialogue.pick_line(npc_seed)
	_world.show_dialogue(player.player_id, speaker, line, self)
	return true
