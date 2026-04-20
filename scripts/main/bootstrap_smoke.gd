## BootstrapSmoke - Phase 0 verification scene.
## Confirms autoloads load, prints to stdout, and quits.
extends Node


func _ready() -> void:
	print("[bootstrap] InputContext present: ", InputContext != null)
	print("[bootstrap] PauseManager present: ", PauseManager != null)
	print("[bootstrap] WorldManager present: ", WorldManager != null)
	print("[bootstrap] GameSession present: ", GameSession != null)
	print("[bootstrap] P1 GAMEPLAY actions: ", InputContext.get_active_actions(0))
	print("[bootstrap] Sample key label for p1_attack: ", InputContext.get_key_label(&"p1_attack"))
	print("[bootstrap] Sample key label for p2_attack: ", InputContext.get_key_label(&"p2_attack"))
	for action in [&"p2_up", &"p2_down", &"p2_left", &"p2_right", &"p2_interact",
			&"p2_inventory", &"p2_attack", &"p2_auto_mine", &"p2_auto_attack",
			&"p2_tab_prev", &"p2_tab_next", &"pause"]:
		print("[bootstrap] %s -> %s" % [action, InputContext.get_key_label(action)])
	print("[bootstrap] OK")
	# In headless boot tests, quit immediately. In editor/run, wait a tick.
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
