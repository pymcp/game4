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
const SLOT_SZ: float = UITheme.SLOT_SZ

const EQUIPMENT_SLOT_ORDER: Array = [
	ItemDefinition.Slot.HEAD,
	ItemDefinition.Slot.BODY,
	ItemDefinition.Slot.FEET,
	ItemDefinition.Slot.WEAPON,
	ItemDefinition.Slot.OFF_HAND,
	ItemDefinition.Slot.TOOL,
]

enum Tab { ALL, WEAPONS, ARMOR, TOOLS, MATERIALS, CHARACTER }

const TAB_LABELS: Array = [
	"All Items",
	"Weapons",
	"Armor",
	"Tools",
	"Materials",
	"Character",
]

# Slot filter: which ItemDefinition.Slot values are shown per tab.
# null means "show all".
const TAB_SLOT_FILTER: Dictionary = {
	Tab.ALL: null,
	Tab.WEAPONS: [ItemDefinition.Slot.WEAPON],
	Tab.ARMOR: [ItemDefinition.Slot.HEAD, ItemDefinition.Slot.BODY, ItemDefinition.Slot.FEET, ItemDefinition.Slot.OFF_HAND],
	Tab.TOOLS: [ItemDefinition.Slot.TOOL],
	Tab.MATERIALS: [ItemDefinition.Slot.NONE],
}


var _player: PlayerController = null
var _current_tab: int = Tab.ALL

# UI refs
var _tab_buttons: Array[Button] = []
var _tab_column: VBoxContainer = null
var _content_stack: Control = null
var _grid_page: VBoxContainer = null
var _inv_slots: Array[HotbarSlot] = []
var _eq_slots: Array[HotbarSlot] = []
var _eq_labels: Array[Label] = []
var _grid: GridContainer = null
var _grid_scroll: ScrollContainer = null
var _paperdoll: Control = null
var _char_page: VBoxContainer = null
var _char_preview_root: Node2D = null
var _char_preview_viewport: SubViewport = null
var _char_preview_rect: TextureRect = null
var _char_row_labels: Array[Label] = []
var _char_value_labels: Array[Label] = []
var _char_cursor: int = 0
var _char_opts: Dictionary = {}
var _char_stats_container: VBoxContainer = null
var _char_xp_bar: XpBar = null
var _char_stat_value_labels: Dictionary = {}   # StringName stat -> Label
var _char_stat_plus_buttons: Dictionary = {}   # StringName stat -> Button
var _char_pending_label: Label = null
var _char_passives_label: Label = null
var _detail_label: Label = null
var _detail_name_label: Label = null
var _detail_desc_label: Label = null
var _detail_meta_label: Label = null
var _tooltip_label: Label = null
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
		ItemDefinition.Slot.OFF_HAND: return "Off-Hand"
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
	_refresh()


func _input(event: InputEvent) -> void:
	if _player == null:
		return
	# Toggle open/close — always check this action.
	if Input.is_action_just_pressed(PlayerActions.action(_player.player_id, PlayerActions.INVENTORY)):
		toggle()
		get_viewport().set_input_as_handled()
		return

	# When open, consume input events for THIS player so nothing leaks to
	# gameplay — but don't eat the other player's inputs.
	if not visible:
		return
	if not _is_my_event(event):
		return
	get_viewport().set_input_as_handled()

	# Only handle key-down events for navigation.
	if event is InputEventKey and not event.pressed:
		return

	# Tab cycling.
	if Input.is_action_just_pressed(PlayerActions.action(_player.player_id, PlayerActions.TAB_PREV)):
		_cycle_tab(-1)
		return
	if Input.is_action_just_pressed(PlayerActions.action(_player.player_id, PlayerActions.TAB_NEXT)):
		_cycle_tab(1)
		return

	# Cursor navigation (arrow keys).
	if Input.is_action_just_pressed(PlayerActions.action(_player.player_id, PlayerActions.UP)):
		_move_cursor(0, -1)
		return
	if Input.is_action_just_pressed(PlayerActions.action(_player.player_id, PlayerActions.DOWN)):
		_move_cursor(0, 1)
		return
	if Input.is_action_just_pressed(PlayerActions.action(_player.player_id, PlayerActions.LEFT)):
		_move_cursor(-1, 0)
		return
	if Input.is_action_just_pressed(PlayerActions.action(_player.player_id, PlayerActions.RIGHT)):
		_move_cursor(1, 0)
		return

	# Interact — equip / use.
	if Input.is_action_just_pressed(PlayerActions.action(_player.player_id, PlayerActions.INTERACT)):
		_interact_cursor()
		return

	# Back key — drop in inventory context.
	if Input.is_action_just_pressed(PlayerActions.action(_player.player_id, PlayerActions.BACK)):
		_drop_cursor()
		return


