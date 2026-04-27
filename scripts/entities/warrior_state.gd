## WarriorState
##
## Pure stateless FSM decision logic for the Warrior companion.
## All methods are static so the logic can be unit-tested without scene instantiation.
class_name WarriorState
extends RefCounted

enum State { IDLE, FOLLOW, ATTACK, DEAD }

## Combat configuration constants.
const ATTACK_RANGE_TILES: float = 1.5
const SIGHT_RANGE_TILES: float = 6.0
const FOLLOW_DIST_TILES: float = 2.5  ## Start following when farther than this.
const ARRIVE_DIST_TILES: float = 1.0  ## Stop following when this close.

## Decide next state. All inputs are in tiles or discrete values.
## - curr: current state
## - hp: current health (0 = dead)
## - dist_target_tiles: distance to follow target (caravan or player)
## - dist_enemy_tiles: distance to nearest hostile (INF if none)
static func decide_state(curr: State, hp: int,
		dist_target_tiles: float,
		dist_enemy_tiles: float) -> State:
	if hp <= 0:
		return State.DEAD
	if curr == State.DEAD:
		return State.DEAD
	# Attack takes priority when enemy is in range.
	if dist_enemy_tiles <= ATTACK_RANGE_TILES:
		return State.ATTACK
	# Enter ATTACK mode when enemy enters sight range.
	if dist_enemy_tiles <= SIGHT_RANGE_TILES:
		return State.ATTACK
	# Leave ATTACK if no enemy in sight.
	if curr == State.ATTACK:
		return State.FOLLOW
	# Follow when far from target.
	if dist_target_tiles > FOLLOW_DIST_TILES:
		return State.FOLLOW
	# Idle when close to target.
	if dist_target_tiles <= ARRIVE_DIST_TILES:
		return State.IDLE
	return curr
