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
var _bg_panel: Panel = null
static var _DEFAULT_BORDER: Color:
	get: return UITheme.COL_FRAME


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_apply_polish()
	_refresh()


func _apply_polish() -> void:
	if _bg == null or not is_instance_valid(_bg):
		return
	var panel := Panel.new()
	panel.name = "BgPanel"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Duplicate the theme stylebox so rarity can modify border color per-instance
	# without mutating the shared Theme resource.
	var base_sb: StyleBoxFlat = get_theme_stylebox(&"panel", &"SlotPanel") as StyleBoxFlat
	var sb: StyleBoxFlat
	if base_sb != null:
		sb = base_sb.duplicate() as StyleBoxFlat
	else:
		# Fallback if theme not yet loaded (e.g. headless unit tests).
		sb = StyleBoxFlat.new()
		sb.bg_color = UITheme.COL_SLOT_BG
		sb.border_color = UITheme.COL_SLOT_BRD
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
	_bg.queue_free()
	_bg = null
	_bg_panel = panel


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
		_update_border_color(null)
		return
	var def: ItemDefinition = ItemRegistry.get_item(item_id)
	if def != null and def.icon != null:
		_icon.texture = def.icon
	else:
		_icon.texture = null
	_count_label.text = "%d" % count if count > 1 else ""
	_update_border_color(def)


func _update_border_color(def: ItemDefinition) -> void:
	if _bg_panel == null:
		return
	var sb: StyleBoxFlat = _bg_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	if def == null or def.rarity == ItemDefinition.Rarity.COMMON:
		sb.border_color = _DEFAULT_BORDER
	else:
		sb.border_color = ItemDefinition.RARITY_COLORS.get(def.rarity, _DEFAULT_BORDER)


## Test helper: returns the current id+count without scene introspection.
func snapshot() -> Dictionary:
	return {"id": item_id, "count": count}
