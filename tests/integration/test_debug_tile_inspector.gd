extends GutTest
## Integration tests for get_tile_info_at_cell() on WorldRoot.
## Uses the full Game scene so WorldRoot has a live region painted.

const _GameScene := preload("res://scenes/main/Game.tscn")
var _game: Game = null


func before_each() -> void:
	WorldManager.reset(99999)
	GameState.clear_flags()
	_game = _GameScene.instantiate()
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	if PauseManager.is_paused():
		PauseManager.set_paused(false)
	GameState.clear_flags()
	_game = null


func _get_world_root() -> Node:
	var world: Node = get_tree().root.find_child("World", true, false)
	if world == null:
		return null
	return world.get_player_world(0)


# ─── Tests ───────────────────────────────────────────────────────────────────

func test_get_tile_info_returns_required_top_level_keys() -> void:
	var wr: Node = _get_world_root()
	if wr == null:
		pending("WorldRoot not available")
		return
	var info: Dictionary = wr.get_tile_info_at_cell(Vector2i(2, 2))
	assert_has(info, "cell",               "must have 'cell'")
	assert_has(info, "region_tile_index",  "must have 'region_tile_index'")
	assert_has(info, "biome",              "must have 'biome'")
	assert_has(info, "layers",             "must have 'layers'")


func test_get_tile_info_cell_matches_input() -> void:
	var wr: Node = _get_world_root()
	if wr == null:
		pending("WorldRoot not available")
		return
	var cell := Vector2i(5, 7)
	var info: Dictionary = wr.get_tile_info_at_cell(cell)
	assert_eq(info["cell"], cell, "returned cell should equal the input")


func test_get_tile_info_layers_is_array() -> void:
	var wr: Node = _get_world_root()
	if wr == null:
		pending("WorldRoot not available")
		return
	var info: Dictionary = wr.get_tile_info_at_cell(Vector2i(0, 0))
	assert_true(info["layers"] is Array, "layers should be an Array")


func test_layer_dict_has_required_keys() -> void:
	var wr: Node = _get_world_root()
	if wr == null:
		pending("WorldRoot not available")
		return
	var info: Dictionary = wr.get_tile_info_at_cell(Vector2i(0, 0))
	if info["layers"].is_empty():
		pending("No painted tiles at (0,0) — can't validate layer keys")
		return
	for layer_data: Dictionary in info["layers"]:
		assert_has(layer_data, "layer",       "layer dict missing 'layer'")
		assert_has(layer_data, "atlas",       "layer dict missing 'atlas'")
		assert_has(layer_data, "sheet_field", "layer dict missing 'sheet_field'")
		assert_has(layer_data, "sheet_path",  "layer dict missing 'sheet_path'")
		assert_has(layer_data, "mineable",    "layer dict missing 'mineable'")
