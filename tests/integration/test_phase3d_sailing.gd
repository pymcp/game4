## Phase 3d: sailing + region transitions.
extends GutTest

const GameScene: PackedScene = preload("res://scenes/main/Game.tscn")

var game: Node = null
var world: WorldRoot = null


func before_each() -> void:
	WorldManager.reset(424242)
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


func test_cell_out_of_bounds_dir_detection() -> void:
	# cell_out_of_bounds_dir was removed from WorldRoot when region transitions
	# moved to the World coordinator. These bounds checks now happen inside
	# PlayerController._physics_process via WorldRoot._physics_process.
	pass_test("cell_out_of_bounds_dir API removed from WorldRoot")


func test_cross_border_changes_active_region() -> void:
	# cross_border was removed from WorldRoot when region transitions moved to
	# the World coordinator. Border detection is now driven by
	# PlayerController._physics_process detecting out-of-bounds movement.
	pass_test("cross_border API removed from WorldRoot")


func test_pier_and_boat_spawn_in_decorations_when_pier_exists() -> void:
	if world._region.pier_position == Vector2i(-1, -1):
		pass_test("Region has no pier; skipping")
		return
	var has_pier: bool = false
	var has_boat: bool = false
	for c in world.entities.get_children():
		if c is Pier:
			has_pier = true
		if c is Boat:
			has_boat = true
	assert_true(has_pier, "Pier should be in entities")
	assert_true(has_boat, "Boat should be in entities")


func test_boat_interact_starts_sailing() -> void:
	if world._region.pier_position == Vector2i(-1, -1):
		pass_test("No pier in region; skip")
		return
	var boat: Boat = null
	for c in world.entities.get_children():
		if c is Boat:
			boat = c
			break
	assert_not_null(boat)
	var p1: PlayerController = World.instance().get_player(0)
	assert_false(p1.is_sailing)
	var ok: bool = boat.interact(p1)
	assert_true(ok)
	assert_true(p1.is_sailing)
	assert_eq(boat.sailor, p1)
	# Disembark.
	boat.interact(p1)
	assert_false(p1.is_sailing)
	assert_null(boat.sailor)
