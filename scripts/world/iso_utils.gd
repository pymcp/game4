## IsoUtils
##
## Pure helpers for isometric coordinate math. Stateless; safe to call from
## anywhere. Conventions:
##
## * "tile" / "iso" coords  : `Vector2i` grid coords (x, y) where +x is "east"
##   (down-right on screen) and +y is "south" (down-left on screen).
## * "world" coords         : `Vector2` pixel coords used by Godot Node2D.
## * `TILE_SIZE`            : the diamond *base* size in pixels (128 wide,
##   64 tall). The Kenney source PNGs are 132x83; the extra width / height
##   is the tile's pedestal cap. `texture_origin` in the TileSet handles
##   that alignment. Stride was calibrated visually with the tile-layout
##   tool against the "Isometric Tiles Base" pack.
class_name IsoUtils

const TILE_SIZE: Vector2i = Vector2i(128, 64)
const TILE_HALF: Vector2 = Vector2(64.0, 32.0)


## Convert tile (iso) coords to world (pixel) coords for the *center* of the
## diamond at that tile.
static func iso_to_world(tile: Vector2i) -> Vector2:
	return Vector2(
		(tile.x - tile.y) * TILE_HALF.x,
		(tile.x + tile.y) * TILE_HALF.y
	)


## Convert world (pixel) coords to floating tile coords. Caller may round /
## floor to get an integer cell.
static func world_to_iso_f(world: Vector2) -> Vector2:
	var fx: float = (world.x / TILE_HALF.x + world.y / TILE_HALF.y) * 0.5
	var fy: float = (world.y / TILE_HALF.y - world.x / TILE_HALF.x) * 0.5
	return Vector2(fx, fy)


## Convert world coords to integer tile cell (floored).
static func world_to_iso(world: Vector2) -> Vector2i:
	var f: Vector2 = world_to_iso_f(world)
	return Vector2i(int(floor(f.x)), int(floor(f.y)))


## 4-connected neighbours (N, E, S, W in iso terms).
static func neighbors4(tile: Vector2i) -> Array[Vector2i]:
	return [
		tile + Vector2i(0, -1),
		tile + Vector2i(1, 0),
		tile + Vector2i(0, 1),
		tile + Vector2i(-1, 0),
	]


## 8-connected neighbours.
static func neighbors8(tile: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			out.append(tile + Vector2i(dx, dy))
	return out


## Manhattan distance in tile space.
static func tile_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Chebyshev distance (king's move) in tile space.
static func tile_distance_cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))
