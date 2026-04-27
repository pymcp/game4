## TreasureChest
##
## Interactive chest entity placed at labyrinth dead ends. A player within
## interaction range pressing their interact input opens the chest, spawning
## LootPickup nodes and switching to the open sprite frame.
##
## Interaction is handled by WorldRoot._process() which polls nearby players
## against in-range chests using the Area2D body tracking.
##
## After opening the chest stays in the world as a visual landmark (open frame).
class_name TreasureChest
extends Node2D

## Floor depth used to pick the correct chest_loot.json tier.
@export var floor_num: int = 1
## True once the chest has been opened this session.
var is_opened: bool = false

## Interaction radius in pixels (matches the old Area2D circle radius).
const INTERACT_RADIUS_PX: float = 20.0

@onready var _sprite: Sprite2D = $Sprite2D

## Atlas cells on dungeon_sheet.png for closed and open frames.
## Reads from TilesetCatalog.LABYRINTH_CHEST_CELLS (editable via Game Editor).
const _TILE_PX: int = 16
const _MARGIN: int = 1


func _ready() -> void:
	_refresh_sprite(false)


## Called by WorldRoot when a player in range presses their interact input.
func open(player: Node) -> void:
	if is_opened:
		return
	is_opened = true
	_refresh_sprite(true)

	if player is PlayerController:
		var pc := player as PlayerController
		if pc.caravan_data != null and pc.caravan_data.travel_logs.size() > pc.player_id:
			pc.caravan_data.travel_logs[pc.player_id].record_chest()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 7.0 + position.y * 13.0 + floor_num * 97)
	var count: int = rng.randi_range(2, 3)
	for i in count:
		var loot: Dictionary = ChestLootRegistry.roll_loot(floor_num, rng)
		if loot.get("id", &"") == &"":
			continue
		var pickup := LootPickup.new()
		pickup.item_id = loot["id"]
		pickup.count = loot.get("count", 1)
		var scatter := Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
		pickup.position = position + scatter
		get_parent().add_child(pickup)


## Returns true when the given player is close enough to interact.
func is_player_in_range(player: Node) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return position.distance_to((player as Node2D).position) <= INTERACT_RADIUS_PX


func _refresh_sprite(opened: bool) -> void:
	if _sprite == null:
		return
	var cells: Array = TilesetCatalog.LABYRINTH_CHEST_CELLS
	var atlas: Vector2i = cells[1] if (opened and cells.size() >= 2) else cells[0]
	var tex: Texture2D = load(TilesetCatalog.get_sheet_path(&"labyrinth_terrain"))
	if tex == null:
		return
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(
		atlas.x * (_TILE_PX + _MARGIN),
		atlas.y * (_TILE_PX + _MARGIN),
		_TILE_PX, _TILE_PX)
	_sprite.centered = true