## True if [param event] matches any action bound to this player's prefix.
func _is_my_event(event: InputEvent) -> bool:
	var actions := InputContext.get_active_actions(_player.player_id)
	# Also include inventory toggle which is always checked.
	actions.append(PlayerActions.action(_player.player_id, PlayerActions.INVENTORY))
	for action in actions:
		if event.is_action(action):
			return true
	return false


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
	if _current_tab == Tab.CHARACTER:
		_apply_char_opts_to_player()
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

	# Main panel with fantasy frame — 90% viewport height, horizontally centred.
	var panel := PanelContainer.new()
	panel.anchor_top = 0.05
	panel.anchor_bottom = 0.95
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -440.0
	panel.offset_right = 440.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(880, 0)
	panel.theme_type_variation = &"WoodPanel"
	add_child(panel)

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
	var vsep := Panel.new()
	vsep.custom_minimum_size = Vector2(2, 0)
	vsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vsep.theme_type_variation = &"WoodSep"
	content_row.add_child(vsep)

	# Middle: content stack (only one child visible at a time).
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

	# Build content pages (no Equipment page — doll is always visible at right).
	_grid_page = _build_grid_page()
	_content_stack.add_child(_grid_page)

	_char_page = _build_character_page()
	_char_page.visible = false
	_content_stack.add_child(_char_page)

	# Right separator.
	var rsep := Panel.new()
	rsep.custom_minimum_size = Vector2(2, 0)
	rsep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rsep.theme_type_variation = &"WoodSep"
	content_row.add_child(rsep)

	# Right column: permanent paper doll.
	var doll_margin := MarginContainer.new()
	doll_margin.add_theme_constant_override("margin_left", 8)
	doll_margin.add_theme_constant_override("margin_right", 8)
	doll_margin.add_theme_constant_override("margin_top", 8)
	doll_margin.add_theme_constant_override("margin_bottom", 8)
	doll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(doll_margin)

	_paperdoll = _build_paperdoll()
	doll_margin.add_child(_paperdoll)

	# Bottom: controls hint bar.
	_controls_bar = _build_controls_bar()
	outer.add_child(_controls_bar)

	# Floating tooltip — rendered above all other children.
	_tooltip_label = Label.new()
	_tooltip_label.name = "Tooltip"
	_tooltip_label.add_theme_font_size_override("font_size", 11)
	_tooltip_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85))
	_tooltip_label.add_theme_stylebox_override("normal", _make_tooltip_style())
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.z_index = 100
	_tooltip_label.visible = false
	add_child(_tooltip_label)


func _build_title_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"TitleBar"
	var lbl := Label.new()
	lbl.text = "Equipment & Inventory"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.theme_type_variation = &"TitleLabel"
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
		btn.theme_type_variation = &"WoodTabButtonActive" if is_default else &"WoodTabButton"
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

	# Scrollable grid of slots.
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Re-fill grid whenever the available area changes (e.g. window resize).
	_grid_scroll.resized.connect(_refresh)
	page.add_child(_grid_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.add_child(_grid)

	for i in range(TOTAL_SLOTS):
		var slot := _make_slot()
		_grid.add_child(slot)
		_inv_slots.append(slot)

	# Cursor highlight (overlaid on the selected slot).
	_cursor_panel = Panel.new()
	_cursor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_panel.size = Vector2(SLOT_SZ, SLOT_SZ)
	_cursor_panel.theme_type_variation = &"CursorPanel"
	_cursor_panel.z_index = 10
	page.add_child(_cursor_panel)

	# Detail panel below grid: name + slot/power meta + description.
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 2)
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.custom_minimum_size = Vector2(0, 60)

	_detail_name_label = Label.new()
	_detail_name_label.theme_type_variation = &"DimLabel"
	_detail_name_label.text = ""
	detail_box.add_child(_detail_name_label)

	_detail_meta_label = Label.new()
	_detail_meta_label.add_theme_font_size_override("font_size", 11)
	_detail_meta_label.add_theme_color_override("font_color", UITheme.COL_LABEL_DIM)
	_detail_meta_label.text = ""
	_detail_meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_detail_meta_label)

	_detail_desc_label = Label.new()
	_detail_desc_label.theme_type_variation = &"HintLabel"
	_detail_desc_label.text = "(select an item)"
	_detail_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_detail_desc_label)

	# Keep _detail_label pointing at desc for legacy compatibility.
	_detail_label = _detail_desc_label
	page.add_child(detail_box)

	return page


