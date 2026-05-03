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


## Walk up the scene tree from [param node] and return the nearest WorldRoot,
## or null if none is found.
static func find_from(node: Node) -> WorldRoot:
	var n: Node = node.get_parent()
	while n != null and not (n is WorldRoot):
		n = n.get_parent()
	return n as WorldRoot


## When non-zero, reseeds WorldManager before generation.
@export var override_seed: int = 0

@onready var ground: TileMapLayer = $Ground
@onready var patch: TileMapLayer = $Patch
@onready var decoration: TileMapLayer = $Decoration
@onready var overlay: TileMapLayer = $Overlay
@onready var entities: Node2D = $Entities
## Canopy layer: sits ABOVE Entities in draw order (z_index 1).
## Tree foliage and other tall-decoration tops are painted here so the
## player renders between the trunk (Decoration) and the foliage (Canopy).
@onready var canopy: TileMapLayer = $Canopy

var _region: Region = null
var _interior: InteriorMap = null
var _boat: Boat = null
var _doors: Dictionary = {}  ## Vector2i -> Dictionary{kind, ...}
var _last_view_kind: StringName = &"overworld"
## Per-player door-tile cache so each player triggers a door at most
## once per cell-step (PlayerController -> Vector2i).
var _last_door_cell_per_player: Dictionary = {}
var _mineable: Dictionary = {}  ## Vector2i -> {kind: StringName, hp: int}
## Last rune touched in this instance (test hook). Re-set per-touch
## with the touching player's id baked in.
var last_rune_message: String = ""
var _dialogue_box: DialogueBox = null  ## Per-instance dialogue UI.
var _active_tree_player: PlayerController = null  ## Player driving branching dialogue.
var _active_dialogue_npc: Node2D = null  ## NPC/entity the player is talking to.

## Entity cache for fast per-frame lookups.
var _player_cache: Array[PlayerController] = []
var _hostile_cache: Array[Node2D] = []
var _entity_cache_dirty: bool = true
## LOD: freeze distant enemies to save CPU.
const LOD_CHECK_INTERVAL: float = 0.5
const LOD_SLEEP_TILES: float = 22.0
var _lod_timer: float = 0.0
## Monotonic counter used to stagger pathfind timers across spawned enemies.
var _spawn_index: int = 0

const MINEABLE_HP: Dictionary = {
	&"tree": 3, &"bush": 1, &"rock": 5,
	&"iron_vein": 6, &"copper_vein": 5, &"gold_vein": 8,
}
const MINEABLE_DROPS: Dictionary = {
	&"tree": [{"id": &"wood", "count": 1}],
	&"bush": [{"id": &"fiber", "count": 1}],
	&"rock": [{"id": &"stone", "count": 1}],
	&"iron_vein": [{"id": &"iron_ore", "count": 1}],
	&"copper_vein": [{"id": &"copper_ore", "count": 1}],
	&"gold_vein": [{"id": &"gold_ore", "count": 1}],
}
## Kinds that benefit from pickaxe bonus damage.
const PICKAXE_BONUS_KINDS: Dictionary = {
	&"rock": true, &"iron_vein": true, &"copper_vein": true, &"gold_vein": true,
}


func _ready() -> void:
	if override_seed != 0:
		WorldManager.reset(override_seed)
	# WorldRoot is now a "world instance": one per location, parented
	# under the [World] coordinator. The coordinator handles spatial
	# offset (between instances) and zoom (set on the World itself).
	add_to_group(&"world_instances")
	# Invalidate entity cache when enemies/players enter or leave this instance.
	entities.child_entered_tree.connect(func(node: Node) -> void:
		if node is PlayerController or node is NPC or node is Monster:
			mark_entity_cache_dirty())
	entities.child_exiting_tree.connect(func(node: Node) -> void:
		if node is PlayerController or node is NPC or node is Monster:
			mark_entity_cache_dirty())


# --- Entity cache + LOD -----------------------------------------

## Mark the entity cache as needing a rebuild.
func mark_entity_cache_dirty() -> void:
	_entity_cache_dirty = true


func _rebuild_entity_cache() -> void:
	_player_cache.clear()
	_hostile_cache.clear()
	for child in entities.get_children():
		if child is PlayerController:
			_player_cache.append(child as PlayerController)
		elif child is NPC or child is Monster:
			_hostile_cache.append(child as Node2D)
	_entity_cache_dirty = false


## Returns the cached list of [PlayerController]s in this world instance.
func get_player_cache() -> Array[PlayerController]:
	if _entity_cache_dirty:
		_rebuild_entity_cache()
	return _player_cache


## Returns the cached list of hostile entities ([NPC], [Monster]) in this world instance.
func get_hostile_cache() -> Array[Node2D]:
	if _entity_cache_dirty:
		_rebuild_entity_cache()
	return _hostile_cache


## Runs every [LOD_CHECK_INTERVAL] seconds. Suspends process on enemies
## far from every player; resumes them as players approach.
func _tick_lod() -> void:
	var players: Array[PlayerController] = get_player_cache()
	var hostiles: Array[Node2D] = get_hostile_cache()
	if players.is_empty():
		return
	for enemy in hostiles:
		if not is_instance_valid(enemy):
			continue
		var min_dist_px: float = INF
		for p in players:
			if not is_instance_valid(p):
				continue
			var d: float = enemy.position.distance_to(p.position)
			if d < min_dist_px:
				min_dist_px = d
		var dist_tiles: float = min_dist_px / float(WorldConst.TILE_PX)
		if dist_tiles > LOD_SLEEP_TILES:
			if not enemy.get(&"_lod_sleeping"):
				enemy.set(&"_lod_sleeping", true)
				enemy.set_process(false)
				enemy.set_physics_process(false)
		else:
			if enemy.get(&"_lod_sleeping"):
				enemy.set(&"_lod_sleeping", false)
				enemy.set_process(true)
				enemy.set_physics_process(true)


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


## Returns true if a door entry exists at [param cell].
func has_door(cell: Vector2i) -> bool:
	return _doors.has(cell)


## Rebuild the door index for the current view without a full apply_view.
## Call after mutating dungeon_entrances at runtime (e.g. player-built house).
func rebuild_door_index() -> void:
	_build_door_index(_last_view_kind)


## Append a player-built house entrance to this region and update all
## live state (doors + entrance markers) immediately.
## Only wires doors and paints markers when currently in the overworld view.
## `style` overrides the wall material; pass &"" to auto-detect from biome.
func add_house_entrance(cell: Vector2i, style: StringName = &"") -> void:
	if _region == null:
		return
	var resolved_style: StringName = style if style != &"" else _house_style_for_biome(_region.biome)
	_region.dungeon_entrances.append({"kind": &"house", "cell": cell, "style": resolved_style})
	if _last_view_kind == &"overworld":
		_build_door_index(&"overworld")
		_paint_overworld_entrance_markers(_region)


## Resolve the house wall style from a biome name.
## Grass/forest biomes → wood; all others → stone.
static func _house_style_for_biome(biome: StringName) -> StringName:
	match biome:
		&"grass", &"forest":
			return &"wood"
		_:
			return &"stone"


func get_map_size() -> Vector2i:
	if _interior != null:
		return Vector2i(_interior.width, _interior.height)
	if _region != null:
		return Vector2i(Region.SIZE, Region.SIZE)
	return Vector2i.ZERO


func is_in_interior() -> bool:
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
	_last_view_kind = view_kind
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
	_materialize_loot_scatter()
	_materialize_chest_scatter()
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
	var sf: float = TilesetCatalog.scale_for_sheet(
			TilesetCatalog.get_sheet_path(&"overworld_terrain"))
	var sv := Vector2(sf, sf)
	ground.tile_set = ts
	ground.scale = sv
	patch.tile_set = ts
	patch.scale = sv
	decoration.tile_set = ts
	decoration.scale = sv
	canopy.tile_set = ts
	canopy.scale = sv
	overlay.tile_set = TilesetCatalog.runes()
	overlay.scale = Vector2.ONE


func _attach_interior_tilesets(view_kind: StringName) -> void:
	var ts: TileSet
	var sheet_field: StringName
	match view_kind:
		&"city":
			ts = TilesetCatalog.city()
			sheet_field = &"city_terrain"
		&"house":
			ts = TilesetCatalog.interior()
			sheet_field = &"interior_terrain"
		&"dungeon":
			ts = TilesetCatalog.dungeon()
			sheet_field = &"dungeon_terrain"
		&"labyrinth":
			ts = TilesetCatalog.labyrinth()
			sheet_field = &"labyrinth_terrain"
		_:
			ts = TilesetCatalog.dungeon()
			sheet_field = &"dungeon_terrain"
	var sf: float = TilesetCatalog.scale_for_sheet(
			TilesetCatalog.get_sheet_path(sheet_field))
	var sv := Vector2(sf, sf)
	ground.tile_set = ts
	ground.scale = sv
	decoration.tile_set = ts
	decoration.scale = sv
	# Patch layer is overworld-only; clearing the tile_set guarantees
	# any leftover overworld patch cells aren't rendered over interior
	# tile coords with mismatched atlas data.
	patch.tile_set = null
	patch.scale = Vector2.ONE
	canopy.tile_set = null
	canopy.scale = Vector2.ONE
	overlay.tile_set = TilesetCatalog.runes()
	overlay.scale = Vector2.ONE


# --- Overworld loading & painting ----------------------------------

