## LootPickup
##
## Lightweight world entity that gives its `item_id` * `count` to the first
## player who steps within `_PICKUP_RADIUS_TILES`. Spawned by `WorldRoot`
## when entering an interior with non-empty `loot_scatter`.
##
## We use a simple per-frame distance check rather than an Area2D so the
## node has no physics dependencies and tests can drive interactions
## deterministically.
extends Node2D
class_name LootPickup

const _PICKUP_RADIUS_TILES: float = 0.7

@export var item_id: StringName = &""
@export var count: int = 1

var _world: WorldRoot = null
var _consumed: bool = false


func _ready() -> void:
	var n: Node = self
	while n != null and not (n is WorldRoot):
		n = n.get_parent()
	_world = n as WorldRoot
	# Show the item's icon if available, else fall back to a coloured square.
	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	var def: ItemDefinition = ItemRegistry.get_item(item_id) if item_id != &"" else null
	if def != null and def.icon != null:
		sprite.texture = def.icon
	else:
		var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.95, 0.85, 0.25, 1.0))
		sprite.texture = ImageTexture.create_from_image(img)
	sprite.modulate = Color(1, 1, 1, 0.95)
	add_child(sprite)
	# Small floating label so players know what they're picking up.
	var display_name: String = def.display_name if def != null else String(item_id)
	var label := Label.new()
	label.name = "Label"
	label.text = "%s x%d" % [display_name, count]
	label.position = Vector2(-30, -38)
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)


func _process(_delta: float) -> void:
	if _consumed or _world == null:
		return
	var radius_px: float = _PICKUP_RADIUS_TILES * float(WorldConst.TILE_PX)
	for pid in 2:
		var p: PlayerController = _world.get_player(pid)
		if p == null:
			continue
		if position.distance_squared_to(p.position) > radius_px * radius_px:
			continue
		if p.inventory == null:
			continue
		var leftover: int = p.inventory.add(item_id, count)
		if leftover < count:
			_consumed = true
			queue_free()
			Sfx.play(&"loot_pickup")
			return
