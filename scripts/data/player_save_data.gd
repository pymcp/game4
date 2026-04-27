## PlayerSaveData
##
## Serializable per-player snapshot. Phase 3e captures only world position
## bits; Phases 4-7 add inventory / stats / equipment by extending this
## resource (older saves load with default zero values for new fields).
class_name PlayerSaveData
extends Resource

@export var player_id: int = 0
@export var region_id: Vector2i = Vector2i.ZERO
@export var position: Vector2 = Vector2.ZERO
@export var is_sailing: bool = false
@export var health: int = 10
@export var max_health: int = 10
@export var inventory_data: Dictionary = {}
@export var equipment_data: Dictionary = {}
@export var stats: Dictionary = {}
## Serialized FogOfWarData for this player. Keys are "x,y" region strings;
## values are PackedByteArray (2048 bytes per region).
@export var fog_data: Dictionary = {}
## Serialized DungeonFogData for this player. Keys are map_id strings;
## values are PackedByteArray (2048 bytes per interior floor).
@export var dungeon_fog_data: Dictionary = {}
