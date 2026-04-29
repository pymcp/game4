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

	# Dissolve isolated single-tile secondary blobs. A secondary cell with
	# no orthogonal same-type neighbor would render as a lonely 1×1 square
	# on the patch overlay (since the patch corner tiles need at least one
	# neighbor to read as part of a larger blob). Reverting them to
	# primary keeps the world looking clean. We snapshot the tiles array
	# so neighbor lookups during dissolve see the pre-dissolve state.
	# Iterative erosion: remove any secondary cell that would produce a
	# 1-tile protrusion — defined as a cell that does NOT have at least two
	# adjacent (non-opposite) secondary cardinal neighbours:
	#   • 0 secondary neighbours  → isolated pixel (already covered)
	#   • 1 secondary neighbour   → arm tip  (needs 2 corners on one tile)
	#   • N+S only, W+E both prim → 1-tile-wide vertical strip
	#   • W+E only, N+S both prim → 1-tile-wide horizontal strip
	# We iterate until no further cells are removed, so the whole arm
	# shrinks inward pass-by-pass rather than leaving an orphaned middle.
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
				# Keep the cell if it has at least two adjacent (non-opposite)
				# secondary cardinal neighbours.  Opposite pairs (N+S, W+E) with
				# nothing else would make a 1-tile-wide corridor.
				var is_protrusion: bool = (
					cnt == 0 or cnt == 1
					or (n_sec and s_sec and not w_sec and not e_sec)
					or (w_sec and e_sec and not n_sec and not s_sec))
				if is_protrusion:
					region.tiles[i] = primary
					changed = true

	# Same iterative erosion for water (interior shallow water cells driven
	# by elevation noise). OCEAN is treated as the same "water family" so
	# water touching the forced ocean ring is not stripped, but water
	# protrusions that jut into land as 1-tile-wide columns/rows are
	# dissolved back to primary terrain.
	changed = true
	while changed:
		changed = false
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
					changed = true


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
