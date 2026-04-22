## InventoryScreen
##
## Per-player full-inventory + equipment overlay. Toggled by the player's
## [code]p{N}_inventory[/code] action. While open, that player's
## [InputContext] is set to [code]INVENTORY[/code] so movement input is
## suppressed; closing returns it to [code]GAMEPLAY[/code].
##
## Layout (inspired by classic RPG menus):
##   - Left: vertical category tabs (Equipment, All, Weapons, Armor, Tools,
##     Materials, Crafting).
##   - Right: content area that changes per tab (paperdoll, item grid, or
##     crafting panel).
##   - Bottom: control hints bar.
##
## Keyboard navigation: arrow keys move a cursor in the grid / tab list,
## interact equips/uses, attack key drops, tab keys cycle categories.
##
## The pure helpers [code]build_grid_view[/code] and
## [code]build_equipment_view[/code] are static so they can be unit-tested
## without instantiating the scene.
extends Control
class_name InventoryScreen

const COLS: int = 6
const ROWS: int = 5
const TOTAL_SLOTS: int = COLS * ROWS
const SLOT_SZ: float = 48.0

const EQUIPMENT_SLOT_ORDER: Array = [
	ItemDefinition.Slot.HEAD,
	ItemDefinition.Slot.BODY,
	ItemDefinition.Slot.FEET,
	ItemDefinition.Slot.WEAPON,
	ItemDefinition.Slot.TOOL,
]

enum Tab { EQUIPMENT, ALL, WEAPONS, ARMOR, TOOLS, MATERIALS, CRAFTING }

const TAB_LABELS: Array = [
	"Equipment",
	"All Items",
	"Weapons",
	"Armor",
	"Tools",
	"Materials",
	"Crafting",
]

# Slot filter: which ItemDefinition.Slot values are shown per tab.
# null means "show all".
const TAB_SLOT_FILTER: Dictionary = {
	Tab.ALL: null,
	Tab.WEAPONS: [ItemDefinition.Slot.WEAPON],
	Tab.ARMOR: [ItemDefinition.Slot.HEAD, ItemDefinition.Slot.BODY, ItemDefinition.Slot.FEET],
	Tab.TOOLS: [ItemDefinition.Slot.TOOL],
	Tab.MATERIALS: [ItemDefinition.Slot.NONE],
}

# Fantasy UI colour palette (Pixel Adventure wood tones).
const COL_BG        := Color(0.16, 0.11, 0.09, 0.95)
const COL_FRAME     := Color(0.62, 0.42, 0.22)
const COL_SLOT_BG   := Color(0.22, 0.14, 0.09, 0.85)
const COL_SLOT_BRD  := Color(0.50, 0.34, 0.18)
const COL_TITLE_BG  := Color(0.34, 0.21, 0.13)
const COL_PARCHMENT := Color(0.28, 0.20, 0.14, 0.60)
const COL_SILHOUETTE := Color(0.45, 0.34, 0.24, 0.35)
const COL_LABEL     := Color(0.88, 0.82, 0.70)
const COL_LABEL_DIM := Color(0.55, 0.48, 0.38)
const COL_TAB_ACTIVE   := Color(0.34, 0.21, 0.13)
const COL_TAB_INACTIVE := Color(0.20, 0.14, 0.10)
const COL_CURSOR    := Color(0.95, 0.85, 0.45, 0.9)

var _player: PlayerController = null
var _current_tab: int = Tab.ALL

# UI refs
var _tab_buttons: Array[Button] = []
var _tab_column: VBoxContainer = null
var _content_stack: Control = null
var _eq_page: Control = null
var _grid_page: VBoxContainer = null
var _craft_page: VBoxContainer = null
var _inv_slots: Array[HotbarSlot] = []
var _eq_slots: Array[HotbarSlot] = []
var _eq_labels: Array[Label] = []
var _grid: GridContainer = null
var _paperdoll: Control = null
var _crafting: CraftingPanel = null
var _detail_label: Label = null
var _controls_bar: PanelContainer = null
var _controls_label: RichTextLabel = null

