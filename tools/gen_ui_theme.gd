## gen_ui_theme.gd
##
## @tool script: run once (or after changing UITheme) to write
## resources/ui/game_theme.tres.
##
## Run from a headless command:
##   godot --headless -s tools/gen_ui_theme.gd
@tool
extends SceneTree

func _initialize() -> void:
	print("[gen_ui_theme] Building theme...")
	var t: Theme = UITheme.build()
	var dir_err: int = DirAccess.make_dir_recursive_absolute("res://resources/ui")
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("[gen_ui_theme] Could not create output dir: %d" % dir_err)
		quit(1)
		return
	var err: int = ResourceSaver.save(t, "res://resources/ui/game_theme.tres")
	if err == OK:
		print("[gen_ui_theme] Saved to res://resources/ui/game_theme.tres")
		quit(0)
	else:
		push_error("[gen_ui_theme] Save failed: %d" % err)
		quit(1)