func _build_paperdoll() -> Control:
	var doll := Control.new()
	doll.custom_minimum_size = Vector2(180, 300)

	var bg := Panel.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.theme_type_variation = &"WoodInnerPanel"
	doll.add_child(bg)

	var silhouette := _build_silhouette()
	doll.add_child(silhouette)

	var cx: float = 90.0
	var half: float = SLOT_SZ * 0.5
	var positions: Dictionary = {
		ItemDefinition.Slot.HEAD:     Vector2(cx - half, 8.0),
		ItemDefinition.Slot.BODY:     Vector2(cx - half, 72.0),
		ItemDefinition.Slot.FEET:     Vector2(cx - half, 196.0),
		ItemDefinition.Slot.WEAPON:   Vector2(10.0, 90.0),
		ItemDefinition.Slot.OFF_HAND: Vector2(180.0 - SLOT_SZ - 10.0, 90.0),
		ItemDefinition.Slot.TOOL:     Vector2(10.0, 150.0),
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
		lbl.add_theme_color_override("font_color", UITheme.COL_LABEL_DIM)
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
	sb.bg_color = UITheme.COL_SILHOUETTE
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	p.add_theme_stylebox_override("panel", sb)
	return p


func _build_controls_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"TitleBar"
	_controls_label = RichTextLabel.new()
	_controls_label.bbcode_enabled = true
	_controls_label.fit_content = true
	_controls_label.scroll_active = false
	_controls_label.custom_minimum_size = Vector2(0, 18)
	_controls_label.add_theme_font_size_override("normal_font_size", 13)
	_controls_label.add_theme_color_override("default_color", UITheme.COL_LABEL_DIM)
	bar.add_child(_controls_label)
	_update_controls_text()
	return bar


func _update_controls_text() -> void:
	if _controls_label == null or _player == null:
		return
	var interact_key := InputContext.get_key_label(PlayerActions.action(_player.player_id, PlayerActions.INTERACT))
	var attack_key := InputContext.get_key_label(PlayerActions.action(_player.player_id, PlayerActions.ATTACK))
	var tab_prev := InputContext.get_key_label(PlayerActions.action(_player.player_id, PlayerActions.TAB_PREV))
	var tab_next := InputContext.get_key_label(PlayerActions.action(_player.player_id, PlayerActions.TAB_NEXT))
	var inv_key := InputContext.get_key_label(PlayerActions.action(_player.player_id, PlayerActions.INVENTORY))
	_controls_label.text = "[center][color=white][%s][/color] Equip/Use   [color=white][%s][/color] Drop   [color=white][%s/%s][/color] Tab   [color=white][%s][/color] Close[/center]" % [
		interact_key, attack_key, tab_prev, tab_next, inv_key]


# ---------- Tab management ----------

func _on_tab_button(tab_idx: int) -> void:
	_select_tab(tab_idx)


func _select_tab(tab_idx: int) -> void:
	# Apply character changes when leaving the CHARACTER tab.
	if _current_tab == Tab.CHARACTER and tab_idx != Tab.CHARACTER:
		_apply_char_opts_to_player()
	_current_tab = tab_idx
	# Update button styles and text color.
	for i in _tab_buttons.size():
		var active: bool = (i == tab_idx)
		_tab_buttons[i].theme_type_variation = \
			&"WoodTabButtonActive" if active else &"WoodTabButton"

	# Show the appropriate content page.
	_grid_page.visible = (tab_idx != Tab.CHARACTER)
	_char_page.visible = (tab_idx == Tab.CHARACTER)
	if tab_idx == Tab.CHARACTER:
		_load_char_opts_from_session()
		_refresh_char_preview()
		_refresh_char_labels()
		_refresh_char_stats()

	_cursor = 0
	_refresh()


func _cycle_tab(dir: int) -> void:
	var total: int = Tab.values().size()
	_select_tab(posmod(_current_tab + dir, total))


# ---------- Cursor navigation ----------

func _move_cursor(dx: int, dy: int) -> void:
	if _current_tab == Tab.CHARACTER:
		_move_char_cursor(dx, dy)
		return

	# Grid navigation.
	var total: int = _filtered_view.size()
	if total == 0:
		return
	var num_cols: int = _grid.columns if _grid != null and _grid.columns > 0 else COLS
	var col: int = _cursor % num_cols
	var row: int = _cursor / num_cols
	col = clampi(col + dx, 0, num_cols - 1)
	row = clampi(row + dy, 0, (total - 1) / num_cols)
	var new_idx: int = row * num_cols + col
	_cursor = clampi(new_idx, 0, total - 1)
	_refresh_cursor()


func _refresh_cursor() -> void:
	if _current_tab == Tab.CHARACTER:
		_cursor_panel.visible = false
		_clear_detail("")
		_hide_tooltip()
		return

	# Grid cursor.
	if _cursor >= 0 and _cursor < _inv_slots.size():
		var slot: HotbarSlot = _inv_slots[_cursor]
		if slot.is_inside_tree():
			_cursor_panel.visible = true
			# Position relative to grid_page so it overlays correctly.
			# Offset outward by 2px so the cursor ring wraps around the slot border.
			_cursor_panel.global_position = slot.global_position - Vector2(2, 2)
			_cursor_panel.size = slot.size + Vector2(4, 4)
			# Scroll the cursor slot into view.
			if _grid_scroll != null:
				_grid_scroll.ensure_control_visible(slot)
		else:
			_cursor_panel.visible = false
	else:
		_cursor_panel.visible = false

	# Update detail text and tooltip.
	if _cursor >= 0 and _cursor < _filtered_view.size():
		var entry: Dictionary = _filtered_view[_cursor]
		if entry["id"] != &"":
			var def: ItemDefinition = ItemRegistry.get_item(entry["id"])
			if def != null:
				_show_item_detail(def)
				if _cursor < _inv_slots.size():
					_show_tooltip(def.display_name, _inv_slots[_cursor])
			else:
				_clear_detail(String(entry["id"]))
				_hide_tooltip()
		else:
			_clear_detail("(empty)")
			_hide_tooltip()
	else:
		_clear_detail("(empty)")
		_hide_tooltip()


func _update_detail_equipment() -> void:
	if _detail_label == null:
		return
	if _cursor < 0 or _cursor >= EQUIPMENT_SLOT_ORDER.size():
		return
	var slot_type: int = EQUIPMENT_SLOT_ORDER[_cursor]
	var slot_name: String = slot_label(slot_type)
	if _player == null or _player.equipment == null:
		_clear_detail("%s — (empty)" % slot_name)
		return
	var equipped_id: StringName = _player.equipment.get_equipped(slot_type)
	if equipped_id == &"":
		_clear_detail("%s — (empty)" % slot_name)
		return
	var def: ItemDefinition = ItemRegistry.get_item(equipped_id)
	if def != null:
		_show_item_detail(def, slot_name)
	else:
		_clear_detail("%s — %s" % [slot_name, String(equipped_id)])


func _show_item_detail(def: ItemDefinition, prefix: String = "") -> void:
	var rarity_color: Color = ItemDefinition.RARITY_COLORS.get(def.rarity, Color.WHITE)
	var rarity_name: String = ItemDefinition.Rarity.keys()[def.rarity].capitalize()
	var name_text: String = def.display_name
	if prefix != "":
		name_text = "%s — %s" % [prefix, name_text]
	if def.rarity != ItemDefinition.Rarity.COMMON:
		name_text += " [%s]" % rarity_name
	_detail_name_label.text = name_text
	_detail_name_label.add_theme_color_override("font_color", rarity_color)

	# Meta line: slot + power + stack size for materials.
	if _detail_meta_label != null:
		var meta_parts: Array[String] = []
		var slot_name: String = slot_label(int(def.slot))
		if slot_name != "?":
			meta_parts.append(slot_name)
		if def.power > 0:
			meta_parts.append("Power: %d" % def.power)
		if def.slot == ItemDefinition.Slot.NONE:
			meta_parts.append("Stack: %d" % def.stack_size)
		_detail_meta_label.text = "  ·  ".join(meta_parts)

	_detail_desc_label.text = def.generate_description()


func _clear_detail(text: String = "(select an item)") -> void:
	_detail_name_label.text = ""
	_detail_name_label.add_theme_color_override("font_color", UITheme.COL_LABEL)
	if _detail_meta_label != null:
		_detail_meta_label.text = ""
	_detail_desc_label.text = text


func _make_tooltip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


func _show_tooltip(item_name: String, near_slot: Control) -> void:
	if _tooltip_label == null or near_slot == null:
		return
	_tooltip_label.text = item_name
	# Force layout to get correct size.
	_tooltip_label.reset_size()
	var slot_pos: Vector2 = near_slot.global_position - global_position
	var tip_x: float = slot_pos.x + near_slot.size.x * 0.5 - _tooltip_label.size.x * 0.5
	var tip_y: float = slot_pos.y - _tooltip_label.size.y - 4.0
	# Clamp within our own rect.
	tip_x = clampf(tip_x, 0.0, size.x - _tooltip_label.size.x)
	tip_y = maxf(tip_y, 0.0)
	_tooltip_label.position = Vector2(tip_x, tip_y)
	_tooltip_label.visible = true


func _hide_tooltip() -> void:
	if _tooltip_label != null:
		_tooltip_label.visible = false


# ---------- Interact / Drop ----------

func _interact_cursor() -> void:
	if _player == null:
		return
	if _current_tab == Tab.CHARACTER:
		return

	# Equip the item under cursor.
	if _cursor < 0 or _cursor >= _filtered_view.size():
		return
	var entry: Dictionary = _filtered_view[_cursor]
	if entry["id"] == &"":
		return
	var def: ItemDefinition = ItemRegistry.get_item(entry["id"])
	if def == null:
		return
	# Consumable items: apply effect and remove 1 from inventory.
	if def.consumable and def.slot == ItemDefinition.Slot.NONE:
		if def.heal_amount > 0 and _player != null:
			if _player.health >= _player.max_health:
				return  # Don't waste consumable at full health.
			_player.heal(def.heal_amount)
		_player.inventory.remove(entry["id"], 1)
		_refresh()
		return
	if def.slot == ItemDefinition.Slot.NONE:
		return
	# Equip: remove from inventory, put in equipment slot.
	var inv_idx: int = entry.get("inv_index", -1)
	if inv_idx < 0:
		return
	var taken: Variant = _player.inventory.take_slot(inv_idx)
	if taken == null:
		return
	# Equip returns displaced items (previous + handedness side-effects).
	var displaced: Array = _player.equipment.equip(def.slot, entry["id"])
	for pair in displaced:
		_player.inventory.add(pair[1], 1)


func _drop_cursor() -> void:
	if _player == null:
		return
	if _current_tab == Tab.CHARACTER:
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

	# Compute how many columns and rows fit in the visible scroll area (fills the panel).
	# slot_cell = SLOT_SZ + separation(4).
	var cell: float = SLOT_SZ + 4.0
	var dyn_cols: int = COLS
	var dyn_rows: int = ROWS
	if _grid_scroll != null and _grid_scroll.size.x > 0:
		dyn_cols = maxi(int(_grid_scroll.size.x / cell), COLS)
	if _grid_scroll != null and _grid_scroll.size.y > 0:
		dyn_rows = maxi(int(_grid_scroll.size.y / cell), ROWS)
	_grid.columns = dyn_cols

	# Ensure enough grid slots exist (at least dyn_cols*dyn_rows, or as many as
	# needed for the filtered view).
	var needed: int = maxi(_filtered_view.size(), dyn_cols * dyn_rows)
	# Round up to full row.
	needed = ceili(float(needed) / dyn_cols) * dyn_cols
	while _inv_slots.size() < needed:
		var slot := _make_slot()
		_grid.add_child(slot)
		_inv_slots.append(slot)

	# Populate grid slots.
	for i in range(_inv_slots.size()):
		if i < _filtered_view.size():
			var e: Dictionary = _filtered_view[i]
			_inv_slots[i].set_item(e["id"], int(e["count"]))
			_inv_slots[i].visible = true
		elif i < needed:
			_inv_slots[i].set_item(&"", 0)
			_inv_slots[i].visible = true
		else:
			_inv_slots[i].visible = false

	# Clamp cursor.
	var max_cursor: int = maxi(_filtered_view.size() - 1, 0)
	_cursor = clampi(_cursor, 0, max_cursor)
	_refresh_cursor()
	_update_controls_text()
	if _current_tab == Tab.CHARACTER:
		_refresh_char_stats()


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


# --- Character builder option definitions ---
const _CHAR_SKIN_OPTIONS: Array[StringName] = [&"light", &"tan", &"dark", &"goblin"]
const _CHAR_TORSO_COLORS: Array[StringName] = [
	&"orange", &"teal", &"purple", &"green", &"tan", &"black",
]
const _CHAR_HAIR_COLORS: Array[StringName] = [
	&"brown", &"blonde", &"white", &"ginger", &"gray",
]
const _CHAR_HAIR_STYLES: Array[int] = [
	CharacterAtlas.HairStyle.SHORT,
	CharacterAtlas.HairStyle.LONG,
	CharacterAtlas.HairStyle.ACCESSORY,
]
const _CHAR_HAIR_STYLE_NAMES: Array[String] = ["Short", "Long", "Accessory"]
const _CHAR_FACE_OPTIONS: Array[String] = [
	"None", "Brown", "Blonde", "White", "Ginger", "Gray",
]

const _CHAR_ROWS: Array = [
	["skin", "Skin Tone"],
	["torso_color", "Outfit Color"],
	["torso_style", "Outfit Style"],
	["hair_color", "Hair Color"],
	["hair_style", "Hair Style"],
	["hair_variant", "Hair Shape"],
	["face", "Facial Hair"],
	["face_variant", "Beard Shape"],
]

const _STAT_ORDER: Array[StringName] = [
	&"strength", &"dexterity", &"defense", &"charisma", &"wisdom", &"speed"
]

const _CHAR_VIEWPORT_SIZE: int = 32


func _build_character_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# --- Stats section ---
	_char_stats_container = _build_char_stats_section()
	page.add_child(_char_stats_container)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	page.add_child(sep)

	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	page.add_child(content)

	# --- Left: preview panel ---
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.custom_minimum_size = Vector2(120, 0)
	preview_panel.theme_type_variation = &"WoodInnerPanel"
	content.add_child(preview_panel)

	_char_preview_viewport = SubViewport.new()
	_char_preview_viewport.size = Vector2i(_CHAR_VIEWPORT_SIZE, _CHAR_VIEWPORT_SIZE)
	_char_preview_viewport.transparent_bg = true
	_char_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_char_preview_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	preview_panel.add_child(_char_preview_viewport)

	_char_preview_rect = TextureRect.new()
	_char_preview_rect.texture = _char_preview_viewport.get_texture()
	_char_preview_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	_char_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_char_preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_char_preview_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_preview_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(_char_preview_rect)

	# --- Right: arrow selector rows ---
	var rows_vbox := VBoxContainer.new()
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", 4)
	content.add_child(rows_vbox)

	_char_row_labels.clear()
	_char_value_labels.clear()
	for i in _CHAR_ROWS.size():
		var row_data: Array = _CHAR_ROWS[i]
		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 6)
		rows_vbox.add_child(row_hbox)

		var name_label := Label.new()
		name_label.text = row_data[1]
		name_label.custom_minimum_size.x = 100
		name_label.theme_type_variation = &"DimLabel"
		row_hbox.add_child(name_label)
		_char_row_labels.append(name_label)

		var left_btn := Button.new()
		left_btn.text = "<"
		left_btn.custom_minimum_size = Vector2(24, 24)
		left_btn.pressed.connect(_char_adjust.bind(i, -1))
		row_hbox.add_child(left_btn)

		var value_label := Label.new()
		value_label.custom_minimum_size.x = 80
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_color_override("font_color", UITheme.COL_LABEL)
		value_label.add_theme_font_size_override("font_size", 13)
		row_hbox.add_child(value_label)
		_char_value_labels.append(value_label)

		var right_btn := Button.new()
		right_btn.text = ">"
		right_btn.custom_minimum_size = Vector2(24, 24)
		right_btn.pressed.connect(_char_adjust.bind(i, 1))
		row_hbox.add_child(right_btn)

	return page


