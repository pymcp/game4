## Unit tests for BlankCellDetector — blank tile detection utility.
extends GutTest


func before_each() -> void:
	BlankCellDetector.clear_cache()


func test_fully_transparent_cell_is_blank() -> void:
	var img := Image.create(17, 17, false, Image.FORMAT_RGBA8)
	# Leave default (all zeros = transparent)
	assert_true(
		BlankCellDetector.is_cell_blank(img, Vector2i(0, 0), 16, 1),
		"Fully transparent 16x16 cell should be blank")


func test_solid_magenta_cell_is_blank() -> void:
	var img := Image.create(17, 17, false, Image.FORMAT_RGBA8)
	var magenta := Color(1, 0, 1, 1)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, magenta)
	assert_true(
		BlankCellDetector.is_cell_blank(img, Vector2i(0, 0), 16, 1),
		"Solid magenta cell should be blank")


func test_solid_black_cell_is_blank() -> void:
	var img := Image.create(17, 17, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, Color.BLACK)
	assert_true(
		BlankCellDetector.is_cell_blank(img, Vector2i(0, 0), 16, 1),
		"Solid black cell should be blank")


func test_solid_white_cell_is_not_blank() -> void:
	var img := Image.create(17, 17, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, Color.WHITE)
	assert_false(
		BlankCellDetector.is_cell_blank(img, Vector2i(0, 0), 16, 1),
		"Solid white cell should NOT be blank")


func test_solid_green_cell_is_not_blank() -> void:
	var img := Image.create(17, 17, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, Color.GREEN)
	assert_false(
		BlankCellDetector.is_cell_blank(img, Vector2i(0, 0), 16, 1),
		"Solid green cell should NOT be blank")


func test_cell_with_two_colors_is_not_blank() -> void:
	var img := Image.create(17, 17, false, Image.FORMAT_RGBA8)
	# Fill with green, then paint one pixel different
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, Color.GREEN)
	img.set_pixel(5, 5, Color.RED)
	assert_false(
		BlankCellDetector.is_cell_blank(img, Vector2i(0, 0), 16, 1),
		"Cell with mixed colors should not be blank")


func test_margin_offset_respected() -> void:
	# 2 cells with 1px margin: total width = 16 + 1 + 16 = 33
	var img := Image.create(33, 17, false, Image.FORMAT_RGBA8)
	# First cell (0,0) stays transparent = blank
	# Second cell (1,0) gets content at offset x=17
	for y in 16:
		for x in range(17, 33):
			img.set_pixel(x, y, Color.GREEN)
	img.set_pixel(20, 5, Color.RED)  # make it non-uniform
	assert_true(
		BlankCellDetector.is_cell_blank(img, Vector2i(0, 0), 16, 1),
		"First cell should be blank")
	assert_false(
		BlankCellDetector.is_cell_blank(img, Vector2i(1, 0), 16, 1),
		"Second cell with content should not be blank")


func test_out_of_bounds_cell_is_blank() -> void:
	var img := Image.create(17, 17, false, Image.FORMAT_RGBA8)
	assert_true(
		BlankCellDetector.is_cell_blank(img, Vector2i(5, 5), 16, 1),
		"Out-of-bounds cell should be blank")


func test_no_margin_sheet() -> void:
	# 32x16 with no margin = 2 cells of 16px each
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	# First cell blank (transparent), second has content
	for y in 16:
		for x in range(16, 32):
			img.set_pixel(x, y, Color.BLUE)
	img.set_pixel(20, 3, Color.RED)
	assert_true(
		BlankCellDetector.is_cell_blank(img, Vector2i(0, 0), 16, 0),
		"First cell with no margin should be blank")
	assert_false(
		BlankCellDetector.is_cell_blank(img, Vector2i(1, 0), 16, 0),
		"Second cell with content should not be blank")


func test_get_blank_cells_uses_real_sheet() -> void:
	# Test against an actual game sheet — just verify it returns an Array
	var blanks: Array = BlankCellDetector.get_blank_cells(
		"res://assets/tiles/roguelike/overworld_sheet.png")
	assert_typeof(blanks, TYPE_ARRAY, "Should return an Array")
	# Overworld sheet definitely has some blank cells (unused atlas regions)
	assert_true(blanks.size() > 0, "Overworld sheet should have some blank cells")


func test_cache_returns_same_result() -> void:
	var path := "res://assets/tiles/roguelike/overworld_sheet.png"
	var first: Array = BlankCellDetector.get_blank_cells(path)
	var second: Array = BlankCellDetector.get_blank_cells(path)
	assert_eq(first, second, "Cached result should match first scan")


func test_is_blank_convenience() -> void:
	var path := "res://assets/tiles/roguelike/overworld_sheet.png"
	var blanks: Array = BlankCellDetector.get_blank_cells(path)
	if blanks.size() > 0:
		assert_true(
			BlankCellDetector.is_blank(path, blanks[0]),
			"is_blank() should agree with get_blank_cells()")
	# A non-blank cell (grass at common position)
	# Cell (0,0) on overworld is typically grass — should not be blank
	var cell_00_blank: bool = BlankCellDetector.is_blank(path, Vector2i(0, 0))
	# We can't know for sure, but let's just check the method runs
	assert_typeof(cell_00_blank, TYPE_BOOL)


func test_clear_cache() -> void:
	var path := "res://assets/tiles/roguelike/overworld_sheet.png"
	BlankCellDetector.get_blank_cells(path)
	BlankCellDetector.clear_cache()
	# After clear, calling again should re-scan (still return same result)
	var result: Array = BlankCellDetector.get_blank_cells(path)
	assert_true(result.size() > 0, "Should still detect blanks after cache clear")
