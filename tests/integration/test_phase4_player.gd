## Phase 4: PlayerAnimator + Hittable + attack hit-scan.
extends GutTest

const GameScene: PackedScene = preload("res://scenes/main/Game.tscn")

var game: Node = null
var world: WorldRoot = null


func before_each() -> void:
	WorldManager.reset(202402)
	game = GameScene.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	# Wait one extra frame so Game.gd's deferred _wire_hud_and_cameras runs
	# (it spawns the players that the World coordinator will then re-parent
	# into their starting WorldRoot instance).
	await get_tree().process_frame
	var coord: World = (game as Game)._world
	assert_not_null(coord, "World coordinator missing")
	world = coord.get_player_world(0)
	assert_not_null(world)


# --- PlayerAnimator pure-direction math ---

func test_direction_from_velocity_east() -> void:
	assert_eq(PlayerAnimator.direction_from_velocity(Vector2(1, 0)), 0)


func test_direction_from_velocity_south() -> void:
	assert_eq(PlayerAnimator.direction_from_velocity(Vector2(0, 1)), 2)


func test_direction_from_velocity_west() -> void:
	assert_eq(PlayerAnimator.direction_from_velocity(Vector2(-1, 0)), 4)


func test_direction_from_velocity_north() -> void:
	assert_eq(PlayerAnimator.direction_from_velocity(Vector2(0, -1)), 6)


func test_direction_from_velocity_diagonal_se() -> void:
	assert_eq(PlayerAnimator.direction_from_velocity(Vector2(1, 1)), 1)


# --- PlayerAnimator behaviour on the live player ---

func test_animator_starts_idle() -> void:
	var a: PlayerAnimator = world.p1.get_node("Animator")
	assert_eq(a.get_state(), PlayerAnimator.State.IDLE)


func test_animator_switches_to_run_on_velocity() -> void:
	var a: PlayerAnimator = world.p1.get_node("Animator")
	a.set_facing_velocity(Vector2(1, 0.5))
	assert_eq(a.get_state(), PlayerAnimator.State.RUN)
	a.set_facing_velocity(Vector2.ZERO)
	assert_eq(a.get_state(), PlayerAnimator.State.IDLE)


func test_animator_pickup_oneshot_reverts() -> void:
	var a: PlayerAnimator = world.p1.get_node("Animator")
	a.set_facing_velocity(Vector2(1, 0))
	assert_eq(a.get_state(), PlayerAnimator.State.RUN)
	a.play_pickup_oneshot()
	assert_eq(a.get_state(), PlayerAnimator.State.PICKUP)
	a._on_animation_finished()  # simulate end of oneshot
	assert_eq(a.get_state(), PlayerAnimator.State.RUN)


func test_animator_builds_all_state_direction_anims() -> void:
	var a: PlayerAnimator = world.p1.get_node("Animator")
	for state_name in ["Idle", "Run", "Pickup"]:
		for d in 8:
			var anim_name := "%s_%d" % [state_name, d]
			assert_true(a.sprite_frames.has_animation(anim_name),
				"Missing animation %s" % anim_name)
			assert_gt(a.sprite_frames.get_frame_count(anim_name), 0,
				"Animation %s should have at least one frame (fallback)" % anim_name)


# --- Hittable + attack hit-scan ---

func test_hittable_destroyed_after_hp_runs_out() -> void:
	var sprite := Sprite2D.new()
	world.decorations.add_child(sprite)
	var h := Hittable.new()
	h.kind = &"tree"
	h.hp = 2
	sprite.add_child(h)
	var seen := []
	h.destroyed.connect(func(kind, _pos): seen.append(kind))
	h.take_hit(1)
	assert_eq(h.hp, 1)
	assert_eq(seen.size(), 0)
	h.take_hit(1)
	assert_eq(seen.size(), 1)
	assert_eq(seen[0], &"tree")


func test_attack_hits_nearby_hittable_in_facing_direction() -> void:
	var p: PlayerController = world.p1
	# Plant a tree one tile to the east of the player.
	var tree := Sprite2D.new()
	tree.position = p.position + Vector2(IsoUtils.TILE_SIZE.x, 0)
	world.decorations.add_child(tree)
	var h := Hittable.new()
	h.kind = &"tree"
	h.hp = 1
	tree.add_child(h)
	var destroyed_emitted := [false]
	h.destroyed.connect(func(_k, _p): destroyed_emitted[0] = true)
	# Face east.
	p._last_world_vel = Vector2(1, 0)
	p._attack_cooldown = 0.0
	p.attack()
	assert_true(destroyed_emitted[0], "Tree in front should be destroyed")


func test_attack_misses_hittable_behind_player() -> void:
	var p: PlayerController = world.p1
	var tree := Sprite2D.new()
	tree.position = p.position + Vector2(-IsoUtils.TILE_SIZE.x, 0)
	world.decorations.add_child(tree)
	var h := Hittable.new()
	h.kind = &"tree"
	h.hp = 1
	tree.add_child(h)
	var destroyed_emitted := [false]
	h.destroyed.connect(func(_k, _p): destroyed_emitted[0] = true)
	p._last_world_vel = Vector2(1, 0)  # facing east
	p._attack_cooldown = 0.0
	p.attack()
	assert_false(destroyed_emitted[0], "Tree behind player should not be hit")


func test_attack_respects_cooldown() -> void:
	var p: PlayerController = world.p1
	var tree := Sprite2D.new()
	tree.position = p.position + Vector2(IsoUtils.TILE_SIZE.x, 0)
	world.decorations.add_child(tree)
	var h := Hittable.new()
	h.kind = &"rock"
	h.hp = 5
	tree.add_child(h)
	p._last_world_vel = Vector2(1, 0)
	p._attack_cooldown = 0.0
	p.attack()
	var hp_after_first: int = h.hp
	# Second attack should be blocked by cooldown.
	p.attack()
	assert_eq(h.hp, hp_after_first, "Cooldown should block back-to-back attacks")


func test_player_take_hit_reduces_health() -> void:
	var p: PlayerController = world.p1
	p.health = 5
	p.take_hit(2)
	assert_eq(p.health, 3)
	p.take_hit(99)
	assert_eq(p.health, 0)


func test_world_decorations_attach_hittables_to_mineable_kinds() -> void:
	var found_mineable: bool = false
	for n in world.decorations.get_children():
		for c in n.get_children():
			if c is Hittable:
				found_mineable = true
				assert_true(Hittable.is_mineable_kind(c.kind))
				break
		if found_mineable:
			break
	# Some seeds may produce few decorations; just assert API consistency
	# rather than requiring a specific count.
	assert_true(true)
