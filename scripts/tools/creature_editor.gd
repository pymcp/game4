## CreatureEditor
##
## Sub-editor panel for managing `resources/creature_sprites.json` within
## the game editor.  Provides a creature list, property panel with sprite /
## rendering / stats sections, and atlas integration for region, anchor,
## and mount-point picking.
##
## Data flow mirrors ItemEditor: reads via
## `CreatureSpriteRegistry.get_raw_data()`, edits an in-memory dict, and
## persists via `CreatureSpriteRegistry.save_data()`.
class_name CreatureEditor
extends VBoxContainer

signal dirty_changed
signal sheet_requested(path: String)

const TILE_PX := 16

var sheet_path: String = "res://assets/characters/monsters/slime.png"
var gutter: int = 0  ## Set by game editor from SheetView auto-detection.

## Raw creature_sprites.json data (id → dict). Edits mutate this directly.
var _data: Dictionary = {}
var _selected_id: StringName = &""
var _dirty: bool = false

## Atlas click mode: "", "region", "anchor", "mount_point"
var _pick_mode: String = ""
## For region drag: start cell of the drag.
var _region_drag_start: Vector2i = Vector2i(-1, -1)

# ─── UI refs ──────────────────────────────────────────────────────────
var _creature_list: ItemList = null
var _prop_scroll: ScrollContainer = null
var _prop_panel: VBoxContainer = null

# CRUD
var _add_btn: Button = null
var _del_btn: Button = null
var _id_edit: LineEdit = null
var _rename_btn: Button = null

# Sprite section
var _sheet_label: Label = null
var _region_check: CheckBox = null
var _region_x: SpinBox = null
var _region_y: SpinBox = null
var _region_w: SpinBox = null
var _region_h: SpinBox = null
var _region_pick_btn: Button = null

# Anchor section
var _anchor_mode_opt: OptionButton = null  # 0 = ratio, 1 = absolute
var _anchor_x: SpinBox = null
var _anchor_y: SpinBox = null
var _anchor_pick_btn: Button = null

# Scale section
var _scale_mode_opt: OptionButton = null  # 0 = target_width_tiles, 1 = explicit
var _scale_x: SpinBox = null
var _scale_y: SpinBox = null

# Misc rendering
var _tint_picker: ColorPickerButton = null
var _footprint_w: SpinBox = null
var _footprint_h: SpinBox = null

# Creature stats (mount)
var _mount_check: CheckBox = null
var _facing_right_check: CheckBox = null
var _can_jump_check: CheckBox = null
var _speed_spin: SpinBox = null
var _mount_section: VBoxContainer = null

# Mount point
var _rider_x: SpinBox = null
var _rider_y: SpinBox = null
var _rider_pick_btn: Button = null

# Boss section
var _is_boss_check: CheckBox = null
var _boss_adds_edit: TextEdit = null

# Pet section
var _is_pet_check: CheckBox = null


func _ready() -> void:
	_load_data()
	_build_ui()
	_populate_list()
	if _creature_list.item_count > 0:
		_creature_list.select(0)
		_on_creature_selected(0)


func _load_data() -> void:
	CreatureSpriteRegistry.reset()
	_data = CreatureSpriteRegistry.get_raw_data()


# ─── Build UI ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 600

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 160
	add_child(split)

	# ── Left pane: creature list + add/delete ──
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left)

	_creature_list = ItemList.new()
	_creature_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_creature_list.item_selected.connect(_on_creature_selected)
	left.add_child(_creature_list)

	var btn_row := HBoxContainer.new()
	_add_btn = Button.new()
	_add_btn.text = "+ Add"
	_add_btn.pressed.connect(_on_add_creature)
	btn_row.add_child(_add_btn)
	_del_btn = Button.new()
	_del_btn.text = "Delete"
	_del_btn.pressed.connect(_on_delete_creature)
	btn_row.add_child(_del_btn)
	left.add_child(btn_row)

	# ── Right pane: scrollable property panel ──
	_prop_scroll = ScrollContainer.new()
	_prop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_prop_scroll)

	_prop_panel = VBoxContainer.new()
	_prop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prop_scroll.add_child(_prop_panel)

	_build_identity_section()
	_build_sprite_section()
	_build_rendering_section()
	_build_stats_section()
	_build_mount_section()
	_build_boss_section()


