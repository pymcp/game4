## Unit tests for HeartDisplay pure helpers and update logic.
extends GutTest


# --- heart_count ---------------------------------------------------

func test_heart_count_10_hp() -> void:
	assert_eq(HeartDisplay.heart_count(10), 3, "10 HP / 4 = 3 hearts")


func test_heart_count_3_hp() -> void:
	assert_eq(HeartDisplay.heart_count(3), 1, "3 HP / 4 = 1 heart")


func test_heart_count_5_hp() -> void:
	assert_eq(HeartDisplay.heart_count(5), 2, "5 HP / 4 = 2 hearts")


func test_heart_count_4_hp() -> void:
	assert_eq(HeartDisplay.heart_count(4), 1, "4 HP / 4 = 1 heart")


func test_heart_count_20_hp() -> void:
	assert_eq(HeartDisplay.heart_count(20), 5, "20 HP / 4 = 5 hearts")


func test_heart_count_1_hp() -> void:
	assert_eq(HeartDisplay.heart_count(1), 1, "1 HP / 4 = 1 heart")


func test_heart_count_0_hp() -> void:
	assert_eq(HeartDisplay.heart_count(0), 0, "0 HP = 0 hearts")


# --- heart_fill ----------------------------------------------------

func test_heart_fill_full_first_heart() -> void:
	# 10 HP max, heart 0 covers HP 0-4.  At 10 curr, heart 0 is full.
	assert_almost_eq(HeartDisplay.heart_fill(10, 10, 0), 1.0, 0.001)


func test_heart_fill_full_second_heart() -> void:
	assert_almost_eq(HeartDisplay.heart_fill(10, 10, 1), 1.0, 0.001)


func test_heart_fill_partial_last_heart() -> void:
	# 10 HP max, heart 2 covers HP 8-10 (only 2 HP span).  At full: 2/2 = 1.0.
	assert_almost_eq(HeartDisplay.heart_fill(10, 10, 2), 1.0, 0.001)


func test_heart_fill_last_heart_half_drained() -> void:
	# 9 HP curr, heart 2 covers 8-10.  9-8=1 filled of 2 span = 0.5
	assert_almost_eq(HeartDisplay.heart_fill(9, 10, 2), 0.5, 0.001)


func test_heart_fill_last_heart_empty() -> void:
	# 8 HP curr, heart 2 covers 8-10.  8-8=0 filled = 0.0
	assert_almost_eq(HeartDisplay.heart_fill(8, 10, 2), 0.0, 0.001)


func test_heart_fill_second_heart_quarter_drained() -> void:
	# 7 HP curr, heart 1 covers 4-8.  7-4=3 filled of 4 span = 0.75
	assert_almost_eq(HeartDisplay.heart_fill(7, 10, 1), 0.75, 0.001)


func test_heart_fill_first_heart_zero() -> void:
	# 0 HP curr, heart 0 should be 0.
	assert_almost_eq(HeartDisplay.heart_fill(0, 10, 0), 0.0, 0.001)


func test_heart_fill_monster_3hp() -> void:
	# Monster: 3 HP max, 1 heart.  Heart 0 covers 0-3 (span 3).
	# At 2 curr: 2/3 ≈ 0.667
	assert_almost_eq(HeartDisplay.heart_fill(2, 3, 0), 2.0 / 3.0, 0.001)


func test_heart_fill_4hp_single_heart() -> void:
	# 4 HP max, 1 heart. Covers 0-4. At 1 curr: 1/4 = 0.25
	assert_almost_eq(HeartDisplay.heart_fill(1, 4, 0), 0.25, 0.001)


# --- update & break detection (scene-tree tests) -------------------

func test_update_sets_size() -> void:
	var hd := HeartDisplay.new(12.0)
	add_child_autofree(hd)
	hd.update(10, 10)
	assert_gt(hd.size.x, 0.0, "width should be positive after update")
	assert_gt(hd.size.y, 0.0, "height should be positive after update")


func test_update_no_redraw_when_unchanged() -> void:
	var hd := HeartDisplay.new(12.0)
	add_child_autofree(hd)
	hd.update(10, 10)
	var s1: Vector2 = hd.size
	# Calling update again with same values should not change size.
	hd.update(10, 10)
	assert_eq(hd.size, s1, "size should not change on redundant update")


func test_break_spawns_particles() -> void:
	var hd := HeartDisplay.new(12.0)
	add_child_autofree(hd)
	# Start at full health.
	hd.update(10, 10)
	# Drain so heart 2 (HP 8-10) goes from full to empty.
	hd.update(8, 10)
	# A CPUParticles2D child should have been spawned for the break.
	var particles_found: bool = false
	for c in hd.get_children():
		if c is CPUParticles2D:
			particles_found = true
			break
	assert_true(particles_found, "break animation should spawn CPUParticles2D")


func test_no_break_when_still_has_fill() -> void:
	var hd := HeartDisplay.new(12.0)
	add_child_autofree(hd)
	hd.update(10, 10)
	# Drain to 9 — heart 2 goes from 1.0 to 0.5, not empty.
	hd.update(9, 10)
	var particles_found: bool = false
	for c in hd.get_children():
		if c is CPUParticles2D:
			particles_found = true
			break
	assert_false(particles_found, "no break when heart still has fill")
