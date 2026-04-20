## VillagerDialogue unit tests.
extends GutTest


func test_pick_line_is_deterministic() -> void:
	for s in [0, 1, 7, 42, 12345, -3, 99999]:
		var a := VillagerDialogue.pick_line(s)
		var b := VillagerDialogue.pick_line(s)
		assert_eq(a, b, "same seed -> same line (seed=%d)" % s)


func test_pick_line_returns_nonempty() -> void:
	for s in range(20):
		assert_true(VillagerDialogue.pick_line(s).length() > 0,
			"non-empty for seed %d" % s)


func test_pool_has_at_least_twelve_lines() -> void:
	assert_true(VillagerDialogue.LINES.size() >= 12,
		"got %d lines" % VillagerDialogue.LINES.size())


func test_pool_lines_are_unique() -> void:
	var seen: Dictionary = {}
	for line in VillagerDialogue.LINES:
		assert_false(seen.has(line), "duplicate line: %s" % line)
		seen[line] = true


func test_pick_line_handles_negative_seeds() -> void:
	# Modulo of a negative number should still yield a valid index.
	for s in [-1, -7, -100, -2147483647]:
		var line := VillagerDialogue.pick_line(s)
		assert_true(line.length() > 0, "negative seed %d" % s)


func test_pick_name_is_deterministic_and_nonempty() -> void:
	for s in [0, 1, 13, 26, 100, -5]:
		var n1 := VillagerDialogue.pick_name(s)
		var n2 := VillagerDialogue.pick_name(s)
		assert_eq(n1, n2)
		assert_true(n1.length() > 0)
