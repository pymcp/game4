## DialogueBox
##
## Per-viewport dialogue panel anchored to the bottom of one player's
## SubViewport. Created lazily by [WorldRoot.show_dialogue]; lives on a
## CanvasLayer so it sits above world tiles but below the cave-fade
## overlay (which uses layer 50 in WorldRoot).
##
## Usage:
##   var box := DialogueBox.spawn_for(world_root)
##   box.show_line("Eda", "Have you seen the sheep?")
##   ...
##   box.hide_line()  # or box.queue_free()
##
## API is intentionally tiny — we'll grow this into a real dialogue
## controller (choices, branching) later.
extends CanvasLayer
class_name DialogueBox

const _PANEL_HEIGHT_PX: int = 92
const _MARGIN_PX: int = 12
## Bottom margin needs to clear the hotbar (HotbarSlot.SLOT_SIZE +
## PlayerHUD.MARGIN ≈ 60) so the dialogue panel doesn't overlap items.
const _HOTBAR_CLEARANCE_PX: int = 72

var _panel: PanelContainer = null
var _speaker_label: Label = null
var _body_label: Label = null
var _hint_label: Label = null
var _open: bool = false


func _ready() -> void:
	layer = 40  # above world (1-2), below cave-fade overlay (50).
	_build()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -_PANEL_HEIGHT_PX - _HOTBAR_CLEARANCE_PX
	_panel.offset_left = _MARGIN_PX
	_panel.offset_right = -_MARGIN_PX
	_panel.offset_bottom = -_HOTBAR_CLEARANCE_PX
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)
	_speaker_label = Label.new()
	_speaker_label.name = "Speaker"
	_speaker_label.add_theme_font_size_override("font_size", 18)
	_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	vb.add_child(_speaker_label)
	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	vb.add_child(_body_label)
	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.text = "[E] close"
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_hint_label)
	_panel.visible = false


## Show `body` attributed to `speaker`. Becomes visible immediately.
func show_line(speaker: String, body: String) -> void:
	if _speaker_label == null:
		return
	_speaker_label.text = speaker
	_body_label.text = body
	_panel.visible = true
	_open = true


## Hide the panel without freeing it (cheap to reopen later).
func hide_line() -> void:
	if _panel != null:
		_panel.visible = false
	_open = false


func is_open() -> bool:
	return _open