# Cursor state (index into current visible slots).
var _cursor: int = 0
var _cursor_panel: Panel = null
# Filtered view: array of {id, count, inv_index} for current tab.
var _filtered_view: Array = []


# ---------- Pure helpers ----------

## Build a normalised view of the inventory's first [param TOTAL_SLOTS]
## entries. Empty slots are represented as {id: &"", count: 0}.
static func build_grid_view(inv: Inventory) -> Array:
	var out: Array = []
	for i in range(inv.size if inv != null else 0):
		if inv == null:
			out.append({"id": StringName(), "count": 0})
			continue
		var s = inv.slots[i]
		if s == null:
			out.append({"id": StringName(), "count": 0})
		else:
			out.append({"id": s["id"], "count": int(s["count"])})
	return out


## Build a view of equipment ordered by [code]EQUIPMENT_SLOT_ORDER[/code].
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


func _input(event: InputEvent) -> void:
	if _player == null:
		return
	var prefix: String = "p%d_" % (_player.player_id + 1)

	# Toggle open/close — always check this action.
	if Input.is_action_just_pressed(StringName(prefix + "inventory")):
		toggle()
		get_viewport().set_input_as_handled()
		return

	# When open, consume ALL input events so nothing leaks to gameplay.
	if not visible:
		return
	get_viewport().set_input_as_handled()

	# Only handle key-down events for navigation.
	if event is InputEventKey and not event.pressed:
		return

	# Tab cycling.
	if Input.is_action_just_pressed(StringName(prefix + "tab_prev")):
		_cycle_tab(-1)
		return
	if Input.is_action_just_pressed(StringName(prefix + "tab_next")):
		_cycle_tab(1)
		return

	# Cursor navigation (arrow keys).
	if Input.is_action_just_pressed(StringName(prefix + "up")):
		_move_cursor(0, -1)
		return
	if Input.is_action_just_pressed(StringName(prefix + "down")):
		_move_cursor(0, 1)
		return
	if Input.is_action_just_pressed(StringName(prefix + "left")):
		_move_cursor(-1, 0)
		return
	if Input.is_action_just_pressed(StringName(prefix + "right")):
		_move_cursor(1, 0)
		return

	# Interact — equip / use.
	if Input.is_action_just_pressed(StringName(prefix + "interact")):
		_interact_cursor()
		return

	# Attack key — drop in inventory context.
	if Input.is_action_just_pressed(StringName(prefix + "attack")):
		_drop_cursor()
		return


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
	_cursor = 0
	_select_tab(Tab.ALL)
	_refresh()


func close() -> void:
	visible = false
	if _player != null:
		InputContext.set_context(_player.player_id, InputContext.Context.GAMEPLAY)


# ---------- Build ----------

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
	panel.custom_minimum_size = Vector2(720, 460)
	panel.add_theme_stylebox_override("panel", _make_frame_style())
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)

	# Title bar.
	outer.add_child(_build_title_bar())

	# Main content: vertical tabs (left) | content area (right).
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 0)
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(content_row)

	# Left: vertical tab column.
	_tab_column = _build_tab_column()
	content_row.add_child(_tab_column)

	# Separator.
	content_row.add_child(_make_vsep())

	# Right: content stack (only one child visible at a time).
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(content_margin)

	_content_stack = Control.new()
	_content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(_content_stack)

	# Build all content pages.
	_eq_page = _build_equipment_page()
	_eq_page.visible = false
	_content_stack.add_child(_eq_page)

	_grid_page = _build_grid_page()
	_content_stack.add_child(_grid_page)

	_craft_page = _build_crafting_page()
	_craft_page.visible = false
	_content_stack.add_child(_craft_page)

	# Bottom: controls hint bar.
	_controls_bar = _build_controls_bar()
	outer.add_child(_controls_bar)


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