func _build_identity_section() -> void:
	_prop_panel.add_child(_section_label("Identity"))
	var row := HBoxContainer.new()
	row.add_child(_label("ID:"))
	_id_edit = LineEdit.new()
	_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_id_edit.editable = true
	row.add_child(_id_edit)
	_rename_btn = Button.new()
	_rename_btn.text = "Rename"
	_rename_btn.pressed.connect(_on_rename)
	row.add_child(_rename_btn)
	_prop_panel.add_child(row)


func _build_sprite_section() -> void:
	_prop_panel.add_child(_section_label("Sprite"))
	# Sheet path (read-only, updated when atlas sheet changes)
	_sheet_label = Label.new()
	_sheet_label.text = "Sheet: (none)"
	_prop_panel.add_child(_sheet_label)

	# Region toggle + spinboxes
	_region_check = CheckBox.new()
	_region_check.text = "Use Region (sub-rect of sheet)"
	_region_check.toggled.connect(_on_region_toggled)
	_prop_panel.add_child(_region_check)

	var rgrid := GridContainer.new()
	rgrid.columns = 4
	rgrid.add_child(_label("X:"))
	_region_x = _spin(0, 4096, 0)
	_region_x.value_changed.connect(func(v): _set_field_arr("region", 0, v))
	rgrid.add_child(_region_x)
	rgrid.add_child(_label("Y:"))
	_region_y = _spin(0, 4096, 0)
	_region_y.value_changed.connect(func(v): _set_field_arr("region", 1, v))
	rgrid.add_child(_region_y)
	rgrid.add_child(_label("W:"))
	_region_w = _spin(1, 4096, 16)
	_region_w.value_changed.connect(func(v): _set_field_arr("region", 2, v))
	rgrid.add_child(_region_w)
	rgrid.add_child(_label("H:"))
	_region_h = _spin(1, 4096, 16)
	_region_h.value_changed.connect(func(v): _set_field_arr("region", 3, v))
	rgrid.add_child(_region_h)
	_prop_panel.add_child(rgrid)

	# Region pick button
	_region_pick_btn = Button.new()
	_region_pick_btn.text = "Pick Region on Atlas"
	_region_pick_btn.pressed.connect(_on_pick_region)
	_prop_panel.add_child(_region_pick_btn)


