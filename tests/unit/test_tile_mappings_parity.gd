## Parity test: the on-disk `tile_mappings.tres` must produce identical
## values to `TileMappings.default_mappings()` so that the SpritePicker
## dev tool's edit cycle (load → save) cannot silently drift the historical
## constants. Also smoke-tests that TilesetCatalog still surfaces a few
## known cells, proving the facade reads from the resource correctly.
extends GutTest

const _RES_PATH := "res://resources/tilesets/tile_mappings.tres"


func _assert_dict_equal(a: Dictionary, b: Dictionary, label: String) -> void:
	assert_eq(a.size(), b.size(), "%s: size mismatch" % label)
	for k in a.keys():
		assert_true(b.has(k), "%s: missing key %s" % [label, str(k)])
		assert_eq(a[k], b[k], "%s[%s]" % [label, str(k)])


func test_tres_matches_defaults() -> void:
	var loaded: TileMappings = load(_RES_PATH) as TileMappings
	assert_not_null(loaded, "tile_mappings.tres should load")
	var defaults: TileMappings = TileMappings.default_mappings()

	_assert_dict_equal(loaded.overworld_terrain, defaults.overworld_terrain, "overworld_terrain")
	_assert_dict_equal(loaded.overworld_decoration, defaults.overworld_decoration, "overworld_decoration")
	_assert_dict_equal(loaded.overworld_terrain_patches_3x3, defaults.overworld_terrain_patches_3x3, "patches_3x3")
	assert_eq(loaded.overworld_water_border_grass_3x3, defaults.overworld_water_border_grass_3x3, "water_border_grass_3x3")
	_assert_dict_equal(loaded.overworld_water_outer_corners, defaults.overworld_water_outer_corners, "water_outer_corners")
	_assert_dict_equal(loaded.city_terrain, defaults.city_terrain, "city_terrain")
	_assert_dict_equal(loaded.dungeon_terrain, defaults.dungeon_terrain, "dungeon_terrain")
	assert_eq(loaded.dungeon_floor_decor, defaults.dungeon_floor_decor, "dungeon_floor_decor")
	assert_eq(loaded.dungeon_entrance_pair, defaults.dungeon_entrance_pair, "dungeon_entrance_pair")
	_assert_dict_equal(loaded.dungeon_doorframe, defaults.dungeon_doorframe, "dungeon_doorframe")
	_assert_dict_equal(loaded.interior_terrain, defaults.interior_terrain, "interior_terrain")

	# Autotile is stored as flat Array[Dictionary]; compare via rebuilt dict
	# so ordering differences (irrelevant at runtime) don't fail the test.
	var loaded_at: Dictionary = loaded.build_dungeon_wall_autotile_dict()
	var default_at: Dictionary = defaults.build_dungeon_wall_autotile_dict()
	assert_eq(loaded_at.size(), default_at.size(), "autotile dict size")
	for mask in default_at.keys():
		assert_true(loaded_at.has(mask), "autotile mask %d missing" % mask)
		assert_eq(loaded_at[mask], default_at[mask], "autotile mask %d" % mask)


# Catalog still owns its constants; verify they agree with the resource
# so any drift between SpritePicker edits and the renderer is caught.
# (When the catalog is migrated to read from TileMappings, this becomes
# trivially true.)
func test_catalog_constants_match_resource() -> void:
	var loaded: TileMappings = load(_RES_PATH) as TileMappings
	# Element [0] is the canonical cell on both sides.
	assert_eq(TilesetCatalog.OVERWORLD_TERRAIN_CELLS[&"grass"][0], loaded.overworld_terrain[&"grass"][0])
	assert_eq(TilesetCatalog.OVERWORLD_TERRAIN_CELLS[&"water"][0], loaded.overworld_terrain[&"water"][0])


# Smoke: SpritePicker dev tool scene loads without parse / instantiation
# errors. Doesn't touch the editor — just instances and frees.
func test_sprite_picker_scene_loads() -> void:
	var scn: PackedScene = load("res://scenes/tools/SpritePicker.tscn") as PackedScene
	assert_not_null(scn, "SpritePicker.tscn should load")
	var inst: Node = scn.instantiate()
	assert_not_null(inst, "SpritePicker should instantiate")
	add_child_autofree(inst)
	# Let one frame tick so _ready runs.
	await get_tree().process_frame
