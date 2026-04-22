extends GutTest


# ─── MineableRegistry tile-size / walkable-mask API ───────────────────

func test_tree_is_1x2() -> void:
	var sz: Vector2i = MineableRegistry.get_tile_size(&"tree")
	assert_eq(sz, Vector2i(1, 2), "tree should be 1 wide, 2 tall")

func test_tree_walkable_mask() -> void:
	var mask: Array = MineableRegistry.get_walkable_mask(&"tree")
	assert_eq(mask.size(), 2, "tree mask should have 2 entries")
	assert_false(mask[0], "tree top (canopy) should not block")
	assert_true(mask[1], "tree bottom (trunk) should block")

func test_rock_is_1x1() -> void:
	var sz: Vector2i = MineableRegistry.get_tile_size(&"rock")
	assert_eq(sz, Vector2i(1, 1), "rock should be 1x1")

func test_rock_walkable_mask() -> void:
	var mask: Array = MineableRegistry.get_walkable_mask(&"rock")
	assert_eq(mask.size(), 1)
	assert_true(mask[0], "rock should block")

func test_unknown_resource_defaults() -> void:
	var sz: Vector2i = MineableRegistry.get_tile_size(&"nonexistent_xyz")
	assert_eq(sz, Vector2i(1, 1))
	var mask: Array = MineableRegistry.get_walkable_mask(&"nonexistent_xyz")
	assert_eq(mask, [true])

func test_is_multi_tile() -> void:
	assert_true(MineableRegistry.is_multi_tile(&"tree"))
	assert_false(MineableRegistry.is_multi_tile(&"rock"))
	assert_false(MineableRegistry.is_multi_tile(&"bush"))

func test_all_resources_have_consistent_mask_size() -> void:
	for rid in MineableRegistry.all_ids():
		var sz: Vector2i = MineableRegistry.get_tile_size(rid)
		var mask: Array = MineableRegistry.get_walkable_mask(rid)
		assert_eq(mask.size(), sz.x * sz.y,
			"%s: mask size %d != %d×%d" % [rid, mask.size(), sz.x, sz.y])


# ─── TilesetCatalog decoration size/mask cache ───────────────────────

func test_catalog_decoration_size_tree() -> void:
	var sz: Vector2i = TilesetCatalog.get_decoration_size(&"tree")
	assert_eq(sz, Vector2i(1, 2))

func test_catalog_decoration_mask_tree() -> void:
	var mask: Array = TilesetCatalog.get_decoration_walkable_mask(&"tree")
	assert_eq(mask.size(), 2)
	assert_false(mask[0])
	assert_true(mask[1])

func test_catalog_decoration_size_rock() -> void:
	var sz: Vector2i = TilesetCatalog.get_decoration_size(&"rock")
	assert_eq(sz, Vector2i(1, 1))

func test_catalog_unknown_decoration_defaults() -> void:
	var sz: Vector2i = TilesetCatalog.get_decoration_size(&"no_such_deco")
	assert_eq(sz, Vector2i(1, 1))
	var mask: Array = TilesetCatalog.get_decoration_walkable_mask(&"no_such_deco")
	assert_eq(mask, [true])

func test_catalog_invalidate_deco_cache() -> void:
	# First call populates cache.
	TilesetCatalog.get_decoration_size(&"tree")
	# Invalidate.
	TilesetCatalog.invalidate_deco_cache()
	# Should still work after invalidation (lazy rebuild).
	var sz: Vector2i = TilesetCatalog.get_decoration_size(&"tree")
	assert_eq(sz, Vector2i(1, 2))
