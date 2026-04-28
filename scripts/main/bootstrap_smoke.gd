## BootstrapSmoke - Phase 0 verification scene.
## Confirms autoloads load, prints to stdout, and quits.
extends Node


func _ready() -> void:
	print("[bootstrap] InputContext present: ", InputContext != null)
	print("[bootstrap] PauseManager present: ", PauseManager != null)
	print("[bootstrap] WorldManager present: ", WorldManager != null)
	print("[bootstrap] GameSession present: ", GameSession != null)
	print("[bootstrap] P1 GAMEPLAY actions: ", InputContext.get_active_actions(0))
	print("[bootstrap] Sample key label for p1_attack: ", InputContext.get_key_label(PlayerActions.action(0, PlayerActions.ATTACK)))
	print("[bootstrap] Sample key label for p2_attack: ", InputContext.get_key_label(PlayerActions.action(1, PlayerActions.ATTACK)))
	for action in [
			PlayerActions.action(1, PlayerActions.UP),
			PlayerActions.action(1, PlayerActions.DOWN),
			PlayerActions.action(1, PlayerActions.LEFT),
			PlayerActions.action(1, PlayerActions.RIGHT),
			PlayerActions.action(1, PlayerActions.INTERACT),
			PlayerActions.action(1, PlayerActions.INVENTORY),
			PlayerActions.action(1, PlayerActions.ATTACK),
			PlayerActions.action(1, PlayerActions.AUTO_MINE),
			PlayerActions.action(1, PlayerActions.AUTO_ATTACK),
			PlayerActions.action(1, PlayerActions.TAB_PREV),
			PlayerActions.action(1, PlayerActions.TAB_NEXT),
			&"pause"]:
		print("[bootstrap] %s -> %s" % [action, InputContext.get_key_label(action)])
	print("[bootstrap] OK")
	# In headless boot tests, quit immediately. In editor/run, wait a tick.
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
