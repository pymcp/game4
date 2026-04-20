## SaveManager
##
## Autoload coordinating save/load:
##   - Slot management (default slot = "slot0")
##   - 5-minute autosave timer (game-time, paused with the tree)
##   - Save on region transition (subscribes to WorldManager.active_region_changed)
##
## The actual snapshot/apply lives on `SaveGame` itself; this autoload just
## decides *when* to save.
extends Node

const AUTOSAVE_INTERVAL_SEC: float = 300.0
const DEFAULT_SLOT: String = "slot0"

signal save_completed(slot)
signal load_completed(slot)

var current_slot: String = DEFAULT_SLOT
var _timer: Timer = null
var _world: WorldRoot = null


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = AUTOSAVE_INTERVAL_SEC
	_timer.one_shot = false
	_timer.timeout.connect(_on_autosave_tick)
	add_child(_timer)


## Bind the SaveManager to the active world; called by Game._ready (Phase 4).
func attach_world(world: WorldRoot) -> void:
	_world = world
	_timer.start()
	if not WorldManager.active_region_changed.is_connected(_on_region_changed):
		WorldManager.active_region_changed.connect(_on_region_changed)


func detach_world() -> void:
	_world = null
	_timer.stop()
	if WorldManager.active_region_changed.is_connected(_on_region_changed):
		WorldManager.active_region_changed.disconnect(_on_region_changed)


func save_now(slot: String = "") -> int:
	if slot == "":
		slot = current_slot
	current_slot = slot
	var err: int = SaveGame.save_to_slot(_world, slot)
	if err == OK:
		save_completed.emit(slot)
	return err


func load_now(slot: String = "") -> SaveGame:
	if slot == "":
		slot = current_slot
	current_slot = slot
	var save: SaveGame = SaveGame.load_from_slot(slot, _world)
	if save != null:
		load_completed.emit(slot)
	return save


func _on_autosave_tick() -> void:
	if _world == null:
		return
	save_now()


func _on_region_changed(_region) -> void:
	if _world == null:
		return
	save_now()
