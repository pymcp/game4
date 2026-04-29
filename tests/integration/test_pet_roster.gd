extends GutTest

const _GameScene := preload("res://scenes/main/Game.tscn")
var _game: Game = null


func before_each() -> void:
	PetRegistry.reload()
	WorldManager.reset(202402)
	GameSession.start_new_game(202402)
	_game = _GameScene.instantiate()
	add_child_autofree(_game)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	_game = null


func _get_world() -> World:
	return World.instance()


func test_each_player_has_six_pets_in_roster() -> void:
	var world: World = _get_world()
	if world == null:
		pending("World not available")
		return
	assert_eq(world.get_pet_roster(0).size(), 6)
	assert_eq(world.get_pet_roster(1).size(), 6)


func test_active_species_is_in_roster() -> void:
	var world: World = _get_world()
	if world == null:
		pending("World not available")
		return
	var active_0: StringName = world.get_active_pet_species(0)
	var roster_0: Array[StringName] = world.get_pet_roster(0)
	assert_true(roster_0.has(active_0),
			"Active species %s should be in roster" % String(active_0))


func test_swap_changes_active_species() -> void:
	var world: World = _get_world()
	if world == null:
		pending("World not available")
		return
	var roster_0: Array[StringName] = world.get_pet_roster(0)
	var current: StringName = world.get_active_pet_species(0)
	# Pick a different species from the roster.
	var other: StringName = &""
	for s: StringName in roster_0:
		if s != current:
			other = s
			break
	assert_ne(other, &"", "Roster must have at least 2 species")
	world.swap_active_pet(0, other)
	assert_eq(world.get_active_pet_species(0), other)


func test_swap_to_same_species_is_noop() -> void:
	var world: World = _get_world()
	if world == null:
		pending("World not available")
		return
	var current: StringName = world.get_active_pet_species(0)
	world.swap_active_pet(0, current)
	assert_eq(world.get_active_pet_species(0), current)


func test_active_pet_node_matches_active_species() -> void:
	var world: World = _get_world()
	if world == null:
		pending("World not available")
		return
	await get_tree().process_frame
	var active: StringName = world.get_active_pet_species(0)
	var pet: Pet = null
	for node: Node in get_tree().get_nodes_in_group(&"pets"):
		var p := node as Pet
		if p != null and p.owner_player != null and p.owner_player.player_id == 0:
			pet = p
			break
	assert_not_null(pet, "A pet for player 0 should exist in the scene tree")
	assert_eq(pet.species, active)


func test_roster_all_unique() -> void:
	var world: World = _get_world()
	if world == null:
		pending("World not available")
		return
	var roster: Array[StringName] = world.get_pet_roster(0)
	var unique: Dictionary = {}
	for s: StringName in roster:
		assert_false(unique.has(s), "Duplicate species in roster: %s" % String(s))
		unique[s] = true
