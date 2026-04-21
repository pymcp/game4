## ItemEditor
##
## Custom panel for the SpritePicker that displays and edits items from
## ItemRegistry. Shows all registered items (hardcoded + .tres overrides),
## allows editing properties, and cross-references mineables that drop
## each item.
##
## Mirrors the MineableEditor pattern: list + property panel + atlas
## sprite picking for icon overrides.
class_name ItemEditor
extends VBoxContainer

signal dirty_changed
signal navigate_to_mineable(resource_id: StringName)
signal sheet_requested(path: String)

const TILE_PX := 16
const TILE_GUTTER := 1
const ITEMS_DIR := "res://resources/items/"
const ICONS_DIR := "res://assets/icons/items/"

var sheet_path: String = "res://assets/tiles/roguelike/overworld_sheet.png"

var _items: Dictionary = {}  ## id → { all fields as Dictionary }
var _selected_id: StringName = &""
var _dirty: bool = false
var _mineable_dirty: bool = false  ## True when drop sources were modified.

# UI refs
var _item_list: ItemList = null
var _prop_panel: ScrollContainer = null

# Property widgets
var _name_edit: LineEdit = null
var _id_label: Label = null
var _desc_edit: LineEdit = null
var _stack_spin: SpinBox = null
var _power_spin: SpinBox = null
var _slot_opt: OptionButton = null
var _icon_preview: TextureRect = null
var _icon_path_label: Label = null
var _icon_cell_label: Label = null
var _icon_cell_container: HBoxContainer = null
var _drop_sources_container: VBoxContainer = null
var _add_mineable_opt: OptionButton = null
var _add_mineable_btn: Button = null


func _ready() -> void:
	_load_all_items()
	_build_ui()
	_populate_list()
	if _item_list.item_count > 0:
		_item_list.select(0)
		_on_item_selected(0)


func _load_all_items() -> void:
	_items.clear()
	ItemRegistry.reset()
	for id in ItemRegistry.all_ids():
		var def: ItemDefinition = ItemRegistry.get_item(id)
		if def == null:
			continue
		_items[id] = _def_to_dict(def)


func _def_to_dict(def: ItemDefinition) -> Dictionary:
	var sprites_and_sheet: Array = _load_atlas_sprites(def.id)
	return {
		"id": String(def.id),
		"display_name": def.display_name,
		"description": def.description,
		"stack_size": def.stack_size,
		"slot": def.slot,
		"power": def.power,
		"icon": def.icon,
		"icon_path": def.icon.resource_path if def.icon else "",
		"atlas_sprites": sprites_and_sheet[0],
		"icon_sheet": sprites_and_sheet[1],
	}


func _load_atlas_sprites(item_id: StringName) -> Array:
	## Read atlas cell coordinates + sheet from custom_sprite_cells.json.
	## Returns [sprites_array, sheet_path_string].
	var manifest_path := "res://resources/custom_sprite_cells.json"
	var default_sheet: String = sheet_path
	if not FileAccess.file_exists(manifest_path):
		return [[], ""]
	var f := FileAccess.open(manifest_path, FileAccess.READ)
	if f == null:
		return [[], ""]
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return [[], ""]
	var cells: Dictionary = (parsed as Dictionary).get("cells", {})
	if cells.has(String(item_id)):
		var entry: Variant = cells[String(item_id)]
		# New format: {"cell": [col, row], "sheet": "res://..."}
		if entry is Dictionary:
			var cell: Array = (entry as Dictionary).get("cell", [])
			var s: String = (entry as Dictionary).get("sheet", default_sheet)
			if cell.size() >= 2:
				return [[cell], s]
		# Legacy format: [col, row]
		if entry is Array:
			var cell: Array = entry as Array
			if cell.size() >= 2:
				return [[cell], default_sheet]
	return [[], ""]


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 180
	add_child(split)

	# Left: item list
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left)

	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	left.add_child(_item_list)

	# Right: property panel
	_prop_panel = _build_prop_panel()
	split.add_child(_prop_panel)


