## LabyrinthGenerator
##
## Generates Gauntlet-style labyrinths using Prim's maze algorithm on a
## coarse junction grid. Corridors are 2-4 tiles wide, producing the dense
## dead-end-rich layout that makes Prim's feel like a true labyrinth.
##
## Output is an [InteriorMap] with INTERIOR_FLOOR / INTERIOR_WALL /
## INTERIOR_STAIRS_UP / INTERIOR_STAIRS_DOWN cells, plus chest_scatter
## at dead-end junctions, and boss_data / boss_room_cells on boss floors.
##
## All randomness is seeded from `seed_val` for determinism.
class_name LabyrinthGenerator
extends RefCounted

const _MIN_CORRIDOR_WIDTH: int = 2
const _MAX_CORRIDOR_WIDTH: int = 4
const _WALL_THICKNESS: int = 1
const _STRIDE: int = _MAX_CORRIDOR_WIDTH + 2 * _WALL_THICKNESS
const _MARGIN: int = 2
const _BOSS_ROOM_HALF: int = 4


static func generate(seed_val: int, width: int, height: int,
		floor_num: int = 1) -> InteriorMap:
	width  = clampi(width,  InteriorMap.MIN_SIZE, InteriorMap.MAX_SIZE)
	height = clampi(height, InteriorMap.MIN_SIZE, InteriorMap.MAX_SIZE)

	var m := InteriorMap.new()
	m.seed = seed_val
	m.width = width
	m.height = height
	m.tiles = PackedByteArray()
	m.tiles.resize(width * height)
	for i in width * height:
		m.tiles[i] = TerrainCodes.INTERIOR_WALL

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var jw: int = max((width  - 2 * _MARGIN) / _STRIDE, 2)
	var jh: int = max((height - 2 * _MARGIN) / _STRIDE, 2)

	var junctions: Array = []
	for jy in jh:
		for jx in jw:
			junctions.append(Vector2i(
				_MARGIN + jx * _STRIDE + _MAX_CORRIDOR_WIDTH / 2,
				_MARGIN + jy * _STRIDE + _MAX_CORRIDOR_WIDTH / 2))

	var dir_delta: Array = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]

	var visited: Array = []
	visited.resize(jw * jh)
	visited.fill(false)
	var connection: Array = []
	connection.resize(jw * jh)
	for i in connection.size():
		connection[i] = []

	var frontier: Array = []

	var start_j: Vector2i = Vector2i(0, rng.randi_range(0, jh - 1))
	var start_idx: int = start_j.y * jw + start_j.x
	visited[start_idx] = true
	_push_frontier(start_idx, jw, jh, visited, dir_delta, frontier)

	while not frontier.is_empty():
		var fi: int = rng.randi_range(0, frontier.size() - 1)
		var edge: Array = frontier[fi]
		frontier.remove_at(fi)
		var from_idx: int = edge[0]
		var to_idx: int = edge[1]
		if visited[to_idx]:
			continue
		visited[to_idx] = true
		connection[from_idx].append(to_idx)
		connection[to_idx].append(from_idx)
		_push_frontier(to_idx, jw, jh, visited, dir_delta, frontier)
		_carve_corridor(rng, m, junctions[from_idx], junctions[to_idx])

	var entry_idx: int = _pick_border_junction(jw, jh, connection, rng)
	var exit_idx: int = _pick_far_junction(entry_idx, jw * jh, connection)
	var entry_cell: Vector2i = junctions[entry_idx]
	var exit_cell: Vector2i = junctions[exit_idx]
	m.set_at(entry_cell, TerrainCodes.INTERIOR_STAIRS_UP)
	m.set_at(exit_cell,  TerrainCodes.INTERIOR_STAIRS_DOWN)
	m.entry_cell = entry_cell
	m.exit_cell  = exit_cell

	for idx in jw * jh:
		if idx == entry_idx or idx == exit_idx:
			continue
		if (connection[idx] as Array).size() == 1:
			m.chest_scatter.append({
				"cell": junctions[idx],
				"floor_num": floor_num,
			})

	var boss_interval: int = EncounterTableRegistry.get_boss_interval(&"labyrinth")
	if floor_num > 0 and (floor_num % boss_interval) == 0:
		_carve_boss_room(rng, m, junctions, exit_idx, floor_num, connection)

	_scatter_enemies(rng, m, junctions, entry_idx, floor_num)

	return m


static func _push_frontier(jidx: int, jw: int, jh: int,
		visited: Array, dir_delta: Array, frontier: Array) -> void:
	var jx: int = jidx % jw
	var jy: int = jidx / jw
	for d in dir_delta:
		var nx: int = jx + d.x
		var ny: int = jy + d.y
		if nx < 0 or nx >= jw or ny < 0 or ny >= jh:
			continue
		var nidx: int = ny * jw + nx
		if not visited[nidx]:
			frontier.append([jidx, nidx])


static func _carve_corridor(rng: RandomNumberGenerator, m: InteriorMap,
		from: Vector2i, to: Vector2i) -> void:
	var w: int = rng.randi_range(_MIN_CORRIDOR_WIDTH, _MAX_CORRIDOR_WIDTH)
	var half: int = w / 2
	if from.x == to.x:
		var y0: int = min(from.y, to.y)
		var y1: int = max(from.y, to.y)
		var cx: int = from.x
		for y in range(y0, y1 + 1):
			for dx in range(-half, half + (w % 2)):
				m.set_at(Vector2i(cx + dx, y), TerrainCodes.INTERIOR_FLOOR)
	else:
		var x0: int = min(from.x, to.x)
		var x1: int = max(from.x, to.x)
		var cy: int = from.y
		for x in range(x0, x1 + 1):
			for dy in range(-half, half + (w % 2)):
				m.set_at(Vector2i(x, cy + dy), TerrainCodes.INTERIOR_FLOOR)


