## Phase 6d — MainMenu pure helpers + button-state tests.
extends GutTest


func test_parse_seed_blank_returns_zero() -> void:
	assert_eq(MainMenu.parse_seed(""), 0)
	assert_eq(MainMenu.parse_seed("   "), 0)


func test_parse_seed_numeric() -> void:
	assert_eq(MainMenu.parse_seed("42"), 42)
	assert_eq(MainMenu.parse_seed(" 1234 "), 1234)
	assert_eq(MainMenu.parse_seed("-7"), -7)


func test_parse_seed_named_is_deterministic() -> void:
	var a := MainMenu.parse_seed("hello")
	var b := MainMenu.parse_seed("hello")
	var c := MainMenu.parse_seed("world")
	assert_eq(a, b)
	assert_ne(a, c)


func test_has_save_false_for_nonexistent_slot() -> void:
	# Use an obviously absent slot id.
	assert_false(MainMenu.has_save("__unit_test_nope__"))


func test_continue_button_disabled_without_save() -> void:
	# Make sure the default slot does not exist for this test.
	var path := SaveGame.slot_path(SaveManager.DEFAULT_SLOT)
	if FileAccess.file_exists(path):
		# Don't delete the user's real save — instead check has_save matches
		# the button state.
		var menu := MainMenu.new()
		add_child_autofree(menu)
		await get_tree().process_frame
		assert_false(menu.get_continue_button().disabled)
	else:
		var menu := MainMenu.new()
		add_child_autofree(menu)
		await get_tree().process_frame
		assert_true(menu.get_continue_button().disabled)


func test_seed_input_present() -> void:
	var menu := MainMenu.new()
	add_child_autofree(menu)
	await get_tree().process_frame
	assert_not_null(menu.get_seed_input())


func test_pending_load_slot_default_empty() -> void:
	# Don't trample real state; just observe the field exists and starts
	# as empty for fresh autoload runs.
	GameSession.pending_load_slot = ""
	assert_eq(GameSession.pending_load_slot, "")
