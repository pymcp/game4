extends GutTest

func test_dead_when_hp_zero() -> void:
	var s := WarriorState.decide_state(WarriorState.State.IDLE, 0, 0.0, INF)
	assert_eq(s, WarriorState.State.DEAD)

func test_stays_dead() -> void:
	var s := WarriorState.decide_state(WarriorState.State.DEAD, 5, 0.0, INF)
	assert_eq(s, WarriorState.State.DEAD)

func test_attacks_nearby_enemy() -> void:
	var s := WarriorState.decide_state(WarriorState.State.IDLE, 10, 1.0, 1.0)
	assert_eq(s, WarriorState.State.ATTACK)

func test_attacks_when_enemy_in_sight() -> void:
	var s := WarriorState.decide_state(WarriorState.State.IDLE, 10, 1.0, 5.0)
	assert_eq(s, WarriorState.State.ATTACK)

func test_follows_when_far_from_target() -> void:
	# No enemy, far from target
	var s := WarriorState.decide_state(WarriorState.State.IDLE, 10, 5.0, INF)
	assert_eq(s, WarriorState.State.FOLLOW)

func test_idles_when_close_to_target() -> void:
	var s := WarriorState.decide_state(WarriorState.State.IDLE, 10, 0.5, INF)
	assert_eq(s, WarriorState.State.IDLE)

func test_leaves_attack_when_no_enemy() -> void:
	var s := WarriorState.decide_state(WarriorState.State.ATTACK, 10, 1.0, INF)
	assert_eq(s, WarriorState.State.FOLLOW)