func _build_prop_panel() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Icon preview
	var icon_row := HBoxContainer.new()
	_icon_preview = TextureRect.new()
	_icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_preview.custom_minimum_size = Vector2(48, 48)
	icon_row.add_child(_icon_preview)
	var icon_info := VBoxContainer.new()
	icon_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon_path_label = Label.new()
	_icon_path_label.text = ""
	_icon_path_label.add_theme_font_size_override("font_size", 11)
	_icon_path_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	icon_info.add_child(_icon_path_label)
	icon_row.add_child(icon_info)
	vb.add_child(icon_row)

	# Display Name
	vb.add_child(_make_label("Display Name"))
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(_on_name_changed)
	vb.add_child(_name_edit)

	# ID (read-only display)
	vb.add_child(_make_label("Item ID"))
	_id_label = Label.new()
	_id_label.add_theme_font_size_override("font_size", 13)
	vb.add_child(_id_label)

	# Description
	vb.add_child(_make_label("Description"))
	_desc_edit = LineEdit.new()
	_desc_edit.text_changed.connect(_on_desc_changed)
	vb.add_child(_desc_edit)

	# Stack Size
	var stack_row := HBoxContainer.new()
	stack_row.add_child(_make_label("Stack Size"))
	_stack_spin = SpinBox.new()
	_stack_spin.min_value = 1
	_stack_spin.max_value = 999
	_stack_spin.value_changed.connect(_on_stack_changed)
	stack_row.add_child(_stack_spin)
	vb.add_child(stack_row)

	# Slot
	var slot_row := HBoxContainer.new()
	slot_row.add_child(_make_label("Slot"))
	_slot_opt = OptionButton.new()
	for s in ["NONE", "WEAPON", "TOOL", "HEAD", "BODY", "FEET"]:
		_slot_opt.add_item(s)
	_slot_opt.item_selected.connect(_on_slot_changed)
	slot_row.add_child(_slot_opt)
	vb.add_child(slot_row)

	# Power
	var power_row := HBoxContainer.new()
	power_row.add_child(_make_label("Power"))
	_power_spin = SpinBox.new()
	_power_spin.min_value = 0
	_power_spin.max_value = 100
	_power_spin.value_changed.connect(_on_power_changed)
	power_row.add_child(_power_spin)
	vb.add_child(power_row)

	# Icon from atlas (click a cell on the sheet to set)
	vb.add_child(_make_label("Icon Cell (click atlas to set)"))
	_icon_cell_label = Label.new()
	_icon_cell_label.text = "(none — click a cell on the atlas)"
	_icon_cell_label.add_theme_font_size_override("font_size", 12)
	vb.add_child(_icon_cell_label)
	_icon_cell_container = HBoxContainer.new()
	_icon_cell_container.add_theme_constant_override("separation", 4)
	vb.add_child(_icon_cell_container)

	# Dropped by (editable list of mineables that drop this item)
	vb.add_child(_make_label("Dropped By (mineables)"))
	_drop_sources_container = VBoxContainer.new()
	vb.add_child(_drop_sources_container)

	# Add-mineable row: dropdown + button
	var add_row := HBoxContainer.new()
	_add_mineable_opt = OptionButton.new()
	_add_mineable_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(_add_mineable_opt)
	_add_mineable_btn = Button.new()
	_add_mineable_btn.text = "+ Add"
	_add_mineable_btn.pressed.connect(_on_add_drop_source)
	add_row.add_child(_add_mineable_btn)
	vb.add_child(add_row)

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
	_item_list.clear()
	var keys: Array = _items.keys()
	keys.sort()
	for k in keys:
		var entry: Dictionary = _items[k]
		_item_list.add_item(entry.get("display_name", String(k)))
		_item_list.set_item_metadata(_item_list.item_count - 1, String(k))


func _on_item_selected(idx: int) -> void:
	if idx < 0 or idx >= _item_list.item_count:
		_selected_id = &""
		return
	_selected_id = StringName(_item_list.get_item_metadata(idx))
	# If this item has a per-item sheet, ask the SpritePicker to switch to it.
	var e: Dictionary = _items.get(_selected_id, {})
	var item_sheet: String = e.get("icon_sheet", "")
	if item_sheet != "":
		sheet_requested.emit(item_sheet)
	_refresh_props()


func _refresh_props() -> void:
	var entry: Variant = _items.get(_selected_id, null)
	if entry == null:
		return
	var e: Dictionary = entry

	_name_edit.text = e.get("display_name", "")
	_id_label.text = e.get("id", String(_selected_id))
	_desc_edit.text = e.get("description", "")
	_stack_spin.value = float(e.get("stack_size", 99))
	_slot_opt.selected = int(e.get("slot", 0))
	_power_spin.value = float(e.get("power", 0))

	# Icon preview
	var icon: Texture2D = e.get("icon", null) as Texture2D
	_icon_preview.texture = icon
	_icon_path_label.text = e.get("icon_path", "") if e.get("icon_path", "") != "" else "(no icon set)"

	# Icon cell (use per-item sheet if available, else current global sheet)
	var atlas_sprites: Array = e.get("atlas_sprites", [])
	var item_sheet: String = e.get("icon_sheet", "")
	_refresh_icon_cell_ui(atlas_sprites, item_sheet)

	# Dropped by
	_refresh_dropped_by()


