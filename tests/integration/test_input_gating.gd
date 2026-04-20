extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")


func _find_world(_node: Node, pid: int) -> WorldRoot:
	var w: World = World.instance()
	if w == null:
		return null
	return w.get_player_world(pid)


func test_player_in_inventory_context_does_not_move() -> void:
	var game := _GameScene.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var w := _find_world(game, 0)
	assert_not_null(w)
	var p := World.instance().get_player(0)
	assert_not_null(p)

	var start: Vector2 = p.position
	# Switch P1 to INVENTORY context — _physics_process should now early-out.
	InputContext.set_context(0, InputContext.Context.INVENTORY)
	# Simulate "right" being held.
	Input.action_press(&"p1_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"p1_right")
	assert_eq(p.position, start, "player should not move while in INVENTORY context")

	# Restore for cleanup.
	InputContext.set_context(0, InputContext.Context.GAMEPLAY)


func test_player_in_disabled_context_does_not_move() -> void:
	var game := _GameScene.instantiate()
	add_child_autofree(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var w := _find_world(game, 0)
	var p := World.instance().get_player(0)
	var start: Vector2 = p.position
	InputContext.set_context(0, InputContext.Context.DISABLED)
	Input.action_press(&"p1_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"p1_right")
	assert_eq(p.position, start, "player should not move while DISABLED")
	InputContext.set_context(0, InputContext.Context.GAMEPLAY)
