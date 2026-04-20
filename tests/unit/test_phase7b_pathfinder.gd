## Phase 7b — Pathfinder unit tests.
extends GutTest


func _open(_c: Vector2i) -> bool:
	return true


# Walkable everywhere except a vertical wall at x=2 from y=0..3 with a gap at y=2.
func _wall_with_gap(c: Vector2i) -> bool:
	if c.x == 2 and c.y >= 0 and c.y <= 3 and c.y != 2:
		return false
	return true


func _all_blocked(_c: Vector2i) -> bool:
	return false


func test_path_to_self_is_single_cell() -> void:
	var p := Pathfinder.find_path(Vector2i(3, 3), Vector2i(3, 3), _open)
	assert_eq(p, [Vector2i(3, 3)])


func test_straight_line_path_length() -> void:
	var p := Pathfinder.find_path(Vector2i(0, 0), Vector2i(3, 0), _open)
	assert_eq(p.size(), 4)
	assert_eq(p.front(), Vector2i(0, 0))
	assert_eq(p.back(), Vector2i(3, 0))


func test_l_shaped_path() -> void:
	var p := Pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 2), _open)
	assert_eq(p.size(), 5)  # manhattan 4 + 1 inclusive
	assert_eq(p.front(), Vector2i(0, 0))
	assert_eq(p.back(), Vector2i(2, 2))


func test_no_path_when_fully_blocked() -> void:
	var p := Pathfinder.find_path(Vector2i(0, 0), Vector2i(5, 5), _all_blocked)
	# Goal cell is always walkable, but neighbours of start are not.
	assert_eq(p, [])


func test_routes_around_wall_through_gap() -> void:
	var p := Pathfinder.find_path(Vector2i(0, 1), Vector2i(4, 1), _wall_with_gap)
	assert_gt(p.size(), 0, "should find a path through the gap")
	# Path should include the gap cell.
	assert_true(p.has(Vector2i(2, 2)),
		"path should pass through the gap at (2,2): %s" % [p])


func test_max_nodes_limit_enforced() -> void:
	var p := Pathfinder.find_path(Vector2i(0, 0), Vector2i(50, 50), _open, 5)
	assert_eq(p, [], "should bail out when expansion budget exhausted")


func test_heuristic_is_manhattan() -> void:
	assert_eq(Pathfinder.heuristic(Vector2i(0, 0), Vector2i(3, 4)), 7)
	assert_eq(Pathfinder.heuristic(Vector2i(2, 2), Vector2i(2, 2)), 0)


func test_next_step_returns_second_cell() -> void:
	var path: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert_eq(Pathfinder.next_step(path, Vector2i(0, 0)), Vector2i(1, 0))


func test_next_step_advances_along_path() -> void:
	var path: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert_eq(Pathfinder.next_step(path, Vector2i(1, 0)), Vector2i(2, 0))


func test_next_step_at_end_returns_current() -> void:
	var path: Array = [Vector2i(0, 0), Vector2i(1, 0)]
	assert_eq(Pathfinder.next_step(path, Vector2i(1, 0)), Vector2i(1, 0))


func test_next_step_single_cell_path() -> void:
	var path: Array = [Vector2i(5, 5)]
	assert_eq(Pathfinder.next_step(path, Vector2i(5, 5)), Vector2i(5, 5))
