## ItemEditor
##
## Full-featured panel for editing items in `items.json` via the SpritePicker.
## Phase 6 rewrite: CRUD, parent/inheritance UI, all equipment property widgets,
## equipment sprite picking, description preview, and balance overview table.
##
## Data flow: reads raw JSON via `ItemRegistry.get_raw_data()`, edits an
## in-memory dictionary, then writes back via `ItemRegistry.save_data()`.
class_name ItemEditor
extends VBoxContainer

signal dirty_changed
signal navigate_to_mineable(resource_id: StringName)
signal sheet_requested(path: String)

const TILE_PX := 16
const TILE_GUTTER := 1
const CHARACTER_SHEET := "res://assets/characters/roguelike/characters_sheet.png"

var sheet_path: String = "res://assets/tiles/roguelike/overworld_sheet.png"

## Raw items.json data (id → dict). Edits mutate this directly.
var _items: Dictionary = {}
var _selected_id: StringName = &""
var _dirty: bool = false
var _mineable_dirty: bool = false

## Which equipment-sprite field we're currently picking for.
## Empty string when normal icon picking mode.
var _sprite_pick_mode: String = ""  # "", "weapon_sprite", "armor_sprite", "shield_sprite"

# ─── UI refs ──────────────────────────────────────────────────────────
var _item_list: ItemList = null
var _prop_scroll: ScrollContainer = null
var _tab_bar: TabBar = null
var _prop_panel: VBoxContainer = null  # property editor widgets
var _table_scroll: ScrollContainer = null  # balance overview

# CRUD
var _add_btn: Button = null
var _del_btn: Button = null
var _id_edit: LineEdit = null
var _rename_btn: Button = null

# Core properties
var _name_edit: LineEdit = null
var _parent_opt: OptionButton = null
var _inherit_label: Label = null
var _desc_flavor_edit: LineEdit = null
var _desc_preview: Label = null
var _stack_spin: SpinBox = null
var _power_spin: SpinBox = null
var _slot_opt: OptionButton = null

# Equipment properties
var _rarity_opt: OptionButton = null
var _hands_spin: SpinBox = null
var _attack_type_opt: OptionButton = null
var _weapon_cat_opt: OptionButton = null
var _attack_speed_spin: SpinBox = null
var _reach_spin: SpinBox = null
var _knockback_spin: SpinBox = null
var _element_opt: OptionButton = null
var _tier_edit: LineEdit = null
var _set_id_edit: LineEdit = null
var _tint_picker: ColorPickerButton = null

# Stat bonus spinboxes: { StringName → SpinBox }
var _stat_spins: Dictionary = {}
const _STAT_NAMES: Array[StringName] = [
	&"strength", &"speed", &"defense", &"dexterity", &"charisma", &"wisdom"
]

# Equipment sprite picking
var _weapon_sprite_btn: Button = null
var _armor_sprite_btn: Button = null
var _shield_sprite_btn: Button = null
var _weapon_sprite_label: Label = null
var _armor_sprite_label: Label = null
var _shield_sprite_label: Label = null

# Icon
var _icon_preview: TextureRect = null
var _icon_cell_label: Label = null

# Drop sources
var _drop_sources_container: VBoxContainer = null
var _add_mineable_opt: OptionButton = null
var _add_mineable_btn: Button = null

# Balance table
var _table_grid: GridContainer = null

# Enum labels for display
const _SLOT_LABELS: Array[String] = ["NONE", "WEAPON", "TOOL", "HEAD", "BODY", "FEET", "OFF_HAND"]
const _RARITY_LABELS: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const _ATTACK_TYPE_LABELS: Array[String] = ["None", "Melee", "Ranged"]
const _WEAPON_CAT_LABELS: Array[String] = ["None", "Sword", "Axe", "Spear", "Bow", "Staff", "Dagger"]
const _ELEMENT_LABELS: Array[String] = ["None", "Fire", "Ice", "Lightning", "Poison"]

# Reverse maps: enum string → index for OptionButtons
const _SLOT_STR_MAP: Dictionary = {
	"none": 0, "weapon": 1, "tool": 2, "head": 3, "body": 4, "feet": 5, "off_hand": 6
}
const _RARITY_STR_MAP: Dictionary = {
	"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4
}
const _ATTACK_TYPE_STR_MAP: Dictionary = {
	"none": 0, "melee": 1, "ranged": 2
}
const _WEAPON_CAT_STR_MAP: Dictionary = {
	"none": 0, "sword": 1, "axe": 2, "spear": 3, "bow": 4, "staff": 5, "dagger": 6
}
const _ELEMENT_STR_MAP: Dictionary = {
	"none": 0, "fire": 1, "ice": 2, "lightning": 3, "poison": 4
}


