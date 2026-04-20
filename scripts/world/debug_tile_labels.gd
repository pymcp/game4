## DebugTileLabels
##
## Debug overlay (toggled by F10) that draws a small text label inside every
## painted tile of the active map showing the layer, terrain name, and atlas
## coordinate of the tile. Useful for cross-referencing what's being painted
## against Kenney's source sheet.
##
## Lives as a child of `WorldRoot` so it inherits the world's 4× scale.
## `queue_redraw()` is called whenever the world repaints; otherwise the
## labels would go stale on region change.
extends Node2D
class_name DebugTileLabels

const _LAYER_TAGS: Array[StringName] = [
	&"G", &"P", &"D", &"O",
]
const _LAYER_COLORS: Array[Color] = [
	Color(1, 1, 1, 0.95),
	Color(0.85, 1.0, 0.85, 0.95),
	Color(1.0, 0.85, 0.65, 0.95),
	Color(1.0, 0.7, 1.0, 0.95),
]

var _world: WorldRoot = null


func _ready() -> void:
	z_index = 4096  # draw on top of everything in the world
	_world = get_parent() as WorldRoot


## Repaint when the world is repainted.
func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _world == null:
		return
	var font: Font = ThemeDB.fallback_font
	# Tile is 16 px in world space; world is scaled 4×. Drawing at font_size
	# 5 yields ~20 px on screen — readable without eclipsing the tile art.
	var font_size: int = 5
	var layers: Array[TileMapLayer] = [
		_world.ground, _world.patch, _world.decoration, _world.overlay,
	]
	for li in layers.size():
		var layer: TileMapLayer = layers[li]
		if layer == null or layer.tile_set == null:
			continue
		var has_terrain: bool = layer.tile_set.get_custom_data_layer_by_name(
			TilesetCatalog.CUSTOM_TERRAIN) >= 0
		var tag: StringName = _LAYER_TAGS[li]
		var color: Color = _LAYER_COLORS[li]
		var y_off: float = -6.0 + float(li) * 4.0
		for cell in layer.get_used_cells():
			var atlas: Vector2i = layer.get_cell_atlas_coords(cell)
			var data: TileData = layer.get_cell_tile_data(cell)
			var terrain: StringName = &""
			if data != null and has_terrain:
				var v: Variant = data.get_custom_data(
					TilesetCatalog.CUSTOM_TERRAIN)
				if v is StringName:
					terrain = v
			var text: String = "%s:%s(%d,%d)" % [
				String(tag), String(terrain), atlas.x, atlas.y]
			var origin := Vector2(
				float(cell.x) * float(WorldConst.TILE_PX) + 0.5,
				float(cell.y) * float(WorldConst.TILE_PX) + 8.0 + y_off)
			# Black halo for legibility against varied tile art.
			for dx in [-0.5, 0.5]:
				for dy in [-0.5, 0.5]:
					draw_string(font, origin + Vector2(dx, dy), text,
						HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
						Color(0, 0, 0, 0.9))
			draw_string(font, origin, text,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
