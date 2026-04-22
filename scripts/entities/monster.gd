## Monster
##
## Training-dummy creature. One per F8 press, spawned a few tiles from
## a player in their current [WorldRoot] instance. Chases the nearest
## [PlayerController] in the same instance when within
## [SIGHT_RADIUS_TILES], otherwise stands still. Never deals damage —
## walks up to the player and overlaps. Useful as a visible AI target.
##
## Coordinate system mirrors [PlayerController]: positions are native
## pixels, [WorldConst.TILE_PX] per tile. Pathing is naive — step
## directly toward the target and skip the move when the next cell is
## not [WorldRoot.is_walkable].
extends Node2D
class_name Monster

signal died(world_position: Vector2, drops: Array)

const _SLIME_TEX: Texture2D = preload("res://assets/characters/monsters/slime.png")
const SIGHT_RADIUS_TILES: float = 8.0
const _MOVE_SPEED_PX_PER_S: float = 32.0  ## native pixels (pre-zoom)

@export var max_health: int = 3
@export var health: int = 3
@export var drops: Array = []  ## [{id: StringName, count: int}]
@export var resistances: Dictionary = {}  ## Element enum → float multiplier (0.0=immune, 2.0=weak)
@export var monster_kind: StringName = &"slime"  ## Loot table key

var _world: WorldRoot = null
var _sprite: Sprite2D = null


func _ready() -> void:
	_world = WorldRoot.find_from(self)
	_sprite = Sprite2D.new()
	_sprite.texture = _SLIME_TEX
	_sprite.centered = true
	# Tiny Dungeon tiles ship with a heavy 1-px black outline. At the
	# global 4x render zoom that reads as a chunky 4-px border around a
	# small creature. Render the slime at half size so the outline
	# settles to ~2 screen px and the body feels appropriately small.
	_sprite.scale = Vector2(0.75, 0.75)
	add_child(_sprite)
	add_to_group(&"monsters")
	add_to_group(&"scattered_npcs")


## Pure helper: nearest [PlayerController] to [param from] within
## [param max_tiles] among [param candidates]. Returns the player or
## [code]null[/code] when none qualify. Static so AI logic is testable
## without instantiating a scene.
static func nearest_player(from: Vector2, candidates: Array,
		max_tiles: float) -> PlayerController:
	var best: PlayerController = null
	var best_d2: float = INF
	var max_px: float = max_tiles * float(WorldConst.TILE_PX)
	var max_d2: float = max_px * max_px
	for n in candidates:
		var p := n as PlayerController
		if p == null:
			continue
		var d2: float = from.distance_squared_to(p.position)
		if d2 < best_d2 and d2 <= max_d2:
			best_d2 = d2
			best = p
	return best


func _process(delta: float) -> void:
	if _world == null:
		return
	var target: PlayerController = nearest_player(position,
			_world.entities.get_children(), SIGHT_RADIUS_TILES)
	if target == null:
		return
	var to: Vector2 = target.position - position
	var dist: float = to.length()
	if dist <= 1.0:
		return
	var step: float = _MOVE_SPEED_PX_PER_S * delta
	if step > dist:
		step = dist
	var next_pos: Vector2 = position + to / dist * step
	var next_cell := Vector2i(
			int(floor(next_pos.x / float(WorldConst.TILE_PX))),
			int(floor(next_pos.y / float(WorldConst.TILE_PX))))
	if _world.is_walkable(next_cell):
		position = next_pos


func take_hit(damage: int, _attacker: Node = null, element: int = 0) -> void:
	var effective: int = _apply_resistance(damage, element)
	health = max(0, health - effective)
	if health <= 0:
		_die()


func _apply_resistance(damage: int, element: int) -> int:
	if element == 0 or not resistances.has(element):
		return max(1, damage)
	var mult: float = float(resistances[element])
	return max(1, ceili(damage * mult))


func _die() -> void:
	var loot: Array = drops.duplicate()
	# Roll drops from loot table if no explicit drops were set.
	if loot.is_empty():
		loot = LootTableRegistry.roll_drops(monster_kind)
	died.emit(position, loot)
	queue_free()
