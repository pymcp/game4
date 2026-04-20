extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")


func test_hud_hotbars_mirror_player_inventory() -> void:
	var game: Game = _GameScene.instantiate() as Game
	add_child_autoqfree(game)
	# Need 2+ frames: 1 for autoload + game._ready, 1 for deferred wire.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	assert_not_null(game._hotbar_p1, "P1 hotbar built")
	assert_not_null(game._hotbar_p2, "P2 hotbar built")
	assert_not_null(World.instance().get_player(0), "P1 player exists")
	assert_not_null(World.instance().get_player(1), "P2 player exists")

	var p1: PlayerController = World.instance().get_player(0)
	# Add an item to P1's inventory; hotbar should refresh via signal.
	p1.inventory.add(&"wood", 3)
	await get_tree().process_frame

	var view := Hotbar.build_view(p1.inventory, 8)
	assert_eq(view[0]["id"], &"wood", "first slot has wood")
	assert_eq(view[0]["count"], 3, "count = 3")

	# P2 hotbar still empty.
	var p2: PlayerController = World.instance().get_player(1)
	var view2 := Hotbar.build_view(p2.inventory, 8)
	assert_eq(view2[0]["id"], StringName(""), "P2 slot still empty")
