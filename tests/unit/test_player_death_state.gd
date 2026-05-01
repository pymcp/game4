## Tests for PlayerController death state and invincibility.
extends GutTest

func _make_player() -> PlayerController:
	var p := PlayerController.new()
	add_child_autofree(p)
	return p


func test_is_dead_false_by_default() -> void:
	var p := _make_player()
	assert_false(p.is_dead)


func test_die_sets_is_dead() -> void:
	var p := _make_player()
	p.health = 5
	p.die()
	assert_true(p.is_dead)


func test_respawn_clears_is_dead() -> void:
	var p := _make_player()
	p.health = 5
	p.die()
	p.respawn(10)
	assert_false(p.is_dead)


func test_respawn_restores_health() -> void:
	var p := _make_player()
	p.health = 1
	p.die()
	p.respawn(10)
	assert_eq(p.health, 10)


func test_take_hit_ignored_while_dead() -> void:
	var p := _make_player()
	p.health = 5
	p.die()
	p.take_hit(99)
	assert_eq(p.health, 0)  # health unchanged after die()


func test_take_hit_ignored_during_invincibility() -> void:
	var p := _make_player()
	p.health = 10
	p.respawn(10)  # starts invincibility
	p.take_hit(5)
	assert_eq(p.health, 10)


func test_invincible_timer_starts_after_respawn() -> void:
	var p := _make_player()
	p.respawn(10)
	assert_gt(p._invincible_timer, 0.0)
