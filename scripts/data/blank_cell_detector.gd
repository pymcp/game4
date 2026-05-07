## BlankCellDetector
##
## Pure static utility that identifies blank (empty/misconfigured) cells in
## tilesheet PNGs. A cell is "blank" if it is:
##   a) Fully transparent (no visible pixels), OR
##   b) Solid magenta (#FF00FF) — pipeline background color, OR
##   c) Solid black (#000000)
##
## Results are cached per sheet path to avoid repeated Image scanning.
class_name BlankCellDetector
extends RefCounted

## Cache: sheet_path → Array[Vector2i] of blank cells.
static var _cache: Dictionary = {}

## Colors that count as "blank" when a cell is filled solid with them.
const _BLANK_COLORS: Array[Color] = [
	Color(1, 0, 1, 1),   # magenta (#FF00FF)
	Color(0, 0, 0, 1),   # black
]


## Returns true if the given cell in the image is blank.
static func is_cell_blank(image: Image, cell: Vector2i, tile_px: int, margin: int) -> bool:
	var x: int = cell.x * (tile_px + margin)
	var y: int = cell.y * (tile_px + margin)
	if x + tile_px > image.get_width() or y + tile_px > image.get_height():
		return true  # Out-of-bounds = blank
	var region: Image = image.get_region(Rect2i(x, y, tile_px, tile_px))
	# Check fully transparent
	if region.get_used_rect() == Rect2i():
		return true
	# Check if every pixel matches a known blank color
	var first_pixel: Color = region.get_pixel(0, 0)
	if not _is_blank_color(first_pixel):
		return false
	for py in tile_px:
		for px in tile_px:
			if region.get_pixel(px, py) != first_pixel:
				return false
	return true


static func _is_blank_color(c: Color) -> bool:
	for bc in _BLANK_COLORS:
		if is_equal_approx(c.r, bc.r) and is_equal_approx(c.g, bc.g) and is_equal_approx(c.b, bc.b):
			return true
	return false


## Returns all blank cells in the given sheet. Cached per path.
static func get_blank_cells(sheet_path: String) -> Array:
	if _cache.has(sheet_path):
		return _cache[sheet_path]
	var result: Array = []
	var tex: Texture2D = load(sheet_path) as Texture2D
	if tex == null:
		_cache[sheet_path] = result
		return result
	var image: Image = tex.get_image()
	if image == null:
		_cache[sheet_path] = result
		return result
	var tile_px: int = 16
	var margin: int = 1
	# Auto-detect margin (same logic as SheetView)
	var w: int = image.get_width()
	var step: int = tile_px + 1
	var fits_gutter: bool = ((w + 1) % step == 0) or (w % step == 0)
	var fits_no_gutter: bool = (w % tile_px) == 0
	if not fits_gutter and fits_no_gutter:
		margin = 0
	var cols: int = (w + margin) / (tile_px + margin)
	var rows: int = (image.get_height() + margin) / (tile_px + margin)
	for row in rows:
		for col in cols:
			var cell := Vector2i(col, row)
			if is_cell_blank(image, cell, tile_px, margin):
				result.append(cell)
	_cache[sheet_path] = result
	return result


## Returns true if a specific cell is blank on the given sheet. Uses cache.
static func is_blank(sheet_path: String, cell: Vector2i) -> bool:
	var blanks: Array = get_blank_cells(sheet_path)
	return blanks.has(cell)


## Clear cache (call after sheet edits).
static func clear_cache() -> void:
	_cache.clear()
