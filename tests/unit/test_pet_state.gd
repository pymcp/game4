## Tests for [PetState] decision logic.
extends GutTest

const PS := preload("res://scripts/entities/pet_state.gd")


func test_idle_when_close_no_enemy() -> void:
	assert_eq(PS.decide_state(PS.State.IDLE, 1.0, INF, 0.0), PS.State.IDLE)


func test_follow_when_owner_far() -> void:
	assert_eq(PS.decide_state(PS.State.IDLE, 5.0, INF, 0.0), PS.State.FOLLOW)


func test_follow_returns_to_idle_within_radius() -> void:
	assert_eq(PS.decide_state(PS.State.FOLLOW, 2.0, INF, 0.0), PS.State.IDLE)


func test_attack_when_hostile_in_range_and_owner_near() -> void:
	assert_eq(PS.decide_state(PS.State.IDLE, 2.0, 3.0, 0.0), PS.State.ATTACK)


func test_no_attack_when_owner_too_far() -> void:
	# Enemy in range but owner past breakoff → don't engage.
	assert_eq(PS.decide_state(PS.State.IDLE, 8.0, 3.0, 0.0), PS.State.FOLLOW)


func test_attack_drops_when_enemy_leaves_breakoff() -> void:
	assert_eq(PS.decide_state(PS.State.ATTACK, 2.0, 7.0, 0.0), PS.State.IDLE)


func test_happy_is_non_interruptible() -> void:
	# Even if owner is far + enemy nearby, HAPPY stays put while timer > 0.
	assert_eq(PS.decide_state(PS.State.HAPPY, 5.0, 1.0, 0.3), PS.State.HAPPY)


func test_happy_releases_when_timer_zero() -> void:
	assert_eq(PS.decide_state(PS.State.HAPPY, 5.0, INF, 0.0), PS.State.FOLLOW)


func test_stuck_when_owner_past_teleport_radius() -> void:
	assert_eq(PS.decide_state(PS.State.IDLE, 25.0, INF, 0.0), PS.State.STUCK)


func test_should_teleport_threshold() -> void:
	assert_false(PS.should_teleport(20.0))
	assert_true(PS.should_teleport(20.5))
