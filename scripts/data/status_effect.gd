## StatusEffect
##
## Data object describing a status effect (burn, freeze, etc.).
## Loaded from resources/status_effects.json via StatusEffectRegistry.
class_name StatusEffect
extends RefCounted

var id: StringName = &""
var display_name: String = ""
var element: int = 0  # ItemDefinition.Element value
var duration_sec: float = 0.0
var tick_interval: float = 0.0
var damage_per_tick: int = 0
var speed_multiplier: float = 1.0
var stun: bool = false
