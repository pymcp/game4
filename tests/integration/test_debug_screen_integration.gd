# tests/integration/test_debug_screen_integration.gd
extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")
var _game: Game = null


func before_each() -> void:
	WorldManager.reset(202402)
	GameState.clear_flags()
	_game = _GameScene.instantiate()
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	if PauseManager.is_paused():
		PauseManager.set_paused(false)
	GameState.clear_flags()
	_game = null


func _get_screen() -> DebugScreen:
	return _game.get_node_or_null("DebugScreen") as DebugScreen


func test_debug_screen_exists_as_child_of_game() -> void:
	var screen := _get_screen()
	assert_not_null(screen, "DebugScreen should be a child of Game")


func test_debug_screen_is_layer_60() -> void:
	var screen := _get_screen()
	if screen == null:
		pending("DebugScreen not found")
		return
	assert_eq(screen.layer, 60, "DebugScreen should sit on layer 60 (above death screen)")


func test_f4_opens_modal_and_pauses() -> void:
	var screen := _get_screen()
	if screen == null:
		pending("DebugScreen not found")
		return
	assert_false(screen._is_open)
	screen.open()
	assert_true(screen._is_open, "should be open after open()")
	assert_true(PauseManager.is_paused(), "game should be paused")


func test_f4_close_unpauses() -> void:
	var screen := _get_screen()
	if screen == null:
		pending("DebugScreen not found")
		return
	screen.open()
	screen.close()
	assert_false(screen._is_open, "should be closed")
	assert_false(PauseManager.is_paused(), "game should be unpaused")


func test_debug_mode_flag_persists_in_game_state() -> void:
	var screen := _get_screen()
	if screen == null:
		pending("DebugScreen not found")
		return
	assert_false(GameState.get_flag("debug_mode"))
	screen.open()
	screen._on_debug_mode_pressed()
	assert_true(GameState.get_flag("debug_mode"), "debug_mode flag should be ON in GameState")


func test_debug_mode_off_after_two_presses() -> void:
	var screen := _get_screen()
	if screen == null:
		pending("DebugScreen not found")
		return
	screen.open()
	screen._on_debug_mode_pressed()
	screen._on_debug_mode_pressed()
	assert_false(GameState.get_flag("debug_mode"), "two presses should return to OFF")


func test_sub_list_shows_no_objectives_when_none_registered() -> void:
	var screen := _get_screen()
	if screen == null:
		pending("DebugScreen not found")
		return
	QuestTracker.reset()
	screen.open()
	screen._on_teleport_pressed()
	assert_true(screen._in_sub_list, "should be in sub-list")
	# With no objectives, the sub_list should have one Label child (the "no objectives" message).
	assert_eq(screen._sub_buttons.size(), 0, "no objective buttons when none registered")
	var children := screen._sub_list.get_children()
	assert_true(children.size() > 0, "sub_list should have at least the info label")
