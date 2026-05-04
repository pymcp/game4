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
	# Add a weapon (hotbar-eligible) and a material (filtered out).
	p1.inventory.add(&"base_axe", 1)
	p1.inventory.add(&"wood", 3)
	await get_tree().process_frame

	var view := Hotbar.build_view(p1.inventory, 8)
	assert_eq(view[0]["id"], &"base_axe", "first slot has weapon")
	assert_eq(view[0]["count"], 1, "count = 1")
	assert_eq(view[1]["id"], StringName(""), "wood is filtered out of hotbar")

	# P2 hotbar still empty.
	var p2: PlayerController = World.instance().get_player(1)
	var view2 := Hotbar.build_view(p2.inventory, 8)
	assert_eq(view2[0]["id"], StringName(""), "P2 slot still empty")
