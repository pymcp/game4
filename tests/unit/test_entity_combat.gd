## Tests for Monster combat FSM and NPC attack VFX wiring.
extends GutTest


func before_each() -> void:
	CreatureSpriteRegistry.reset()


# --- Monster combat stats loaded from creature data ----------------

func test_monster_slime_attack_style() -> void:
	var m := Monster.new()
	m.monster_kind = &"slime"
	add_child_autofree(m)
	assert_eq(m._attack_style, &"slam", "slime should have slam style")


func test_monster_wolf_attack_damage() -> void:
	var m := Monster.new()
	m.monster_kind = &"wolf"
	add_child_autofree(m)
	assert_eq(m._attack_damage, 2, "wolf should have 2 attack_damage")


func test_monster_fire_elemental_element() -> void:
	var m := Monster.new()
	m.monster_kind = &"fire_elemental"
	add_child_autofree(m)
	assert_eq(m._attack_element, ItemDefinition.Element.FIRE)


func test_monster_attack_cooldown_starts_at_zero() -> void:
	var m := Monster.new()
	add_child_autofree(m)
	assert_almost_eq(m._attack_cooldown, 0.0, 0.001,
		"attack cooldown should start at 0")


# --- NPC decide_state (static, testable) ---------------------------

func test_npc_decide_attack_when_in_range() -> void:
	var s: NPC.State = NPC.decide_state(
		NPC.State.CHASE, 1.0, 5, 2.0, 6.0, 1.25, 10.0)
	assert_eq(s, NPC.State.ATTACK, "should attack when dist <= attack_range")


func test_npc_decide_chase_when_in_sight() -> void:
	var s: NPC.State = NPC.decide_state(
		NPC.State.IDLE, 4.0, 5, 2.0, 6.0, 1.25, 10.0)
	assert_eq(s, NPC.State.CHASE, "should chase when in sight range")


func test_npc_decide_dead_when_hp_zero() -> void:
	var s: NPC.State = NPC.decide_state(
		NPC.State.ATTACK, 1.0, 0, 2.0, 6.0, 1.25, 10.0)
	assert_eq(s, NPC.State.DEAD, "should be dead when hp == 0")


func test_npc_decide_idle_when_leash_exceeded() -> void:
	var s: NPC.State = NPC.decide_state(
		NPC.State.CHASE, 4.0, 5, 11.0, 6.0, 1.25, 10.0)
	assert_eq(s, NPC.State.IDLE, "should idle when leash exceeded")