func _ready() -> void:
	_load_data()
	_build_ui()
	_populate_list()
	if _item_list.item_count > 0:
		_item_list.select(0)
		_on_item_selected(0)


func _load_data() -> void:
	ItemRegistry.reset()
	_items = ItemRegistry.get_raw_data().duplicate(true)


# ═══════════════════════════════════════════════════════════════════════
#  UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Tab bar: Properties | Balance Table
	_tab_bar = TabBar.new()
	_tab_bar.add_tab("Properties")
	_tab_bar.add_tab("Balance Table")
	_tab_bar.tab_changed.connect(_on_tab_changed)
	add_child(_tab_bar)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 180
	add_child(split)

	# Left: item list + CRUD buttons
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left)

	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	left.add_child(_item_list)

	var btn_row := HBoxContainer.new()
	_add_btn = Button.new()
	_add_btn.text = "+ Add"
	_add_btn.pressed.connect(_on_add_item)
	btn_row.add_child(_add_btn)
	_del_btn = Button.new()
	_del_btn.text = "Delete"
	_del_btn.pressed.connect(_on_delete_item)
	btn_row.add_child(_del_btn)
	left.add_child(btn_row)

	# Right: stacked panels
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right)

	# Property editor (tab 0)
	_prop_scroll = _build_prop_panel()
	right.add_child(_prop_scroll)

	# Balance table (tab 1)
	_table_scroll = _build_balance_table()
	_table_scroll.visible = false
	right.add_child(_table_scroll)


func _on_tab_changed(idx: int) -> void:
	_prop_scroll.visible = (idx == 0)
	_item_list.get_parent().visible = (idx == 0)
	_table_scroll.visible = (idx == 1)
	if idx == 1:
		_refresh_balance_table()


# ─── Property Panel ───────────────────────────────────────────────────

