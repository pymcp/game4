## Tests for WeaponAtlas, ActionParticles, and Equipment→weapon sprite wiring.
extends GutTest


# --- WeaponAtlas ---------------------------------------------------

func test_sword_returns_valid_cell() -> void:
	var cell: Vector2i = WeaponAtlas.cell_for(&"sword")
	assert_ne(cell, Vector2i(-1, -1), "sword should have a weapon cell")
	assert_true(cell.x >= 42 and cell.x <= 53, "sword col should be in weapon range")


func test_pickaxe_returns_valid_cell() -> void:
	var cell: Vector2i = WeaponAtlas.cell_for(&"pickaxe")
	assert_ne(cell, Vector2i(-1, -1), "pickaxe should have a weapon cell")


func test_bow_returns_valid_cell() -> void:
	var cell: Vector2i = WeaponAtlas.cell_for(&"bow")
	assert_ne(cell, Vector2i(-1, -1), "bow should have a weapon cell")
	assert_eq(cell.x, 52, "bow should be at column 52")


func test_unknown_item_returns_no_cell() -> void:
	var cell: Vector2i = WeaponAtlas.cell_for(&"wood")
	assert_eq(cell, Vector2i(-1, -1), "materials should have no weapon cell")


func test_empty_id_returns_no_cell() -> void:
	var cell: Vector2i = WeaponAtlas.cell_for(&"")
	assert_eq(cell, Vector2i(-1, -1))


func test_region_for_sword() -> void:
	var r: Rect2 = WeaponAtlas.region_for(&"sword")
	assert_gt(r.size.x, 0.0, "sword region should have positive width")
	assert_eq(int(r.size.y), 33, "weapon region should be 33px tall (2 tiles)")


func test_region_for_unknown() -> void:
	var r: Rect2 = WeaponAtlas.region_for(&"stone")
	assert_eq(r.size, Vector2.ZERO, "unknown items should return empty region")


# --- ActionParticles -----------------------------------------------

func test_action_particle_constants_exist() -> void:
	# Verify the Action enum values are accessible.
	assert_eq(ActionParticles.Action.MELEE, 0)
	assert_eq(ActionParticles.Action.MINE, 1)
	assert_eq(ActionParticles.Action.GATHER, 2)
	assert_eq(ActionParticles.Action.RANGED, 3)
	assert_eq(ActionParticles.Action.BREAK, 4)


func test_spawn_impact_creates_particles() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var p: CPUParticles2D = ActionParticles.spawn_impact(
		parent, Vector2(100, 100), ActionParticles.Action.MELEE)
	assert_not_null(p, "spawn_impact should return a CPUParticles2D")
	assert_true(p.one_shot)
	assert_true(p.emitting)


func test_spawn_impact_mine_spark_for_rock() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var p: CPUParticles2D = ActionParticles.spawn_impact(
		parent, Vector2(50, 50), ActionParticles.Action.MINE, &"rock")
	assert_not_null(p)
	# Spark particles have yellowish color.
	assert_gt(p.color.r, 0.8, "spark particles should be warm-colored")


func test_spawn_impact_mine_dirt_for_tree() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var p: CPUParticles2D = ActionParticles.spawn_impact(
		parent, Vector2(50, 50), ActionParticles.Action.MINE, &"tree")
	assert_not_null(p)
	# Dirt particles have brownish color.
	assert_lt(p.color.g, 0.7, "dirt particles should be earthy-colored")


func test_spawn_impact_break_burst() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var p: CPUParticles2D = ActionParticles.spawn_impact(
		parent, Vector2(50, 50), ActionParticles.Action.BREAK, &"iron_vein")
	assert_not_null(p)
	assert_eq(p.amount, 12, "break burst should have 12 particles")


# --- Equipment → weapon sprite wiring ---

func test_equipment_contents_changed_signal() -> void:
	var eq := Equipment.new()
	var fired := [false]
	eq.contents_changed.connect(func(): fired[0] = true)
	eq.equip(ItemDefinition.Slot.WEAPON, &"sword")
	assert_true(fired[0], "contents_changed should fire on equip")


func test_weapon_atlas_defaults_match_tile_mappings() -> void:
	# The TileMappings defaults should include weapon_sprites.
	var tm: TileMappings = TileMappings.default_mappings()
	assert_true(tm.weapon_sprites.has(&"sword"), "defaults should have sword")
	assert_true(tm.weapon_sprites.has(&"pickaxe"), "defaults should have pickaxe")
	assert_true(tm.weapon_sprites.has(&"bow"), "defaults should have bow")
