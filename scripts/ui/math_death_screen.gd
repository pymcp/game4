## MathDeathScreen
##
## Full-screen overlay shown when a player dies. Pauses the game and
## presents a simple math problem (addition or subtraction, numbers < 100).
## On correct answer the player is restored to full health and the game
## resumes.
extends CanvasLayer
class_name MathDeathScreen

signal answered_correctly(player_id: int)

var _player_id: int = -1
var _answer: int = 0
var _death_counts: Dictionary = {}

@onready var _panel: PanelContainer = $Center/Panel
@onready var _problem_label: Label = $Center/Panel/VBox/ProblemLabel
@onready var _input_field: LineEdit = $Center/Panel/VBox/AnswerRow/AnswerInput
@onready var _feedback_label: Label = $Center/Panel/VBox/FeedbackLabel
@onready var _submit_button: Button = $Center/Panel/VBox/AnswerRow/SubmitButton


func _ready() -> void:
	# Apply the dramatic death-screen panel style (dark purple, generous padding).
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.18, 0.95)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", sb)

	_input_field.text_submitted.connect(_on_text_submitted)
	_submit_button.pressed.connect(_on_submit_pressed)
	hide_screen()


## Returns the difficulty tier dict for [param death_count].
## Keys: max_operand (int), use_div (bool), use_mul (bool).
func _get_tier(death_count: int) -> Dictionary:
	var dc: int = maxi(death_count, 1)
	# Intro ramp: deaths 1–3 all use max=4.
	if dc <= 3:
		return {"max_operand": 4, "use_div": dc >= 2, "use_mul": dc >= 3}
	# Repeating 2-death cycle starting at death 4.
	# cycle_num counts how many +5 bumps have happened (0-indexed from death 4).
	var cycle_idx: int = dc - 4
	var cycle_num: int = cycle_idx / 2
	var cycle_step: int = cycle_idx % 2
	var max_op: int = mini(9 + cycle_num * 5, 99)
	# cycle_step 0 = add/sub only; cycle_step 1 = all four ops.
	return {"max_operand": max_op, "use_div": cycle_step == 1, "use_mul": cycle_step == 1}


## Generate a new problem and show the screen for [param pid].
func show_for_player(pid: int) -> void:
	_death_counts[pid] = _death_counts.get(pid, 0) + 1
	_player_id = pid
	_generate_problem()
	_feedback_label.text = ""
	_input_field.text = ""
	visible = true
	# Double-deferred to ensure focus after any other deferred UI calls.
	_input_field.call_deferred("grab_focus")
	get_tree().create_timer(0.0).timeout.connect(_input_field.grab_focus)


func hide_screen() -> void:
	visible = false
	_player_id = -1


func _generate_problem() -> void:
	var tier: Dictionary = _get_tier(_death_counts.get(_player_id, 1))
	var max_op: int = tier.max_operand

	# Build the allowed operator pool.
	var ops: Array[String] = ["+", "-"]
	if tier.use_div:
		ops.append("÷")
	if tier.use_mul:
		ops.append("×")

	var op: String = ops[randi() % ops.size()]
	var a: int = randi_range(1, max_op)
	var b: int = randi_range(1, max_op)

	match op:
		"+":
			_answer = a + b
			_problem_label.text = "%d + %d = ?" % [a, b]
		"-":
			# Ensure non-negative result.
			if a < b:
				var tmp: int = a
				a = b
				b = tmp
			_answer = a - b
			_problem_label.text = "%d - %d = ?" % [a, b]
		"÷":
			# Generate a×b ÷ b so answer is always a clean integer.
			_answer = a
			_problem_label.text = "%d ÷ %d = ?" % [a * b, b]
		"×":
			_answer = a * b
			_problem_label.text = "%d × %d = ?" % [a, b]


func _on_text_submitted(_text: String) -> void:
	_check_answer()


func _on_submit_pressed() -> void:
	_check_answer()


func _check_answer() -> void:
	var text: String = _input_field.text.strip_edges()
	if not text.is_valid_int():
		_feedback_label.text = "Enter a number!"
		_input_field.text = ""
		_input_field.grab_focus()
		return
	var guess: int = text.to_int()
	if guess == _answer:
		var pid: int = _player_id
		hide_screen()
		answered_correctly.emit(pid)
	else:
		_feedback_label.text = "Try again!"
		_input_field.text = ""
		_input_field.grab_focus()


## Expose for testing.
func get_answer() -> int:
	return _answer


## Expose for testing.
func get_player_id() -> int:
	return _player_id


## Expose for testing.
func get_death_count(pid: int) -> int:
	return _death_counts.get(pid, 0)
