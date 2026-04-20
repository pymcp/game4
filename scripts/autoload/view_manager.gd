## ViewManager
##
## Per-player active-view state for the split-screen co-op design. Each
## player can independently be on the overworld, in a city, in a house, or
## in a dungeon — possibly different from the other player. Every WorldRoot
## subscribes to `player_view_changed` and reacts only to its own player_id.
##
## State per player_id (0 or 1):
##   - view_kind: &"overworld" | &"city" | &"house" | &"dungeon"
##   - region_id: Vector2i (the overworld region the player belongs to;
##                stays valid even while inside an interior so we know
##                where to drop them on exit)
##   - interior:  InteriorMap or null (set when view_kind != overworld)
##
## `enter_overworld(pid, region_id)` and `enter_interior(pid, interior,
## view_kind)` are the only mutators. Persistence lives in `SaveGame`.
extends Node

signal player_view_changed(player_id, view_kind, region, interior)

const PLAYER_COUNT: int = 2

var _state: Array = []  # Array of Dictionaries: {view_kind, region_id, interior}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset()


func reset() -> void:
	_state.clear()
	for i in PLAYER_COUNT:
		_state.append({
			"view_kind": &"overworld",
			"region_id": Vector2i.ZERO,
			"interior": null,
		})


# --- Queries -------------------------------------------------------

func get_view_kind(player_id: int) -> StringName:
	return _state[player_id]["view_kind"]


func get_region_id(player_id: int) -> Vector2i:
	return _state[player_id]["region_id"]


func get_interior(player_id: int) -> InteriorMap:
	return _state[player_id]["interior"]


# --- Mutators ------------------------------------------------------

## Move player `player_id` onto the overworld in `region_id`. If the player
## was inside an interior, that interior is dropped from their state.
func enter_overworld(player_id: int, region_id: Vector2i) -> void:
	var st: Dictionary = _state[player_id]
	st["view_kind"] = &"overworld"
	st["region_id"] = region_id
	st["interior"] = null
	var region: Region = WorldManager.get_or_generate(region_id)
	player_view_changed.emit(player_id, &"overworld", region, null)


## Move player `player_id` into `interior`. `view_kind` should be one of
## &"city", &"house", &"dungeon" (matching the InteriorMap's content). The
## player's `region_id` is NOT cleared so we know where to come back to.
func enter_interior(player_id: int, interior: InteriorMap, view_kind: StringName) -> void:
	var st: Dictionary = _state[player_id]
	st["view_kind"] = view_kind
	st["interior"] = interior
	if interior != null and interior.origin_region_id != Vector2i.ZERO:
		st["region_id"] = interior.origin_region_id
	var region: Region = WorldManager.get_or_generate(st["region_id"])
	player_view_changed.emit(player_id, view_kind, region, interior)