func _refresh_icon_cell_ui(sprites: Array, item_sheet: String = "") -> void:
	for c in _icon_cell_container.get_children():
		c.queue_free()
	if sprites.is_empty():
		_icon_cell_label.text = "(none \u2014 click a cell on the atlas)"
		return
	var s: Array = sprites[0]
	if not (s is Array) or s.size() < 2:
		_icon_cell_label.text = "(invalid cell data)"
		return
	var cell := Vector2i(int(s[0]), int(s[1]))
	var display_sheet: String = item_sheet if item_sheet != "" else sheet_path
	var short_name: String = display_sheet.get_file()
	_icon_cell_label.text = "Cell [%d, %d] on %s" % [cell.x, cell.y, short_name]
	var tex: Texture2D = load(display_sheet) as Texture2D
	if tex == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var step := TILE_PX + TILE_GUTTER
	atlas.region = Rect2(float(cell.x * step), float(cell.y * step),
			float(TILE_PX), float(TILE_PX))
	var rect := TextureRect.new()
	rect.texture = atlas
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(32, 32)
	_icon_cell_container.add_child(rect)
	# Also update the main icon preview to this atlas cell.
	_icon_preview.texture = atlas


func _refresh_dropped_by() -> void:
	for c in _drop_sources_container.get_children():
		c.queue_free()
	var item_id: String = String(_selected_id)
	var mineable_data: Dictionary = MineableRegistry.get_raw_data()
	var resources: Dictionary = mineable_data.get("resources", {})
	var found := false
	var tex: Texture2D = load(sheet_path) as Texture2D
	for rid in resources:
		var entry: Dictionary = resources[rid]
		var drops: Array = entry.get("drops", [])
		for d in drops:
			if d is Dictionary and d.get("item_id", "") == item_id:
				found = true
				var row := HBoxContainer.new()
				# Thumbnail from mineable sprite
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
				var lbl := Label.new()
				lbl.text = "%s (×%d)" % [entry.get("display_name", rid), int(d.get("count", 1))]
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(lbl)
				var count_spin := SpinBox.new()
				count_spin.min_value = 1
				count_spin.max_value = 99
				count_spin.value = float(d.get("count", 1))
				count_spin.value_changed.connect(_on_drop_source_count_changed.bind(String(rid), item_id))
				row.add_child(count_spin)
				var go_btn := Button.new()
				go_btn.text = "\u2192"
				go_btn.tooltip_text = "Go to mineable: %s" % rid
				go_btn.pressed.connect(_on_navigate_mineable.bind(StringName(rid)))
				row.add_child(go_btn)
				var del := Button.new()
				del.text = "\u00d7"
				del.tooltip_text = "Remove this item from %s drops" % rid
				del.pressed.connect(_on_remove_drop_source.bind(String(rid), item_id))
				row.add_child(del)
				_drop_sources_container.add_child(row)
				break
	if not found:
		var lbl := Label.new()
		lbl.text = "(not dropped by any mineable)"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_drop_sources_container.add_child(lbl)
	# Refresh the add-mineable dropdown (exclude already-added ones).
	_refresh_add_mineable_dropdown()


func _on_navigate_mineable(resource_id: StringName) -> void:
	navigate_to_mineable.emit(resource_id)


# ─── Property change handlers ─────────────────────────────────────────

func _get_entry() -> Dictionary:
	return _items.get(_selected_id, {})


func _mark_dirty_internal() -> void:
	_dirty = true
	dirty_changed.emit()


func _on_name_changed(new_text: String) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	e["display_name"] = new_text
	_mark_dirty_internal()
	for i in _item_list.item_count:
		if _item_list.get_item_metadata(i) == String(_selected_id):
			_item_list.set_item_text(i, new_text)
			break


func _on_desc_changed(new_text: String) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	e["description"] = new_text
	_mark_dirty_internal()


func _on_stack_changed(val: float) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	e["stack_size"] = int(val)
	_mark_dirty_internal()


func _on_slot_changed(idx: int) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	e["slot"] = idx
	_mark_dirty_internal()


func _on_power_changed(val: float) -> void:
	var e := _get_entry()
	if e.is_empty(): return
	e["power"] = int(val)
	_mark_dirty_internal()


# ─── Atlas sprite picking integration ─────────────────────────────────

