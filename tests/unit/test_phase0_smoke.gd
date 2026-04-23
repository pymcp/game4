## Smoke test: confirms autoloads exist and InputContext basic API works.
extends GutTest


func test_input_context_exists() -> void:
	assert_not_null(InputContext, "InputContext autoload should exist")


func test_pause_manager_exists() -> void:
	assert_not_null(PauseManager, "PauseManager autoload should exist")


func test_world_manager_exists() -> void:
	assert_not_null(WorldManager, "WorldManager autoload should exist")


func test_default_p1_context_is_gameplay() -> void:
	assert_eq(InputContext.get_context(0), InputContext.Context.GAMEPLAY)


func test_set_context_emits_signal() -> void:
	InputContext.set_context(0, InputContext.Context.GAMEPLAY)  # ensure baseline
	watch_signals(InputContext)
	InputContext.set_context(0, InputContext.Context.INVENTORY)
	assert_signal_emitted(InputContext, "context_changed")
	# restore
	InputContext.set_context(0, InputContext.Context.GAMEPLAY)


func test_p1_attack_label_is_R() -> void:
	assert_eq(InputContext.get_key_label(&"p1_attack"), "R")


func test_p2_attack_label_is_kp_add() -> void:
	assert_eq(InputContext.get_key_label(&"p2_attack"), "Kp Add")


func test_pause_manager_toggles() -> void:
	PauseManager.set_paused(false)  # baseline
	PauseManager.toggle_pause()
	assert_true(PauseManager.is_paused())
	PauseManager.toggle_pause()
	assert_false(PauseManager.is_paused())