func _build_prop_panel() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_prop_panel = VBoxContainer.new()
	_prop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# --- ID + rename ---
	var id_row := HBoxContainer.new()
	id_row.add_child(_make_label("Item ID"))
	_id_edit = LineEdit.new()
	_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_id_edit.editable = false
	id_row.add_child(_id_edit)
	_rename_btn = Button.new()
	_rename_btn.text = "Rename"
	_rename_btn.pressed.connect(_on_rename_item)
	id_row.add_child(_rename_btn)
	_prop_panel.add_child(id_row)

	# --- Parent / inheritance ---
	_prop_panel.add_child(_make_label("Parent (inheritance)"))
	_parent_opt = OptionButton.new()
	_parent_opt.item_selected.connect(_on_parent_changed)
	_prop_panel.add_child(_parent_opt)
	_inherit_label = Label.new()
	_inherit_label.add_theme_font_size_override("font_size", 11)
	_inherit_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	_prop_panel.add_child(_inherit_label)

	# --- Icon preview ---
	var icon_row := HBoxContainer.new()
	_icon_preview = TextureRect.new()
	_icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_preview.custom_minimum_size = Vector2(48, 48)
	icon_row.add_child(_icon_preview)
	_icon_cell_label = Label.new()
	_icon_cell_label.add_theme_font_size_override("font_size", 11)
	icon_row.add_child(_icon_cell_label)
	_prop_panel.add_child(icon_row)

	# --- Display Name ---
	_prop_panel.add_child(_make_label("Display Name"))
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(func(t): _set_field("display_name", t))
	_prop_panel.add_child(_name_edit)

	# --- Core stats row ---
	_prop_panel.add_child(_make_sep())
	_prop_panel.add_child(_make_label("Core Properties"))

	_slot_opt = _add_opt_row("Slot", _SLOT_LABELS, func(i): _set_field("slot", _SLOT_LABELS[i].to_lower()))
	_power_spin = _add_spin_row("Power", 0, 100, 1, func(v): _set_field("power", int(v)))
	_stack_spin = _add_spin_row("Stack Size", 1, 999, 1, func(v): _set_field("stack_size", int(v)))
	_rarity_opt = _add_opt_row("Rarity", _RARITY_LABELS, func(i): _set_field("rarity", _RARITY_LABELS[i].to_lower()))

	# --- Combat ---
	_prop_panel.add_child(_make_sep())
	_prop_panel.add_child(_make_label("Combat"))

	_hands_spin = _add_spin_row("Hands", 1, 2, 1, func(v): _set_field("hands", int(v)))
	_attack_type_opt = _add_opt_row("Attack Type", _ATTACK_TYPE_LABELS, func(i): _set_field("attack_type", _ATTACK_TYPE_LABELS[i].to_lower()))
	_weapon_cat_opt = _add_opt_row("Weapon Category", _WEAPON_CAT_LABELS, func(i): _set_field("weapon_category", _WEAPON_CAT_LABELS[i].to_lower()))
	_attack_speed_spin = _add_spin_row("Attack Speed", 0.0, 3.0, 0.05, func(v): _set_field("attack_speed", snappedf(v, 0.01)))
	_reach_spin = _add_spin_row("Reach", 0, 200, 1, func(v): _set_field("reach", int(v)))
	_knockback_spin = _add_spin_row("Knockback", 0, 100, 1, func(v): _set_field("knockback", int(v)))
	_element_opt = _add_opt_row("Element", _ELEMENT_LABELS, func(i): _set_field("element", _ELEMENT_LABELS[i].to_lower()))

	# --- Tier / Set ---
	_prop_panel.add_child(_make_sep())
	_prop_panel.add_child(_make_label("Tier & Set"))

	var tier_row := HBoxContainer.new()
	tier_row.add_child(_make_label("Tier"))
	_tier_edit = LineEdit.new()
	_tier_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tier_edit.text_changed.connect(func(t): _set_field("tier", t))
	tier_row.add_child(_tier_edit)
	_prop_panel.add_child(tier_row)

	var set_row := HBoxContainer.new()
	set_row.add_child(_make_label("Set ID"))
	_set_id_edit = LineEdit.new()
	_set_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_id_edit.text_changed.connect(func(t): _set_field("set_id", t))
	set_row.add_child(_set_id_edit)
	_prop_panel.add_child(set_row)

	# --- Armor Tint ---
	var tint_row := HBoxContainer.new()
	tint_row.add_child(_make_label("Armor Tint"))
	_tint_picker = ColorPickerButton.new()
	_tint_picker.custom_minimum_size = Vector2(40, 24)
	_tint_picker.color_changed.connect(func(c: Color):
		_set_field("armor_tint", [c.r, c.g, c.b, c.a]))
	tint_row.add_child(_tint_picker)
	_prop_panel.add_child(tint_row)

	# --- Stat Bonuses ---
	_prop_panel.add_child(_make_sep())
	_prop_panel.add_child(_make_label("Stat Bonuses"))

	for sn in _STAT_NAMES:
		var row := HBoxContainer.new()
		row.add_child(_make_label(String(sn).capitalize()))
		var spin := SpinBox.new()
		spin.min_value = -10
		spin.max_value = 20
		spin.step = 1
		var stat_name: StringName = sn
		spin.value_changed.connect(func(v): _on_stat_bonus_changed(stat_name, int(v)))
		row.add_child(spin)
		_stat_spins[sn] = spin
		_prop_panel.add_child(row)

	# --- Equipment Sprite Picking ---
	_prop_panel.add_child(_make_sep())
	_prop_panel.add_child(_make_label("Equipment Sprites (click atlas to set)"))

	_weapon_sprite_btn = Button.new()
	_weapon_sprite_btn.text = "Pick Weapon Sprite"
	_weapon_sprite_btn.pressed.connect(_on_pick_weapon_sprite)
	_weapon_sprite_label = Label.new()
	_weapon_sprite_label.add_theme_font_size_override("font_size", 11)
	var ws_row := HBoxContainer.new()
	ws_row.add_child(_weapon_sprite_btn)
	ws_row.add_child(_weapon_sprite_label)
	_prop_panel.add_child(ws_row)

	_armor_sprite_btn = Button.new()
	_armor_sprite_btn.text = "Pick Armor Sprite"
	_armor_sprite_btn.pressed.connect(_on_pick_armor_sprite)
	_armor_sprite_label = Label.new()
	_armor_sprite_label.add_theme_font_size_override("font_size", 11)
	var as_row := HBoxContainer.new()
	as_row.add_child(_armor_sprite_btn)
	as_row.add_child(_armor_sprite_label)
	_prop_panel.add_child(as_row)

	_shield_sprite_btn = Button.new()
	_shield_sprite_btn.text = "Pick Shield Sprite"
	_shield_sprite_btn.pressed.connect(_on_pick_shield_sprite)
	_shield_sprite_label = Label.new()
	_shield_sprite_label.add_theme_font_size_override("font_size", 11)
	var ss_row := HBoxContainer.new()
	ss_row.add_child(_shield_sprite_btn)
	ss_row.add_child(_shield_sprite_label)
	_prop_panel.add_child(ss_row)

	# --- Description ---
	_prop_panel.add_child(_make_sep())
	_prop_panel.add_child(_make_label("Description"))

	_desc_flavor_edit = LineEdit.new()
	_desc_flavor_edit.placeholder_text = "Flavor text..."
	_desc_flavor_edit.text_changed.connect(func(t): _set_field("description_flavor", t))
	_prop_panel.add_child(_desc_flavor_edit)

	_prop_panel.add_child(_make_label("Generated Preview"))
	_desc_preview = Label.new()
	_desc_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_preview.add_theme_font_size_override("font_size", 12)
	_desc_preview.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	_desc_preview.custom_minimum_size = Vector2(0, 40)
	_prop_panel.add_child(_desc_preview)

	# --- Dropped by (mineables) ---
	_prop_panel.add_child(_make_sep())
	_prop_panel.add_child(_make_label("Dropped By (mineables)"))
	_drop_sources_container = VBoxContainer.new()
	_prop_panel.add_child(_drop_sources_container)

	var add_row := HBoxContainer.new()
	_add_mineable_opt = OptionButton.new()
	_add_mineable_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(_add_mineable_opt)
	_add_mineable_btn = Button.new()
	_add_mineable_btn.text = "+ Add"
	_add_mineable_btn.pressed.connect(_on_add_drop_source)
	add_row.add_child(_add_mineable_btn)
	_prop_panel.add_child(add_row)

	scroll.add_child(_prop_panel)
	return scroll


