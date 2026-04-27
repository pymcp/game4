## SheetSpec
##
## Describes the tile layout of a single spritesheet. Read from a
## `_spec.json` sidecar file in the same directory as the sheet PNG via
## `SheetSpecReader.read()`. When no sidecar exists the defaults match the
## historical Kenney sheet format (16×16 tiles, 1 px gutter).
##
## `scale_factor()` returns the multiplier that a TileMapLayer using this
## sheet must apply so its tiles occupy the same world footprint as a
## standard 16×16 tile (WorldConst.TILE_PX).
##
## Example — 64×64 sheet:
##   spec.tile_px     = 64
##   spec.margin_px   = 1
##   spec.stride      = 65
##   spec.scale_factor() = 16 / 64 = 0.25
##   TileMapLayer.scale = Vector2(0.25, 0.25)
##   → 64 × 0.25 × World.scale(4) = 64 screen px  ✓
class_name SheetSpec
extends RefCounted

## Width/height of each tile cell in the source PNG, in pixels.
var tile_px: int = 16

## Gap between adjacent cells in the source PNG, in pixels.
## Classic Kenney sheets use 1 px; tightly-packed sheets use 0.
var margin_px: int = 1

## Distance in pixels between the top-left corners of adjacent cells.
## Computed from tile_px + margin_px.
var stride: int:
	get:
		return tile_px + margin_px


## Returns the scale factor to apply to a TileMapLayer that uses this
## sheet so each tile occupies the same world space as a 16×16 tile.
## Result is 1.0 for the default 16×16 sheet (no-op).
func scale_factor() -> float:
	if tile_px <= 0:
		return 1.0
	return float(WorldConst.TILE_PX) / float(tile_px)
