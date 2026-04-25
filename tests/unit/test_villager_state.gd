## Villager unit tests — pure helpers (no scene instantiation).
extends GutTest


func _open(_c: Vector2i) -> bool:
	return true


func _blocked(_c: Vector2i) -> bool:
	return false


func _ring_only(c: Vector2i) -> bool:
	# Walkable only when within a 4-tile Manhattan radius of (10, 10).
	return abs(c.x - 10) + abs(c.y - 10) <= 4


func test_pick_wander_target_returns_home_when_nothing_walkable() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var home := Vector2i(5, 5)
	var got := Villager.pick_wander_target(rng, home, 4, _blocked)
	assert_eq(got, home)


func test_pick_wander_target_skips_origin() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# Even when everything is walkable, the picker must never return `home`.
	for i in range(40):
		rng.seed = i
		var got := Villager.pick_wander_target(rng, Vector2i(0, 0), 3, _open)
		assert_ne(got, Vector2i(0, 0), "iteration %d picked origin" % i)


func test_pick_wander_target_respects_radius_and_walkability() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(40):
		rng.seed = i
		var got := Villager.pick_wander_target(rng, Vector2i(10, 10), 6, _ring_only)
		# Must be inside the walkable ring AND within the 6-radius window.
		assert_true(_ring_only.call(got), "non-walkable result: %s" % str(got))
		assert_true(abs(got.x - 10) + abs(got.y - 10) <= 6,
			"outside radius: %s" % str(got))


func test_step_toward_clamps_at_destination() -> void:
	var got := Villager.step_toward(Vector2(0, 0), Vector2(1, 0), 100.0, 1.0)
	assert_eq(got, Vector2(1, 0))


func test_step_toward_partial_progress() -> void:
	var got := Villager.step_toward(Vector2(0, 0), Vector2(10, 0), 5.0, 1.0)
	assert_almost_eq(got.x, 5.0, 0.001)
	assert_almost_eq(got.y, 0.0, 0.001)


func test_roll_appearance_is_deterministic() -> void:
	for s in [0, 1, 42, 99999]:
		var a := Villager.roll_appearance(s)
		var b := Villager.roll_appearance(s)
		assert_eq(a, b, "seed %d" % s)


func test_roll_appearance_has_required_keys() -> void:
	var opts := Villager.roll_appearance(123)
	for k in ["torso_color", "torso_style", "hair_color", "hair_style"]:
		assert_true(opts.has(k), "missing key: %s" % k)


# --- Combat states -------------------------------------------------

func test_villager_has_health() -> void:
	var v := Villager.new()
	assert_eq(v.max_health, 5, "default max_health should be 5")
	assert_eq(v.health, 5, "default health should be 5")


func test_villager_is_cowardly_default_false() -> void:
	var v := Villager.new()
	assert_false(v.is_cowardly, "default is_cowardly should be false")


func test_villager_state_enum_has_defend_and_flee() -> void:
	# Verify the new states exist.
	assert_eq(Villager.State.DEFEND, 2, "DEFEND should be state 2")
	assert_eq(Villager.State.FLEE, 3, "FLEE should be state 3")