func on_atlas_cell_clicked(cell: Vector2i) -> void:
	if _selected_id == &"":
		return
	var e := _get_entry()
	if e.is_empty():
		return
	var sprites: Array = e.get("atlas_sprites", [])
	var cell_arr: Array = [cell.x, cell.y]
	var old_sheet: String = e.get("icon_sheet", "")
	# Toggle: if same cell AND same sheet already set, clear it; otherwise replace.
	if sprites.size() > 0 and sprites[0] is Array and sprites[0].size() >= 2:
		if int(sprites[0][0]) == cell.x and int(sprites[0][1]) == cell.y and old_sheet == sheet_path:
			sprites.clear()
			e["icon_sheet"] = ""
		else:
			sprites = [cell_arr]
			e["icon_sheet"] = sheet_path
	else:
		sprites = [cell_arr]
		e["icon_sheet"] = sheet_path
	e["atlas_sprites"] = sprites
	_mark_dirty_internal()
	_refresh_icon_cell_ui(sprites, e.get("icon_sheet", ""))


func get_marks() -> Array:
	if _selected_id == &"":
		return []
	var e := _get_entry()
	if e.is_empty():
		return []
	# Only show marks if the item's icon sheet matches the currently displayed sheet.
	var item_sheet: String = e.get("icon_sheet", "")
	if item_sheet != "" and item_sheet != sheet_path:
		return []
	var sprites: Array = e.get("atlas_sprites", [])
	var marks: Array = []
	for s in sprites:
		if s is Array and s.size() >= 2:
			marks.append({
				"cell": Vector2i(int(s[0]), int(s[1])),
				"color": Color(0.4, 0.7, 1.0, 1.0),
				"width": 3.0,
			})
	return marks


# ─── Drop source management (which mineables drop this item) ──────────

func _refresh_add_mineable_dropdown() -> void:
	_add_mineable_opt.clear()
	var item_id: String = String(_selected_id)
	var mineable_data: Dictionary = MineableRegistry.get_raw_data()
	var resources: Dictionary = mineable_data.get("resources", {})
	# Collect mineables that already drop this item.
	var already: Array = []
	for rid in resources:
		var entry: Dictionary = resources[rid]
		for d in entry.get("drops", []):
			if d is Dictionary and d.get("item_id", "") == item_id:
				already.append(String(rid))
				break
	# Populate dropdown with mineables that DON'T already drop this item.
	_add_mineable_opt.add_item("(select a mineable)")
	_add_mineable_opt.set_item_metadata(0, "")
	var rids: Array = resources.keys()
	rids.sort()
	for rid in rids:
		if String(rid) in already:
			continue
		var entry: Dictionary = resources[rid]
		var label: String = "%s (%s)" % [entry.get("display_name", rid), rid]
		_add_mineable_opt.add_item(label)
		_add_mineable_opt.set_item_metadata(_add_mineable_opt.item_count - 1, String(rid))
	_add_mineable_btn.disabled = (_add_mineable_opt.item_count <= 1)


func _on_add_drop_source() -> void:
	if _selected_id == &"" or _add_mineable_opt.item_count <= 1:
		return
	var sel_idx: int = _add_mineable_opt.selected
	if sel_idx < 0:
		return
	var rid: String = _add_mineable_opt.get_item_metadata(sel_idx)
	if rid == "":
		return
	var item_id: String = String(_selected_id)
	# Add this item to the mineable's drops in the registry data.
	var data: Dictionary = MineableRegistry.get_raw_data()
	var resources: Dictionary = data.get("resources", {})
	if not resources.has(rid):
		return
	var entry: Dictionary = resources[rid]
	var drops: Array = entry.get("drops", [])
	drops.append({"item_id": item_id, "count": 1})
	entry["drops"] = drops
	_mineable_dirty = true
	_mark_dirty_internal()
	_refresh_dropped_by()


func _on_remove_drop_source(rid: String, item_id: String) -> void:
	var data: Dictionary = MineableRegistry.get_raw_data()
	var resources: Dictionary = data.get("resources", {})
	if not resources.has(rid):
		return
	var entry: Dictionary = resources[rid]
	var drops: Array = entry.get("drops", [])
	for i in drops.size():
		var d: Dictionary = drops[i]
		if d.get("item_id", "") == item_id:
			drops.remove_at(i)
			break
	entry["drops"] = drops
	_mineable_dirty = true
	_mark_dirty_internal()
	_refresh_dropped_by()


