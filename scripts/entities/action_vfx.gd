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

## Spell orb texture.
const _SPELL_TEXTURE_PATH: String = "res://assets/particles/pack/star_06.png"

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


# --- Combat dispatcher -------------------------------------------

## Main entry point for weapon-based attacks. Dispatches VFX based on
## weapon_category and tints particles by element.
func play_attack(target_cell: Vector2i, category: int, element: int,
		attack_speed: float) -> void:
	if _is_playing:
		return
	var dur: float = clampf(attack_speed * 0.6, 0.1, 0.4)
	match category:
		ItemDefinition.WeaponCategory.SWORD:
			_play_swing(target_cell, -60.0, 60.0, dur, element)
		ItemDefinition.WeaponCategory.AXE:
			_play_swing(target_cell, -90.0, 20.0, dur, element)
		ItemDefinition.WeaponCategory.DAGGER:
			_play_swing(target_cell, -30.0, 30.0, dur * 0.6, element)
		ItemDefinition.WeaponCategory.SPEAR:
			_play_thrust(target_cell, dur, element)
		ItemDefinition.WeaponCategory.BOW:
			play_ranged(target_cell, dur, element)
		ItemDefinition.WeaponCategory.STAFF:
			_play_spell(target_cell, dur, element)
		_:
			_play_swing(target_cell, -60.0, 60.0, dur, element)


## Parameterized arc swing: SWORD, AXE, DAGGER with different arcs.
func _play_swing(target_cell: Vector2i, from_deg: float, to_deg: float,
		duration: float, element: int) -> void:
	_is_playing = true
	var target_pos: Vector2 = _target_world_pos(target_cell) - _player.position
	var swing_spr := _create_icon_sprite(_get_weapon_id(), target_pos)
	if swing_spr == null:
		_spawn_combat_particles(target_cell, element)
		_finish()
		return
	add_child(swing_spr)
	swing_spr.rotation_degrees = from_deg
	var tw := create_tween()
	tw.tween_property(swing_spr, "rotation_degrees", to_deg, duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		swing_spr.queue_free()
		_finish()
	)
	_sympathetic_tilt()
	_spawn_combat_particles(target_cell, element)


## Spear / polearm thrust: linear forward motion, no arc.
func _play_thrust(target_cell: Vector2i, duration: float, element: int) -> void:
	_is_playing = true
	var target_pos: Vector2 = _target_world_pos(target_cell) - _player.position
	var spr := _create_icon_sprite(_get_weapon_id(), _facing_offset())
	if spr == null:
		_spawn_combat_particles(target_cell, element)
		_finish()
		return
	add_child(spr)
	spr.rotation = Vector2(_player._facing_dir).angle()
	var tw := create_tween()
	tw.tween_property(spr, "position", target_pos, duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		spr.queue_free()
		_finish()
	)
	_sympathetic_tilt()
	_spawn_combat_particles(target_cell, element)


## Staff / magic spell: colored orb projectile.
func _play_spell(target_cell: Vector2i, duration: float, element: int) -> void:
	_is_playing = true
	var start_pos: Vector2 = _facing_offset()
	var end_pos: Vector2 = _target_world_pos(target_cell) - _player.position
	var orb := Sprite2D.new()
	var tex: Texture2D = load(_SPELL_TEXTURE_PATH)
	orb.texture = tex
	orb.scale = Vector2(0.15, 0.15)
	orb.position = start_pos
	match element:
		ItemDefinition.Element.FIRE:
			orb.modulate = Color(1.0, 0.5, 0.15)
		ItemDefinition.Element.ICE:
			orb.modulate = Color(0.4, 0.8, 1.0)
		ItemDefinition.Element.LIGHTNING:
			orb.modulate = Color(1.0, 1.0, 0.3)
		ItemDefinition.Element.POISON:
			orb.modulate = Color(0.4, 0.85, 0.3)
		_:
			orb.modulate = Color(0.8, 0.6, 1.0)
	add_child(orb)
	var tw := create_tween()
	tw.tween_property(orb, "position", end_pos, duration)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		orb.queue_free()
		_spawn_combat_particles(target_cell, element)
		_finish()
	)


func _spawn_combat_particles(target_cell: Vector2i, element: int) -> void:
	if _world == null:
		return
	var pos: Vector2 = _target_world_pos(target_cell)
	ActionParticles.spawn_impact(_world.entities, pos, ActionParticles.Action.MELEE, &"", element)


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

func play_ranged(target_cell: Vector2i, duration: float = 0.15,
		element: int = 0) -> void:
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
	tw.tween_property(arrow, "position", end_pos, duration)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		arrow.queue_free()
		_spawn_ranged_particles(target_cell, element)
		_finish()
	)

	# Bow pull-back effect on persistent weapon.
	_bow_pullback()


func _spawn_ranged_particles(target_cell: Vector2i,
		element: int = 0) -> void:
	if _world == null:
		return
	var pos: Vector2 = _target_world_pos(target_cell)
	ActionParticles.spawn_impact(_world.entities, pos, ActionParticles.Action.RANGED, &"", element)


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


func _get_weapon_id() -> StringName:
	if _player == null:
		return &""
	var wid: StringName = _player.equipment.get_equipped(ItemDefinition.Slot.WEAPON)
	if wid != &"":
		return wid
	return _player.equipment.get_equipped(ItemDefinition.Slot.TOOL)


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
