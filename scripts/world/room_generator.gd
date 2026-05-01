## RoomGenerator
##
## Standalone room-layout algorithm used by [HouseGenerator] and
## injected into dungeons/labyrinths via [carve_into]. Produces
## [InteriorMap] layouts using only terrain codes — no rendering logic.
##
## Size dispatch:
##   min(w,h) < 10 → single rectangular room  (_make_single_rect)
##   otherwise      → multi-room layout        (_make_multi_room)
##
## All methods are static and fully deterministic given the same rng state.
class_name RoomGenerator
extends RefCounted

## Min dimension before switching from single to multi-room layout.
const MULTI_ROOM_THRESHOLD: int = 10
## Minimum side-room width/height.
const SIDE_ROOM_MIN: int = 4
## Maximum number of side rooms for multi-room layouts.
const MAX_SIDE_ROOMS: int = 2


## Generate a complete [InteriorMap] of size `w × h`.
## The caller is responsible for setting map_id, origin_*, floor_num, style, etc.
## Minimum supported size is 4×4 (smaller is no-op / degenerate).
static func generate(rng: RandomNumberGenerator, w: int, h: int) -> InteriorMap:
	w = maxi(w, 4)
	h = maxi(h, 4)
	if mini(w, h) < MULTI_ROOM_THRESHOLD:
		return _make_single_rect(rng, w, h)
	return _make_multi_room(rng, w, h)


## Carve a room-style chamber into an existing [InteriorMap] at `rect`.
## Walls around the rect perimeter become INTERIOR_WALL, interior cells
## become INTERIOR_FLOOR. The rect is appended to `target.chamber_rects`.
## A door is punched on the south wall of the rect to connect to the dungeon.
static func carve_into(rng: RandomNumberGenerator,
		target: InteriorMap, rect: Rect2i) -> void:
	# Clamp rect to the map bounds.
	var r := Rect2i(
		maxi(rect.position.x, 0),
		maxi(rect.position.y, 0),
		0, 0)
	r.end = Vector2i(
		mini(rect.end.x, target.width),
		mini(rect.end.y, target.height))
	if r.size.x < 4 or r.size.y < 4:
		return  # Too small to be useful.
	# Flood the rect with walls first so we own every cell.
	# Skip cells already carved as floor (corridor tiles) so connectivity
	# is preserved — corridor cells act as natural chamber entrances.
	# Also skip stair cells so dungeon entry/exit points are not erased.
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var cell := Vector2i(x, y)
			var existing: int = target.at(cell)
			if existing == TerrainCodes.INTERIOR_FLOOR \
					or existing == TerrainCodes.INTERIOR_STAIRS_UP \
					or existing == TerrainCodes.INTERIOR_STAIRS_DOWN:
				continue
			target.set_at(cell, TerrainCodes.INTERIOR_WALL)
	# Carve interior floor (inside the 1-tile-thick wall border).
	# Preserve stair cells so dungeon entry/exit are not overwritten.
	for y in range(r.position.y + 1, r.end.y - 1):
		for x in range(r.position.x + 1, r.end.x - 1):
			var cell := Vector2i(x, y)
			var existing: int = target.at(cell)
			if existing != TerrainCodes.INTERIOR_STAIRS_UP \
					and existing != TerrainCodes.INTERIOR_STAIRS_DOWN:
				target.set_at(cell, TerrainCodes.INTERIOR_FLOOR)
	# Punch an interior door in the south wall (center) so the chamber
	# connects to dungeon corridors on the south side.
	var door_x: int = r.position.x + r.size.x / 2
	var door_y: int = r.end.y - 1
	target.set_at(Vector2i(door_x, door_y), TerrainCodes.INTERIOR_DOOR)
	target.chamber_rects.append(r)


# ── Private helpers ────────────────────────────────────────────────

## Single rectangular room: 1-tile-thick outer wall, filled floor, south door.
static func _make_single_rect(rng: RandomNumberGenerator, w: int, h: int) -> InteriorMap:
	var m := InteriorMap.new()
	m.width = w
	m.height = h
	m.tiles = PackedByteArray()
	m.tiles.resize(w * h)
	for y in h:
		for x in w:
			var on_edge: bool = (x == 0 or y == 0 or x == w - 1 or y == h - 1)
			m.set_at(Vector2i(x, y),
				TerrainCodes.INTERIOR_WALL if on_edge else TerrainCodes.INTERIOR_FLOOR)
	var door := Vector2i(w / 2, h - 1)
	m.set_at(door, TerrainCodes.INTERIOR_DOOR)
	m.entry_cell = Vector2i(door.x, door.y - 1)
	m.exit_cell = door
	return m