static func _pick_border_junction(jw: int, jh: int,
		connection: Array, rng: RandomNumberGenerator) -> int:
	var border: Array = []
	for jy in jh:
		for jx in jw:
			if jx == 0 or jx == jw - 1 or jy == 0 or jy == jh - 1:
				border.append(jy * jw + jx)
	if border.is_empty():
		return 0
	# Use rng for deterministic shuffle instead of border.shuffle()
	for i in range(border.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = border[i]
		border[i] = border[j]
		border[j] = tmp
	var best: int = border[0]
	var best_conn: int = (connection[best] as Array).size()
	for idx in border:
		var c: int = (connection[idx] as Array).size()
		if c < best_conn:
			best_conn = c
			best = idx
	return best


static func _pick_far_junction(start: int, total: int, connection: Array) -> int:
	var dist: Array = []
	dist.resize(total)
	dist.fill(-1)
	dist[start] = 0
	var queue: Array = [start]
	var farthest: int = start
	var max_dist: int = 0
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nb in (connection[cur] as Array):
			if dist[nb] == -1:
				dist[nb] = dist[cur] + 1
				if dist[nb] > max_dist:
					max_dist = dist[nb]
					farthest = nb
				queue.append(nb)
	return farthest


static func _carve_boss_room(rng: RandomNumberGenerator, m: InteriorMap,
		junctions: Array, exit_idx: int,
		floor_num: int, connection: Array) -> void:
	var boss_jidx: int = exit_idx
	var dead_ends: Array = []
	for idx in connection.size():
		if idx == exit_idx:
			continue
		if (connection[idx] as Array).size() == 1:
			dead_ends.append(idx)
	if not dead_ends.is_empty():
		var min_dist: int = 999
		var best_idx: int = exit_idx
		for idx in dead_ends:
			var d: int = abs(junctions[idx].x - junctions[exit_idx].x) \
				+ abs(junctions[idx].y - junctions[exit_idx].y)
			if d < min_dist:
				min_dist = d
				best_idx = idx
		boss_jidx = best_idx

	var centre: Vector2i = junctions[boss_jidx]
	var room_cells: Array = []
	for dy in range(-_BOSS_ROOM_HALF, _BOSS_ROOM_HALF + 1):
		for dx in range(-_BOSS_ROOM_HALF, _BOSS_ROOM_HALF + 1):
			var cell: Vector2i = centre + Vector2i(dx, dy)
			m.set_at(cell, TerrainCodes.INTERIOR_FLOOR)
			room_cells.append(cell)
	m.boss_room_cells = room_cells

	var boss_kind: StringName = _pick_boss_kind(rng)

	var adds_data: Array = []
	var adds_list: Array = CreatureSpriteRegistry.get_boss_adds(boss_kind)
	var add_positions: Array = [
		centre + Vector2i(-3, -3),
		centre + Vector2i( 3, -3),
		centre + Vector2i(-3,  3),
		centre + Vector2i( 3,  3),
	]
	var ai: int = 0
	for add_entry in adds_list:
		var add_count: int = int(add_entry.get("count", 1))
		for _i in add_count:
			if ai >= add_positions.size():
				break
			adds_data.append({
				"kind": StringName(add_entry.get("creature", &"slime")),
				"cell": add_positions[ai],
			})
			ai += 1

	m.boss_data = {
		"kind": boss_kind,
		"cell": centre,
		"adds": adds_data,
	}

	m.chest_scatter = m.chest_scatter.filter(
		func(e: Dictionary) -> bool: return e["cell"] != centre)


static func _pick_boss_kind(rng: RandomNumberGenerator) -> StringName:
	var all_kinds: Array = CreatureSpriteRegistry.all_kinds()
	var bosses: Array = all_kinds.filter(
		func(k) -> bool: return CreatureSpriteRegistry.is_boss(StringName(k)))
	if bosses.is_empty():
		return &"slime_king"
	return StringName(bosses[rng.randi_range(0, bosses.size() - 1)])


static func _scatter_enemies(rng: RandomNumberGenerator, m: InteriorMap,
		junctions: Array, entry_idx: int, floor_num: int) -> void:
	var table: Array = EncounterTableRegistry.get_weighted_list(&"labyrinth", floor_num)
	if table.is_empty():
		return
	var boss_cells: Dictionary = {}
	for cell in m.boss_room_cells:
		boss_cells[cell] = true

	for idx in junctions.size():
		if idx == entry_idx:
			continue
		var jcell: Vector2i = junctions[idx]
		if boss_cells.has(jcell):
			continue
		if rng.randf() >= 0.30:
			continue
		var pick: Dictionary = EncounterTableRegistry.weighted_pick(rng, table)
		if pick.is_empty():
			continue
		var kind: StringName = pick.get("creature", &"slime")
		m.npcs_scatter.append({
			"kind": kind,
			"monster_kind": kind,
			"cell": jcell,
			"variant": rng.randi(),
		})
