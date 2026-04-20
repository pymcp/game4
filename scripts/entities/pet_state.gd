## PetState
##
## Pure-logic helpers for the [Pet] companion. Kept separate from the
## scene/node so the state machine and follow-distance rules can be
## unit-tested without instantiating any nodes.
##
## States:
##   IDLE   — close enough to owner, standing still (with the occasional
##            wander tick at the call site)
##   FOLLOW — too far from owner, walking toward them
##   ATTACK — a hostile NPC is in range and the owner is reachable
##   HAPPY  — petted by the owner; brief hop animation, no movement
##   STUCK  — way too far behind; caller should teleport
class_name PetState
extends RefCounted

enum State { IDLE, FOLLOW, ATTACK, HAPPY, STUCK }

const FOLLOW_RADIUS_TILES: float = 3.0
const TELEPORT_RADIUS_TILES: float = 20.0
const ATTACK_DETECT_TILES: float = 4.0
const ATTACK_BREAKOFF_TILES: float = 6.0
const HAPPY_DURATION_SEC: float = 0.6


## Decide which state the pet should be in next.
## - [param curr]: current state
## - [param dist_owner_tiles]: tile distance to owner (NaN/inf if owner
##                             missing — treated as STUCK only if huge)
## - [param dist_enemy_tiles]: tile distance to nearest hostile NPC, or
##                             INF if none in range. Caller is responsible
##                             for filtering by `hostile` flag.
## - [param happy_remaining_sec]: time left in HAPPY (0 means free to leave)
static func decide_state(curr: State, dist_owner_tiles: float,
		dist_enemy_tiles: float, happy_remaining_sec: float) -> State:
	# HAPPY is non-interruptible until the timer drains.
	if curr == State.HAPPY and happy_remaining_sec > 0.0:
		return State.HAPPY
	# Way out of range → caller teleports.
	if dist_owner_tiles > TELEPORT_RADIUS_TILES:
		return State.STUCK
	# Combat: only engage if the enemy is in detect radius AND the owner
	# is still nearby (don't drag the pet across the map after a target).
	if dist_enemy_tiles <= ATTACK_DETECT_TILES \
			and dist_owner_tiles <= ATTACK_BREAKOFF_TILES:
		return State.ATTACK
	# If we were attacking but enemy moved out of breakoff range, drop it.
	if curr == State.ATTACK and dist_enemy_tiles > ATTACK_BREAKOFF_TILES:
		# Fall through to follow/idle decision below.
		pass
	if dist_owner_tiles > FOLLOW_RADIUS_TILES:
		return State.FOLLOW
	return State.IDLE


## Returns true when the pet should teleport-snap to the owner (caller
## checks each frame; true means "do it this frame, then resume").
static func should_teleport(dist_owner_tiles: float) -> bool:
	return dist_owner_tiles > TELEPORT_RADIUS_TILES
