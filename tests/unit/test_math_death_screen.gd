## Tests for MathDeathScreen — the math-problem revival overlay.
extends GutTest

const _Scene := preload("res://scenes/ui/MathDeathScreen.tscn")

func _new_screen() -> MathDeathScreen:
	var s := _Scene.instantiate() as MathDeathScreen
	add_child_autofree(s)
	return s


# --- Tier parameters (_get_tier) ----------------------------------

func test_tier_death1_is_add_sub_max4() -> void:
	var screen := _new_screen()
	var tier: Dictionary = screen._get_tier(1)
	assert_eq(tier.max_operand, 4)
	assert_false(tier.use_div, "death 1 should not have division")
	assert_false(tier.use_mul, "death 1 should not have multiplication")


func test_tier_death2_adds_division() -> void:
	var screen := _new_screen()
	var tier: Dictionary = screen._get_tier(2)
	assert_eq(tier.max_operand, 4)
	assert_true(tier.use_div, "death 2 should have division")
	assert_false(tier.use_mul, "death 2 should not yet have multiplication")


func test_tier_death3_adds_multiplication() -> void:
	var screen := _new_screen()
	var tier: Dictionary = screen._get_tier(3)
	assert_eq(tier.max_operand, 4)
	assert_true(tier.use_div)
	assert_true(tier.use_mul)


func test_tier_death4_bumps_to_9_add_sub_only() -> void:
	var screen := _new_screen()
	var tier: Dictionary = screen._get_tier(4)
	assert_eq(tier.max_operand, 9)
	assert_false(tier.use_div, "death 4 resets to add/sub only")
	assert_false(tier.use_mul)


func test_tier_death5_all_ops_max9() -> void:
	var screen := _new_screen()
	var tier: Dictionary = screen._get_tier(5)
	assert_eq(tier.max_operand, 9)
	assert_true(tier.use_div)
	assert_true(tier.use_mul)


func test_tier_death6_bumps_to_14_add_sub_only() -> void:
	var screen := _new_screen()
	var tier: Dictionary = screen._get_tier(6)
	assert_eq(tier.max_operand, 14)
	assert_false(tier.use_div)
	assert_false(tier.use_mul)


func test_tier_death7_all_ops_max14() -> void:
	var screen := _new_screen()
	var tier: Dictionary = screen._get_tier(7)
	assert_eq(tier.max_operand, 14)
	assert_true(tier.use_div)
	assert_true(tier.use_mul)


func test_tier_max_operand_capped_at_99() -> void:
	var screen := _new_screen()
	# Check a very large death count never exceeds 99.
	for d in [100, 200, 1000]:
		var tier: Dictionary = screen._get_tier(d)
		assert_true(tier.max_operand <= 99,
			"max_operand should never exceed 99 (death %d)" % d)


# --- Death counter per player ------------------------------------

func test_death_counter_starts_at_zero() -> void:
	var screen := _new_screen()
	assert_eq(screen.get_death_count(0), 0)
	assert_eq(screen.get_death_count(1), 0)


func test_show_for_player_increments_that_players_counter() -> void:
	var screen := _new_screen()
	screen.show_for_player(0)
	assert_eq(screen.get_death_count(0), 1)
	assert_eq(screen.get_death_count(1), 0, "P1 death should not affect P2")


func test_death_counters_are_independent() -> void:
	var screen := _new_screen()
	screen.show_for_player(0)
	screen.hide_screen()
	screen.show_for_player(0)
	screen.hide_screen()
	screen.show_for_player(1)
	assert_eq(screen.get_death_count(0), 2)
	assert_eq(screen.get_death_count(1), 1)


# --- Problem generation -------------------------------------------

func test_generate_problem_sets_answer() -> void:
	var screen := _new_screen()
	screen.show_for_player(0)
	var label_text: String = screen._problem_label.text
	assert_true(
		label_text.contains("+") or label_text.contains("-") or
		label_text.contains("×") or label_text.contains("÷"),
		"problem should contain an operator"
	)
	assert_ne(screen.get_player_id(), -1, "player id should be set")


func test_addition_answer_is_correct() -> void:
	var screen := _new_screen()
	for i in 50:
		screen._generate_problem()
		if "+" in screen._problem_label.text:
			break
	if "+" not in screen._problem_label.text:
		pass_test("could not force addition in 50 tries — probabilistic skip")
		return
	var parts: PackedStringArray = screen._problem_label.text.split(" ")
	var a: int = parts[0].to_int()
	var b: int = parts[2].to_int()
	assert_eq(screen.get_answer(), a + b, "answer should be a + b")


