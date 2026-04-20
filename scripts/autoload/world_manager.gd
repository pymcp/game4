## WorldManager
##
## Autoload owning the world's plans/regions cache and the active region.
## (Per-player active regions arrive with sailing in P7.)
extends Node

signal active_region_changed(region)
signal region_planned(region_id)
signal region_generated(region_id)

@export var world_seed: int = 1337

var plans: Dictionary = {}
var regions: Dictionary = {}
var active_region: Region = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func get_or_plan(region_id: Vector2i) -> RegionPlan:
	var existed: bool = plans.has(region_id)
	var plan: RegionPlan = WorldGenerator.plan_region(world_seed, region_id, plans)
	if not existed:
		region_planned.emit(region_id)
	return plan


func get_or_generate(region_id: Vector2i) -> Region:
	if regions.has(region_id):
		return regions[region_id]
	var plan: RegionPlan = get_or_plan(region_id)
	var region: Region = WorldGenerator.generate_region(world_seed, plan, plans)
	regions[region_id] = region
	region_generated.emit(region_id)
	return region


func set_active_region(region_id: Vector2i) -> Region:
	var region: Region = get_or_generate(region_id)
	if active_region == region:
		return region
	active_region = region
	active_region_changed.emit(region)
	return region


func reset(new_seed: int = 0) -> void:
	world_seed = new_seed if new_seed != 0 else int(Time.get_unix_time_from_system())
	plans.clear()
	regions.clear()
	active_region = null
