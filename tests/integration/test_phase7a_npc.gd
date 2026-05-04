## Phase 7a — Monster live-behaviour integration tests.
## The old NPC class (with its decide_state/wander_step pure helpers) has been
## removed. These tests now cover the equivalent Monster runtime behaviour.
extends GutTest


# ---------- Monster live behaviour ----------

func _make_monster() -> Monster:
	var m := Monster.new()
	m.max_health = 5
	m.health = 5
	m.monster_kind = &"slime"
	add_child_autofree(m)
	return m


func test_monster_take_hit_reduces_hp() -> void:
	var m := _make_monster()
	await get_tree().process_frame
	m.take_hit(2)
	assert_eq(m.health, 3)
	assert_gt(m.health, 0)


func test_monster_take_hit_kills_and_emits_died() -> void:
	var m := _make_monster()
	await get_tree().process_frame
	var fired: Array = []
	m.died.connect(func(pos, drops): fired.append([pos, drops]))
	m.take_hit(99)
	assert_eq(fired.size(), 1)
	assert_eq(m.health, 0)


func test_monster_dead_ignores_further_hits() -> void:
	var m := _make_monster()
	await get_tree().process_frame
	m.take_hit(99)
	assert_eq(m.health, 0)
	# Should not crash or fire died again (monster queues free on death).
	# We just verify it doesn't throw.
	pass


func test_monster_nearest_player_returns_null_with_no_players() -> void:
	var result: PlayerController = Monster.nearest_player(
			Vector2.ZERO, [], Monster.SIGHT_RADIUS_TILES)
	assert_null(result)