func _build_rendering_section() -> void:
	_prop_panel.add_child(_section_label("Rendering"))

	# Anchor mode
	var arow := HBoxContainer.new()
	arow.add_child(_label("Anchor:"))
	_anchor_mode_opt = OptionButton.new()
	_anchor_mode_opt.add_item("Ratio", 0)
	_anchor_mode_opt.add_item("Absolute (px)", 1)
	_anchor_mode_opt.item_selected.connect(_on_anchor_mode_changed)
	arow.add_child(_anchor_mode_opt)
	_prop_panel.add_child(arow)

	var agrid := GridContainer.new()
	agrid.columns = 4
	agrid.add_child(_label("X:"))
	_anchor_x = _spin_f(-4096, 4096, 0.0, 0.01)
	_anchor_x.value_changed.connect(func(v): _on_anchor_changed(0, v))
	agrid.add_child(_anchor_x)
	agrid.add_child(_label("Y:"))
	_anchor_y = _spin_f(-4096, 4096, 0.0, 0.01)
	_anchor_y.value_changed.connect(func(v): _on_anchor_changed(1, v))
	agrid.add_child(_anchor_y)
	_prop_panel.add_child(agrid)

	_anchor_pick_btn = Button.new()
	_anchor_pick_btn.text = "Pick Anchor on Atlas"
	_anchor_pick_btn.pressed.connect(_on_pick_anchor)
	_prop_panel.add_child(_anchor_pick_btn)

	# Scale mode
	var srow := HBoxContainer.new()
	srow.add_child(_label("Scale:"))
	_scale_mode_opt = OptionButton.new()
	_scale_mode_opt.add_item("Target Width (tiles)", 0)
	_scale_mode_opt.add_item("Explicit", 1)
	_scale_mode_opt.item_selected.connect(_on_scale_mode_changed)
	srow.add_child(_scale_mode_opt)
	_prop_panel.add_child(srow)

	var sgrid := GridContainer.new()
	sgrid.columns = 4
	sgrid.add_child(_label("X/Tiles:"))
	_scale_x = _spin_f(0.01, 100, 1.0, 0.05)
	_scale_x.value_changed.connect(_on_scale_x_changed)
	sgrid.add_child(_scale_x)
	sgrid.add_child(_label("Y:"))
	_scale_y = _spin_f(0.01, 100, 1.0, 0.05)
	_scale_y.value_changed.connect(func(v): _set_field_arr("scale", 1, v))
	sgrid.add_child(_scale_y)
	_prop_panel.add_child(sgrid)

	# Tint
	var trow := HBoxContainer.new()
	trow.add_child(_label("Tint:"))
	_tint_picker = ColorPickerButton.new()
	_tint_picker.custom_minimum_size = Vector2(60, 28)
	_tint_picker.color = Color.WHITE
	_tint_picker.color_changed.connect(_on_tint_changed)
	trow.add_child(_tint_picker)
	_prop_panel.add_child(trow)

	# Footprint
	var frow := HBoxContainer.new()
	frow.add_child(_label("Footprint:"))
	_footprint_w = _spin(1, 8, 1)
	_footprint_w.value_changed.connect(func(v): _set_field_arr("footprint", 0, int(v)))
	frow.add_child(_footprint_w)
	frow.add_child(_label("×"))
	_footprint_h = _spin(1, 8, 1)
	_footprint_h.value_changed.connect(func(v): _set_field_arr("footprint", 1, int(v)))
	frow.add_child(_footprint_h)
	_prop_panel.add_child(frow)


func _build_stats_section() -> void:
	_prop_panel.add_child(_section_label("Creature Stats"))
	_mount_check = CheckBox.new()
	_mount_check.text = "Mountable"
	_mount_check.toggled.connect(_on_mount_toggled)
	_prop_panel.add_child(_mount_check)

	_facing_right_check = CheckBox.new()
	_facing_right_check.text = "Sprite faces right"
	_facing_right_check.toggled.connect(func(v): _set_field("facing_right", v))
	_prop_panel.add_child(_facing_right_check)


func _build_mount_section() -> void:
	_mount_section = VBoxContainer.new()
	_mount_section.visible = false
	_prop_panel.add_child(_mount_section)

	_mount_section.add_child(_section_label("Mount Properties"))

	_can_jump_check = CheckBox.new()
	_can_jump_check.text = "Can Jump / Hop"
	_can_jump_check.toggled.connect(func(v): _set_field("can_jump", v))
	_mount_section.add_child(_can_jump_check)

	var srow := HBoxContainer.new()
	srow.add_child(_label("Speed ×:"))
	_speed_spin = _spin_f(0.1, 10.0, 1.0, 0.1)
	_speed_spin.value_changed.connect(func(v): _set_field("speed_multiplier", v))
	srow.add_child(_speed_spin)
	_mount_section.add_child(srow)

	_mount_section.add_child(_section_label("Rider Mount Point"))
	var rgrid := GridContainer.new()
	rgrid.columns = 4
	rgrid.add_child(_label("X:"))
	_rider_x = _spin_f(-200, 200, 0, 1)
	_rider_x.value_changed.connect(func(v): _set_field_arr("rider_offset", 0, v))
	rgrid.add_child(_rider_x)
	rgrid.add_child(_label("Y:"))
	_rider_y = _spin_f(-200, 200, -12, 1)
	_rider_y.value_changed.connect(func(v): _set_field_arr("rider_offset", 1, v))
	rgrid.add_child(_rider_y)
	_mount_section.add_child(rgrid)

	_rider_pick_btn = Button.new()
	_rider_pick_btn.text = "Pick Mount Point on Atlas"
	_rider_pick_btn.pressed.connect(_on_pick_mount_point)
	_mount_section.add_child(_rider_pick_btn)


