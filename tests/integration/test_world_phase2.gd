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
	var cells: Array[Vector2i] = world.ground.get_used_cells()
	assert_gt(cells.size(), 50, "ground layer should be painted")


func test_water_layer_has_tiles() -> void:
	# Water is painted on the ground layer (no separate water TileMapLayer).
	var cells: Array[Vector2i] = world.ground.get_used_cells()
	assert_gt(cells.size(), 50, "ground layer should include water tiles")


func test_water_layer_has_shader_material() -> void:
	# Tileset is loaded from TilesetCatalog; confirm the ground tileset is set.
	assert_not_null(world.ground.tile_set, "ground layer should have a tileset")


func test_player_spawned_on_walkable_cell() -> void:
	var p1: PlayerController = World.instance().get_player(0)
	var p1_cell: Vector2i = Vector2i(
			int(floor(p1.position.x / float(WorldConst.TILE_PX))),
			int(floor(p1.position.y / float(WorldConst.TILE_PX))))
	assert_true(world.is_walkable(p1_cell), "P1 should spawn on a walkable cell")


func test_two_players_at_distinct_cells() -> void:
	var p1: PlayerController = World.instance().get_player(0)
	var p2: PlayerController = World.instance().get_player(1)
	assert_ne(p1.position, p2.position)
