## Phase 9c: HUD shows a "DUNGEON" badge while the active interior is set.
extends GutTest


func before_each() -> void:
	MapManager.reset()


func after_each() -> void:
	MapManager.reset()


func _make_hud() -> PlayerHUD:
	var hud := PlayerHUD.new()
	hud.size = Vector2(800, 600)
	add_child_autofree(hud)
	return hud


func test_badge_hidden_on_overworld() -> void:
	var hud: PlayerHUD = _make_hud()
	await get_tree().process_frame
	var label: Label = hud.get_interior_label()
	assert_not_null(label)
	assert_false(label.visible, "badge should be hidden on overworld")


func test_badge_visible_when_interior_active() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(4, 4)
	var map_id: StringName = MapManager.make_id(rid, cell, 1)
	MapManager.set_active(map_id, rid, cell, 1)
	var hud: PlayerHUD = _make_hud()
	await get_tree().process_frame
	assert_true(hud.get_interior_label().visible)


func test_badge_toggles_on_signal() -> void:
	var hud: PlayerHUD = _make_hud()
	await get_tree().process_frame
	var label: Label = hud.get_interior_label()
	assert_false(label.visible)
	# Enter.
	var rid := Vector2i(1, 0)
	var cell := Vector2i(6, 6)
	var map_id: StringName = MapManager.make_id(rid, cell, 1)
	MapManager.set_active(map_id, rid, cell, 1)
	assert_true(label.visible)
	# Exit.
	MapManager.exit_to_overworld()
	assert_false(label.visible)
