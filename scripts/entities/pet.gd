## Pet
##
## Companion creature that follows its owner ([param owner_player])
## around. One Pet is spawned per player on every view change (overworld
## ↔ cave ↔ house). Pets die-with-the-view (added to `&"scattered_npcs"`
## group) and a fresh one is reborn on the new view, snapped to the
## owner's spawn cell.
##
## Behaviour: see [PetState] for the pure decision logic.
##
##   IDLE   — close enough to owner, light bob animation, no movement.
##   FOLLOW — too far; walk straight toward owner via [WorldRoot.is_walkable].
##   ATTACK — a hostile NPC is in range; close in and swing on cooldown.
##            Only NPCs with `hostile == true` count (villagers stay safe).
##   HAPPY  — owner pressed `interact` while adjacent → small hop + heart
##            particle for [const PetState.HAPPY_DURATION_SEC].
##   STUCK  — owner is far away (>20 tiles); teleport to them.
extends Node2D
class_name Pet

const PET_SPECIES_CAT: StringName = &"cat"
const PET_SPECIES_DOG: StringName = &"dog"
const _CAT_TEX: Texture2D = preload("res://assets/characters/pets/cat.png")
const _DOG_TEX: Texture2D = preload("res://assets/characters/pets/dog.png")

const _MOVE_SPEED_PX_PER_S: float = 70.0  ## native pixels (pre-zoom)
const _ATTACK_COOLDOWN_SEC: float = 0.8
const _ATTACK_DAMAGE: int = 1
const _ARRIVE_DIST_PX: float = 6.0

## Dog's signature ranged attack: a soundwave that travels [BARK_RANGE_TILES]
## tiles outward from the dog and damages every hostile NPC it touches for
## [BARK_DAMAGE] HP. Longer cooldown than melee so it stays a "powerful"
## move rather than a spam button.
const BARK_RANGE_TILES: float = 5.0
const BARK_DAMAGE: int = 5
const BARK_COOLDOWN_SEC: float = 2.0
const _BARK_VISUAL_DURATION_SEC: float = 0.35
const _BOB_HZ: float = 4.0
const _BOB_AMPLITUDE_PX: float = 1.0
const _HOP_HEIGHT_PX: float = 4.0

@export var species: StringName = PET_SPECIES_CAT
@export var owner_player: PlayerController = null
@export var max_health: int = 3
@export var health: int = 3

var hitbox_radius: float = 3.0  ## Gungeon-style body-core radius (native px).
var state: int = PetState.State.IDLE  ## see [PetState.State]
var _world: WorldRoot = null
var _sprite: Sprite2D = null
var _heart: Sprite2D = null
var _attack_cooldown: float = 0.0
var _happy_remaining: float = 0.0
var _move_time: float = 0.0
var _facing_left: bool = false
var _last_owner_x: float = NAN
var _attack_target: NPC = null


func _ready() -> void:
	_world = WorldRoot.find_from(self)
	_sprite = Sprite2D.new()
	_sprite.texture = _DOG_TEX if species == PET_SPECIES_DOG else _CAT_TEX
	_sprite.centered = true
	add_child(_sprite)
	hitbox_radius = HitboxCalc.radius_from_sprite(_sprite)
	# Heart popup (drawn above the sprite when HAPPY).
	_heart = Sprite2D.new()
	_heart.texture = _make_heart_texture()
	_heart.centered = true
	_heart.position = Vector2(0, -16)
	_heart.visible = false
	add_child(_heart)
	add_to_group(&"scattered_npcs")
	add_to_group(&"pets")



# ─── Pure helpers ──────────────────────────────────────────────────────

## Return the nearest hostile [NPC] within [param max_tiles] of [param from]
## by scanning all [&"scattered_npcs"] in [param world]. Returns
## [code]{npc, dist_tiles}[/code] with [code]npc == null[/code] when none.
static func find_nearest_hostile(world: WorldRoot, from: Vector2,
		max_tiles: float) -> Dictionary:
	var best: NPC = null
	var best_d2: float = INF
	if world == null:
		return {"npc": null, "dist_tiles": INF}
	var max_px: float = max_tiles * float(WorldConst.TILE_PX)
	var max_d2: float = max_px * max_px
	for n in world.entities.get_children():
		if n is NPC and (n as NPC).hostile and (n as NPC).health > 0:
			var d2: float = from.distance_squared_to((n as NPC).position)
			if d2 < best_d2 and d2 <= max_d2:
				best_d2 = d2
				best = n
	if best == null:
		return {"npc": null, "dist_tiles": INF}
	return {"npc": best, "dist_tiles": sqrt(best_d2) / float(WorldConst.TILE_PX)}


