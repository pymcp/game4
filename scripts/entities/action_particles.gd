## ActionParticles
##
## Static helper that spawns short-lived [CPUParticles2D] with a themed
## texture chosen by action type and target kind. Replaces the old
## untextured square-particle bursts in [WorldRoot].
extends RefCounted
class_name ActionParticles

## Particle texture paths grouped by theme.
const _SLASH_TEXTURES: Array[String] = [
	"res://assets/particles/pack/slash_01.png",
	"res://assets/particles/pack/slash_02.png",
	"res://assets/particles/pack/slash_03.png",
	"res://assets/particles/pack/slash_04.png",
]
const _SPARK_TEXTURES: Array[String] = [
	"res://assets/particles/pack/spark_01.png",
	"res://assets/particles/pack/spark_02.png",
	"res://assets/particles/pack/spark_03.png",
]
const _DIRT_TEXTURES: Array[String] = [
	"res://assets/particles/pack/dirt_01.png",
	"res://assets/particles/pack/dirt_02.png",
	"res://assets/particles/pack/dirt_03.png",
]
const _SMOKE_TEXTURES: Array[String] = [
	"res://assets/particles/pack/smoke_01.png",
	"res://assets/particles/pack/smoke_04.png",
]
const _STAR_TEXTURES: Array[String] = [
	"res://assets/particles/pack/star_04.png",
	"res://assets/particles/pack/star_06.png",
]

enum Action { MELEE, MINE, GATHER, RANGED, BREAK }

## Rock / ore kinds that produce spark particles on mining hits.
const _ROCKY_KINDS: Dictionary = {
	&"rock": true, &"iron_vein": true,
	&"copper_vein": true, &"gold_vein": true,
}


## Spawn a themed impact burst at [param world_pos] as a child of
## [param parent]. The burst self-frees after its lifetime.
static func spawn_impact(parent: Node, world_pos: Vector2, action: int,
		kind: StringName = &"") -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = world_pos
	p.one_shot = true
	p.emitting = true

	# Choose texture + params by action.
	match action:
		Action.MELEE:
			_configure_slash(p)
		Action.MINE:
			if _ROCKY_KINDS.has(kind):
				_configure_spark(p)
			else:
				_configure_dirt(p)
		Action.GATHER:
			_configure_gather(p)
		Action.RANGED:
			_configure_star(p)
		Action.BREAK:
			_configure_break(p, kind)
		_:
			_configure_dirt(p)

	parent.add_child(p)

	# Auto-free after lifetime + margin.
	var tree: SceneTree = parent.get_tree()
	if tree != null:
		tree.create_timer(p.lifetime + 0.3).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free()
		)
	return p


# --- Configuration helpers ----------------------------------------

static func _configure_slash(p: CPUParticles2D) -> void:
	p.texture = load(_SLASH_TEXTURES[randi() % _SLASH_TEXTURES.size()])
	p.amount = 3
	p.lifetime = 0.2
	p.spread = 45.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 30.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.25
	p.color = Color(1.0, 1.0, 1.0, 0.9)


static func _configure_spark(p: CPUParticles2D) -> void:
	p.texture = load(_SPARK_TEXTURES[randi() % _SPARK_TEXTURES.size()])
	p.amount = 6
	p.lifetime = 0.25
	p.spread = 120.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, 60)
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.15
	p.color = Color(1.0, 0.9, 0.5, 1.0)  # warm yellow


static func _configure_dirt(p: CPUParticles2D) -> void:
	p.texture = load(_DIRT_TEXTURES[randi() % _DIRT_TEXTURES.size()])
	p.amount = 5
	p.lifetime = 0.3
	p.spread = 150.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 40.0
	p.gravity = Vector2(0, 80)
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.2
	p.color = Color(0.7, 0.55, 0.35, 0.9)  # earthy brown


static func _configure_gather(p: CPUParticles2D) -> void:
	p.texture = load(_SMOKE_TEXTURES[randi() % _SMOKE_TEXTURES.size()])
	p.amount = 4
	p.lifetime = 0.35
	p.spread = 180.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector2(0, -10)  # slight upward drift
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.2
	p.color = Color(0.6, 0.75, 0.45, 0.7)  # greenish dust for plants


static func _configure_star(p: CPUParticles2D) -> void:
	p.texture = load(_STAR_TEXTURES[randi() % _STAR_TEXTURES.size()])
	p.amount = 4
	p.lifetime = 0.2
	p.spread = 90.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 35.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.18
	p.color = Color(1.0, 1.0, 0.8, 1.0)


static func _configure_break(p: CPUParticles2D, kind: StringName) -> void:
	if _ROCKY_KINDS.has(kind):
		p.texture = load(_SPARK_TEXTURES[randi() % _SPARK_TEXTURES.size()])
		p.color = Color(1.0, 0.85, 0.4, 1.0)
	else:
		p.texture = load(_DIRT_TEXTURES[randi() % _DIRT_TEXTURES.size()])
		p.color = Color(0.6, 0.5, 0.3, 0.9)
	p.amount = 12
	p.lifetime = 0.4
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0, 100)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.25
