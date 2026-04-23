## BalanceOverview
##
## Read-only sub-editor showing a cross-system balance table.
## Biome → Creature Kinds → Avg HP → Notable Drops → Recommended Power.
class_name BalanceOverview
extends VBoxContainer

signal dirty_changed

var sheet_path: String = ""

var _grid: GridContainer = null
var _refresh_btn: Button = null

const _COLUMNS: Array = [
	"Biome", "Creatures", "Avg HP", "Avg Damage", "Notable Drops", "Power Level"
]


func _ready() -> void:
	_build_ui()
	_refresh_table()


func _build_ui() -> void:
	var header := HBoxContainer.new()
	add_child(header)
	var title := Label.new()
	title.text = "Balance Overview — Biome / Creature / Loot Analysis"
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)
	_refresh_btn = Button.new()
	_refresh_btn.text = "Refresh"
	_refresh_btn.pressed.connect(_refresh_table)
	header.add_child(_refresh_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = _COLUMNS.size()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)


func _refresh_table() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()

	# Header row
	for col: String in _COLUMNS:
		var lbl := Label.new()
		lbl.text = col
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
		_grid.add_child(lbl)

	# Gather biome data
	var biome_data: Dictionary = BiomeRegistry.get_raw_data()
	var loot_data: Dictionary = LootTableRegistry.get_raw_data()

	for biome_id: String in biome_data:
		var biome: Dictionary = biome_data[biome_id]
		var npc_kinds: Array = biome.get("npc_kinds", [])

		# Biome column
		_grid.add_child(_cell(biome.get("display_name", biome_id)))

		# Creatures column
		var creature_names: Array = []
		for kind in npc_kinds:
			creature_names.append(String(kind))
		_grid.add_child(_cell(", ".join(creature_names) if creature_names.size() > 0 else "-"))

		# Avg HP
		var total_hp: int = 0
		var count: int = 0
		for kind in npc_kinds:
			var kind_str: String = String(kind)
			if loot_data.has(kind_str):
				total_hp += int(loot_data[kind_str].get("health", 3))
				count += 1
		var avg_hp: String = str(total_hp / max(1, count)) if count > 0 else "-"
		_grid.add_child(_cell(avg_hp))

		# Avg Damage (from loot table damage field, default 1)
		var total_dmg: int = 0
		var dmg_count: int = 0
		for kind in npc_kinds:
			var kind_str: String = String(kind)
			if loot_data.has(kind_str):
				total_dmg += int(loot_data[kind_str].get("damage", 1))
				dmg_count += 1
		var avg_dmg: String = str(total_dmg / max(1, dmg_count)) if dmg_count > 0 else "-"
		_grid.add_child(_cell(avg_dmg))

		# Notable drops
		var drops_set: Dictionary = {}
		for kind in npc_kinds:
			var kind_str: String = String(kind)
			if loot_data.has(kind_str):
				for drop: Dictionary in loot_data[kind_str].get("drops", []):
					var did: String = drop.get("id", "")
					if did != "" and not drops_set.has(did):
						drops_set[did] = true
		var drop_names: Array = drops_set.keys()
		drop_names.sort()
		_grid.add_child(_cell(", ".join(drop_names.slice(0, 5)) if drop_names.size() > 0 else "-"))

		# Recommended power level (rough: avg_hp / 3 rounded up)
		var power: int = ceili(float(total_hp) / max(1.0, float(count)) / 3.0) if count > 0 else 1
		_grid.add_child(_cell(str(power)))


func _cell(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	return lbl


func is_dirty() -> bool:
	return false


func save() -> void:
	pass


func revert() -> void:
	_refresh_table()


func get_marks() -> Array:
	return []


func on_atlas_cell_clicked(_cell: Vector2i) -> void:
	pass