static func _resolve_land_region(start: Region) -> Region:
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
	var biome: BiomeDefinition = BiomeRegistry.get_biome(region.biome)

	# ── Secondary-terrain overlay setup ────────────────────────────────────
	# Transparent Kenney overlay tiles painted on the Patch layer above the
	# primary Ground tile. Water-as-secondary is skipped — the water-border
	# pass handles those cells separately.
	var overlay_code: int = -1
	var overlay_cells: Array = []
	if biome != null and not biome.overlay_set.is_empty():
		if not _is_water_code(biome.secondary_terrain):
			overlay_code = biome.secondary_terrain
			var oset: Variant = TilesetCatalog.OVERWORLD_OVERLAY_SETS.get(biome.overlay_set, null)
			if oset is Array:
				overlay_cells = oset as Array

	for y in size:
		for x in size:
			var cell := Vector2i(x, y)
			var code: int = region.tiles[y * size + x]
			var terrain: StringName = TerrainCodes.to_terrain_type(code)
			var hash32: int = seed_hash ^ (x * 73856093) ^ (y * 19349663)

			if overlay_code >= 0 and code == overlay_code and overlay_cells.size() >= 13:
				# Secondary terrain blob cell.
				# Paint primary terrain underneath on Ground, overlay tile on Patch.
				var prim_cell: Vector2i = TilesetCatalog.cell_for(&"overworld",
						TerrainCodes.to_terrain_type(biome.primary_terrain))
				ground.set_cell(cell, 0, prim_cell, 0)
				var idx: int = _patch_index_for_neighbors(region, x, y, overlay_code, size)
				# Clamp idx for 13-tile sets (no path tiles → fall back to center).
				idx = mini(idx, overlay_cells.size() - 1)
				patch.set_cell(cell, 0, overlay_cells[idx], 0)
			else:
				var atlas_cell: Vector2i = TilesetCatalog.cell_for_variant(
						&"overworld", terrain, hash32)
				if atlas_cell.x >= 0:
					ground.set_cell(cell, 0, atlas_cell, 0)
	# Path overlay pass — 1-tile-wide corridors stored in region.path_tiles.
	# Uses the full 29-tile bitmask lookup for correct corners/T-junctions.
	if not region.path_tiles.is_empty() and overlay_cells.size() >= 29:
		var path_prim_cell: Vector2i = Vector2i(-1, -1)
		if biome != null:
			path_prim_cell = TilesetCatalog.cell_for(&"overworld",
					TerrainCodes.to_terrain_type(biome.primary_terrain))
		var path_set: Dictionary = {}
		for c: Vector2i in region.path_tiles:
			path_set[c] = true
		for c: Vector2i in region.path_tiles:
			# If this path cell is already inside the dirt blob, let the blob
			# tiling pass handle it so the path blends in seamlessly.
			var tile_code: int = region.tiles[c.y * size + c.x]
			if overlay_code >= 0 and tile_code == overlay_code:
				continue
			if path_prim_cell.x >= 0:
				ground.set_cell(c, 0, path_prim_cell, 0)
			patch.erase_cell(c)
			var pidx: int = _path_index_for_cell(path_set, c.x, c.y, size)
			patch.set_cell(c, 0, overlay_cells[pidx], 0)

	# Decoration pass — trees/rocks/veins from `region.decorations`.
	for entry in region.decorations:
		var kind: StringName = entry["kind"]
		var cell: Vector2i = entry["cell"]
		var variants: Variant = TilesetCatalog.OVERWORLD_DECORATION_CELLS.get(kind, null)
		if variants == null:
			continue
		var arr: Array = variants
		if arr.is_empty():
			continue
		var idx: int = int(entry.get("variant", 0)) % arr.size()
		# sprites[] stores the TOP-LEFT atlas cell (x1y1 convention).
		# For 1×1 decorations this is the only cell.
		# For 2-tile-tall decorations: top-left = foliage (top), trunk = one row below.
		var top_left_atlas: Vector2i = arr[idx]
		if TilesetCatalog.is_tall_decoration(kind):
			# Paint trunk at ground cell on Decoration (player walks in front of it).
			decoration.set_cell(cell, 0, top_left_atlas + Vector2i(0, 1), 0)
			# Paint foliage on Canopy (draws above Entities so player walks behind it).
			var top_cell: Vector2i = cell + Vector2i(0, -1)
			if top_cell.y >= 0:
				canopy.set_cell(top_cell, 0, top_left_atlas, 0)
		else:
			decoration.set_cell(cell, 0, top_left_atlas, 0)
	# Water-grass border pass.
	var border_set: Array = TilesetCatalog.OVERWORLD_WATER_BORDER_GRASS_3X3
	for y2 in size:
		for x2 in size:
			var code2: int = region.tiles[y2 * size + x2]
			if not _is_water_code(code2):
				continue
			var bidx: int = _water_border_index(region, x2, y2, size)
			if bidx < 0:
				continue
			ground.set_cell(Vector2i(x2, y2), 0, border_set[bidx], 0)
	# Convex outer-corner pass.
	var corners: Dictionary = TilesetCatalog.OVERWORLD_WATER_OUTER_CORNERS
	for y3 in size:
		for x3 in size:
			var code3: int = region.tiles[y3 * size + x3]
			if not _is_water_code(code3):
				continue
			if _water_border_index(region, x3, y3, size) >= 0:
				continue
			var corner_dir: Vector2i = _water_outer_corner_dir(region, x3, y3, size)
			if corner_dir == Vector2i.ZERO:
				continue
			var tile: Variant = corners.get(corner_dir, null)
			if tile is Vector2i:
				ground.set_cell(Vector2i(x3, y3), 0, tile, 0)
	for rune in region.runes:
		var rc: Vector2i = rune["cell"]
		overlay.set_cell(rc, int(rune["source"]), rune["atlas"], 0)
	_paint_overworld_entrance_markers(region)


func _paint_interior(interior: InteriorMap, view_kind: StringName) -> void:
	if view_kind == &"dungeon" or view_kind == &"labyrinth":
		_paint_dungeon_interior(interior, view_kind)
		if view_kind == &"labyrinth" and not interior.boss_room_cells.is_empty():
			_paint_boss_room_overlay(interior)
		return
	if view_kind == &"house":
		_paint_room_walls(interior)
		_paint_room_furniture(interior)
		return
	for y in interior.height:
		for x in interior.width:
			var cell := Vector2i(x, y)
			var code: int = interior.at(cell)
			var terrain: StringName = TerrainCodes.to_terrain_type(code)
			var is_wall: bool = (code == TerrainCodes.INTERIOR_WALL
				or code == TerrainCodes.CITY_BUILDING_WALL)
			if is_wall:
				var floor_terrain: StringName = (&"sidewalk"
					if code == TerrainCodes.CITY_BUILDING_WALL else &"floor")
				var floor_cell: Vector2i = TilesetCatalog.cell_for(view_kind, floor_terrain)
				if floor_cell.x >= 0:
					ground.set_cell(cell, 0, floor_cell, 0)
				var wall_cell: Vector2i = TilesetCatalog.cell_for(view_kind, terrain)
				if wall_cell.x >= 0:
					decoration.set_cell(cell, 0, wall_cell, 0)
			else:
				var atlas_cell: Vector2i = TilesetCatalog.cell_for(view_kind, terrain)
				if atlas_cell.x >= 0:
					ground.set_cell(cell, 0, atlas_cell, 0)
				# Tall ground tiles (e.g. dungeon door) get canopy on Decoration.
				if atlas_cell.x >= 0 and TilesetCatalog.is_tall_tile(terrain):
					var canopy_cell: Vector2i = cell + Vector2i(0, -1)
					var canopy_atlas: Vector2i = atlas_cell + Vector2i(0, -1)
					if canopy_atlas.y >= 0:
						decoration.set_cell(canopy_cell, 0, canopy_atlas, 0)


## Derive the correct view_kind for an InteriorMap from its map_id.
static func _view_kind_from_interior(interior: InteriorMap) -> StringName:
	if interior == null:
		return &"overworld"
	return MapManager._kind_from_id(interior.map_id)


# --- Room-wall painting (house interiors) --------------------------

## Paint a house interior using the directional dungeon_sheet.png wall tiles
## (source_id=1 in the interior TileSet) and themed floor variants.
## Walls use a 2-pass autotile: cardinal floor-neighbor mask selects the row,
## diagonal checks resolve corner tiles (mask=0).
func _paint_room_walls(interior: InteriorMap) -> void:
	var style: StringName = interior.style if interior.style != &"" else &"wood"
	var wall_lut: Dictionary = (TilesetCatalog.HOUSE_WALL_WOOD_AUTOTILE
			if style == &"wood" else TilesetCatalog.HOUSE_WALL_STONE_AUTOTILE)
	var floor_pool: Array = (TilesetCatalog.HOUSE_FLOOR_WOOD
			if style == &"wood" else TilesetCatalog.HOUSE_FLOOR_STONE)
	var corner_cells: Array = TilesetCatalog.house_corner_cells(style)
	# Pick one floor variant for this house, seeded for determinism.
	var floor_idx: int = (interior.seed >> 3) % maxi(floor_pool.size(), 1)
	var floor_cell: Vector2i = floor_pool[floor_idx] if not floor_pool.is_empty() else Vector2i(19, 12)
	for y in interior.height:
		for x in interior.width:
			var cell := Vector2i(x, y)
			var code: int = interior.at(cell)
			if code == TerrainCodes.INTERIOR_DOOR:
				# Door: use interior_sheet floor on ground + door sprite on decoration.
				var gfloor: Vector2i = TilesetCatalog.cell_for(&"house", &"floor")
				if gfloor.x >= 0:
					ground.set_cell(cell, 0, gfloor, 0)
				var door_atlas: Vector2i = TilesetCatalog.cell_for(&"house", &"door")
				if door_atlas.x >= 0:
					ground.set_cell(cell, 0, door_atlas, 0)
				continue
			if _is_room_floor(interior, cell):
				ground.set_cell(cell, 1, floor_cell, 0)
				continue
			if code != TerrainCodes.INTERIOR_WALL:
				continue
			# Wall cell: compute floor-neighbor mask + diagonals.
			var fN: bool = _is_room_floor(interior, cell + Vector2i(0, -1))
			var fS: bool = _is_room_floor(interior, cell + Vector2i(0, 1))
			var fE: bool = _is_room_floor(interior, cell + Vector2i(1, 0))
			var fW: bool = _is_room_floor(interior, cell + Vector2i(-1, 0))
			var fNW: bool = _is_room_floor(interior, cell + Vector2i(-1, -1))
			var fNE: bool = _is_room_floor(interior, cell + Vector2i(1, -1))
			var fSW: bool = _is_room_floor(interior, cell + Vector2i(-1, 1))
			var fSE: bool = _is_room_floor(interior, cell + Vector2i(1, 1))
			var mask: int = (8 if fN else 0) | (4 if fS else 0) | (2 if fE else 0) | (1 if fW else 0)
			var atlas: Vector2i
			if mask == 0:
				# Corner or isolated: resolve via single diagonal.
				var diag_count: int = (1 if fSE else 0) + (1 if fSW else 0) + (1 if fNE else 0) + (1 if fNW else 0)
				if diag_count == 1:
					if fSE: atlas = corner_cells[0]   # NW corner
					elif fSW: atlas = corner_cells[1] # NE corner
					elif fNE: atlas = corner_cells[2] # SW corner
					else: atlas = corner_cells[3]     # SE corner
				else:
					# Multi-diagonal or isolated → solid center (row 3/8).
					atlas = Vector2i(19, 3 if style != &"wood" else 8)
			else:
				var entry: Variant = wall_lut.get(mask, null)
				if entry == null:
					continue
				atlas = entry as Vector2i
				# Refine column for N-wall (row with fS) and S-wall (row with fN):
				if mask == 4 or mask == 5 or mask == 6:
					atlas.x = _nwall_col(fW, fE)
				elif mask == 8 or mask == 9 or mask == 10:
					atlas.x = _nwall_col(fW, fE)
			# Place floor underneath wall, except for drip/perspective tiles whose
			# transparent tips would bleed the interior floor colour outside the room.
			var drip_row: int = 9 if style == &"wood" else 4
			if atlas.y != drip_row:
				ground.set_cell(cell, 1, floor_cell, 0)
			decoration.set_cell(cell, 1, atlas, 0)


## Returns the column (17-21) for a N-wall or S-wall cell based on
## whether the cell has floor immediately to its west and east.
static func _nwall_col(fW: bool, fE: bool) -> int:
	if fW: return 17   # floor to west → left end-cap
	if fE: return 21   # floor to east → right end-cap
	return 19          # wall on both sides → center