func _build_tab_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.custom_minimum_size = Vector2(120, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	margin.add_child(inner)

	for i in Tab.values().size():
		var is_default: bool = (i == Tab.ALL)
		var btn := Button.new()
		btn.text = TAB_LABELS[i]
		btn.flat = true
		btn.custom_minimum_size = Vector2(108, 30)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_color_override("font_color", Color.WHITE if is_default else COL_LABEL_DIM)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_stylebox_override("normal", _make_vtab_style(is_default))
		btn.add_theme_stylebox_override("hover", _make_vtab_style(true))
		btn.add_theme_stylebox_override("pressed", _make_vtab_style(true))
		btn.pressed.connect(_on_tab_button.bind(i))
		inner.add_child(btn)
		_tab_buttons.append(btn)

	return col


func _build_grid_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.anchor_right = 1.0
	page.anchor_bottom = 1.0

	# Grid of slots.
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	page.add_child(_grid)

	for i in range(TOTAL_SLOTS):
		var slot := _make_slot()
		_grid.add_child(slot)
		_inv_slots.append(slot)

	# Cursor highlight (overlaid on the selected slot).
	_cursor_panel = Panel.new()
	_cursor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_panel.size = Vector2(SLOT_SZ, SLOT_SZ)
	_cursor_panel.add_theme_stylebox_override("panel", _make_cursor_style())
	_cursor_panel.z_index = 10
	page.add_child(_cursor_panel)

	# Detail label below grid.
	_detail_label = Label.new()
	_detail_label.add_theme_color_override("font_color", COL_LABEL_DIM)
	_detail_label.add_theme_font_size_override("font_size", 12)
	_detail_label.text = "(empty)"
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_detail_label)

	return page


func _build_equipment_page() -> HBoxContainer:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.anchor_right = 1.0
	page.anchor_bottom = 1.0

	_paperdoll = _build_paperdoll()
	page.add_child(_paperdoll)
	return page


func _build_paperdoll() -> Control:
	var doll := Control.new()
	doll.custom_minimum_size = Vector2(180, 300)

	var bg := Panel.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", _make_paperdoll_bg_style())
	doll.add_child(bg)

	var silhouette := _build_silhouette()
	doll.add_child(silhouette)

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
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cx: float = 90.0
	root.add_child(_silhouette_part(cx - 14.0, 18.0, 28.0, 28.0, 14))
	root.add_child(_silhouette_part(cx - 5.0, 44.0, 10.0, 12.0, 2))
	root.add_child(_silhouette_part(cx - 24.0, 54.0, 48.0, 80.0, 6))
	root.add_child(_silhouette_part(cx - 38.0, 60.0, 16.0, 64.0, 4))
	root.add_child(_silhouette_part(cx + 22.0, 60.0, 16.0, 64.0, 4))
	root.add_child(_silhouette_part(cx - 36.0, 120.0, 12.0, 12.0, 6))
	root.add_child(_silhouette_part(cx + 24.0, 120.0, 12.0, 12.0, 6))
	root.add_child(_silhouette_part(cx - 18.0, 132.0, 16.0, 72.0, 4))
	root.add_child(_silhouette_part(cx + 2.0, 132.0, 16.0, 72.0, 4))
	root.add_child(_silhouette_part(cx - 22.0, 200.0, 20.0, 10.0, 3))
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


func _build_crafting_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.anchor_right = 1.0
	page.anchor_bottom = 1.0
	_crafting = CraftingPanel.new()
	page.add_child(_crafting)
	if _player != null:
		_crafting.set_player(_player)
	return page


func _build_controls_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TITLE_BG
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("panel", sb)

	_controls_label = RichTextLabel.new()
	_controls_label.bbcode_enabled = true
	_controls_label.fit_content = true
	_controls_label.scroll_active = false
	_controls_label.custom_minimum_size = Vector2(0, 18)
	_controls_label.add_theme_font_size_override("normal_font_size", 13)
	_controls_label.add_theme_color_override("default_color", COL_LABEL_DIM)
	bar.add_child(_controls_label)

	_update_controls_text()
	return bar


