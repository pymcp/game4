## Structural smoke tests for `tile_mappings.tres`: the on-disk resource
## must load, contain the expected dictionary keys, and agree with the
## TilesetCatalog facade on a few known cells. The .tres is the source of
## truth (edited via Game Editor), so we do NOT compare against the
## hardcoded `default_mappings()` seed — intentional drift is expected.
extends GutTest

const _RES_PATH := "res://resources/tilesets/tile_mappings.tres"

## Expected top-level terrain keys that must always be present.
const _EXPECTED_OW_KEYS: Array[StringName] = [
	&"grass", &"water", &"sand", &"stone", &"snow", &"dirt", &"deep_water",
]
const _EXPECTED_DECO_KEYS: Array[StringName] = [
	&"tree", &"bush", &"rock",
]


func test_tres_loads_and_has_expected_keys() -> void:
	var loaded: TileMappings = load(_RES_PATH) as TileMappings
	assert_not_null(loaded, "tile_mappings.tres should load")

	for k in _EXPECTED_OW_KEYS:
		assert_true(loaded.overworld_terrain.has(k),
			"overworld_terrain missing key %s" % k)
		var arr: Variant = loaded.overworld_terrain[k]
		assert_true(arr is Array, "overworld_terrain[%s] should be Array" % k)
		assert_true((arr as Array).size() > 0,
			"overworld_terrain[%s] should be non-empty" % k)

	for k in _EXPECTED_DECO_KEYS:
		assert_true(loaded.overworld_decoration.has(k),
			"overworld_decoration missing key %s" % k)

	assert_true(loaded.dungeon_terrain.size() > 0, "dungeon_terrain non-empty")
	assert_true(loaded.city_terrain.size() > 0, "city_terrain non-empty")
	assert_true(loaded.interior_terrain.size() > 0, "interior_terrain non-empty")
	assert_true(loaded.dungeon_wall_autotile.size() > 0, "autotile non-empty")


# Catalog still owns its constants; verify they agree with the resource
# so any drift between Game Editor edits and the renderer is caught.
# (When the catalog is migrated to read from TileMappings, this becomes
# trivially true.)
func test_catalog_constants_match_resource() -> void:
	var loaded: TileMappings = load(_RES_PATH) as TileMappings
	# Element [0] is the canonical cell on both sides.
	assert_eq(TilesetCatalog.OVERWORLD_TERRAIN_CELLS[&"grass"][0], loaded.overworld_terrain[&"grass"][0])
	assert_eq(TilesetCatalog.OVERWORLD_TERRAIN_CELLS[&"water"][0], loaded.overworld_terrain[&"water"][0])


# Smoke: Game Editor dev tool scene loads without parse / instantiation
# errors. Doesn't touch the editor — just instances and frees.
func test_game_editor_scene_loads() -> void:
	var scn: PackedScene = load("res://scenes/tools/GameEditor.tscn") as PackedScene
	assert_not_null(scn, "GameEditor.tscn should load")
	var inst: Node = scn.instantiate()
	assert_not_null(inst, "GameEditor should instantiate")
	add_child_autofree(inst)
	# Let one frame tick so _ready runs.
	await get_tree().process_frame
