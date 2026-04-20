## SaveGame
##
## Top-level save snapshot. Stored as a `.tres` Resource at
## `user://saves/<slot>.tres`. Holds:
##   - world seed
##   - every RegionPlan ever planned
##   - every Region ever fully generated
##   - both player snapshots
##
## A backup `.bak.tres` is written alongside on each save (Phase 9 will harden
## this further). `version` lets future migrations detect old layouts.
class_name SaveGame
extends Resource

const VERSION: int = 2
const _SAVE_DIR: String = "user://saves/"

@export var version: int = VERSION
@export var world_seed: int = 0
@export var saved_at_unix: int = 0
@export var active_region_id: Vector2i = Vector2i.ZERO
## Array[RegionPlan]
@export var plans: Array = []
## Array[Region]
@export var regions: Array = []
@export var players: Array[PlayerSaveData] = []
## Phase 9a: persistent dungeon state.
## Array[InteriorMap] - every interior visited so generated layouts persist.
@export var interiors: Array = []
## StringName id of the active interior, or &"" if on the overworld.
@export var active_interior_id: StringName = &""
@export var game_state_flags: Dictionary = {}


static func slot_path(slot: String) -> String:
	return "%s%s.tres" % [_SAVE_DIR, slot]


static func backup_path(slot: String) -> String:
	return "%s%s.bak.tres" % [_SAVE_DIR, slot]


static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_SAVE_DIR))


## Snapshot the current state of WorldManager + the two players in `world`
## into a fresh SaveGame. `world` may be null when only saving plans/seed.
static func snapshot(world: WorldRoot) -> SaveGame:
	var save := SaveGame.new()
	save.world_seed = WorldManager.world_seed
	save.saved_at_unix = Time.get_unix_time_from_system() as int
	for plan in WorldManager.plans.values():
		save.plans.append(plan)
	for region in WorldManager.regions.values():
		save.regions.append(region)
	# Phase 9a: snapshot interiors.
	for interior in MapManager.interiors.values():
		save.interiors.append(interior)
	if MapManager.active_interior != null:
		save.active_interior_id = MapManager.active_interior.map_id
	if world != null and world._region != null:
		save.active_region_id = world._region.region_id
		for pid in 2:
			var p: PlayerController = world.get_player(pid)
			var psd := PlayerSaveData.new()
			psd.player_id = pid
			psd.region_id = world._region.region_id
			psd.position = p.position
			psd.is_sailing = p.is_sailing
			psd.health = p.health
			psd.max_health = p.max_health
			if p.inventory != null:
				psd.inventory_data = p.inventory.to_dict()
			if p.equipment != null:
				psd.equipment_data = p.equipment.to_dict()
			psd.stats = p.stats.duplicate()
			save.players.append(psd)
	save.game_state_flags = GameState.to_dict()
	return save


## Apply this save to WorldManager + (optionally) `world`. Resets caches.
func apply(world: WorldRoot = null) -> void:
	WorldManager.reset(world_seed)
	GameState.from_dict(game_state_flags)
	for plan in plans:
		WorldManager.plans[plan.region_id] = plan
	for region in regions:
		WorldManager.regions[region.region_id] = region
	# Phase 9a: restore interiors.
	MapManager.reset()
	for interior in interiors:
		MapManager.interiors[interior.map_id] = interior
	# Re-mark the active interior even when no world is attached so headless
	# callers (and tests) see the same state.
	if active_interior_id != &"" and MapManager.interiors.has(active_interior_id):
		var m: InteriorMap = MapManager.interiors[active_interior_id]
		MapManager.active_interior = m
		MapManager.active_interior_changed.emit(m)
	if world == null:
		return
	world.load_region(active_region_id)
	for psd in players:
		var p: PlayerController = world.get_player(psd.player_id)
		p.position = psd.position
		# Sailing state restoration is best-effort: we restore the flag so
		# walkability checks stay consistent, but the boat sprite is not
		# re-bound to a specific Boat instance until Phase 8 polish.
		p.is_sailing = psd.is_sailing
		p.max_health = psd.max_health
		p.health = psd.health
		if p.inventory != null and not psd.inventory_data.is_empty():
			p.inventory.from_dict(psd.inventory_data)
		if p.equipment != null and not psd.equipment_data.is_empty():
			p.equipment.from_dict(psd.equipment_data)
		if not psd.stats.is_empty():
			p.stats = psd.stats.duplicate()
	# Phase 9a: enter active interior in the live world (Game.gd's signal
	# handler will repaint the WorldRoot).
	if active_interior_id != &"" and MapManager.interiors.has(active_interior_id) \
			and MapManager.active_interior == null:
		var m: InteriorMap = MapManager.interiors[active_interior_id]
		MapManager.active_interior = m
		MapManager.active_interior_changed.emit(m)


## Convenience: snapshot + write to slot. Returns OK or an Error code.
static func save_to_slot(world: WorldRoot, slot: String) -> int:
	ensure_dir()
	var save: SaveGame = snapshot(world)
	var path: String = slot_path(slot)
	var bak: String = backup_path(slot)
	# Move existing save to backup before overwriting (best-effort).
	if FileAccess.file_exists(path):
		var da := DirAccess.open(_SAVE_DIR)
		if da != null:
			da.remove(bak)
			da.rename(path.get_file(), bak.get_file())
	return ResourceSaver.save(save, path)


## Convenience: load + apply. Returns the SaveGame, or null on failure.
static func load_from_slot(slot: String, world: WorldRoot = null) -> SaveGame:
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var save := load(path) as SaveGame
	if save == null:
		return null
	save.apply(world)
	return save
