## Tests for Phase 4: Combat Properties + Weapon VFX System
extends GutTest


var _backup: Dictionary = {}


func before_all() -> void:
	ItemRegistry.reset()
	_backup = ItemRegistry.get_raw_data().duplicate(true)


func before_each() -> void:
	ItemRegistry.reset()


func after_all() -> void:
	ItemRegistry.save_data(_backup)
	ItemRegistry.reset()


# --- Monster.take_hit + death ------------------------------------

func test_monster_takes_damage() -> void:
	var m := Monster.new()
	add_child_autofree(m)
	assert_eq(m.health, 3)
	m.take_hit(1)
	assert_eq(m.health, 2)


func test_monster_dies_at_zero_hp() -> void:
	var m := Monster.new()
	add_child_autofree(m)
	watch_signals(m)
	m.take_hit(10)
	assert_eq(m.health, 0)
	assert_signal_emitted(m, "died")


func test_monster_emits_drops_on_death() -> void:
	var m := Monster.new()
	m.drops = [{"id": &"wood", "count": 2}]
	add_child_autofree(m)
	watch_signals(m)
	m.take_hit(100)
	assert_signal_emitted(m, "died")
	var params: Array = get_signal_parameters(m, "died")
	var received_drops: Array = params[1]
	assert_eq(received_drops.size(), 1)
	assert_eq(received_drops[0]["id"], &"wood")


func test_monster_overkill_clamps_to_zero() -> void:
	var m := Monster.new()
	add_child_autofree(m)
	m.take_hit(999)
	assert_eq(m.health, 0)


# --- Data-driven attack type dispatch ----------------------------

func test_sword_is_melee_attack_type() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_not_null(def)
	assert_eq(def.attack_type, ItemDefinition.AttackType.MELEE)


func test_bow_is_ranged_attack_type() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"bow")
	assert_not_null(def)
	assert_eq(def.attack_type, ItemDefinition.AttackType.RANGED)


func test_sword_has_weapon_category() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_eq(def.weapon_category, ItemDefinition.WeaponCategory.SWORD)


func test_bow_has_weapon_category() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"bow")
	assert_eq(def.weapon_category, ItemDefinition.WeaponCategory.BOW)


# --- Per-weapon reach & attack_speed -----------------------------

func test_sword_reach_from_data() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_eq(def.reach, 24.0)


func test_bow_reach_from_data() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"bow")
	assert_eq(def.reach, 80.0)


func test_sword_attack_speed_from_data() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_eq(def.attack_speed, 0.35)


func test_bow_attack_speed_from_data() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"bow")
	assert_eq(def.attack_speed, 0.6)


# --- Tool power for mining ---------------------------------------

func test_pickaxe_power_from_data() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"pickaxe")
	assert_eq(def.power, 2)


# --- Knockback field on weapon -----------------------------------

func test_sword_knockback_field() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"sword")
	assert_eq(def.knockback, 0.0, "sword has zero knockback by default")


func test_custom_knockback_weapon() -> void:
	var raw: Dictionary = _backup.duplicate(true)
	raw["test_hammer"] = {
		"display_name": "War Hammer",
		"icon_idx": 1,
		"slot": "weapon",
		"power": 5,
		"hands": 1,
		"attack_type": "melee",
		"attack_speed": 0.5,
		"reach": 20,
		"knockback": 12,
		"weapon_category": "axe",
	}
	ItemRegistry.save_data(raw)
	ItemRegistry.reset()
	var def: ItemDefinition = ItemRegistry.get_item(&"test_hammer")
	assert_eq(def.knockback, 12.0)


# --- Armor defense includes defense stat -------------------------

func test_armor_defense_includes_defense_stat() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	# No armor, no defense stat → 0
	assert_eq(player._armor_defense(), 0)
	# Add defense stat
	player.stats[&"defense"] = 3
	assert_eq(player._armor_defense(), 3, "defense stat alone = 3")
	# Equip armor
	player.equipment.equip(ItemDefinition.Slot.BODY, &"armor")
	assert_eq(player._armor_defense(), 6, "3 armor power + 3 defense stat")


# --- ActionParticles element tinting exists ----------------------

func test_element_param_accepted() -> void:
	# Just verify the function signature accepts element param without error.
	# We create a Node as parent to catch the particle.
	var parent := Node2D.new()
	add_child_autofree(parent)
	var p: CPUParticles2D = ActionParticles.spawn_impact(
		parent, Vector2.ZERO, ActionParticles.Action.MELEE, &"",
		ItemDefinition.Element.FIRE)
	assert_not_null(p, "particle created with element param")
	assert_almost_eq(p.color.r, 1.0, 0.01, "fire tint red channel")


func test_no_element_keeps_default_color() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var p: CPUParticles2D = ActionParticles.spawn_impact(
		parent, Vector2.ZERO, ActionParticles.Action.MELEE)
	assert_not_null(p)
	# Default melee slash color: (1, 1, 1, 0.9)
	assert_almost_eq(p.color.r, 1.0, 0.01)
	assert_almost_eq(p.color.g, 1.0, 0.01)


# --- ActionVFX.play_attack dispatch exists -----------------------

func test_play_attack_method_exists() -> void:
	var vfx := ActionVFX.new()
	add_child_autofree(vfx)
	assert_true(vfx.has_method("play_attack"))


func test_play_attack_accepts_category_and_element() -> void:
	# Verify the function signature works (no crash). VFX won't actually
	# show without a player/world, but we can check it doesn't error.
	var vfx := ActionVFX.new()
	add_child_autofree(vfx)
	# Without a player, play_attack should gracefully handle nil.
	# It checks _is_playing first, which is false, then tries to create
	# sprites which will be null, so it should just finish.
	vfx.play_attack(Vector2i.ZERO, ItemDefinition.WeaponCategory.SWORD,
		ItemDefinition.Element.FIRE, 0.35)
	# No crash = pass
	pass_test("play_attack accepted parameters without crash")
