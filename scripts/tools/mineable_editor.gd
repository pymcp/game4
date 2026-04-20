## MineableEditor
##
## Custom panel for the SpritePicker that edits `resources/mineables.json`.
## Provides a resource list, property editor, sprite picker integration,
## and biome summary view.
class_name MineableEditor
extends VBoxContainer

signal dirty_changed  ## Emitted when edits are made.
signal request_sprite_pick(resource_id: StringName)  ## Ask SpritePicker to activate atlas picking.

const _SHEET_PATH := "res://assets/tiles/roguelike/overworld_sheet.png"
const TILE_PX := 16
const TILE_GUTTER := 1

var _data: Dictionary = {}  ## Full JSON data (resources + items).
var _selected_id: StringName = &""
var _dirty: bool = false

# UI refs.
var _res_list: ItemList = null
var _prop_panel: ScrollContainer = null
var _biome_tab: ScrollContainer = null
var _tab_bar: TabBar = null
var _stack: Control = null  ## Holds prop_panel and biome_tab, only one visible.

# Property widgets (resource editor).
var _name_edit: LineEdit = null
var _id_edit: LineEdit = null
var _hp_spin: SpinBox = null
var _tall_check: CheckBox = null
var _pick_check: CheckBox = null
var _sprites_label: Label = null
var _sprites_container: HBoxContainer = null
var _drops_container: VBoxContainer = null
var _biome_container: VBoxContainer = null
var _add_btn: Button = null
var _del_btn: Button = null

# Track which resource is being sprite-picked.
var _picking_for: StringName = &""


func _ready() -> void:
	_data = MineableRegistry.get_raw_data().duplicate(true)
	_build_ui()
	_populate_list()
	if _res_list.item_count > 0:
		_res_list.select(0)
		_on_resource_selected(0)


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Top: tab bar to switch between Resource Editor and Biome Summary.
	_tab_bar = TabBar.new()
	_tab_bar.add_tab("Resource Editor")
	_tab_bar.add_tab("Biome Summary")
	_tab_bar.tab_changed.connect(_on_tab_changed)
	add_child(_tab_bar)

	# Main split: list on left, content on right.
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 180
	add_child(split)

	# Left: resource list + add/delete buttons.
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left)

	_res_list = ItemList.new()
	_res_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_res_list.item_selected.connect(_on_resource_selected)
	left.add_child(_res_list)

	var btn_row := HBoxContainer.new()
	_add_btn = Button.new()
	_add_btn.text = "Add"
	_add_btn.pressed.connect(_on_add_resource)
	btn_row.add_child(_add_btn)
	_del_btn = Button.new()
	_del_btn.text = "Delete"
	_del_btn.pressed.connect(_on_delete_resource)
	btn_row.add_child(_del_btn)
	left.add_child(btn_row)

	# Right: stacked panels (only one visible at a time).
	_stack = Control.new()
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_stack)

	_prop_panel = _build_prop_panel()
	_stack.add_child(_prop_panel)

	_biome_tab = _build_biome_tab()
	_biome_tab.visible = false
	_stack.add_child(_biome_tab)


func _build_prop_panel() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Display Name
	vb.add_child(_make_label("Display Name"))
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(_on_name_changed)
	vb.add_child(_name_edit)

	# Ref ID (read-only after creation)
	vb.add_child(_make_label("Ref ID"))
	_id_edit = LineEdit.new()
	_id_edit.editable = false
	vb.add_child(_id_edit)

	# HP
	var hp_row := HBoxContainer.new()
	hp_row.add_child(_make_label("HP"))
	_hp_spin = SpinBox.new()
	_hp_spin.min_value = 1
	_hp_spin.max_value = 100
	_hp_spin.value_changed.connect(_on_hp_changed)
	hp_row.add_child(_hp_spin)
	vb.add_child(hp_row)

	# Flags
	var flag_row := HBoxContainer.new()
	_tall_check = CheckBox.new()
	_tall_check.text = "Tall (2-cell)"
	_tall_check.toggled.connect(_on_tall_toggled)
	flag_row.add_child(_tall_check)
	_pick_check = CheckBox.new()
	_pick_check.text = "Pickaxe Bonus"
	_pick_check.toggled.connect(_on_pick_toggled)
	flag_row.add_child(_pick_check)
	vb.add_child(flag_row)

	# Sprites
	vb.add_child(_make_label("Sprites (click atlas to add/remove)"))
	_sprites_label = Label.new()
	_sprites_label.text = "0 sprites"
	vb.add_child(_sprites_label)
	_sprites_container = HBoxContainer.new()
	_sprites_container.add_theme_constant_override("separation", 2)
	vb.add_child(_sprites_container)

	# Biome weights
	vb.add_child(_make_label("Biome Spawn Weights"))
	_biome_container = VBoxContainer.new()
	vb.add_child(_biome_container)

	# Drops
	vb.add_child(_make_label("Drops"))
	_drops_container = VBoxContainer.new()
	vb.add_child(_drops_container)

	var add_drop_btn := Button.new()
	add_drop_btn.text = "+ Add Drop"
	add_drop_btn.pressed.connect(_on_add_drop)
	vb.add_child(add_drop_btn)

	scroll.add_child(vb)
	return scroll


