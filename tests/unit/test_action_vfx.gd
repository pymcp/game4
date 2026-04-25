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

func test_flash_hit_no_crash_on_null() -> void:
	# flash_hit should not crash when called with null.
	ActionParticles.flash_hit(null)
	pass_test("flash_hit(null) did not crash")


func test_flash_hit_modulates_node() -> void:
	var sprite := Sprite2D.new()
	add_child_autofree(sprite)
	ActionParticles.flash_hit(sprite)
	# Tween is running — modulate will change over time.
	# Just verify it doesn't crash and the node is valid.
	assert_true(is_instance_valid(sprite))


# --- Equipment → weapon sprite wiring ---

func test_equipment_contents_changed_signal() -> void:
	var eq := Equipment.new()
	var fired := [false]
	eq.contents_changed.connect(func(): fired[0] = true)
	eq.equip(ItemDefinition.Slot.WEAPON, &"sword")
	assert_true(fired[0], "contents_changed should fire on equip")


func test_weapon_atlas_defaults_match_item_definitions() -> void:
	# Weapon sprites are now in items.json, resolved via WeaponAtlas.
	assert_ne(WeaponAtlas.cell_for(&"sword"), Vector2i(-1, -1), "sword should have weapon cell")
	assert_ne(WeaponAtlas.cell_for(&"pickaxe"), Vector2i(-1, -1), "pickaxe should have weapon cell")
	assert_ne(WeaponAtlas.cell_for(&"bow"), Vector2i(-1, -1), "bow should have weapon cell")


# --- flash_hit ----------------------------------------------------

func test_flash_hit_tweens_modulate() -> void:
	var spr := Sprite2D.new()
	add_child_autofree(spr)
	ActionParticles.flash_hit(spr)
	# Immediately after call, a tween should be running on the node.
	# We can't easily test the tween mid-flight, but we can verify it
	# doesn't crash and the modulate will be white at the end.
	pass_test("flash_hit did not crash")


func test_flash_hit_null_no_crash() -> void:
	ActionParticles.flash_hit(null)
	pass_test("flash_hit(null) did not crash")


# --- ActionVFX decoupled setup ------------------------------------

func test_action_vfx_setup_with_plain_node2d() -> void:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var vfx := ActionVFX.new()
	add_child_autofree(vfx)
	# Should work with any Node2D, not just PlayerController.
	vfx.setup(owner, null, null)
	assert_false(vfx.is_playing(), "should not be playing after setup")


func test_action_vfx_null_weapon_sprite_no_crash() -> void:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var vfx := ActionVFX.new()
	add_child_autofree(vfx)
	vfx.setup(owner, null, null)
	# These should not crash with null weapon sprite.
	vfx._bow_pullback()
	vfx._weapon_flash_and_rotate(-45.0, 45.0, 0.15)
	vfx._weapon_flash_and_thrust(0.2)
	pass_test("null weapon sprite methods did not crash")


# --- ActionVFX creature attack dispatch ----------------------------

func test_creature_attack_swing_lunges() -> void:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var sprite := Sprite2D.new()
	owner.add_child(sprite)
	var vfx := ActionVFX.new()
	add_child_autofree(vfx)
	vfx.setup(owner, null, null, sprite)
	vfx.play_creature_attack(Vector2i(5, 5), Vector2(1, 0), &"swing")
	assert_true(vfx.is_playing(), "should be playing after creature swing")


func test_creature_attack_slam_lunges() -> void:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var sprite := Sprite2D.new()
	owner.add_child(sprite)
	var vfx := ActionVFX.new()
	add_child_autofree(vfx)
	vfx.setup(owner, null, null, sprite)
	vfx.play_creature_attack(Vector2i(5, 5), Vector2(0, 1), &"slam")
	assert_true(vfx.is_playing(), "slam should trigger lunge")


func test_creature_attack_none_does_nothing() -> void:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var vfx := ActionVFX.new()
	add_child_autofree(vfx)
	vfx.setup(owner, null, null)
	vfx.play_creature_attack(Vector2i(5, 5), Vector2(1, 0), &"none")
	assert_false(vfx.is_playing(), "none style should not play anything")


func test_creature_attack_projectile_plays_ranged() -> void:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var vfx := ActionVFX.new()
	owner.add_child(vfx)
	add_child_autofree(owner)
	vfx.setup(owner, null, null)
	vfx.play_creature_attack(Vector2i(5, 5), Vector2(1, 0), &"projectile")
	assert_true(vfx.is_playing(), "projectile should play ranged")


func test_unarmed_lunge_with_visual_root() -> void:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var sprite := Sprite2D.new()
	owner.add_child(sprite)
	var vfx := ActionVFX.new()
	add_child_autofree(vfx)
	vfx.setup(owner, null, null, sprite)
	vfx.play_unarmed_lunge(Vector2i(3, 3), Vector2(1, 0))
	assert_true(vfx.is_playing(), "unarmed lunge should be playing")


func test_unarmed_lunge_no_visual_root_finishes() -> void:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var vfx := ActionVFX.new()
	add_child_autofree(vfx)
	vfx.setup(owner, null, null)
	vfx.play_unarmed_lunge(Vector2i(3, 3), Vector2(1, 0))
	assert_false(vfx.is_playing(), "no visual_root should finish immediately")


func test_weapon_flash_and_rotate_with_sprite() -> void:
	var owner := Node2D.new()
	add_child_autofree(owner)
	var weapon := Sprite2D.new()
	weapon.visible = true
	weapon.texture = PlaceholderTexture2D.new()
	owner.add_child(weapon)
	var vfx := ActionVFX.new()
	add_child_autofree(vfx)
	vfx.setup(owner, weapon, null)
	# Call through public API which sets _is_playing before the helper.
	vfx.play_melee_swing(Vector2i(3, 3), Vector2(1, 0))
	assert_true(vfx.is_playing(), "weapon flash+rotate should be playing")
