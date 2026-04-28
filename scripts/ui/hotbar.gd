## Hotbar
##
## Horizontal row of [HotbarSlot] cells showing the first N slots of an
## [Inventory]. Subscribes to [signal Inventory.contents_changed] to refresh
## automatically.
extends Control
class_name Hotbar

const DEFAULT_VISIBLE_SLOTS: int = 10

@export var visible_slots: int = DEFAULT_VISIBLE_SLOTS

var _inventory: Inventory = null

var _row: HBoxContainer = null


## Pure helper: build a view-model of the first [param n] inventory slots.
## Returns an Array of {id: StringName, count: int} entries; empty slots are
## represented as {id: &"", count: 0}.
static func build_view(inv: Inventory, n: int) -> Array:
	var out: Array = []
	for i in range(n):
		if inv == null or i >= inv.size:
			out.append({"id": StringName(), "count": 0})
			continue
		var s: Variant = inv.slots[i]
		if s == null:
			out.append({"id": StringName(), "count": 0})
		else:
			out.append({"id": s["id"], "count": int(s["count"])})
	return out


func _ready() -> void:
	_row = get_node_or_null("Row") as HBoxContainer
	focus_mode = Control.FOCUS_NONE
	_ensure_slot_nodes()
	_refresh()


func set_inventory(inv: Inventory) -> void:
	if _inventory == inv:
		return
	if _inventory != null and _inventory.contents_changed.is_connected(_refresh):
		_inventory.contents_changed.disconnect(_refresh)
	_inventory = inv
	if _inventory != null:
		_inventory.contents_changed.connect(_refresh)
	_refresh()


func _ensure_slot_nodes() -> void:
	if _row == null:
		return
	while _row.get_child_count() < visible_slots:
		_row.add_child(_make_slot())
	while _row.get_child_count() > visible_slots:
		var c: Node = _row.get_child(_row.get_child_count() - 1)
		_row.remove_child(c)
		c.queue_free()


func _make_slot() -> HotbarSlot:
	var slot := HotbarSlot.new()
	slot.name = "Slot%d" % _row.get_child_count()
	# Programmatically build the inner texture/label without a packed scene.
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0, 0, 0, 0.45)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	var count_label := Label.new()
	count_label.name = "Count"
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 1.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count_label)
	return slot


func _refresh() -> void:
	if _row == null:
		return
	var view := build_view(_inventory, visible_slots)
	for i in range(visible_slots):
		var entry: Dictionary = view[i]
		var slot: HotbarSlot = _row.get_child(i) as HotbarSlot
		if slot != null:
			slot.set_item(entry["id"], int(entry["count"]))
