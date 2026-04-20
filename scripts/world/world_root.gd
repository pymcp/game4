## WorldRoot
##
## Top-down 2D scene root for ONE player's view in the split-screen co-op.
## Renders whatever map ViewManager says this player is currently in
## (overworld Region or InteriorMap) into 3 stacked TileMapLayers and a
## Y-sorted entity container.
##
## A WorldRoot is now a *world instance*: one per location
## (overworld region, dungeon floor, house interior). Multiple
## instances live side-by-side under the [World] coordinator at
## fixed spatial offsets so a single shared `world_2d` can be
## sampled by both player viewports. Players are re-parented under
## the active instance by [World.transition_player]; this script
## owns terrain/door/mineable/villager/boat state but not players.
## Legacy header continued (kept for completeness):
## (formerly: subscribed to
## `ViewManager.player_view_changed` and ignores events for the OTHER
## player_id.
##
## Children (declared in World.tscn):
##   Ground       - TileMapLayer (terrain: grass/water/floor/road/...)
##   Decoration   - TileMapLayer (rocks/trees/walls; non-walkable per
##                  TilesetCatalog.CUSTOM_WALKABLE)
##   Overlay      - TileMapLayer (rune marks, mining-damage cracks)
##   Entities     - Y-sorted Node2D for players / NPCs / loot
extends Node2D
class_name WorldRoot

const _MAX_LAND_SEARCH_RADIUS: int = 8
const _BoatScene: PackedScene = preload("res://scenes/entities/Boat.tscn")

## When non-zero, reseeds WorldManager before generation.
@export var override_seed: int = 0

@onready var ground: TileMapLayer = $Ground
@onready var patch: TileMapLayer = $Patch
@onready var decoration: TileMapLayer = $Decoration
@onready var overlay: TileMapLayer = $Overlay
@onready var entities: Node2D = $Entities

var _region: Region = null
var _interior: InteriorMap = null
var _boat: Boat = null
var _doors: Dictionary = {}  ## Vector2i -> Dictionary{kind, ...}
## Per-player door-tile cache so each player triggers a door at most
## once per cell-step (PlayerController -> Vector2i).
var _last_door_cell_per_player: Dictionary = {}
var _mineable: Dictionary = {}  ## Vector2i -> {kind: StringName, hp: int}
## Last rune touched in this instance (test hook). Re-set per-touch
## with the touching player's id baked in.
var last_rune_message: String = ""
var _dialogue_box: DialogueBox = null  ## Per-instance dialogue UI.

const MINEABLE_HP: Dictionary = {
	&"tree": 3, &"bush": 1, &"rock": 5, &"iron_vein": 6, &"copper_vein": 5,
}
const MINEABLE_DROPS: Dictionary = {
	&"tree": [{"id": &"wood", "count": 1}],
	&"bush": [{"id": &"fiber", "count": 1}],
	&"rock": [{"id": &"stone", "count": 1}],
	&"iron_vein": [{"id": &"iron_ore", "count": 1}],
	&"copper_vein": [{"id": &"copper_ore", "count": 1}],
}


func _ready() -> void:
	if override_seed != 0:
		WorldManager.reset(override_seed)
	# WorldRoot is now a "world instance": one per location, parented
	# under the [World] coordinator. The coordinator handles spatial
	# offset (between instances) and zoom (set on the World itself).
	add_to_group(&"world_instances")


# --- Public API ----------------------------------------------------

func get_terrain_at(cell: Vector2i) -> StringName:
	var data: TileData = ground.get_cell_tile_data(cell)
	if data == null:
		return &""
	var v: Variant = data.get_custom_data(TilesetCatalog.CUSTOM_TERRAIN)
	return v if v is StringName else &""


func is_walkable(cell: Vector2i) -> bool:
	var deco: TileData = decoration.get_cell_tile_data(cell)
	if deco != null:
		var dv: Variant = deco.get_custom_data(TilesetCatalog.CUSTOM_WALKABLE)
		if dv is bool and not dv:
			return false
	var ground_data: TileData = ground.get_cell_tile_data(cell)
	if ground_data == null:
		return false
	var gv: Variant = ground_data.get_custom_data(TilesetCatalog.CUSTOM_WALKABLE)
	return bool(gv)


func get_map_size() -> Vector2i:
	if _interior != null:
		return Vector2i(_interior.width, _interior.height)
	if _region != null:
		return Vector2i(Region.SIZE, Region.SIZE)
	return Vector2i.ZERO


func in_interior() -> bool:
	return _interior != null


## Seed [param player]'s door cache so we don't immediately re-trigger
## the door beneath them. Used by [World] after re-parenting a player.
func prime_door_cache(player: PlayerController, cell: Vector2i) -> void:
	_last_door_cell_per_player[player] = cell


## Returns the `PlayerController` for `pid` (0 = P1, 1 = P2). Thin
## passthrough to [World.get_player] so legacy callers that hold a
## `WorldRoot` ref keep working.
func get_player(pid: int) -> PlayerController:
	return World.instance().get_player(pid)


