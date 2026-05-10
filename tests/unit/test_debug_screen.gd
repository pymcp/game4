# tests/unit/test_debug_screen.gd
extends GutTest

const _Scene := preload("res://scenes/ui/DebugScreen.tscn")
var _screen: DebugScreen = null


func before_each() -> void:
	_screen = _Scene.instantiate() as DebugScreen
	add_child_autofree(_screen)
	await get_tree().process_frame


func after_each() -> void:
	if PauseManager.is_paused():
		PauseManager.set_paused(false)
	GameState.set_flag("debug_mode", false)
	_screen = null


func test_starts_closed() -> void:
	assert_false(_screen._is_open, "should start closed")
	assert_false(_screen.visible, "should start invisible")


func test_open_sets_visible() -> void:
	_screen.open()
	assert_true(_screen._is_open, "should be open")
	assert_true(_screen.visible, "should be visible")


func test_close_hides() -> void:
	_screen.open()
	_screen.close()
	assert_false(_screen._is_open, "should be closed")
	assert_false(_screen.visible, "should be invisible")


func test_open_pauses_if_not_already_paused() -> void:
	assert_false(PauseManager.is_paused())
	_screen.open()
	assert_true(PauseManager.is_paused(), "opening debug screen should pause game")


func test_close_unpauses_when_we_caused_pause() -> void:
	_screen.open()
	assert_true(_screen._caused_pause, "should track that we caused the pause")
	_screen.close()
	assert_false(PauseManager.is_paused(), "closing should unpause")


func test_open_does_not_double_pause() -> void:
	PauseManager.set_paused(true)
	_screen.open()
	assert_false(_screen._caused_pause, "should not claim to have caused pre-existing pause")
	_screen.close()
	# Game was paused before we opened — must remain paused.
	assert_true(PauseManager.is_paused(), "game was paused before debug screen; should stay paused")
	PauseManager.set_paused(false)


func test_cursor_wraps_up_from_zero() -> void:
	_screen.open()
	var last: int = _screen._main_nav.size() - 1
	_screen._nav.move(-1)
	assert_eq(_screen._nav.cursor, last, "cursor should wrap to last button")


func test_cursor_wraps_down_from_last() -> void:
	_screen.open()
	_screen._nav.reset(_screen._main_nav.size() - 1)
	_screen._nav.move(1)
	assert_eq(_screen._nav.cursor, 0, "cursor should wrap to first button")


func test_debug_mode_flag_toggles_on() -> void:
	GameState.set_flag("debug_mode", false)
	_screen.open()
	_screen._on_debug_mode_pressed()
	assert_true(GameState.get_flag("debug_mode"), "debug_mode should be ON")


func test_debug_mode_flag_toggles_off() -> void:
	GameState.set_flag("debug_mode", true)
	_screen.open()
	_screen._on_debug_mode_pressed()
	assert_false(GameState.get_flag("debug_mode"), "debug_mode should be OFF")


func test_debug_mode_label_reflects_state() -> void:
	GameState.set_flag("debug_mode", false)
	_screen._refresh_debug_mode_label()
	assert_true(_screen._btn_debug_mode.text.contains("OFF"), "label should show OFF")
	GameState.set_flag("debug_mode", true)
	_screen._refresh_debug_mode_label()
	assert_true(_screen._btn_debug_mode.text.contains("ON"), "label should show ON")


func test_teleport_button_enters_sub_list() -> void:
	_screen.open()
	_screen._on_teleport_pressed()
	assert_true(_screen._in_sub_list, "should enter sub-list after teleport pressed")
	assert_true(_screen._sub_panel.visible, "sub panel should be visible")
	assert_false(_screen._main_buttons_box.visible, "main buttons should be hidden")


func test_back_from_sub_list_returns_to_main() -> void:
	_screen.open()
	_screen._on_teleport_pressed()
	_screen._show_main_list()
	assert_false(_screen._in_sub_list, "should exit sub-list")
	assert_true(_screen._main_buttons_box.visible, "main buttons should be visible again")
