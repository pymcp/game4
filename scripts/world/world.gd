## World
##
## Top-level shared world container. Replaces the dual-WorldRoot
## architecture: ONE [World] hosts every active [WorldRoot] (each one
## is a "world instance" — overworld region, cave, or house), plus both
## [PlayerController]s, plus their pets.
##
## Both split-screen [SubViewport]s share a single [World2D] (set up in
## [Game._ready]) so both render this same scene tree. Each viewport
## has its own [Camera2D] following its [PlayerController]; the camera
## naturally renders only the instance the player is standing in
## because instances are spaced [_INSTANCE_OFFSET_PX] pixels apart in
## the shared canvas.
##
## Key responsibilities:
## - Lazily create + paint [WorldRoot] instances on demand.
## - Re-parent players + pets between instances on view change.
## - Keep a per-player "current instance" map for queries.
## - Expose [find_player_world] / [get_player] for entities and tests.
##
## Doors in [WorldRoot._handle_door] call [transition_player] (passing
## an optional [override_spawn_cell] when they need the player to
## arrive on a specific cell, e.g. an interior_exit returning to the
## cave entrance).
extends Node2D
class_name World

const _PlayerScene: PackedScene = preload("res://scenes/entities/Player.tscn")
const _PetScene: PackedScene = preload("res://scenes/entities/Pet.tscn")
const _WorldInstanceScene: PackedScene = preload(
		"res://scenes/world/World.tscn")

## Pixel offset between consecutive [WorldRoot] instances on the shared
## canvas. Large enough that no single map (regions are 64×16=1024 px,
## interiors are even smaller) ever overlaps a neighbour.
const _INSTANCE_OFFSET_PX: float = 100000.0

const _NO_OVERRIDE: Vector2i = Vector2i(-9999, -9999)

@export var override_seed: int = 0
@export var start_region_id: Vector2i = Vector2i.ZERO

var _instances: Dictionary = {}  ## key (StringName) -> WorldRoot
var _next_instance_index: int = 0
var _players: Array = []  ## index = player_id; PlayerController
var _pets: Array = []  ## index = player_id; Pet
var _player_instance_key: Array = []  ## index = player_id; StringName
var _pending_spawn: Array = []  ## index = player_id; Vector2i (or _NO_OVERRIDE)


func _ready() -> void:
	add_to_group(&"world")
	if override_seed != 0:
		WorldManager.reset(override_seed)
	scale = Vector2(WorldConst.RENDER_ZOOM, WorldConst.RENDER_ZOOM)
	for _i in range(2):
		_players.append(null)
		_pets.append(null)
		_player_instance_key.append(&"")
		_pending_spawn.append(_NO_OVERRIDE)
	for pid in range(2):
		var p := _PlayerScene.instantiate() as PlayerController
		p.player_id = pid
		p.name = "Player%d" % pid
		_players[pid] = p
	# Drop both players into the starting overworld region.
	for pid in range(2):
		_enter_view(pid, &"overworld",
				WorldManager.get_or_generate(start_region_id), null)


# ─── Public API ────────────────────────────────────────────────────────

func get_player(pid: int) -> PlayerController:
	if pid < 0 or pid >= _players.size():
		return null
	return _players[pid]


func get_player_world(pid: int) -> WorldRoot:
	if pid < 0 or pid >= _player_instance_key.size():
		return null
	return _instances.get(_player_instance_key[pid])


## Singleton-ish accessor: returns the active [World] from the scene
## tree (added to the [&"world"] group in [_ready]). Returns null
## before [Game] has finished setting up.
static func instance() -> World:
	var t: SceneTree = Engine.get_main_loop() as SceneTree
	if t == null:
		return null
	return t.get_first_node_in_group(&"world") as World


## Move [param pid] into [param view_kind] (overworld/cave/house).
## [param region] is the overworld region that hosts the destination
## (also valid when the destination IS the overworld). [param interior]
## is the [InteriorMap] when [param view_kind] != [code]&"overworld"[/code].
##
## When [param override_spawn_cell] is set (≠ [_NO_OVERRIDE]), the player
## is dropped on that cell instead of the instance's default spawn.
## Doors use this to pop the player back onto the cave entrance after
## an interior_exit.
func transition_player(pid: int, view_kind: StringName, region: Region,
		interior: InteriorMap,
		override_spawn_cell: Vector2i = _NO_OVERRIDE) -> void:
	if override_spawn_cell != _NO_OVERRIDE:
		_pending_spawn[pid] = override_spawn_cell
	# Update ViewManager state so HUD / save game / inputs that read it
	# stay coherent. ViewManager will emit player_view_changed which we
	# intentionally don't subscribe to (we're handling the work right
	# here to avoid signal-ordering surprises).
	if view_kind == &"overworld":
		ViewManager.enter_overworld(pid, region.region_id)
	else:
		ViewManager.enter_interior(pid, interior, view_kind)
	_enter_view(pid, view_kind, region, interior)


# ─── Instance management ──────────────────────────────────────────────

