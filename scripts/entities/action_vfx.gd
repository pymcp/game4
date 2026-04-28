## ActionVFX
##
## Tween-driven visual effects for entity actions: melee swing, mine swing,
## gather rustle, ranged shot, and creature attacks.
##
## Armed attacks animate the persistent weapon sprite (flash + scale +
## category motion). Unarmed and creature attacks do a quick body lunge
## toward the target.
##
## Attached as a direct child of any entity root (NOT under SpriteRoot)
## so it doesn't h-flip with the character.
extends Node2D
class_name ActionVFX

## If true, an animation is currently playing. Prevents overlap.
var _is_playing: bool = false

## Pixel size of one tile (matches WorldConst.TILE_PX).
const _TILE_PX: float = 16.0

## Lunge distance in pixels for unarmed / creature attacks.
const _LUNGE_PX: float = 4.0

## Weapon flash scale multiplier.
const _FLASH_SCALE: float = 1.3

## Arrow/projectile texture.
const _ARROW_TEXTURE_PATH: String = "res://assets/particles/pack/trace_05.png"

## Spell orb texture.
const _SPELL_TEXTURE_PATH: String = "res://assets/particles/pack/star_06.png"

# References set by the owning entity after instancing.
var _weapon_sprite: Sprite2D = null
var _world: WorldRoot = null
var _owner: Node2D = null
var _visual_root: Node2D = null  ## Node to lunge (SpriteRoot or creature Sprite).


func setup(owner: Node2D, weapon_spr: Sprite2D, world: WorldRoot,
		visual_root: Node2D = null) -> void:
	_owner = owner
	_weapon_sprite = weapon_spr
	_world = world
	_visual_root = visual_root


## True while a VFX tween is playing.
func is_playing() -> bool:
	return _is_playing


# --- Target helpers -----------------------------------------------

func _target_world_pos(target_cell: Vector2i) -> Vector2:
	return (Vector2(target_cell) + Vector2(0.5, 0.5)) * _TILE_PX


## Cached facing direction, set by callers via play methods.
var _last_facing: Vector2 = Vector2(1, 0)

func _facing_offset() -> Vector2:
	return _last_facing * 8.0


# --- Combat dispatcher -------------------------------------------

## Main entry point for weapon-based attacks. Dispatches VFX based on
## weapon_category and tints particles by element.
func play_attack(target_cell: Vector2i, category: int, element: int,
		attack_speed: float, facing: Vector2 = Vector2(1, 0),
		weapon_id: StringName = &"") -> void:
	if _is_playing:
		return
	_last_facing = facing if facing != Vector2.ZERO else Vector2(1, 0)
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
			play_ranged(target_cell, dur, element, facing)
		ItemDefinition.WeaponCategory.STAFF:
			_play_spell(target_cell, dur, element)
		_:
			_play_swing(target_cell, -60.0, 60.0, dur, element)


## Parameterized arc swing: SWORD, AXE, DAGGER with different arcs.
## Animates the persistent weapon sprite instead of spawning a copy.
func _play_swing(target_cell: Vector2i, from_deg: float, to_deg: float,
		duration: float, element: int) -> void:
	_is_playing = true
	_weapon_flash_and_rotate(from_deg, to_deg, duration)


## Spear / polearm thrust: brief forward push on the weapon sprite.
func _play_thrust(target_cell: Vector2i, duration: float, element: int) -> void:
	_is_playing = true
	_weapon_flash_and_thrust(duration)


## Staff / magic spell: colored orb projectile.
func _play_spell(target_cell: Vector2i, duration: float, element: int) -> void:
	_is_playing = true
	var start_pos: Vector2 = _facing_offset()
	var end_pos: Vector2 = _target_world_pos(target_cell) - _owner.position
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
		_finish()
	)


# --- Creature attack dispatcher -----------------------------------

## Entry point for creature (Monster/NPC/Villager) attacks. Maps the
## creature's attack_style string to the appropriate VFX.
func play_creature_attack(target_cell: Vector2i, facing: Vector2,
		attack_style: StringName, element: int = 0) -> void:
	if _is_playing:
		return
	_last_facing = facing if facing != Vector2.ZERO else Vector2(1, 0)
	match attack_style:
		&"swing", &"thrust", &"slam":
			_do_lunge()
		&"projectile":
			play_ranged(target_cell, 0.2, element, _last_facing)
		_:
			pass  # "none" or unknown — no VFX


# --- Melee swing ---------------------------------------------------