func _build_boss_section() -> void:
	_prop_panel.add_child(_section_label("Boss Settings"))

	var is_boss_hbox := HBoxContainer.new()
	_prop_panel.add_child(is_boss_hbox)
	var is_boss_label := Label.new()
	is_boss_label.text = "is_boss:"
	is_boss_hbox.add_child(is_boss_label)
	_is_boss_check = CheckBox.new()
	_is_boss_check.name = "IsBossCheck"
	_is_boss_check.toggled.connect(func(v: bool) -> void: _set_field("is_boss", v))
	is_boss_hbox.add_child(_is_boss_check)

	# Is Pet toggle — lets any creature be promoted to a pet from the editor.
	var is_pet_hbox := HBoxContainer.new()
	_prop_panel.add_child(is_pet_hbox)
	var is_pet_label := Label.new()
	is_pet_label.text = "is_pet:"
	is_pet_hbox.add_child(is_pet_label)
	_is_pet_check = CheckBox.new()
	_is_pet_check.name = "IsPetCheck"
	_is_pet_check.toggled.connect(func(v: bool) -> void: _set_field("is_pet", v))
	is_pet_hbox.add_child(_is_pet_check)

	var adds_label := Label.new()
	adds_label.text = "boss_adds (one per line: 'creature count'):"
	_prop_panel.add_child(adds_label)

	_boss_adds_edit = TextEdit.new()
	_boss_adds_edit.name = "BossAddsEdit"
	_boss_adds_edit.custom_minimum_size = Vector2(0, 60)
	_boss_adds_edit.text_changed.connect(func() -> void:
		_parse_boss_adds(_boss_adds_edit.text)
		_mark_dirty())
	_prop_panel.add_child(_boss_adds_edit)


# ─── List management ───────────────────────────────────────────────────

func _populate_list() -> void:
	_creature_list.clear()
	var keys: Array = _data.keys()
	keys.sort()
	for k in keys:
		_creature_list.add_item(String(k))
		var idx: int = _creature_list.item_count - 1
		_creature_list.set_item_metadata(idx, String(k))
		# Highlight pet entries in pastel green so they're visually distinct.
		var entry: Dictionary = _data.get(String(k), {})
		if entry.get("is_pet", false):
			_creature_list.set_item_custom_fg_color(idx, Color(0.5, 1.0, 0.6))


func _on_creature_selected(idx: int) -> void:
	if idx < 0 or idx >= _creature_list.item_count:
		_selected_id = &""
		return
	_selected_id = StringName(_creature_list.get_item_metadata(idx))
	_refresh_props()


func _on_add_creature() -> void:
	var base_id: String = "new_creature"
	var new_id: String = base_id
	var counter: int = 1
	while _data.has(new_id):
		new_id = "%s_%d" % [base_id, counter]
		counter += 1
	_data[new_id] = {
		"sheet": sheet_path,
		"anchor": [8, 14],
		"scale": [1.0, 1.0],
		"footprint": [1, 1],
		"tint": [1.0, 1.0, 1.0, 1.0],
	}
	_mark_dirty()
	_populate_list()
	_select_by_id(StringName(new_id))


func _on_delete_creature() -> void:
	if _selected_id == &"":
		return
	_data.erase(String(_selected_id))
	_mark_dirty()
	_populate_list()
	if _creature_list.item_count > 0:
		_creature_list.select(0)
		_on_creature_selected(0)
	else:
		_selected_id = &""


func _on_rename() -> void:
	if _selected_id == &"" or _id_edit.text.strip_edges().is_empty():
		return
	var new_id: String = _id_edit.text.strip_edges()
	if new_id == String(_selected_id):
		return
	if _data.has(new_id):
		return  # name conflict
	var entry: Dictionary = _data[String(_selected_id)]
	_data.erase(String(_selected_id))
	_data[new_id] = entry
	_selected_id = StringName(new_id)
	_mark_dirty()
	_populate_list()
	_select_by_id(_selected_id)


func _select_by_id(id: StringName) -> void:
	for i in _creature_list.item_count:
		if _creature_list.get_item_metadata(i) == String(id):
			_creature_list.select(i)
			_on_creature_selected(i)
			return