func _update_controls_text() -> void:
	if _controls_label == null or _player == null:
		return
	var prefix: String = "p%d_" % (_player.player_id + 1)
	var interact_key := InputContext.get_key_label(StringName(prefix + "interact"))
	var attack_key := InputContext.get_key_label(StringName(prefix + "attack"))
	var tab_prev := InputContext.get_key_label(StringName(prefix + "tab_prev"))
	var tab_next := InputContext.get_key_label(StringName(prefix + "tab_next"))
	var inv_key := InputContext.get_key_label(StringName(prefix + "inventory"))
	_controls_label.text = "[center][color=white][%s][/color] Equip/Use   [color=white][%s][/color] Drop   [color=white][%s/%s][/color] Tab   [color=white][%s][/color] Close[/center]" % [
		interact_key, attack_key, tab_prev, tab_next, inv_key]


# ---------- Tab management ----------

func _on_tab_button(tab_idx: int) -> void:
	_select_tab(tab_idx)


func _select_tab(tab_idx: int) -> void:
	_current_tab = tab_idx
	# Update button styles and text color.
	for i in _tab_buttons.size():
		var active: bool = (i == tab_idx)
		_tab_buttons[i].add_theme_stylebox_override("normal",
			_make_vtab_style(active))
		_tab_buttons[i].add_theme_color_override("font_color",
			Color.WHITE if active else COL_LABEL_DIM)

	# Show the appropriate content page.
	_eq_page.visible = (tab_idx == Tab.EQUIPMENT)
	_grid_page.visible = (tab_idx != Tab.EQUIPMENT and tab_idx != Tab.CRAFTING)
	_craft_page.visible = (tab_idx == Tab.CRAFTING)

	_cursor = 0
	_refresh()


func _cycle_tab(dir: int) -> void:
	var total: int = Tab.values().size()
	_select_tab(posmod(_current_tab + dir, total))


# ---------- Cursor navigation ----------

func _move_cursor(dx: int, dy: int) -> void:
	if _current_tab == Tab.EQUIPMENT:
		# Navigate equipment slots (5 slots, vertical list).
		_cursor = clampi(_cursor + dy + dx, 0, EQUIPMENT_SLOT_ORDER.size() - 1)
		_refresh_cursor()
		return
	if _current_tab == Tab.CRAFTING:
		return

	# Grid navigation.
	var total: int = _filtered_view.size()
	if total == 0:
		return
	var col: int = _cursor % COLS
	var row: int = _cursor / COLS
	col = clampi(col + dx, 0, COLS - 1)
	row = clampi(row + dy, 0, (total - 1) / COLS)
	var new_idx: int = row * COLS + col
	_cursor = clampi(new_idx, 0, total - 1)
	_refresh_cursor()


func _refresh_cursor() -> void:
	if _current_tab == Tab.EQUIPMENT:
		# Highlight the equipment slot.
		if _cursor >= 0 and _cursor < _eq_slots.size():
			var slot: HotbarSlot = _eq_slots[_cursor]
			_cursor_panel.visible = true
			_cursor_panel.global_position = slot.global_position
			_cursor_panel.size = slot.size
		_update_detail_equipment()
		return

	if _current_tab == Tab.CRAFTING:
		_cursor_panel.visible = false
		_detail_label.text = ""
		return

	# Grid cursor.
	if _cursor >= 0 and _cursor < _inv_slots.size():
		var slot: HotbarSlot = _inv_slots[_cursor]
		if slot.is_inside_tree():
			_cursor_panel.visible = true
			# Position relative to grid_page so it overlays correctly.
			_cursor_panel.global_position = slot.global_position
			_cursor_panel.size = slot.size
		else:
			_cursor_panel.visible = false
	else:
		_cursor_panel.visible = false

	# Update detail text.
	if _cursor >= 0 and _cursor < _filtered_view.size():
		var entry: Dictionary = _filtered_view[_cursor]
		if entry["id"] != &"":
			var def: ItemDefinition = ItemRegistry.get_item(entry["id"])
			if def != null:
				var desc: String = def.description if def.description != "" else "(no description)"
				_detail_label.text = "%s — %s" % [def.display_name, desc]
			else:
				_detail_label.text = String(entry["id"])
		else:
			_detail_label.text = "(empty)"
	else:
		_detail_label.text = "(empty)"


