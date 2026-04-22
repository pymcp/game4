## DungeonGenerator
##
## Deterministic BSP room-and-corridor generator. Recursively splits the map
## rectangle until each leaf is small enough, carves a randomly-sized room
## inside each leaf, then connects sibling leaf-rooms with L-shaped
## corridors. Walls are filled around everything.
##
## Output is an [InteriorMap] with `INTERIOR_FLOOR` / `INTERIOR_WALL` /
## `INTERIOR_STAIRS_UP` cells. The first room placed becomes the entry
## room; the room furthest from it becomes the exit room.
##
## All randomness is seeded from `seed` so the same input always produces
## the same dungeon.
class_name DungeonGenerator
extends RefCounted

const MIN_LEAF: int = 8
const MAX_LEAF: int = 18
const MIN_ROOM: int = 4


## Generate an [InteriorMap]. `width`/`height` are clamped to
## [InteriorMap.MIN_SIZE..MAX_SIZE].
static func generate(seed_val: int, width: int = 32, height: int = 32) -> InteriorMap:
	width = clampi(width, InteriorMap.MIN_SIZE, InteriorMap.MAX_SIZE)
	height = clampi(height, InteriorMap.MIN_SIZE, InteriorMap.MAX_SIZE)

	var m := InteriorMap.new()
	m.seed = seed_val
	m.width = width
	m.height = height
	m.tiles = PackedByteArray()
	m.tiles.resize(width * height)
	# Fill with walls; rooms / corridors will carve floor.
	for i in width * height:
		m.tiles[i] = TerrainCodes.INTERIOR_WALL

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Build BSP leaves.
	var leaves: Array = []
	_split(rng, Rect2i(0, 0, width, height), leaves)

	# Carve a room in each leaf.
	var rooms: Array = []  # Array[Rect2i]
	for leaf_rect in leaves:
		var room: Rect2i = _carve_room(rng, leaf_rect)
		_fill_floor(m, room)
		rooms.append(room)

	# Connect rooms in scan order with L corridors (gives a fully-
	# connected layout because every pair has a path through the chain).
	for i in range(rooms.size() - 1):
		_carve_corridor(rng, m, _center(rooms[i]), _center(rooms[i + 1]))

	# Pick entry (first room center) and exit (room furthest from entry).
	var entry: Vector2i = _center(rooms[0])
	var exit_room_idx: int = 0
	var best: int = -1
	for i in rooms.size():
		var c: Vector2i = _center(rooms[i])
		var d: int = abs(c.x - entry.x) + abs(c.y - entry.y)
		if d > best:
			best = d
			exit_room_idx = i
	var exit_cell: Vector2i = _center(rooms[exit_room_idx])

	m.set_at(entry, TerrainCodes.INTERIOR_STAIRS_UP)
	m.set_at(exit_cell, TerrainCodes.INTERIOR_STAIRS_DOWN)
	m.entry_cell = entry
	m.exit_cell = exit_cell

	# Light NPC scatter — slimes default; per-floor tuning is Phase 8b/9.
	_scatter_npcs(rng, m, rooms)
	# Phase 10a: scatter loot in the same rooms (post-entry).
	_scatter_loot(rng, m, rooms)
	return m


# ─── BSP ──────────────────────────────────────────────────────────────

static func _split(rng: RandomNumberGenerator, rect: Rect2i, out: Array) -> void:
	if rect.size.x <= MAX_LEAF and rect.size.y <= MAX_LEAF:
		out.append(rect)
		return
	# Pick split axis: prefer the longer one.
	var split_horiz: bool
	if rect.size.x > rect.size.y * 1.25:
		split_horiz = false  # vertical cut on x
	elif rect.size.y > rect.size.x * 1.25:
		split_horiz = true   # horizontal cut on y
	else:
		split_horiz = rng.randf() < 0.5

	if split_horiz:
		# Cut along y.
		if rect.size.y < MIN_LEAF * 2:
			out.append(rect)
			return
		var cut: int = rng.randi_range(MIN_LEAF, rect.size.y - MIN_LEAF)
		var top := Rect2i(rect.position, Vector2i(rect.size.x, cut))
		var bot := Rect2i(rect.position + Vector2i(0, cut),
			Vector2i(rect.size.x, rect.size.y - cut))
		_split(rng, top, out)
		_split(rng, bot, out)
	else:
		if rect.size.x < MIN_LEAF * 2:
			out.append(rect)
			return
		var cut: int = rng.randi_range(MIN_LEAF, rect.size.x - MIN_LEAF)
		var lhs := Rect2i(rect.position, Vector2i(cut, rect.size.y))
		var rhs := Rect2i(rect.position + Vector2i(cut, 0),
			Vector2i(rect.size.x - cut, rect.size.y))
		_split(rng, lhs, out)
		_split(rng, rhs, out)


# ─── Room / corridor carving ──────────────────────────────────────────