func _enter_view(pid: int, view_kind: StringName, region: Region,
		interior: InteriorMap) -> void:
	var resolved_region: Region = region
	if view_kind == &"overworld":
		resolved_region = _resolve_land_region(region)
	var key: StringName = _instance_key(view_kind, resolved_region, interior)
	var inst: WorldRoot = _ensure_instance(key, view_kind, resolved_region,
			interior)
	_player_instance_key[pid] = key
	# Re-parent the player into this instance's `entities` y-sort node.
	var player: PlayerController = _players[pid]
	if player.get_parent() == null:
		inst.entities.add_child(player)
	elif player.get_parent() != inst.entities:
		player.get_parent().remove_child(player)
		inst.entities.add_child(player)
	player.set_world(inst)
	# Place the player.
	var spawn_cell: Vector2i = _pending_spawn[pid]
	_pending_spawn[pid] = _NO_OVERRIDE
	if spawn_cell == _NO_OVERRIDE:
		spawn_cell = inst.default_spawn_cell(view_kind, resolved_region,
				interior)
	spawn_cell = inst.find_safe_spawn_cell(spawn_cell, 16, true)
	player.position = (Vector2(spawn_cell) + Vector2(0.5, 0.5)) \
			* float(WorldConst.TILE_PX)
	# Prime this instance's per-player door cache so we don't immediately
	# re-trigger the door we just landed on (e.g. exiting a dungeon drops
	# the player back onto the entrance cell).
	inst.prime_door_cache(player, spawn_cell)
	# Re-parent + place pet alongside.
	_ensure_pet_for_player(pid, inst)


func _instance_key(view_kind: StringName, region: Region,
		interior: InteriorMap) -> StringName:
	if view_kind == &"overworld":
		var rid: Vector2i = region.region_id
		return StringName("overworld:%d_%d" % [rid.x, rid.y])
	return StringName("interior:%s" % str(interior.map_id))


func _ensure_instance(key: StringName, view_kind: StringName,
		region: Region, interior: InteriorMap) -> WorldRoot:
	if _instances.has(key):
		return _instances[key]
	var inst: WorldRoot = _WorldInstanceScene.instantiate() as WorldRoot
	inst.name = String(key).replace(":", "_").replace("/", "_")
	# Park instances at unique spatial offsets so their tilemaps don't
	# overlap on the shared canvas. The inverse render-zoom keeps the
	# offset in pre-zoom pixels (each instance scales itself by zoom).
	var inv_zoom: float = 1.0 / float(WorldConst.RENDER_ZOOM)
	inst.position = Vector2(_next_instance_index * _INSTANCE_OFFSET_PX
			* inv_zoom, 0.0)
	_next_instance_index += 1
	add_child(inst)
	inst.apply_view(view_kind, region, interior)
	_instances[key] = inst
	return inst


func _resolve_land_region(start: Region) -> Region:
	if start != null and not start.is_ocean and not start.spawn_points.is_empty():
		return start
	var start_id: Vector2i = start.region_id if start != null else Vector2i.ZERO
	for r in range(1, 8 + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if max(abs(dx), abs(dy)) != r:
					continue
				var cand: Region = WorldManager.get_or_generate(
						start_id + Vector2i(dx, dy))
				if not cand.is_ocean and not cand.spawn_points.is_empty():
					return cand
	return start


# ─── Pets ──────────────────────────────────────────────────────────────

## Cat owned by player 0, dog owned by player 1. Same lifetime as the
## [World]; re-parented (not re-spawned) on view change so HP/state
## persists.
func _ensure_pet_for_player(pid: int, inst: WorldRoot) -> void:
	var pet: Pet = _pets[pid]
	if pet == null:
		pet = _PetScene.instantiate() as Pet
		pet.species = Pet.PET_SPECIES_CAT if pid == 0 else Pet.PET_SPECIES_DOG
		pet.owner_player = _players[pid]
		_pets[pid] = pet
	if pet.get_parent() == null:
		inst.entities.add_child(pet)
	elif pet.get_parent() != inst.entities:
		pet.get_parent().remove_child(pet)
		inst.entities.add_child(pet)
	# Snap pet next to its owner.
	var centre: Vector2i = Vector2i(
			int(floor(_players[pid].position.x / float(WorldConst.TILE_PX))),
			int(floor(_players[pid].position.y / float(WorldConst.TILE_PX))))
	var cell: Vector2i = inst.find_safe_spawn_cell(centre, 6, true)
	pet.position = (Vector2(cell) + Vector2(0.5, 0.5)) \
			* float(WorldConst.TILE_PX)


# ─── Debug (forwarded from PauseManager) ──────────────────────────────

func debug_spawn_villager() -> void:
	for pid in range(2):
		var inst: WorldRoot = get_player_world(pid)
		if inst != null:
			inst.debug_spawn_villager_for(_players[pid])


func debug_spawn_monster() -> void:
	for pid in range(2):
		var inst: WorldRoot = get_player_world(pid)
		if inst != null:
			inst.debug_spawn_monster_for(_players[pid])


func debug_spawn_interactables() -> void:
	for pid in range(2):
		var inst: WorldRoot = get_player_world(pid)
		if inst != null:
			inst.debug_spawn_interactables_for(_players[pid])


func debug_toggle_tile_labels() -> void:
	for inst in _instances.values():
		if inst.has_method("debug_toggle_tile_labels"):
			inst.debug_toggle_tile_labels()