## Returns true if `cell` counts as "floor" for room-wall neighbor checks.
static func _is_room_floor(interior: InteriorMap, cell: Vector2i) -> bool:
	var code: int = interior.at(cell)
	return (code == TerrainCodes.INTERIOR_FLOOR
			or code == TerrainCodes.INTERIOR_DOOR
			or code == TerrainCodes.INTERIOR_STAIRS_UP
			or code == TerrainCodes.INTERIOR_STAIRS_DOWN)


## Paint furniture_scatter entries onto the Decoration layer using
## TilesetCatalog.INTERIOR_FURNITURE cells from interior_sheet.png (source_id=0).
func _paint_room_furniture(interior: InteriorMap) -> void:
	if interior.furniture_scatter.is_empty():
		return
	for entry in interior.furniture_scatter:
		var cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
		if cell.x < 0:
			continue
		var ftype: StringName = entry.get("type", &"")
		var atlas: Variant = TilesetCatalog.INTERIOR_FURNITURE.get(ftype, null)
		if atlas is Vector2i and (atlas as Vector2i).x >= 0:
			decoration.set_cell(cell, 0, atlas as Vector2i, 0)


## Returns true if `cell` falls within any chamber_rect in `interior`.
static func _is_in_chamber(cell: Vector2i, interior: InteriorMap) -> bool:
	for r in interior.chamber_rects:
		var rect: Rect2i = r
		if rect.has_point(cell):
			return true
	return false

func _paint_dungeon_interior(interior: InteriorMap, view_kind: StringName = &"dungeon") -> void:
	var ts: TileSet = TilesetCatalog.labyrinth() if view_kind == &"labyrinth" else TilesetCatalog.dungeon()
	var dim_layer: TileMapLayer = _ensure_dungeon_dim_layer(ts)
	dim_layer.clear()
	var floor_cell: Vector2i = TilesetCatalog.cell_for(view_kind, &"floor")
	var dim_seed: int = interior.map_id.hash()
	var floor_decor: Array = (TilesetCatalog.LABYRINTH_FLOOR_DECOR_CELLS
			if view_kind == &"labyrinth" else TilesetCatalog.DUNGEON_FLOOR_DECOR_CELLS)
	var wall_autotile: Dictionary = (TilesetCatalog.LABYRINTH_WALL_AUTOTILE
			if view_kind == &"labyrinth" else TilesetCatalog.DUNGEON_WALL_AUTOTILE)
	var decor_count: int = floor_decor.size()
	var has_chambers: bool = not interior.chamber_rects.is_empty()
	for y in interior.height:
		for x in interior.width:
			var cell := Vector2i(x, y)
			# Chamber cells: skip cave autotile; handled by _paint_room_walls pass below.
			if has_chambers and _is_in_chamber(cell, interior):
				continue
			var code: int = interior.at(cell)
			var is_floor_like: bool = (
					code == TerrainCodes.INTERIOR_FLOOR
					or code == TerrainCodes.INTERIOR_STAIRS_UP
					or code == TerrainCodes.INTERIOR_STAIRS_DOWN)
			if is_floor_like:
				ground.set_cell(cell, 0, floor_cell, 0)
				var h: int = (dim_seed ^ (x * 73856093) ^ (y * 19349663)) & 0x7fffffff
				if (h % 100) < 10 and decor_count > 0:
					var didx: int = (h >> 8) % decor_count
					decoration.set_cell(cell, 0, floor_decor[didx], 0)
				continue
			var mask: int = 0
			if _dungeon_neighbour_is_floor(interior, cell + Vector2i(0, -1)):
				mask |= 8
			if _dungeon_neighbour_is_floor(interior, cell + Vector2i(0, 1)):
				mask |= 4
			if _dungeon_neighbour_is_floor(interior, cell + Vector2i(1, 0)):
				mask |= 2
			if _dungeon_neighbour_is_floor(interior, cell + Vector2i(-1, 0)):
				mask |= 1
			if mask == 0:
				dim_layer.set_cell(cell, 0, floor_cell, 0)
				continue
			var entry: Variant = wall_autotile.get(mask, null)
			if entry == null:
				continue
			var arr: Array = entry
			var atlas: Vector2i = arr[0]
			var flip_v: bool = arr[1]
			var flip_h: bool = arr.size() > 2 and arr[2]
			var alt: int = 0
			if flip_v:
				alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
			if flip_h:
				alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
			decoration.set_cell(cell, 0, atlas, alt)
	# Paint chamber cells with stone room-wall tiles over the dungeon TileSet.
	# Chamber walls/floors use dungeon_sheet.png directly (same source as the
	# dungeon TileSet), so we write to source_id=0 (the only source in dungeon_ts).
	if has_chambers:
		_paint_dungeon_chambers(interior)
	# Floor border pass — overwrites Ground with edge/corner tiles where
	# floor meets wall. No-op when border_cells are all the plain floor cell.
	var floor_border: Array = (TilesetCatalog.LABYRINTH_FLOOR_BORDER_3X3
			if view_kind == &"labyrinth" else TilesetCatalog.DUNGEON_FLOOR_BORDER_3X3)
	_paint_dungeon_floor_border(interior, floor_border)
	_paint_dungeon_corridor_frames(interior)
	_paint_dungeon_stair_markers(interior)


## Paint chamber_rects inside a dungeon/labyrinth with stone room-wall tiles.
## The dungeon TileSet uses a single source (id=0) from dungeon_sheet.png, so
## room-wall cells (also on dungeon_sheet.png) are written to source_id=0.
func _paint_dungeon_chambers(interior: InteriorMap) -> void:
	var floor_pool: Array = TilesetCatalog.HOUSE_FLOOR_STONE
	var floor_idx: int = (interior.seed >> 3) % maxi(floor_pool.size(), 1)
	var floor_cell: Vector2i = floor_pool[floor_idx] if not floor_pool.is_empty() else Vector2i(19, 12)
	var wall_lut: Dictionary = TilesetCatalog.HOUSE_WALL_STONE_AUTOTILE
	var corner_cells: Array = TilesetCatalog.house_corner_cells(&"stone")
	for r in interior.chamber_rects:
		var rect: Rect2i = r
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				var cell := Vector2i(x, y)
				var code: int = interior.at(cell)
				if _is_room_floor(interior, cell):
					ground.set_cell(cell, 0, floor_cell, 0)
					decoration.erase_cell(cell)  # remove any cave decor
					continue
				if code != TerrainCodes.INTERIOR_WALL:
					continue
				var fN: bool = _is_room_floor(interior, cell + Vector2i(0, -1))
				var fS: bool = _is_room_floor(interior, cell + Vector2i(0, 1))
				var fE: bool = _is_room_floor(interior, cell + Vector2i(1, 0))
				var fW: bool = _is_room_floor(interior, cell + Vector2i(-1, 0))
				var fNW: bool = _is_room_floor(interior, cell + Vector2i(-1, -1))
				var fNE: bool = _is_room_floor(interior, cell + Vector2i(1, -1))
				var fSW: bool = _is_room_floor(interior, cell + Vector2i(-1, 1))
				var fSE: bool = _is_room_floor(interior, cell + Vector2i(1, 1))
				var mask: int = (8 if fN else 0) | (4 if fS else 0) | (2 if fE else 0) | (1 if fW else 0)
				var atlas: Vector2i
				if mask == 0:
					var diag_count: int = (1 if fSE else 0) + (1 if fSW else 0) + (1 if fNE else 0) + (1 if fNW else 0)
					if diag_count == 1:
						if fSE: atlas = corner_cells[0]
						elif fSW: atlas = corner_cells[1]
						elif fNE: atlas = corner_cells[2]
						else: atlas = corner_cells[3]
					else:
						atlas = Vector2i(19, 4)
				else:
					var entry: Variant = wall_lut.get(mask, null)
					if entry == null:
						continue
					atlas = entry as Vector2i
					if mask == 4 or mask == 5 or mask == 6 or mask == 8 or mask == 9 or mask == 10:
						atlas.x = _nwall_col(fW, fE)
				ground.set_cell(cell, 0, floor_cell, 0)
				decoration.set_cell(cell, 0, atlas, 0)


## Paint a distinct floor decor pattern over boss room cells.
func _paint_boss_room_overlay(interior: InteriorMap) -> void:
	var decor: Array = TilesetCatalog.LABYRINTH_FLOOR_DECOR_CELLS
	if decor.is_empty():
		return
	var boss_tile: Vector2i = decor[decor.size() - 1]
	for cell_var in interior.boss_room_cells:
		var cell: Vector2i = cell_var
		if (cell.x + cell.y) % 2 == 0:
			decoration.set_cell(cell, 0, boss_tile, 0)


## Overwrite the Ground layer for every floor-like cell with the
## matching 3×3 border cell so floors that meet walls get edge art.
## Cells whose border resolves to index 4 (open centre) keep the plain
## floor cell — the border and floor cell are the same when no 3×3 is
## configured, so this is always safe to call.
func _paint_dungeon_floor_border(interior: InteriorMap,
		border_cells: Array) -> void:
	if border_cells.size() < 9:
		return
	for y in interior.height:
		for x in interior.width:
			var cell := Vector2i(x, y)
			var code: int = interior.at(cell)
			var is_floor_like: bool = (
					code == TerrainCodes.INTERIOR_FLOOR
					or code == TerrainCodes.INTERIOR_STAIRS_UP
					or code == TerrainCodes.INTERIOR_STAIRS_DOWN)
			if not is_floor_like:
				continue
			var bidx: int = _dungeon_floor_border_index(interior, cell)
			var atlas: Vector2i = border_cells[bidx]
			ground.set_cell(cell, 0, atlas, 0)


func _paint_dungeon_corridor_frames(interior: InteriorMap) -> void:
	var root: Node2D = _ensure_corridor_frame_root()
	for c in root.get_children():
		c.queue_free()
	var tex: Texture2D = load(TilesetCatalog.DUNGEON_PNG) as Texture2D
	if tex == null:
		return
	var w: int = interior.width
	var h: int = interior.height
	for y in range(1, h - 2):
		var x: int = 1
		while x < w - 1:
			if not _is_corridor_exit_left_edge(interior, x, y, w, h):
				x += 1
				continue
			var x_end: int = x
			while x_end + 1 < w \
					and interior.at(Vector2i(x_end + 1, y)) == TerrainCodes.INTERIOR_FLOOR \
					and interior.at(Vector2i(x_end + 1, y - 1)) == TerrainCodes.INTERIOR_FLOOR \
					and interior.at(Vector2i(x_end + 1, y + 1)) == TerrainCodes.INTERIOR_FLOOR:
				x_end += 1
			if x_end + 1 >= w \
					or interior.at(Vector2i(x_end + 1, y)) != TerrainCodes.INTERIOR_WALL \
					or interior.at(Vector2i(x_end + 1, y + 1)) != TerrainCodes.INTERIOR_FLOOR:
				x = x_end + 1
				continue
			_spawn_corridor_frame(root, tex, x - 1, x_end + 1, y)
			x = x_end + 1


