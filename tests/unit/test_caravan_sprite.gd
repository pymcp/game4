extends GutTest


func test_scale_factor_for_hires_sheet() -> void:
	var spec := SheetSpec.new()
	spec.tile_px = 64
	spec.margin_px = 1
	var sf: float = spec.scale_factor()
	assert_almost_eq(sf, 0.25, 0.001, "64px hires sheet should scale to 0.25 in 16px game space")


func test_stride_for_hires_sheet() -> void:
	var spec := SheetSpec.new()
	spec.tile_px = 64
	spec.margin_px = 1
	assert_eq(spec.stride, 65, "64px tile + 1px margin = stride 65")


func test_cell_3_1_origin_with_hires_spec() -> void:
	# caravan_wagon is mapped to cell (3, 1) on the hires items sheet
	var spec := SheetSpec.new()
	spec.tile_px = 64
	spec.margin_px = 1
	var cell := Vector2i(3, 1)
	var origin_x: float = float(cell.x * spec.stride)  # 195
	var origin_y: float = float(cell.y * spec.stride)  # 65
	assert_eq(origin_x, 195.0, "cell (3,1) x origin should be 3*65=195")
	assert_eq(origin_y, 65.0, "cell (3,1) y origin should be 1*65=65")
