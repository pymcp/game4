## ActionVFX
##
## Tween-driven visual effects for player actions: melee swing, mine swing,
## gather rustle, and ranged shot. Spawns temporary sprites that animate
## via [Tween] and self-free, plus themed [CPUParticles2D] via
## [ActionParticles].
##
## Attached as a direct child of the Player root (NOT under SpriteRoot)
## so it doesn't h-flip with the character. Reads facing direction and
## position from the parent [PlayerController].
extends Node2D
class_name ActionVFX

## If true, an animation is currently playing. Prevents overlap.
var _is_playing: bool = false

## Pixel size of one tile (matches WorldConst.TILE_PX).
const _TILE_PX: float = 16.0

## Icon scale for the enlarged swing sprite (100-140px icons → ~16px).
const _ICON_SCALE: float = 0.12

## Arrow/projectile texture.
const _ARROW_TEXTURE_PATH: String = "res://assets/particles/pack/trace_05.png"

# References set by PlayerController after instancing.
var _weapon_sprite: Sprite2D = null
var _world: WorldRoot = null
var _player: PlayerController = null


func setup(player: PlayerController, weapon_spr: Sprite2D, world: WorldRoot) -> void:
	_player = player
	_weapon_sprite = weapon_spr
	_world = world


## True while a VFX tween is playing.
func is_playing() -> bool:
	return _is_playing


# --- Target helpers -----------------------------------------------

func _target_world_pos(target_cell: Vector2i) -> Vector2:
	return (Vector2(target_cell) + Vector2(0.5, 0.5)) * _TILE_PX


func _facing_offset() -> Vector2:
	if _player == null:
		return Vector2(8, 0)
	return Vector2(_player._facing_dir) * 8.0


# --- Melee swing ---------------------------------------------------

func play_melee_swing(target_cell: Vector2i) -> void:
	if _is_playing:
		return
	_is_playing = true

	var target_pos: Vector2 = _target_world_pos(target_cell) - _player.position
	var swing_spr := _create_icon_sprite(
		equipment_get(&"sword"), target_pos)
	if swing_spr == null:
		# No icon — just do particles.
		_spawn_melee_particles(target_cell)
		_finish()
		return

	add_child(swing_spr)
	swing_spr.rotation_degrees = -60.0

	var tw := create_tween()
	tw.tween_property(swing_spr, "rotation_degrees", 60.0, 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		swing_spr.queue_free()
		_finish()
	)

	# Sympathetic tilt on persistent weapon.
	_sympathetic_tilt()
	_spawn_melee_particles(target_cell)


func _spawn_melee_particles(target_cell: Vector2i) -> void:
	if _world == null:
		return
	var pos: Vector2 = _target_world_pos(target_cell)
	ActionParticles.spawn_impact(_world.entities, pos, ActionParticles.Action.MELEE)


# --- Mine swing ----------------------------------------------------

func play_mine_swing(target_cell: Vector2i, kind: StringName = &"") -> void:
	if _is_playing:
		return
	_is_playing = true

	var target_pos: Vector2 = _target_world_pos(target_cell) - _player.position
	var swing_spr := _create_icon_sprite(
		equipment_get(&"pickaxe"), target_pos)
	if swing_spr == null:
		_spawn_mine_particles(target_cell, kind)
		_finish()
		return

	add_child(swing_spr)
	swing_spr.rotation_degrees = -90.0

	var tw := create_tween()
	tw.tween_property(swing_spr, "rotation_degrees", 20.0, 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		swing_spr.queue_free()
		_finish()
	)

	_sympathetic_tilt()
	_spawn_mine_particles(target_cell, kind)


func _spawn_mine_particles(target_cell: Vector2i, kind: StringName) -> void:
	if _world == null:
		return
	var pos: Vector2 = _target_world_pos(target_cell)
	ActionParticles.spawn_impact(_world.entities, pos, ActionParticles.Action.MINE, kind)


# --- Gather rustle -------------------------------------------------

func play_gather(target_cell: Vector2i) -> void:
	if _is_playing:
		return
	_is_playing = true

	_shake_tile(target_cell)
	_spawn_gather_particles(target_cell)


