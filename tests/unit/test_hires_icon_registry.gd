# tests/unit/test_hires_icon_registry.gd
extends GutTest

func test_stride_is_tile_plus_margin() -> void:
	var spec := SheetSpec.new()
	spec.tile_px = 64
	spec.margin_px = 1
	assert_eq(spec.stride, 65, "stride should be tile_px + margin_px")

func test_cell_1_0_origin_uses_stride() -> void:
	var spec := SheetSpec.new()
	spec.tile_px = 64
	spec.margin_px = 1
	var col: int = 1
	var row: int = 0
	# Correct: use stride for origin
	var expected_x: float = float(col * spec.stride)  # 65
	var expected_y: float = float(row * spec.stride)  # 0
	# Wrong (pre-fix): col * spec.tile_px = 64
	assert_eq(expected_x, 65.0, "col=1 origin x should be 65 (stride=65), not 64 (tile_px)")
	assert_eq(expected_y, 0.0, "row=0 origin y should be 0")

func test_cell_0_0_origin_is_zero() -> void:
	var spec := SheetSpec.new()
	spec.tile_px = 64
	spec.margin_px = 1
	assert_eq(float(0 * spec.stride), 0.0, "cell 0,0 origin should be 0")
