## InventoryScreen
##
## Per-player full-inventory + equipment overlay. Toggled by the player's
## [code]p{N}_inventory[/code] action. While open, that player's
## [InputContext] is set to [code]INVENTORY[/code] so movement input is
## suppressed; closing returns it to [code]GAMEPLAY[/code].
##
## Render layout:
##   - Left: paperdoll with 5 equipment slots (HEAD, BODY, FEET, WEAPON, TOOL)
##     positioned over a character silhouette.
##   - Centre: 4 × 6 = 24 inventory slots.
##   - Right: crafting panel.
##
## The pure helpers [code]build_grid_view[/code] and
## [code]build_equipment_view[/code] are static so they can be unit-tested
## without instantiating the scene.
extends Control
class_name InventoryScreen

const COLS: int = 4
const ROWS: int = 6
const TOTAL_SLOTS: int = COLS * ROWS
const SLOT_SZ: float = 48.0

const EQUIPMENT_SLOT_ORDER: Array = [
	ItemDefinition.Slot.HEAD,
	ItemDefinition.Slot.BODY,
	ItemDefinition.Slot.FEET,
	ItemDefinition.Slot.WEAPON,
	ItemDefinition.Slot.TOOL,
]

# Fantasy UI colour palette (Pixel Adventure wood tones).
const COL_BG       := Color(0.16, 0.11, 0.09, 0.95)   # Dark panel bg
const COL_FRAME    := Color(0.62, 0.42, 0.22)          # Golden-brown border
const COL_SLOT_BG  := Color(0.22, 0.14, 0.09, 0.85)   # Slot background
const COL_SLOT_BRD := Color(0.50, 0.34, 0.18)          # Slot border
const COL_TITLE_BG := Color(0.34, 0.21, 0.13)          # Title bar
const COL_PARCHMENT := Color(0.28, 0.20, 0.14, 0.60)   # Paperdoll bg
const COL_SILHOUETTE := Color(0.45, 0.34, 0.24, 0.35)  # Body outline
const COL_LABEL    := Color(0.88, 0.82, 0.70)          # Text
const COL_LABEL_DIM := Color(0.55, 0.48, 0.38)         # Dim labels
const COL_TAB_ACTIVE := Color(0.34, 0.21, 0.13)
const COL_TAB_INACTIVE := Color(0.20, 0.14, 0.10)

var _player: PlayerController = null
var _inv_slots: Array[HotbarSlot] = []
var _eq_slots: Array[HotbarSlot] = []
var _eq_labels: Array[Label] = []
var _grid: GridContainer = null
var _paperdoll: Control = null
var _crafting: CraftingPanel = null
var _tab_bar: HBoxContainer = null
var _inv_page: Control = null
var _craft_page: Control = null


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
	dim.color = Color(0, 0, 0, 0.60)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	# Main panel with fantasy frame.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 420)
	panel.add_theme_stylebox_override("panel", _make_frame_style())
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)

	# Title bar.
	var title_bar := _build_title_bar()
	outer.add_child(title_bar)

	# Tab bar.
	_tab_bar = _build_tab_bar()
	outer.add_child(_tab_bar)

	# Content area with margin.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(margin)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	# Left: Paperdoll with positioned equipment slots.
	_paperdoll = _build_paperdoll()
	content.add_child(_paperdoll)

	# Vertical separator.
	content.add_child(_make_vsep())

	# Centre: Inventory grid (swappable page).
	_inv_page = _build_inventory_page()
	content.add_child(_inv_page)

	# Right: Crafting panel (swappable page).
	_craft_page = _build_crafting_page()
	_craft_page.visible = false
	content.add_child(_craft_page)


func _build_title_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TITLE_BG
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	bar.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "Equipment & Inventory"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", COL_LABEL)
	lbl.add_theme_font_size_override("font_size", 16)
	bar.add_child(lbl)
	return bar


func _build_tab_bar() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var tabs: Array = ["Inventory", "Crafting"]
	for i in tabs.size():
		var btn := Button.new()
		btn.text = tabs[i]
		btn.flat = true
		btn.custom_minimum_size = Vector2(100, 28)
		btn.add_theme_color_override("font_color", COL_LABEL)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_stylebox_override("normal", _make_tab_style(i == 0))
		btn.add_theme_stylebox_override("hover", _make_tab_style(true))
		btn.add_theme_stylebox_override("pressed", _make_tab_style(true))
		btn.pressed.connect(_on_tab_pressed.bind(i))
		row.add_child(btn)
	return row


func _on_tab_pressed(idx: int) -> void:
	_inv_page.visible = (idx == 0)
	_craft_page.visible = (idx == 1)
	# Update tab styles.
	for i in _tab_bar.get_child_count():
		var btn: Button = _tab_bar.get_child(i) as Button
		if btn != null:
			btn.add_theme_stylebox_override("normal", _make_tab_style(i == idx))


