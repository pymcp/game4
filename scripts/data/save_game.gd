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

## v5→v6: Added xp, level, unlocked_passives, pending_stat_points to PlayerSaveData.
##         Missing fields in v5 saves default to initial values automatically.
const VERSION: int = 6
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
@export var caravans: Array[CaravanSaveData] = []
## Phase 9a: persistent dungeon state.
## Array[InteriorMap] - every interior visited so generated layouts persist.
@export var interiors: Array = []
## StringName id of the active interior, or &"" if on the overworld.
@export var active_interior_id: StringName = &""
@export var game_state_flags: Dictionary = {}
## Serialized QuestTracker state (branch + objective progress per active quest).
@export var quest_tracker_data: Dictionary = {}


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
		var world_node: World = World.instance()
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
			psd.xp = p.xp
			psd.level = p.level
			psd.unlocked_passives = p.unlocked_passives.duplicate()
			psd.pending_stat_points = p._pending_stat_points
			psd.fog_data = p.fog_of_war.to_dict()
			psd.dungeon_fog_data = p.dungeon_fog.to_dict()
			# Pet roster — read from the World coordinator.
			if world_node != null and world_node.has_method("get_active_pet_species"):
				psd.active_pet_species = world_node.call("get_active_pet_species", pid)
				var roster: Array[StringName] = world_node.call("get_pet_roster", pid)
				psd.pet_roster = roster
			save.players.append(psd)
	# Save caravan state.
	save.caravans.clear()
	var _world_node_caravan: World = World.instance()
	if _world_node_caravan != null:
		for pid in range(2):
			var caravan_data: CaravanData = _world_node_caravan.get_caravan_data(pid)
			if caravan_data == null:
				continue
			var csd := CaravanSaveData.new()
			csd.player_id = pid
			csd.recruited_ids = caravan_data.recruited_ids.duplicate()
			var d := caravan_data.to_dict()
			csd.inventory_data = d.get("inventory", {})
			var tl_data: Array = d.get("travel_logs", [{}, {}])
			csd.travel_log_data = [
				tl_data[0] if tl_data.size() > 0 else {},
				tl_data[1] if tl_data.size() > 1 else {},
			]
			csd.member_names = d.get("member_names", {}).duplicate()
			save.caravans.append(csd)
	save.game_state_flags = GameState.to_dict()
	save.quest_tracker_data = QuestTracker.to_dict()
	return save


## Apply this save to WorldManager + (optionally) `world`. Resets caches.
func apply(world: WorldRoot = null) -> void:
	# Version migration.
	if version < 3:
		caravans = []
	if version < 4:
		quest_tracker_data = {}
	# VERSION 5: pet_roster / active_pet_species — no migration needed (defaults to empty).
	WorldManager.reset(world_seed)
	GameState.from_dict(game_state_flags)
	if not quest_tracker_data.is_empty():
		QuestTracker.from_dict(quest_tracker_data)
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
		p.xp = psd.xp
		p.level = psd.level
		p.unlocked_passives = psd.unlocked_passives.duplicate()
		p._pending_stat_points = psd.pending_stat_points
		if not psd.fog_data.is_empty():
			p.fog_of_war.from_dict(psd.fog_data)
		if not psd.dungeon_fog_data.is_empty():
			p.dungeon_fog.from_dict(psd.dungeon_fog_data)
	# Restore pet rosters into GameSession so World picks them up.
	for psd: PlayerSaveData in players:
		if psd.pet_roster.is_empty():
			continue
		if psd.player_id == 0:
			GameSession.p1_pet_roster = psd.pet_roster.duplicate()
			GameSession.p1_active_pet = psd.active_pet_species
		elif psd.player_id == 1:
			GameSession.p2_pet_roster = psd.pet_roster.duplicate()
			GameSession.p2_active_pet = psd.active_pet_species
	# Restore caravan state.
	var world_node: World = World.instance() if world != null else null
	if world_node != null:
		for csd in caravans:
			var caravan_data: CaravanData = world_node.get_caravan_data(csd.player_id)
			if caravan_data == null:
				continue
			caravan_data.recruited_ids.clear()
			for id_str in csd.recruited_ids:
				caravan_data.recruited_ids.append(StringName(id_str))
			if not csd.inventory_data.is_empty():
				caravan_data.inventory.from_dict(csd.inventory_data)
			if not csd.travel_log_data.is_empty() and caravan_data.travel_logs.size() >= 2:
				caravan_data.travel_logs[0].from_dict(csd.travel_log_data[0])
				caravan_data.travel_logs[1].from_dict(csd.travel_log_data[1] if csd.travel_log_data.size() > 1 else {})
			caravan_data.member_names = csd.member_names.duplicate()
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
