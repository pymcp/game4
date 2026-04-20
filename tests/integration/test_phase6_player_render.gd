## P6 smoke test: spawn Game.tscn, advance frames, verify both
## players are spawned and findable through the World coordinator.
extends GutTest

const GameScene := preload("res://scenes/main/Game.tscn")


func test_each_player_is_spawned() -> void:
	var game = GameScene.instantiate()
	add_child_autofree(game)
	# Wait a few frames for _ready chain + signal propagation.
	for i in 4:
		await get_tree().process_frame
	var w0: WorldRoot = game.get_world(0)
	var w1: WorldRoot = game.get_world(1)
	assert_not_null(w0, "WorldRoot for P0 missing")
	assert_not_null(w1, "WorldRoot for P1 missing")
	var coord: World = (game as Game)._world
	var p0: PlayerController = coord.get_player(0)
	var p1: PlayerController = coord.get_player(1)
	assert_not_null(p0, "P0 not spawned")
	assert_not_null(p1, "P1 not spawned")
	assert_eq(p0.player_id, 0)
	assert_eq(p1.player_id, 1)
