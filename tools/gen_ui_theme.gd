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
	DirAccess.make_dir_recursive_absolute("res://resources/ui")
	var err: int = ResourceSaver.save(t, "res://resources/ui/game_theme.tres")
	if err == OK:
		print("[gen_ui_theme] Saved to res://resources/ui/game_theme.tres")
	else:
		push_error("[gen_ui_theme] Save failed: %d" % err)
	quit()