static func _is_corridor_exit_left_edge(interior: InteriorMap, x: int, y: int,
		w: int, h: int) -> bool:
	if x <= 0 or x >= w - 1 or y <= 0 or y >= h - 2:
		return false
	if interior.at(Vector2i(x, y)) != TerrainCodes.INTERIOR_FLOOR:
		return false
	if interior.at(Vector2i(x, y - 1)) != TerrainCodes.INTERIOR_FLOOR:
		return false
	if interior.at(Vector2i(x, y + 1)) != TerrainCodes.INTERIOR_FLOOR:
		return false
	if interior.at(Vector2i(x - 1, y)) != TerrainCodes.INTERIOR_WALL:
		return false
	if interior.at(Vector2i(x - 1, y + 1)) != TerrainCodes.INTERIOR_FLOOR:
		return false
	return true


func _spawn_corridor_frame(root: Node2D, tex: Texture2D,
		west_col: int, east_col: int, top_row: int) -> void:
	_spawn_frame_sprite(root, tex,
		TilesetCatalog.DUNGEON_DOORFRAME_TL, west_col, top_row)
	for cx in range(west_col + 1, east_col):
		_spawn_frame_sprite(root, tex,
			TilesetCatalog.DUNGEON_DOORFRAME_TOP, cx, top_row)
	_spawn_frame_sprite(root, tex,
		TilesetCatalog.DUNGEON_DOORFRAME_TR, east_col, top_row)
	_spawn_frame_sprite(root, tex,
		TilesetCatalog.DUNGEON_DOORFRAME_LW,  west_col, top_row + 1)
	_spawn_frame_sprite(root, tex,
		TilesetCatalog.DUNGEON_DOORFRAME_LW2, west_col, top_row + 2)
	_spawn_frame_sprite(root, tex,
		TilesetCatalog.DUNGEON_DOORFRAME_RW,  east_col, top_row + 1)
	_spawn_frame_sprite(root, tex,
		TilesetCatalog.DUNGEON_DOORFRAME_RW2, east_col, top_row + 2)


func _spawn_frame_sprite(root: Node2D, tex: Texture2D, atlas: Vector2i,
		cx: int, cy: int) -> void:
	var tile_px: int = WorldConst.TILE_PX
	var margin: int = WorldConst.TILESHEET_MARGIN
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.region_enabled = true
	spr.region_rect = Rect2(
		atlas.x * (tile_px + margin),
		atlas.y * (tile_px + margin),
		tile_px, tile_px)
	spr.centered = false
	spr.position = Vector2(float(cx * tile_px), float(cy * tile_px))
	root.add_child(spr)


func _ensure_corridor_frame_root() -> Node2D:
	var existing: Node = get_node_or_null("CaveDoorFrames")
	if existing is Node2D:
		return existing as Node2D
	var root := Node2D.new()
	root.name = "CaveDoorFrames"
	root.z_index = 2
	add_child(root)
	return root


func _paint_dungeon_stair_markers(interior: InteriorMap) -> void:
	var root: Node2D = _ensure_stair_marker_root()
	for c in root.get_children():
		c.queue_free()
	var tile_px: float = float(WorldConst.TILE_PX)
	var sz := Vector2(tile_px, tile_px)
	for y in interior.height:
		for x in interior.width:
			var cell := Vector2i(x, y)
			var code: int = interior.at(cell)
			var color: Color
			if code == TerrainCodes.INTERIOR_STAIRS_UP:
				color = Color(1.0, 1.0, 0.0, 0.5)
			elif code == TerrainCodes.INTERIOR_STAIRS_DOWN:
				color = Color(1.0, 0.0, 0.0, 0.5)
			else:
				continue
			var rect := ColorRect.new()
			rect.color = color
			rect.size = sz
			rect.position = Vector2(float(x) * tile_px, float(y) * tile_px)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(rect)


func _ensure_stair_marker_root() -> Node2D:
	var existing: Node = get_node_or_null("StairMarkers")
	if existing is Node2D:
		return existing as Node2D
	var root := Node2D.new()
	root.name = "StairMarkers"
	root.z_index = 1
	add_child(root)
	return root