func _load_char_opts_from_session() -> void:
	if _player == null:
		_char_opts = {}
		return
	_char_opts = GameSession.get_appearance(_player.player_id).duplicate()
	if _char_opts.is_empty():
		_char_opts = {
			"skin": &"light",
			"torso_color": &"orange",
			"torso_style": 0,
			"torso_row": 0,
			"hair_color": &"brown",
			"hair_style": CharacterAtlas.HairStyle.SHORT,
			"hair_variant": 0,
		}


func _char_adjust(row_idx: int, dir: int) -> void:
	var row_data: Array = _CHAR_ROWS[row_idx]
	var key: String = row_data[0]
	match key:
		"skin":
			var idx: int = maxi(_CHAR_SKIN_OPTIONS.find(_char_opts.get("skin", &"light")), 0)
			idx = posmod(idx + dir, _CHAR_SKIN_OPTIONS.size())
			_char_opts["skin"] = _CHAR_SKIN_OPTIONS[idx]
		"torso_color":
			var idx: int = maxi(_CHAR_TORSO_COLORS.find(_char_opts.get("torso_color", &"orange")), 0)
			idx = posmod(idx + dir, _CHAR_TORSO_COLORS.size())
			_char_opts["torso_color"] = _CHAR_TORSO_COLORS[idx]
		"torso_style":
			_char_opts["torso_style"] = posmod(int(_char_opts.get("torso_style", 0)) + dir, 4)
		"hair_color":
			var idx: int = maxi(_CHAR_HAIR_COLORS.find(_char_opts.get("hair_color", &"brown")), 0)
			idx = posmod(idx + dir, _CHAR_HAIR_COLORS.size())
			_char_opts["hair_color"] = _CHAR_HAIR_COLORS[idx]
		"hair_style":
			var styles := _CHAR_HAIR_STYLES
			var cur: int = maxi(styles.find(int(_char_opts.get("hair_style", 0))), 0)
			cur = posmod(cur + dir, styles.size())
			_char_opts["hair_style"] = styles[cur]
		"hair_variant":
			_char_opts["hair_variant"] = posmod(int(_char_opts.get("hair_variant", 0)) + dir, 4)
		"face":
			var cur_color: Variant = _char_opts.get("face_color", null)
			var idx: int = 0
			if cur_color != null:
				idx = maxi(_CHAR_HAIR_COLORS.find(cur_color), 0) + 1
			idx = posmod(idx + dir, _CHAR_FACE_OPTIONS.size())
			if idx == 0:
				_char_opts.erase("face_color")
				_char_opts.erase("face_variant")
			else:
				_char_opts["face_color"] = _CHAR_HAIR_COLORS[idx - 1]
				if not _char_opts.has("face_variant"):
					_char_opts["face_variant"] = 0
		"face_variant":
			if _char_opts.has("face_color"):
				_char_opts["face_variant"] = posmod(
					int(_char_opts.get("face_variant", 0)) + dir, 4)
	_refresh_char_preview()
	_refresh_char_labels()


