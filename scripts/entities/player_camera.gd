## PlayerCamera
##
## Camera2D that smoothly follows a target Node2D each frame. Lives inside its
## owning SubViewport so it controls only that viewport's canvas transform.
extends Camera2D
class_name PlayerCamera

@export var target_path: NodePath
@export var follow_speed: float = 8.0  # higher = snappier

var _target: Node2D = null


func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node2D
	make_current()


func set_target(node: Node2D) -> void:
	_target = node


func _process(delta: float) -> void:
	if _target == null:
		return
	var t: float = clamp(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(_target.global_position, t)
