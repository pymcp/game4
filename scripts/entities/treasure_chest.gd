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

## Players currently in interaction range (tracked by Area2D signals).
var _players_in_range: Array = []

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _area: Area2D = $Area2D

## Atlas cells on dungeon_sheet.png for closed and open frames.
const _CLOSED_CELL: Vector2i = Vector2i(2, 10)
const _OPEN_CELL:   Vector2i = Vector2i(3, 10)
const _TILE_PX: int = 16
const _MARGIN: int = 1


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_refresh_sprite(false)


## Called by WorldRoot when a player in range presses their interact input.
func open(player: Node) -> void:
	if is_opened:
		return
	is_opened = true
	_refresh_sprite(true)

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


## Returns the first player in range, or null.
func nearest_player_in_range() -> Node:
	for p in _players_in_range:
		if is_instance_valid(p):
			return p
	return null


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_hit"):
		_players_in_range.append(body)


func _on_body_exited(body: Node) -> void:
	_players_in_range.erase(body)


func _refresh_sprite(opened: bool) -> void:
	if _sprite == null:
		return
	var atlas: Vector2i = _OPEN_CELL if opened else _CLOSED_CELL
	var tex: Texture2D = load("res://assets/tiles/roguelike/dungeon_sheet.png")
	if tex == null:
		return
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(
		atlas.x * (_TILE_PX + _MARGIN),
		atlas.y * (_TILE_PX + _MARGIN),
		_TILE_PX, _TILE_PX)
	_sprite.centered = true
