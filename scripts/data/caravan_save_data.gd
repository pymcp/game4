## CaravanSaveData
##
## Snapshot of one player's caravan state for save/load.
## Stored inside SaveGame.caravans (array of two, one per player).
class_name CaravanSaveData
extends Resource

@export var player_id: int = 0
## IDs of recruited party members.
@export var recruited_ids: Array[StringName] = []
## Serialized caravan inventory (from CaravanData.inventory.to_dict()).
@export var inventory_data: Dictionary = {}
## Serialized TravelLog data (array of 2 dicts, index = player_id).
@export var travel_log_data: Array[Dictionary] = []
## Rolled member names (StringName string keys → name strings).
@export var member_names: Dictionary = {}
