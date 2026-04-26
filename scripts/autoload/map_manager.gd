## MapManager
##
## Autoload that owns interior maps (dungeons, buildings, caves) and tracks
## which one the players are currently in. Mirrors the design of
## [WorldManager] but for interiors.
##
## Maps are keyed by a `StringName` id derived from the entrance location:
##   `&"dungeon@<region_id.x>:<region_id.y>:<cell.x>:<cell.y>:<floor>"`
##
## Floors are 1-based; each floor is a separately-generated [InteriorMap]
## sharing the same base id minus the floor suffix.
##
## Phase 8b: data layer only. Phase 8c does the actual scene transition.
extends Node

signal interior_generated(map_id: StringName)
signal active_interior_changed(map: InteriorMap)
signal exited_to_overworld(region_id: Vector2i, cell: Vector2i)

const DEFAULT_FLOOR_SIZE: int = 32

var interiors: Dictionary = {}   # StringName -> InteriorMap
var active_interior: InteriorMap = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Build the canonical id for an entrance + floor. `kind` controls the
## prefix so a house and a dungeon at the same overworld cell don't
## collide in the cache (they almost never share a cell, but the prefix
## also lets readers tell map kinds apart from the id alone).
static func make_id(region_id: Vector2i, cell: Vector2i, floor_num: int = 1,
		kind: StringName = &"dungeon") -> StringName:
	return StringName("%s@%d:%d:%d:%d:%d" % [
		String(kind), region_id.x, region_id.y, cell.x, cell.y, floor_num])


## Returns the [InteriorMap] for `map_id`, generating it on demand.
## Caller supplies the entrance metadata; the map's `origin_*` fields are
## stamped so [exit_to_overworld] can teleport the players back.
## `kind` selects the generator: &"dungeon" (default) uses
## [DungeonGenerator]; &"house" uses [HouseGenerator] and ignores `size`.
func get_or_generate(map_id: StringName, region_id: Vector2i,
		cell: Vector2i, floor_num: int = 1, size: int = DEFAULT_FLOOR_SIZE,
		kind: StringName = &"dungeon") -> InteriorMap:
	if interiors.has(map_id):
		return interiors[map_id]
	var seed_val: int = _seed_for(region_id, cell, floor_num)
	var m: InteriorMap
	if kind == &"house":
		m = HouseGenerator.generate(seed_val)
	elif kind == &"labyrinth":
		m = LabyrinthGenerator.generate(seed_val, size, size, floor_num)
	else:
		m = DungeonGenerator.generate(seed_val, size, size)
	m.map_id = map_id
	m.origin_region_id = region_id
	m.origin_cell = cell
	m.floor_num = floor_num
	interiors[map_id] = m
	interior_generated.emit(map_id)
	return m


## Returns the cave one floor below `current`, generating it on demand.
## The new floor inherits the same overworld origin (so climbing back to
## floor 1 still leads to the right region/cell) but uses
## `current.floor_num + 1` for both seeding and id derivation, so each
## descent yields a deterministic but distinct layout. The first time the
## descent happens we record the parent linkage so STAIRS_UP on the deeper
## floor knows where to drop the player on the floor above.
func descend_from(current: InteriorMap, size: int = DEFAULT_FLOOR_SIZE) -> InteriorMap:
	var next_floor: int = current.floor_num + 1
	var rid: Vector2i = current.origin_region_id
	var origin: Vector2i = current.origin_cell
	var kind: StringName = _kind_from_id(current.map_id)
	var new_id: StringName = make_id(rid, origin, next_floor, kind)
	var m: InteriorMap = get_or_generate(new_id, rid, origin, next_floor, size, kind)
	if m.parent_map_id == &"":
		m.parent_map_id = current.map_id
		m.parent_entrance_cell = current.exit_cell
	return m


## Returns the parent (one floor up) of `current`, or null when `current`
## is floor 1 (whose parent is the overworld).
func get_parent_interior(current: InteriorMap) -> InteriorMap:
	if current.parent_map_id == &"":
		return null
	return interiors.get(current.parent_map_id, null)


## Mark `map_id` as the currently-active interior (creating if needed) and
## emit `active_interior_changed`. Pass an empty StringName to clear.
func set_active(map_id: StringName, region_id: Vector2i = Vector2i.ZERO,
		cell: Vector2i = Vector2i.ZERO, floor_num: int = 1) -> InteriorMap:
	if map_id == &"":
		active_interior = null
		active_interior_changed.emit(null)
		return null
	var m: InteriorMap = get_or_generate(map_id, region_id, cell, floor_num)
	if active_interior == m:
		return m
	active_interior = m
	active_interior_changed.emit(m)
	return m


## Leaves the current interior; signals listeners to reload the overworld
## at the previously-recorded entrance cell.
func exit_to_overworld() -> void:
	if active_interior == null:
		return
	var rid: Vector2i = active_interior.origin_region_id
	var cell: Vector2i = active_interior.origin_cell
	active_interior = null
	exited_to_overworld.emit(rid, cell)
	active_interior_changed.emit(null)


## Reset all interior state (used by tests / New Game).
func reset() -> void:
	interiors.clear()
	active_interior = null


# ─── Internals ────────────────────────────────────────────────────────

## Extract the kind prefix from a map_id (e.g. "labyrinth@1:2:3:4:1" → &"labyrinth").
static func _kind_from_id(map_id: StringName) -> StringName:
	var s: String = String(map_id)
	var at: int = s.find("@")
	if at >= 0:
		return StringName(s.substr(0, at))
	return &"dungeon"

static func _seed_for(region_id: Vector2i, cell: Vector2i, floor_num: int) -> int:
	# Mix the world seed in so the same entrance differs across worlds.
	var ws: int = WorldManager.world_seed if WorldManager else 0
	return (ws * 2654435761) ^ (region_id.x * 19349663) \
		^ (region_id.y * 83492791) ^ (cell.x * 374761393) \
		^ (cell.y * 668265263) ^ (floor_num * 1274126177)
