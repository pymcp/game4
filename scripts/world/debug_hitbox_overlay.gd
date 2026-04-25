## DebugHitboxOverlay
##
## Debug overlay (toggled by F10) that draws translucent circles showing
## each entity's detection and attack ranges, plus a small solid square
## at the entity's collision point (all hit-detection is distance-from-point).
##
## Colour key:
##   White square — entity collision point (hitbox)
##   Red ring     — player melee reach
##   Blue ring    — player ranged reach
##   Orange ring  — monster/NPC attack range
##   Yellow ring  — monster/NPC sight radius
##   Dark-yellow  — NPC leash radius
##   Green ring   — villager threat / melee range
##   Cyan ring    — pet detect / bark range
extends Node2D
class_name DebugHitboxOverlay

const _TILE_PX: float = 16.0
const _CIRCLE_SEGMENTS: int = 32

var _world: WorldRoot = null


func _ready() -> void:
	z_index = 4096
	_world = get_parent() as WorldRoot


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _world == null or _world.entities == null:
		return
	# Draw mineables first so entity overlays render on top.
	_draw_mineables()
	for child in _world.entities.get_children():
		if child is PlayerController:
			_draw_player(child as PlayerController)
		elif child is Monster:
			_draw_monster(child as Monster)
		elif child is NPC:
			_draw_npc(child as NPC)
		elif child is Villager:
			_draw_villager(child as Villager)
		elif child is Pet:
			_draw_pet(child as Pet)


func _draw_player(p: PlayerController) -> void:
	if p.health <= 0 or not p.visible:
		return
	# Facing attack cone + would-hit highlights (drawn below hitbox circle).
	_draw_attack_cone(p)
	# Hitbox circle.
	_draw_hitbox_circle(p.position, p.hitbox_radius, Color(1, 1, 1, 0.5))
	# Melee reach ring (kept as red ring per design).
	var weapon_id: StringName = p.equipment.get_equipped(ItemDefinition.Slot.WEAPON)
	var def: ItemDefinition = ItemRegistry.get_item(weapon_id) if weapon_id != &"" else null
	var melee_reach: float = def.reach if def != null and def.reach > 0 else p._MELEE_REACH_PX
	_draw_ring(p.position, melee_reach, Color(1, 0.2, 0.2, 0.35))
	# Ranged reach (always shown — represents bow / auto-attack range).
	_draw_ring(p.position, p._RANGED_REACH_PX, Color(0.3, 0.5, 1.0, 0.15))
	# Label.
	_draw_label(p.position + Vector2(0, -10), "P%d" % p.player_id,
		Color(1, 0.3, 0.3))


func _draw_monster(m: Monster) -> void:
	if m.health <= 0:
		return
	_draw_hitbox_circle(m.position, m.hitbox_radius, Color(1, 0.6, 0.2, 0.5))
	var attack_px: float = m._attack_range_tiles * _TILE_PX
	_draw_ring(m.position, attack_px, Color(1, 0.5, 0.1, 0.35))
	var sight_px: float = Monster.SIGHT_RADIUS_TILES * _TILE_PX
	_draw_ring(m.position, sight_px, Color(1, 1, 0.2, 0.15))
	_draw_label(m.position + Vector2(0, -10), "M", Color(1, 0.6, 0.2))


func _draw_npc(n: NPC) -> void:
	if not n.hostile or n.health <= 0:
		return
	_draw_hitbox_circle(n.position, n.hitbox_radius, Color(1, 0.5, 0.1, 0.5))
	var attack_px: float = n.attack_range_tiles * _TILE_PX
	_draw_ring(n.position, attack_px, Color(1, 0.5, 0.1, 0.35))
	var sight_px: float = n.sight_radius_tiles * _TILE_PX
	_draw_ring(n.position, sight_px, Color(1, 1, 0.2, 0.15))
	# Leash radius — how far NPC chases before returning home.
	var leash_px: float = n.leash_radius_tiles * _TILE_PX
	_draw_ring(n.position, leash_px, Color(0.8, 0.7, 0.1, 0.1))
	_draw_label(n.position + Vector2(0, -10), "N", Color(1, 0.6, 0.2))


func _draw_villager(v: Villager) -> void:
	_draw_hitbox_circle(v.position, v.hitbox_radius, Color(0.3, 0.9, 0.4, 0.5))
	var threat_px: float = 8.0 * _TILE_PX  # _THREAT_FORGET_TILES
	_draw_ring(v.position, threat_px, Color(0.2, 0.9, 0.3, 0.15))
	var melee_px: float = _TILE_PX * 1.5
	_draw_ring(v.position, melee_px, Color(0.2, 0.9, 0.3, 0.35))
	_draw_label(v.position + Vector2(0, -10), "V", Color(0.3, 0.9, 0.4))