# ─── Frame loop ────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	_move_time += delta
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_happy_remaining = max(0.0, _happy_remaining - delta)

	var owner_pos: Vector2 = owner_player.position
	var dist_owner_px: float = position.distance_to(owner_pos)
	var dist_owner_tiles: float = dist_owner_px / float(WorldConst.TILE_PX)

	var enemy: Dictionary = find_nearest_hostile(_world, position,
			BARK_RANGE_TILES if species == PET_SPECIES_DOG \
					else PetState.ATTACK_DETECT_TILES)
	var dist_enemy_tiles: float = enemy["dist_tiles"]
	# PetState.decide_state thresholds attack at ATTACK_DETECT_TILES (4.0).
	# The dog's bark reaches further (5.0), so lie to the state machine
	# when a hostile is in bark range — keeps the transition logic in one
	# place without leaking species-specific knowledge into PetState.
	if species == PET_SPECIES_DOG and dist_enemy_tiles <= BARK_RANGE_TILES:
		dist_enemy_tiles = min(dist_enemy_tiles, PetState.ATTACK_DETECT_TILES)

	var prev: int = state
	state = PetState.decide_state(state, dist_owner_tiles, dist_enemy_tiles,
			_happy_remaining)

	# Drop attack target if we left ATTACK.
	if state != PetState.State.ATTACK:
		_attack_target = null
	else:
		_attack_target = enemy["npc"] as NPC

	match state:
		PetState.State.STUCK:
			_teleport_to_owner()
			state = PetState.State.IDLE  # resume normal logic next frame
		PetState.State.FOLLOW:
			_step_toward(owner_pos, delta)
		PetState.State.ATTACK:
			_do_attack(delta)
		PetState.State.HAPPY:
			# Small hop driven by _happy_remaining.
			var t: float = 1.0 - (_happy_remaining / PetState.HAPPY_DURATION_SEC)
			_sprite.position.y = -sin(t * PI) * _HOP_HEIGHT_PX
			_heart.visible = true
		PetState.State.IDLE, _:
			_sprite.position.y = sin(_move_time * _BOB_HZ * TAU) * _BOB_AMPLITUDE_PX

	if state != PetState.State.HAPPY:
		_heart.visible = false

	# Face the owner (or movement direction) by horizontal flip.
	if state == PetState.State.FOLLOW or state == PetState.State.ATTACK:
		var target_x: float = owner_pos.x if state == PetState.State.FOLLOW \
				else (_attack_target.position.x if _attack_target != null else owner_pos.x)
		_facing_left = target_x < position.x
	_sprite.flip_h = _facing_left

	if prev != state and state == PetState.State.HAPPY:
		_heart.visible = true


# ─── Movement ──────────────────────────────────────────────────────────

func _step_toward(target_pos: Vector2, delta: float) -> void:
	var to_target: Vector2 = target_pos - position
	if to_target.length() <= _ARRIVE_DIST_PX:
		return
	var step: Vector2 = to_target.normalized() * _MOVE_SPEED_PX_PER_S * delta
	var new_pos: Vector2 = position + step
	# Walkability check on the destination cell. If blocked, don't step
	# (the simple sliding fallback used by NPCs is enough for v1).
	if _world != null:
		var cell: Vector2i = Vector2i(
				int(floor(new_pos.x / float(WorldConst.TILE_PX))),
				int(floor(new_pos.y / float(WorldConst.TILE_PX))))
		if not _world.is_walkable(cell):
			return
	position = new_pos


func _teleport_to_owner() -> void:
	if owner_player == null:
		return
	# Drop one tile to the side so we don't end up exactly on the owner.
	var off: Vector2 = Vector2(float(WorldConst.TILE_PX), 0.0)
	if _world != null:
		var cell: Vector2i = Vector2i(
				int(floor((owner_player.position + off).x / float(WorldConst.TILE_PX))),
				int(floor((owner_player.position + off).y / float(WorldConst.TILE_PX))))
		if not _world.is_walkable(cell):
			off = Vector2.ZERO
	position = owner_player.position + off


# ─── Combat ────────────────────────────────────────────────────────────

func _do_attack(delta: float) -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		return
	if species == PET_SPECIES_DOG:
		_do_bark()
		return
	var to_t: Vector2 = _attack_target.position - position
	var target_hb: float = HitboxCalc.get_radius(_attack_target)
	if to_t.length() > float(WorldConst.TILE_PX) + target_hb:
		# Close in.
		_step_toward(_attack_target.position, delta)
		return
	# In melee. Swing on cooldown.
	if _attack_cooldown <= 0.0:
		_attack_cooldown = _ATTACK_COOLDOWN_SEC
		if _attack_target.has_method("take_hit"):
			_attack_target.call("take_hit", _ATTACK_DAMAGE, self)