func _build_biome_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)
	return scroll


func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	return l


# ─── List population ──────────────────────────────────────────────────

func _populate_list() -> void:
	_res_list.clear()
	var res: Dictionary = _data.get("resources", {})
	var keys := res.keys()
	keys.sort()
	for k in keys:
		var entry: Dictionary = res[k]
		_res_list.add_item(entry.get("display_name", k))
		_res_list.set_item_metadata(_res_list.item_count - 1, k)


func _on_resource_selected(idx: int) -> void:
	if idx < 0 or idx >= _res_list.item_count:
		_selected_id = &""
		return
	_selected_id = StringName(_res_list.get_item_metadata(idx))
	_refresh_props()


func _refresh_props() -> void:
	var res: Dictionary = _data.get("resources", {})
	var entry: Variant = res.get(String(_selected_id), null)
	if entry == null:
		return
	var e: Dictionary = entry

	_name_edit.text = e.get("display_name", "")
	_id_edit.text = e.get("ref_id", String(_selected_id))
	_hp_spin.value = float(e.get("hp", 1))
	_tall_check.button_pressed = bool(e.get("is_tall", false))
	_pick_check.button_pressed = bool(e.get("is_pickaxe_bonus", false))

	# Sprites preview
	var sprites: Array = e.get("sprites", [])
	_sprites_label.text = "%d sprite(s)" % sprites.size()
	_refresh_sprite_thumbnails(sprites)

	# Biome weights
	_refresh_biome_weights(e.get("biome_weights", {}))

	# Drops
	_refresh_drops(e.get("drops", []))


func _refresh_sprite_thumbnails(sprites: Array) -> void:
	for c in _sprites_container.get_children():
		c.queue_free()
	var tex: Texture2D = load(_SHEET_PATH) as Texture2D
	if tex == null:
		return
	for s in sprites:
		if not (s is Array) or s.size() < 2:
			continue
		var cell := Vector2i(int(s[0]), int(s[1]))
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		var step := TILE_PX + TILE_GUTTER
		atlas.region = Rect2(float(cell.x * step), float(cell.y * step),
				float(TILE_PX), float(TILE_PX))
		var rect := TextureRect.new()
		rect.texture = atlas
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(32, 32)
		_sprites_container.add_child(rect)


func _refresh_biome_weights(weights: Dictionary) -> void:
	for c in _biome_container.get_children():
		c.queue_free()
	var all_biomes: Array = ["grass", "desert", "snow", "swamp", "rocky"]
	for b in all_biomes:
		var row := HBoxContainer.new()
		var cb := CheckBox.new()
		cb.text = b
		cb.button_pressed = weights.has(b)
		cb.toggled.connect(_on_biome_toggle.bind(b))
		row.add_child(cb)
		var spin := SpinBox.new()
		spin.min_value = 0.0
		spin.max_value = 1.0
		spin.step = 0.001
		spin.value = float(weights.get(b, 0.0))
		spin.custom_minimum_size.x = 90
		spin.value_changed.connect(_on_biome_weight_changed.bind(b))
		row.add_child(spin)
		_biome_container.add_child(row)


