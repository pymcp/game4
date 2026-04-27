## Tests for SheetSpec and SheetSpecReader.
extends GutTest


# ─── SheetSpec defaults ───────────────────────────────────────────────

func test_default_tile_px() -> void:
	var spec := SheetSpec.new()
	assert_eq(spec.tile_px, 16)


func test_default_margin_px() -> void:
	var spec := SheetSpec.new()
	assert_eq(spec.margin_px, 1)


func test_default_stride() -> void:
	var spec := SheetSpec.new()
	assert_eq(spec.stride, 17)


func test_stride_64px_no_margin() -> void:
	var spec := SheetSpec.new()
	spec.tile_px = 64
	spec.margin_px = 0
	assert_eq(spec.stride, 64)


func test_stride_64px_with_margin() -> void:
	var spec := SheetSpec.new()
	spec.tile_px = 64
	spec.margin_px = 1
	assert_eq(spec.stride, 65)


func test_scale_factor_default_is_one() -> void:
	var spec := SheetSpec.new()
	assert_almost_eq(spec.scale_factor(), 1.0, 0.0001)


func test_scale_factor_64px() -> void:
	var spec := SheetSpec.new()
	spec.tile_px = 64
	assert_almost_eq(spec.scale_factor(), 0.25, 0.0001)


func test_scale_factor_32px() -> void:
	var spec := SheetSpec.new()
	spec.tile_px = 32
	assert_almost_eq(spec.scale_factor(), 0.5, 0.0001)


func test_scale_factor_16px_explicit() -> void:
	var spec := SheetSpec.new()
	spec.tile_px = 16
	assert_almost_eq(spec.scale_factor(), 1.0, 0.0001)


# ─── SheetSpecReader._parse_spec ─────────────────────────────────────

func test_parse_valid_64px_no_margin() -> void:
	var spec := SheetSpecReader._parse_spec('{"tile_px": 64, "margin_px": 0}')
	assert_eq(spec.tile_px, 64)
	assert_eq(spec.margin_px, 0)


func test_parse_valid_64px_with_margin() -> void:
	var spec := SheetSpecReader._parse_spec('{"tile_px": 64, "margin_px": 1}')
	assert_eq(spec.tile_px, 64)
	assert_eq(spec.margin_px, 1)


func test_parse_partial_tile_px_only() -> void:
	var spec := SheetSpecReader._parse_spec('{"tile_px": 32}')
	assert_eq(spec.tile_px, 32)
	assert_eq(spec.margin_px, 1, "margin_px should fall back to default 1")


func test_parse_partial_margin_px_only() -> void:
	var spec := SheetSpecReader._parse_spec('{"margin_px": 0}')
	assert_eq(spec.tile_px, 16, "tile_px should fall back to default 16")
	assert_eq(spec.margin_px, 0)


func test_parse_malformed_returns_defaults() -> void:
	var spec := SheetSpecReader._parse_spec("not valid json {{")
	assert_eq(spec.tile_px, 16)
	assert_eq(spec.margin_px, 1)


func test_parse_empty_string_returns_defaults() -> void:
	var spec := SheetSpecReader._parse_spec("")
	assert_eq(spec.tile_px, 16)
	assert_eq(spec.margin_px, 1)


func test_parse_wrong_type_ignored() -> void:
	var spec := SheetSpecReader._parse_spec('{"tile_px": "bad", "margin_px": null}')
	assert_eq(spec.tile_px, 16, "non-numeric tile_px should fall back to default")
	assert_eq(spec.margin_px, 1, "non-numeric margin_px should fall back to default")


func test_parse_scale_factor_from_parsed() -> void:
	var spec := SheetSpecReader._parse_spec('{"tile_px": 64, "margin_px": 1}')
	assert_almost_eq(spec.scale_factor(), 0.25, 0.0001)


# ─── SheetSpecReader.read (file path) ────────────────────────────────

func test_read_missing_path_returns_defaults() -> void:
	var spec := SheetSpecReader.read("res://nonexistent/does_not_exist/sheet.png")
	assert_eq(spec.tile_px, 16)
	assert_eq(spec.margin_px, 1)


func test_read_empty_path_returns_defaults() -> void:
	var spec := SheetSpecReader.read("")
	assert_eq(spec.tile_px, 16)
	assert_eq(spec.margin_px, 1)