func _on_drop_source_count_changed(val: float, rid: String, item_id: String) -> void:
	var data: Dictionary = MineableRegistry.get_raw_data()
	var resources: Dictionary = data.get("resources", {})
	if not resources.has(rid):
		return
	var entry: Dictionary = resources[rid]
	var drops: Array = entry.get("drops", [])
	for d in drops:
		if d is Dictionary and d.get("item_id", "") == item_id:
			d["count"] = int(val)
			break
	_mineable_dirty = true
	_mark_dirty_internal()


# ─── Save / Revert ────────────────────────────────────────────────────

func save() -> void:
	# Save each modified item as a .tres override.
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(ITEMS_DIR))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(ICONS_DIR))
	# Also update custom_sprite_cells.json with atlas sprite mappings.
	var manifest: Dictionary = _load_manifest()
	var sheet_images: Dictionary = {}   # sheet_path → Image cache
	for id in _items:
		var e: Dictionary = _items[id]
		var atlas_sprites: Array = e.get("atlas_sprites", [])
		var item_sheet: String = e.get("icon_sheet", "")
		# Extract icon from atlas cell if set.
		if atlas_sprites.size() > 0 and atlas_sprites[0] is Array and atlas_sprites[0].size() >= 2:
			var cell: Array = atlas_sprites[0]
			# New manifest format: store cell + sheet per item.
			manifest["cells"][String(id)] = {
				"cell": cell,
				"sheet": item_sheet if item_sheet != "" else sheet_path,
			}
			# Extract and save the 16×16 icon PNG from the per-item sheet.
			var extract_sheet: String = item_sheet if item_sheet != "" else sheet_path
			if not sheet_images.has(extract_sheet):
				sheet_images[extract_sheet] = Image.load_from_file(
					ProjectSettings.globalize_path(extract_sheet))
			var sheet_tex: Image = sheet_images[extract_sheet] as Image
			if sheet_tex != null:
				var step := TILE_PX + TILE_GUTTER
				var cx: int = int(cell[0]) * step
				var cy: int = int(cell[1]) * step
				var icon_img := Image.create(TILE_PX, TILE_PX, false, Image.FORMAT_RGBA8)
				icon_img.blit_rect(sheet_tex, Rect2i(cx, cy, TILE_PX, TILE_PX), Vector2i.ZERO)
				var icon_path: String = ICONS_DIR + String(id) + ".png"
				icon_img.save_png(ProjectSettings.globalize_path(icon_path))
				e["icon_path"] = icon_path
		else:
			manifest["cells"].erase(String(id))
		_save_item_tres(StringName(id), e)
	_save_manifest(manifest)
	# Save mineable data if drop sources were modified.
	if _mineable_dirty:
		MineableRegistry.save_data(MineableRegistry.get_raw_data())
		_mineable_dirty = false
	ItemRegistry.reset()
	_dirty = false


func _save_item_tres(id: StringName, e: Dictionary) -> void:
	var def := ItemDefinition.new()
	def.id = id
	def.display_name = e.get("display_name", "")
	def.description = e.get("description", "")
	def.stack_size = int(e.get("stack_size", 99))
	def.slot = int(e.get("slot", 0)) as ItemDefinition.Slot
	def.power = int(e.get("power", 0))
	# Set icon from the extracted PNG if available, else preserve existing.
	var icon_path: String = e.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		def.icon = load(icon_path) as Texture2D
	else:
		var existing_icon: Texture2D = e.get("icon", null) as Texture2D
		if existing_icon != null:
			def.icon = existing_icon
	var path: String = ITEMS_DIR + String(id) + ".tres"
	ResourceSaver.save(def, path)


func _load_manifest() -> Dictionary:
	var manifest_path := "res://resources/custom_sprite_cells.json"
	if not FileAccess.file_exists(manifest_path):
		return {"cells": {}}
	var f := FileAccess.open(manifest_path, FileAccess.READ)
	if f == null:
		return {"cells": {}}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return {"cells": {}}
	return parsed as Dictionary


func _save_manifest(manifest: Dictionary) -> void:
	var manifest_path := "res://resources/custom_sprite_cells.json"
	var f := FileAccess.open(manifest_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(manifest, "  ", true))
	f.close()


func revert() -> void:
	ItemRegistry.reset()
	_load_all_items()
	_dirty = false
	_populate_list()
	if _item_list.item_count > 0:
		_item_list.select(0)
		_on_item_selected(0)


func is_dirty() -> bool:
	return _dirty


## Select an item by ID (used by cross-reference navigation).
func select_item(item_id: StringName) -> void:
	for i in _item_list.item_count:
		if _item_list.get_item_metadata(i) == String(item_id):
			_item_list.select(i)
			_on_item_selected(i)
			return