func _shake_tile(target_cell: Vector2i) -> void:
	if _world == null:
		_finish()
		return
	# Read the current decoration cell so we can recreate it visually.
	var deco_layer: TileMapLayer = _world.decoration
	var source_id: int = deco_layer.get_cell_source_id(target_cell)
	if source_id < 0:
		# No tile to shake — just finish.
		_finish()
		return
	var atlas_coords: Vector2i = deco_layer.get_cell_atlas_coords(target_cell)
	var alt_id: int = deco_layer.get_cell_alternative_tile(target_cell)

	# Create a temp Sprite2D at the tile's position.
	var tile_pos: Vector2 = _target_world_pos(target_cell)
	var tmp := Sprite2D.new()
	# Use the tileset's texture. Get it from the tile source.
	var ts: TileSet = deco_layer.tile_set
	var src: TileSetAtlasSource = ts.get_source(source_id) as TileSetAtlasSource
	if src == null:
		_finish()
		return
	tmp.texture = src.texture
	tmp.region_enabled = true
	var tex_region_size: Vector2i = src.get_tile_texture_region(atlas_coords).size
	tmp.region_rect = src.get_tile_texture_region(atlas_coords)
	tmp.position = tile_pos
	tmp.centered = true

	# Hide the real tile temporarily.
	deco_layer.set_cell(target_cell, -1)
	_world.entities.add_child(tmp)

	# Oscillate ±2px horizontally for 3 cycles over 0.3s.
	var tw := create_tween()
	var base_x: float = tile_pos.x
	for i in 3:
		tw.tween_property(tmp, "position:x", base_x + 2.0, 0.05)
		tw.tween_property(tmp, "position:x", base_x - 2.0, 0.05)
	tw.tween_property(tmp, "position:x", base_x, 0.05)  # return to center
	tw.tween_callback(func():
		# Restore the real tile.
		deco_layer.set_cell(target_cell, source_id, atlas_coords, alt_id)
		tmp.queue_free()
		_finish()
	)


func _spawn_gather_particles(target_cell: Vector2i) -> void:
	if _world == null:
		return
	var pos: Vector2 = _target_world_pos(target_cell)
	ActionParticles.spawn_impact(_world.entities, pos, ActionParticles.Action.GATHER)


# --- Ranged shot ---------------------------------------------------

func play_ranged(target_cell: Vector2i) -> void:
	if _is_playing:
		return
	_is_playing = true

	var start_pos: Vector2 = _facing_offset()  # relative to player
	var end_pos: Vector2 = _target_world_pos(target_cell) - _player.position

	var arrow := Sprite2D.new()
	var tex: Texture2D = load(_ARROW_TEXTURE_PATH)
	arrow.texture = tex
	arrow.scale = Vector2(0.1, 0.1)
	arrow.position = start_pos
	# Rotate arrow to face the travel direction.
	var dir: Vector2 = (end_pos - start_pos).normalized()
	arrow.rotation = dir.angle()
	add_child(arrow)

	var tw := create_tween()
	tw.tween_property(arrow, "position", end_pos, 0.15)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		arrow.queue_free()
		_spawn_ranged_particles(target_cell)
		_finish()
	)

	# Bow pull-back effect on persistent weapon.
	_bow_pullback()


func _spawn_ranged_particles(target_cell: Vector2i) -> void:
	if _world == null:
		return
	var pos: Vector2 = _target_world_pos(target_cell)
	ActionParticles.spawn_impact(_world.entities, pos, ActionParticles.Action.RANGED)


# --- Shared helpers ------------------------------------------------

func _create_icon_sprite(item_id: StringName, local_pos: Vector2) -> Sprite2D:
	if item_id == &"":
		return null
	var def: ItemDefinition = ItemRegistry.get_item(item_id)
	if def == null or def.icon == null:
		return null
	var spr := Sprite2D.new()
	spr.texture = def.icon
	spr.scale = Vector2(_ICON_SCALE, _ICON_SCALE)
	spr.position = local_pos
	return spr


func equipment_get(fallback_id: StringName) -> StringName:
	if _player == null:
		return fallback_id
	# For mine swing: check TOOL slot. For melee: check WEAPON slot.
	var tool_id: StringName = _player.equipment.get_equipped(ItemDefinition.Slot.TOOL)
	if tool_id != &"":
		return tool_id
	var weapon_id: StringName = _player.equipment.get_equipped(ItemDefinition.Slot.WEAPON)
	if weapon_id != &"":
		return weapon_id
	return fallback_id


func _sympathetic_tilt() -> void:
	if _weapon_sprite == null or not _weapon_sprite.visible:
		return
	var tw := create_tween()
	tw.tween_property(_weapon_sprite, "rotation_degrees", 15.0, 0.1)
	tw.tween_property(_weapon_sprite, "rotation_degrees", 0.0, 0.1)


func _bow_pullback() -> void:
	if _weapon_sprite == null or not _weapon_sprite.visible:
		return
	var tw := create_tween()
	tw.tween_property(_weapon_sprite, "scale:x", 0.8, 0.08)
	tw.tween_property(_weapon_sprite, "scale:x", 1.0, 0.08)


func _finish() -> void:
	_is_playing = false
