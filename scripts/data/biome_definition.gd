## BiomeDefinition
##
## Static rules describing how a biome's terrain, decorations, and (later)
## resources/NPCs are rolled. Kept as a `Resource` so designers could author
## `.tres` overrides; for now a code-side registry in `BiomeRegistry` provides
## defaults so tests don't depend on disk files.
class_name BiomeDefinition
extends Resource

@export var id: StringName = &"grass"
## Modulate color applied to ground TileMapLayer for visual variety
## (snow/swamp use this since Kenney has no native sprites).
@export var ground_modulate: Color = Color.WHITE
## Primary land terrain code (TerrainCodes.GRASS/SAND/SNOW/etc).
@export var primary_terrain: int = TerrainCodes.GRASS
## Secondary terrain code; sprinkled into the primary at low frequency.
@export var secondary_terrain: int = TerrainCodes.DIRT
## 0..1, fraction of land cells that become secondary terrain.
@export var secondary_chance: float = 0.08
## Per-cell probability rolls for decorations on this biome's land.
@export var decoration_weights: Dictionary = {
	&"tree": 0.06,
	&"bush": 0.04,
	&"rock": 0.015,
	&"flower": 0.04,
}
## Default per-edge chance this biome bleeds into a neighbor region. Tunable
## per biome; applied in Phase 3c.
@export var bleed_chance: float = 0.25
## Per-cell probability that a walkable, decoration-free, off-spawn tile gets
## an NPC. Phase 7. Set to 0.0 to disable spawning entirely for this biome.
@export var npc_density: float = 0.002
## NPC kinds (StringNames) eligible to spawn on this biome.
@export var npc_kinds: Array = [&"slime"]
## Which overlay set to paint for secondary terrain blobs on this biome.
## Must match a key in TilesetCatalog.OVERWORLD_OVERLAY_SETS.
## Empty string disables the overlay pass (e.g. for water-secondary biomes
## that use the dedicated water-border system instead).
@export var overlay_set: StringName = &""