func _refresh_drops(drops: Array) -> void:
	for c in _drops_container.get_children():
		c.queue_free()
	for i in drops.size():
		var d: Dictionary = drops[i]
		var row := HBoxContainer.new()
		var id_edit := LineEdit.new()
		id_edit.text = d.get("item_id", "")
		id_edit.placeholder_text = "item_id"
		id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		id_edit.text_changed.connect(_on_drop_id_changed.bind(i))
		row.add_child(id_edit)
		var count_spin := SpinBox.new()
		count_spin.min_value = 1
		count_spin.max_value = 99
		count_spin.value = float(d.get("count", 1))
		count_spin.value_changed.connect(_on_drop_count_changed.bind(i))
		row.add_child(count_spin)
		var del := Button.new()
		del.text = "×"
		del.pressed.connect(_on_delete_drop.bind(i))
		row.add_child(del)
		_drops_container.add_child(row)


# ─── Property change handlers ─────────────────────────────────────────

func _get_entry() -> Dictionary:
	var res: Dictionary = _data.get("resources", {})
	return res.get(String(_selected_id), {})

func _mark_dirty_internal() -> void:
	_dirty = true
	dirty_changed.emit()

func _on_name_changed(new_text: String) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	e["display_name"] = new_text
	_mark_dirty_internal()
	# Update list item text.
	for i in _res_list.item_count:
		if _res_list.get_item_metadata(i) == String(_selected_id):
			_res_list.set_item_text(i, new_text)
			break

func _on_hp_changed(val: float) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	e["hp"] = int(val)
	_mark_dirty_internal()

func _on_tall_toggled(pressed: bool) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	e["is_tall"] = pressed
	_mark_dirty_internal()

func _on_pick_toggled(pressed: bool) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	e["is_pickaxe_bonus"] = pressed
	_mark_dirty_internal()

func _on_biome_toggle(pressed: bool, biome: String) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	var bw: Dictionary = e.get("biome_weights", {})
	if pressed:
		if not bw.has(biome):
			bw[biome] = 0.01
	else:
		bw.erase(biome)
	e["biome_weights"] = bw
	_mark_dirty_internal()

func _on_biome_weight_changed(val: float, biome: String) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	var bw: Dictionary = e.get("biome_weights", {})
	if val > 0.0:
		bw[biome] = val
	else:
		bw.erase(biome)
	e["biome_weights"] = bw
	_mark_dirty_internal()

func _on_drop_id_changed(new_text: String, idx: int) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	var drops: Array = e.get("drops", [])
	if idx >= 0 and idx < drops.size():
		drops[idx]["item_id"] = new_text
		_mark_dirty_internal()

func _on_drop_count_changed(val: float, idx: int) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	var drops: Array = e.get("drops", [])
	if idx >= 0 and idx < drops.size():
		drops[idx]["count"] = int(val)
		_mark_dirty_internal()

func _on_add_drop() -> void:
	var e := _get_entry()
	if e.is_empty(): return
	var drops: Array = e.get("drops", [])
	drops.append({"item_id": "", "count": 1})
	e["drops"] = drops
	_mark_dirty_internal()
	_refresh_drops(drops)

func _on_delete_drop(idx: int) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	var drops: Array = e.get("drops", [])
	if idx >= 0 and idx < drops.size():
		drops.remove_at(idx)
		_mark_dirty_internal()
		_refresh_drops(drops)


# ─── Add / Delete resources ───────────────────────────────────────────

func _on_add_resource() -> void:
	var res: Dictionary = _data.get("resources", {})
	var new_id := "new_resource"
	var counter := 1
	while res.has(new_id):
		counter += 1
		new_id = "new_resource_%d" % counter
	res[new_id] = {
		"display_name": "New Resource",
		"ref_id": new_id,
		"is_tall": false,
		"is_pickaxe_bonus": false,
		"hp": 1,
		"sprites": [],
		"biome_weights": {},
		"drops": [],
	}
	_data["resources"] = res
	_mark_dirty_internal()
	_populate_list()
	# Select the new entry.
	for i in _res_list.item_count:
		if _res_list.get_item_metadata(i) == new_id:
			_res_list.select(i)
			_on_resource_selected(i)
			break

func _on_delete_resource() -> void:
	if _selected_id == &"":
		return
	var res: Dictionary = _data.get("resources", {})
	res.erase(String(_selected_id))
	_data["resources"] = res
	_selected_id = &""
	_mark_dirty_internal()
	_populate_list()
	if _res_list.item_count > 0:
		_res_list.select(0)
		_on_resource_selected(0)


# ─── Tab switching ────────────────────────────────────────────────────

func _on_tab_changed(tab: int) -> void:
	_prop_panel.visible = (tab == 0)
	_biome_tab.visible = (tab == 1)
	if tab == 1:
		_refresh_biome_summary()