func _move_char_cursor(dx: int, dy: int) -> void:
	if dy != 0:
		_char_cursor = clampi(_char_cursor + dy, 0, _CHAR_ROWS.size() - 1)
		# Skip beard shape row if no facial hair selected.
		if _char_cursor == _CHAR_ROWS.size() - 1 and not _char_opts.has("face_color"):
			_char_cursor = clampi(_char_cursor + dy, 0, _CHAR_ROWS.size() - 2)
	if dx != 0:
		_char_adjust(_char_cursor, dx)
	_refresh_char_labels()


func _refresh_char_labels() -> void:
	for i in _CHAR_ROWS.size():
		var row_data: Array = _CHAR_ROWS[i]
		var key: String = row_data[0]
		var val_text: String = ""
		match key:
			"skin":
				val_text = String(_char_opts.get("skin", &"light")).capitalize()
			"torso_color":
				val_text = String(_char_opts.get("torso_color", &"orange")).capitalize()
			"torso_style":
				var names: Array = ["Plain", "Sash", "Apron", "Armored"]
				val_text = names[clampi(int(_char_opts.get("torso_style", 0)), 0, 3)]
			"hair_color":
				val_text = String(_char_opts.get("hair_color", &"brown")).capitalize()
			"hair_style":
				var si: int = maxi(_CHAR_HAIR_STYLES.find(
					int(_char_opts.get("hair_style", 0))), 0)
				val_text = _CHAR_HAIR_STYLE_NAMES[si]
			"hair_variant":
				val_text = str(int(_char_opts.get("hair_variant", 0)) + 1)
			"face":
				var fc: Variant = _char_opts.get("face_color", null)
				if fc == null:
					val_text = "None"
				else:
					val_text = String(fc).capitalize()
			"face_variant":
				if _char_opts.has("face_color"):
					val_text = str(int(_char_opts.get("face_variant", 0)) + 1)
				else:
					val_text = "-"
		if i < _char_value_labels.size():
			_char_value_labels[i].text = val_text
		# Highlight active row.
		if i < _char_row_labels.size():
			_char_row_labels[i].add_theme_color_override("font_color",
				UITheme.COL_LABEL if i == _char_cursor else UITheme.COL_LABEL_DIM)
	# Dim beard shape when no facial hair.
	var face_row: int = _CHAR_ROWS.size() - 1
	if face_row < _char_row_labels.size():
		var has_face: bool = _char_opts.has("face_color")
		_char_row_labels[face_row].modulate.a = 1.0 if has_face else 0.3
		_char_value_labels[face_row].modulate.a = 1.0 if has_face else 0.3


