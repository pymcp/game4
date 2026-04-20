## Phase 9a: SaveGame persists interior state (visited dungeons) and
## restores the active interior on load.
extends GutTest

const TEST_SLOT: String = "phase9a_test"


func before_each() -> void:
	WorldManager.reset(0xCAFE)
	MapManager.reset()
	var p: String = SaveGame.slot_path(TEST_SLOT)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func after_each() -> void:
	MapManager.reset()


func test_snapshot_captures_interiors() -> void:
	var rid := Vector2i(2, 3)
	var cell := Vector2i(7, 9)
	var map_id: StringName = MapManager.make_id(rid, cell, 1)
	MapManager.get_or_generate(map_id, rid, cell, 1)
	var snap: SaveGame = SaveGame.snapshot(null)
	assert_eq(snap.interiors.size(), 1)
	assert_eq(snap.active_interior_id, &"")


func test_snapshot_records_active_interior_id() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(5, 5)
	var map_id: StringName = MapManager.make_id(rid, cell, 1)
	MapManager.set_active(map_id, rid, cell, 1)
	var snap: SaveGame = SaveGame.snapshot(null)
	assert_eq(snap.active_interior_id, map_id)


func test_apply_restores_interior_cache() -> void:
	var rid := Vector2i(1, 1)
	var cell := Vector2i(3, 4)
	var map_id: StringName = MapManager.make_id(rid, cell, 1)
	var original: InteriorMap = MapManager.get_or_generate(map_id, rid, cell, 1)
	var original_entry: Vector2i = original.entry_cell
	var snap: SaveGame = SaveGame.snapshot(null)
	# Mutate state.
	MapManager.reset()
	assert_eq(MapManager.interiors.size(), 0)
	# Apply (no world).
	snap.apply(null)
	assert_true(MapManager.interiors.has(map_id))
	var restored: InteriorMap = MapManager.interiors[map_id]
	assert_eq(restored.entry_cell, original_entry)


func test_apply_restores_active_interior() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(8, 8)
	var map_id: StringName = MapManager.make_id(rid, cell, 1)
	MapManager.set_active(map_id, rid, cell, 1)
	var snap: SaveGame = SaveGame.snapshot(null)
	# Wipe and re-apply.
	MapManager.reset()
	snap.apply(null)
	assert_not_null(MapManager.active_interior)
	assert_eq(MapManager.active_interior.map_id, map_id)


func test_roundtrip_to_disk_preserves_interiors() -> void:
	var rid := Vector2i(2, -1)
	var cell := Vector2i(6, 12)
	var map_id: StringName = MapManager.make_id(rid, cell, 1)
	MapManager.get_or_generate(map_id, rid, cell, 1)
	var err: int = SaveGame.save_to_slot(null, TEST_SLOT)
	assert_eq(err, OK)
	MapManager.reset()
	var loaded: SaveGame = SaveGame.load_from_slot(TEST_SLOT, null)
	assert_not_null(loaded)
	assert_true(MapManager.interiors.has(map_id))


func test_version_bumped() -> void:
	assert_eq(SaveGame.VERSION, 2)
