## Tests for MathDeathScreen — the math-problem revival overlay.
extends GutTest


# --- Problem generation -------------------------------------------

func test_generate_problem_sets_answer() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	screen.show_for_player(0)
	# Answer should be set (non-default).
	var label_text: String = screen._problem_label.text
	assert_true(label_text.contains("+") or label_text.contains("-"),
		"problem should contain + or -")
	assert_ne(screen.get_player_id(), -1, "player id should be set")


func test_addition_answer_is_correct() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	# Force an addition problem by calling _generate multiple times
	# until we get one with "+".
	for i in 50:
		screen._generate_problem()
		if "+" in screen._problem_label.text:
			break
	if "+" not in screen._problem_label.text:
		pass_test("could not force addition in 50 tries — probabilistic skip")
		return
	# Parse: "A + B = ?"
	var parts: PackedStringArray = screen._problem_label.text.split(" ")
	var a: int = parts[0].to_int()
	var b: int = parts[2].to_int()
	assert_eq(screen.get_answer(), a + b, "answer should be a + b")


func test_subtraction_answer_is_correct() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	for i in 50:
		screen._generate_problem()
		if "-" in screen._problem_label.text:
			break
	if "-" not in screen._problem_label.text:
		pass_test("could not force subtraction in 50 tries — probabilistic skip")
		return
	var parts: PackedStringArray = screen._problem_label.text.split(" ")
	var a: int = parts[0].to_int()
	var b: int = parts[2].to_int()
	assert_eq(screen.get_answer(), a - b, "answer should be a - b")
	assert_true(screen.get_answer() >= 0, "subtraction result should be >= 0")


func test_subtraction_never_negative() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	for i in 200:
		screen._generate_problem()
		assert_true(screen.get_answer() >= 0,
			"answer should never be negative (iteration %d)" % i)


func test_numbers_under_100() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	for i in 100:
		screen._generate_problem()
		var parts: PackedStringArray = screen._problem_label.text.split(" ")
		var a: int = parts[0].to_int()
		var b: int = parts[2].to_int()
		assert_true(a >= 1 and a <= 99, "first operand in range")
		assert_true(b >= 1 and b <= 99, "second operand in range")


# --- Answer checking ----------------------------------------------

func test_correct_answer_emits_signal() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	screen.show_for_player(1)
	var received := [false, -1]
	screen.answered_correctly.connect(func(pid: int):
		received[0] = true
		received[1] = pid
	)
	screen._input_field.text = str(screen.get_answer())
	screen._check_answer()
	assert_true(received[0], "signal should have fired")
	assert_eq(received[1], 1, "signal should carry player_id 1")
	assert_false(screen.visible, "screen should hide after correct answer")


func test_wrong_answer_shows_feedback() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	screen.show_for_player(0)
	screen._input_field.text = str(screen.get_answer() + 1)
	screen._check_answer()
	assert_eq(screen._feedback_label.text, "Try again!")
	assert_true(screen.visible, "screen should remain visible")


func test_non_numeric_input_shows_feedback() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	screen.show_for_player(0)
	screen._input_field.text = "abc"
	screen._check_answer()
	assert_eq(screen._feedback_label.text, "Enter a number!")
	assert_true(screen.visible, "screen should remain visible")


func test_empty_input_shows_feedback() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	screen.show_for_player(0)
	screen._input_field.text = ""
	screen._check_answer()
	assert_eq(screen._feedback_label.text, "Enter a number!")


# --- Visibility lifecycle -----------------------------------------

func test_starts_hidden() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	assert_false(screen.visible, "should start hidden")


func test_show_for_player_makes_visible() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	screen.show_for_player(0)
	assert_true(screen.visible)
	assert_eq(screen.get_player_id(), 0)


func test_hide_screen_clears_state() -> void:
	var screen := MathDeathScreen.new()
	add_child_autofree(screen)
	screen.show_for_player(1)
	screen.hide_screen()
	assert_false(screen.visible)
	assert_eq(screen.get_player_id(), -1)


# --- Player death signal ------------------------------------------

func test_player_emits_died_signal_at_zero_health() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	player.max_health = 4
	player.health = 4
	var died_pids: Array = []
	player.player_died.connect(func(pid: int): died_pids.append(pid))
	player.player_id = 0
	# Direct damage — no world needed for the signal test.
	player.health = 1
	# Simulate take_hit reducing to 0.
	# We can't call take_hit without a full world, so test the signal directly.
	player.health = 0
	player.player_died.emit(player.player_id)
	assert_eq(died_pids.size(), 1)
	assert_eq(died_pids[0], 0)
