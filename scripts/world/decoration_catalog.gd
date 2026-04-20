## DecorationCatalog
##
## Maps decoration kinds (`StringName`) → list of texture paths. Lets
## `WorldRoot` (and later procgen) spawn Sprite2D children at iso cells
## without hard-coding asset paths everywhere.
##
## Index choices for `tree` / `rock` are visual best-guesses pending manual
## review of `kenney_raw/2D assets/Isometric Nature/Preview.png`. Adjust the
## index lists below if a sprite looks wrong in-game; no other code changes
## should be needed.
class_name DecorationCatalog
extends RefCounted

const _NATURE: String = "res://assets/tiles/nature/"

## Each kind maps to a list of base names (without `_0.png` rotation suffix).
## We only ever use the `_0` (front-facing) rotation since players don't rotate.
## Indices below were chosen by visually inspecting `kenney_raw/2D assets/
## Isometric Nature/Preview.png`. Most low-index `naturePack_NNN` files in the
## pack are full iso *floor blocks* (a green diamond on a brown pedestal) —
## those would render as raised platforms when scattered. The indices here
## point at the actual props (trees, boulders, plants, mushrooms).
const KINDS: Dictionary = {
	&"tree":   ["naturePack_140", "naturePack_150", "naturePack_160", "naturePack_165"],
	&"bush":   ["naturePack_054", "naturePack_055", "naturePack_056", "naturePack_110"],
	&"rock":   ["naturePack_060", "naturePack_170", "naturePack_171"],
	&"flower": ["naturePack_111", "naturePack_112", "naturePack_113"],
}


static func get_paths(kind: StringName) -> Array[String]:
	if not KINDS.has(kind):
		return [] as Array[String]
	var out: Array[String] = []
	for base in KINDS[kind]:
		out.append("%s%s_0.png" % [_NATURE, base])
	return out


## Returns a random texture for the kind, or `null` if no variants exist or
## none load successfully.
static func random_texture(kind: StringName, rng: RandomNumberGenerator) -> Texture2D:
	var paths: Array[String] = get_paths(kind)
	if paths.is_empty():
		return null
	# Try up to N times in case some files are missing on disk.
	for _i in 4:
		var p: String = paths[rng.randi() % paths.size()]
		var t := load(p) as Texture2D
		if t != null:
			return t
	return null
