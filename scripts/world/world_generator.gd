## WorldGenerator
##
## Deterministic two-stage pipeline:
##   Stage A — `plan_region(world_seed, region_id, plans)` returns a
##             `RegionPlan` with planned biome + ocean flag, honoring any
##             bleed flags previous neighbors stamped onto it.
##   Stage B — `generate_region(world_seed, plan, plans)` carves the full
##             128×128 `Region`: ocean ring (skipped on bleed-edges), island
##             land mask, secondary terrain sprinkle, decorations, pier.
##             May allocate / mutate neighbor `RegionPlan`s in `plans` when
##             this region rolls a successful bleed onto a side.
##
## Determinism: every random decision is seeded from
## `_region_seed(world_seed, region_id)` so the same inputs always yield the
## same output. Bleed conflicts use deterministic tiebreak (lowest neighbor
## `region_id` wins; comparison is x-major, then y).
##
## Knobs are class consts so callers / tests can assert against them directly.
class_name WorldGenerator
extends RefCounted

const PURE_OCEAN_CHANCE: float = 0.6
## Carved away from each non-bleed edge so islands feel surrounded by sea.
const OCEAN_RING: int = 4
## Per-edge chance any given LAND region bleeds into a neighbor; capped here
## as a default — biome-specific overrides come from `BiomeDefinition`.
const DEFAULT_BLEED_CHANCE: float = 0.25

const _N: int = 1
const _E: int = 2
const _S: int = 4
const _W: int = 8


# ─────────── Stage A ────────────────────────────────────────────────

static func plan_region(world_seed: int, region_id: Vector2i, plans: Dictionary) -> RegionPlan:
	if plans.has(region_id):
		return plans[region_id]
	var plan := RegionPlan.new()
	plan.region_id = region_id
	var rng := RandomNumberGenerator.new()
	rng.seed = _region_seed(world_seed, region_id)
	# Starting region (0,0) is always grass so the player begins on familiar terrain.
	if region_id == Vector2i.ZERO:
		plan.is_ocean = false
		plan.planned_biome = &"grass"
	else:
		plan.is_ocean = rng.randf() < PURE_OCEAN_CHANCE
		plan.planned_biome = _pick_biome(rng) if not plan.is_ocean else &"ocean"
	plans[region_id] = plan
	return plan


# ─────────── Stage B ────────────────────────────────────────────────

static func generate_region(world_seed: int, plan: RegionPlan, plans: Dictionary) -> Region:
	var region := Region.new()
	region.region_id = plan.region_id
	region.biome = plan.planned_biome
	region.is_ocean = plan.is_ocean
	region.seed = _region_seed(world_seed, plan.region_id)

	# Land regions may roll bleeds onto their 4 neighbors; ocean never bleeds.
	if not plan.is_ocean:
		region.bleed_edges = _roll_and_apply_bleeds(world_seed, plan, plans)
	else:
		region.bleed_edges = 0

	_carve_terrain(region, plan)
	_scatter_decorations(region)
	_scatter_npcs(region)
	_pick_spawn_points(region)
	_place_pier(region)
	_place_dungeon_entrances(region)
	_place_labyrinth_entrances(region)
	_place_runes(region)
	if plan.region_id == Vector2i(0, 0) and not plan.is_ocean:
		_generate_starting_region_features(region)
	return region


# ─────────── Bleed handling ─────────────────────────────────────────

