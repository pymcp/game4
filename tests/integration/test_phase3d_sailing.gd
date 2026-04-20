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
	assert_eq(world.cell_out_of_bounds_dir(Vector2i(64, 64)), Vector2i.ZERO)
	assert_eq(world.cell_out_of_bounds_dir(Vector2i(-1, 50)), Vector2i(-1, 0))
	assert_eq(world.cell_out_of_bounds_dir(Vector2i(Region.SIZE, 50)), Vector2i(1, 0))
	assert_eq(world.cell_out_of_bounds_dir(Vector2i(50, -1)), Vector2i(0, -1))
	assert_eq(world.cell_out_of_bounds_dir(Vector2i(50, Region.SIZE)), Vector2i(0, 1))


func test_cross_border_changes_active_region() -> void:
	var origin_id: Vector2i = world._region.region_id
	# Force a known east-bound crossing.
	var crossing_cell := Vector2i(Region.SIZE, 50)
	world.cross_border(world.p1, Vector2i(1, 0), crossing_cell)
	assert_eq(world._region.region_id, origin_id + Vector2i(1, 0),
		"Active region should advance east")
	# Crosser now at x=0 of new region.
	var p1_cell: Vector2i = IsoUtils.world_to_iso(world.p1.position)
	assert_eq(p1_cell.x, 0, "P1 should land on west edge of new region")


func test_pier_and_boat_spawn_in_decorations_when_pier_exists() -> void:
	if world._region.pier_position == Vector2i(-1, -1):
		pass_test("Region has no pier; skipping")
		return
	var has_pier: bool = false
	var has_boat: bool = false
	for c in world.decorations.get_children():
		if c is Pier:
			has_pier = true
		if c is Boat:
			has_boat = true
	assert_true(has_pier, "Pier should be in decorations")
	assert_true(has_boat, "Boat should be in decorations")


func test_boat_interact_starts_sailing() -> void:
	if world._region.pier_position == Vector2i(-1, -1):
		pass_test("No pier in region; skip")
		return
	var boat: Boat = null
	for c in world.decorations.get_children():
		if c is Boat:
			boat = c
			break
	assert_not_null(boat)
	assert_false(world.p1.is_sailing)
	var ok: bool = boat.interact(world.p1)
	assert_true(ok)
	assert_true(world.p1.is_sailing)
	assert_eq(boat.sailor, world.p1)
	# Disembark.
	boat.interact(world.p1)
	assert_false(world.p1.is_sailing)
	assert_null(boat.sailor)