# ─── Property refresh ──────────────────────────────────────────────────

func _refresh_props() -> void:
	var e: Dictionary = _data.get(String(_selected_id), {})
	if e.is_empty():
		return

	_id_edit.text = String(_selected_id)

	# Sheet
	var sp: String = e.get("sheet", "")
	_sheet_label.text = "Sheet: %s" % (sp if sp != "" else "(none)")
	if sp != "" and sp != sheet_path:
		sheet_requested.emit(sp)

	# Region
	var region: Array = e.get("region", [])
	var has_region: bool = region.size() == 4
	_region_check.set_pressed_no_signal(has_region)
	_region_x.editable = has_region
	_region_y.editable = has_region
	_region_w.editable = has_region
	_region_h.editable = has_region
	if has_region:
		_region_x.set_value_no_signal(float(region[0]))
		_region_y.set_value_no_signal(float(region[1]))
		_region_w.set_value_no_signal(float(region[2]))
		_region_h.set_value_no_signal(float(region[3]))
	else:
		_region_x.set_value_no_signal(0)
		_region_y.set_value_no_signal(0)
		_region_w.set_value_no_signal(16)
		_region_h.set_value_no_signal(16)

	# Anchor
	if e.has("anchor_ratio"):
		_anchor_mode_opt.select(0)
		var ar: Array = e["anchor_ratio"]
		_anchor_x.set_value_no_signal(float(ar[0]))
		_anchor_y.set_value_no_signal(float(ar[1]))
		_anchor_x.step = 0.01
		_anchor_y.step = 0.01
	else:
		_anchor_mode_opt.select(1)
		var a: Array = e.get("anchor", [0, 0])
		_anchor_x.set_value_no_signal(float(a[0]))
		_anchor_y.set_value_no_signal(float(a[1]))
		_anchor_x.step = 1
		_anchor_y.step = 1

	# Scale
	if e.has("target_width_tiles"):
		_scale_mode_opt.select(0)
		_scale_x.set_value_no_signal(float(e["target_width_tiles"]))
		_scale_y.set_value_no_signal(1.0)
		_scale_y.editable = false
	elif e.has("scale"):
		_scale_mode_opt.select(1)
		var s: Array = e["scale"]
		_scale_x.set_value_no_signal(float(s[0]))
		_scale_y.set_value_no_signal(float(s[1]))
		_scale_y.editable = true
	else:
		_scale_mode_opt.select(1)
		_scale_x.set_value_no_signal(1.0)
		_scale_y.set_value_no_signal(1.0)
		_scale_y.editable = true

	# Tint
	var t: Array = e.get("tint", [1.0, 1.0, 1.0, 1.0])
	_tint_picker.color = Color(float(t[0]), float(t[1]), float(t[2]), float(t[3]))

	# Footprint
	var fp: Array = e.get("footprint", [1, 1])
	_footprint_w.set_value_no_signal(int(fp[0]))
	_footprint_h.set_value_no_signal(int(fp[1]))

	# Creature stats
	_mount_check.set_pressed_no_signal(e.get("mount", false))
	_facing_right_check.set_pressed_no_signal(e.get("facing_right", false))

	# Mount section visibility
	_mount_section.visible = e.get("mount", false)
	if _mount_section.visible:
		_can_jump_check.set_pressed_no_signal(e.get("can_jump", false))
		_speed_spin.set_value_no_signal(float(e.get("speed_multiplier", 1.0)))
		var ro: Array = e.get("rider_offset", [0, -12])
		_rider_x.set_value_no_signal(float(ro[0]))
		_rider_y.set_value_no_signal(float(ro[1]))

	# Boss fields
	_is_boss_check.set_pressed_no_signal(bool(e.get("is_boss", false)))
	_is_pet_check.set_pressed_no_signal(bool(e.get("is_pet", false)))
	var adds_list: Array = e.get("boss_adds", [])
	var adds_text: String = ""
	for add in adds_list:
		adds_text += "%s %d\n" % [add.get("creature", ""), int(add.get("count", 1))]
	_boss_adds_edit.text = adds_text.strip_edges()