func _refresh_char_preview() -> void:
	if _char_preview_viewport == null:
		return
	# Remove old preview.
	if _char_preview_root != null and is_instance_valid(_char_preview_root):
		_char_preview_root.queue_free()
		_char_preview_root = null
	# Build fresh character preview (body features only, no weapon/shield).
	var preview_opts: Dictionary = _char_opts.duplicate()
	preview_opts.erase("weapon")
	preview_opts.erase("shield_material")
	_char_preview_root = CharacterBuilder.build(preview_opts)
	# Center the sprite stack in the viewport.
	_char_preview_root.position = Vector2(
		_CHAR_VIEWPORT_SIZE * 0.5, _CHAR_VIEWPORT_SIZE * 0.5 + 4)
	_char_preview_viewport.add_child(_char_preview_root)


func _apply_char_opts_to_player() -> void:
	if _player == null:
		return
	GameSession.set_appearance(_player.player_id, _char_opts.duplicate())
	_player.apply_appearance(_char_opts)


# ---------- Style helpers ----------

func _make_slot() -> HotbarSlot:
	var slot := HotbarSlot.new()
	slot.custom_minimum_size = Vector2(UITheme.SLOT_SZ, UITheme.SLOT_SZ)
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = UITheme.COL_SLOT_BG
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
	count_label.theme_type_variation = &"HintLabel"
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 1.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count_label)
	return slot


