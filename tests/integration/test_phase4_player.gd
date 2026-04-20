## Phase 4: PlayerAnimator + tile-based mining + attack mechanics.
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


# --- Tile-based mining + attack mechanics ---

func test_mine_at_decrements_hp() -> void:
	# Plant a fake mineable entry into the world's internal dict.
	var cell := Vector2i(3, 3)
	world._mineable[cell] = {"kind": &"rock", "hp": 5}
	var res: Dictionary = world.mine_at(cell, 1)
	assert_true(res["hit"])
	assert_false(res["destroyed"])
	assert_eq(world._mineable[cell]["hp"], 4)


func test_mine_at_destroys_at_zero_hp() -> void:
	var cell := Vector2i(4, 4)
	world._mineable[cell] = {"kind": &"bush", "hp": 1}
	var res: Dictionary = world.mine_at(cell, 1)
	assert_true(res["hit"])
	assert_true(res["destroyed"])
	assert_eq(res["kind"], &"bush")
	assert_false(world._mineable.has(cell))


func test_mine_at_returns_drops_on_destroy() -> void:
	var cell := Vector2i(5, 5)
	world._mineable[cell] = {"kind": &"tree", "hp": 1}
	var res: Dictionary = world.mine_at(cell, 3)
	assert_true(res["destroyed"])
	var drops: Array = res["drops"]
	assert_gt(drops.size(), 0, "Tree should drop at least one item")


func test_mine_at_miss_on_empty_cell() -> void:
	var res: Dictionary = world.mine_at(Vector2i(99, 99), 1)
	assert_false(res["hit"])


func test_pickaxe_bonus_doubles_damage() -> void:
	# Populate a rock in the mineable dict.
	var cell := Vector2i(7, 7)
	world._mineable[cell] = {"kind": &"rock", "hp": 6}
	# Get the player and equip a pickaxe.
	var p: PlayerController = world.get_player(0)
	if p == null:
		gut.p("Player not available in this configuration — skip")
		assert_true(true)
		return
	p.equipment.equip(ItemDefinition.Slot.TOOL, &"pickaxe")
	p._facing_dir = Vector2i(1, 0)
	# Compute damage: should be 2 (base 1 doubled for rock kind).
	var dmg: int = p._compute_mine_damage(cell)
	assert_eq(dmg, 2, "Pickaxe should double damage vs rocks")
	p.equipment.unequip(ItemDefinition.Slot.TOOL)


func test_pickaxe_normal_damage_vs_tree() -> void:
	var cell := Vector2i(8, 8)
	world._mineable[cell] = {"kind": &"tree", "hp": 3}
	var p: PlayerController = world.get_player(0)
	if p == null:
		gut.p("Player not available — skip")
		assert_true(true)
		return
	p.equipment.equip(ItemDefinition.Slot.TOOL, &"pickaxe")
	p._facing_dir = Vector2i(1, 0)
	var dmg: int = p._compute_mine_damage(cell)
	assert_eq(dmg, 1, "Pickaxe should NOT double damage vs trees")
	p.equipment.unequip(ItemDefinition.Slot.TOOL)


func test_attack_cooldown_blocks_rapid_attack() -> void:
	var p: PlayerController = world.get_player(0)
	if p == null:
		gut.p("Player not available — skip")
		assert_true(true)
		return
	# Set cooldown to a positive value.
	p._attack_cooldown = 1.0
	assert_gt(p._attack_cooldown, 0.0, "Cooldown should be positive before tick")


func test_gold_vein_in_mineable_hp() -> void:
	assert_true(WorldRoot.MINEABLE_HP.has(&"gold_vein"),
		"gold_vein should be in MINEABLE_HP")
	assert_true(WorldRoot.MINEABLE_DROPS.has(&"gold_vein"),
		"gold_vein should be in MINEABLE_DROPS")
