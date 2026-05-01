## Integration tests for death → respawn flow.
extends GutTest

const GameScene := preload("res://scenes/main/Game.tscn")

var _game: Node = null
var _p1: PlayerController = null

func before_each() -> void:
	WorldManager.reset(999)
	_game = GameScene.instantiate()
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# Find P1 PlayerController — search recursively.
	_p1 = _find_player(_game, 0)


func _find_player(node: Node, pid: int) -> PlayerController:
	if node is PlayerController and (node as PlayerController).player_id == pid:
		return node as PlayerController
	for child in node.get_children():
		var found: PlayerController = _find_player(child, pid)
		if found != null:
			return found
	return null


func test_player_p1_exists() -> void:
	assert_not_null(_p1, "PlayerController p1 should exist in game scene")


func test_is_dead_false_on_start() -> void:
	if _p1 == null:
		pass
		return
	assert_false(_p1.is_dead)


func test_die_sets_is_dead_and_zeros_health() -> void:
	if _p1 == null:
		pass
		return
	_p1.health = 5
	_p1.die()
	assert_true(_p1.is_dead)
	assert_eq(_p1.health, 0)


func test_respawn_restores_health_and_grants_invincibility() -> void:
	if _p1 == null:
		pass
		return
	_p1.health = 1
	_p1.is_dead = true
	_p1.respawn(_p1.max_health)
	assert_false(_p1.is_dead)
	assert_eq(_p1.health, _p1.max_health)
	assert_gt(_p1._invincible_timer, 0.0)


func test_take_hit_ignored_while_dead() -> void:
	if _p1 == null:
		pass
		return
	var hp := _p1.health
	_p1.health = hp
	_p1.die()
	_p1.take_hit(999)
	assert_eq(_p1.health, 0)


func test_take_hit_ignored_while_invincible() -> void:
	if _p1 == null:
		pass
		return
	_p1.health = _p1.max_health
	_p1.is_dead = true
	_p1.respawn(_p1.max_health)
	_p1.take_hit(5)
	assert_eq(_p1.health, _p1.max_health)


func test_tree_not_paused_by_die() -> void:
	if _p1 == null:
		pass
		return
	_p1.health = 1
	_p1.die()
	assert_false(get_tree().paused, "die() must not pause the scene tree")