# --- ViewManager integration --------------------------------------

## Paint this instance with the given view. Idempotent for the same
## (region, interior) tuple but cheap enough that the coordinator can
## call it freely on instance creation. Does NOT spawn or place
## players — the [World] coordinator owns player ownership.
func apply_view(view_kind: StringName, region: Region, interior: InteriorMap) -> void:
	_clear_layers()
	if view_kind == &"overworld":
		_interior = null
		_region = _resolve_land_region(region)
		_attach_overworld_tilesets()
		_paint_region(_region)
	else:
		_region = region
		_interior = interior
		_attach_interior_tilesets(view_kind)
		if interior != null:
			_paint_interior(interior, view_kind)
	_spawn_scattered_npcs()
	_build_door_index(view_kind)
	_build_mineable_index()
	_last_door_cell_per_player.clear()
	if view_kind == &"overworld":
		_ensure_boat()
	elif _boat != null and is_instance_valid(_boat):
		_boat.queue_free()
		_boat = null


# --- TileSet wiring ------------------------------------------------

func _attach_overworld_tilesets() -> void:
	var ts: TileSet = TilesetCatalog.overworld()
	ground.tile_set = ts
	patch.tile_set = ts
	decoration.tile_set = ts
	overlay.tile_set = TilesetCatalog.runes()


func _attach_interior_tilesets(view_kind: StringName) -> void:
	var ts: TileSet
	match view_kind:
		&"city": ts = TilesetCatalog.city()
		&"house": ts = TilesetCatalog.interior()
		_: ts = TilesetCatalog.dungeon()
	ground.tile_set = ts
	decoration.tile_set = ts
	# Patch layer is overworld-only; clearing the tile_set guarantees
	# any leftover overworld patch cells aren't rendered over interior
	# tile coords with mismatched atlas data.
	patch.tile_set = null
	overlay.tile_set = TilesetCatalog.runes()


# --- Overworld loading & painting ----------------------------------

func _resolve_land_region(start: Region) -> Region:
	if start != null and not start.is_ocean and not start.spawn_points.is_empty():
		return start
	var start_id: Vector2i = start.region_id if start != null else Vector2i.ZERO
	for r in range(1, _MAX_LAND_SEARCH_RADIUS + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if max(abs(dx), abs(dy)) != r:
					continue
				var cand: Region = WorldManager.get_or_generate(start_id + Vector2i(dx, dy))
				if not cand.is_ocean and not cand.spawn_points.is_empty():
					return cand
	return start


func _paint_region(region: Region) -> void:
	var size: int = Region.SIZE
	# Mix region.seed into the per-cell hash so reloads pick the same
	# variant tiles every time, but DIFFERENT regions don't share the
	# same flower-grass arrangement.
	var seed_hash: int = region.seed
	# Look up overlay-secondary settings: when a biome's secondary terrain
	# (e.g. dirt for grass biome, dirt for desert biome) has a registered
	# 3×3 patch set AND is walkable, we paint PRIMARY on Ground for those
	# cells and the matching corner/edge tile on the Patch layer. The
	# transparent corners of patch tiles let the underlying primary show
	# through, producing soft rounded blob edges instead of hard squares.
	var biome: BiomeDefinition = BiomeRegistry.get_biome(region.biome)
	var overlay_code: int = -1
	var primary_cell: Vector2i = Vector2i(-1, -1)
	var patch_cells: Array = []
	if biome != null:
		var sec_name: StringName = TerrainCodes.to_terrain_type(
			biome.secondary_terrain)
		var prim_name: StringName = TerrainCodes.to_terrain_type(
			biome.primary_terrain)
		var pset: Variant = TilesetCatalog.OVERWORLD_TERRAIN_PATCH_3X3.get(
			sec_name, null)
		var sec_walkable: bool = bool(
			TilesetCatalog.WALKABLE.get(sec_name, false))
		if sec_walkable and pset is Array and (pset as Array).size() == 9:
			patch_cells = pset
			primary_cell = TilesetCatalog.cell_for(&"overworld", prim_name)
			overlay_code = biome.secondary_terrain
	for y in size:
		for x in size:
			var cell := Vector2i(x, y)
			var code: int = region.tiles[y * size + x]
			var terrain: StringName = TerrainCodes.to_terrain_type(code)
			var hash32: int = seed_hash ^ (x * 73856093) ^ (y * 19349663)
			if code == overlay_code and primary_cell.x >= 0:
				# Paint primary terrain on Ground so the patch corners blend.
				ground.set_cell(cell, 0, primary_cell, 0)
				var idx: int = _patch_index_for_neighbors(
					region, x, y, overlay_code, size)
				patch.set_cell(cell, 0, patch_cells[idx], 0)
			else:
				var atlas_cell: Vector2i = TilesetCatalog.cell_for_variant(
