## InventoryScreen
##
## Per-player full-inventory + equipment overlay. Toggled by the player's
## [code]p{N}_inventory[/code] action. While open, that player's
## [InputContext] is set to [code]INVENTORY[/code] so movement input is
## suppressed; closing returns it to [code]GAMEPLAY[/code].
##
## Render layout:
##   - Left column: 5 equipment slots (HEAD, BODY, FEET, WEAPON, TOOL).
##   - Right grid: 4 columns × 6 rows = 24 inventory slots.
##
## The pure helpers [code]build_grid_view[/code] and
## [code]build_equipment_view[/code] are static so they can be unit-tested
## without instantiating the scene.
extends Control
class_name InventoryScreen

const COLS: int = 4
const ROWS: int = 6
const TOTAL_SLOTS: int = COLS * ROWS

const EQUIPMENT_SLOT_ORDER: Array = [
	ItemDefinition.Slot.HEAD,
	ItemDefinition.Slot.BODY,
	ItemDefinition.Slot.FEET,
	ItemDefinition.Slot.WEAPON,
	ItemDefinition.Slot.TOOL,
]

var _player: PlayerController = null
var _inv_slots: Array[HotbarSlot] = []
var _eq_slots: Array[HotbarSlot] = []
var _eq_labels: Array[Label] = []
var _grid: GridContainer = null
var _eq_box: VBoxContainer = null
var _crafting: CraftingPanel = null


# ---------- Pure helpers ----------

## Build a normalised view of the inventory's first [param TOTAL_SLOTS]
## entries. Empty slots are represented as {id: &"", count: 0}.
static func build_grid_view(inv: Inventory) -> Array:
	var out: Array = []
	for i in range(TOTAL_SLOTS):
		if inv == null or i >= inv.size:
			out.append({"id": StringName(), "count": 0})
			continue
		var s = inv.slots[i]
		if s == null:
			out.append({"id": StringName(), "count": 0})
		else:
			out.append({"id": s["id"], "count": int(s["count"])})
	return out


## Build a view of equipment ordered by [code]EQUIPMENT_SLOT_ORDER[/code].
## Returns an Array of {slot: int, id: StringName, count: int}; unequipped
## slots have id == &"".
static func build_equipment_view(eq: Equipment) -> Array:
	var out: Array = []
	for s in EQUIPMENT_SLOT_ORDER:
		var id := StringName()
		if eq != null:
			id = eq.get_equipped(s)
		out.append({"slot": int(s), "id": id, "count": 1 if id != &"" else 0})
	return out


static func slot_label(s: int) -> String:
	match s:
		ItemDefinition.Slot.HEAD: return "Head"
		ItemDefinition.Slot.BODY: return "Body"
		ItemDefinition.Slot.FEET: return "Feet"
		ItemDefinition.Slot.WEAPON: return "Weapon"
		ItemDefinition.Slot.TOOL: return "Tool"
	return "?"


# ---------- Lifecycle ----------

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build()


## Bind this screen to a specific player. Connects to inventory / equipment
## change signals so the view stays current.
func set_player(p: PlayerController) -> void:
	if _player == p:
		return
	if _player != null:
		if _player.inventory != null and _player.inventory.contents_changed.is_connected(_refresh):
			_player.inventory.contents_changed.disconnect(_refresh)
		if _player.equipment != null and _player.equipment.contents_changed.is_connected(_refresh):
			_player.equipment.contents_changed.disconnect(_refresh)
	_player = p
	if _player != null:
		if _player.inventory != null:
			_player.inventory.contents_changed.connect(_refresh)
		if _player.equipment != null:
			_player.equipment.contents_changed.connect(_refresh)
	if _crafting != null:
		_crafting.set_player(_player)
	_refresh()


func _input(_event: InputEvent) -> void:
	if _player == null:
		return
	var action := StringName("p%d_inventory" % (_player.player_id + 1))
	if Input.is_action_just_pressed(action):
		toggle()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if _player == null:
		return
	visible = true
	InputContext.set_context(_player.player_id, InputContext.Context.INVENTORY)
	_refresh()


func close() -> void:
	visible = false
	if _player != null:
		InputContext.set_context(_player.player_id, InputContext.Context.GAMEPLAY)


# ---------- Build / refresh ----------

func _build() -> void:
	# Dim background.
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 380)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	# Left: equipment column.
	_eq_box = VBoxContainer.new()
	_eq_box.add_theme_constant_override("separation", 6)
	hbox.add_child(_eq_box)
	for s in EQUIPMENT_SLOT_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl := Label.new()
		lbl.text = slot_label(s)
		lbl.custom_minimum_size = Vector2(52, 0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lbl)
		var slot := _make_slot()
		row.add_child(slot)
		_eq_box.add_child(row)
		_eq_slots.append(slot)
		_eq_labels.append(lbl)

	# Right: inventory grid.
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	hbox.add_child(_grid)
	for i in range(TOTAL_SLOTS):
		var slot := _make_slot()
		_grid.add_child(slot)
		_inv_slots.append(slot)

	# Far right: crafting panel.
	_crafting = CraftingPanel.new()
	hbox.add_child(_crafting)
	if _player != null:
		_crafting.set_player(_player)


func _make_slot() -> HotbarSlot:
	var slot := HotbarSlot.new()
	slot.custom_minimum_size = Vector2(HotbarSlot.SLOT_SIZE, HotbarSlot.SLOT_SIZE)
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
	if _grid == null or _player == null:
		return
	var inv_view := build_grid_view(_player.inventory)
	for i in range(TOTAL_SLOTS):
		var entry: Dictionary = inv_view[i]
		var slot: HotbarSlot = _inv_slots[i]
		slot.set_item(entry["id"], int(entry["count"]))
	var eq_view := build_equipment_view(_player.equipment)
	for i in range(eq_view.size()):
		var e: Dictionary = eq_view[i]
		var s: HotbarSlot = _eq_slots[i]
		s.set_item(e["id"], int(e["count"]))


# ---------- Test helpers ----------

func get_inv_slots() -> Array[HotbarSlot]:
	return _inv_slots


func get_eq_slots() -> Array[HotbarSlot]:
	return _eq_slots


func get_crafting_panel() -> CraftingPanel:
	return _crafting
