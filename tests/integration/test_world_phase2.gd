## Phase-2 integration: load Game.tscn, verify the World has the iso tilemap
## populated and that the player spawn lands on a walkable cell.
extends GutTest

const GameScene: PackedScene = preload("res://scenes/main/Game.tscn")

var game: Node = null
var world: WorldRoot = null


func before_each() -> void:
	game = GameScene.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	# Find the WorldRoot inside P1's viewport.
	# Wait one extra frame so Game.gd's deferred _wire_hud_and_cameras runs
	# (it spawns the players that the World coordinator will then re-parent
	# into their starting WorldRoot instance).
	await get_tree().process_frame
	var coord: World = (game as Game)._world
	assert_not_null(coord, "World coordinator missing")
	world = coord.get_player_world(0)
	assert_not_null(world)


func test_ground_layer_has_tiles() -> void:
	var cells: Array[Vector2i] = world.ground_layer.get_used_cells()
	assert_gt(cells.size(), 50, "ground layer should be painted")


func test_water_layer_has_tiles() -> void:
	var cells: Array[Vector2i] = world.water_layer.get_used_cells()
	assert_gt(cells.size(), 50, "water layer should be painted")


func test_water_layer_has_shader_material() -> void:
	assert_true(world.water_layer.material is ShaderMaterial)


func test_player_spawned_on_walkable_cell() -> void:
	var p1_cell: Vector2i = IsoUtils.world_to_iso(world.p1.position)
	assert_true(world.is_walkable(p1_cell), "P1 should spawn on a walkable cell")


func test_two_players_at_distinct_cells() -> void:
	assert_ne(world.p1.position, world.p2.position)
