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
## Font size in screen pixels. The label is counter-scaled by 1/RENDER_ZOOM
## so it renders crisp at native resolution instead of being pixel-upscaled
## with the rest of the world.
const _LABEL_FONT_SIZE: int = 14

@export var item_id: StringName = &""
@export var count: int = 1

var _world: WorldRoot = null
var _consumed: bool = false
var _visual: Sprite2D = null
var _label: Label = null
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
	# Prefer hires icon; fall back to character-sheet equipment sprite, then placeholder.
	if def != null and def.icon != null:
		_visual.texture = def.icon
	else:
		var equip_tex: Texture2D = _try_equipment_sprite(def)
		if equip_tex != null:
			_visual.texture = equip_tex
		else:
			var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color(0.95, 0.85, 0.25, 1.0))
			_visual.texture = ImageTexture.create_from_image(img)
	# Scale the visual so it always occupies exactly one tile (TILE_PX world pixels).
	if _visual.texture != null:
		var tex_w: int = _visual.texture.get_width()
		if tex_w > 0:
			var s: float = float(WorldConst.TILE_PX) / float(tex_w)
			_visual.scale = Vector2(s, s)
	_visual.modulate = Color(1, 1, 1, 0.95)
	add_child(_visual)
	# Small floating label — persists until the item is collected.
	# Counter-scaled by 1/RENDER_ZOOM so text renders at native resolution
	# rather than being pixel-upscaled with the 4× world scale.
	var display_name: String = def.display_name if def != null else String(item_id)
	_label = Label.new()
	_label.name = "Label"
	_label.text = "%s x%d" % [display_name, count]
	var inv_zoom: float = 1.0 / float(WorldConst.RENDER_ZOOM)
	_label.scale = Vector2(inv_zoom, inv_zoom)
	# Position is in world pixels. At 0.25 scale the text appears 6 world px
	# left and 10 world px above the item = 24 px left, 40 px above on screen.
	_label.position = Vector2(-6, -10)
	_label.add_theme_font_size_override("font_size", _LABEL_FONT_SIZE)
	# Tint label by rarity.
	if def != null and def.rarity != ItemDefinition.Rarity.COMMON:
		var rc: Color = ItemDefinition.RARITY_COLORS.get(def.rarity, Color.WHITE)
		_label.add_theme_color_override("font_color", rc)
	add_child(_label)


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
			if p.caravan_data != null and p.caravan_data.travel_logs.size() > p.player_id:
				p.caravan_data.travel_logs[p.player_id].record_loot(count - leftover)
			# Float the label away before freeing.
			if _label != null:
				_label.reparent(get_parent())
				_label.global_position = global_position + Vector2(-6, -10) * float(WorldConst.RENDER_ZOOM)
				var tw := _label.create_tween()
				tw.set_parallel(true)
				# Float 5 world px up (= 20 screen px) over 0.8 s.
				tw.tween_property(_label, "position:y", _label.position.y - 5.0, 0.8)
				tw.tween_property(_label, "modulate:a", 0.0, 0.8)
				tw.chain().tween_callback(_label.queue_free)
				_label = null
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