# ─── Widget helpers ───────────────────────────────────────────────────

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	return l


func _make_sep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 6)
	return s


func _add_spin_row(label: String, lo: float, hi: float, step: float,
		cb: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_child(_make_label(label))
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.step = step
	spin.value_changed.connect(cb)
	row.add_child(spin)
	_prop_panel.add_child(row)
	return spin


func _add_opt_row(label: String, items: Array, cb: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_child(_make_label(label))
	var opt := OptionButton.new()
	for item_text in items:
		opt.add_item(item_text)
	opt.item_selected.connect(cb)
	row.add_child(opt)
	_prop_panel.add_child(row)
	return opt


# ═══════════════════════════════════════════════════════════════════════
#  LIST + SELECTION
# ═══════════════════════════════════════════════════════════════════════

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
	_refresh_props()


func select_item(item_id: StringName) -> void:
	for i in _item_list.item_count:
		if _item_list.get_item_metadata(i) == String(item_id):
			_item_list.select(i)
			_on_item_selected(i)
			return


# ═══════════════════════════════════════════════════════════════════════
#  PROPERTY REFRESH (selection → widgets)
# ═══════════════════════════════════════════════════════════════════════

func _refresh_props() -> void:
	var e: Dictionary = _items.get(String(_selected_id), {})
	if e.is_empty():
		return

	_id_edit.text = String(_selected_id)

	# Parent
	_refresh_parent_opt()
	_refresh_inherit_label()

	_name_edit.text = e.get("display_name", "")
	_slot_opt.selected = _SLOT_STR_MAP.get(e.get("slot", "none"), 0)
	_power_spin.value = float(e.get("power", 0))
	_stack_spin.value = float(e.get("stack_size", 99))
	_rarity_opt.selected = _RARITY_STR_MAP.get(e.get("rarity", "common"), 0)

	# Combat
	_hands_spin.value = float(e.get("hands", 1))
	_attack_type_opt.selected = _ATTACK_TYPE_STR_MAP.get(e.get("attack_type", "none"), 0)
	_weapon_cat_opt.selected = _WEAPON_CAT_STR_MAP.get(e.get("weapon_category", "none"), 0)
	_attack_speed_spin.value = float(e.get("attack_speed", 0))
	_reach_spin.value = float(e.get("reach", 0))
	_knockback_spin.value = float(e.get("knockback", 0))
	_element_opt.selected = _ELEMENT_STR_MAP.get(e.get("element", "none"), 0)

	# Tier / set
	_tier_edit.text = e.get("tier", "")
	_set_id_edit.text = e.get("set_id", "")

	# Tint
	var tint_arr: Array = e.get("armor_tint", [1, 1, 1, 1])
	if tint_arr.size() >= 4:
		_tint_picker.color = Color(float(tint_arr[0]), float(tint_arr[1]),
			float(tint_arr[2]), float(tint_arr[3]))

	# Stat bonuses
	var bonuses: Dictionary = e.get("stat_bonuses", {})
	for sn in _STAT_NAMES:
		_stat_spins[sn].value = float(bonuses.get(String(sn), 0))

	# Equipment sprites
	_refresh_sprite_label(_weapon_sprite_label, e.get("weapon_sprite", null))
	_refresh_sprite_label(_armor_sprite_label, e.get("armor_sprite", null))
	_refresh_sprite_label(_shield_sprite_label, e.get("shield_sprite", null))

	# Description
	_desc_flavor_edit.text = e.get("description_flavor", "")
	_refresh_desc_preview()

	# Icon
	_refresh_icon_preview()

	# Dropped by
	_refresh_dropped_by()


func _refresh_parent_opt() -> void:
	_parent_opt.clear()
	_parent_opt.add_item("(none)")
	_parent_opt.set_item_metadata(0, "")
	var current_parent: String = _items.get(String(_selected_id), {}).get("parent", "")
	var keys: Array = _items.keys()
	keys.sort()
	var sel_idx: int = 0
	var i: int = 1
	for k in keys:
		if String(k) == String(_selected_id):
			continue
		_parent_opt.add_item(String(k))
		_parent_opt.set_item_metadata(i, String(k))
		if String(k) == current_parent:
			sel_idx = i
		i += 1
	_parent_opt.selected = sel_idx


func _refresh_inherit_label() -> void:
	var chain: PackedStringArray = []
	var current: String = String(_selected_id)
	for _safety in 20:
		var parent: String = _items.get(current, {}).get("parent", "")
		if parent == "" or parent == current:
			break
		chain.append(parent)
		current = parent
	if chain.is_empty():
		_inherit_label.text = ""
	else:
		_inherit_label.text = "Inherits: " + " → ".join(chain)


func _refresh_sprite_label(label: Label, val: Variant) -> void:
	if val is Array and val.size() >= 2 and (int(val[0]) >= 0 or int(val[1]) >= 0):
		label.text = "[%d, %d]" % [int(val[0]), int(val[1])]
	else:
		label.text = "(none)"


func _refresh_desc_preview() -> void:
	# Build a temp ItemDefinition to use generate_description().
	var e: Dictionary = _items.get(String(_selected_id), {})
	if e.is_empty():
		_desc_preview.text = ""
		return
	var resolved: Dictionary = ItemRegistry.get_resolved_entry(String(_selected_id))
	if resolved.is_empty():
		resolved = e
	var def := ItemDefinition.new()
	def.power = int(resolved.get("power", 0))
	def.slot = ItemRegistry._SLOT_MAP.get(resolved.get("slot", "none"), 0)
	def.attack_speed = float(resolved.get("attack_speed", 0))
	def.attack_type = ItemRegistry._ATTACK_TYPE_MAP.get(resolved.get("attack_type", "none"), 0)
	def.element = ItemRegistry._ELEMENT_MAP.get(resolved.get("element", "none"), 0)
	def.weapon_category = ItemRegistry._WEAPON_CAT_MAP.get(resolved.get("weapon_category", "none"), 0)
	def.stat_bonuses = resolved.get("stat_bonuses", {})
	def.set_id = resolved.get("set_id", "")
	def.description_flavor = resolved.get("description_flavor", "")
	_desc_preview.text = def.generate_description()


func _refresh_icon_preview() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(_selected_id)
	if def != null and def.icon != null:
		_icon_preview.texture = def.icon
		_icon_cell_label.text = String(_selected_id)
	else:
		_icon_preview.texture = null
		_icon_cell_label.text = "(no icon)"


# ═══════════════════════════════════════════════════════════════════════
#  FIELD EDITING
# ═══════════════════════════════════════════════════════════════════════

func _set_field(key: String, value: Variant) -> void:
	var e: Dictionary = _items.get(String(_selected_id), {})
	if e.is_empty():
		return
	e[key] = value
	_mark_dirty()
	# Update list label when display_name changes.
	if key == "display_name":
		for i in _item_list.item_count:
			if _item_list.get_item_metadata(i) == String(_selected_id):
				_item_list.set_item_text(i, str(value))
				break
	if key == "description_flavor" or key == "power" or key == "attack_speed" \
			or key == "attack_type" or key == "element" or key == "stat_bonuses" \
			or key == "set_id":
		_refresh_desc_preview()


func _on_parent_changed(idx: int) -> void:
	var parent_id: String = _parent_opt.get_item_metadata(idx) if idx >= 0 else ""
	var e: Dictionary = _items.get(String(_selected_id), {})
	if e.is_empty():
		return
	if parent_id == "":
		e.erase("parent")
	else:
		e["parent"] = parent_id
	_mark_dirty()
	_refresh_inherit_label()
	_refresh_desc_preview()


func _on_stat_bonus_changed(stat_name: StringName, val: int) -> void:
	var e: Dictionary = _items.get(String(_selected_id), {})
	if e.is_empty():
		return
	var bonuses: Dictionary = e.get("stat_bonuses", {})
	if val == 0:
		bonuses.erase(String(stat_name))
	else:
		bonuses[String(stat_name)] = val
	e["stat_bonuses"] = bonuses
	_mark_dirty()
	_refresh_desc_preview()


func _mark_dirty() -> void:
	_dirty = true
	dirty_changed.emit()


# ═══════════════════════════════════════════════════════════════════════
#  CRUD
# ═══════════════════════════════════════════════════════════════════════

func _on_add_item() -> void:
	var base_id: String = "new_item"
	var new_id: String = base_id
	var counter: int = 1
	while _items.has(new_id):
		new_id = "%s_%d" % [base_id, counter]
		counter += 1
	_items[new_id] = {
		"display_name": new_id.replace("_", " ").capitalize(),
		"icon_idx": -1,
		"slot": "none",
		"power": 0,
		"stack_size": 99,
	}
	_mark_dirty()
	_populate_list()
	select_item(StringName(new_id))


func _on_delete_item() -> void:
	if _selected_id == &"":
		return
	_items.erase(String(_selected_id))
	_mark_dirty()
	_populate_list()
	if _item_list.item_count > 0:
		_item_list.select(0)
		_on_item_selected(0)
	else:
		_selected_id = &""


func _on_rename_item() -> void:
	if _selected_id == &"":
		return
	var new_id: String = _id_edit.text.strip_edges().to_lower().replace(" ", "_")
	if new_id == "" or new_id == String(_selected_id):
		return
	if _items.has(new_id):
		push_warning("[ItemEditor] ID '%s' already exists" % new_id)
		return
	var old_id: String = String(_selected_id)
	var entry: Dictionary = _items[old_id]
	_items.erase(old_id)
	_items[new_id] = entry
	# Update parent references in other items.
	for k in _items:
		if _items[k].get("parent", "") == old_id:
			_items[k]["parent"] = new_id
	_mark_dirty()
	_populate_list()
	select_item(StringName(new_id))


# ═══════════════════════════════════════════════════════════════════════
#  EQUIPMENT SPRITE PICKING
# ═══════════════════════════════════════════════════════════════════════

func _on_pick_weapon_sprite() -> void:
	if _sprite_pick_mode == "weapon_sprite":
		_sprite_pick_mode = ""
		_weapon_sprite_btn.text = "Pick Weapon Sprite"
	else:
		_sprite_pick_mode = "weapon_sprite"
		_weapon_sprite_btn.text = ">> Click atlas cell <<"
		_armor_sprite_btn.text = "Pick Armor Sprite"
		_shield_sprite_btn.text = "Pick Shield Sprite"
		sheet_requested.emit(CHARACTER_SHEET)


func _on_pick_armor_sprite() -> void:
	if _sprite_pick_mode == "armor_sprite":
		_sprite_pick_mode = ""
		_armor_sprite_btn.text = "Pick Armor Sprite"
	else:
		_sprite_pick_mode = "armor_sprite"
		_armor_sprite_btn.text = ">> Click atlas cell <<"
		_weapon_sprite_btn.text = "Pick Weapon Sprite"
		_shield_sprite_btn.text = "Pick Shield Sprite"
		sheet_requested.emit(CHARACTER_SHEET)


func _on_pick_shield_sprite() -> void:
	if _sprite_pick_mode == "shield_sprite":
		_sprite_pick_mode = ""
		_shield_sprite_btn.text = "Pick Shield Sprite"
	else:
		_sprite_pick_mode = "shield_sprite"
		_shield_sprite_btn.text = ">> Click atlas cell <<"
		_weapon_sprite_btn.text = "Pick Weapon Sprite"
		_armor_sprite_btn.text = "Pick Armor Sprite"
		sheet_requested.emit(CHARACTER_SHEET)


# ═══════════════════════════════════════════════════════════════════════
#  ATLAS CLICK (icon + equipment sprite)
# ═══════════════════════════════════════════════════════════════════════

func on_atlas_cell_clicked(cell: Vector2i) -> void:
	if _selected_id == &"":
		return
	# Equipment sprite picking mode.
	if _sprite_pick_mode != "":
		_set_field(_sprite_pick_mode, [cell.x, cell.y])
		match _sprite_pick_mode:
			"weapon_sprite":
				_refresh_sprite_label(_weapon_sprite_label, [cell.x, cell.y])
				_weapon_sprite_btn.text = "Pick Weapon Sprite"
			"armor_sprite":
				_refresh_sprite_label(_armor_sprite_label, [cell.x, cell.y])
				_armor_sprite_btn.text = "Pick Armor Sprite"
			"shield_sprite":
				_refresh_sprite_label(_shield_sprite_label, [cell.x, cell.y])
				_shield_sprite_btn.text = "Pick Shield Sprite"
		_sprite_pick_mode = ""
		return
	# Normal icon cell picking — store icon_idx as cell index on the icon sheet.
	var e: Dictionary = _items.get(String(_selected_id), {})
	if e.is_empty():
		return
	e["icon_idx"] = cell.y * 100 + cell.x  # encode col/row into an index
	_mark_dirty()
	_icon_cell_label.text = "Cell [%d, %d]" % [cell.x, cell.y]


func get_marks() -> Array:
	if _selected_id == &"":
		return []
	var e: Dictionary = _items.get(String(_selected_id), {})
	if e.is_empty():
		return []
	var marks: Array = []
	# Show equipment sprite marks on character sheet.
	for field in ["weapon_sprite", "armor_sprite", "shield_sprite"]:
		var val: Variant = e.get(field, null)
		if val is Array and val.size() >= 2 and int(val[0]) >= 0:
			var color: Color = Color.CYAN
			if field == "armor_sprite":
				color = Color.GREEN
			elif field == "shield_sprite":
				color = Color.YELLOW
			marks.append({
				"cell": Vector2i(int(val[0]), int(val[1])),
				"color": color,
				"width": 3.0,
			})
	return marks


# ═══════════════════════════════════════════════════════════════════════
#  DROP SOURCE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════

func _refresh_dropped_by() -> void:
	for c in _drop_sources_container.get_children():
		c.queue_free()
	var item_id: String = String(_selected_id)
	var mineable_data: Dictionary = MineableRegistry.get_raw_data()
	var resources: Dictionary = mineable_data.get("resources", {})
	var found := false
	for rid in resources:
		var entry: Dictionary = resources[rid]
		for d in entry.get("drops", []):
			if d is Dictionary and d.get("item_id", "") == item_id:
				found = true
				var row := HBoxContainer.new()
				var lbl := Label.new()
				lbl.text = "%s (×%d)" % [entry.get("display_name", rid), int(d.get("count", 1))]
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(lbl)
				var count_spin := SpinBox.new()
				count_spin.min_value = 1
				count_spin.max_value = 99
				count_spin.value = float(d.get("count", 1))
				count_spin.value_changed.connect(
					_on_drop_source_count_changed.bind(String(rid), item_id))
				row.add_child(count_spin)
				var go_btn := Button.new()
				go_btn.text = "\u2192"
				go_btn.pressed.connect(_on_navigate_mineable.bind(StringName(rid)))
				row.add_child(go_btn)
				var del := Button.new()
				del.text = "\u00d7"
				del.pressed.connect(_on_remove_drop_source.bind(String(rid), item_id))
				row.add_child(del)
				_drop_sources_container.add_child(row)
				break
	if not found:
		var lbl := Label.new()
		lbl.text = "(not dropped by any mineable)"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_drop_sources_container.add_child(lbl)
	_refresh_add_mineable_dropdown()


func _refresh_add_mineable_dropdown() -> void:
	_add_mineable_opt.clear()
	var item_id: String = String(_selected_id)
	var mineable_data: Dictionary = MineableRegistry.get_raw_data()
	var resources: Dictionary = mineable_data.get("resources", {})
	var already: Array = []
	for rid in resources:
		for d in resources[rid].get("drops", []):
			if d is Dictionary and d.get("item_id", "") == item_id:
				already.append(String(rid))
				break
	_add_mineable_opt.add_item("(select)")
	_add_mineable_opt.set_item_metadata(0, "")
	var rids: Array = resources.keys()
	rids.sort()
	for rid in rids:
		if String(rid) in already:
			continue
		_add_mineable_opt.add_item(String(rid))
		_add_mineable_opt.set_item_metadata(
			_add_mineable_opt.item_count - 1, String(rid))
	_add_mineable_btn.disabled = (_add_mineable_opt.item_count <= 1)


func _on_add_drop_source() -> void:
	var sel_idx: int = _add_mineable_opt.selected
	if sel_idx < 0:
		return
	var rid: String = _add_mineable_opt.get_item_metadata(sel_idx)
	if rid == "":
		return
	var data: Dictionary = MineableRegistry.get_raw_data()
	var resources: Dictionary = data.get("resources", {})
	if not resources.has(rid):
		return
	resources[rid].get("drops", []).append(
		{"item_id": String(_selected_id), "count": 1})
	_mineable_dirty = true
	_mark_dirty()
	_refresh_dropped_by()


func _on_remove_drop_source(rid: String, item_id: String) -> void:
	var data: Dictionary = MineableRegistry.get_raw_data()
	var resources: Dictionary = data.get("resources", {})
	if not resources.has(rid):
		return
	var drops: Array = resources[rid].get("drops", [])
	for i in drops.size():
		if drops[i].get("item_id", "") == item_id:
			drops.remove_at(i)
			break
	_mineable_dirty = true
	_mark_dirty()
	_refresh_dropped_by()


func _on_drop_source_count_changed(val: float, rid: String, item_id: String) -> void:
	var data: Dictionary = MineableRegistry.get_raw_data()
	var resources: Dictionary = data.get("resources", {})
	if not resources.has(rid):
		return
	for d in resources[rid].get("drops", []):
		if d.get("item_id", "") == item_id:
			d["count"] = int(val)
			break
	_mineable_dirty = true
	_mark_dirty()


func _on_navigate_mineable(resource_id: StringName) -> void:
	navigate_to_mineable.emit(resource_id)


# ═══════════════════════════════════════════════════════════════════════
#  BALANCE OVERVIEW TABLE
# ═══════════════════════════════════════════════════════════════════════

const _TABLE_COLS: Array[String] = [
	"ID", "Name", "Rarity", "Slot", "Power", "Hands",
	"AtkType", "AtkSpd", "Reach", "Element", "Tier", "SetID"
]


func _build_balance_table() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_table_grid = GridContainer.new()
	_table_grid.columns = _TABLE_COLS.size()
	_table_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_table_grid)
	return scroll


func _refresh_balance_table() -> void:
	for c in _table_grid.get_children():
		c.queue_free()
	# Header row
	for col_name in _TABLE_COLS:
		var h := Label.new()
		h.text = col_name
		h.add_theme_font_size_override("font_size", 12)
		h.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
		_table_grid.add_child(h)
	# Data rows
	var keys: Array = _items.keys()
	keys.sort()
	for k in keys:
		var e: Dictionary = _items[k]
		var resolved: Dictionary = ItemRegistry.get_resolved_entry(String(k))
		if resolved.is_empty():
			resolved = e
		_add_table_cell(String(k), Color(0.7, 0.7, 0.7))
		_add_table_cell(resolved.get("display_name", ""), Color.WHITE)
		var rarity_str: String = resolved.get("rarity", "common")
		var rarity_idx: int = _RARITY_STR_MAP.get(rarity_str, 0)
		var rarity_color: Color = ItemDefinition.RARITY_COLORS.get(rarity_idx, Color.WHITE)
		_add_table_cell(rarity_str.capitalize(), rarity_color)
		_add_table_cell(resolved.get("slot", "none"), Color.WHITE)
		_add_table_cell(str(resolved.get("power", 0)), Color.WHITE)
		_add_table_cell(str(resolved.get("hands", 1)), Color.WHITE)
		_add_table_cell(resolved.get("attack_type", "none"), Color.WHITE)
		_add_table_cell(str(resolved.get("attack_speed", 0)), Color.WHITE)
		_add_table_cell(str(resolved.get("reach", 0)), Color.WHITE)
		_add_table_cell(resolved.get("element", "none"), Color.WHITE)
		_add_table_cell(resolved.get("tier", ""), Color.WHITE)
		_add_table_cell(resolved.get("set_id", ""), Color.WHITE)


func _add_table_cell(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	_table_grid.add_child(l)


# ═══════════════════════════════════════════════════════════════════════
#  SAVE / REVERT
# ═══════════════════════════════════════════════════════════════════════

func save() -> void:
	ItemRegistry.save_data(_items)
	if _mineable_dirty:
		MineableRegistry.save_data(MineableRegistry.get_raw_data())
		_mineable_dirty = false
	ItemRegistry.reset()
	_dirty = false


func revert() -> void:
	ItemRegistry.reset()
	_load_data()
	_dirty = false
	_populate_list()
	if _item_list.item_count > 0:
		_item_list.select(0)
		_on_item_selected(0)


func is_dirty() -> bool:
	return _dirty
