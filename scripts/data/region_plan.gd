## RegionPlan
##
## Lightweight metadata about a region the world has *thought about* but may
## not have generated yet. Created when any of a region's 4 neighbors gets
## fully generated (so bleed-edges can lock the neighbor's biome before we
## render it).
##
## Persisted as part of `SaveGame`. Cheap by design — handful of fields, no
## tile data.
##
## Bleed bitmask uses N=1, E=2, S=4, W=8 to match `Region.bleed_edges`.
class_name RegionPlan
extends Resource

@export var region_id: Vector2i = Vector2i.ZERO
@export var planned_biome: StringName = &"grass"
@export var is_ocean: bool = false
## Bitmask of sides where a *neighbor* has decided to bleed INTO this region
## (this region must adopt that biome on that side when generated).
@export var bleed_in_from: int = 0
## True once any bleed has locked this plan; further bleeds from other
## neighbors are rejected (deterministic conflict resolution lives in
## `WorldGenerator.try_apply_bleed`).
@export var is_locked_by_bleed: bool = false
