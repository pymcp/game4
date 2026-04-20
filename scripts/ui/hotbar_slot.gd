## HotbarSlot
##
## One cell in the hotbar / inventory grid. Shows the item icon plus a
## stack count badge. Empty slots show nothing.
extends Control
class_name HotbarSlot

const SLOT_SIZE: float = 48.0

var item_id: StringName = &""
var count: int = 0

@onready var _icon: TextureRect = $Icon
@onready var _count_label: Label = $Count
@onready var _bg: ColorRect = $Bg


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_apply_polish()
	_refresh()


func _apply_polish() -> void:
	# Replace plain Bg ColorRect with a Panel using a brown wood
	# StyleBoxFlat (Pixel Adventure UI palette) for a 9-slice feel.
	if _bg == null or not is_instance_valid(_bg):
		return
	var panel := Panel.new()
	panel.name = "BgPanel"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.34, 0.21, 0.13)
	sb.border_color = Color(0.62, 0.42, 0.22)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", sb)
	_bg.add_sibling(panel)
	panel.show_behind_parent = false
	_bg.queue_free()
	_bg = null


## Set the slot's contents. Pass [code]&""[/code] / 0 for an empty slot.
func set_item(id: StringName, n: int) -> void:
	item_id = id
	count = n
	_refresh()


func _refresh() -> void:
	if _icon == null:
		return
	if item_id == &"" or count <= 0:
		_icon.texture = null
		_count_label.text = ""
		return
	var def: ItemDefinition = ItemRegistry.get_item(item_id)
	if def != null and def.icon != null:
		_icon.texture = def.icon
	else:
		_icon.texture = null
	_count_label.text = "%d" % count if count > 1 else ""


## Test helper: returns the current id+count without scene introspection.
func snapshot() -> Dictionary:
	return {"id": item_id, "count": count}
