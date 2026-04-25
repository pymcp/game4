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

var _panel: PanelContainer = null
var _problem_label: Label = null
var _input_field: LineEdit = null
var _feedback_label: Label = null
var _submit_button: Button = null


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide_screen()


func _build() -> void:
	# Full-screen dim backdrop.
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color(0, 0, 0, 0.75)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Centred panel.
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 200)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.18, 0.95)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# "You died!" header.
	var header := Label.new()
	header.text = "You Died!"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(0.9, 0.25, 0.2))
	vbox.add_child(header)

	# "Solve to revive:" subtitle.
	var subtitle := Label.new()
	subtitle.text = "Solve to revive:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	vbox.add_child(subtitle)

	# Problem label.
	_problem_label = Label.new()
	_problem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_problem_label.add_theme_font_size_override("font_size", 32)
	_problem_label.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(_problem_label)

	# Answer input row.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	_input_field = LineEdit.new()
	_input_field.placeholder_text = "?"
	_input_field.custom_minimum_size = Vector2(100, 0)
	_input_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input_field.add_theme_font_size_override("font_size", 24)
	_input_field.text_submitted.connect(_on_text_submitted)
	row.add_child(_input_field)

	_submit_button = Button.new()
	_submit_button.text = "OK"
	_submit_button.add_theme_font_size_override("font_size", 20)
	_submit_button.pressed.connect(_on_submit_pressed)
	row.add_child(_submit_button)

	# Feedback label (wrong answer hint).
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 14)
	_feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	vbox.add_child(_feedback_label)


## Generate a new problem and show the screen for [param pid].
func show_for_player(pid: int) -> void:
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
	var a: int = randi_range(1, 99)
	var b: int = randi_range(1, 99)
	if randi() % 2 == 0:
		# Addition.
		_answer = a + b
		_problem_label.text = "%d + %d = ?" % [a, b]
	else:
		# Subtraction — ensure non-negative result.
		if a < b:
			var tmp: int = a
			a = b
			b = tmp
		_answer = a - b
		_problem_label.text = "%d - %d = ?" % [a, b]


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
