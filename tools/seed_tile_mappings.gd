## One-shot seeding script. Run with:
##   godot --headless -s tools/seed_tile_mappings.gd
## Writes res://resources/tilesets/tile_mappings.tres from
## TileMappings.default_mappings().
extends SceneTree


func _init() -> void:
	var m: TileMappings = TileMappings.default_mappings()
	var path := "res://resources/tilesets/tile_mappings.tres"
	var err := ResourceSaver.save(m, path)
	if err == OK:
		print("seeded: ", path)
	else:
		printerr("save failed: ", err)
	quit()