func _draw_pet(p: Pet) -> void:
	_draw_hitbox_circle(p.position, p.hitbox_radius, Color(0.3, 0.9, 1, 0.5))
	# Dogs use bark range (5 tiles), cats use attack detect range (4 tiles).
	var detect_px: float
	if p.species == Pet.PET_SPECIES_DOG:
		detect_px = Pet.BARK_RANGE_TILES * _TILE_PX
	else:
		detect_px = PetState.ATTACK_DETECT_TILES * _TILE_PX
	_draw_ring(p.position, detect_px, Color(0.2, 0.8, 1, 0.25))
	_draw_label(p.position + Vector2(0, -10), "Pet", Color(0.3, 0.9, 1))


# --- Mineables & attack cone ---------------------------------------

## Draw teal hitbox circles on every mineable tile. The tile that the
## player WOULD hit if they attacked right now is highlighted bright.
func _draw_mineables() -> void:
	if _world == null or _world._mineable == null:
		return
	for cell: Vector2i in _world._mineable.keys():
		var center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * _TILE_PX
		_draw_ring(center, WorldConst.MINEABLE_HITBOX_RADIUS, Color(0.2, 0.9, 0.8, 0.35))


## Draw a semi-transparent wedge in the player's facing direction showing
## the exact area that would be checked on the next attack/mine press.
## The winning target (nearest mineable or entity in cone) is highlighted.
func _draw_attack_cone(p: PlayerController) -> void:
	var weapon_id: StringName = p.equipment.get_equipped(ItemDefinition.Slot.WEAPON)
	var wdef: ItemDefinition = ItemRegistry.get_item(weapon_id) if weapon_id != &"" else null
	var reach: float = wdef.reach if wdef != null and wdef.reach > 0 else p._MELEE_REACH_PX
	var dir := Vector2(p._facing_dir).normalized()
	# Draw filled cone wedge (~60° half-angle = acos(0.5) ≈ 60°).
	var cone_color := Color(1.0, 0.95, 0.3, 0.12)
	var pts := PackedVector2Array()
	pts.append(p.position)
	var half_angle: float = deg_to_rad(60.0)
	var base_angle: float = dir.angle()
	var steps: int = 12
	for i in range(steps + 1):
		var a: float = base_angle - half_angle + (2.0 * half_angle * float(i) / float(steps))
		pts.append(p.position + Vector2(cos(a), sin(a)) * reach)
	draw_colored_polygon(pts, cone_color)
	# Bright outline arc.
	for i in range(1, pts.size()):
		draw_line(pts[i - 1], pts[i], Color(1.0, 0.95, 0.3, 0.45), 0.5)

	# Highlight the would-be mineable target (bright teal filled circle).
	if _world != null and _world._mineable != null:
		var mine_reach: float = reach + WorldConst.MINEABLE_HITBOX_RADIUS
		var best_cell: Vector2i = Vector2i(-1, -1)
		var best_d2: float = mine_reach * mine_reach + 1.0
		for cell: Vector2i in _world._mineable.keys():
			var tile_center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * _TILE_PX
			var to: Vector2 = tile_center - p.position
			if to.length_squared() > best_d2:
				continue
			if to.normalized().dot(dir) < 0.5:
				continue
			best_d2 = to.length_squared()
			best_cell = cell
		if best_cell != Vector2i(-1, -1):
			var tc: Vector2 = (Vector2(best_cell) + Vector2(0.5, 0.5)) * _TILE_PX
			_draw_hitbox_circle(tc, WorldConst.MINEABLE_HITBOX_RADIUS, Color(0.2, 1.0, 0.85, 0.55))
			_draw_label(tc + Vector2(0, -10), "hit", Color(0.2, 1.0, 0.85))

	# Auto-mine: show full circle instead of cone when active.
	if p.auto_mine:
		var am_reach: float = reach + WorldConst.MINEABLE_HITBOX_RADIUS
		_draw_ring(p.position, am_reach, Color(0.2, 0.9, 0.8, 0.3))


# --- Helpers -------------------------------------------------------

func _draw_hitbox_circle(center: Vector2, radius: float, color: Color) -> void:
	## Filled circle showing the entity's hitbox.
	var pts := PackedVector2Array()
	for i in _CIRCLE_SEGMENTS:
		var angle: float = TAU * float(i) / float(_CIRCLE_SEGMENTS)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(pts, color)
	# Bright outline.
	var outline := Color(color.r, color.g, color.b, min(color.a * 3, 1.0))
	for i in _CIRCLE_SEGMENTS:
		draw_line(pts[i], pts[(i + 1) % _CIRCLE_SEGMENTS], outline, 0.5)


func _draw_ring(center: Vector2, radius: float, color: Color) -> void:
	# Filled translucent circle.
	var pts := PackedVector2Array()
	for i in _CIRCLE_SEGMENTS:
		var angle: float = TAU * float(i) / float(_CIRCLE_SEGMENTS)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(pts, color)
	# Solid outline.
	var outline_color := Color(color.r, color.g, color.b, min(color.a * 3, 1.0))
	for i in _CIRCLE_SEGMENTS:
		var a: int = i
		var b: int = (i + 1) % _CIRCLE_SEGMENTS
		draw_line(pts[a], pts[b], outline_color, 0.5)


func _draw_label(pos: Vector2, text: String, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 6, color)
