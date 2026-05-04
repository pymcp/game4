## StatusBadges
##
## Draws small coloured squares for each active status effect on a player.
## Uses procedural [method CanvasItem._draw] — no textures required.
## Position it next to the HeartDisplay in the per-player overlay.
extends Control
class_name StatusBadges

const _BADGE_SIZE: float = 10.0
const _BADGE_GAP: float = 3.0

## element int → badge color (mirrors PlayerHUD._ELEMENT_COLORS)
const _ELEMENT_COLORS: Dictionary = {
	1: Color(1.0, 0.4, 0.2),   # FIRE
	2: Color(0.3, 0.7, 1.0),   # ICE
	3: Color(1.0, 0.9, 0.2),   # LIGHTNING
	4: Color(0.3, 0.9, 0.3),   # POISON
}
const _DEFAULT_COLOR: Color = Color(0.7, 0.7, 0.7)

var _effects: Array[Dictionary] = []


## Call with the player's [code]active_effects[/code] array each frame.
func set_effects(effects: Array[Dictionary]) -> void:
	_effects = effects
	var w: float = _effects.size() * (_BADGE_SIZE + _BADGE_GAP)
	custom_minimum_size = Vector2(w, _BADGE_SIZE)
	queue_redraw()


func _draw() -> void:
	var x: float = 0.0
	for entry: Dictionary in _effects:
		var eid: StringName = entry.get("effect_id", &"")
		var eff: StatusEffect = StatusEffectRegistry.get_effect(eid) if eid != &"" else null
		var element: int = eff.element if eff != null else 0
		var col: Color = _ELEMENT_COLORS.get(element, _DEFAULT_COLOR)
		draw_rect(Rect2(x, 0.0, _BADGE_SIZE, _BADGE_SIZE), col)
		x += _BADGE_SIZE + _BADGE_GAP