## Fire a powerful bark soundwave: damages every hostile NPC within
## [BARK_RANGE_TILES] of the dog, then spawns an expanding ring visual.
## Held off by the longer [BARK_COOLDOWN_SEC]; the dog stands its ground
## and barks instead of running into melee.
func _do_bark() -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = BARK_COOLDOWN_SEC
	var range_px: float = BARK_RANGE_TILES * float(WorldConst.TILE_PX)
	var range_d2: float = range_px * range_px
	if _world != null:
		for n in _world.entities.get_children():
			if n is NPC and (n as NPC).hostile and (n as NPC).health > 0:
				var eff_range: float = range_px + (n as NPC).hitbox_radius
				if position.distance_squared_to((n as NPC).position) <= eff_range * eff_range:
					if (n as NPC).has_method("take_hit"):
						(n as NPC).call("take_hit", BARK_DAMAGE, self)
	_spawn_bark_visual(range_px)


func _spawn_bark_visual(range_px: float) -> void:
	var ring := _BarkRing.new()
	ring.start_radius = float(WorldConst.TILE_PX) * 0.5
	ring.end_radius = range_px
	ring.lifetime = _BARK_VISUAL_DURATION_SEC
	ring.position = position
	get_parent().add_child(ring)


# ─── Player interaction ────────────────────────────────────────────────

## Called by [PlayerController._try_interact] when adjacent. Plays the
## happy gesture for [const PetState.HAPPY_DURATION_SEC]. The owner check
## prevents Player 2 from petting Player 1's pet (and vice versa).
func interact(by: Node) -> void:
	if by != owner_player:
		return
	_happy_remaining = PetState.HAPPY_DURATION_SEC
	state = PetState.State.HAPPY


# Damage (forwarded from any future enemy that targets the pet). For v1
# the pet can't actually die — `take_hit` just refreshes hp.
func take_hit(damage: int, _attacker: Node = null) -> void:
	health = max(1, health - damage)
	ActionParticles.flash_hit(self)


# ─── Heart particle texture ────────────────────────────────────────────

# Tiny 7×6 pixel heart. Built once at runtime so we don't ship another asset.
static func _make_heart_texture() -> Texture2D:
	var img := Image.create(7, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pink := Color8(232, 70, 100, 255)
	var dark := Color8(168, 32, 60, 255)
	var pixels: Array = [
		Vector2i(1,0), Vector2i(2,0), Vector2i(4,0), Vector2i(5,0),
		Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(3,1),
		Vector2i(4,1), Vector2i(5,1), Vector2i(6,1),
		Vector2i(0,2), Vector2i(1,2), Vector2i(2,2), Vector2i(3,2),
		Vector2i(4,2), Vector2i(5,2), Vector2i(6,2),
		Vector2i(1,3), Vector2i(2,3), Vector2i(3,3), Vector2i(4,3), Vector2i(5,3),
		Vector2i(2,4), Vector2i(3,4), Vector2i(4,4),
		Vector2i(3,5),
	]
	for p in pixels:
		img.set_pixel(p.x, p.y, pink)
	# Outline pixels (darker)
	for p in [Vector2i(0,1), Vector2i(6,1), Vector2i(0,2), Vector2i(6,2),
			Vector2i(3,5)]:
		img.set_pixel(p.x, p.y, dark)
	return ImageTexture.create_from_image(img)



# ─── Bark soundwave ────────────────────────────────────────────────────

## Expanding ring drawn for [_BARK_VISUAL_DURATION_SEC] then freed.
## Pure visual — damage is applied by [Pet._do_bark] at the moment of
## the bark, so late-arriving NPCs aren't hit by the trailing edge.
class _BarkRing extends Node2D:
	var start_radius: float = 4.0
	var end_radius: float = 80.0
	var lifetime: float = 0.35
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= lifetime:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var f: float = clamp(_t / lifetime, 0.0, 1.0)
		var r: float = lerp(start_radius, end_radius, f)
		var alpha: float = (1.0 - f) * 0.85
		# Two concentric arcs for a chunky pixel-art feel.
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48,
				Color(1.0, 1.0, 1.0, alpha), 2.0, true)
		draw_arc(Vector2.ZERO, max(0.0, r - 3.0), 0.0, TAU, 48,
				Color(0.6, 0.85, 1.0, alpha * 0.6), 1.0, true)
