## Phase 7a — NPC state machine + pure-helper tests.
extends GutTest


func _walkable_all(_c: Vector2i) -> bool:
	return true


func _walkable_none(_c: Vector2i) -> bool:
	return false


func _walkable_only_origin_neighbours(c: Vector2i) -> bool:
	return abs(c.x) <= 1 and abs(c.y) <= 1


# ---------- decide_state ----------

func test_dead_when_hp_zero() -> void:
	var s := NPC.decide_state(NPC.State.IDLE, 1.0, 0, 0.0, 6.0, 1.0, 10.0)
	assert_eq(s, NPC.State.DEAD)


func test_attack_when_in_range() -> void:
	var s := NPC.decide_state(NPC.State.IDLE, 1.0, 5, 0.0, 6.0, 1.25, 10.0)
	assert_eq(s, NPC.State.ATTACK)


func test_chase_when_in_sight_outside_attack_range() -> void:
	var s := NPC.decide_state(NPC.State.IDLE, 4.0, 5, 0.0, 6.0, 1.25, 10.0)
	assert_eq(s, NPC.State.CHASE)


func test_idle_when_target_out_of_sight() -> void:
	var s := NPC.decide_state(NPC.State.WANDER, 100.0, 5, 0.0, 6.0, 1.25, 10.0)
	assert_eq(s, NPC.State.WANDER, "no target → keep current non-combat state")
	var s2 := NPC.decide_state(NPC.State.CHASE, 100.0, 5, 0.0, 6.0, 1.25, 10.0)
	assert_eq(s2, NPC.State.IDLE, "chase → idle when target slips out of sight")


func test_leash_breaks_chase() -> void:
	# Currently chasing, target still in sight, but we wandered too far from
	# home: should give up.
	var s := NPC.decide_state(NPC.State.CHASE, 4.0, 5, 12.0, 6.0, 1.25, 10.0)
	assert_eq(s, NPC.State.IDLE)


func test_dead_state_sticks() -> void:
	var s := NPC.decide_state(NPC.State.DEAD, 1.0, 5, 0.0, 6.0, 1.25, 10.0)
	assert_eq(s, NPC.State.DEAD)


# ---------- wander_step ----------

func test_wander_step_returns_origin_when_no_walkable() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var step := NPC.wander_step(rng, Vector2i(5, 5), 3, _walkable_none)
	assert_eq(step, Vector2i(5, 5))


func test_wander_step_chooses_walkable_neighbour() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var step := NPC.wander_step(rng, Vector2i.ZERO, 1, _walkable_only_origin_neighbours)
	# Step is non-origin (since origin excluded) and within manhattan ≤ 1.
	assert_ne(step, Vector2i.ZERO)
	assert_lte(abs(step.x) + abs(step.y), 1)


func test_wander_step_respects_max_dist() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in range(20):
		var step := NPC.wander_step(rng, Vector2i(10, 10), 2, _walkable_all)
		var dx := step.x - 10
		var dy := step.y - 10
		assert_lte(abs(dx) + abs(dy), 2)


# ---------- step_toward ----------

func test_step_toward_clamps_to_dest() -> void:
	var p := NPC.step_toward(Vector2(0, 0), Vector2(1, 0), 100.0, 0.5)
	assert_eq(p, Vector2(1, 0))


func test_step_toward_partial_step() -> void:
	var p := NPC.step_toward(Vector2(0, 0), Vector2(10, 0), 4.0, 1.0)
	assert_eq(p, Vector2(4, 0))


func test_step_toward_already_at_dest() -> void:
	var p := NPC.step_toward(Vector2(5, 5), Vector2(5, 5), 100.0, 1.0)
	assert_eq(p, Vector2(5, 5))


# ---------- NPC live behaviour ----------

func _make_npc() -> NPC:
	var n := NPC.new()
	n.max_health = 5
	n.health = 5
	n.drops = [{"id": &"fiber", "count": 1}]
	add_child_autofree(n)
	return n


func test_npc_initial_state_is_idle() -> void:
	var n := _make_npc()
	await get_tree().process_frame
	assert_eq(n.state, NPC.State.IDLE)


func test_take_hit_reduces_hp() -> void:
	var n := _make_npc()
	await get_tree().process_frame
	n.take_hit(2)
	assert_eq(n.health, 3)
	assert_ne(n.state, NPC.State.DEAD)


func test_take_hit_kills_and_emits_died() -> void:
	var n := _make_npc()
	await get_tree().process_frame
	var fired: Array = []
	n.died.connect(func(pos, drops): fired.append([pos, drops]))
	n.take_hit(99)
	assert_eq(fired.size(), 1)
	assert_eq(int((fired[0][1] as Array).size()), 1)
	assert_eq(n.state, NPC.State.DEAD)


func test_taking_hit_acquires_attacker_as_target() -> void:
	var n := _make_npc()
	await get_tree().process_frame
	var attacker := Node2D.new()
	add_child_autofree(attacker)
	attacker.position = Vector2(64, 0)
	n.take_hit(1, attacker)
	assert_eq(n.target, attacker)


func test_dead_npc_ignores_further_hits() -> void:
	var n := _make_npc()
	await get_tree().process_frame
	n.take_hit(99)
	assert_eq(n.state, NPC.State.DEAD)
	# Should not crash or fire died again.
	n.take_hit(1)


func test_idle_progresses_to_wander_after_timeout() -> void:
	var n := _make_npc()
	await get_tree().process_frame
	# Manually fast-forward the state timer.
	n._state_timer = NPC.IDLE_DURATION_SEC + 0.1
	# Trigger one physics step.
	n._physics_process(0.016)
	assert_eq(n.state, NPC.State.WANDER)


func test_chase_state_picks_when_target_within_sight() -> void:
	var n := _make_npc()
	n.position = Vector2.ZERO
	await get_tree().process_frame
	var target_node := Node2D.new()
	add_child_autofree(target_node)
	# 3 tiles away horizontally → within sight (default 6) but outside attack
	# range (default 1.25).
	target_node.position = Vector2(IsoUtils.TILE_SIZE.x * 3.0, 0)
	n.set_target(target_node)
	n._physics_process(0.016)
	assert_eq(n.state, NPC.State.CHASE)


func test_attack_state_when_within_attack_range() -> void:
	var n := _make_npc()
	n.position = Vector2.ZERO
	await get_tree().process_frame
	var target_node := Node2D.new()
	add_child_autofree(target_node)
	target_node.position = Vector2(IsoUtils.TILE_SIZE.x * 0.5, 0)
	n.set_target(target_node)
	n._physics_process(0.016)
	assert_eq(n.state, NPC.State.ATTACK)