func _build_char_stats_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Level + XP row.
	var lv_row := HBoxContainer.new()
	lv_row.add_theme_constant_override("separation", 8)
	section.add_child(lv_row)

	var lv_label := Label.new()
	lv_label.text = "Level"
	lv_label.add_theme_font_size_override("font_size", 13)
	lv_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	lv_label.custom_minimum_size.x = 42
	lv_row.add_child(lv_label)

	var lv_val := Label.new()
	lv_val.add_theme_font_size_override("font_size", 13)
	lv_val.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	lv_val.custom_minimum_size.x = 24
	lv_row.add_child(lv_val)
	_char_stat_value_labels[&"_level"] = lv_val

	_char_xp_bar = XpBar.new()
	_char_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv_row.add_child(_char_xp_bar)

	# Pending points label (hidden when 0).
	_char_pending_label = Label.new()
	_char_pending_label.add_theme_font_size_override("font_size", 12)
	_char_pending_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_char_pending_label.visible = false
	section.add_child(_char_pending_label)

	# Stat rows.
	for stat: StringName in _STAT_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		section.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = String(stat).capitalize()
		name_lbl.custom_minimum_size.x = 90
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", UITheme.COL_LABEL)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.custom_minimum_size.x = 28
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		row.add_child(val_lbl)
		_char_stat_value_labels[stat] = val_lbl

		var plus_btn := Button.new()
		plus_btn.text = "[+]"
		plus_btn.flat = true
		plus_btn.custom_minimum_size = Vector2(32, 20)
		plus_btn.add_theme_font_size_override("font_size", 11)
		plus_btn.visible = false
		var s: StringName = stat  # capture for closure
		plus_btn.pressed.connect(func() -> void: _on_stat_plus_pressed(s))
		row.add_child(plus_btn)
		_char_stat_plus_buttons[stat] = plus_btn

	# Passives row.
	_char_passives_label = Label.new()
	_char_passives_label.add_theme_font_size_override("font_size", 11)
	_char_passives_label.add_theme_color_override("font_color", UITheme.COL_LABEL_DIM)
	_char_passives_label.text = ""
	section.add_child(_char_passives_label)

	return section