func _update_detail_equipment() -> void:
	if _detail_label == null:
		return
	if _cursor < 0 or _cursor >= EQUIPMENT_SLOT_ORDER.size():
		return
	var slot_type: int = EQUIPMENT_SLOT_ORDER[_cursor]
	var slot_name: String = slot_label(slot_type)
	if _player == null or _player.equipment == null:
		_detail_label.text = "%s — (empty)" % slot_name
		return
	var equipped_id: StringName = _player.equipment.get_equipped(slot_type)
	if equipped_id == &"":
		_detail_label.text = "%s — (empty)" % slot_name
		return
	var def: ItemDefinition = ItemRegistry.get_item(equipped_id)
	if def != null:
		_detail_label.text = "%s — %s" % [slot_name, def.display_name]
	else:
		_detail_label.text = "%s — %s" % [slot_name, String(equipped_id)]


# ---------- Interact / Drop ----------

func _interact_cursor() -> void:
	if _player == null:
		return
	if _current_tab == Tab.EQUIPMENT:
		# Unequip the selected slot.
		if _cursor >= 0 and _cursor < EQUIPMENT_SLOT_ORDER.size():
			var slot_type: int = EQUIPMENT_SLOT_ORDER[_cursor]
			var eq_id: StringName = _player.equipment.get_equipped(slot_type)
			if eq_id != &"":
				_player.equipment.unequip(slot_type)
				_player.inventory.add(eq_id, 1)
		return

	if _current_tab == Tab.CRAFTING:
		return

	# Equip the item under cursor.
	if _cursor < 0 or _cursor >= _filtered_view.size():
		return
	var entry: Dictionary = _filtered_view[_cursor]
	if entry["id"] == &"":
		return
	var def: ItemDefinition = ItemRegistry.get_item(entry["id"])
	if def == null or def.slot == ItemDefinition.Slot.NONE:
		return
	# Equip: remove from inventory, put in equipment slot.
	var inv_idx: int = entry.get("inv_index", -1)
	if inv_idx < 0:
		return
	var taken: Variant = _player.inventory.take_slot(inv_idx)
	if taken == null:
		return
	# If something is already equipped in that slot, unequip it first.
	var prev: StringName = _player.equipment.get_equipped(def.slot)
	if prev != &"":
		_player.equipment.unequip(def.slot)
		_player.inventory.add(prev, 1)
	_player.equipment.equip(def.slot, entry["id"])


func _drop_cursor() -> void:
	if _player == null:
		return
	if _current_tab == Tab.EQUIPMENT:
		# Drop equipped item.
		if _cursor >= 0 and _cursor < EQUIPMENT_SLOT_ORDER.size():
			var slot_type: int = EQUIPMENT_SLOT_ORDER[_cursor]
			var eq_id: StringName = _player.equipment.get_equipped(slot_type)
			if eq_id != &"":
				_player.equipment.unequip(slot_type)
				_spawn_loot_pickup(eq_id, 1)
		return

	if _current_tab == Tab.CRAFTING:
		return

	# Drop one from the inventory slot under cursor.
	if _cursor < 0 or _cursor >= _filtered_view.size():
		return
	var entry: Dictionary = _filtered_view[_cursor]
	if entry["id"] == &"":
		return
	var inv_idx: int = entry.get("inv_index", -1)
	if inv_idx >= 0:
		_player.inventory.remove(entry["id"], 1)
		_spawn_loot_pickup(entry["id"], 1)