static func _roll_and_apply_bleeds(world_seed: int, plan: RegionPlan, plans: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = _region_seed(world_seed, plan.region_id) ^ 0xb1eed
	var biome := BiomeRegistry.get_biome(plan.planned_biome)
	var chance: float = biome.bleed_chance if biome != null else DEFAULT_BLEED_CHANCE
	# Honor any already-locked-in bleeds the neighbors stamped onto US.
	var edges: int = plan.bleed_in_from
	# Try to bleed outward on each side.
	for side_data in [
		[_N, Vector2i(0, -1), _S],
		[_E, Vector2i(1, 0), _W],
		[_S, Vector2i(0, 1), _N],
		[_W, Vector2i(-1, 0), _E],
	]:
		var my_side: int = side_data[0]
		var offset: Vector2i = side_data[1]
		var their_side: int = side_data[2]
		if rng.randf() >= chance:
			continue
		var neighbor_id: Vector2i = plan.region_id + offset
		var neighbor: RegionPlan = plan_region(world_seed, neighbor_id, plans)
		if try_apply_bleed(plan, neighbor, their_side):
			edges |= my_side
	return edges


## Returns true if the bleed was accepted (neighbor adopted source's biome).
## Conflict rule: if neighbor is already locked by another bleed, accept only
## when the source has a smaller `region_id` than whatever previously locked.
## Since we don't track who locked, the rule simplifies to: do not overwrite
## an existing lock unless the new source `region_id` is lexicographically
## smaller than the neighbor's current `planned_biome` source — which we
## approximate by storing the source `region_id` on the plan via a meta
## field. To keep the resource clean, we use a runtime metadata key.
static func try_apply_bleed(source: RegionPlan, neighbor: RegionPlan, into_side: int) -> bool:
	if neighbor.is_ocean:
		# Ocean regions ignore bleed; they stay ocean.
		return false
	if neighbor.is_locked_by_bleed:
		var prev: Vector2i = neighbor.get_meta("bleed_lock_source", Vector2i(2147483647, 2147483647))
		if not _id_less(source.region_id, prev):
			return false
	neighbor.planned_biome = source.planned_biome
	neighbor.bleed_in_from |= into_side
	neighbor.is_locked_by_bleed = true
	neighbor.set_meta("bleed_lock_source", source.region_id)
	return true


static func _id_less(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y


# ─────────── Terrain carving ────────────────────────────────────────

static func _carve_terrain(region: Region, plan: RegionPlan) -> void:
	var size := Region.SIZE
	var biome: BiomeDefinition = BiomeRegistry.get_biome(plan.planned_biome)
	if plan.is_ocean:
		# Pure-ocean region: deep water everywhere, no land.
		for i in size * size:
			region.tiles[i] = TerrainCodes.OCEAN
		return
	# Elevation noise drives land/water; threshold pushed up near edges
	# UNLESS that edge is in `bleed_edges`, in which case land extends to
	# the border seamlessly.
	var noise := FastNoiseLite.new()
	noise.seed = region.seed
	noise.frequency = 0.025
	noise.fractal_octaves = 4
	# Secondary terrain (dirt/rock/water blobs in the primary) is driven by
	# a SECOND noise field rather than per-cell randf — that way patches
	# come out as connected blobs of contiguous secondary terrain instead
	# of single-tile freckles that look like ugly isolated path squares.
	var sec_noise := FastNoiseLite.new()
	sec_noise.seed = region.seed ^ 0x53c0d
	# Lower frequency than ground-elevation noise so secondary patches form
	# a few large cohesive blobs per region instead of speckled noise.
	sec_noise.frequency = 0.07
	sec_noise.fractal_octaves = 2
	var primary: int = biome.primary_terrain
	var secondary: int = biome.secondary_terrain
	# Convert the 0..1 area fraction into a noise threshold. FastNoise's
	# output for our settings is roughly bell-shaped in (-0.9, 0.85);
	# this linear approximation was empirically calibrated to keep the
	# visible secondary area close to `secondary_chance`:
	#   chance=0.05 -> threshold=0.50 (~5% area)
	#   chance=0.08 -> threshold=0.44 (~8% area)
	#   chance=0.20 -> threshold=0.20 (~20% area)
	var sec_chance: float = clampf(biome.secondary_chance, 0.0, 1.0)
	var sec_threshold: float = 0.6 - 2.0 * sec_chance
	for y in size:
		for x in size:
			var dist_to_edge: int = min(min(x, y), min(size - 1 - x, size - 1 - y))
			var on_bleed_edge: bool = _cell_on_bleed_edge(x, y, region.bleed_edges, size)
			var threshold: float = -0.1
			if not on_bleed_edge and dist_to_edge < OCEAN_RING:
				# Force ocean ring.
				region.tiles[y * size + x] = TerrainCodes.OCEAN
				continue
			var n: float = noise.get_noise_2d(float(x), float(y))
			if n < threshold:
				region.tiles[y * size + x] = TerrainCodes.WATER
			else:
				var sn: float = sec_noise.get_noise_2d(float(x), float(y))
				if sn > sec_threshold:
					region.tiles[y * size + x] = secondary
				else:
					region.tiles[y * size + x] = primary

	# Erosion pass for secondary terrain:
	# 20-tile overlay sets (dirt/stone/snow) have dedicated path tiles for
	# every shape, so no erosion needed — thin strips and isolated dots all
	# render correctly. 13-tile sets (grass/mud/purple) lack path tiles, so
	# protrusions must be dissolved back to primary terrain.
	var needs_sec_erosion: bool = true
	var overlay_sets: Dictionary = TilesetCatalog.OVERWORLD_OVERLAY_SETS
	var oset_arr: Variant = overlay_sets.get(biome.overlay_set, null)
	if oset_arr is Array and (oset_arr as Array).size() >= 20:
		needs_sec_erosion = false
	if needs_sec_erosion:
		var changed: bool = true
		while changed:
			changed = false
			var before: PackedByteArray = region.tiles.duplicate()
			for y in size:
				for x in size:
					var i: int = y * size + x
					if before[i] != secondary:
						continue
					var n_sec: bool = y > 0         and before[i - size] == secondary
					var s_sec: bool = y < size - 1  and before[i + size] == secondary
					var w_sec: bool = x > 0         and before[i - 1]    == secondary
					var e_sec: bool = x < size - 1  and before[i + 1]    == secondary
					var cnt: int = int(n_sec) + int(s_sec) + int(w_sec) + int(e_sec)
					var is_protrusion: bool = (
						cnt == 0 or cnt == 1
						or (n_sec and s_sec and not w_sec and not e_sec)
						or (w_sec and e_sec and not n_sec and not s_sec))
					if is_protrusion:
						region.tiles[i] = primary
						changed = true

	# Water erosion always runs regardless of overlay set — water has no
	# path-tile equivalents.
	var water_changed: bool = true
	while water_changed:
		water_changed = false
		var before_w: PackedByteArray = region.tiles.duplicate()
		for y in size:
			for x in size:
				var i: int = y * size + x
				if before_w[i] != TerrainCodes.WATER:
					continue
				# Neighbour counts — both WATER and OCEAN count as "water family".
				var n_w: bool = y > 0         and (before_w[i - size] == TerrainCodes.WATER or before_w[i - size] == TerrainCodes.OCEAN)
				var s_w: bool = y < size - 1  and (before_w[i + size] == TerrainCodes.WATER or before_w[i + size] == TerrainCodes.OCEAN)
				var w_w: bool = x > 0         and (before_w[i - 1]    == TerrainCodes.WATER or before_w[i - 1]    == TerrainCodes.OCEAN)
				var e_w: bool = x < size - 1  and (before_w[i + 1]    == TerrainCodes.WATER or before_w[i + 1]    == TerrainCodes.OCEAN)
				var cnt: int = int(n_w) + int(s_w) + int(w_w) + int(e_w)
				var is_protrusion: bool = (
					cnt == 0 or cnt == 1
					or (n_w and s_w and not w_w and not e_w)
					or (w_w and e_w and not n_w and not s_w))
				if is_protrusion:
					region.tiles[i] = primary
					water_changed = true


static func _cell_on_bleed_edge(x: int, y: int, edges: int, size: int) -> bool:
	if (edges & _N) != 0 and y < OCEAN_RING:
		return true
	if (edges & _S) != 0 and y >= size - OCEAN_RING:
		return true
	if (edges & _W) != 0 and x < OCEAN_RING:
		return true
	if (edges & _E) != 0 and x >= size - OCEAN_RING:
		return true
	return false


# ─────────── Scatter / placement ────────────────────────────────────

static func _scatter_decorations(region: Region) -> void:
	if region.is_ocean:
		return
	var biome: BiomeDefinition = BiomeRegistry.get_biome(region.biome)
	if biome == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = region.seed ^ 0xdec02a7
	var size := Region.SIZE
	for y in size:
		for x in size:
			var code: int = region.tiles[y * size + x]
			if not TerrainCodes.is_walkable(code):
				continue
			for kind in biome.decoration_weights:
				var weight: float = biome.decoration_weights[kind]
				if rng.randf() < weight:
					region.decorations.append({
						"kind": kind,
						"cell": Vector2i(x, y),
						"variant": rng.randi(),
					})
					break  # one decoration per cell


## Scatter NPCs onto walkable, decoration-free cells. Density is biome-driven
## (`BiomeDefinition.npc_density`); kinds picked from `BiomeDefinition.npc_kinds`.
## Stays well clear of region center so spawns aren't ON top of players.
static func _scatter_npcs(region: Region) -> void:
	if region.is_ocean:
		return
	var biome: BiomeDefinition = BiomeRegistry.get_biome(region.biome)
	if biome == null:
		return
	var density: float = biome.npc_density
	var kinds: Array = biome.npc_kinds
	if density <= 0.0 or kinds.is_empty():
		return
	# Build a quick set of decoration cells to avoid double-occupancy.
	var occupied: Dictionary = {}
	for entry in region.decorations:
		occupied[entry["cell"]] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = region.seed ^ 0x9c022e
	var size := Region.SIZE
	var center := Vector2i(size / 2, size / 2)
	for y in size:
		for x in size:
			var cell := Vector2i(x, y)
			if occupied.has(cell):
				continue
			if not region.is_walkable_at(cell):
				continue
			# Keep a small buffer around the player spawn.
			if abs(cell.x - center.x) + abs(cell.y - center.y) < 6:
				continue
			if rng.randf() < density:
				var kind: StringName = kinds[rng.randi() % kinds.size()]
				var entry: Dictionary = {
					"kind": kind,
					"cell": cell,
					"variant": rng.randi(),
				}
				# ~30% of generated villagers are cowardly.
				if kind == &"villager":
					entry["is_cowardly"] = rng.randf() < 0.3
				region.npcs_scatter.append(entry)


static func _pick_spawn_points(region: Region) -> void:
	var size := Region.SIZE
	var center := Vector2i(size / 2, size / 2)
	# Spiral outward from center looking for walkable land.
	for radius in range(0, size / 2):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var c: Vector2i = center + Vector2i(dx, dy)
				if region.is_walkable_at(c):
					region.spawn_points.append(c)
					if region.spawn_points.size() >= 4:
						return


static func _place_pier(region: Region) -> void:
	if region.is_ocean:
		return
	# Find the longest contiguous shore segment along any of the 4 cardinal
	# directions and place a pier base on the most central tile of it. Phase
	# 3 only records the cell; the actual `Pier.tscn` instantiation happens
	# when the region scene is built (Phase 3b).
	var size := Region.SIZE
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_score: int = -1
	for y in size:
		for x in size:
			var c := Vector2i(x, y)
			if region.at(c) != TerrainCodes.SAND and region.at(c) != TerrainCodes.GRASS:
				continue
			# Shore = adjacent to ocean.
			var touches_ocean: bool = false
			for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				if region.at(c + off) == TerrainCodes.OCEAN:
					touches_ocean = true
					break
			if not touches_ocean:
				continue
			var score: int = size - (abs(x - size / 2) + abs(y - size / 2))
			if score > best_score:
				best_score = score
				best_cell = c
	region.pier_position = best_cell


## Place 0–3 dungeon entrances per land region. Each entrance is a walkable
## rock or dirt cell, well away from the spawn center, and not occupied by
## a decoration. Stored on the Region as a list of cells.
static func _place_dungeon_entrances(region: Region) -> void:
	if region.is_ocean:
		return
	# Build a quick set of decoration / npc cells to avoid double-occupancy.
	var occupied: Dictionary = {}
	for entry in region.decorations:
		occupied[entry["cell"]] = true
	for entry in region.npcs_scatter:
		occupied[entry["cell"]] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = region.seed ^ 0xd0e7c4
	var size := Region.SIZE
	var center := Vector2i(size / 2, size / 2)
	# Decide how many entrances this region gets (0..3).
	var target_count: int = rng.randi_range(0, 3)
	if target_count == 0:
		return
	# Collect candidate cells (rock or dirt, walkable, not occupied,
	# at least 16 tiles from spawn).
	var candidates: Array[Vector2i] = []
	for y in size:
		for x in size:
			var cell := Vector2i(x, y)
			if occupied.has(cell):
				continue
			var code: int = region.at(cell)
			if code != TerrainCodes.ROCK and code != TerrainCodes.DIRT:
				continue
			if not TerrainCodes.is_walkable(code):
				continue
			if abs(cell.x - center.x) + abs(cell.y - center.y) < 16:
				continue
			candidates.append(cell)
	# Shuffle deterministically and take target_count (but enforce a
	# minimum spacing so entrances don't cluster).
	candidates.shuffle()  # non-deterministic — re-shuffle with our rng:
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var placed: Array = []
	for cell in candidates:
		if placed.size() >= target_count:
			break
		var too_close: bool = false
		for p in placed:
			var pc: Vector2i = p
			if abs(cell.x - pc.x) + abs(cell.y - pc.y) < 12:
				too_close = true
				break
		if too_close:
			continue
		placed.append(cell)
	for cell in placed:
		region.dungeon_entrances.append({
			"kind": &"dungeon",
			"cell": cell,
		})


## Place 0 or 1 labyrinth entrance per non-ocean region (~35% of regions).
static func _place_labyrinth_entrances(region: Region) -> void:
	if region.is_ocean:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = region.seed ^ 0xa7b3c1
	# ~35% of regions get a labyrinth entrance.
	if rng.randf() > 0.35:
		return
	# Build occupied set.
	var occupied: Dictionary = {}
	for entry in region.decorations:
		occupied[entry["cell"]] = true
	for entry in region.npcs_scatter:
		occupied[entry["cell"]] = true
	for entry in region.dungeon_entrances:
		occupied[entry["cell"]] = true
	var size: int = Region.SIZE
	var center := Vector2i(size / 2, size / 2)
	# Collect candidate cells (same criteria as dungeon entrances).
	var candidates: Array[Vector2i] = []
	for y in size:
		for x in size:
			var cell := Vector2i(x, y)
			if occupied.has(cell):
				continue
			var code: int = region.at(cell)
			if code != TerrainCodes.ROCK and code != TerrainCodes.DIRT:
				continue
			if not TerrainCodes.is_walkable(code):
				continue
			if abs(cell.x - center.x) + abs(cell.y - center.y) < 20:
				continue
			candidates.append(cell)
	if candidates.is_empty():
		return
	# Deterministic shuffle.
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var cell: Vector2i = candidates[0]
	region.dungeon_entrances.append({
		"kind": &"labyrinth",
		"cell": cell,
	})


# ─────────── Helpers ────────────────────────────────────────────────

static func _region_seed(world_seed: int, region_id: Vector2i) -> int:
	# Cheap deterministic mix; bits are ample for FastNoiseLite + RNG.
	return (world_seed * 73856093) ^ (region_id.x * 19349663) ^ (region_id.y * 83492791)


static func _pick_biome(rng: RandomNumberGenerator) -> StringName:
	var ids: Array[StringName] = BiomeRegistry.all_ids()
	return ids[rng.randi() % ids.size()]


## Place 0-4 ancient runes per land region. Each rune is a walkable cell
## (avoiding decorations and dungeon entrances) decorated with a randomly
## chosen rune sprite from one of the 3 colour sources (0=black, 1=grey,
## 2=blue). Stored on the Region so painting + interaction can replay them
## deterministically.
static func _place_runes(region: Region) -> void:
	if region.is_ocean:
		return
	var occupied: Dictionary = {}
	for entry in region.decorations:
		occupied[entry["cell"]] = true
	for entry in region.dungeon_entrances:
		occupied[entry["cell"]] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = region.seed ^ 0x12ade5
	var size := Region.SIZE
	var target_count: int = rng.randi_range(0, 4)
	var placed: int = 0
	var attempts: int = 0
	while placed < target_count and attempts < 200:
		attempts += 1
		var c := Vector2i(rng.randi_range(8, size - 9), rng.randi_range(8, size - 9))
		if occupied.has(c):
			continue
		var code: int = region.at(c)
		if not TerrainCodes.is_walkable(code):
			continue
		occupied[c] = true
		region.runes.append({
			"cell": c,
			"source": rng.randi_range(0, 2),
			"atlas": Vector2i(rng.randi_range(0, 3), rng.randi_range(0, 3)),
		})
		placed += 1


## Carve a dirt patch around spawn and a 1-tile-wide random-walk path to the
## nearest dungeon/labyrinth entrance. Only called for region (0, 0).
static func _generate_starting_region_features(region: Region) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = region.seed ^ 0x5781c0
	var size := Region.SIZE

	# Determine spawn anchor — first spawn point or center.
	var anchor: Vector2i = Vector2i(size / 2, size / 2)
	if not region.spawn_points.is_empty():
		anchor = region.spawn_points[0]

	# ── Guarantee a cave entrance ────────────────────────────────────────
	# _place_dungeon_entrances only drops entrances on ROCK/DIRT cells, which
	# are rare in the default grass biome. Force-place one if missing.
	if region.dungeon_entrances.is_empty():
		var goal: Vector2i = Vector2i(-1, -1)
		var attempts: int = 0
		while goal == Vector2i(-1, -1) and attempts < 500:
			attempts += 1
			var dist: int = rng.randi_range(20, 40)
			var angle: float = rng.randf() * TAU
			var cx: int = clamp(anchor.x + int(cos(angle) * float(dist)), 4, size - 5)
			var cy: int = clamp(anchor.y + int(sin(angle) * float(dist)), 4, size - 5)
			var c := Vector2i(cx, cy)
			if TerrainCodes.is_walkable(region.at(c)):
				goal = c
		if goal != Vector2i(-1, -1):
			region.dungeon_entrances.append({"kind": &"dungeon", "cell": goal})

	if region.dungeon_entrances.is_empty():
		return

	var entrance_cell: Vector2i = region.dungeon_entrances[0]["cell"]

	# ── Dirt patch (noise-blob around spawn) ─────────────────────────────
	var patch_radius: int = 7
	for dy in range(-patch_radius, patch_radius + 1):
		for dx in range(-patch_radius, patch_radius + 1):
			var dist_sq: float = float(dx * dx + dy * dy)
			# Organic blob: use noise-like threshold that varies with distance.
			var threshold: float = float(patch_radius * patch_radius)
			# Add some randomness proportional to radial distance.
			var jitter: float = rng.randf_range(-10.0, 10.0)
			if dist_sq > threshold + jitter:
				continue
			var c := Vector2i(anchor.x + dx, anchor.y + dy)
			if c.x < 0 or c.y < 0 or c.x >= size or c.y >= size:
				continue
			if not TerrainCodes.is_walkable(region.at(c)):
				continue
			region.tiles[c.y * size + c.x] = TerrainCodes.DIRT

	# ── Gentle random-walk path from anchor to entrance ──────────────────
	var pos: Vector2i = anchor
	var visited: Dictionary = {}
	var max_steps: int = 300
	for _i in max_steps:
		if pos == entrance_cell:
			break
		visited[pos] = true
		region.tiles[pos.y * size + pos.x] = TerrainCodes.DIRT
		region.path_tiles.append(pos)

		# 70% chance: step toward goal (Manhattan); 30% chance: random cardinal.
		var step: Vector2i
		if rng.randf() < 0.7:
			var dx: int = entrance_cell.x - pos.x
			var dy: int = entrance_cell.y - pos.y
			if abs(dx) >= abs(dy):
				step = Vector2i(sign(dx), 0)
			else:
				step = Vector2i(0, sign(dy))
		else:
			var dirs: Array[Vector2i] = [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]
			step = dirs[rng.randi() % 4]

		var next: Vector2i = pos + step
		next.x = clamp(next.x, 0, size - 1)
		next.y = clamp(next.y, 0, size - 1)
		if TerrainCodes.is_walkable(region.at(next)) or next == entrance_cell:
			pos = next

	# Append the entrance cell itself so the path visually connects.
	if pos == entrance_cell and not (entrance_cell in region.path_tiles):
		region.tiles[entrance_cell.y * size + entrance_cell.x] = TerrainCodes.DIRT
		region.path_tiles.append(entrance_cell)