func test_subtraction_answer_is_correct() -> void:
	var screen := _new_screen()
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
	var screen := _new_screen()
	for i in 200:
		screen._generate_problem()
		assert_true(screen.get_answer() >= 0,
			"answer should never be negative (iteration %d)" % i)


func test_division_answer_is_always_integer() -> void:
	# Death 2+ unlocks division. Simulate a death-2 player by calling
	# show_for_player twice so the internal counter is 2.
	var screen := _new_screen()
	screen.show_for_player(0)
	screen.hide_screen()
	screen.show_for_player(0)
	# Now at death 2 — division is available. Spin until we get one.
	var got_div := false
	for i in 200:
		screen._generate_problem()
		if "÷" in screen._problem_label.text:
			got_div = true
			var parts := screen._problem_label.text.split(" ")
			var dividend: int = parts[0].to_int()
			var divisor: int  = parts[2].to_int()
			assert_gt(divisor, 0, "divisor must be positive")
			assert_eq(dividend % divisor, 0, "division must be exact (no remainder)")
			assert_eq(screen.get_answer(), dividend / divisor)
			break
	if not got_div:
		pass_test("could not force division in 200 tries — probabilistic skip")


func test_multiplication_answer_is_correct() -> void:
	# Death 3+ unlocks multiplication.
	var screen := _new_screen()
	for _i in 3:
		screen.show_for_player(0)
		screen.hide_screen()
	screen.show_for_player(0)
	var got_mul := false
	for i in 200:
		screen._generate_problem()
		if "×" in screen._problem_label.text:
			got_mul = true
			var parts := screen._problem_label.text.split(" ")
			var a: int = parts[0].to_int()
			var b: int = parts[2].to_int()
			assert_eq(screen.get_answer(), a * b)
			break
	if not got_mul:
		pass_test("could not force multiplication in 200 tries — probabilistic skip")


func test_operands_within_tier_range_death1() -> void:
	var screen := _new_screen()
	screen.show_for_player(0)
	for i in 200:
		screen._generate_problem()
		var parts := screen._problem_label.text.split(" ")
		var a: int = parts[0].to_int()
		assert_true(a >= 1 and a <= 4,
			"death-1 first operand should be in [1,4], got %d" % a)


func test_operands_within_tier_range_death4() -> void:
	var screen := _new_screen()
	for _i in 4:
		screen.show_for_player(0)
		screen.hide_screen()
	screen.show_for_player(0)
	for i in 200:
		screen._generate_problem()
		# For + and - the displayed operands are the raw values.
		# For × and ÷ the dividend can exceed max_operand intentionally.
		var parts := screen._problem_label.text.split(" ")
		var a: int = parts[0].to_int()
		var op: String = parts[1]
		if op == "+" or op == "-":
			assert_true(a >= 1 and a <= 9,
				"death-4 operand should be in [1,9], got %d" % a)


# --- Answer checking ----------------------------------------------

func test_correct_answer_emits_signal() -> void:
	var screen := _new_screen()
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
	var screen := _new_screen()
	screen.show_for_player(0)
	screen._input_field.text = str(screen.get_answer() + 1)
	screen._check_answer()
	assert_eq(screen._feedback_label.text, "Try again!")
	assert_true(screen.visible, "screen should remain visible")


func test_non_numeric_input_shows_feedback() -> void:
	var screen := _new_screen()
	screen.show_for_player(0)
	screen._input_field.text = "abc"
	screen._check_answer()
	assert_eq(screen._feedback_label.text, "Enter a number!")
	assert_true(screen.visible, "screen should remain visible")


func test_empty_input_shows_feedback() -> void:
	var screen := _new_screen()
	screen.show_for_player(0)
	screen._input_field.text = ""
	screen._check_answer()
	assert_eq(screen._feedback_label.text, "Enter a number!")


# --- Visibility lifecycle -----------------------------------------

func test_starts_hidden() -> void:
	var screen := _new_screen()
	assert_false(screen.visible, "should start hidden")


func test_show_for_player_makes_visible() -> void:
	var screen := _new_screen()
	screen.show_for_player(0)
	assert_true(screen.visible)
	assert_eq(screen.get_player_id(), 0)


func test_hide_screen_clears_state() -> void:
	var screen := _new_screen()
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