func _refresh_char_stats() -> void:
	if _player == null or _char_stat_value_labels.is_empty():
		return

	# Level label.
	var lv_lbl: Label = _char_stat_value_labels.get(&"_level")
	if lv_lbl != null:
		lv_lbl.text = str(_player.level)

	# XP bar.
	if _char_xp_bar != null:
		_char_xp_bar.update(
			_player.xp,
			_player.level,
			LevelingConfig.xp_to_next(_player.level),
			_player._pending_stat_points > 0
		)

	# Stat rows.
	var has_points: bool = _player._pending_stat_points > 0
	for stat: StringName in _STAT_ORDER:
		var val_lbl: Label = _char_stat_value_labels.get(stat)
		if val_lbl != null:
			val_lbl.text = str(_player.get_stat(stat))
		var btn: Button = _char_stat_plus_buttons.get(stat)
		if btn != null:
			btn.visible = has_points

	# Pending points header.
	if _char_pending_label != null:
		if has_points:
			_char_pending_label.text = "[%d stat point%s to spend — press [+]]" % [
				_player._pending_stat_points,
				"s" if _player._pending_stat_points > 1 else ""
			]
			_char_pending_label.visible = true
		else:
			_char_pending_label.visible = false

	# Passives.
	if _char_passives_label != null:
		if _player.unlocked_passives.is_empty():
			_char_passives_label.text = ""
		else:
			var names: Array[String] = []
			for p: StringName in _player.unlocked_passives:
				names.append(String(p).capitalize().replace("_", " "))
			_char_passives_label.text = "Passives: %s" % ", ".join(names)


func _on_stat_plus_pressed(stat: StringName) -> void:
	if _player == null:
		return
	_player.spend_stat_point(stat)
	_refresh_char_stats()


# ---------- Test helpers ----------

func get_inv_slots() -> Array[HotbarSlot]:
	return _inv_slots


func get_eq_slots() -> Array[HotbarSlot]:
	return _eq_slots


