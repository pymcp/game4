extends GutTest

func test_verb_constants_exist() -> void:
	assert_eq(PlayerActions.UP, &"up")
	assert_eq(PlayerActions.DOWN, &"down")
	assert_eq(PlayerActions.LEFT, &"left")
	assert_eq(PlayerActions.RIGHT, &"right")
	assert_eq(PlayerActions.INTERACT, &"interact")
	assert_eq(PlayerActions.BACK, &"back")
	assert_eq(PlayerActions.ATTACK, &"attack")
	assert_eq(PlayerActions.INVENTORY, &"inventory")
	assert_eq(PlayerActions.TAB_PREV, &"tab_prev")
	assert_eq(PlayerActions.TAB_NEXT, &"tab_next")
	assert_eq(PlayerActions.AUTO_MINE, &"auto_mine")
	assert_eq(PlayerActions.AUTO_ATTACK, &"auto_attack")
	assert_eq(PlayerActions.WORLDMAP, &"worldmap")

func test_action_builds_correct_name_p1() -> void:
	assert_eq(PlayerActions.action(0, PlayerActions.UP), &"p1_up")
	assert_eq(PlayerActions.action(0, PlayerActions.BACK), &"p1_back")
	assert_eq(PlayerActions.action(0, PlayerActions.INVENTORY), &"p1_inventory")

func test_action_builds_correct_name_p2() -> void:
	assert_eq(PlayerActions.action(1, PlayerActions.UP), &"p2_up")
	assert_eq(PlayerActions.action(1, PlayerActions.INTERACT), &"p2_interact")
	assert_eq(PlayerActions.action(1, PlayerActions.TAB_NEXT), &"p2_tab_next")

func test_prefix_matches_action() -> void:
	assert_eq(PlayerActions.prefix(0), "p1_")
	assert_eq(PlayerActions.prefix(1), "p2_")

func test_either_just_pressed_requires_event() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.pressed = false
	assert_false(PlayerActions.either_just_pressed(ev, PlayerActions.UP),
		"Non-pressed event should return false")
