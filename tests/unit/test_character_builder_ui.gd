## Tests for character builder: GameSession randomization, PlayerController
## apply_appearance, and InventoryScreen CHARACTER tab integration.
extends GutTest


# --- GameSession.randomize_appearance ---

func test_randomize_appearance_returns_all_keys() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var opts: Dictionary = GameSession.randomize_appearance(rng)
	assert_true(opts.has("skin"), "should have skin")
	assert_true(opts.has("torso_color"), "should have torso_color")
	assert_true(opts.has("torso_style"), "should have torso_style")
	assert_true(opts.has("torso_row"), "should have torso_row")
	assert_true(opts.has("hair_color"), "should have hair_color")
	assert_true(opts.has("hair_style"), "should have hair_style")
	assert_true(opts.has("hair_variant"), "should have hair_variant")


func test_randomize_appearance_is_deterministic() -> void:
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99
	var opts1: Dictionary = GameSession.randomize_appearance(rng1)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99
	var opts2: Dictionary = GameSession.randomize_appearance(rng2)
	assert_eq(opts1, opts2, "same seed should produce same appearance")


func test_randomize_appearance_different_seeds_differ() -> void:
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 1
	var opts1: Dictionary = GameSession.randomize_appearance(rng1)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 999
	var opts2: Dictionary = GameSession.randomize_appearance(rng2)
	# Very unlikely to be identical across different seeds.
	assert_ne(opts1, opts2, "different seeds should produce different appearances")


func test_randomize_appearance_skin_is_valid() -> void:
	var valid: Array = [&"light", &"tan", &"dark", &"goblin"]
	for i in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var opts: Dictionary = GameSession.randomize_appearance(rng)
		assert_true(opts["skin"] in valid,
			"skin '%s' should be a valid option" % opts["skin"])


func test_randomize_appearance_torso_color_is_valid() -> void:
	var valid: Array = [&"orange", &"teal", &"purple", &"green", &"tan", &"black"]
	for i in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var opts: Dictionary = GameSession.randomize_appearance(rng)
		assert_true(opts["torso_color"] in valid,
			"torso_color '%s' should be valid" % opts["torso_color"])


func test_randomize_appearance_hair_color_is_valid() -> void:
	var valid: Array = [&"brown", &"blonde", &"white", &"ginger", &"gray"]
	for i in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var opts: Dictionary = GameSession.randomize_appearance(rng)
		assert_true(opts["hair_color"] in valid,
			"hair_color '%s' should be valid" % opts["hair_color"])


func test_randomize_appearance_sometimes_has_face() -> void:
	var has_face := false
	var no_face := false
	for i in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var opts: Dictionary = GameSession.randomize_appearance(rng)
		if opts.has("face_color"):
			has_face = true
		else:
			no_face = true
	assert_true(has_face, "some appearances should have facial hair")
	assert_true(no_face, "some appearances should lack facial hair")


# --- GameSession.get/set_appearance ---

func test_get_set_appearance_p1() -> void:
	var opts: Dictionary = {"skin": &"dark", "hair_color": &"blonde"}
	GameSession.set_appearance(0, opts)
	assert_eq(GameSession.get_appearance(0), opts)


func test_get_set_appearance_p2() -> void:
	var opts: Dictionary = {"skin": &"tan"}
	GameSession.set_appearance(1, opts)
	assert_eq(GameSession.get_appearance(1), opts)


# --- PlayerController.apply_appearance ---

func test_apply_appearance_updates_body_region() -> void:
	var scene: PackedScene = preload("res://scenes/entities/Player.tscn")
	var p: PlayerController = scene.instantiate() as PlayerController
	add_child_autofree(p)
	var opts: Dictionary = {"skin": &"dark"}
	p.apply_appearance(opts)
	var body: Sprite2D = p.get_node("SpriteRoot/Body") as Sprite2D
	var expected_cell: Vector2i = CharacterAtlas.body_cell(&"dark")
	var expected_rect := Rect2(CharacterAtlas.tile_rect(expected_cell))
	assert_eq(body.region_rect, expected_rect, "body should use dark skin region")


func test_apply_appearance_updates_torso_and_default() -> void:
	var scene: PackedScene = preload("res://scenes/entities/Player.tscn")
	var p: PlayerController = scene.instantiate() as PlayerController
	add_child_autofree(p)
	var opts: Dictionary = {
		"skin": &"light",
		"torso_color": &"teal",
		"torso_style": 2,
		"torso_row": 1,
	}
	p.apply_appearance(opts)
	var torso: Sprite2D = p.get_node("SpriteRoot/Torso") as Sprite2D
	var expected_cell: Vector2i = CharacterAtlas.torso_cell(&"teal", 2, 1)
	var expected_rect := Rect2(CharacterAtlas.tile_rect(expected_cell))
	assert_eq(torso.region_rect, expected_rect, "torso should use teal style 2 row 1")
	# The default region should also be updated for armor restore.
	assert_eq(p._default_torso_region, expected_rect,
		"_default_torso_region should match new appearance")


