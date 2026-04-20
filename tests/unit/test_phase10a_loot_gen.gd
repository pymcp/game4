## Phase 10a: DungeonGenerator scatters loot in non-entry rooms.
extends GutTest


func _gen() -> InteriorMap:
	return DungeonGenerator.generate(0xC0FFEE, 32, 32)


func test_loot_scatter_non_empty_for_seeded_dungeon() -> void:
	# Seed picked so the table guarantees at least one drop in 32x32.
	var m: InteriorMap = _gen()
	assert_gt(m.loot_scatter.size(), 0)


func test_loot_entries_have_required_keys() -> void:
	var m: InteriorMap = _gen()
	if m.loot_scatter.is_empty():
		pass_test("no loot")
		return
	var e: Dictionary = m.loot_scatter[0]
	assert_true(e.has("item_id"))
	assert_true(e.has("count"))
	assert_true(e.has("cell"))


func test_loot_cells_are_floor_tiles() -> void:
	var m: InteriorMap = _gen()
	for e in m.loot_scatter:
		assert_eq(m.at(e["cell"]), TerrainCodes.INTERIOR_FLOOR)


func test_loot_does_not_overlap_npcs() -> void:
	var m: InteriorMap = _gen()
	var npc_cells := {}
	for n in m.npcs_scatter:
		npc_cells[n["cell"]] = true
	for l in m.loot_scatter:
		assert_false(npc_cells.has(l["cell"]),
			"loot at %s collides with an NPC" % str(l["cell"]))


func test_loot_item_ids_are_known() -> void:
	var m: InteriorMap = _gen()
	for l in m.loot_scatter:
		assert_true(ItemRegistry.has_item(l["item_id"]),
			"unknown item id %s" % str(l["item_id"]))


func test_loot_counts_positive() -> void:
	var m: InteriorMap = _gen()
	for l in m.loot_scatter:
		assert_gt(int(l["count"]), 0)


func test_loot_deterministic_per_seed() -> void:
	var a: InteriorMap = DungeonGenerator.generate(42, 32, 32)
	var b: InteriorMap = DungeonGenerator.generate(42, 32, 32)
	assert_eq(a.loot_scatter.size(), b.loot_scatter.size())
	for i in a.loot_scatter.size():
		assert_eq(a.loot_scatter[i]["item_id"], b.loot_scatter[i]["item_id"])
		assert_eq(a.loot_scatter[i]["cell"], b.loot_scatter[i]["cell"])