func play_melee_swing(target_cell: Vector2i, facing: Vector2 = Vector2(1, 0),
		_weapon_id: StringName = &"sword") -> void:
	if _is_playing:
		return
	_is_playing = true
	_last_facing = facing if facing != Vector2.ZERO else Vector2(1, 0)
	_weapon_flash_and_rotate(-45.0, 45.0, 0.15)


# --- Mine swing ----------------------------------------------------

func play_mine_swing(target_cell: Vector2i, kind: StringName = &"",
		facing: Vector2 = Vector2(1, 0),
		_tool_id: StringName = &"pickaxe") -> void:
	if _is_playing:
		return
	_is_playing = true
	_last_facing = facing if facing != Vector2.ZERO else Vector2(1, 0)
	_weapon_flash_and_rotate(-90.0, 20.0, 0.2)


# --- Gather rustle -------------------------------------------------

func play_gather(target_cell: Vector2i, facing: Vector2 = Vector2(1, 0)) -> void:
	if _is_playing:
		return
	_is_playing = true
	_last_facing = facing if facing != Vector2.ZERO else Vector2(1, 0)

	_shake_tile(target_cell)


func _shake_tile(target_cell: Vector2i) -> void:
	if _world == null:
		_finish()
		return
	var deco_layer: TileMapLayer = _world.decoration
	var source_id: int = deco_layer.get_cell_source_id(target_cell)
	if source_id < 0:
		_finish()
		return
	var atlas_coords: Vector2i = deco_layer.get_cell_atlas_coords(target_cell)
	var alt_id: int = deco_layer.get_cell_alternative_tile(target_cell)
	var ts: TileSet = deco_layer.tile_set
	var src: TileSetAtlasSource = ts.get_source(source_id) as TileSetAtlasSource
	if src == null:
		_finish()
		return

	# Check for foliage on the Canopy layer one cell above (tall decorations).
	var canopy_layer: TileMapLayer = _world.canopy
	var canopy_cell: Vector2i = target_cell + Vector2i(0, -1)
	var canopy_src_id: int = canopy_layer.get_cell_source_id(canopy_cell) if canopy_layer != null else -1
	var canopy_atlas: Vector2i = Vector2i(-1, -1)
	var canopy_alt: int = 0
	var tmp_canopy: Sprite2D = null
	if canopy_src_id >= 0:
		canopy_atlas = canopy_layer.get_cell_atlas_coords(canopy_cell)
		canopy_alt = canopy_layer.get_cell_alternative_tile(canopy_cell)

	# Create temp Sprite2D for the trunk.
	var tile_pos: Vector2 = _target_world_pos(target_cell)
	var tmp := Sprite2D.new()
	tmp.texture = src.texture
	tmp.region_enabled = true
	tmp.region_rect = src.get_tile_texture_region(atlas_coords)
	tmp.position = tile_pos
	tmp.centered = true
	deco_layer.set_cell(target_cell, -1)
	_world.entities.add_child(tmp)

	# Create temp Sprite2D for the foliage if there is one.
	if canopy_src_id >= 0 and canopy_layer != null:
		var foliage_pos: Vector2 = _target_world_pos(canopy_cell)
		tmp_canopy = Sprite2D.new()
		var csrc: TileSetAtlasSource = ts.get_source(canopy_src_id) as TileSetAtlasSource
		if csrc != null:
			tmp_canopy.texture = csrc.texture
			tmp_canopy.region_enabled = true
			tmp_canopy.region_rect = csrc.get_tile_texture_region(canopy_atlas)
		tmp_canopy.position = foliage_pos
		tmp_canopy.centered = true
		tmp_canopy.z_index = 1
		canopy_layer.set_cell(canopy_cell, -1)
		_world.entities.add_child(tmp_canopy)

	# Oscillate both sprites ±2px for 3 cycles over 0.3s.
	var tw := create_tween()
	var base_x: float = tile_pos.x
	for i in 3:
		tw.tween_property(tmp, "position:x", base_x + 2.0, 0.05)
		tw.tween_property(tmp, "position:x", base_x - 2.0, 0.05)
	tw.tween_property(tmp, "position:x", base_x, 0.05)
	# Mirror the same oscillation on the foliage (parallel tween).
	if tmp_canopy != null:
		var tw2 := create_tween()
		var base_cx: float = _target_world_pos(canopy_cell).x
		for i in 3:
			tw2.tween_property(tmp_canopy, "position:x", base_cx + 2.0, 0.05)
			tw2.tween_property(tmp_canopy, "position:x", base_cx - 2.0, 0.05)
		tw2.tween_property(tmp_canopy, "position:x", base_cx, 0.05)
	tw.tween_callback(func():
		deco_layer.set_cell(target_cell, source_id, atlas_coords, alt_id)
		if tmp_canopy != null and canopy_layer != null and canopy_src_id >= 0:
			canopy_layer.set_cell(canopy_cell, canopy_src_id, canopy_atlas, canopy_alt)
			tmp_canopy.queue_free()
		tmp.queue_free()
		_finish()
	)