# ─── Field setters ─────────────────────────────────────────────────────

func _set_field(key: String, value: Variant) -> void:
	var e: Dictionary = _data.get(String(_selected_id), {})
	if e.is_empty():
		return
	e[key] = value
	_mark_dirty()


func _set_field_arr(key: String, idx: int, value: Variant) -> void:
	var e: Dictionary = _data.get(String(_selected_id), {})
	if e.is_empty():
		return
	if not e.has(key) or not (e[key] is Array):
		return
	var arr: Array = e[key]
	if idx < arr.size():
		arr[idx] = value
		_mark_dirty()


func _mark_dirty() -> void:
	_dirty = true
	dirty_changed.emit()


func _parse_boss_adds(text: String) -> void:
	var result: Array = []
	for line in text.split("\n"):
		var parts: Array = line.strip_edges().split(" ")
		if parts.size() >= 2:
			result.append({
				"creature": parts[0],
				"count": int(parts[1]),
			})
	var e: Dictionary = _data.get(String(_selected_id), {})
	if not e.is_empty():
		e["boss_adds"] = result


# ─── Callbacks ─────────────────────────────────────────────────────────

func _on_region_toggled(pressed: bool) -> void:
	var e: Dictionary = _data.get(String(_selected_id), {})
	if e.is_empty():
		return
	if pressed:
		if not e.has("region") or not (e["region"] is Array) or e["region"].size() != 4:
			e["region"] = [0, 0, 16, 16]
	else:
		e.erase("region")
	_mark_dirty()
	_refresh_props()


func _on_anchor_mode_changed(idx: int) -> void:
	var e: Dictionary = _data.get(String(_selected_id), {})
	if e.is_empty():
		return
	if idx == 0:  # ratio
		e.erase("anchor")
		if not e.has("anchor_ratio"):
			e["anchor_ratio"] = [0.5, 0.95]
	else:  # absolute
		e.erase("anchor_ratio")
		if not e.has("anchor"):
			e["anchor"] = [8, 14]
	_mark_dirty()
	_refresh_props()


func _on_anchor_changed(component: int, value: float) -> void:
	var e: Dictionary = _data.get(String(_selected_id), {})
	if e.is_empty():
		return
	if e.has("anchor_ratio"):
		_set_field_arr("anchor_ratio", component, value)
	elif e.has("anchor"):
		_set_field_arr("anchor", component, value)


func _on_scale_mode_changed(idx: int) -> void:
	var e: Dictionary = _data.get(String(_selected_id), {})
	if e.is_empty():
		return
	if idx == 0:  # target_width_tiles
		e.erase("scale")
		if not e.has("target_width_tiles"):
			e["target_width_tiles"] = 1
	else:  # explicit
		e.erase("target_width_tiles")
		if not e.has("scale"):
			e["scale"] = [1.0, 1.0]
	_mark_dirty()
	_refresh_props()


func _on_scale_x_changed(value: float) -> void:
	var e: Dictionary = _data.get(String(_selected_id), {})
	if e.is_empty():
		return
	if e.has("target_width_tiles"):
		e["target_width_tiles"] = value
		_mark_dirty()
	elif e.has("scale"):
		_set_field_arr("scale", 0, value)


func _on_tint_changed(color: Color) -> void:
	_set_field("tint", [color.r, color.g, color.b, color.a])


func _on_mount_toggled(pressed: bool) -> void:
	var e: Dictionary = _data.get(String(_selected_id), {})
	if e.is_empty():
		return
	if pressed:
		e["mount"] = true
		if not e.has("speed_multiplier"):
			e["speed_multiplier"] = 1.0
		if not e.has("rider_offset"):
			e["rider_offset"] = [0, -12]
	else:
		e.erase("mount")
		e.erase("speed_multiplier")
		e.erase("can_jump")
		e.erase("rider_offset")
	_mark_dirty()
	_mount_section.visible = pressed
	_refresh_props()


# ─── Atlas pick modes ──────────────────────────────────────────────────

func _on_pick_region() -> void:
	_pick_mode = "region"
	_region_pick_btn.text = "Click two corners on atlas..."
	_region_drag_start = Vector2i(-1, -1)