func test_apply_appearance_updates_hair_and_default() -> void:
	var scene: PackedScene = preload("res://scenes/entities/Player.tscn")
	var p: PlayerController = scene.instantiate() as PlayerController
	add_child_autofree(p)
	var opts: Dictionary = {
		"skin": &"light",
		"hair_color": &"ginger",
		"hair_style": CharacterAtlas.HairStyle.LONG,
		"hair_variant": 2,
	}
	p.apply_appearance(opts)
	var hair: Sprite2D = p.get_node("SpriteRoot/Hair") as Sprite2D
	var expected_cell: Vector2i = CharacterAtlas.hair_cell(&"ginger", CharacterAtlas.HairStyle.LONG, 2)
	var expected_rect := Rect2(CharacterAtlas.tile_rect(expected_cell))
	assert_eq(hair.region_rect, expected_rect, "hair should use ginger long variant 2")
	assert_eq(p._default_hair_region, expected_rect,
		"_default_hair_region should match new appearance")


func test_apply_appearance_shows_face_when_set() -> void:
	var scene: PackedScene = preload("res://scenes/entities/Player.tscn")
	var p: PlayerController = scene.instantiate() as PlayerController
	add_child_autofree(p)
	var opts: Dictionary = {
		"skin": &"light",
		"face_color": &"brown",
		"face_variant": 1,
	}
	p.apply_appearance(opts)
	var face: Sprite2D = p.get_node("SpriteRoot/Face") as Sprite2D
	assert_true(face.visible, "face sprite should be visible with facial hair")


func test_apply_appearance_hides_face_when_unset() -> void:
	var scene: PackedScene = preload("res://scenes/entities/Player.tscn")
	var p: PlayerController = scene.instantiate() as PlayerController
	add_child_autofree(p)
	var opts: Dictionary = {"skin": &"light"}
	p.apply_appearance(opts)
	var face: Sprite2D = p.get_node("SpriteRoot/Face") as Sprite2D
	assert_false(face.visible, "face sprite should be hidden without facial hair")


func test_apply_appearance_empty_opts_is_noop() -> void:
	var scene: PackedScene = preload("res://scenes/entities/Player.tscn")
	var p: PlayerController = scene.instantiate() as PlayerController
	add_child_autofree(p)
	var torso: Sprite2D = p.get_node("SpriteRoot/Torso") as Sprite2D
	var original_region: Rect2 = torso.region_rect
	p.apply_appearance({})
	assert_eq(torso.region_rect, original_region,
		"empty opts should not change torso region")


func test_apply_appearance_armor_restore_uses_new_default() -> void:
	var scene: PackedScene = preload("res://scenes/entities/Player.tscn")
	var p: PlayerController = scene.instantiate() as PlayerController
	add_child_autofree(p)
	# Apply a non-default appearance.
	var opts: Dictionary = {
		"skin": &"dark",
		"torso_color": &"purple",
		"torso_style": 1,
		"torso_row": 3,
	}
	p.apply_appearance(opts)
	var expected_cell: Vector2i = CharacterAtlas.torso_cell(&"purple", 1, 3)
	var expected_rect := Rect2(CharacterAtlas.tile_rect(expected_cell))
	# Simulate armor unequip: _apply_armor_layer with empty id restores default.
	var torso: Sprite2D = p.get_node("SpriteRoot/Torso") as Sprite2D
	p._apply_armor_layer(torso, p._default_torso_region, &"")
	assert_eq(torso.region_rect, expected_rect,
		"armor restore should use appearance-based default, not scene default")


# --- InventoryScreen CHARACTER tab ---

func test_character_tab_exists_in_enum() -> void:
	assert_true(InventoryScreen.Tab.has("CHARACTER"),
		"Tab enum should include CHARACTER")


func test_character_tab_label() -> void:
	assert_eq(InventoryScreen.TAB_LABELS[InventoryScreen.Tab.CHARACTER], "Character",
		"CHARACTER tab label should be 'Character'")


func test_equipment_tab_removed() -> void:
	assert_false(InventoryScreen.Tab.has("EQUIPMENT"),
		"Equipment tab should be removed from Tab enum")


func test_all_tab_is_index_zero() -> void:
	assert_eq(int(InventoryScreen.Tab.ALL), 0,
		"ALL tab should be index 0 after Equipment removal")
