class_name LevelingConfig extends RefCounted

## XP required to level up from [param level] to [param level]+1.
## At level >= 20 returns a sentinel value (capped progression).
static func xp_to_next(level: int) -> int:
	if level >= 20:
		return 999999
	return level * 100


## Passive ability name granted at milestone levels.
## Returns an empty StringName for non-milestone levels.
static func milestone_passive(level: int) -> StringName:
	match level:
		5:  return &"hardy"
		10: return &"scavenger"
		15: return &"iron_skin"
		20: return &"hero"
		_:  return &""