func _on_pick_anchor() -> void:
	_pick_mode = "anchor"
	_anchor_pick_btn.text = "Click anchor point on atlas..."


func _on_pick_mount_point() -> void:
	_pick_mode = "mount_point"
	_rider_pick_btn.text = "Click mount point on atlas..."


## Called by the game editor when the user clicks a cell on the atlas.
func on_atlas_cell_clicked(cell: Vector2i) -> void:
	if _selected_id == &"":
		return
	var e: Dictionary = _data.get(String(_selected_id), {})
	if e.is_empty():
		return

	if _pick_mode == "region":
		if _region_drag_start.x < 0:
			_region_drag_start = cell
			_region_pick_btn.text = "Click second corner..."
			return
		# Compute region from two corners.
		var step: int = TILE_PX + gutter
		var x0: int = mini(cell.x, _region_drag_start.x) * step
		var y0: int = mini(cell.y, _region_drag_start.y) * step
		var x1: int = (maxi(cell.x, _region_drag_start.x) + 1) * step - gutter
		var y1: int = (maxi(cell.y, _region_drag_start.y) + 1) * step - gutter
		e["region"] = [x0, y0, x1 - x0, y1 - y0]
		_region_check.set_pressed_no_signal(true)
		_pick_mode = ""
		_region_pick_btn.text = "Pick Region on Atlas"
		_region_drag_start = Vector2i(-1, -1)
		_mark_dirty()
		_refresh_props()
		return

	if _pick_mode == "anchor":
		# Store anchor in pixels (cell center).
		var step: int = TILE_PX + gutter
		var px_x: float = float(cell.x) * step + TILE_PX * 0.5
		var px_y: float = float(cell.y) * step + TILE_PX * 0.5
		# Relative to region origin if region exists.
		var region: Array = e.get("region", [])
		if region.size() == 4:
			px_x -= float(region[0])
			px_y -= float(region[1])
		if e.has("anchor_ratio"):
			e.erase("anchor_ratio")
		e["anchor"] = [px_x, px_y]
		_anchor_mode_opt.select(1)
		_pick_mode = ""
		_anchor_pick_btn.text = "Pick Anchor on Atlas"
		_mark_dirty()
		_refresh_props()
		return

	if _pick_mode == "mount_point":
		# Rider offset is relative to anchor, in native pixels.
		var anchor: Vector2 = _get_current_anchor(e)
		var step: int = TILE_PX + gutter
		var click_px := Vector2(
			float(cell.x) * step + TILE_PX * 0.5,
			float(cell.y) * step + TILE_PX * 0.5)
		# Adjust for region origin.
		var region: Array = e.get("region", [])
		if region.size() == 4:
			click_px.x -= float(region[0])
			click_px.y -= float(region[1])
		# Scale down to native pixels if target_width_tiles is used.
		var scale: Vector2 = _get_current_scale(e)
		var offset := (click_px - anchor) * scale
		e["rider_offset"] = [snapped(offset.x, 0.5), snapped(offset.y, 0.5)]
		_pick_mode = ""
		_rider_pick_btn.text = "Pick Mount Point on Atlas"
		_mark_dirty()
		_refresh_props()
		return

	# Default: update sheet path from current atlas.
	e["sheet"] = sheet_path
	_mark_dirty()
	_refresh_props()


