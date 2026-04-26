## Game Editor (dev tool)
##
## Standalone scene that lets the developer browse every editable sprite
## mapping in [TileMappings], view the source atlas sheet for the
## currently-selected mapping, click a slot in the right pane to mark it
## active, then click a cell in the sheet to bind that cell to the active
## slot. Save writes back to `res://resources/tilesets/tile_mappings.tres`.
##
## Also includes sub-editors for mineables, items, and encounters.
##
## The scene is built fully from code so the layout is in one place and
## doesn't fight `.tscn` formatting. Run via:
##   godot res://scenes/tools/GameEditor.tscn
extends Control

const MAPPINGS_PATH: String = "res://resources/tilesets/tile_mappings.tres"

# Mapping kinds. Each entry drives the tree, decides which sheet to show,
# and tells the right-pane what selection shape to render. Hand-curated
# to match the v1 scope agreed in planning.
#
# Fields:
#   id      : StringName — internal key, also used as TreeItem metadata
#   label   : String     — visible label in the tree
#   sheet   : String     — atlas PNG path
#   field   : StringName — TileMappings field to read/write
#   kind    : StringName — selection layout for the right pane:
#                          "single"      Dictionary[StringName→Vector2i]
#                          "list"        Dictionary[StringName→Array[Vector2i]]
#                          "patch3"      Dictionary[StringName→Array[Vector2i] (9)]
#                          "patch3_flat" Array[Vector2i] (9)
#                          "named"       Dictionary[Variant→Vector2i]
#                          "flat_list"   Array[Vector2i]
#                          "autotile"    Array[Dict{mask,cell,flip}]
const _MAPPINGS: Array = [
	{"id": &"overworld_terrain",                 "label": "Overworld terrain",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"overworld_terrain",                 "kind": &"list"},
	{"id": &"overworld_decoration",              "label": "Overworld decorations",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"overworld_decoration",              "kind": &"list"},
	{"id": &"overworld_terrain_patches_3x3",     "label": "Overworld 3×3 terrain patches",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"overworld_terrain_patches_3x3",     "kind": &"patch3"},
	{"id": &"overworld_water_border_grass_3x3",  "label": "Water-on-grass 3×3 border",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"overworld_water_border_grass_3x3",  "kind": &"patch3_flat"},
	{"id": &"overworld_water_outer_corners",     "label": "Water outer corners (diagonals)",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"overworld_water_outer_corners",     "kind": &"named"},
	{"id": &"city_terrain",                      "label": "City terrain",
	 "sheet": "res://assets/tiles/roguelike/city_sheet.png",
	 "field": &"city_terrain",                      "kind": &"list"},
	{"id": &"dungeon_terrain",                   "label": "Dungeon single-cell terrains",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"dungeon_terrain",                   "kind": &"list"},
	{"id": &"dungeon_wall_autotile",             "label": "Dungeon wall autotile (16-mask)",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"dungeon_wall_autotile",             "kind": &"autotile"},
	{"id": &"dungeon_floor_decor",               "label": "Dungeon floor decor",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"dungeon_floor_decor",               "kind": &"flat_list"},
	{"id": &"dungeon_floor_border_3x3",        "label": "Dungeon floor border (3\u00d73)",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"dungeon_floor_border_3x3",     "kind": &"patch3_flat"},
	{"id": &"dungeon_entrance_pair",             "label": "Dungeon entrance marker pair",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"dungeon_entrance_pair",             "kind": &"flat_list"},
	{"id": &"labyrinth_entrance_pair",           "label": "Labyrinth entrance marker pair",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"labyrinth_entrance_pair",            "kind": &"flat_list"},
	{"id": &"labyrinth_terrain",                "label": "Labyrinth single-cell terrains",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"labyrinth_terrain",             "kind": &"list"},
	{"id": &"labyrinth_wall_autotile",          "label": "Labyrinth wall autotile (16-mask)",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"labyrinth_wall_autotile",       "kind": &"autotile"},
	{"id": &"labyrinth_floor_decor",            "label": "Labyrinth floor decor",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"labyrinth_floor_decor",         "kind": &"flat_list"},
	{"id": &"labyrinth_floor_border_3x3",      "label": "Labyrinth floor border (3\u00d73)",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"labyrinth_floor_border_3x3",   "kind": &"patch3_flat"},
	{"id": &"labyrinth_chest_pair",             "label": "Labyrinth chest (closed + open)",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"labyrinth_chest_pair",          "kind": &"flat_list"},
	{"id": &"dungeon_doorframe",                 "label": "Dungeon doorframe (named slots)",
	 "sheet": "res://assets/tiles/roguelike/dungeon_sheet.png",
	 "field": &"dungeon_doorframe",                 "kind": &"named"},
	{"id": &"interior_terrain",                  "label": "Interior terrain",
	 "sheet": "res://assets/tiles/roguelike/interior_sheet.png",
	 "field": &"interior_terrain",                  "kind": &"list"},
	{"id": &"mineable_resources",                "label": "Mineable Resources",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_mineable_json",                    "kind": &"mineable"},
	{"id": &"item_editor",                        "label": "Items / Drops",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_item_editor",                      "kind": &"item_editor"},
	{"id": &"encounter_editor",                  "label": "Encounters",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_encounter_editor",                 "kind": &"encounter_editor"},
	{"id": &"creature_editor",                    "label": "Creatures",
	 "sheet": "res://assets/characters/monsters/slime.png",
	 "field": &"_creature_editor",                  "kind": &"creature_editor"},
	{"id": &"loot_table_editor",                  "label": "Loot Tables",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_loot_table_editor",                "kind": &"loot_table_editor"},
	{"id": &"crafting_editor",                     "label": "Crafting Recipes",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_crafting_editor",                   "kind": &"crafting_editor"},
	{"id": &"armor_set_editor",                    "label": "Armor Sets",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_armor_set_editor",                  "kind": &"armor_set_editor"},
	{"id": &"biome_editor",                        "label": "Biomes",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_biome_editor",                      "kind": &"biome_editor"},
	{"id": &"shop_editor",                         "label": "Shops",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_shop_editor",                       "kind": &"shop_editor"},
	{"id": &"quest_editor",                        "label": "Quests (Graph)",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_quest_editor",                     "kind": &"quest_editor"},
	{"id": &"dialogue_editor",                     "label": "Dialogue (Graph)",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_dialogue_editor",                  "kind": &"dialogue_editor"},
	{"id": &"balance_overview",                    "label": "Balance Overview",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_balance_overview",                 "kind": &"balance_overview"},
	{"id": &"encounter_table_editor",            "label": "Encounter Tables (Depth)",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_encounter_table_editor",           "kind": &"encounter_table_editor"},
	{"id": &"chest_loot_editor",                  "label": "Chest Loot (Depth Tiers)",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_chest_loot_editor",               "kind": &"chest_loot_editor"},
	{"id": &"asset_browser",                      "label": "Import from Kenney",
	 "sheet": "res://assets/tiles/roguelike/overworld_sheet.png",
	 "field": &"_asset_browser",                    "kind": &"asset_browser"},
]

# Tile-sheet geometry. Matches WorldConst.TILE_PX (16) and the 1-px
# gutter between tiles used by every Roguelike-pack sheet we ship.
const TILE_PX: int = 16
const TILE_GUTTER: int = 1
const SHEET_ZOOM: int = 3

# Slot mark colours. Every bound cell is outlined dim cyan so the
# developer can see at a glance which cells the current mapping uses.
# The active slot's cell is overlaid bright green.
const COLOR_BOUND: Color  = Color(0.3, 0.8, 1.0, 0.9)
const COLOR_ACTIVE: Color = Color(0.3, 1.0, 0.4, 1.0)
const COLOR_HOVER: Color  = Color(0.95, 0.9, 0.2, 0.9)

var _mappings_resource: TileMappings = null
var _dirty: bool = false
var _mineable_editor: MineableEditor = null  ## Active only for kind=="mineable".
var _item_editor: ItemEditor = null          ## Active only for kind=="item_editor".
var _encounter_editor: EncounterEditor = null ## Active only for kind=="encounter_editor".
var _creature_editor: CreatureEditor = null  ## Active only for kind=="creature_editor".
var _asset_browser: AssetBrowser = null      ## Active only for kind=="asset_browser".
var _loot_table_editor: LootTableEditor = null
var _crafting_editor: CraftingEditor = null
var _armor_set_editor: ArmorSetEditor = null
var _biome_editor: BiomeEditor = null
var _shop_editor: ShopEditor = null
var _quest_editor: QuestEditor = null
var _dialogue_editor: DialogueEditor = null
var _balance_overview: BalanceOverview = null
var _encounter_table_editor: EncounterTableEditor = null
var _chest_loot_editor: ChestLootEditor = null

# Quest TODO panel state.
var _quest_panel: ScrollContainer = null
var _quest_icon_grid: GridContainer = null
var _quest_creating_item: String = ""       ## Item ID awaiting icon pick.
var _quest_item_btns: Dictionary = {}        ## id → Button for status updates.
var _quest_feature_btns: Dictionary = {}     ## id → Button for status updates.

# Currently focused mapping entry (one of _MAPPINGS) and its expanded
# slot list. Each slot is a Dictionary:
#   label  : String — display text in the row button
#   path   : Array  — addressing path used by `_get_slot_cell` /
#                     `_set_slot_cell` to read/write the resource
#   flip_v : int    — 0/1 for autotile entries, -1 for everything else
#   flip_h : int    — 0/1 for autotile entries, -1 for everything else
#                     (autotile rows render Flip V and Flip H checkboxes)
var _current_mapping: Dictionary = {}
var _slots: Array = []
var _active_slot: int = -1

# UI refs.
var _tree: Tree = null
var _sheet_view: SheetView = null
var _slot_root: VBoxContainer = null
var _slot_scroll: ScrollContainer = null
var _header_label: Label = null
var _preview_label: Label = null
var _status_label: Label = null
var _save_btn: Button = null
var _revert_btn: Button = null
var _preview: PreviewView = null
var _sheet_selector: OptionButton = null  ## Spritesheet dropdown.
var _available_sheets: Array[String] = []  ## Discovered PNGs.


# ─── Inner class: SheetView ─────────────────────────────────────────────
#
# Custom Control that draws an atlas sheet, a per-cell grid overlay, all
# bound cells (dim cyan), the active slot's cell (bright green), and the
# hovered cell (yellow). Emits `cell_clicked(cell)` on left-click.
class SheetView extends Control:
	signal cell_clicked(cell: Vector2i)

	var texture: Texture2D = null
	var tile_px: int = 16
	var gutter: int = 1
	var zoom: int = 3
	var hovered: Vector2i = Vector2i(-1, -1)
	# `marks` is an Array of Dictionaries: {cell: Vector2i, color: Color, width: float}.
	var marks: Array = []

	func set_sheet(tex: Texture2D) -> void:
		texture = tex
		# Auto-detect gutter: Kenney roguelike sheets use 1-px gutter.
		# Accepted patterns (step = tile_px + 1 = 17):
		#   w = cols * step - 1  (no trailing gutter)  → (w+1) % step == 0
		#   w = cols * step      (trailing gutter)     →  w    % step == 0
		# Sheets that divide evenly by tile_px alone have no gutter.
		if tex != null:
			var w: int = tex.get_width()
			var h: int = tex.get_height()
			var step: int = tile_px + 1  # 17
			var fits_gutter_w: bool = ((w + 1) % step == 0) or (w % step == 0)
			var fits_gutter_h: bool = ((h + 1) % step == 0) or (h % step == 0)
			var fits_no_gutter_w: bool = (w % tile_px) == 0
			var fits_no_gutter_h: bool = (h % tile_px) == 0
			# Width is a stronger signal than height (more tiles = more constraints).
			# If width cleanly fits the gutter pattern, trust it regardless of height,
			# so a sheet with a slightly-off height doesn't revert everything to step=16.
			if fits_gutter_w:
				gutter = 1
			elif fits_no_gutter_w and fits_no_gutter_h:
				gutter = 0
			else:
				gutter = 1  # default: Kenney roguelike sheets always use 1-px gutter
		_resize_to_texture()
		queue_redraw()

	func set_marks(new_marks: Array) -> void:
		marks = new_marks
		queue_redraw()

	func clear_marks() -> void:
		marks = []
		hovered = Vector2i(-1, -1)
		queue_redraw()

	func _resize_to_texture() -> void:
		if texture == null:
			custom_minimum_size = Vector2.ZERO
			return
		custom_minimum_size = Vector2(
				float(texture.get_width() * zoom),
				float(texture.get_height() * zoom))

	# Local mouse coords → atlas (col, row). Returns Vector2i(-1, -1) for
	# clicks outside the texture or inside the inter-tile gutter.
	func _cell_at(pos: Vector2) -> Vector2i:
		if texture == null:
			return Vector2i(-1, -1)
		var step: float = float(tile_px + gutter) * float(zoom)
		var col: int = int(floor(pos.x / step))
		var row: int = int(floor(pos.y / step))
		var max_col: int = (texture.get_width() + gutter) / (tile_px + gutter)
		var max_row: int = (texture.get_height() + gutter) / (tile_px + gutter)
		if col < 0 or col >= max_col or row < 0 or row >= max_row:
			return Vector2i(-1, -1)
		var cell_x_local: float = pos.x - float(col) * step
		var cell_y_local: float = pos.y - float(row) * step
		var visible_px: float = float(tile_px) * float(zoom)
		if cell_x_local >= visible_px or cell_y_local >= visible_px:
			return Vector2i(-1, -1)
		return Vector2i(col, row)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var hc: Vector2i = _cell_at(ev.position)
			if hc != hovered:
				hovered = hc
				queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var cc: Vector2i = _cell_at(ev.position)
			if cc != Vector2i(-1, -1):
				cell_clicked.emit(cc)

	func _draw() -> void:
		if texture == null:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.12), true)
			return
		var dest := Rect2(Vector2.ZERO,
				Vector2(texture.get_width() * zoom, texture.get_height() * zoom))
		draw_texture_rect(texture, dest, false)
		var step: float = float(tile_px + gutter) * float(zoom)
		var max_col: int = (texture.get_width() + gutter) / (tile_px + gutter)
		var max_row: int = (texture.get_height() + gutter) / (tile_px + gutter)
		var grid_col := Color(1, 1, 1, 0.10)
		for x in range(max_col + 1):
			var px: float = float(x) * step
			draw_line(Vector2(px, 0), Vector2(px, dest.size.y), grid_col, 1.0)
		for y in range(max_row + 1):
			var py: float = float(y) * step
			draw_line(Vector2(0, py), Vector2(dest.size.x, py), grid_col, 1.0)
		for m in marks:
			_draw_cell_outline(m["cell"], m["color"], float(m.get("width", 2.0)))
		if hovered.x >= 0:
			_draw_cell_outline(hovered, Color(0.95, 0.9, 0.2, 0.9), 2.0)

	func _draw_cell_outline(cell: Vector2i, col: Color, w: float) -> void:
		var step: float = float(tile_px + gutter) * float(zoom)
		var visible_px: float = float(tile_px) * float(zoom)
		var p := Vector2(float(cell.x) * step, float(cell.y) * step)
		draw_rect(Rect2(p, Vector2(visible_px, visible_px)), col, false, w)


# ─── Inner class: PreviewView ──────────────────────────────────────────
#
# Renders a small 5×5 (or 3×3, for patch layouts) preview of the cells
# currently bound to the focused mapping, stamping from the same atlas
# the runtime renderer uses. Layouts:
#   "tile"   — fill the grid by cycling through `cells` (great for
#              single-cell terrains, lists, autotile entries).
#   "patch3" — render exactly 9 cells in a 3×3 (NW..SE), centred in the
#              preview frame.
class PreviewView extends Control:
	## Emitted when the user clicks a wall cell in the autotile_room preview.
	signal mask_clicked(mask: int)

	const FRAME: int = 5
	const PREVIEW_ZOOM: int = 3
	## Dimensions of the synthetic room+hallway preview map.
	const _ROOM_W: int = 11
	const _ROOM_H: int = 11
	## 0 = wall, 1 = floor. 5×4 room (cols 1-5, rows 1-4) with 2-wide
	## corridor (cols 2-3, rows 5-8) exiting south.
	const _ROOM_MAP: Array = [
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		[0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
		[0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
		[0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
		[0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
		[0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	]

	var texture: Texture2D = null
	var tile_px: int = 16
	var gutter: int = 1
	var cells: Array = []
	var layout: StringName = &"tile"
	## Autotile mask→[cell, flip_v] dict. Only used when layout == &"autotile_room".
	var autotile_dict: Dictionary = {}
	## The 4-bit mask of the currently selected slot. -1 = nothing selected.
	var highlighted_mask: int = -1

	func _ready() -> void:
		_resize()

	func set_data(tex: Texture2D, new_cells: Array, new_layout: StringName) -> void:
		texture = tex
		cells = new_cells
		layout = new_layout
		_resize()
		queue_redraw()

	func set_autotile_data(tex: Texture2D, at_dict: Dictionary, active_mask: int = -1) -> void:
		texture = tex
		autotile_dict = at_dict
		highlighted_mask = active_mask
		cells = []  # not used for autotile_room layout
		layout = &"autotile_room"
		_resize()
		queue_redraw()

	func _resize() -> void:
		if layout == &"autotile_room":
			custom_minimum_size = Vector2(
					float(_ROOM_W * tile_px * PREVIEW_ZOOM),
					float(_ROOM_H * tile_px * PREVIEW_ZOOM))
		else:
			custom_minimum_size = Vector2(
					float(FRAME * tile_px * PREVIEW_ZOOM),
					float(FRAME * tile_px * PREVIEW_ZOOM))

	func _room_neighbour_is_floor(gx: int, gy: int) -> bool:
		if gx < 0 or gx >= _ROOM_W or gy < 0 or gy >= _ROOM_H:
			return false
		return _ROOM_MAP[gy][gx] == 1

	func _draw_autotile_room(src_step: int, dest_step: float) -> void:
		var bg_dark := Color(0.08, 0.08, 0.10)
		# Pick a floor tile: prefer mask=15 (all floors), else first entry.
		var floor_atlas := Vector2i(0, 0)
		var floor_entry: Variant = autotile_dict.get(15, null)
		if floor_entry is Array and (floor_entry as Array).size() >= 1:
			floor_atlas = (floor_entry as Array)[0]
		elif not autotile_dict.is_empty():
			var first: Variant = autotile_dict.values()[0]
			if first is Array and (first as Array).size() >= 1:
				floor_atlas = (first as Array)[0]
		for gy in _ROOM_H:
			for gx in _ROOM_W:
				var dest := Rect2(
					Vector2(float(gx) * dest_step, float(gy) * dest_step),
					Vector2(dest_step, dest_step))
				if _ROOM_MAP[gy][gx] == 1:
					# Floor cell.
					var src := Rect2(
						float(floor_atlas.x * src_step),
						float(floor_atlas.y * src_step),
						float(tile_px), float(tile_px))
					draw_texture_rect_region(texture, dest, src)
				else:
					# Wall cell — compute 4-bit mask.
					var mask: int = 0
					if _room_neighbour_is_floor(gx, gy - 1): mask |= 8  # N
					if _room_neighbour_is_floor(gx, gy + 1): mask |= 4  # S
					if _room_neighbour_is_floor(gx + 1, gy): mask |= 2  # E
					if _room_neighbour_is_floor(gx - 1, gy): mask |= 1  # W
					if mask == 0:
						draw_rect(dest, bg_dark, true)
					else:
						var entry: Variant = autotile_dict.get(mask, null)
						if entry == null or not (entry is Array):
							draw_rect(dest, bg_dark, true)
						else:
							var arr: Array = entry as Array
							var atlas: Vector2i = arr[0]
							var flip_v: bool = (arr.size() > 1 and arr[1])
							var flip_h: bool = (arr.size() > 2 and arr[2])
							var src := Rect2(
								float(atlas.x * src_step),
								float(atlas.y * src_step),
								float(tile_px), float(tile_px))
							var sc: float = float(dest_step) / float(tile_px)
							if flip_v or flip_h:
								# Use draw_set_transform for reliable flipping.
								# Anchor: bottom-left for V, top-right for H,
								# bottom-right for both.
								var ox: float = dest_step if flip_h else 0.0
								var oy: float = dest_step if flip_v else 0.0
								draw_set_transform(
									Vector2(dest.position.x + ox,
										dest.position.y + oy),
									0.0,
									Vector2(-sc if flip_h else sc,
										-sc if flip_v else sc))
								draw_texture_rect_region(texture,
									Rect2(Vector2.ZERO,
										Vector2(float(tile_px), float(tile_px))),
									src)
								draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
							else:
								draw_texture_rect_region(texture, dest, src)
					# Highlight border for the currently selected mask.
					if mask == highlighted_mask and highlighted_mask >= 0:
						draw_rect(dest, Color(1.0, 0.9, 0.0, 1.0), false, 2.0)

	## Hit-test: return the 4-bit wall mask at pixel position `pos` inside
	## the autotile_room preview, or -1 if `pos` is over a floor cell or
	## outside the map.
	func _mask_at_pos(pos: Vector2) -> int:
		var dest_step: float = float(tile_px * PREVIEW_ZOOM)
		var gx: int = int(floor(pos.x / dest_step))
		var gy: int = int(floor(pos.y / dest_step))
		if gx < 0 or gx >= _ROOM_W or gy < 0 or gy >= _ROOM_H:
			return -1
		if _ROOM_MAP[gy][gx] == 1:
			return -1  # floor cell
		var mask: int = 0
		if _room_neighbour_is_floor(gx, gy - 1): mask |= 8  # N
		if _room_neighbour_is_floor(gx, gy + 1): mask |= 4  # S
		if _room_neighbour_is_floor(gx + 1, gy): mask |= 2  # E
		if _room_neighbour_is_floor(gx - 1, gy): mask |= 1  # W
		return mask if mask > 0 else -1

	func _gui_input(ev: InputEvent) -> void:
		if layout != &"autotile_room":
			return
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var m: int = _mask_at_pos((ev as InputEventMouseButton).position)
			if m >= 0:
				mask_clicked.emit(m)
				accept_event()

	func _draw() -> void:
		var bg := Color(0.08, 0.08, 0.10)
		draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), bg, true)
		if texture == null:
			return
		if layout != &"autotile_room" and cells.is_empty():
			return
		var dest_step: float = float(tile_px * PREVIEW_ZOOM)
		var src_step: int = tile_px + gutter
		match layout:
			&"patch3":
				# Centred 3×3 in the 5×5 frame.
				var n: int = mini(cells.size(), 9)
				var offset := Vector2(dest_step, dest_step)
				for i in n:
					var cell: Vector2i = cells[i]
					var gx: int = i % 3
					var gy: int = i / 3
					var dest := Rect2(offset + Vector2(float(gx) * dest_step, float(gy) * dest_step),
							Vector2(dest_step, dest_step))
					var src := Rect2(
							float(cell.x * src_step), float(cell.y * src_step),
							float(tile_px), float(tile_px))
					draw_texture_rect_region(texture, dest, src)
			&"autotile_room":
				if autotile_dict.is_empty():
					return
				_draw_autotile_room(src_step, dest_step)
			_:
				# "tile" — fill the FRAME×FRAME grid by cycling cells.
				for y in FRAME:
					for x in FRAME:
						var idx: int = (y * FRAME + x) % cells.size()
						var cell: Vector2i = cells[idx]
						var dest := Rect2(
								Vector2(float(x) * dest_step, float(y) * dest_step),
								Vector2(dest_step, dest_step))
						var src := Rect2(
								float(cell.x * src_step), float(cell.y * src_step),
								float(tile_px), float(tile_px))
						draw_texture_rect_region(texture, dest, src)


# ─── Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	_load_mappings_resource()
	_discover_sheets()
	_build_ui()
	_populate_sheet_selector()
	_populate_tree()
	_select_mapping(_MAPPINGS[0])


func _load_mappings_resource() -> void:
	if ResourceLoader.exists(MAPPINGS_PATH):
		var r: Resource = load(MAPPINGS_PATH)
		if r is TileMappings:
			# duplicate(true) so edits don't mutate Godot's resource cache
			# until the user explicitly Saves.
			_mappings_resource = r.duplicate(true) as TileMappings
			return
	push_warning("GameEditor: %s missing or wrong type, using defaults" % MAPPINGS_PATH)
	_mappings_resource = TileMappings.default_mappings()


## Scan known asset directories for spritesheet PNGs. Adds every .png
## found under `assets/tiles/` and `assets/characters/`.
func _discover_sheets() -> void:
	_available_sheets.clear()
	var dirs: Array[String] = [
		"res://assets/tiles/roguelike",
		"res://assets/tiles/runes",
		"res://assets/characters/roguelike",
		"res://assets/characters/monsters",
		"res://assets/characters/mounts",
		"res://assets/characters/pets",
		"res://assets/characters/iso_miniature",
	]
	for dir_path in dirs:
		var da := DirAccess.open(dir_path)
		if da == null:
			continue
		da.list_dir_begin()
		var name := da.get_next()
		while name != "":
			if not da.current_is_dir() and name.ends_with(".png"):
				_available_sheets.append(dir_path.path_join(name))
			name = da.get_next()
		da.list_dir_end()
	_available_sheets.sort()


func _populate_sheet_selector() -> void:
	if _sheet_selector == null:
		return
	_sheet_selector.clear()
	for i in _available_sheets.size():
		# Show short label: last two path components (e.g. "roguelike/overworld_sheet.png").
		var path: String = _available_sheets[i]
		var parts: PackedStringArray = path.split("/")
		var label: String = path
		if parts.size() >= 2:
			label = parts[-2] + "/" + parts[-1]
		_sheet_selector.add_item(label, i)


## Resolve the current sheet path for a mapping entry. Checks
## sheet_overrides first, falls back to the entry's default "sheet" key.
func _resolve_sheet(entry: Dictionary) -> String:
	var field: StringName = entry["field"]
	var override: Variant = _mappings_resource.sheet_overrides.get(field, null)
	if override is String and not (override as String).is_empty():
		return override as String
	return entry["sheet"]


func _sync_sheet_selector(new_path: String) -> void:
	if _sheet_selector == null:
		return
	# Block _on_sheet_selected from firing during programmatic sync.
	if _sheet_selector.item_selected.is_connected(_on_sheet_selected):
		_sheet_selector.item_selected.disconnect(_on_sheet_selected)
	for i in _available_sheets.size():
		if _available_sheets[i] == new_path:
			_sheet_selector.select(i)
			_sheet_selector.item_selected.connect(_on_sheet_selected)
			return
	# Sheet not in list — append it.
	_available_sheets.append(new_path)
	_populate_sheet_selector()
	_sheet_selector.select(_available_sheets.size() - 1)
	_sheet_selector.item_selected.connect(_on_sheet_selected)


func _on_sheet_selected(idx: int) -> void:
	if idx < 0 or idx >= _available_sheets.size():
		return
	if _current_mapping.is_empty():
		return
	var new_sheet: String = _available_sheets[idx]
	var field: StringName = _current_mapping["field"]
	var default_sheet: String = _current_mapping["sheet"]
	# Store override only if different from the default.
	if new_sheet == default_sheet:
		_mappings_resource.sheet_overrides.erase(field)
	else:
		_mappings_resource.sheet_overrides[field] = new_sheet
	_mark_dirty()
	# Reload the atlas view with the new sheet.
	var tex: Texture2D = load(new_sheet) as Texture2D
	if tex != null:
		_sheet_view.set_sheet(tex)
		_refresh_marks()
		if _mineable_editor != null and _mineable_editor.visible:
			_mineable_editor.sheet_path = new_sheet
		if _item_editor != null and _item_editor.visible:
			_item_editor.sheet_path = new_sheet
		if _encounter_editor != null and _encounter_editor.visible:
			_encounter_editor.sheet_path = new_sheet
		if _creature_editor != null and _creature_editor.visible:
			_creature_editor.sheet_path = new_sheet
			_creature_editor.gutter = _sheet_view.gutter
		_status_label.text = "sheet → %s" % new_sheet


# ─── UI construction ───────────────────────────────────────────────────

func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	root.add_child(_build_toolbar())

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 280
	root.add_child(split)
	split.add_child(_build_left_pane())

	var inner := HSplitContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.split_offset = -320
	split.add_child(inner)
	inner.add_child(_build_middle_pane())
	inner.add_child(_build_right_pane())

	_status_label = Label.new()
	_status_label.text = "ready"
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	root.add_child(_status_label)


func _build_toolbar() -> Control:
	var hb := HBoxContainer.new()
	var title := Label.new()
	title.text = "Game Editor"
	title.add_theme_font_size_override("font_size", 18)
	hb.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	_save_btn = Button.new()
	_save_btn.text = "Save"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_save)
	hb.add_child(_save_btn)
	_revert_btn = Button.new()
	_revert_btn.text = "Revert"
	_revert_btn.disabled = true
	_revert_btn.pressed.connect(_revert)
	hb.add_child(_revert_btn)
	var path_lbl := Label.new()
	path_lbl.text = "  " + MAPPINGS_PATH
	path_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	hb.add_child(path_lbl)
	return hb


func _build_left_pane() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_make_section_label("Mappings"))
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.item_selected.connect(_on_tree_item_selected)
	vb.add_child(_tree)
	return vb


func _build_middle_pane() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Sheet selector row.
	var sheet_row := HBoxContainer.new()
	sheet_row.add_child(_make_section_label("Sheet"))
	_sheet_selector = OptionButton.new()
	_sheet_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_selector.item_selected.connect(_on_sheet_selected)
	sheet_row.add_child(_sheet_selector)
	vb.add_child(sheet_row)
	vb.add_child(_make_section_label("(click a cell to bind to the active slot)"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	_sheet_view = SheetView.new()
	_sheet_view.tile_px = TILE_PX
	_sheet_view.gutter = TILE_GUTTER
	_sheet_view.zoom = SHEET_ZOOM
	_sheet_view.cell_clicked.connect(_on_cell_clicked)
	scroll.add_child(_sheet_view)
	return vb


func _build_right_pane() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_header_label = _make_section_label("Slots")
	vb.add_child(_header_label)
	_slot_scroll = ScrollContainer.new()
	_slot_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_slot_scroll)
	_slot_root = VBoxContainer.new()
	_slot_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_scroll.add_child(_slot_root)
	_preview_label = _make_section_label("Live preview")
	vb.add_child(_preview_label)
	_preview = PreviewView.new()
	_preview.tile_px = TILE_PX
	_preview.gutter = TILE_GUTTER
	_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview.mask_clicked.connect(_on_preview_mask_clicked)
	vb.add_child(_preview)
	return vb


func _make_section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	return l


# ─── Tree population ───────────────────────────────────────────────────

func _populate_tree() -> void:
	_tree.clear()
	var root := _tree.create_item()
	for entry in _MAPPINGS:
		var item := _tree.create_item(root)
		item.set_text(0, entry["label"])
		item.set_metadata(0, entry["id"])
	# Quest TODO entries.
	var quest_ids: Array[String] = QuestRegistry.all_ids()
	var added_sep := false
	for qid in quest_ids:
		var reqs: Array[Dictionary] = QuestRegistry.get_unimplemented_requirements(qid)
		var actionable: Array[Dictionary] = []
		for r in reqs:
			if r["category"] == "items" or r["category"] == "terrain_features":
				actionable.append(r)
		if actionable.size() == 0:
			continue
		if not added_sep:
			added_sep = true
			var sep_item := _tree.create_item(root)
			sep_item.set_text(0, "── Quest TODO ──")
			sep_item.set_selectable(0, false)
			sep_item.set_custom_color(0, Color(0.9, 0.75, 0.4))
		var quest: Dictionary = QuestRegistry.get_quest(qid)
		var label: String = quest.get("display_name", qid)
		var qi := _tree.create_item(root)
		qi.set_text(0, "%s (%d)" % [label, actionable.size()])
		qi.set_metadata(0, StringName("quest:" + qid))
		qi.set_custom_color(0, Color(0.9, 0.85, 0.6))


func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	var id: StringName = item.get_metadata(0)
	var id_str: String = String(id)
	if id_str.begins_with("quest:"):
		_select_quest_todo(id_str.substr(6))
		return
	for entry in _MAPPINGS:
		if entry["id"] == id:
			_select_mapping(entry)
			return


# ─── Mapping selection ─────────────────────────────────────────────────

func _select_mapping(entry: Dictionary) -> void:
	_hide_quest_panel()
	_current_mapping = entry
	var kind: StringName = entry["kind"]
	var sheet_path: String = _resolve_sheet(entry)
	_sync_sheet_selector(sheet_path)
	var tex: Texture2D = load(sheet_path) as Texture2D
	if tex == null:
		_status_label.text = "ERROR: sheet not found at %s" % sheet_path
		return
	_sheet_view.set_sheet(tex)

	if kind == &"mineable":
		_show_mineable_editor()
		_hide_all_editors_except(&"mineable")
		_refresh_marks()
		_status_label.text = "Editing mineables — %s" % sheet_path
		return

	if kind == &"item_editor":
		_show_item_editor()
		_hide_all_editors_except(&"item_editor")
		_refresh_marks()
		_status_label.text = "Editing items — %s" % sheet_path
		return

	if kind == &"encounter_editor":
		_show_encounter_editor()
		_hide_all_editors_except(&"encounter_editor")
		_refresh_marks()
		_status_label.text = "Editing encounters"
		return

	if kind == &"creature_editor":
		_show_creature_editor()
		_hide_all_editors_except(&"creature_editor")
		_refresh_marks()
		_status_label.text = "Editing creatures"
		return

	if kind == &"loot_table_editor":
		_show_loot_table_editor()
		_hide_all_editors_except(&"loot_table_editor")
		_refresh_marks()
		_status_label.text = "Editing loot tables"
		return

	if kind == &"crafting_editor":
		_show_crafting_editor()
		_hide_all_editors_except(&"crafting_editor")
		_refresh_marks()
		_status_label.text = "Editing crafting recipes"
		return

	if kind == &"armor_set_editor":
		_show_armor_set_editor()
		_hide_all_editors_except(&"armor_set_editor")
		_refresh_marks()
		_status_label.text = "Editing armor sets"
		return

	if kind == &"biome_editor":
		_show_biome_editor()
		_hide_all_editors_except(&"biome_editor")
		_refresh_marks()
		_status_label.text = "Editing biomes"
		return

	if kind == &"shop_editor":
		_show_shop_editor()
		_hide_all_editors_except(&"shop_editor")
		_refresh_marks()
		_status_label.text = "Editing shops"
		return

	if kind == &"quest_editor":
		_show_quest_editor()
		_hide_all_editors_except(&"quest_editor")
		_refresh_marks()
		_status_label.text = "Editing quests (graph)"
		return

	if kind == &"dialogue_editor":
		_show_dialogue_editor()
		_hide_all_editors_except(&"dialogue_editor")
		_refresh_marks()
		_status_label.text = "Editing dialogue (graph)"
		return

	if kind == &"balance_overview":
		_show_balance_overview()
		_hide_all_editors_except(&"balance_overview")
		_refresh_marks()
		_status_label.text = "Balance overview"
		return

	if kind == &"encounter_table_editor":
		_show_encounter_table_editor()
		_hide_all_editors_except(&"encounter_table_editor")
		_refresh_marks()
		_status_label.text = "Editing encounter tables"
		return

	if kind == &"chest_loot_editor":
		_show_chest_loot_editor()
		_hide_all_editors_except(&"chest_loot_editor")
		_refresh_marks()
		_status_label.text = "Editing chest loot tiers"
		return

	if kind == &"asset_browser":
		_show_asset_browser()
		_hide_all_editors_except(&"asset_browser")
		_refresh_marks()
		_status_label.text = "Browsing Kenney assets"
		return

	_hide_all_editors()
	_slot_root.visible = true
	_header_label.visible = true
	if _preview != null:
		_preview.visible = true
	_slots = _build_slots(entry)
	_active_slot = 0 if _slots.size() > 0 else -1
	_header_label.text = "Slots — %s (%s)" % [entry["label"], entry["kind"]]
	_rebuild_slot_ui()
	_refresh_marks()
	_status_label.text = sheet_path


# Build the flat slot list for `entry` from the current resource state.
# Each slot's `path` is what `_get_slot_cell`/`_set_slot_cell` use to
# read or write through the resource.
func _build_slots(entry: Dictionary) -> Array:
	var field: StringName = entry["field"]
	var kind: StringName = entry["kind"]
	if kind == &"mineable" or kind == &"item_editor" or kind == &"encounter_editor" or kind == &"creature_editor" or kind == &"asset_browser" or kind == &"loot_table_editor" or kind == &"crafting_editor" or kind == &"armor_set_editor" or kind == &"biome_editor" or kind == &"shop_editor" or kind == &"quest_editor" or kind == &"dialogue_editor" or kind == &"balance_overview" or kind == &"encounter_table_editor" or kind == &"chest_loot_editor":
		return []  # These use their own editors.
	var value: Variant = _mappings_resource.get(field)
	var out: Array = []

	match kind:
		&"single", &"named":
			# Dictionary[Variant → Vector2i]
			var d: Dictionary = value
			var keys: Array = d.keys()
			keys.sort_custom(func(a, b): return _key_str(a) < _key_str(b))
			for k in keys:
				out.append({
					"label": _key_str(k),
					"path":  [field, k],
					"flip":  -1,
				})
		&"list":
			# Dictionary[StringName → Array[Vector2i]]. One slot per
			# named sub-array; click toggles cells in/out of that array.
			var d: Dictionary = value
			var keys: Array = d.keys()
			keys.sort_custom(func(a, b): return _key_str(a) < _key_str(b))
			for k in keys:
				out.append({
					"label": _key_str(k),
					"path":  [field, k],
					"flip":  -1,
					"is_array": true,
				})
		&"patch3":
			# Dictionary[StringName → Array[Vector2i] (9)]
			var d: Dictionary = value
			var keys: Array = d.keys()
			keys.sort_custom(func(a, b): return _key_str(a) < _key_str(b))
			for k in keys:
				var arr: Array = d[k]
				for i in arr.size():
					out.append({
						"label": "%s[%d] %s" % [_key_str(k), i, _patch3_pos_label(i)],
						"path":  [field, k, i],
						"flip":  -1,
					})
		&"patch3_flat":
			var arr: Array = value
			for i in arr.size():
				out.append({
					"label": "[%d] %s" % [i, _patch3_pos_label(i)],
					"path":  [field, i],
					"flip":  -1,
				})
		&"flat_list":
			# Single Array[Vector2i] for the whole field. One slot;
			# click toggles cells in/out of the array.
			out.append({
				"label": _key_str(field),
				"path":  [field],
				"flip":  -1,
				"is_array": true,
			})
		&"autotile":
			var arr: Array = value
			for i in arr.size():
				var ent: Dictionary = arr[i]
				var mask: int = int(ent.get("mask", 0))
				out.append({
					"label":  "mask=%2d  (%s)" % [mask, _autotile_mask_desc(mask)],
					"path":   [field, i, "cell"],
					"flip_v": int(ent.get("flip_v", ent.get("flip", 0))),
					"flip_h": int(ent.get("flip_h", 0)),
				})
	return out


# Patch 3×3 position labels — match the NW…SE ordering used by both the
# patch helper in world_root.gd and the resource itself.
static func _patch3_pos_label(i: int) -> String:
	const LBL := ["NW", "N", "NE", "W", "C", "E", "SW", "S", "SE"]
	if i >= 0 and i < LBL.size():
		return LBL[i]
	return "?"


# Decode the 4-bit floor-neighbour mask into a compact direction string.
static func _autotile_mask_desc(mask: int) -> String:
	var parts: Array = []
	if mask & 8: parts.append("N")
	if mask & 4: parts.append("S")
	if mask & 2: parts.append("E")
	if mask & 1: parts.append("W")
	return "+".join(parts) if parts.size() > 0 else "—"


# Pretty-print arbitrary keys (StringName, Vector2i, etc.) for slot
# labels and sort-comparison.
static func _key_str(k: Variant) -> String:
	if k is Vector2i:
		return "(%d,%d)" % [k.x, k.y]
	return str(k)


# ─── Slot UI ───────────────────────────────────────────────────────────

func _rebuild_slot_ui() -> void:
	for c in _slot_root.get_children():
		c.queue_free()
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var row := HBoxContainer.new()
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_pressed = (i == _active_slot)
		if slot.get("is_array", false):
			var arr: Variant = _get_at_path(slot["path"])
			var n: int = (arr as Array).size() if arr is Array else 0
			btn.text = "%s   (%d cell%s) — click atlas to add/remove" % [
					slot["label"], n, "" if n == 1 else "s"]
		else:
			btn.text = "%s   →   %s" % [slot["label"], _str_cell(_get_slot_cell(i))]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_slot_pressed.bind(i))
		row.add_child(btn)
		# Autotile rows get Flip V and Flip H checkboxes.
		if slot.get("flip_v", -1) >= 0:
			var flip_v := CheckBox.new()
			flip_v.text = "flip V"
			flip_v.button_pressed = (int(slot["flip_v"]) == 1)
			flip_v.toggled.connect(_on_flip_v_toggled.bind(i))
			row.add_child(flip_v)
			var flip_h := CheckBox.new()
			flip_h.text = "flip H"
			flip_h.button_pressed = (int(slot["flip_h"]) == 1)
			flip_h.toggled.connect(_on_flip_h_toggled.bind(i))
			row.add_child(flip_h)
		_slot_root.add_child(row)


func _on_slot_pressed(idx: int) -> void:
	_active_slot = idx
	_rebuild_slot_ui()
	_refresh_marks()
	if idx >= 0 and idx < _slots.size():
		_status_label.text = "active slot: %s = %s" % [
				_slots[idx]["label"], _str_cell(_get_slot_cell(idx))]


## Called when the user clicks a wall cell in the autotile room preview.
## Finds the slot whose mask matches and activates it.
func _on_preview_mask_clicked(mask: int) -> void:
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		# Autotile slot paths are [field, array_index, "cell"].
		if slot["path"].size() < 2:
			continue
		var field: StringName = _current_mapping.get("field", &"")
		if field == &"":
			continue
		var arr: Array = _mappings_resource.get(field)
		var slot_idx: int = int(slot["path"][1])
		if slot_idx < 0 or slot_idx >= arr.size():
			continue
		if int(arr[slot_idx].get("mask", -1)) == mask:
			_on_slot_pressed(i)
			return


func _on_flip_v_toggled(pressed: bool, idx: int) -> void:
	if idx < 0 or idx >= _slots.size():
		return
	var slot: Dictionary = _slots[idx]
	if slot.get("flip_v", -1) < 0:
		return
	var path: Array = slot["path"].duplicate()
	path[-1] = "flip_v"
	var new_val: int = 1 if pressed else 0
	_set_at_path(path, new_val)
	slot["flip_v"] = new_val
	_mark_dirty()
	_refresh_marks()
	_status_label.text = "%s flip_v = %d" % [slot["label"], new_val]


func _on_flip_h_toggled(pressed: bool, idx: int) -> void:
	if idx < 0 or idx >= _slots.size():
		return
	var slot: Dictionary = _slots[idx]
	if slot.get("flip_h", -1) < 0:
		return
	var path: Array = slot["path"].duplicate()
	path[-1] = "flip_h"
	var new_val: int = 1 if pressed else 0
	_set_at_path(path, new_val)
	slot["flip_h"] = new_val
	_mark_dirty()
	_refresh_marks()
	_status_label.text = "%s flip_h = %d" % [slot["label"], new_val]


# ─── Cell click handler ────────────────────────────────────────────────

func _on_cell_clicked(cell: Vector2i) -> void:
	# Route to mineable editor if active.
	if _mineable_editor != null and _mineable_editor.visible:
		_mineable_editor.on_atlas_cell_clicked(cell)
		_refresh_marks()
		_status_label.text = "toggled sprite %s" % _str_cell(cell)
		return
	# Route to item editor if active.
	if _item_editor != null and _item_editor.visible:
		_item_editor.on_atlas_cell_clicked(cell)
		_refresh_marks()
		_status_label.text = "set item icon to %s" % _str_cell(cell)
		return
	# Route to encounter editor if active.
	if _encounter_editor != null and _encounter_editor.visible:
		_encounter_editor.on_atlas_cell_clicked(cell)
		_refresh_marks()
		_status_label.text = "encounter editor: picked %s" % _str_cell(cell)
		return
	# Route to creature editor if active.
	if _creature_editor != null and _creature_editor.visible:
		_creature_editor.on_atlas_cell_clicked(cell)
		_refresh_marks()
		_status_label.text = "creature editor: picked %s" % _str_cell(cell)
		return
	# Route to new data editors (they generally don't use atlas clicks).
	if _loot_table_editor != null and _loot_table_editor.visible:
		_loot_table_editor.on_atlas_cell_clicked(cell)
		return
	if _crafting_editor != null and _crafting_editor.visible:
		_crafting_editor.on_atlas_cell_clicked(cell)
		return
	if _armor_set_editor != null and _armor_set_editor.visible:
		_armor_set_editor.on_atlas_cell_clicked(cell)
		return
	if _biome_editor != null and _biome_editor.visible:
		_biome_editor.on_atlas_cell_clicked(cell)
		return
	if _shop_editor != null and _shop_editor.visible:
		_shop_editor.on_atlas_cell_clicked(cell)
		return
	if _quest_editor != null and _quest_editor.visible:
		_quest_editor.on_atlas_cell_clicked(cell)
		return
	if _dialogue_editor != null and _dialogue_editor.visible:
		_dialogue_editor.on_atlas_cell_clicked(cell)
		return
	if _balance_overview != null and _balance_overview.visible:
		_balance_overview.on_atlas_cell_clicked(cell)
		return
	if _active_slot < 0 or _active_slot >= _slots.size():
		_status_label.text = "no active slot — pick one in the right pane first"
		return
	var slot: Dictionary = _slots[_active_slot]
	if slot.get("is_array", false):
		var arr: Variant = _get_at_path(slot["path"])
		if not (arr is Array):
			_status_label.text = "slot path is not an Array — cannot toggle"
			return
		var typed: Array = arr
		var idx: int = typed.find(cell)
		if idx >= 0:
			typed.remove_at(idx)
			_status_label.text = "removed %s from %s (now %d)" % [
					_str_cell(cell), slot["label"], typed.size()]
		else:
			typed.append(cell)
			_status_label.text = "added %s to %s (now %d)" % [
					_str_cell(cell), slot["label"], typed.size()]
	else:
		_set_slot_cell(_active_slot, cell)
		_status_label.text = "%s = %s" % [slot["label"], _str_cell(cell)]
	_mark_dirty()
	_rebuild_slot_ui()
	_refresh_marks()


# ─── Save / Revert ─────────────────────────────────────────────────────

func _mark_dirty() -> void:
	_dirty = true
	_save_btn.disabled = false
	_revert_btn.disabled = false


func _save() -> void:
	# Save mineable data if the mineable editor is active and dirty.
	if _mineable_editor != null and _mineable_editor.is_dirty():
		_mineable_editor.save()
	if _item_editor != null and _item_editor.is_dirty():
		_item_editor.save()
	if _encounter_editor != null and _encounter_editor.is_dirty():
		_encounter_editor.save()
	if _creature_editor != null and _creature_editor.is_dirty():
		_creature_editor.save()
	if _loot_table_editor != null and _loot_table_editor.is_dirty():
		_loot_table_editor.save()
	if _crafting_editor != null and _crafting_editor.is_dirty():
		_crafting_editor.save()
	if _armor_set_editor != null and _armor_set_editor.is_dirty():
		_armor_set_editor.save()
	if _biome_editor != null and _biome_editor.is_dirty():
		_biome_editor.save()
	if _shop_editor != null and _shop_editor.is_dirty():
		_shop_editor.save()
	if _quest_editor != null and _quest_editor.is_dirty():
		_quest_editor.save()
	if _dialogue_editor != null and _dialogue_editor.is_dirty():
		_dialogue_editor.save()
	if _balance_overview != null and _balance_overview.is_dirty():
		_balance_overview.save()
	if _encounter_table_editor != null and _encounter_table_editor.is_dirty():
		_encounter_table_editor.save()
	if _chest_loot_editor != null and _chest_loot_editor.is_dirty():
		_chest_loot_editor.save()
	var err: int = ResourceSaver.save(_mappings_resource, MAPPINGS_PATH)
	if err != OK:
		_status_label.text = "SAVE FAILED (err %d)" % err
		return
	_dirty = false
	_save_btn.disabled = true
	_revert_btn.disabled = true
	_status_label.text = "saved → %s" % MAPPINGS_PATH


func _revert() -> void:
	# Revert mineable data if the mineable editor exists.
	if _mineable_editor != null:
		_mineable_editor.revert()
	if _item_editor != null:
		_item_editor.revert()
	if _encounter_editor != null:
		_encounter_editor.revert()
	if _creature_editor != null:
		_creature_editor.revert()
	if _loot_table_editor != null:
		_loot_table_editor.revert()
	if _crafting_editor != null:
		_crafting_editor.revert()
	if _armor_set_editor != null:
		_armor_set_editor.revert()
	if _biome_editor != null:
		_biome_editor.revert()
	if _shop_editor != null:
		_shop_editor.revert()
	if _quest_editor != null:
		_quest_editor.revert()
	if _dialogue_editor != null:
		_dialogue_editor.revert()
	if _balance_overview != null:
		_balance_overview.revert()
	if _encounter_table_editor != null:
		_encounter_table_editor.revert()
	if _chest_loot_editor != null:
		_chest_loot_editor.revert()
	# Force a fresh load — drop the cached resource so subsequent loads
	# pick up the on-disk version (in case it was edited externally).
	if ResourceLoader.has_cached(MAPPINGS_PATH):
		# No public API to evict a single resource cache entry in 4.3, so
		# we just `load()` and trust it; the duplicate(true) below means
		# our working copy is independent regardless.
		pass
	_load_mappings_resource()
	_dirty = false
	_save_btn.disabled = true
	_revert_btn.disabled = true
	if not _current_mapping.is_empty():
		_select_mapping(_current_mapping)
	_status_label.text = "reverted"


# ─── Slot read/write through path ──────────────────────────────────────

func _get_slot_cell(idx: int) -> Vector2i:
	if idx < 0 or idx >= _slots.size():
		return Vector2i(-1, -1)
	var v: Variant = _get_at_path(_slots[idx]["path"])
	if v is Vector2i:
		return v
	return Vector2i(-1, -1)


func _set_slot_cell(idx: int, cell: Vector2i) -> void:
	if idx < 0 or idx >= _slots.size():
		return
	_set_at_path(_slots[idx]["path"], cell)


# Walk `path` against the resource. Path elements: first is the field
# StringName; subsequent elements are dict keys or array indices.
func _get_at_path(path: Array) -> Variant:
	var cur: Variant = _mappings_resource.get(path[0])
	for i in range(1, path.size()):
		var step: Variant = path[i]
		if cur is Dictionary:
			cur = (cur as Dictionary).get(step, null)
		elif cur is Array:
			var idx: int = int(step)
			var arr: Array = cur
			if idx < 0 or idx >= arr.size():
				return null
			cur = arr[idx]
		else:
			return null
		if cur == null:
			return null
	return cur


# Write `value` to the location addressed by `path`. We walk to the
# parent container, then mutate the leaf in place. Containers in Godot
# are reference-typed so this propagates back into the resource.
func _set_at_path(path: Array, value: Variant) -> void:
	var parent: Variant = _mappings_resource.get(path[0])
	for i in range(1, path.size() - 1):
		var step: Variant = path[i]
		if parent is Dictionary:
			parent = (parent as Dictionary)[step]
		elif parent is Array:
			parent = (parent as Array)[int(step)]
	var leaf: Variant = path[-1]
	if parent is Dictionary:
		(parent as Dictionary)[leaf] = value
	elif parent is Array:
		(parent as Array)[int(leaf)] = value


# ─── Mark refresh (sheet overlay) ──────────────────────────────────────

func _refresh_marks() -> void:
	# Use mineable editor marks when in mineable mode.
	if _mineable_editor != null and _mineable_editor.visible:
		_sheet_view.set_marks(_mineable_editor.get_marks())
		return
	if _item_editor != null and _item_editor.visible:
		_sheet_view.set_marks(_item_editor.get_marks())
		return
	if _encounter_editor != null and _encounter_editor.visible:
		_sheet_view.set_marks(_encounter_editor.get_marks())
		return
	if _creature_editor != null and _creature_editor.visible:
		_sheet_view.set_marks(_creature_editor.get_marks())
		return
	if _loot_table_editor != null and _loot_table_editor.visible:
		_sheet_view.set_marks(_loot_table_editor.get_marks())
		return
	if _crafting_editor != null and _crafting_editor.visible:
		_sheet_view.set_marks(_crafting_editor.get_marks())
		return
	if _armor_set_editor != null and _armor_set_editor.visible:
		_sheet_view.set_marks(_armor_set_editor.get_marks())
		return
	if _biome_editor != null and _biome_editor.visible:
		_sheet_view.set_marks(_biome_editor.get_marks())
		return
	if _shop_editor != null and _shop_editor.visible:
		_sheet_view.set_marks(_shop_editor.get_marks())
		return
	if _quest_editor != null and _quest_editor.visible:
		_sheet_view.set_marks(_quest_editor.get_marks())
		return
	if _dialogue_editor != null and _dialogue_editor.visible:
		_sheet_view.set_marks(_dialogue_editor.get_marks())
		return
	if _balance_overview != null and _balance_overview.visible:
		_sheet_view.set_marks(_balance_overview.get_marks())
		return
	var marks: Array = []
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var is_active: bool = (i == _active_slot)
		if slot.get("is_array", false):
			var arr: Variant = _get_at_path(slot["path"])
			if not (arr is Array):
				continue
			for c in arr:
				if not (c is Vector2i):
					continue
				if is_active:
					marks.append({"cell": c, "color": COLOR_ACTIVE, "width": 3.0})
				else:
					marks.append({"cell": c, "color": COLOR_BOUND, "width": 2.0})
		else:
			var c: Vector2i = _get_slot_cell(i)
			if c.x < 0:
				continue
			if is_active:
				marks.append({"cell": c, "color": COLOR_ACTIVE, "width": 3.0})
			else:
				marks.append({"cell": c, "color": COLOR_BOUND, "width": 2.0})
	_sheet_view.set_marks(marks)
	_refresh_preview()


# Build the preview cell list for the focused mapping. For `patch3` we
# render only the active slot's 9-cell group (the one the user is looking
# at); for everything else we cycle through every bound cell.
func _refresh_preview() -> void:
	if _preview == null or _current_mapping.is_empty():
		return
	var tex: Texture2D = load(_resolve_sheet(_current_mapping)) as Texture2D
	if tex == null:
		_preview.set_data(null, [], &"tile")
		return
	var kind: StringName = _current_mapping["kind"]
	var cells: Array = []
	var layout: StringName = &"tile"
	match kind:
		&"patch3":
			layout = &"patch3"
			cells = _active_patch3_group_cells()
		&"patch3_flat":
			layout = &"patch3"
			var arr: Array = _mappings_resource.get(_current_mapping["field"])
			cells = arr.duplicate()
		&"autotile":
			var field: StringName = _current_mapping["field"]
			var arr: Array = _mappings_resource.get(field)
			var at_dict: Dictionary = {}
			for entry in arr:
				var mask: int = int(entry.get("mask", -1))
				if mask < 0:
					continue
				var cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
				var flip_v: bool = int(entry.get("flip_v", entry.get("flip", 0))) != 0
				var flip_h: bool = int(entry.get("flip_h", 0)) != 0
				at_dict[mask] = [cell, flip_v, flip_h]
			# Determine the active slot's mask so the preview can highlight it.
			var active_mask: int = -1
			if _active_slot >= 0 and _active_slot < _slots.size():
				var active_path: Array = _slots[_active_slot]["path"]
				# path is [field, array_index, "cell"]; lookup mask from the entry.
				if active_path.size() >= 2:
					var slot_arr: Array = _mappings_resource.get(field)
					var slot_idx: int = int(active_path[1])
					if slot_idx >= 0 and slot_idx < slot_arr.size():
						active_mask = int(slot_arr[slot_idx].get("mask", -1))
			_preview.set_autotile_data(tex, at_dict, active_mask)
			return
		_:
			for i in _slots.size():
				var slot: Dictionary = _slots[i]
				if slot.get("is_array", false):
					var arr: Variant = _get_at_path(slot["path"])
					if arr is Array:
						for cc in arr:
							if cc is Vector2i:
								cells.append(cc)
				else:
					var c: Vector2i = _get_slot_cell(i)
					if c.x >= 0:
						cells.append(c)
	_preview.set_data(tex, cells, layout)


# Pull the 9 cells of the 3×3 group containing the active slot. Returns
# an empty array if there's no active slot or its parent group can't be
# read.
func _active_patch3_group_cells() -> Array:
	if _active_slot < 0 or _active_slot >= _slots.size():
		return []
	var path: Array = _slots[_active_slot]["path"]
	# path is [field, key, idx]; drop idx to get the parent Array[Vector2i].
	if path.size() < 3:
		return []
	var parent_path: Array = path.slice(0, path.size() - 1)
	var parent: Variant = _get_at_path(parent_path)
	if parent is Array:
		return (parent as Array).duplicate()
	return []


# ─── Misc ──────────────────────────────────────────────────────────────

static func _str_cell(c: Vector2i) -> String:
	return "(%d, %d)" % [c.x, c.y]


# ─── Quest TODO panel ─────────────────────────────────────────────────

const _ICON_DIR := "res://assets/icons/generic_items/"
const _ITEM_SAVE_DIR := "res://resources/items/"
const _ICON_COLS := 10
const _ICON_SIZE := 36

func _select_quest_todo(quest_id: String) -> void:
	_hide_mineable_editor()
	_hide_item_editor()
	_hide_encounter_editor()
	_hide_creature_editor()
	_hide_asset_browser()
	_current_mapping = {}
	_slots = []
	_active_slot = -1
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_sheet_view.clear_marks()
	_show_quest_panel(quest_id)
	_status_label.text = "Quest requirements — %s" % quest_id


func _show_quest_panel(quest_id: String) -> void:
	_hide_quest_panel()

	var unimpl: Array[Dictionary] = QuestRegistry.get_unimplemented_requirements(quest_id)
	var quest: Dictionary = QuestRegistry.get_quest(quest_id)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Title.
	var title := Label.new()
	title.text = quest.get("display_name", quest_id)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = quest.get("description", "")
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(desc)

	# Separate items and terrain features.
	var items: Array[Dictionary] = []
	var features: Array[Dictionary] = []
	for r in unimpl:
		if r["category"] == "items":
			items.append(r)
		elif r["category"] == "terrain_features":
			features.append(r)

	# Items section.
	if items.size() > 0:
		vbox.add_child(_quest_section_label("Items (%d)" % items.size()))
		_quest_item_btns.clear()
		for item_req in items:
			var row := _build_quest_item_row(item_req)
			vbox.add_child(row)

	# Terrain features section.
	if features.size() > 0:
		vbox.add_child(_quest_section_label("Terrain Features (%d)" % features.size()))
		_quest_feature_btns.clear()
		for feat_req in features:
			var row := _build_quest_feature_row(feat_req)
			vbox.add_child(row)

	# Icon picker grid for items.
	if items.size() > 0:
		vbox.add_child(_quest_section_label("Pick Icon (click Create first)"))
		_quest_icon_grid = _build_icon_grid()
		vbox.add_child(_quest_icon_grid)

	_quest_panel = scroll
	# Add to the right pane VBox (same parent as mineable editor).
	_slot_root.get_parent().get_parent().add_child(_quest_panel)


func _hide_quest_panel() -> void:
	if _quest_panel != null:
		_quest_panel.queue_free()
		_quest_panel = null
		_quest_icon_grid = null
	_quest_creating_item = ""
	_quest_item_btns.clear()
	_quest_feature_btns.clear()
	_slot_root.visible = true
	_header_label.visible = true
	if _preview != null:
		_preview.visible = true


func _quest_section_label(text: String) -> Label:
	var l := Label.new()
	l.text = "── %s ──" % text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	return l


func _build_quest_item_row(req: Dictionary) -> HBoxContainer:
	var id: String = req.get("id", "")
	var source: String = req.get("source", "")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = id
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)

	# Show source hint as tooltip.
	lbl.tooltip_text = source

	# Check if .tres already exists.
	var tres_path: String = _ITEM_SAVE_DIR + id + ".tres"
	var already_exists: bool = ResourceLoader.exists(tres_path)

	var btn := Button.new()
	if already_exists:
		btn.text = "✓ Created"
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		btn.text = "Create"
		btn.pressed.connect(_on_quest_create_item.bind(req, btn))
	row.add_child(btn)

	# Icon thumbnail (shown after picking).
	var icon_rect := TextureRect.new()
	icon_rect.name = "IconPreview"
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if already_exists:
		var def := load(tres_path) as ItemDefinition
		if def != null and def.icon != null:
			icon_rect.texture = def.icon
	row.add_child(icon_rect)

	_quest_item_btns[id] = btn
	return row


func _build_quest_feature_row(req: Dictionary) -> HBoxContainer:
	var id: String = req.get("id", "")
	var desc: String = req.get("description", "")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = id
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.tooltip_text = desc
	row.add_child(lbl)

	# Check if mineable already exists.
	var existing: Variant = MineableRegistry.get_resource(StringName(id))
	var already_exists: bool = existing != null and existing is Dictionary

	var btn := Button.new()
	if already_exists:
		btn.text = "✓ Created"
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		btn.text = "Create Mineable"
		btn.pressed.connect(_on_quest_create_feature.bind(req, btn))
	row.add_child(btn)

	_quest_feature_btns[id] = btn
	return row


func _on_quest_create_item(req: Dictionary, btn: Button) -> void:
	var id: String = req.get("id", "")
	if id.is_empty():
		return

	# Create stub ItemDefinition and save as .tres.
	var def := ItemDefinition.new()
	def.id = StringName(id)
	def.display_name = id.replace("_", " ").capitalize()
	def.stack_size = 99
	def.slot = ItemDefinition.Slot.NONE
	def.power = 0
	def.description = req.get("source", "")

	# Ensure directory exists.
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_ITEM_SAVE_DIR))

	var path: String = _ITEM_SAVE_DIR + id + ".tres"
	var err: int = ResourceSaver.save(def, path)
	if err != OK:
		_status_label.text = "ERROR saving %s (err %d)" % [path, err]
		return

	btn.text = "→ Pick icon below"
	btn.disabled = true
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))

	_quest_creating_item = id
	_status_label.text = "Created %s — click an icon below to assign it" % path


func _on_quest_create_feature(req: Dictionary, btn: Button) -> void:
	var id: String = req.get("id", "")
	if id.is_empty():
		return

	# Ensure mineable editor exists and has data.
	if _mineable_editor == null:
		_mineable_editor = MineableEditor.new()
		_mineable_editor.dirty_changed.connect(_on_mineable_dirty)
		_mineable_editor.navigate_to_item.connect(_on_navigate_to_item)
		_slot_root.get_parent().get_parent().add_child(_mineable_editor)
		_mineable_editor.visible = false

	# Create the resource entry in the mineable editor's data.
	var data: Dictionary = MineableRegistry.get_raw_data().duplicate(true)
	var res: Dictionary = data.get("resources", {})
	if not res.has(id):
		res[id] = {
			"display_name": id.replace("_", " ").capitalize(),
			"ref_id": id,
			"is_tall": false,
			"is_pickaxe_bonus": false,
			"hp": 1,
			"sprites": [],
			"biome_weights": {},
			"drops": [],
		}
		data["resources"] = res
		MineableRegistry.save_data(data)
		MineableRegistry.reload()

	btn.text = "✓ Created"
	btn.disabled = true
	btn.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	_status_label.text = "Created mineable '%s' — select Mineable Resources to edit" % id

	# Reload the mineable editor's data so it sees the new entry.
	if _mineable_editor != null:
		_mineable_editor.revert()

	# Switch to the mineable editor tree entry.
	var root_item: TreeItem = _tree.get_root()
	if root_item != null:
		var child: TreeItem = root_item.get_first_child()
		while child != null:
			if child.get_metadata(0) == &"mineable_resources":
				child.select(0)
				_on_tree_item_selected()
				break
			child = child.get_next()


func _build_icon_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = _ICON_COLS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)

	# Scan the icon directory.
	var da := DirAccess.open(_ICON_DIR)
	if da == null:
		var lbl := Label.new()
		lbl.text = "(cannot open %s)" % _ICON_DIR
		grid.add_child(lbl)
		return grid

	var files: Array[String] = []
	da.list_dir_begin()
	var fname: String = da.get_next()
	while fname != "":
		if not da.current_is_dir() and fname.ends_with(".png"):
			files.append(fname)
		fname = da.get_next()
	da.list_dir_end()
	files.sort()

	for f in files:
		var path: String = _ICON_DIR + f
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(_ICON_SIZE, _ICON_SIZE)
		btn.icon = tex
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
		btn.flat = true
		btn.tooltip_text = f
		btn.pressed.connect(_on_quest_icon_picked.bind(path))
		grid.add_child(btn)

	return grid


func _on_quest_icon_picked(icon_path: String) -> void:
	if _quest_creating_item.is_empty():
		_status_label.text = "Click Create on an item first, then pick an icon"
		return

	var tres_path: String = _ITEM_SAVE_DIR + _quest_creating_item + ".tres"
	if not ResourceLoader.exists(tres_path):
		_status_label.text = "ERROR: %s not found — create item first" % tres_path
		return

	# Load, set icon, save.
	var def := load(tres_path) as ItemDefinition
	if def == null:
		_status_label.text = "ERROR: failed to load %s" % tres_path
		return

	var tex: Texture2D = load(icon_path) as Texture2D
	def.icon = tex
	var err: int = ResourceSaver.save(def, tres_path)
	if err != OK:
		_status_label.text = "ERROR saving icon (err %d)" % err
		return

	# Update the button and icon preview in the row.
	var btn: Variant = _quest_item_btns.get(_quest_creating_item, null)
	if btn is Button:
		(btn as Button).text = "✓ Created"
		(btn as Button).add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		# Find the IconPreview in the same row.
		var row: HBoxContainer = (btn as Button).get_parent() as HBoxContainer
		if row != null:
			var icon_rect: TextureRect = row.get_node_or_null("IconPreview") as TextureRect
			if icon_rect != null:
				icon_rect.texture = tex

	_status_label.text = "Set icon for '%s' → %s" % [_quest_creating_item, icon_path.get_file()]
	_quest_creating_item = ""


# ─── Mineable editor integration ──────────────────────────────────────

func _show_mineable_editor() -> void:
	# Hide normal slot UI and quest panel.
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _mineable_editor == null:
		_mineable_editor = MineableEditor.new()
		_mineable_editor.dirty_changed.connect(_on_mineable_dirty)
		_mineable_editor.navigate_to_item.connect(_on_navigate_to_item)
		# Insert into the right pane's parent (the ScrollContainer that
		# holds _slot_root).
		_slot_root.get_parent().get_parent().add_child(_mineable_editor)
	_mineable_editor.sheet_path = _resolve_sheet(_current_mapping)
	_mineable_editor.visible = true


func _hide_mineable_editor() -> void:
	if _mineable_editor != null:
		_mineable_editor.visible = false


func _on_mineable_dirty() -> void:
	_mark_dirty()
	_refresh_marks()


# ─── Item editor integration ──────────────────────────────────────────

func _show_item_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_slot_scroll.visible = false
	_header_label.visible = false
	_preview_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _item_editor == null:
		_item_editor = ItemEditor.new()
		_item_editor.dirty_changed.connect(_on_item_dirty)
		_item_editor.navigate_to_mineable.connect(_on_navigate_to_mineable)
		_item_editor.sheet_requested.connect(_on_item_sheet_requested)
		_slot_root.get_parent().get_parent().add_child(_item_editor)
	_item_editor.sheet_path = _resolve_sheet(_current_mapping)
	_item_editor.visible = true


func _hide_item_editor() -> void:
	if _item_editor != null:
		_item_editor.visible = false
	_slot_scroll.visible = true
	_header_label.visible = true
	_preview_label.visible = true
	if _preview != null:
		_preview.visible = true


func _on_item_dirty() -> void:
	_mark_dirty()
	_refresh_marks()


func _on_item_sheet_requested(path: String) -> void:
	## Switch the atlas view to the requested sheet when the user selects
	## an item whose icon lives on a different sheet.
	if path.is_empty():
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	_item_editor.sheet_path = path
	_sheet_view.set_sheet(tex)
	# Update the sheet dropdown to reflect the new sheet.
	for i in _available_sheets.size():
		if _available_sheets[i] == path:
			_sheet_selector.select(i)
			break
	_refresh_marks()


# ─── Encounter editor integration ─────────────────────────────────────

func _show_encounter_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _encounter_editor == null:
		_encounter_editor = EncounterEditor.new()
		_encounter_editor.dirty_changed.connect(_on_encounter_dirty)
		_slot_root.get_parent().get_parent().add_child(_encounter_editor)
	_encounter_editor.sheet_path = _resolve_sheet(_current_mapping)
	_encounter_editor.visible = true


func _hide_encounter_editor() -> void:
	if _encounter_editor != null:
		_encounter_editor.visible = false


func _on_encounter_dirty() -> void:
	_mark_dirty()
	_refresh_marks()


# ─── Creature editor integration ──────────────────────────────────────

func _show_creature_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _creature_editor == null:
		_creature_editor = CreatureEditor.new()
		_creature_editor.dirty_changed.connect(_on_creature_dirty)
		_creature_editor.sheet_requested.connect(_on_creature_sheet_requested)
		_slot_root.get_parent().get_parent().add_child(_creature_editor)
	_creature_editor.sheet_path = _resolve_sheet(_current_mapping)
	_creature_editor.gutter = _sheet_view.gutter
	_creature_editor.visible = true


func _hide_creature_editor() -> void:
	if _creature_editor != null:
		_creature_editor.visible = false


func _on_creature_dirty() -> void:
	_mark_dirty()
	_refresh_marks()


func _on_creature_sheet_requested(path: String) -> void:
	# When the creature editor requests a sheet, switch the atlas view.
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_sheet_view.set_sheet(tex)
		_creature_editor.gutter = _sheet_view.gutter
		_sync_sheet_selector(path)


# ─── Asset browser integration ─────────────────────────────────────────

func _show_asset_browser() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _asset_browser == null:
		_asset_browser = AssetBrowser.new()
		_slot_root.get_parent().get_parent().add_child(_asset_browser)
	_asset_browser.visible = true


func _hide_asset_browser() -> void:
	if _asset_browser != null:
		_asset_browser.visible = false


# ─── Loot Table editor integration ────────────────────────────────────

func _show_loot_table_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _loot_table_editor == null:
		_loot_table_editor = LootTableEditor.new()
		_loot_table_editor.dirty_changed.connect(_on_loot_table_dirty)
		_slot_root.get_parent().get_parent().add_child(_loot_table_editor)
	_loot_table_editor.visible = true


func _hide_loot_table_editor() -> void:
	if _loot_table_editor != null:
		_loot_table_editor.visible = false


func _on_loot_table_dirty() -> void:
	_mark_dirty()


# ─── Crafting editor integration ──────────────────────────────────────

func _show_crafting_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _crafting_editor == null:
		_crafting_editor = CraftingEditor.new()
		_crafting_editor.dirty_changed.connect(_on_crafting_dirty)
		_slot_root.get_parent().get_parent().add_child(_crafting_editor)
	_crafting_editor.visible = true


func _hide_crafting_editor() -> void:
	if _crafting_editor != null:
		_crafting_editor.visible = false


func _on_crafting_dirty() -> void:
	_mark_dirty()


# ─── Armor Set editor integration ────────────────────────────────────

func _show_armor_set_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _armor_set_editor == null:
		_armor_set_editor = ArmorSetEditor.new()
		_armor_set_editor.dirty_changed.connect(_on_armor_set_dirty)
		_slot_root.get_parent().get_parent().add_child(_armor_set_editor)
	_armor_set_editor.visible = true


func _hide_armor_set_editor() -> void:
	if _armor_set_editor != null:
		_armor_set_editor.visible = false


func _on_armor_set_dirty() -> void:
	_mark_dirty()


# ─── Biome editor integration ────────────────────────────────────────

func _show_biome_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _biome_editor == null:
		_biome_editor = BiomeEditor.new()
		_biome_editor.dirty_changed.connect(_on_biome_dirty)
		_slot_root.get_parent().get_parent().add_child(_biome_editor)
	_biome_editor.visible = true


func _hide_biome_editor() -> void:
	if _biome_editor != null:
		_biome_editor.visible = false


func _on_biome_dirty() -> void:
	_mark_dirty()


# ─── Shop editor integration ──────────────────────────────────────────

func _show_shop_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _shop_editor == null:
		_shop_editor = ShopEditor.new()
		_shop_editor.dirty_changed.connect(_on_shop_dirty)
		_slot_root.get_parent().get_parent().add_child(_shop_editor)
	_shop_editor.visible = true


func _hide_shop_editor() -> void:
	if _shop_editor != null:
		_shop_editor.visible = false


func _on_shop_dirty() -> void:
	_mark_dirty()


func _show_quest_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _quest_editor == null:
		_quest_editor = QuestEditor.new()
		_quest_editor.dirty_changed.connect(_on_quest_editor_dirty)
		_slot_root.get_parent().get_parent().add_child(_quest_editor)
	_quest_editor.visible = true


func _hide_quest_editor() -> void:
	if _quest_editor != null:
		_quest_editor.visible = false


func _on_quest_editor_dirty() -> void:
	_mark_dirty()


func _show_dialogue_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _dialogue_editor == null:
		_dialogue_editor = DialogueEditor.new()
		_dialogue_editor.dirty_changed.connect(_on_dialogue_editor_dirty)
		_slot_root.get_parent().get_parent().add_child(_dialogue_editor)
	_dialogue_editor.visible = true


func _hide_dialogue_editor() -> void:
	if _dialogue_editor != null:
		_dialogue_editor.visible = false


func _on_dialogue_editor_dirty() -> void:
	_mark_dirty()


func _show_balance_overview() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _balance_overview == null:
		_balance_overview = BalanceOverview.new()
		_balance_overview.dirty_changed.connect(_on_balance_overview_dirty)
		_slot_root.get_parent().get_parent().add_child(_balance_overview)
	_balance_overview.visible = true


func _hide_balance_overview() -> void:
	if _balance_overview != null:
		_balance_overview.visible = false


func _on_balance_overview_dirty() -> void:
	_mark_dirty()


# ─── Encounter Table editor integration ──────────────────────────────

func _show_encounter_table_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _encounter_table_editor == null:
		_encounter_table_editor = EncounterTableEditor.new()
		_encounter_table_editor.dirty_changed.connect(_on_encounter_table_dirty)
		_slot_root.get_parent().get_parent().add_child(_encounter_table_editor)
	_encounter_table_editor.visible = true


func _hide_encounter_table_editor() -> void:
	if _encounter_table_editor != null:
		_encounter_table_editor.visible = false


func _on_encounter_table_dirty() -> void:
	_mark_dirty()


# ─── Chest Loot editor integration ───────────────────────────────────

func _show_chest_loot_editor() -> void:
	_hide_quest_panel()
	_slot_root.visible = false
	_header_label.visible = false
	if _preview != null:
		_preview.visible = false
	_slots = []
	_active_slot = -1

	if _chest_loot_editor == null:
		_chest_loot_editor = ChestLootEditor.new()
		_chest_loot_editor.dirty_changed.connect(_on_chest_loot_dirty)
		_slot_root.get_parent().get_parent().add_child(_chest_loot_editor)
	_chest_loot_editor.visible = true


func _hide_chest_loot_editor() -> void:
	if _chest_loot_editor != null:
		_chest_loot_editor.visible = false


func _on_chest_loot_dirty() -> void:
	_mark_dirty()


# ─── Editor visibility helpers ────────────────────────────────────────

func _hide_all_editors() -> void:
	_hide_mineable_editor()
	_hide_item_editor()
	_hide_encounter_editor()
	_hide_creature_editor()
	_hide_asset_browser()
	_hide_loot_table_editor()
	_hide_crafting_editor()
	_hide_armor_set_editor()
	_hide_biome_editor()
	_hide_shop_editor()
	_hide_quest_editor()
	_hide_dialogue_editor()
	_hide_balance_overview()
	_hide_encounter_table_editor()
	_hide_chest_loot_editor()


func _hide_all_editors_except(kind: StringName) -> void:
	if kind != &"mineable":
		_hide_mineable_editor()
	if kind != &"item_editor":
		_hide_item_editor()
	if kind != &"encounter_editor":
		_hide_encounter_editor()
	if kind != &"creature_editor":
		_hide_creature_editor()
	if kind != &"asset_browser":
		_hide_asset_browser()
	if kind != &"loot_table_editor":
		_hide_loot_table_editor()
	if kind != &"crafting_editor":
		_hide_crafting_editor()
	if kind != &"armor_set_editor":
		_hide_armor_set_editor()
	if kind != &"biome_editor":
		_hide_biome_editor()
	if kind != &"shop_editor":
		_hide_shop_editor()
	if kind != &"quest_editor":
		_hide_quest_editor()
	if kind != &"dialogue_editor":
		_hide_dialogue_editor()
	if kind != &"balance_overview":
		_hide_balance_overview()
	if kind != &"encounter_table_editor":
		_hide_encounter_table_editor()
	if kind != &"chest_loot_editor":
		_hide_chest_loot_editor()


func _on_navigate_to_mineable(resource_id: StringName) -> void:
	# Switch to Mineable Resources mapping and select the target resource.
	for i in _MAPPINGS.size():
		if _MAPPINGS[i]["id"] == &"mineable_resources":
			_select_mapping(_MAPPINGS[i])
			# Select the entry in the tree.
			_select_tree_item_by_id(&"mineable_resources")
			# Select the resource in the mineable editor.
			if _mineable_editor != null:
				_mineable_editor.select_resource(resource_id)
			break


func _on_navigate_to_item(item_id: StringName) -> void:
	# Switch to Items / Drops mapping and select the target item.
	for i in _MAPPINGS.size():
		if _MAPPINGS[i]["id"] == &"item_editor":
			_select_mapping(_MAPPINGS[i])
			_select_tree_item_by_id(&"item_editor")
			if _item_editor != null:
				_item_editor.select_item(item_id)
			break


func _select_tree_item_by_id(mapping_id: StringName) -> void:
	var root: TreeItem = _tree.get_root()
	if root == null:
		return
	var item: TreeItem = root.get_first_child()
	while item != null:
		var child: TreeItem = item.get_first_child()
		while child != null:
			if child.get_metadata(0) is StringName and child.get_metadata(0) == mapping_id:
				child.select(0)
				return
			child = child.get_next()
		item = item.get_next()