func _build_paperdoll() -> Control:
	# A fixed-size panel with a character silhouette and equipment slots
	# positioned at the appropriate body locations.
	var doll := Control.new()
	doll.custom_minimum_size = Vector2(180, 300)

	# Parchment background.
	var bg := Panel.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", _make_paperdoll_bg_style())
	doll.add_child(bg)

	# Character silhouette (drawn shapes).
	var silhouette := _build_silhouette()
	doll.add_child(silhouette)

	# Equipment slots positioned over the body.
	# Centre X = 90 (half of 180), slot size = 48.
	var cx: float = 90.0
	var half: float = SLOT_SZ * 0.5
	var positions: Dictionary = {
		ItemDefinition.Slot.HEAD:   Vector2(cx - half, 8.0),
		ItemDefinition.Slot.BODY:   Vector2(cx - half, 72.0),
		ItemDefinition.Slot.FEET:   Vector2(cx - half, 196.0),
		ItemDefinition.Slot.WEAPON: Vector2(10.0, 110.0),
		ItemDefinition.Slot.TOOL:   Vector2(180.0 - SLOT_SZ - 10.0, 110.0),
	}

	for s in EQUIPMENT_SLOT_ORDER:
		var slot := _make_slot()
		var pos: Vector2 = positions.get(s, Vector2.ZERO)
		slot.position = pos
		doll.add_child(slot)
		_eq_slots.append(slot)

		# Small label below slot.
		var lbl := Label.new()
		lbl.text = slot_label(s)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", COL_LABEL_DIM)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(pos.x - 4.0, pos.y + SLOT_SZ + 1.0)
		lbl.custom_minimum_size = Vector2(SLOT_SZ + 8.0, 0)
		doll.add_child(lbl)
		_eq_labels.append(lbl)

	return doll


func _build_silhouette() -> Control:
	# A simple stylised body outline using overlapping ColorRects.
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cx: float = 90.0

	# Head circle (approximated as rounded rect).
	root.add_child(_silhouette_part(cx - 14.0, 18.0, 28.0, 28.0, 14))
	# Neck.
	root.add_child(_silhouette_part(cx - 5.0, 44.0, 10.0, 12.0, 2))
	# Torso.
	root.add_child(_silhouette_part(cx - 24.0, 54.0, 48.0, 80.0, 6))
	# Left arm.
	root.add_child(_silhouette_part(cx - 38.0, 60.0, 16.0, 64.0, 4))
	# Right arm.
	root.add_child(_silhouette_part(cx + 22.0, 60.0, 16.0, 64.0, 4))
	# Left hand.
	root.add_child(_silhouette_part(cx - 36.0, 120.0, 12.0, 12.0, 6))
	# Right hand.
	root.add_child(_silhouette_part(cx + 24.0, 120.0, 12.0, 12.0, 6))
	# Left leg.
	root.add_child(_silhouette_part(cx - 18.0, 132.0, 16.0, 72.0, 4))
	# Right leg.
	root.add_child(_silhouette_part(cx + 2.0, 132.0, 16.0, 72.0, 4))
	# Left foot.
	root.add_child(_silhouette_part(cx - 22.0, 200.0, 20.0, 10.0, 3))
	# Right foot.
	root.add_child(_silhouette_part(cx + 2.0, 200.0, 20.0, 10.0, 3))
	return root


func _silhouette_part(x: float, y: float, w: float, h: float,
		corner: int) -> Panel:
	var p := Panel.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_SILHOUETTE
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	p.add_theme_stylebox_override("panel", sb)
	return p


func _build_inventory_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header := Label.new()
	header.text = "Backpack"
	header.add_theme_color_override("font_color", COL_LABEL)
	header.add_theme_font_size_override("font_size", 13)
	page.add_child(header)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	page.add_child(_grid)
	for i in range(TOTAL_SLOTS):
		var slot := _make_slot()
		_grid.add_child(slot)
		_inv_slots.append(slot)

	return page


func _build_crafting_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_crafting = CraftingPanel.new()
	page.add_child(_crafting)
	if _player != null:
		_crafting.set_player(_player)
	return page


func _make_vsep() -> Panel:
	var sep := Panel.new()
	sep.custom_minimum_size = Vector2(2, 0)
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_FRAME.darkened(0.3)
	sep.add_theme_stylebox_override("panel", sb)
	return sep


func _make_slot() -> HotbarSlot:
	var slot := HotbarSlot.new()
	slot.custom_minimum_size = Vector2(SLOT_SZ, SLOT_SZ)
	# Background — uses HotbarSlot's _apply_polish() but we provide
	# a Bg child with our fantasy colours so it gets upgraded.
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = COL_SLOT_BG
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
	count_label.add_theme_color_override("font_color", COL_LABEL)
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count_label)
	return slot


# ---------- Style helpers ----------

func _make_frame_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.border_color = COL_FRAME
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	return sb


func _make_paperdoll_bg_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PARCHMENT
	sb.border_color = COL_FRAME.darkened(0.2)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb


func _make_tab_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TAB_ACTIVE if active else COL_TAB_INACTIVE
	sb.border_color = COL_FRAME if active else COL_FRAME.darkened(0.3)
	sb.border_width_bottom = 2 if active else 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	return sb


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