# ─── Biome Summary ────────────────────────────────────────────────────

func _refresh_biome_summary() -> void:
	# Clear.
	# _biome_tab is a ScrollContainer with a VBoxContainer child.
	var inner: VBoxContainer = null
	for c in _biome_tab.get_children():
		if c is VBoxContainer:
			inner = c
			break
	if inner == null:
		inner = VBoxContainer.new()
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_biome_tab.add_child(inner)
	for c in inner.get_children():
		c.queue_free()

	var res: Dictionary = _data.get("resources", {})
	var all_biomes: Array = ["grass", "desert", "snow", "swamp", "rocky"]
	var tex: Texture2D = load(_SHEET_PATH) as Texture2D

	for biome in all_biomes:
		var header := Label.new()
		header.text = "── %s ──" % biome.capitalize()
		header.add_theme_font_size_override("font_size", 15)
		header.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
		inner.add_child(header)

		var found := false
		for rid in res:
			var entry: Dictionary = res[rid]
			var bw: Dictionary = entry.get("biome_weights", {})
			if not bw.has(biome):
				continue
			found = true
			var row := HBoxContainer.new()
			# Thumbnail
			var sprites: Array = entry.get("sprites", [])
			if tex != null and sprites.size() > 0 and sprites[0] is Array and sprites[0].size() >= 2:
				var cell := Vector2i(int(sprites[0][0]), int(sprites[0][1]))
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				var step := TILE_PX + TILE_GUTTER
				atlas.region = Rect2(float(cell.x * step), float(cell.y * step),
						float(TILE_PX), float(TILE_PX))
				var thumb := TextureRect.new()
				thumb.texture = atlas
				thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				thumb.custom_minimum_size = Vector2(24, 24)
				row.add_child(thumb)
			var info := Label.new()
			info.text = "%s  w=%.3f  hp=%d  drops=%d" % [
				entry.get("display_name", rid),
				float(bw[biome]),
				int(entry.get("hp", 1)),
				(entry.get("drops", []) as Array).size(),
			]
			row.add_child(info)
			inner.add_child(row)

		if not found:
			var empty := Label.new()
			empty.text = "(no mineable resources)"
			empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			inner.add_child(empty)


# ─── Sprite picking integration ───────────────────────────────────────

## Called by SpritePicker when a cell is clicked on the atlas while
## this editor is active. Toggles the cell in/out of the selected
## resource's sprites array.
func on_atlas_cell_clicked(cell: Vector2i) -> void:
	if _selected_id == &"":
		return
	var e := _get_entry()
	if e.is_empty():
		return
	var sprites: Array = e.get("sprites", [])
	var cell_arr: Array = [cell.x, cell.y]
	# Check if already present.
	var found_idx := -1
	for i in sprites.size():
		var s: Array = sprites[i]
		if s.size() >= 2 and int(s[0]) == cell.x and int(s[1]) == cell.y:
			found_idx = i
			break
	if found_idx >= 0:
		sprites.remove_at(found_idx)
	else:
		sprites.append(cell_arr)
	e["sprites"] = sprites
	_mark_dirty_internal()
	_sprites_label.text = "%d sprite(s)" % sprites.size()
	_refresh_sprite_thumbnails(sprites)

## Return marks (bound cells) for the sheet overlay.
func get_marks() -> Array:
	if _selected_id == &"":
		return []
	var e := _get_entry()
	if e.is_empty():
		return []
	var sprites: Array = e.get("sprites", [])
	var marks: Array = []
	for s in sprites:
		if s is Array and s.size() >= 2:
			marks.append({
				"cell": Vector2i(int(s[0]), int(s[1])),
				"color": Color(0.3, 1.0, 0.4, 1.0),
				"width": 3.0,
			})
	return marks


# ─── Save / Revert ────────────────────────────────────────────────────

func save() -> void:
	MineableRegistry.save_data(_data)
	# Reload the runtime caches so changes take effect immediately.
	MineableRegistry.reload()
	TilesetCatalog._tall_decoration_cache.clear()
	TilesetCatalog._loaded = false
	_dirty = false

func revert() -> void:
	MineableRegistry.reload()
	_data = MineableRegistry.get_raw_data().duplicate(true)
	_dirty = false
	_populate_list()
	if _res_list.item_count > 0:
		_res_list.select(0)
		_on_resource_selected(0)

func is_dirty() -> bool:
	return _dirty
