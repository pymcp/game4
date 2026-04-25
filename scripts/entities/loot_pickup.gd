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
const _BOB_AMP_PX: float = 2.0
const _BOB_HZ: float = 1.0

@export var item_id: StringName = &""
@export var count: int = 1

var _world: WorldRoot = null
var _consumed: bool = false
var _visual: Sprite2D = null
var _bob_t: float = 0.0


func _ready() -> void:
	var n: Node = self
	while n != null and not (n is WorldRoot):
		n = n.get_parent()
	_world = n as WorldRoot
	# Show equipment sprite if available, else item icon, else coloured square.
	_visual = Sprite2D.new()
	_visual.name = "Visual"
	var def: ItemDefinition = ItemRegistry.get_item(item_id) if item_id != &"" else null
	var equip_tex: Texture2D = _try_equipment_sprite(def)
	if equip_tex != null:
		_visual.texture = equip_tex
	elif def != null and def.icon != null:
		_visual.texture = def.icon
	else:
		var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.95, 0.85, 0.25, 1.0))
		_visual.texture = ImageTexture.create_from_image(img)
	_visual.modulate = Color(1, 1, 1, 0.95)
	add_child(_visual)
	# Small floating label so players know what they're picking up.
	var display_name: String = def.display_name if def != null else String(item_id)
	var label := Label.new()
	label.name = "Label"
	label.text = "%s x%d" % [display_name, count]
	label.position = Vector2(-30, -38)
	label.add_theme_font_size_override("font_size", 7)
	# Tint label by rarity.
	if def != null and def.rarity != ItemDefinition.Rarity.COMMON:
		var rc: Color = ItemDefinition.RARITY_COLORS.get(def.rarity, Color.WHITE)
		label.add_theme_color_override("font_color", rc)
	add_child(label)
	# Scroll label up and fade it out over 2 seconds.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 20.0, 2.0)
	tw.tween_property(label, "modulate:a", 0.0, 2.0)


func _process(delta: float) -> void:
	# Gentle bob animation.
	if _visual != null:
		_bob_t += delta
		_visual.position.y = sin(_bob_t * TAU * _BOB_HZ) * _BOB_AMP_PX
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


## Try to create an AtlasTexture from the character sheet for equipment items.
## Returns null if no equipment sprite is set.
static func _try_equipment_sprite(def: ItemDefinition) -> Texture2D:
	if def == null:
		return null
	var cell: Vector2i = Vector2i(-1, -1)
	if def.weapon_sprite != Vector2i(-1, -1):
		cell = def.weapon_sprite
	elif def.armor_sprite != Vector2i(-1, -1):
		cell = def.armor_sprite
	elif def.shield_sprite != Vector2i(-1, -1):
		cell = def.shield_sprite
	if cell == Vector2i(-1, -1):
		return null
	var sheet_path: String = "res://assets/characters/roguelike/characters_sheet.png"
	if not ResourceLoader.exists(sheet_path):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(sheet_path)
	atlas.region = Rect2(
		cell.x * CharacterAtlas.STRIDE,
		cell.y * CharacterAtlas.STRIDE,
		CharacterAtlas.TILE,
		CharacterAtlas.TILE)
	return atlas