static func _carve_room(rng: RandomNumberGenerator, leaf: Rect2i) -> Rect2i:
	# Reserve a 1-tile margin so adjacent rooms don't merge.
	var max_w: int = max(MIN_ROOM, leaf.size.x - 2)
	var max_h: int = max(MIN_ROOM, leaf.size.y - 2)
	var w: int = rng.randi_range(MIN_ROOM, max_w)
	var h: int = rng.randi_range(MIN_ROOM, max_h)
	var x: int = leaf.position.x + 1 + rng.randi_range(0, max(0, leaf.size.x - 2 - w))
	var y: int = leaf.position.y + 1 + rng.randi_range(0, max(0, leaf.size.y - 2 - h))
	return Rect2i(x, y, w, h)


static func _fill_floor(m: InteriorMap, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			m.set_at(Vector2i(x, y), TerrainCodes.INTERIOR_FLOOR)


static func _carve_corridor(rng: RandomNumberGenerator, m: InteriorMap,
		from: Vector2i, to: Vector2i) -> void:
	# L-shape: either go x then y, or y then x.
	if rng.randf() < 0.5:
		_carve_h(m, from.y, from.x, to.x)
		_carve_v(m, to.x, from.y, to.y)
	else:
		_carve_v(m, from.x, from.y, to.y)
		_carve_h(m, to.y, from.x, to.x)


static func _carve_h(m: InteriorMap, y: int, x0: int, x1: int) -> void:
	var lo: int = min(x0, x1)
	var hi: int = max(x0, x1)
	for x in range(lo, hi + 1):
		m.set_at(Vector2i(x, y), TerrainCodes.INTERIOR_FLOOR)


static func _carve_v(m: InteriorMap, x: int, y0: int, y1: int) -> void:
	var lo: int = min(y0, y1)
	var hi: int = max(y0, y1)
	for y in range(lo, hi + 1):
		m.set_at(Vector2i(x, y), TerrainCodes.INTERIOR_FLOOR)


static func _center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


# ─── Misc placement ───────────────────────────────────────────────────

static func _scatter_npcs(rng: RandomNumberGenerator, m: InteriorMap,
		rooms: Array) -> void:
	# Skip the first room (entry) to keep the player safe on arrival.
	for i in range(1, rooms.size()):
		var room: Rect2i = rooms[i]
		# 30% chance per room to spawn a slime in the room's center.
		if rng.randf() < 0.3:
			var c: Vector2i = _center(room)
			# Avoid stairs cells.
			if m.at(c) == TerrainCodes.INTERIOR_FLOOR:
				m.npcs_scatter.append({
					"kind": &"slime",
					"cell": c,
					"variant": rng.randi(),
				})


## Phase 10a: scatter loot piles in rooms (skipping the entry room) so a
## diving session has tangible reward. Each pile holds one stack of an item
## drawn from a data-driven loot table loaded from resources/dungeon_loot.json.
const _DUNGEON_LOOT_PATH: String = "res://resources/dungeon_loot.json"
static var _loot_table: Array = []


static func _get_loot_table() -> Array:
	if not _loot_table.is_empty():
		return _loot_table
	if not FileAccess.file_exists(_DUNGEON_LOOT_PATH):
		push_warning("[DungeonGenerator] %s not found" % _DUNGEON_LOOT_PATH)
		return _loot_table
	var f := FileAccess.open(_DUNGEON_LOOT_PATH, FileAccess.READ)
	if f == null:
		return _loot_table
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Array:
		for entry in json.data:
			_loot_table.append({
				"id": StringName(entry.get("id", "")),
				"weight": int(entry.get("weight", 1)),
				"min": int(entry.get("min", 1)),
				"max": int(entry.get("max", 1)),
			})
	return _loot_table


static func _scatter_loot(rng: RandomNumberGenerator, m: InteriorMap,
		rooms: Array) -> void:
	for i in range(1, rooms.size()):
		var room: Rect2i = rooms[i]
		# 60% chance per non-entry room to drop a single pile somewhere.
		if rng.randf() >= 0.6:
			continue
		# Pick a random floor cell within the room.
		var attempts: int = 6
		var cell := Vector2i.ZERO
		var ok: bool = false
		while attempts > 0:
			attempts -= 1
			var c := Vector2i(
				rng.randi_range(room.position.x, room.position.x + room.size.x - 1),
				rng.randi_range(room.position.y, room.position.y + room.size.y - 1))
			if m.at(c) == TerrainCodes.INTERIOR_FLOOR \
					and not _cell_taken_by_npc(m, c):
				cell = c
				ok = true
				break
		if not ok:
			continue
		var pick: Dictionary = _weighted_pick(rng, _get_loot_table())
		var count: int = rng.randi_range(int(pick["min"]), int(pick["max"]))
		m.loot_scatter.append({
			"item_id": pick["id"],
			"count": count,
			"cell": cell,
		})


static func _cell_taken_by_npc(m: InteriorMap, cell: Vector2i) -> bool:
	for entry in m.npcs_scatter:
		if entry["cell"] == cell:
			return true
	return false


static func _weighted_pick(rng: RandomNumberGenerator, table: Array) -> Dictionary:
	var total: int = 0
	for entry in table:
		total += int(entry["weight"])
	var roll: int = rng.randi_range(1, total)
	var acc: int = 0
	for entry in table:
		acc += int(entry["weight"])
		if roll <= acc:
			return entry
	return table[0]
