extends GutTest

var _game: Node = null
const _GameScene: PackedScene = preload("res://scenes/main/Game.tscn")


func before_each() -> void:
	WorldManager.reset(20260425)
	MapManager.reset()
	ViewManager.reset()
	EncounterTableRegistry.reset()
	ChestLootRegistry.reset()
	_game = _GameScene.instantiate()
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	MapManager.reset()
	ViewManager.reset()


func test_labyrinth_entrance_enter_and_floor1() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(20, 20)
	var mid: StringName = MapManager.make_id(rid, cell, 1, &"labyrinth")
	var m: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 1, 64, &"labyrinth")
	assert_not_null(m)
	assert_eq(m.floor_num, 1)
	assert_true(m.width >= 16 and m.width <= 96)
	assert_eq(MapManager._kind_from_id(m.map_id), &"labyrinth")


func test_labyrinth_descent_preserves_kind() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(30, 30)
	var mid: StringName = MapManager.make_id(rid, cell, 1, &"labyrinth")
	var floor1: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 1, 64, &"labyrinth")
	var floor2: InteriorMap = MapManager.descend_from(floor1, 64)
	assert_eq(floor2.floor_num, 2)
	assert_eq(MapManager._kind_from_id(floor2.map_id), &"labyrinth")
	var floor3: InteriorMap = MapManager.descend_from(floor2, 64)
	assert_eq(floor3.floor_num, 3)
	assert_eq(MapManager._kind_from_id(floor3.map_id), &"labyrinth")


func test_labyrinth_has_chest_scatter() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(40, 20)
	var mid: StringName = MapManager.make_id(rid, cell, 1, &"labyrinth")
	var m: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 1, 64, &"labyrinth")
	assert_true(m.chest_scatter.size() >= 1, "Floor 1 labyrinth should have chest(s)")


func test_boss_floor_has_boss_data() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(50, 20)
	# boss_interval == 2, so floor 2 is the first boss floor (2 % 2 == 0).
	var mid: StringName = MapManager.make_id(rid, cell, 2, &"labyrinth")
	var m: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 2, 64, &"labyrinth")
	assert_false(m.boss_data.is_empty(), "Floor 2 labyrinth should have boss_data")
	assert_true(m.boss_room_cells.size() >= 4, "Boss room should have cells")


func test_non_boss_floor_has_no_boss() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(60, 20)
	var mid: StringName = MapManager.make_id(rid, cell, 1, &"labyrinth")
	var m: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 1, 64, &"labyrinth")
	assert_true(m.boss_data.is_empty(), "Floor 1 should have no boss")


func test_labyrinth_map_is_connected() -> void:
	var rid := Vector2i(0, 0)
	var cell := Vector2i(70, 20)
	var mid: StringName = MapManager.make_id(rid, cell, 1, &"labyrinth")
	var m: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 1, 64, &"labyrinth")
	var visited: Dictionary = {}
	var queue: Array = [m.entry_cell]
	visited[m.entry_cell] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var nb: Vector2i = cur + d
			if not visited.has(nb) and m.at(nb) != TerrainCodes.INTERIOR_WALL:
				visited[nb] = true
				queue.append(nb)
	assert_true(visited.has(m.exit_cell), "Exit must be reachable from entry via floor tiles")
