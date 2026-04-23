extends GutTest

# --- StatusEffectRegistry tests ---

func before_each() -> void:
	StatusEffectRegistry.reset()


func test_all_ids_returns_four_effects() -> void:
	var ids: Array = StatusEffectRegistry.all_ids()
	assert_eq(ids.size(), 4, "Should have 4 default effects")


func test_has_effect_burn() -> void:
	assert_true(StatusEffectRegistry.has_effect(&"burn"))


func test_has_effect_freeze() -> void:
	assert_true(StatusEffectRegistry.has_effect(&"freeze"))


func test_has_effect_shock() -> void:
	assert_true(StatusEffectRegistry.has_effect(&"shock"))


func test_has_effect_poison() -> void:
	assert_true(StatusEffectRegistry.has_effect(&"poison"))


func test_get_effect_burn_fields() -> void:
	var e: StatusEffect = StatusEffectRegistry.get_effect(&"burn")
	assert_not_null(e)
	assert_eq(e.display_name, "Burn")
	assert_eq(e.element, 1)  # FIRE
	assert_eq(e.duration_sec, 3.0)
	assert_eq(e.tick_interval, 1.0)
	assert_eq(e.damage_per_tick, 1)
	assert_eq(e.speed_multiplier, 1.0)
	assert_false(e.stun)


func test_get_effect_freeze_fields() -> void:
	var e: StatusEffect = StatusEffectRegistry.get_effect(&"freeze")
	assert_not_null(e)
	assert_eq(e.speed_multiplier, 0.5)
	assert_false(e.stun)


func test_get_effect_shock_stun() -> void:
	var e: StatusEffect = StatusEffectRegistry.get_effect(&"shock")
	assert_not_null(e)
	assert_true(e.stun)


func test_get_effect_for_element_fire() -> void:
	var e: StatusEffect = StatusEffectRegistry.get_effect_for_element(1)
	assert_not_null(e)
	assert_eq(e.id, &"burn")


func test_get_effect_for_element_none_returns_null() -> void:
	var e: StatusEffect = StatusEffectRegistry.get_effect_for_element(0)
	assert_null(e)


func test_get_effect_for_element_invalid_returns_null() -> void:
	var e: StatusEffect = StatusEffectRegistry.get_effect_for_element(99)
	assert_null(e)


func test_get_raw_data_roundtrip() -> void:
	var raw: Dictionary = StatusEffectRegistry.get_raw_data()
	assert_eq(raw.size(), 4)
	assert_true(raw.has("burn"))
	assert_eq(raw["burn"]["damage_per_tick"], 1)


func test_save_data_persists() -> void:
	var raw: Dictionary = StatusEffectRegistry.get_raw_data()
	raw["test_effect"] = {
		"display_name": "Test",
		"element": 0,
		"duration_sec": 1.0,
		"tick_interval": 0.0,
		"damage_per_tick": 0,
		"speed_multiplier": 1.0,
		"stun": false,
	}
	StatusEffectRegistry.save_data(raw)
	assert_eq(StatusEffectRegistry.all_ids().size(), 5)
	# Restore original.
	raw.erase("test_effect")
	StatusEffectRegistry.save_data(raw)
	assert_eq(StatusEffectRegistry.all_ids().size(), 4)


# --- PlayerController status effect integration tests ---

func test_player_apply_status() -> void:
	var p := PlayerController.new()
	p.apply_status(&"burn")
	assert_true(p.has_status(&"burn"))
	assert_eq(p.active_effects.size(), 1)
	p.free()


func test_player_apply_status_resets_duration() -> void:
	var p := PlayerController.new()
	p.apply_status(&"burn")
	p.active_effects[0]["remaining"] = 0.5
	p.apply_status(&"burn")
	# Duration should reset to full (3.0)
	assert_almost_eq(p.active_effects[0]["remaining"], 3.0, 0.01)
	p.free()


func test_player_remove_status() -> void:
	var p := PlayerController.new()
	p.apply_status(&"burn")
	p.remove_status(&"burn")
	assert_false(p.has_status(&"burn"))
	assert_eq(p.active_effects.size(), 0)
	p.free()


func test_player_clear_effects() -> void:
	var p := PlayerController.new()
	p.apply_status(&"burn")
	p.apply_status(&"poison")
	p.clear_effects()
	assert_eq(p.active_effects.size(), 0)
	p.free()


func test_player_is_stunned_with_shock() -> void:
	var p := PlayerController.new()
	p.apply_status(&"shock")
	assert_true(p.is_stunned())
	p.free()


func test_player_is_stunned_without_shock() -> void:
	var p := PlayerController.new()
	p.apply_status(&"burn")
	assert_false(p.is_stunned())
	p.free()


func test_player_speed_multiplier_freeze() -> void:
	var p := PlayerController.new()
	p.apply_status(&"freeze")
	assert_almost_eq(p.get_status_speed_multiplier(), 0.5, 0.01)
	p.free()


func test_player_speed_multiplier_no_effects() -> void:
	var p := PlayerController.new()
	assert_almost_eq(p.get_status_speed_multiplier(), 1.0, 0.01)
	p.free()


func test_player_tick_effects_burn_damage() -> void:
	var p := PlayerController.new()
	p.health = 10
	p.max_health = 10
	p.apply_status(&"burn")
	# Tick 1.0s — should trigger 1 tick of burn damage (1 dmg)
	p.tick_effects(1.0)
	assert_eq(p.health, 9)
	p.free()


func test_player_tick_effects_expire() -> void:
	var p := PlayerController.new()
	p.apply_status(&"burn")  # 3.0s duration
	p.tick_effects(3.1)
	assert_eq(p.active_effects.size(), 0)
	p.free()


func test_player_take_hit_with_element_applies_status() -> void:
	var p := PlayerController.new()
	p.health = 10
	p.max_health = 10
	p.take_hit(1, null, 1)  # element=FIRE
	assert_true(p.has_status(&"burn"))
	p.free()


func test_player_take_hit_no_element_no_status() -> void:
	var p := PlayerController.new()
	p.health = 10
	p.max_health = 10
	p.take_hit(1, null, 0)
	assert_eq(p.active_effects.size(), 0)
	p.free()