## Returns marks for the atlas overlay.
func get_marks() -> Array:
	if _selected_id == &"":
		return []
	var e: Dictionary = _data.get(String(_selected_id), {})
	if e.is_empty():
		return []
	var marks: Array = []

	# Region rectangle.
	var region: Array = e.get("region", [])
	var step: int = TILE_PX + gutter
	if region.size() == 4:
		var rx: int = int(region[0]) / step
		var ry: int = int(region[1]) / step
		var rw: int = ceili(float(region[2]) / TILE_PX)
		var rh: int = ceili(float(region[3]) / TILE_PX)
		for dy in rh:
			for dx in rw:
				marks.append({
					"cell": Vector2i(rx + dx, ry + dy),
					"color": Color.CYAN,
					"width": 2.0,
				})

	# Anchor cell.
	var anchor_cell: Vector2i = _anchor_to_cell(e)
	if anchor_cell.x >= 0:
		marks.append({
			"cell": anchor_cell,
			"color": Color.GREEN,
			"width": 3.0,
		})

	# Mount point cell.
	if e.get("mount", false) and e.has("rider_offset"):
		var mp_cell: Vector2i = _rider_offset_to_cell(e)
		if mp_cell.x >= 0:
			marks.append({
				"cell": mp_cell,
				"color": Color.YELLOW,
				"width": 3.0,
			})

	# Region drag start indicator.
	if _pick_mode == "region" and _region_drag_start.x >= 0:
		marks.append({
			"cell": _region_drag_start,
			"color": Color.RED,
			"width": 3.0,
		})

	return marks


# ─── Save / Revert / Dirty ────────────────────────────────────────────

func save() -> void:
	CreatureSpriteRegistry.save_data(_data.duplicate(true))
	CreatureSpriteRegistry.reset()
	_dirty = false


func revert() -> void:
	CreatureSpriteRegistry.reset()
	_load_data()
	_dirty = false
	_populate_list()
	if _creature_list.item_count > 0:
		_creature_list.select(0)
		_on_creature_selected(0)


func is_dirty() -> bool:
	return _dirty


# ─── Helpers ───────────────────────────────────────────────────────────

func _get_current_anchor(e: Dictionary) -> Vector2:
	if e.has("anchor_ratio"):
		var ar: Array = e["anchor_ratio"]
		var region: Array = e.get("region", [])
		var w: float
		var h: float
		if region.size() == 4:
			w = float(region[2])
			h = float(region[3])
		else:
			w = 16.0
			h = 16.0
		return Vector2(w * float(ar[0]), h * float(ar[1]))
	var a: Array = e.get("anchor", [0, 0])
	return Vector2(float(a[0]), float(a[1]))


func _get_current_scale(e: Dictionary) -> Vector2:
	if e.has("target_width_tiles"):
		var region: Array = e.get("region", [])
		var img_w: float = float(region[2]) if region.size() == 4 else 16.0
		if img_w > 0:
			var s: float = (float(e["target_width_tiles"]) * TILE_PX) / img_w
			return Vector2(s, s)
	var s: Array = e.get("scale", [1.0, 1.0])
	return Vector2(float(s[0]), float(s[1]))


func _anchor_to_cell(e: Dictionary) -> Vector2i:
	var anchor: Vector2 = _get_current_anchor(e)
	var region: Array = e.get("region", [])
	var ox: float = float(region[0]) if region.size() == 4 else 0.0
	var oy: float = float(region[1]) if region.size() == 4 else 0.0
	var step: int = TILE_PX + gutter
	return Vector2i(int((ox + anchor.x) / step), int((oy + anchor.y) / step))


func _rider_offset_to_cell(e: Dictionary) -> Vector2i:
	var anchor: Vector2 = _get_current_anchor(e)
	var scale: Vector2 = _get_current_scale(e)
	var ro: Array = e.get("rider_offset", [0, -12])
	# rider_offset is in native (post-scale) pixels, convert back to sheet pixels.
	var sheet_offset := Vector2(float(ro[0]), float(ro[1]))
	if scale.x > 0:
		sheet_offset /= scale
	var abs_px: Vector2 = anchor + sheet_offset
	var region: Array = e.get("region", [])
	var ox: float = float(region[0]) if region.size() == 4 else 0.0
	var oy: float = float(region[1]) if region.size() == 4 else 0.0
	var step: int = TILE_PX + gutter
	return Vector2i(int((ox + abs_px.x) / step), int((oy + abs_px.y) / step))


func _section_label(text: String) -> VBoxContainer:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	var sep := HSeparator.new()
	var box := VBoxContainer.new()
	box.add_child(sep)
	box.add_child(lbl)
	return box


func _label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl


func _spin(lo: int, hi: int, initial: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.value = initial
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb


func _spin_f(lo: float, hi: float, initial: float, step: float = 0.1) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value = initial
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb
