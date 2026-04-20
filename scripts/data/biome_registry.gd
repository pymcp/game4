## BiomeRegistry
##
## Code-side catalog of `BiomeDefinition`s so tests + early phases work
## without any `.tres` files. Designers can later override individual biomes
## by dropping `resources/biomes/<id>.tres` next to it; `get(id)` will prefer
## the disk file if present.
class_name BiomeRegistry
extends RefCounted

const _OVERRIDE_DIR: String = "res://resources/biomes/"

static var _cache: Dictionary = {}


static func get_biome(id: StringName) -> BiomeDefinition:
	if _cache.has(id):
		return _cache[id]
	var override_path: String = "%s%s.tres" % [_OVERRIDE_DIR, String(id)]
	if ResourceLoader.exists(override_path):
		var res := load(override_path) as BiomeDefinition
		if res != null:
			_cache[id] = res
			return res
	var defn := _make_default(id)
	_cache[id] = defn
	return defn


static func all_ids() -> Array[StringName]:
	return [&"grass", &"desert", &"snow", &"swamp", &"rocky"] as Array[StringName]


static func _make_default(id: StringName) -> BiomeDefinition:
	var b := BiomeDefinition.new()
	b.id = id
	match id:
		&"grass":
			b.primary_terrain = TerrainCodes.GRASS
			b.secondary_terrain = TerrainCodes.DIRT
			b.ground_modulate = Color.WHITE
			# Override the BiomeDefinition default so grass leans toward
			# trees + flowers (no rock/bush spam) for a meadow feel.
			b.decoration_weights = {&"tree": 0.05, &"bush": 0.025,
				&"flower": 0.025, &"rock": 0.008}
		&"desert":
			b.primary_terrain = TerrainCodes.SAND
			b.secondary_terrain = TerrainCodes.DIRT
			b.ground_modulate = Color(1.0, 0.95, 0.75)
			b.decoration_weights = {&"rock": 0.03, &"bush": 0.01}
		&"snow":
			b.primary_terrain = TerrainCodes.SNOW
			b.secondary_terrain = TerrainCodes.ROCK
			b.ground_modulate = Color(0.85, 0.95, 1.05)
			b.decoration_weights = {&"tree": 0.04, &"rock": 0.02}
		&"swamp":
			b.primary_terrain = TerrainCodes.SWAMP
			b.secondary_terrain = TerrainCodes.WATER
			b.ground_modulate = Color(0.7, 0.85, 0.6)
			b.decoration_weights = {&"tree": 0.05, &"bush": 0.06, &"flower": 0.02}
		&"rocky":
			b.primary_terrain = TerrainCodes.ROCK
			b.secondary_terrain = TerrainCodes.DIRT
			b.ground_modulate = Color(0.95, 0.95, 0.95)
			b.decoration_weights = {&"rock": 0.06, &"tree": 0.02,
				&"iron_vein": 0.015, &"copper_vein": 0.01}
		_:
			b.primary_terrain = TerrainCodes.GRASS
	return b