static func _dungeon_neighbour_is_floor(interior: InteriorMap, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= interior.width or c.y >= interior.height:
		return false
	var code: int = interior.at(c)
	return (code == TerrainCodes.INTERIOR_FLOOR
			or code == TerrainCodes.INTERIOR_STAIRS_UP
			or code == TerrainCodes.INTERIOR_STAIRS_DOWN)


## Returns the NW…SE index (0..8) into the floor-border 3×3 for a floor
## cell, based on which orthogonal neighbours are wall (not floor-like).
static func _dungeon_floor_border_index(interior: InteriorMap,
		cell: Vector2i) -> int:
	var n_floor: bool = _dungeon_neighbour_is_floor(interior, cell + Vector2i(0, -1))
	var s_floor: bool = _dungeon_neighbour_is_floor(interior, cell + Vector2i(0,  1))
	var w_floor: bool = _dungeon_neighbour_is_floor(interior, cell + Vector2i(-1, 0))
	var e_floor: bool = _dungeon_neighbour_is_floor(interior, cell + Vector2i( 1, 0))
	# Corner cases first (two open sides meeting a wall corner).
	if not n_floor and not w_floor: return 0  # NW
	if not n_floor and not e_floor: return 2  # NE
	if not s_floor and not w_floor: return 6  # SW
	if not s_floor and not e_floor: return 8  # SE
	# Edge cases (one open side).
	if not n_floor: return 1  # N
	if not s_floor: return 7  # S
	if not w_floor: return 3  # W
	if not e_floor: return 5  # E
	return 4  # fully surrounded by floor — open centre


func _ensure_dungeon_dim_layer(ts: TileSet) -> TileMapLayer:
	var existing: Node = get_node_or_null("DungeonDim")
	if existing is TileMapLayer:
		var tml: TileMapLayer = existing as TileMapLayer
		tml.tile_set = ts
		return tml
	var layer := TileMapLayer.new()
	layer.name = "DungeonDim"
	layer.tile_set = ts
	layer.modulate = Color(0.5, 0.5, 0.5, 1.0)
	layer.z_index = -1
	add_child(layer)
	move_child(layer, ground.get_index() + 1)
	return layer


# --- Overworld cave-entrance markers --------------------------------

func _paint_overworld_entrance_markers(region: Region) -> void:
	var root: Node2D = _ensure_entrance_marker_root()
	for c in root.get_children():
		c.queue_free()
	var dungeon_tex: Texture2D = load(TilesetCatalog.DUNGEON_PNG) as Texture2D
	var house_tex: Texture2D = load(TilesetCatalog.MEDIEVAL_RTS_PNG) as Texture2D
	var tile_px: int = WorldConst.TILE_PX
	var margin: int = WorldConst.TILESHEET_MARGIN
	var cells: Array = TilesetCatalog.DUNGEON_OVERWORLD_ENTRANCE_CELLS
	for entry in region.dungeon_entrances:
		var base: Vector2i = entry["cell"]
		var ek: StringName = entry.get("kind", &"dungeon")
		if ek == &"house":
			if house_tex == null:
				continue
			var spr := Sprite2D.new()
			spr.texture = house_tex
			spr.region_enabled = true
			spr.region_rect = Rect2(TilesetCatalog.HOUSE_OVERWORLD_RECT)
			spr.scale = Vector2(float(tile_px) / 64.0, float(tile_px) / 64.0)
			spr.centered = false
			spr.position = Vector2(float(base.x * tile_px), float(base.y * tile_px))
			root.add_child(spr)
			continue
		if dungeon_tex == null:
			continue
		var tint: Color
		var cells_to_use: Array
		if ek == &"labyrinth":
			tint = Color(1.2, 0.6, 1.4)   # purple
			cells_to_use = TilesetCatalog.LABYRINTH_OVERWORLD_ENTRANCE_CELLS
		else:
			tint = Color.WHITE
			cells_to_use = cells
		for i in cells_to_use.size():
			var atlas: Vector2i = cells_to_use[i]
			var spr := Sprite2D.new()
			spr.texture = dungeon_tex
			spr.region_enabled = true
			spr.region_rect = Rect2(
				atlas.x * (tile_px + margin),
				atlas.y * (tile_px + margin),
				tile_px, tile_px)
			spr.centered = false
			spr.position = Vector2(
				float((base.x + i) * tile_px),
				float(base.y * tile_px))
			spr.modulate = tint
			root.add_child(spr)



func _ensure_entrance_marker_root() -> Node2D:
	var existing: Node = get_node_or_null("EntranceMarkers")
	if existing is Node2D:
		return existing as Node2D
	var root := Node2D.new()
	root.name = "EntranceMarkers"
	root.z_index = 1
	add_child(root)
	return root


# --- Helpers -------------------------------------------------------

static func _patch_index_for_neighbors(region: Region, x: int, y: int,
		secondary: int, size: int) -> int:
	var n_sec: bool = (y > 0
		and region.tiles[(y - 1) * size + x] == secondary)
	var s_sec: bool = (y < size - 1
		and region.tiles[(y + 1) * size + x] == secondary)
	var w_sec: bool = (x > 0
		and region.tiles[y * size + (x - 1)] == secondary)
	var e_sec: bool = (x < size - 1
		and region.tiles[y * size + (x + 1)] == secondary)
	var cnt: int = int(n_sec) + int(s_sec) + int(w_sec) + int(e_sec)

	if cnt == 0:
		return 19  # isolated dot

	if cnt == 1:
		if n_sec: return 16  # dead-end S (only north neighbour → open end faces S)
		if s_sec: return 15  # dead-end N
		if w_sec: return 18  # dead-end E
		if e_sec: return 17  # dead-end W

	if cnt == 2:
		# Straight-through paths
		if n_sec and s_sec: return 13  # N+S straight
		if w_sec and e_sec: return 14  # E+W straight
		# Outer corners (two adjacent sides are NOT secondary)
		if not n_sec and not w_sec: return 0  # NW outer
		if not n_sec and not e_sec: return 2  # NE outer
		if not s_sec and not w_sec: return 6  # SW outer
		if not s_sec and not e_sec: return 8  # SE outer

	if cnt == 3:
		if not n_sec: return 1  # N edge
		if not s_sec: return 7  # S edge
		if not w_sec: return 3  # W edge
		if not e_sec: return 5  # E edge

	# cnt == 4: all cardinal neighbours are secondary — check diagonals.
	# A single primary diagonal = concave inner-corner tile.
	# Out-of-bounds diagonals treated as primary.
	var nw_prim: bool = x == 0 or y == 0 or region.tiles[(y - 1) * size + (x - 1)] != secondary
	var ne_prim: bool = x == size - 1 or y == 0 or region.tiles[(y - 1) * size + (x + 1)] != secondary
	var sw_prim: bool = x == 0 or y == size - 1 or region.tiles[(y + 1) * size + (x - 1)] != secondary
	var se_prim: bool = x == size - 1 or y == size - 1 or region.tiles[(y + 1) * size + (x + 1)] != secondary
	var dcnt: int = int(nw_prim) + int(ne_prim) + int(sw_prim) + int(se_prim)
	if dcnt == 1:
		if nw_prim: return 9   # inner NW
		if ne_prim: return 10  # inner NE
		if sw_prim: return 11  # inner SW
		if se_prim: return 12  # inner SE
	return 4  # fully surrounded (center)


## Bitmask → path tile index. bit0=N, bit1=S, bit2=E, bit3=W.
## Indices 13-19 match the 20-tile overlay set (straight/dead-end/isolated).
## Indices 20-28 are the new corner/T-junction/cross tiles.
const PATH_BITMASK_TO_INDEX: Array[int] = [
	19, # 0000 = no connections → isolated
	16, # 0001 = N only → dead-end (open end toward N)
	15, # 0010 = S only → dead-end (open end toward S)
	13, # 0011 = N+S → straight vertical
	17, # 0100 = E only → dead-end (open end toward E)
	20, # 0101 = N+E → corner cNE
	22, # 0110 = S+E → corner cSE
	24, # 0111 = N+S+E → T-junction missing W (tW)
	18, # 1000 = W only → dead-end (open end toward W)
	21, # 1001 = N+W → corner cNW
	23, # 1010 = S+W → corner cSW
	26, # 1011 = N+S+W → T-junction missing E (tE)
	14, # 1100 = E+W → straight horizontal
	25, # 1101 = N+E+W → T-junction missing S (tS)
	27, # 1110 = S+E+W → T-junction missing N (tN)
	28, # 1111 = all four → cross (+)
]

## Returns the overlay tile index for a path cell based on its 4 cardinal
## path-set neighbours. `path_set` maps Vector2i → true for all path cells.
static func _path_index_for_cell(path_set: Dictionary, x: int, y: int, size: int) -> int:
	var mask: int = 0
	if y > 0        and path_set.has(Vector2i(x, y - 1)): mask |= 1  # N
	if y < size - 1 and path_set.has(Vector2i(x, y + 1)): mask |= 2  # S
	if x < size - 1 and path_set.has(Vector2i(x + 1, y)): mask |= 4  # E
	if x > 0        and path_set.has(Vector2i(x - 1, y)): mask |= 8  # W
	return PATH_BITMASK_TO_INDEX[mask]


static func _is_water_code(code: int) -> bool:
	return code == TerrainCodes.OCEAN or code == TerrainCodes.WATER


static func _water_border_index(region: Region, x: int, y: int,
		size: int) -> int:
	var n_water: bool = (y == 0
		or _is_water_code(region.tiles[(y - 1) * size + x]))
	var s_water: bool = (y == size - 1
		or _is_water_code(region.tiles[(y + 1) * size + x]))
	var w_water: bool = (x == 0
		or _is_water_code(region.tiles[y * size + (x - 1)]))
	var e_water: bool = (x == size - 1
		or _is_water_code(region.tiles[y * size + (x + 1)]))
	if not n_water and not w_water: return 0  # NW
	if not n_water and not e_water: return 2  # NE
	if not s_water and not w_water: return 6  # SW
	if not s_water and not e_water: return 8  # SE
	if not n_water: return 1  # N edge
	if not s_water: return 7  # S edge
	if not w_water: return 3  # W edge
	if not e_water: return 5  # E edge
	return -1  # all neighbours are water


static func _water_outer_corner_dir(region: Region, x: int, y: int,
		size: int) -> Vector2i:
	var dirs: Array = [
		Vector2i(-1, -1), Vector2i( 1, -1),
		Vector2i(-1,  1), Vector2i( 1,  1),
	]
	for d in dirs:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or nx >= size or ny < 0 or ny >= size:
			continue
		if not _is_water_code(region.tiles[ny * size + nx]):
			return d
	return Vector2i.ZERO


func _clear_layers() -> void:
	ground.clear()
	patch.clear()
	decoration.clear()
	overlay.clear()
	var dim: Node = get_node_or_null("DungeonDim")
	if dim is TileMapLayer:
		(dim as TileMapLayer).clear()
	var markers: Node = get_node_or_null("EntranceMarkers")
	if markers != null:
		for c in markers.get_children():
			c.queue_free()
	var frames: Node = get_node_or_null("CaveDoorFrames")
	if frames != null:
		for c in frames.get_children():
			c.queue_free()
	var stairs: Node = get_node_or_null("StairMarkers")
	if stairs != null:
		for c in stairs.get_children():
			c.queue_free()
	# Free any scattered NPCs so the next view paints fresh.
	if entities != null:
		for c in entities.get_children():
			if c.is_in_group(&"scattered_npcs"):
				c.queue_free()
	# Hide any open dialogue so it doesn't bleed across view changes.
	hide_dialogue()


# Stable per-cell 32-bit hash for deterministic variant rolls.
static func _cell_hash(cell: Vector2i, seed_value: int) -> int:
	return (seed_value ^ (cell.x * 73856093) ^ (cell.y * 19349663)) & 0x7fffffff


# --- Spawn helpers -------------------------------------------------

func find_safe_spawn_cell(centre: Vector2i, max_radius: int = 16,
		avoid_doors: bool = true) -> Vector2i:
	if avoid_doors:
		var c1: Variant = _scan_for(centre, max_radius, true)
		if c1 != null:
			return c1
	var c2: Variant = _scan_for(centre, max_radius, false)
	if c2 != null:
		return c2
	return centre


func _scan_for(centre: Vector2i, max_radius: int, avoid_doors: bool) -> Variant:
	if is_walkable(centre) and (not avoid_doors or not _doors.has(centre)):
		return centre
	for r in range(1, max_radius):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if max(abs(dx), abs(dy)) != r:
					continue
				var c := centre + Vector2i(dx, dy)
				if is_walkable(c) and (not avoid_doors or not _doors.has(c)):
					return c
	return null


func default_spawn_cell(view_kind: StringName, region: Region,
		interior: InteriorMap) -> Vector2i:
	if view_kind != &"overworld" and interior != null:
		if interior.entry_cell != Vector2i.ZERO:
			return find_safe_spawn_cell(interior.entry_cell)
		return find_safe_spawn_cell(Vector2i(interior.width / 2, interior.height / 2))
	if region != null:
		if not region.spawn_points.is_empty():
			return find_safe_spawn_cell(region.spawn_points[0])
		return find_safe_spawn_cell(Vector2i(Region.SIZE / 2, Region.SIZE / 2))
	return Vector2i.ZERO


## Return the entrance metadata at [param cell], or empty dict if none.
func get_entrance_at(cell: Vector2i) -> Dictionary:
	if _region == null:
		return {}
	for entry in _region.dungeon_entrances:
		if entry.get("cell", Vector2i(-1, -1)) == cell:
			return entry
	return {}


# --- Boat spawning -------------------------------------------------

func _ensure_boat() -> void:
	if _boat != null and is_instance_valid(_boat):
		return
	var dock: Vector2i = _find_dock_cell()
	if dock == Vector2i(-1, -1):
		return
	_boat = _BoatScene.instantiate() as Boat
	_boat.dock_cell = dock
	_boat.position = (Vector2(dock) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
	entities.add_child(_boat)


func _find_dock_cell() -> Vector2i:
	var centre: Vector2i = Vector2i(Region.SIZE / 2, Region.SIZE / 2)
	var sz: int = Region.SIZE if _interior == null else _interior.width
	for r in range(1, sz):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if max(abs(dx), abs(dy)) != r:
					continue
				var c := centre + Vector2i(dx, dy)
				if _is_water_cell(c) and _has_walkable_neighbour(c):
					return c
	return Vector2i(-1, -1)


func _is_water_cell(c: Vector2i) -> bool:
	var t: StringName = get_terrain_at(c)
	return t == &"water" or t == &"deep_water"


func _has_walkable_neighbour(c: Vector2i) -> bool:
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		if is_walkable(c + d):
			return true
	return false


# --- Door / interior transitions ------------------------------------

func _physics_process(_delta: float) -> void:
	for p in get_player_cache():
		var cell: Vector2i = Vector2i(
				int(floor(p.position.x / float(WorldConst.TILE_PX))),
				int(floor(p.position.y / float(WorldConst.TILE_PX))))
		var prev: Variant = _last_door_cell_per_player.get(p, null)
		if prev != null and (prev as Vector2i) == cell:
			continue
		_last_door_cell_per_player[p] = cell
		var door: Variant = _doors.get(cell, null)
		if door == null:
			continue
		_handle_door(p, door, cell)


func _process(delta: float) -> void:
	# LOD sleep/wake check — runs every LOD_CHECK_INTERVAL seconds.
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_tick_lod()
		_lod_timer = LOD_CHECK_INTERVAL
	# Chest interaction — check each player's interact input.
	for pid in range(2):
		var input_ctx: InputContext.Context = InputContext.get_context(pid)
		if input_ctx != InputContext.Context.GAMEPLAY:
			continue
		var action: StringName = PlayerActions.action(pid, PlayerActions.INTERACT)
		if not Input.is_action_just_pressed(action):
			continue
		var player: PlayerController = get_player(pid)
		if player == null or not is_instance_valid(player):
			continue
		for child in entities.get_children():
			if not (child is TreasureChest):
				continue
			var chest: TreasureChest = child
			if chest.is_opened:
				continue
			if chest.is_player_in_range(player):
				chest.open(player)
				break


func _build_door_index(view_kind: StringName) -> void:
	_doors.clear()
	if view_kind == &"overworld" and _region != null:
		for entry in _region.dungeon_entrances:
			var c: Vector2i = entry["cell"]
			var ek: StringName = entry.get("kind", &"dungeon")
			if ek == &"house":
				_doors[c] = {"kind": &"house_enter", "cell": c,
						"style": entry.get("style", &"wood")}
			elif ek == &"labyrinth":
				_doors[c] = {"kind": &"labyrinth_enter", "cell": c}
			else:
				_doors[c] = {"kind": &"dungeon_enter", "cell": c}
		for rune in _region.runes:
			var rc: Vector2i = rune["cell"]
			_doors[rc] = {"kind": &"rune", "cell": rc, "source": int(rune["source"])}
	elif _interior != null:
		if view_kind == &"dungeon" or view_kind == &"labyrinth":
			_doors[_interior.entry_cell] = {"kind": &"stairs_up"}
			_doors[_interior.exit_cell] = {"kind": &"stairs_down"}
		else:
			_doors[_interior.exit_cell] = {"kind": &"interior_exit"}


func _handle_door(player: PlayerController, door: Dictionary, cell: Vector2i) -> void:
	match door["kind"]:
		&"rune":
			last_rune_message = "Player %d touched an ancient symbol (color=%d)" % [player.player_id + 1, int(door["source"])]
			print(last_rune_message)
		&"dungeon_enter":
			_handle_enter_interior(player, cell, &"dungeon")
		&"house_enter":
			Sfx.play(&"dungeon_enter")
			var hrid: Vector2i = _region.region_id
			var hmid: StringName = MapManager.make_id(hrid, cell, 1, &"house")
			var hstyle: StringName = door.get("style", &"wood")
			var house: InteriorMap = MapManager.get_or_generate(
					hmid, hrid, cell, 1,
					MapManager.DEFAULT_FLOOR_SIZE, &"house", hstyle)
			World.instance().transition_player(player.player_id, &"house", _region, house)
		&"labyrinth_enter":
			_handle_enter_interior(player, cell, &"labyrinth")
		&"interior_exit":
			if _interior != null:
				Sfx.play(&"dungeon_exit")
				var origin: Vector2i = _interior.origin_cell
				var origin_region: Region = WorldManager.get_or_generate(_interior.origin_region_id)
				World.instance().transition_player(player.player_id, &"overworld", origin_region, null, origin)
		&"stairs_up":
			if _interior == null:
				return
			var pid_up: int = player.player_id
			var exit_origin: Vector2i = _interior.origin_cell
			var exit_rid: Vector2i = _interior.origin_region_id
			if _interior.parent_map_id == &"":
				# Floor 1 stairs up → exit to surface. Offer cancel.
				var game_up: Game = Game.instance()
				if game_up != null:
					game_up.show_floor_confirm_menu(pid_up,
							"Stairs leading up...",
							["Exit to Surface", "Stay on Floor %d" % _interior.floor_num],
							func(idx: int) -> void:
								if idx == 0:
									_play_cave_transition(pid_up,
											func() -> void:
												Sfx.play(&"dungeon_exit")
												var r: Region = WorldManager.get_or_generate(exit_rid)
												World.instance().transition_player(
														pid_up, &"overworld", r, null, exit_origin)))
				else:
					# Headless / no Game fallback.
					_play_cave_transition(pid_up, func() -> void:
						Sfx.play(&"dungeon_exit")
						var r: Region = WorldManager.get_or_generate(exit_rid)
						World.instance().transition_player(pid_up, &"overworld", r, null, exit_origin))
			else:
				var parent: InteriorMap = MapManager.get_parent_interior(_interior)
				if parent == null:
					return
				var parent_cell: Vector2i = _interior.parent_entrance_cell
				var origin_r: Region = WorldManager.get_or_generate(_interior.origin_region_id)
				var parent_kind: StringName = WorldRoot._view_kind_from_interior(parent)
				var game_up2: Game = Game.instance()
				if game_up2 != null:
					game_up2.show_floor_confirm_menu(pid_up,
							"Stairs leading up...",
							["Ascend to Floor %d" % parent.floor_num,
							"Exit to Surface"],
							func(idx: int) -> void:
								if idx == 0:
									_play_cave_transition(pid_up,
											func() -> void:
												Sfx.play(&"dungeon_exit")
												World.instance().transition_player(
														pid_up, parent_kind, origin_r, parent, parent_cell),
											"Floor %d" % parent.floor_num)
								else:
									_play_cave_transition(pid_up,
											func() -> void:
												Sfx.play(&"dungeon_exit")
												var r: Region = WorldManager.get_or_generate(exit_rid)
												World.instance().transition_player(
														pid_up, &"overworld", r, null, exit_origin)))
				else:
					_play_cave_transition(pid_up, func() -> void:
						Sfx.play(&"dungeon_exit")
						World.instance().transition_player(pid_up, parent_kind, origin_r, parent, parent_cell),
						"Floor %d" % parent.floor_num)
		&"stairs_down":
			if _interior == null:
				return
			var deeper: InteriorMap = MapManager.descend_from(_interior)
			if deeper == null:
				return
			var entry_cell: Vector2i = deeper.entry_cell
			var pid3: int = player.player_id
			var deeper_kind: StringName = WorldRoot._view_kind_from_interior(deeper)
			var origin_r3: Region = WorldManager.get_or_generate(_interior.origin_region_id)
			var exit_origin3: Vector2i = _interior.origin_cell
			var exit_rid3: Vector2i = _interior.origin_region_id
			var game3: Game = Game.instance()
			if game3 != null:
				game3.show_floor_confirm_menu(pid3,
						"Stairs leading down...",
						["Descend to Floor %d" % deeper.floor_num,
						"Exit to Surface"],
						func(idx: int) -> void:
							if idx == 0:
								_play_cave_transition(pid3,
										func() -> void:
											Sfx.play(&"dungeon_enter")
											World.instance().transition_player(
													pid3, deeper_kind, origin_r3, deeper, entry_cell),
										"Floor %d" % deeper.floor_num)
							else:
								_play_cave_transition(pid3,
										func() -> void:
											Sfx.play(&"dungeon_exit")
											var r3: Region = WorldManager.get_or_generate(exit_rid3)
											World.instance().transition_player(
													pid3, &"overworld", r3, null, exit_origin3)))
			else:
				_play_cave_transition(pid3, func() -> void:
					Sfx.play(&"dungeon_enter")
					World.instance().transition_player(pid3, deeper_kind, origin_r3, deeper, entry_cell),
					"Floor %d" % deeper.floor_num)


## Common handler for dungeon/labyrinth overworld entrances. Checks if the
## player has been here before and offers a resume prompt if so.
func _handle_enter_interior(player: PlayerController, cell: Vector2i,
		kind: StringName) -> void:
	var rid: Vector2i = _region.region_id
	# Deterministic size for labyrinths derived from the entrance seed.
	var lsize: int = MapManager.DEFAULT_FLOOR_SIZE
	if kind == &"labyrinth":
		var rng := RandomNumberGenerator.new()
		rng.seed = MapManager.make_id(rid, cell, 1, kind).hash()
		lsize = rng.randi_range(64, 96)
	var mid: StringName = MapManager.make_id(rid, cell, 1, kind)
	var floor1: InteriorMap = MapManager.get_or_generate(mid, rid, cell, 1, lsize, kind)
	var pid_e: int = player.player_id
	var deepest: InteriorMap = MapManager.get_deepest_cached_interior(rid, cell, kind)
	if deepest != null and deepest.floor_num > 1:
		# Player has explored beyond floor 1 — offer resume.
		var game_e: Game = Game.instance()
		if game_e != null:
			game_e.show_floor_confirm_menu(pid_e,
					"Return to %s?" % String(kind).capitalize(),
					["Resume at Floor %d" % deepest.floor_num,
					"Start from Floor 1"],
					func(idx: int) -> void:
						var target: InteriorMap = deepest if idx == 0 else floor1
						var target_kind: StringName = WorldRoot._view_kind_from_interior(target)
						_play_cave_transition(pid_e,
								func() -> void:
									Sfx.play(&"dungeon_enter")
									World.instance().transition_player(
											pid_e, target_kind, _region, target),
								"Floor %d" % target.floor_num))
			return
	# First visit (or only floor 1 in cache): enter directly with fade.
	_play_cave_transition(pid_e, func() -> void:
		Sfx.play(&"dungeon_enter")
		var entry_kind: StringName = WorldRoot._view_kind_from_interior(floor1)
		World.instance().transition_player(pid_e, entry_kind, _region, floor1),
		"Floor 1")


func _play_cave_transition(pid: int, switch_fn: Callable,
		floor_label: String = "") -> void:
	var game: Game = Game.instance()
	if game != null:
		game.play_floor_transition(pid, floor_label, switch_fn)
		return
	# Fallback path: no Game available (e.g. headless tests).
	var fade: ColorRect = _ensure_fade_overlay()
	fade.color.a = 0.0
	var fade_out := create_tween()
	fade_out.tween_property(fade, "color:a", 1.0, 0.18)
	fade_out.tween_property(fade, "color:a", 1.0, 0.05)
	await fade_out.finished
	switch_fn.call()
	var fade_in := create_tween()
	fade_in.tween_property(fade, "color:a", 0.0, 0.28)


func _ensure_fade_overlay() -> ColorRect:
	var existing: Node = get_node_or_null("FadeLayer/FadeRect")
	if existing is ColorRect:
		return existing as ColorRect
	var layer := CanvasLayer.new()
	layer.name = "FadeLayer"
	layer.layer = 50
	add_child(layer)
	var rect := ColorRect.new()
	rect.name = "FadeRect"
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	return rect


# --- Mining --------------------------------------------------------

func _build_mineable_index() -> void:
	_mineable.clear()
	if _region == null:
		return
	for entry in _region.decorations:
		var k: StringName = entry["kind"]
		if not MINEABLE_HP.has(k):
			continue
		_mineable[entry["cell"]] = {"kind": k, "hp": int(MINEABLE_HP[k])}


func mine_at(cell: Vector2i, damage: int) -> Dictionary:
	var entry: Variant = _mineable.get(cell, null)
	if entry == null:
		return {"hit": false}
	var e: Dictionary = entry
	e["hp"] = int(e["hp"]) - damage
	if e["hp"] > 0:
		_mineable[cell] = e
		return {"hit": true, "destroyed": false, "kind": e["kind"], "hp": e["hp"]}
	_mineable.erase(cell)
	decoration.set_cell(cell, -1)
	# Clear foliage on Canopy layer for tall decorations.
	if TilesetCatalog.is_tall_decoration(e["kind"]):
		canopy.set_cell(cell + Vector2i(0, -1), -1)
	overlay.set_cell(cell, -1)
	var drops: Array = MINEABLE_DROPS.get(e["kind"], [])
	return {"hit": true, "destroyed": true, "kind": e["kind"], "drops": drops}


# --- Scattered NPC spawning ----------------------------------------

const _VillagerScene: PackedScene = preload("res://scenes/entities/Villager.tscn")
const _MonsterScene: PackedScene = preload("res://scenes/entities/Monster.tscn")
const _TreasureChestScene: PackedScene = preload("res://scenes/entities/TreasureChest.tscn")

func _spawn_scattered_npcs() -> void:
	_maybe_inject_mara()
	var entries: Array = []
	if _interior != null:
		entries = _interior.npcs_scatter
	elif _region != null:
		entries = _region.npcs_scatter
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var kind: StringName = entry.get("kind", &"")
		match kind:
			&"villager":
				_spawn_villager(entry)
			&"monster":
				_spawn_monster(entry)
			_:
				# Try loot-table creature kinds (slime, skeleton, etc.)
				if LootTableRegistry.has_table(kind):
					entry["monster_kind"] = kind
					_spawn_monster(entry)
	# Boss room — spawn boss + adds if this is a labyrinth boss floor.
	if _interior != null and not _interior.boss_data.is_empty():
		var bd: Dictionary = _interior.boss_data
		var boss_entry: Dictionary = {
			"monster_kind": bd.get("kind", &"slime_king"),
			"cell": bd.get("cell", Vector2i.ZERO),
			"kind": bd.get("kind", &"slime_king"),
		}
		_spawn_monster(boss_entry)
		for add in bd.get("adds", []):
			var add_entry: Dictionary = {
				"monster_kind": StringName(add.get("kind", &"slime")),
				"cell": add.get("cell", Vector2i.ZERO),
				"kind": StringName(add.get("kind", &"slime")),
			}
			_spawn_monster(add_entry)


func _maybe_inject_mara() -> void:
	# Only inject Mara on the overworld starting region (not interiors).
	if _interior != null or _region == null:
		return
	# Only the starting region (the one _resolve_land_region selected, which
	# is always region_id (0,0) or a nearby non-ocean neighbour).
	var rid: Vector2i = _region.region_id
	if abs(rid.x) > 1 or abs(rid.y) > 1:
		return
	# Check if Mara is already in the scatter list.
	for entry in _region.npcs_scatter:
		if typeof(entry) == TYPE_DICTIONARY \
				and entry.get("dialogue", "") == "res://resources/dialogue/healer_mara.tres":
			return
	# Place her near the first spawn point.
	if _region.spawn_points.is_empty():
		return
	var centre: Vector2i = _region.spawn_points[0]
	var cell: Vector2i = find_safe_spawn_cell(centre + Vector2i(3, 2), 4, true)
	_region.npcs_scatter.append({
		"kind": &"villager",
		"cell": cell,
		"seed": 0xA4A7A,  # Deterministic seed for "Mara" appearance.
		"dialogue": "res://resources/dialogue/healer_mara.tres",
	})


func _spawn_villager(entry: Dictionary) -> void:
	var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
	var v: Villager = _VillagerScene.instantiate() as Villager
	v.npc_seed = int(entry.get("seed", 0))
	v.home_cell = cell
	v.position = (Vector2(cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
	var dlg_path: String = entry.get("dialogue", "")
	if dlg_path != "":
		var tree: DialogueTree = load(dlg_path) as DialogueTree
		if tree != null:
			v.dialogue_tree = tree
	var sid: String = entry.get("shop_id", "")
	if sid != "":
		v.shop_id = StringName(sid)
	v.is_cowardly = entry.get("is_cowardly", false)
	v._lod_index = _spawn_index % 4
	_spawn_index += 1
	v.add_to_group(&"scattered_npcs")
	entities.add_child(v)


func _spawn_monster(entry: Dictionary) -> void:
	var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
	var kind: StringName = entry.get("monster_kind", &"slime")
	var mtier: int = int(entry.get("tier", 0))
	var m: Monster = _MonsterScene.instantiate() as Monster
	m.position = (Vector2(cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
	m.monster_kind = kind
	m.tier = mtier
	# Configure from loot table.
	if LootTableRegistry.has_table(kind):
		var base_hp: int = LootTableRegistry.get_health(kind)
		m.max_health = int(ceil(base_hp * MonsterTier.HP_MULT[mtier]))
		m.health = m.max_health
		m.resistances = LootTableRegistry.get_resistances(kind)
	# Apply tier XP multiplier.
	var base_xp: int = CreatureSpriteRegistry.get_xp_reward(kind)
	m.xp_reward_override = int(ceil(base_xp * MonsterTier.XP_MULT[mtier]))
	m.died.connect(_on_monster_died)
	m._lod_index = _spawn_index % 4
	_spawn_index += 1
	entities.add_child(m)



## Spawn a single [LootPickup] at [param world_pos] with [param item_id] × [param count].
## Used by hedgehog sniff ability and other sources that spawn loot at an explicit position.
func spawn_loot_at(world_pos: Vector2, item_id: StringName, count: int = 1) -> void:
	var pickup := LootPickup.new()
	pickup.item_id = item_id
	pickup.count = count
	pickup.position = world_pos
	entities.add_child(pickup)


func _on_monster_died(world_position: Vector2, drops: Array) -> void:
	for d in drops:
		var pickup := LootPickup.new()
		pickup.item_id = d["id"] if d is Dictionary else d
		pickup.count = d.get("count", 1) if d is Dictionary else 1
		# Small random scatter so stacked drops spread out.
		var offset := Vector2(randf_range(-8, 8), randf_range(-8, 8))
		pickup.position = world_position + offset
		entities.add_child(pickup)


func _materialize_loot_scatter() -> void:
	if _interior == null:
		return
	var scatter: Array = _interior.loot_scatter
	for entry in scatter:
		var id: StringName = entry.get("id", &"")
		var count: int = int(entry.get("count", 1))
		var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
		if id == &"":
			continue
		var pickup := LootPickup.new()
		pickup.item_id = id
		pickup.count = count
		pickup.position = (Vector2(cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
		entities.add_child(pickup)


func _materialize_chest_scatter() -> void:
	if _interior == null or _interior.chest_scatter.is_empty():
		return
	for entry in _interior.chest_scatter:
		var cell: Vector2i = entry.get("cell", Vector2i.ZERO)
		var floor_n: int = int(entry.get("floor_num", _interior.floor_num))
		var chest: TreasureChest = _TreasureChestScene.instantiate()
		chest.floor_num = floor_n
		chest.position = (Vector2(cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
		entities.add_child(chest)


# --- Dialogue ------------------------------------------------------


## Mark both participants as in_conversation (freeze + invincible).
func _begin_conversation(player: PlayerController, npc: Node2D) -> void:
	# End any prior conversation first.
	_end_conversation()
	if player != null:
		player.in_conversation = true
		_active_tree_player = player
	if npc != null and "in_conversation" in npc:
		npc.in_conversation = true
	_active_dialogue_npc = npc


## Clear in_conversation on the tracked participants.
func _end_conversation() -> void:
	if _active_tree_player != null and is_instance_valid(_active_tree_player):
		_active_tree_player.in_conversation = false
	if _active_dialogue_npc != null and is_instance_valid(_active_dialogue_npc):
		if "in_conversation" in _active_dialogue_npc:
			_active_dialogue_npc.in_conversation = false


func show_dialogue(pid: int, speaker: String, line: String, npc: Node2D = null) -> void:
	var player: PlayerController = get_player(pid)
	_begin_conversation(player, npc)
	var box: DialogueBox = _ensure_dialogue_box()
	box.player_id = pid
	box.show_line(speaker, line)


func hide_dialogue() -> void:
	_end_conversation()
	if _dialogue_box != null and is_instance_valid(_dialogue_box):
		if _dialogue_box.choice_selected.is_connected(_on_choice_selected):
			_dialogue_box.choice_selected.disconnect(_on_choice_selected)
		_dialogue_box.hide_line()
	_active_tree_player = null
	_active_dialogue_npc = null


func dialogue_open() -> bool:
	return _dialogue_box != null and is_instance_valid(_dialogue_box) \
		and _dialogue_box.is_open()


func get_dialogue_box() -> DialogueBox:
	return _dialogue_box if _dialogue_box != null and is_instance_valid(_dialogue_box) else null


func _ensure_dialogue_box() -> DialogueBox:
	if _dialogue_box != null and is_instance_valid(_dialogue_box):
		return _dialogue_box
	_dialogue_box = load("res://scenes/ui/DialogueBox.tscn").instantiate() as DialogueBox
	_dialogue_box.name = "DialogueBox"
	add_child(_dialogue_box)
	return _dialogue_box


func show_dialogue_tree(player: PlayerController, tree: DialogueTree, npc: Node2D = null) -> void:
	if tree == null or tree.root == null:
		return
	_active_tree_player = player
	_begin_conversation(player, npc)
	var box: DialogueBox = _ensure_dialogue_box()
	box.player_id = player.player_id
	# Disconnect any prior connection so we don't double-fire.
	if box.choice_selected.is_connected(_on_choice_selected):
		box.choice_selected.disconnect(_on_choice_selected)
	box.choice_selected.connect(_on_choice_selected)
	box.show_node(tree.root as DialogueNode, player.stats)


func _on_choice_selected(choice: DialogueChoice, passed: bool) -> void:
	var next: Resource = choice.next_node if passed else choice.failure_node
	if next == null:
		next = choice.next_node  # fallback on missing failure branch
	if next == null:
		hide_dialogue()
		return
	var node: DialogueNode = next as DialogueNode
	if node == null:
		hide_dialogue()
		return
	# Condition flag gating on the destination node.
	if node.condition_flag != "" and not GameState.get_flag(node.condition_flag):
		hide_dialogue()
		return
	if node.condition_flag_false != "" and GameState.get_flag(node.condition_flag_false):
		hide_dialogue()
		return
	var box: DialogueBox = _ensure_dialogue_box()
	var stats: Dictionary = _active_tree_player.stats if _active_tree_player != null else {}
	box.show_node(node, stats)


# --- Shop integration ------------------------------------------------

var _shop_screen: ShopScreen = null

func open_shop(player: PlayerController, shop_id: String, npc: Node2D = null) -> void:
	_begin_conversation(player, npc)
	if _shop_screen == null:
		_shop_screen = load("res://scenes/ui/ShopScreen.tscn").instantiate() as ShopScreen
		_shop_screen.name = "ShopScreen"
		_shop_screen.closed.connect(_on_shop_closed)
		add_child(_shop_screen)
	_shop_screen.open(player, shop_id, npc)


func _on_shop_closed() -> void:
	_end_conversation()


# --- Debug spawn helpers -------------------------------------------

func debug_spawn_villager_for(player: PlayerController) -> void:
	if player == null or not is_instance_valid(player):
		return
	var centre: Vector2i = Vector2i(
		int(floor(player.position.x / float(WorldConst.TILE_PX))),
		int(floor(player.position.y / float(WorldConst.TILE_PX))))
	var cell: Vector2i = find_safe_spawn_cell(centre, 6, true)
	var seed_base: int = 0
	if _interior != null:
		seed_base = _interior.seed
	elif _region != null:
		seed_base = _region.seed
	var e: Dictionary = {
		"kind": &"villager",
		"cell": cell,
		"seed": (seed_base ^ Time.get_ticks_msec()) & 0x7fffffff,
	}
	if _interior != null:
		_interior.npcs_scatter.append(e)
	elif _region != null:
		_region.npcs_scatter.append(e)
	_spawn_villager(e)


func debug_spawn_shop_villager_for(player: PlayerController) -> void:
	if player == null or not is_instance_valid(player):
		return
	var centre: Vector2i = Vector2i(
		int(floor(player.position.x / float(WorldConst.TILE_PX))),
		int(floor(player.position.y / float(WorldConst.TILE_PX))))
	var cell: Vector2i = find_safe_spawn_cell(centre, 4, true)
	var seed_base: int = 0
	if _interior != null:
		seed_base = _interior.seed
	elif _region != null:
		seed_base = _region.seed
	var e: Dictionary = {
		"kind": &"villager",
		"cell": cell,
		"seed": (seed_base ^ Time.get_ticks_msec()) & 0x7fffffff,
		"shop_id": "general_store",
	}
	if _interior != null:
		_interior.npcs_scatter.append(e)
	elif _region != null:
		_region.npcs_scatter.append(e)
	_spawn_villager(e)
	print("[F9] shop villager (general_store) @ %s" % str(cell))


func debug_spawn_monster_for(player: PlayerController) -> void:
	if player == null or not is_instance_valid(player):
		return
	var centre: Vector2i = Vector2i(
			int(floor(player.position.x / float(WorldConst.TILE_PX))),
			int(floor(player.position.y / float(WorldConst.TILE_PX))))
	# Spawn one of every non-mount creature kind.
	var kinds: Array = CreatureSpriteRegistry.all_kinds()
	var idx: int = 0
	for kind in kinds:
		if CreatureSpriteRegistry.is_mount(kind):
			continue
		var offset := Vector2i(3 + (idx % 6) * 2, (idx / 6) * 2)
		var cell: Vector2i = find_safe_spawn_cell(centre + offset, 6, true)
		var e: Dictionary = {"kind": &"monster", "cell": cell, "monster_kind": kind}
		if _interior != null:
			_interior.npcs_scatter.append(e)
		elif _region != null:
			_region.npcs_scatter.append(e)
		_spawn_monster(e)
		print("[F8] monster \"%s\" @ %s" % [kind, str(cell)])
		idx += 1



func debug_spawn_mount_for(player: PlayerController) -> void:
	if player == null or not is_instance_valid(player):
		return
	if _interior != null:
		return  # mounts are outdoor-only for now
	var centre: Vector2i = Vector2i(
		int(floor(player.position.x / float(WorldConst.TILE_PX))),
		int(floor(player.position.y / float(WorldConst.TILE_PX))))
	var kinds: Array = CreatureSpriteRegistry.all_mount_kinds()
	if kinds.is_empty():
		push_warning("[F8] no mount kinds registered")
		return
	for i in kinds.size():
		var offset := Vector2i(2 + i * 3, -2)
		var cell: Vector2i = find_safe_spawn_cell(centre + offset, 6, true)
		var mount := Mount.new()
		mount.mount_kind = kinds[i]
		mount.position = (Vector2(cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
		entities.add_child(mount)
		print("[F8] mount \"%s\" @ %s" % [mount.mount_kind, str(cell)])


func debug_spawn_interactables_for(player: PlayerController) -> void:
	if player == null or not is_instance_valid(player):
		push_warning("[F9] no player to spawn near")
		return
	if _interior != null:
		print("[F9] skipped — currently inside an interior")
		return
	if _region == null:
		return
	var centre: Vector2i = Vector2i(
		int(floor(player.position.x / float(WorldConst.TILE_PX))),
		int(floor(player.position.y / float(WorldConst.TILE_PX))))
	_debug_place_entrance(&"dungeon", &"dungeon_enter",
			centre, Vector2i(-2, 0), "cave entrance")
	_debug_place_entrance(&"house", &"house_enter",
			centre, Vector2i(2, 0), "house entrance")
	_debug_place_entrance(&"labyrinth", &"labyrinth_enter",
			centre, Vector2i(4, 0), "labyrinth entrance")
	_debug_spawn_encounters(centre)
	debug_drop_all_items_for(player)
	_debug_refresh_labels()


## Drop one LootPickup per item in ItemRegistry in a grid below the player.
## Items are arranged in rows of 10, starting 4 tiles south of the player.
func debug_drop_all_items_for(player: PlayerController) -> void:
	if player == null or not is_instance_valid(player):
		return
	const COLS: int = 10
	const ROW_OFFSET: int = 4   # tiles south of player before first row
	var tile_px: float = float(WorldConst.TILE_PX)
	var centre: Vector2i = Vector2i(
		int(floor(player.position.x / tile_px)),
		int(floor(player.position.y / tile_px)))
	var ids: Array = ItemRegistry.all_ids()
	ids.sort()
	var i: int = 0
	for id in ids:
		var col: int = i % COLS
		var row: int = i / COLS
		var cell := Vector2i(centre.x - COLS / 2 + col, centre.y + ROW_OFFSET + row)
		var pickup := LootPickup.new()
		pickup.item_id = id
		pickup.count = 1
		pickup.position = (Vector2(cell) + Vector2(0.5, 0.5)) * tile_px
		entities.add_child(pickup)
		i += 1
	print("[F9] dropped %d items in a grid south of player" % ids.size())



func _debug_spawn_encounters(centre: Vector2i) -> void:
	var ids: Array = EncounterRegistry.all_ids()
	if ids.is_empty():
		print("[F9] no encounters registered")
		return
	var spacing: int = 12  # tile gap between encounter origins
	var col: int = 0
	for id in ids:
		var enc: Dictionary = EncounterRegistry.get_encounter(StringName(id))
		if enc.is_empty():
			continue
		var sz: Vector2i = EncounterRegistry.get_size(enc)
		# Place in a row to the right of the player, offset down a bit.
		var origin_offset := Vector2i(4 + col * spacing, 4)
		var origin: Vector2i = _debug_find_walkable(centre, origin_offset, false)
		if origin == Vector2i(-9999, -9999):
			push_warning("[F9] no walkable cell for encounter %s" % id)
			col += 1
			continue
		_debug_stamp_encounter(enc, origin)
		print("[F9] encounter \"%s\" (%dx%d) @ %s" % [id, sz.x, sz.y, str(origin)])
		col += 1


func _debug_stamp_encounter(enc: Dictionary, origin: Vector2i) -> void:
	var sz: Vector2i = EncounterRegistry.get_size(enc)
	var tiles: Array = EncounterRegistry.get_tiles(enc)
	var size: int = Region.SIZE
	# Stamp terrain.
	for y in sz.y:
		for x in sz.x:
			var code: int = -1
			if y < tiles.size() and x < tiles[y].size():
				code = int(tiles[y][x])
			if code == -1:
				continue  # Keep existing terrain.
			var cell := origin + Vector2i(x, y)
			if cell.x < 0 or cell.y < 0 or cell.x >= size or cell.y >= size:
				continue
			_region.tiles[cell.y * size + cell.x] = code
			# Re-paint the ground tile.
			var terrain: StringName = TerrainCodes.to_terrain_type(code)
			var hash32: int = _region.seed ^ (cell.x * 73856093) ^ (cell.y * 19349663)
			var atlas_cell: Vector2i = TilesetCatalog.cell_for_variant(
				&"overworld", terrain, hash32)
			if atlas_cell.x >= 0:
				ground.set_cell(cell, 0, atlas_cell, 0)
	# Stamp decorations.
	for d in EncounterRegistry.get_decorations(enc):
		var off: Array = d.get("offset", [0, 0])
		var cell := origin + Vector2i(int(off[0]), int(off[1]))
		if cell.x < 0 or cell.y < 0 or cell.x >= size or cell.y >= size:
			continue
		var deco_kind: StringName = StringName(d.get("kind", ""))
		var variant: int = int(d.get("variant", 0))
		# Add to region data.
		_region.decorations.append({"kind": deco_kind, "cell": cell, "variant": variant})
		# Paint on decoration layer.
		var variants: Variant = TilesetCatalog.OVERWORLD_DECORATION_CELLS.get(deco_kind, null)
		if variants is Array and not (variants as Array).is_empty():
			var arr: Array = variants
			var idx: int = variant % arr.size()
			# sprites[] stores the TOP-LEFT atlas cell (x1y1 convention).
			var top_left_atlas: Vector2i = arr[idx]
			if TilesetCatalog.is_tall_decoration(deco_kind):
				# Paint trunk at ground cell on Decoration.
				decoration.set_cell(cell, 0, top_left_atlas + Vector2i(0, 1), 0)
				# Paint foliage on Canopy above Entities.
				var top_cell := cell + Vector2i(0, -1)
				if top_cell.y >= 0:
					canopy.set_cell(top_cell, 0, top_left_atlas, 0)
			else:
				decoration.set_cell(cell, 0, top_left_atlas, 0)
		# Register mineable if applicable.
		if MINEABLE_HP.has(deco_kind):
			_mineable[cell] = {"kind": deco_kind, "hp": MINEABLE_HP[deco_kind]}
	# Spawn entities.
	for e in EncounterRegistry.get_entities(enc):
		var off: Array = e.get("offset", [0, 0])
		var cell := origin + Vector2i(int(off[0]), int(off[1]))
		var kind: StringName = StringName(e.get("kind", "slime"))
		var entry: Dictionary = {"cell": cell, "kind": kind, "monster_kind": kind}
		_region.npcs_scatter.append(entry)
		if LootTableRegistry.has_table(kind):
			_spawn_monster(entry)
		else:
			push_warning("[F9] unknown entity kind \"%s\" — skipped" % kind)


func _debug_place_entrance(kind: StringName, door_kind: StringName,
		centre: Vector2i, offset: Vector2i, label: String) -> void:
	var cell: Vector2i = _debug_find_walkable(centre, offset, false)
	if cell == Vector2i(-9999, -9999):
		push_warning("[F9] no walkable land cell for %s" % label)
		return
	var already: bool = false
	for entry in _region.dungeon_entrances:
		if entry.get("cell", Vector2i(-9999, -9999)) == cell:
			already = true
			break
	if not already:
		_region.dungeon_entrances.append({"kind": kind, "cell": cell})
	# Register the door in every WorldRoot viewing this region.
	for n in get_tree().get_nodes_in_group(&"world_instances"):
		var w: WorldRoot = n as WorldRoot
		if w == null or w._region == null:
			continue
		if w._region.region_id != _region.region_id:
			continue
		w._doors[cell] = {"kind": door_kind, "cell": cell}
		w._paint_overworld_entrance_markers(w._region)
	print("[F9] %s @ %s" % [label, str(cell)])


func debug_toggle_tile_labels() -> void:
	var existing: Node = get_node_or_null("DebugTileLabels")
	if existing != null:
		existing.queue_free()
		print("[F10] tile labels OFF")
		return
	var overlay_node := DebugTileLabels.new()
	overlay_node.name = "DebugTileLabels"
	add_child(overlay_node)
	print("[F10] tile labels ON")


func debug_toggle_hitbox_overlay() -> void:
	var existing: Node = get_node_or_null("DebugHitboxOverlay")
	if existing != null:
		existing.queue_free()
		print("[F10] hitbox overlay OFF")
		return
	var overlay := DebugHitboxOverlay.new()
	overlay.name = "DebugHitboxOverlay"
	add_child(overlay)
	print("[F10] hitbox overlay ON")


func _debug_find_walkable(centre: Vector2i, offset: Vector2i,
		want_water: bool) -> Vector2i:
	var sz: Vector2i = get_map_size()
	var start: Vector2i = centre + offset
	for r in 12:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if max(abs(dx), abs(dy)) != r:
					continue
				var c := start + Vector2i(dx, dy)
				if sz.x > 0 and (c.x < 0 or c.y < 0
						or c.x >= sz.x or c.y >= sz.y):
					continue
				var is_w: bool = _is_water_cell(c)
				if want_water:
					if is_w:
						return c
				else:
					if not is_w and is_walkable(c):
						return c
	return Vector2i(-9999, -9999)


func _debug_refresh_labels() -> void:
	var overlay_node: Node = get_node_or_null("DebugTileLabels")
	if overlay_node != null and overlay_node.has_method("refresh"):
		overlay_node.call("refresh")
