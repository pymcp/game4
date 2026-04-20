## TileSetBuilder
##
## Builds Godot `TileSet` resources at runtime from a list of source PNG paths.
## Lets us avoid hand-editing brittle 5MB `.tres` tileset files. Each call
## creates one `TileSetAtlasSource` per (terrain_type) entry and registers a
## single tile per source. Tile metadata (terrain_type, is_walkable, etc.) is
## stored in custom data layers.
##
## A registered tile is identified by `(source_id, Vector2i.ZERO, 0)` — the
## triplet you pass to `TileMapLayer.set_cell(coords, source_id, atlas_coords,
## alternative_id)`. We expose convenience helpers for that.
##
## Usage:
##     var b := TileSetBuilder.new()
##     b.add_terrain("grass", "res://assets/tiles/overworld/landscapeTiles_000.png", true)
##     b.add_terrain("water", "res://assets/tiles/overworld/landscapeTiles_037.png", false, true)
##     var ts := b.build()
##     # Pick a specific terrain at random:
##     var src_id := b.get_random_source_for("grass", rng)
class_name TileSetBuilder
extends RefCounted

const TILE_SIZE: Vector2i = Vector2i(128, 64)

## Names of the custom data layers, in the order they're added.
const CUSTOM_LAYERS := [
	&"terrain_type",  # StringName
	&"is_walkable",   # bool
	&"is_water",      # bool
	&"move_cost",     # float
]


class TerrainEntry:
	var terrain_type: StringName
	var texture_path: String
	var is_walkable: bool
	var is_water: bool
	var move_cost: float
	## Optional Kenney landscapeTiles index. -1 = unknown / not catalogued.
	var tile_index: int

	func _init(t: StringName, path: String, walkable: bool, water: bool, cost: float, idx: int = -1) -> void:
		terrain_type = t
		texture_path = path
		is_walkable = walkable
		is_water = water
		move_cost = cost
		tile_index = idx


var _entries: Array[TerrainEntry] = []
## terrain_type -> Array[int] of source ids
var _by_terrain: Dictionary = {}
## tile_index (Kenney landscapeTiles_NNN) -> source_id. Populated by `build()`
## for entries that supplied a `tile_index`. Lets the height-aware renderer
## map a chosen tile back to a TileMapLayer source.
var _by_index: Dictionary = {}


## Register a tile. `texture_path` must be a `res://` path to a PNG of the
## expected `132x83` (flat) Kenney iso size — other sizes will be accepted but
## may not align perfectly.
##
## Multiple calls with the same `terrain_type` register variants; pick one at
## render time via `get_random_source_for`.
func add_terrain(
	terrain_type: StringName,
	texture_path: String,
	is_walkable: bool = true,
	is_water: bool = false,
	move_cost: float = 1.0,
	tile_index: int = -1
) -> void:
	_entries.append(TerrainEntry.new(terrain_type, texture_path, is_walkable, is_water, move_cost, tile_index))


## Build the `TileSet`. Each registered terrain entry becomes one
## `TileSetAtlasSource` with one tile.
func build() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_VERTICAL
	ts.tile_size = TILE_SIZE

	# Custom data layers in fixed order so consumers can refer by index too.
	for i in CUSTOM_LAYERS.size():
		ts.add_custom_data_layer(i)
		ts.set_custom_data_layer_name(i, CUSTOM_LAYERS[i])
	ts.set_custom_data_layer_type(0, TYPE_STRING_NAME)
	ts.set_custom_data_layer_type(1, TYPE_BOOL)
	ts.set_custom_data_layer_type(2, TYPE_BOOL)
	ts.set_custom_data_layer_type(3, TYPE_FLOAT)

	for entry in _entries:
		var tex := load(entry.texture_path) as Texture2D
		if tex == null:
			push_warning("[TileSetBuilder] missing texture: %s" % entry.texture_path)
			continue
		var src := TileSetAtlasSource.new()
		src.texture = tex
		# Use the FULL texture as the tile region (single-tile atlas).
		src.texture_region_size = Vector2i(tex.get_width(), tex.get_height())
		# Source must be added to the TileSet *before* creating tiles so that
		# tile data inherits the parent's custom data layer schema.
		var src_id: int = ts.add_source(src)
		src.create_tile(Vector2i.ZERO)

		var data: TileData = src.get_tile_data(Vector2i.ZERO, 0)
		# Origin: align the diamond floor to cell. Source PNGs are 132 x H. The
		# diamond occupies the bottom 66px; the PNG center sits ((H-66)/2) above
		# cell center, so we shift down by ((H-66)/2) to align the floor.
		var h: int = tex.get_height()
		var origin_y: int = (h - TILE_SIZE.y) / 2
		# Flip sign because positive Y origin raises the texture in Godot 4.
		data.texture_origin = Vector2i(0, origin_y)
		data.set_custom_data(CUSTOM_LAYERS[0], entry.terrain_type)
		data.set_custom_data(CUSTOM_LAYERS[1], entry.is_walkable)
		data.set_custom_data(CUSTOM_LAYERS[2], entry.is_water)
		data.set_custom_data(CUSTOM_LAYERS[3], entry.move_cost)

		if not _by_terrain.has(entry.terrain_type):
			_by_terrain[entry.terrain_type] = [] as Array[int]
		(_by_terrain[entry.terrain_type] as Array[int]).append(src_id)
		if entry.tile_index >= 0 and not _by_index.has(entry.tile_index):
			_by_index[entry.tile_index] = src_id

	return ts


## Look up the TileMapLayer source id for a Kenney landscapeTiles index, or
## -1 if that index was never registered.
func get_source_for_index(idx: int) -> int:
	return int(_by_index.get(idx, -1))


func get_source_ids_for(terrain_type: StringName) -> Array[int]:
	if _by_terrain.has(terrain_type):
		return _by_terrain[terrain_type]
	return [] as Array[int]


func get_random_source_for(terrain_type: StringName, rng: RandomNumberGenerator) -> int:
	var ids := get_source_ids_for(terrain_type)
	if ids.is_empty():
		return -1
	return ids[rng.randi() % ids.size()]


func known_terrains() -> Array[StringName]:
	var keys: Array[StringName] = []
	for k in _by_terrain.keys():
		keys.append(k)
	return keys