# --- Ranged shot ---------------------------------------------------

func play_ranged(target_cell: Vector2i, duration: float = 0.15,
		element: int = 0, facing: Vector2 = Vector2(1, 0)) -> void:
	if _is_playing:
		return
	_is_playing = true
	_last_facing = facing if facing != Vector2.ZERO else Vector2(1, 0)

	var start_pos: Vector2 = _facing_offset()
	var end_pos: Vector2 = _target_world_pos(target_cell) - _owner.position

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
		_finish()
	)

	# Bow pull-back effect on persistent weapon.
	_bow_pullback()


# --- Unarmed lunge -------------------------------------------------

## Quick body lunge toward the target for unarmed attacks.
func play_unarmed_lunge(target_cell: Vector2i, facing: Vector2 = Vector2(1, 0)) -> void:
	if _is_playing:
		return
	_last_facing = facing if facing != Vector2.ZERO else Vector2(1, 0)
	_do_lunge()


# --- Shared helpers ------------------------------------------------

## Flash the persistent weapon sprite white + scale up, with a rotation arc.
func _weapon_flash_and_rotate(from_deg: float, to_deg: float, duration: float) -> void:
	if _weapon_sprite == null or not _weapon_sprite.visible:
		_finish()
		return
	var base_scale: Vector2 = _weapon_sprite.scale
	_weapon_sprite.rotation_degrees = from_deg
	var tw := create_tween()
	tw.set_parallel(true)
	# Phase 1 (t=0): flash white + scale up + rotate arc.
	tw.tween_property(_weapon_sprite, "modulate", Color(3, 3, 3, 1), 0.05)
	tw.tween_property(_weapon_sprite, "scale", base_scale * _FLASH_SCALE, 0.05)
	tw.tween_property(_weapon_sprite, "rotation_degrees", to_deg, duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Phase 2 (t=duration): restore — delayed so they start after the longest phase-1 step.
	tw.tween_property(_weapon_sprite, "modulate", Color(1, 1, 1, 1), 0.08).set_delay(duration)
	tw.tween_property(_weapon_sprite, "scale", base_scale, 0.08).set_delay(duration)
	tw.tween_property(_weapon_sprite, "rotation_degrees", 0.0, 0.06).set_delay(duration)
	tw.tween_callback(_finish).set_delay(duration + 0.08)


## Flash the persistent weapon sprite white + thrust forward, then retract.
func _weapon_flash_and_thrust(duration: float) -> void:
	if _weapon_sprite == null or not _weapon_sprite.visible:
		_finish()
		return
	var base_scale: Vector2 = _weapon_sprite.scale
	var base_pos: Vector2 = _weapon_sprite.position
	var push: Vector2 = _last_facing * _LUNGE_PX
	var half: float = duration * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	# Phase 1 (t=0): flash white + scale up + thrust forward.
	tw.tween_property(_weapon_sprite, "modulate", Color(3, 3, 3, 1), 0.05)
	tw.tween_property(_weapon_sprite, "scale", base_scale * _FLASH_SCALE, 0.05)
	tw.tween_property(_weapon_sprite, "position", base_pos + push, half)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Phase 2 (t=half): restore — delayed so they start after the thrust completes.
	tw.tween_property(_weapon_sprite, "modulate", Color(1, 1, 1, 1), 0.08).set_delay(half)
	tw.tween_property(_weapon_sprite, "scale", base_scale, 0.08).set_delay(half)
	tw.tween_property(_weapon_sprite, "position", base_pos, half)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(half)
	tw.tween_callback(_finish).set_delay(half + 0.08)


## Lunge the visual root toward the facing direction and snap back.
func _do_lunge() -> void:
	_is_playing = true
	if _visual_root == null:
		_finish()
		return
	var push: Vector2 = _last_facing * _LUNGE_PX
	var tw := create_tween()
	tw.tween_property(_visual_root, "position", push, 0.06)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_visual_root, "position", Vector2.ZERO, 0.06)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_finish)


func _bow_pullback() -> void:
	if _weapon_sprite == null or not _weapon_sprite.visible:
		return
	var tw := create_tween()
	tw.tween_property(_weapon_sprite, "scale:x", 0.8, 0.08)
	tw.tween_property(_weapon_sprite, "scale:x", 1.0, 0.08)


func _finish() -> void:
	_is_playing = false
