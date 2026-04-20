## IslandGenerator
##
## Phase-2 placeholder generator. Produces a small ~40x40 tile island with a
## ring of water around grass interior, scattered sand at the shore, and a few
## rock outcrops. Phase 5 replaces this with the full procgen + biome-bleed
## pipeline.
##
## Returns a `Result` struct with two `Dictionary[Vector2i, StringName]` maps:
## one for ground tiles, one for water tiles (so they can populate separate
## TileMapLayers).
class_name IslandGenerator
extends RefCounted


class Result:
	var ground: Dictionary = {}  # Vector2i -> StringName terrain
	var water: Dictionary = {}   # Vector2i -> StringName ("water")
	var rocks: Array[Vector2i] = []  # decoration spawn points (rock outcrops)
	var spawn_points: Array[Vector2i] = []  # safe walkable spawn cells
	var decorations: Array = []  # Array of [kind: StringName, cell: Vector2i]


## `seed` controls noise; `radius` is the half-extent of the generated region
## (in tiles). Center is (0, 0).
static func generate(world_seed: int, radius: int = 20) -> Result:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.frequency = 0.06
	noise.fractal_octaves = 4

	var result := Result.new()
	# Coastline shape: distance from center, biased by noise, defines island.
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var p := Vector2i(x, y)
			var dist: float = sqrt(float(x * x + y * y))
			var n: float = noise.get_noise_2d(float(x), float(y))  # -1..1
			var coast_thresh: float = float(radius) * 0.85 + n * 4.0
			if dist > coast_thresh:
				result.water[p] = &"water"
			elif dist > coast_thresh - 1.5:
				result.ground[p] = &"sand"
			else:
				# Interior: rock patch where noise is high, otherwise grass.
				var rock_n: float = noise.get_noise_2dv(Vector2(x * 1.7, y * 1.7))
				if rock_n > 0.55 and dist < coast_thresh - 4.0:
					result.ground[p] = &"rock"
					if rng.randf() < 0.35:
						result.rocks.append(p)
				else:
					result.ground[p] = &"grass"

	# Pick spawn points: walkable cells near center.
	for y in range(-3, 4):
		for x in range(-3, 4):
			var p := Vector2i(x, y)
			if result.ground.get(p, &"") == &"grass":
				result.spawn_points.append(p)
	# Make sure we always have at least two; if not, add the origin.
	if result.spawn_points.size() < 2:
		result.spawn_points = [Vector2i.ZERO, Vector2i(1, 0)]
	# Trees + bushes + flowers scattered on grass tiles, away from spawn.
	var spawn_set: Dictionary = {}
	for sp in result.spawn_points:
		spawn_set[sp] = true
	for cell in result.ground:
		if result.ground[cell] != &"grass":
			continue
		if spawn_set.has(cell):
			continue
		var roll: float = rng.randf()
		if roll < 0.06:
			result.decorations.append([&"tree", cell])
		elif roll < 0.10:
			result.decorations.append([&"bush", cell])
		elif roll < 0.14:
			result.decorations.append([&"flower", cell])
	# Rocks decoration on detected rock outcrops.
	for r in result.rocks:
		result.decorations.append([&"rock", r])
	return result