## Multi-room layout: one main room plus 1-2 side rooms connected by
## INTERIOR_DOOR cells punched through shared walls.
static func _make_multi_room(rng: RandomNumberGenerator, w: int, h: int) -> InteriorMap:
	var m := InteriorMap.new()
	m.width = w
	m.height = h
	m.tiles = PackedByteArray()
	m.tiles.resize(w * h)
	# Start all walls.
	for i in w * h:
		m.tiles[i] = TerrainCodes.INTERIOR_WALL

	# Main room: random rect with a 1-tile border from the map edges.
	var main_min_w: int = maxi(w / 2, SIDE_ROOM_MIN + 2)
	var main_min_h: int = maxi(h / 2, SIDE_ROOM_MIN + 2)
	var main_w: int = rng.randi_range(main_min_w, w - 2)
	var main_h: int = rng.randi_range(main_min_h, h - 2)
	var main_x: int = 1 + rng.randi_range(0, maxi(0, w - 2 - main_w))
	var main_y: int = 1 + rng.randi_range(0, maxi(0, h - 2 - main_h))
	var main_rect := Rect2i(main_x, main_y, main_w, main_h)
	_fill_rect(m, main_rect, TerrainCodes.INTERIOR_FLOOR)

	# Side rooms: attempt up to MAX_SIDE_ROOMS on random walls of the main room.
	var placed_rooms: Array[Rect2i] = [main_rect]
	var side_count: int = rng.randi_range(1, MAX_SIDE_ROOMS)
	for _i in side_count:
		_try_add_side_room(rng, m, w, h, main_rect, placed_rooms)

	# Entry door on the south wall of the main room.
	var door := Vector2i(main_rect.position.x + main_rect.size.x / 2,
			main_rect.position.y + main_rect.size.y - 1)
	# If the south wall is the map's south edge, use the one row above.
	if door.y >= h - 1:
		door.y = h - 1
	m.set_at(door, TerrainCodes.INTERIOR_DOOR)
	m.entry_cell = Vector2i(door.x, door.y - 1)
	m.exit_cell = door
	return m


## Try to attach a side room to one of the four walls of `main_rect`.
## Fails silently if no valid placement exists.
static func _try_add_side_room(rng: RandomNumberGenerator, m: InteriorMap,
		map_w: int, map_h: int, main_rect: Rect2i, placed: Array[Rect2i]) -> void:
	# Side room dimensions.
	var sw: int = rng.randi_range(SIDE_ROOM_MIN, maxi(SIDE_ROOM_MIN, main_rect.size.x - 2))
	var sh: int = rng.randi_range(SIDE_ROOM_MIN, maxi(SIDE_ROOM_MIN, main_rect.size.y - 2))
	# Try all 4 walls in random order.
	var sides: Array = [0, 1, 2, 3]
	for i in range(sides.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = sides[i]; sides[i] = sides[j]; sides[j] = tmp
	for side in sides:
		var candidate: Rect2i = _side_room_rect(rng, main_rect, side, sw, sh, map_w, map_h)
		if candidate.size.x < SIDE_ROOM_MIN or candidate.size.y < SIDE_ROOM_MIN:
			continue
		# Reject if overlapping any already-placed room.
		var overlap: bool = false
		for pr in placed:
			if candidate.intersects(pr.grow(1)):
				overlap = true
				break
		if overlap:
			continue
		_fill_rect(m, candidate, TerrainCodes.INTERIOR_FLOOR)
		placed.append(candidate)
		# Punch a door on the shared wall between main room and side room.
		_punch_connecting_door(m, main_rect, candidate, side)
		return


## Return a candidate side-room rect placed on `side` (0=N, 1=E, 2=S, 3=W).
static func _side_room_rect(rng: RandomNumberGenerator, main: Rect2i,
		side: int, sw: int, sh: int, map_w: int, map_h: int) -> Rect2i:
	match side:
		0:  # North
			var rx: int = main.position.x + rng.randi_range(0, maxi(0, main.size.x - sw))
			var ry: int = main.position.y - sh  # placed above main room
			return Rect2i(clampi(rx, 1, map_w - sw - 1),
				clampi(ry, 1, map_h - sh - 1), sw, sh)
		1:  # East
			var rx: int = main.position.x + main.size.x
			var ry: int = main.position.y + rng.randi_range(0, maxi(0, main.size.y - sh))
			return Rect2i(clampi(rx, 1, map_w - sw - 1),
				clampi(ry, 1, map_h - sh - 1), sw, sh)
		2:  # South
			var rx: int = main.position.x + rng.randi_range(0, maxi(0, main.size.x - sw))
			var ry: int = main.position.y + main.size.y
			return Rect2i(clampi(rx, 1, map_w - sw - 1),
				clampi(ry, 1, map_h - sh - 1), sw, sh)
		_:  # West
			var rx: int = main.position.x - sw
			var ry: int = main.position.y + rng.randi_range(0, maxi(0, main.size.y - sh))
			return Rect2i(clampi(rx, 1, map_w - sw - 1),
				clampi(ry, 1, map_h - sh - 1), sw, sh)
	return Rect2i()


## Punch a door on the wall between `main` and `side_room`.
## `side` indicates which wall of main the side room is attached to.
static func _punch_connecting_door(m: InteriorMap, main: Rect2i,
		side_room: Rect2i, side: int) -> void:
	match side:
		0:  # Side room to the north — door on main's top wall.
			var cx: int = (maxi(main.position.x, side_room.position.x)
					+ mini(main.end.x, side_room.end.x)) / 2
			m.set_at(Vector2i(cx, main.position.y), TerrainCodes.INTERIOR_DOOR)
		1:  # East — door on main's right wall.
			var cy: int = (maxi(main.position.y, side_room.position.y)
					+ mini(main.end.y, side_room.end.y)) / 2
			m.set_at(Vector2i(main.end.x - 1, cy), TerrainCodes.INTERIOR_DOOR)
		2:  # South — door on main's bottom wall.
			var cx: int = (maxi(main.position.x, side_room.position.x)
					+ mini(main.end.x, side_room.end.x)) / 2
			m.set_at(Vector2i(cx, main.end.y - 1), TerrainCodes.INTERIOR_DOOR)
		3:  # West — door on main's left wall.
			var cy: int = (maxi(main.position.y, side_room.position.y)
					+ mini(main.end.y, side_room.end.y)) / 2
			m.set_at(Vector2i(main.position.x, cy), TerrainCodes.INTERIOR_DOOR)


## Fill all cells in `rect` with `code`.
static func _fill_rect(m: InteriorMap, rect: Rect2i, code: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			m.set_at(Vector2i(x, y), code)
