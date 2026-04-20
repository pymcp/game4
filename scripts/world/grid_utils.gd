## GridUtils
##
## Top-down cell ↔ world conversion helpers. Replaces `IsoUtils` from the
## old isometric build. All math is grid-aligned: cell (x,y) maps to world
## ((x+0.5)*TILE_PX, (y+0.5)*TILE_PX) so positions are tile-centered.
##
## Pure helpers — no Node state — kept as a `RefCounted` static API to dodge
## the Godot 4.3 quirk around static methods on `Node`-derived `class_name`
## scripts.
class_name GridUtils
extends RefCounted


static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x + 0.5) * WorldConst.TILE_PX,
		(cell.y + 0.5) * WorldConst.TILE_PX,
	)


static func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / WorldConst.TILE_PX)),
		int(floor(world_pos.y / WorldConst.TILE_PX)),
	)


## Distance in tiles between two world positions.
static func tile_distance(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b) / float(WorldConst.TILE_PX)


## Cardinal-only direction snap: returns the closest of N/S/E/W as a
## Vector2i. (0,0) for zero-length input.
static func snap_to_cardinal(v: Vector2) -> Vector2i:
	if v.length_squared() < 0.0001:
		return Vector2i.ZERO
	if absf(v.x) > absf(v.y):
		return Vector2i(1 if v.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if v.y > 0.0 else -1)