## Place a LootPickup entity near the player in the world.
func _spawn_loot_pickup(id: StringName, amount: int) -> void:
	if _player == null or _player._world == null:
		return
	var pickup := LootPickup.new()
	pickup.item_id = id
	pickup.count = amount
	# Offset slightly in front of the player so it doesn't auto-pickup instantly.
	var offset := Vector2(_player._facing_x * 18, 0)
	pickup.position = _player.position + offset
	_player._world.entities.add_child(pickup)


# ---------- Refresh ----------

func _refresh() -> void:
	if _grid == null or _player == null:
		return

	# Refresh equipment slots.
	var eq_view := build_equipment_view(_player.equipment)
	for i in range(eq_view.size()):
		if i < _eq_slots.size():
			var e: Dictionary = eq_view[i]
			_eq_slots[i].set_item(e["id"], int(e["count"]))

	# Build filtered inventory view for current tab.
	_build_filtered_view()

	# Populate grid slots.
	for i in range(TOTAL_SLOTS):
		if i < _filtered_view.size():
			var e: Dictionary = _filtered_view[i]
			_inv_slots[i].set_item(e["id"], int(e["count"]))
			_inv_slots[i].visible = true
		else:
			_inv_slots[i].set_item(&"", 0)
			_inv_slots[i].visible = true  # Show empty slots up to grid capacity.

	# Clamp cursor.
	var max_cursor: int = maxi(_filtered_view.size() - 1, 0)
	_cursor = clampi(_cursor, 0, max_cursor)
	_refresh_cursor()
	_update_controls_text()


func _build_filtered_view() -> void:
	_filtered_view.clear()
	if _player == null or _player.inventory == null:
		return

	var filter: Variant = TAB_SLOT_FILTER.get(_current_tab, null)
	for i in range(_player.inventory.size):
		var s: Variant = _player.inventory.slots[i]
		if s == null:
			if filter == null:
				# "All" tab: show empty slots to fill the grid.
				_filtered_view.append({"id": StringName(), "count": 0, "inv_index": i})
			continue
		var item_id: StringName = s["id"]
		var cnt: int = int(s["count"])
		if filter == null:
			# "All" tab: show everything.
			_filtered_view.append({"id": item_id, "count": cnt, "inv_index": i})
			continue
		# Check if item's slot matches the filter.
		var def: ItemDefinition = ItemRegistry.get_item(item_id)
		if def == null:
			continue
		var slot_val: int = int(def.slot)
		if slot_val in filter:
			_filtered_view.append({"id": item_id, "count": cnt, "inv_index": i})


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


func _make_vtab_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TAB_ACTIVE if active else COL_TAB_INACTIVE
	sb.border_color = COL_FRAME if active else COL_FRAME.darkened(0.3)
	sb.border_width_left = 4 if active else 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	if active:
		sb.border_color = Color(0.95, 0.80, 0.40)  # Gold accent on left edge.
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	sb.corner_radius_top_left = 3
	sb.corner_radius_bottom_left = 3
	return sb


func _make_cursor_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = COL_CURSOR
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _make_slot() -> HotbarSlot:
	var slot := HotbarSlot.new()
	slot.custom_minimum_size = Vector2(SLOT_SZ, SLOT_SZ)
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


func _make_vsep() -> Panel:
	var sep := Panel.new()
	sep.custom_minimum_size = Vector2(2, 0)
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_FRAME.darkened(0.3)
	sep.add_theme_stylebox_override("panel", sb)
	return sep


# ---------- Test helpers ----------

func get_inv_slots() -> Array[HotbarSlot]:
	return _inv_slots


func get_eq_slots() -> Array[HotbarSlot]:
	return _eq_slots


func get_crafting_panel() -> CraftingPanel:
	return _crafting
