## Pathfinder
##
## Tile-grid A* for NPCs. Static helpers; no state. Walkability is supplied
## via a Callable so the pathfinder doesn't depend on WorldRoot directly,
## which keeps it unit-testable.
##
## Diagonals are NOT allowed by default (matches the iso "step on a tile"
## feel and keeps NPC trajectories visually sensible).
class_name Pathfinder
extends RefCounted

const MAX_NODES_DEFAULT: int = 1024


## Manhattan-distance heuristic.
static func heuristic(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## A* on a 4-neighbour grid. Returns the path of cells from
## [param start] to [param goal] (inclusive of both). Returns [] if no path
## found within [param max_nodes] expansions.
##
## [param walkable_cb]: Callable(Vector2i) -> bool. The goal cell is always
## treated as walkable (so we can path *to* an attacker / item even when
## they stand on a non-tile).
static func find_path(start: Vector2i, goal: Vector2i,
		walkable_cb: Callable, max_nodes: int = MAX_NODES_DEFAULT) -> Array:
	if start == goal:
		return [start]

	var open: Array = []  # Binary min-heap of [f_score, counter, cell]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var counter: int = 0
	_heap_push(open, [heuristic(start, goal), counter, start])

	var expanded: int = 0
	while not open.is_empty():
		var current_entry: Array = _heap_pop_min(open)
		var current: Vector2i = current_entry[2]
		if current == goal:
			return _reconstruct(came_from, current)
		expanded += 1
		if expanded > max_nodes:
			return []

		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = current + dir
			# Goal cell is always pathable; everything else must be walkable.
			if next != goal and not walkable_cb.call(next):
				continue
			var tentative_g: int = int(g_score[current]) + 1
			if tentative_g < int(g_score.get(next, 0x7fffffff)):
				came_from[next] = current
				g_score[next] = tentative_g
				counter += 1
				_heap_push(open, [tentative_g + heuristic(next, goal), counter, next])
	return []


## Binary min-heap push. Items are [f_score, counter, cell].
static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i: int = heap.size() - 1
	while i > 0:
		var parent: int = (i - 1) / 2
		var h_i: Array = heap[i]
		var h_p: Array = heap[parent]
		if h_i[0] < h_p[0] or (h_i[0] == h_p[0] and h_i[1] < h_p[1]):
			heap[i] = h_p
			heap[parent] = h_i
			i = parent
		else:
			break


## Binary min-heap pop. Returns and removes the item with lowest f_score.
static func _heap_pop_min(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap[heap.size() - 1]
	heap.resize(heap.size() - 1)
	if heap.is_empty():
		return top
	heap[0] = last
	var i: int = 0
	var size: int = heap.size()
	while true:
		var left: int = 2 * i + 1
		var right: int = 2 * i + 2
		var smallest: int = i
		if left < size:
			var h_l: Array = heap[left]
			var h_s: Array = heap[smallest]
			if h_l[0] < h_s[0] or (h_l[0] == h_s[0] and h_l[1] < h_s[1]):
				smallest = left
		if right < size:
			var h_r: Array = heap[right]
			var h_s2: Array = heap[smallest]
			if h_r[0] < h_s2[0] or (h_r[0] == h_s2[0] and h_r[1] < h_s2[1]):
				smallest = right
		if smallest == i:
			break
		var tmp: Array = heap[i]
		heap[i] = heap[smallest]
		heap[smallest] = tmp
		i = smallest
	return top


static func _reconstruct(came_from: Dictionary, end: Vector2i) -> Array:
	var path: Array = [end]
	var n: Vector2i = end
	while came_from.has(n):
		n = came_from[n]
		path.push_front(n)
	return path


## Return the next cell to step toward when following [param path] from
## [param current]. Returns [param current] when at end of path.
static func next_step(path: Array, current: Vector2i) -> Vector2i:
	if path.size() <= 1:
		return current
	for i in range(path.size() - 1):
		if path[i] == current:
			return path[i + 1]
	# Not found in path — return the second cell (best effort).
	return path[1]
