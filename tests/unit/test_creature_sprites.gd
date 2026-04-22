## Tests for CreatureSpriteRegistry — JSON manifest loading, sprite building,
## and integration with Monster / NPC sprite setup.
extends GutTest


func before_each() -> void:
	CreatureSpriteRegistry.reset()


# --- Loading & querying ------------------------------------------

func test_loads_creature_sprites_json() -> void:
	assert_true(CreatureSpriteRegistry.has_entry(&"slime"),
		"slime entry should exist")


func test_all_kinds_returns_registered() -> void:
	var kinds: Array = CreatureSpriteRegistry.all_kinds()
	assert_true(kinds.size() >= 2, "at least 2 kinds expected")
	assert_true(kinds.has(&"slime"), "should include slime")
	assert_true(kinds.has(&"skeleton"), "should include skeleton")


func test_has_entry_false_for_missing() -> void:
	assert_false(CreatureSpriteRegistry.has_entry(&"nonexistent"),
		"nonexistent kind should return false")


func test_get_entry_returns_dict_with_sheet() -> void:
	var e: Dictionary = CreatureSpriteRegistry.get_entry(&"slime")
	assert_true(e.has("sheet"), "entry should have sheet path")
	assert_true(e.has("region"), "entry should have region")
	assert_true(e.has("anchor"), "entry should have anchor")
	assert_true(e.has("scale"), "entry should have scale")


func test_get_entry_empty_for_missing() -> void:
	var e: Dictionary = CreatureSpriteRegistry.get_entry(&"nonexistent")
	assert_eq(e.size(), 0, "missing kind should return empty dict")


# --- Accessors ---------------------------------------------------

func test_get_footprint_default() -> void:
	var fp: Vector2i = CreatureSpriteRegistry.get_footprint(&"slime")
	assert_eq(fp, Vector2i(1, 1), "slime should have 1x1 footprint")


func test_get_anchor_returns_vector2() -> void:
	var a: Vector2 = CreatureSpriteRegistry.get_anchor(&"slime")
	assert_true(a.x >= 0.0, "anchor x should be non-negative")
	assert_true(a.y >= 0.0, "anchor y should be non-negative")


func test_get_scale_returns_vector2() -> void:
	var s: Vector2 = CreatureSpriteRegistry.get_scale(&"slime")
	assert_true(s.x > 0.0, "scale x should be positive")
	assert_true(s.y > 0.0, "scale y should be positive")


func test_get_tint_returns_colour() -> void:
	var t: Color = CreatureSpriteRegistry.get_tint(&"slime")
	assert_true(t.a > 0.0, "tint alpha should be positive")


func test_ogre_has_larger_scale_than_slime() -> void:
	var slime_s: Vector2 = CreatureSpriteRegistry.get_scale(&"slime")
	var ogre_s: Vector2 = CreatureSpriteRegistry.get_scale(&"ogre")
	assert_true(ogre_s.x > slime_s.x, "ogre should be larger than slime")


func test_bat_has_smaller_scale_than_slime() -> void:
	var slime_s: Vector2 = CreatureSpriteRegistry.get_scale(&"slime")
	var bat_s: Vector2 = CreatureSpriteRegistry.get_scale(&"bat")
	assert_true(bat_s.x < slime_s.x, "bat should be smaller than slime")


# --- Sprite building ---------------------------------------------

func test_build_sprite_returns_sprite2d() -> void:
	var spr: Sprite2D = CreatureSpriteRegistry.build_sprite(&"slime")
	assert_not_null(spr, "build_sprite should return a Sprite2D")
	assert_true(spr is Sprite2D)
	if spr != null:
		spr.free()


func test_build_sprite_has_texture() -> void:
	var spr: Sprite2D = CreatureSpriteRegistry.build_sprite(&"slime")
	assert_not_null(spr.texture, "sprite should have a texture assigned")
	if spr != null:
		spr.free()


func test_build_sprite_applies_scale() -> void:
	var spr: Sprite2D = CreatureSpriteRegistry.build_sprite(&"slime")
	var expected: Vector2 = CreatureSpriteRegistry.get_scale(&"slime")
	assert_eq(spr.scale, expected, "sprite scale should match registry")
	if spr != null:
		spr.free()


func test_build_sprite_applies_tint() -> void:
	var spr: Sprite2D = CreatureSpriteRegistry.build_sprite(&"fire_elemental")
	var expected: Color = CreatureSpriteRegistry.get_tint(&"fire_elemental")
	assert_eq(spr.modulate, expected, "sprite modulate should match tint")
	if spr != null:
		spr.free()


func test_build_sprite_null_for_missing_kind() -> void:
	var spr: Sprite2D = CreatureSpriteRegistry.build_sprite(&"nonexistent")
	assert_null(spr, "build_sprite should return null for missing kind")


func test_build_sprite_anchor_sets_offset() -> void:
	var spr: Sprite2D = CreatureSpriteRegistry.build_sprite(&"slime")
	var anchor: Vector2 = CreatureSpriteRegistry.get_anchor(&"slime")
	assert_eq(spr.offset, -anchor, "offset should be negative anchor")
	assert_false(spr.centered, "centered should be false when using anchor offset")
	if spr != null:
		spr.free()


func test_different_kinds_get_different_tints() -> void:
	var slime_t: Color = CreatureSpriteRegistry.get_tint(&"slime")
	var skeleton_t: Color = CreatureSpriteRegistry.get_tint(&"skeleton")
	assert_ne(slime_t, skeleton_t, "different kinds should have different tints")


# --- All loot table kinds have sprite entries --------------------

func test_every_loot_table_kind_has_sprite_entry() -> void:
	LootTableRegistry.reset()
	var loot_kinds: Array = LootTableRegistry.all_kinds()
	for kind in loot_kinds:
		assert_true(CreatureSpriteRegistry.has_entry(kind),
			"creature kind '%s' in loot tables should have a sprite entry" % kind)


# --- Monster integration -----------------------------------------

func test_monster_uses_registry_sprite() -> void:
	var m := Monster.new()
	m.monster_kind = &"slime"
	add_child_autofree(m)
	# Monster._ready builds sprite from registry.
	var spr: Sprite2D = null
	for c in m.get_children():
		if c is Sprite2D:
			spr = c
			break
	assert_not_null(spr, "monster should have a Sprite2D child")
	assert_not_null(spr.texture, "monster sprite should have texture")
	var expected_tint: Color = CreatureSpriteRegistry.get_tint(&"slime")
	assert_eq(spr.modulate, expected_tint, "monster sprite tint should match registry")
