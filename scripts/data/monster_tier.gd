## MonsterTier
##
## Pure data helper for the 5-tier monster variant system.
## Tiers modify HP, damage, scale, XP, and visual tint at spawn time.
## No scene dependencies — fully unit-testable.
class_name MonsterTier extends RefCounted

enum Tier { NORMAL, TOUGH, HARDENED, VETERAN, ELITE }

const TIER_NAMES: Array[String] = ["", "Tough", "Hardened", "Veteran", "Elite"]

const HP_MULT: Array[float] = [1.0, 1.25, 1.75, 2.5, 3.5]
const DMG_MULT: Array[float] = [1.0, 1.1, 1.3, 1.6, 2.0]
const SCALE_MULT: Array[float] = [1.0, 1.05, 1.1, 1.15, 1.25]
const XP_MULT: Array[float] = [1.0, 1.25, 1.75, 2.5, 3.5]

## Per-tier tint multiplier applied on top of the creature's base tint.
## Higher tiers shift warmer (more red/yellow) and brighter.
const TINT_FACTORS: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0),      # Normal — no change
	Color(1.1, 1.05, 0.95, 1.0),    # Tough — slightly warm
	Color(1.2, 1.05, 0.85, 1.0),    # Hardened — warm shift
	Color(1.35, 1.1, 0.75, 1.0),    # Veteran — saturated warm
	Color(1.6, 1.2, 0.7, 1.0),      # Elite — intense glow
]

const ELITE_PROMOTION_CHANCE: float = 0.05

## Floor-tier distribution weights.  Each entry is an Array of ints
## whose length equals the number of tiers that can spawn on that band.
## Index = tier, value = weight.
const _FLOOR_WEIGHTS: Array = [
	[100],                # floors 1-4: Normal only
	[70, 30],             # floors 5-9
	[50, 30, 20],         # floors 10-14
	[40, 25, 20, 15],     # floors 15-19
	[30, 25, 20, 15, 10], # floors 20+
]


## Returns a tier index [0..4] based on floor depth plus random promotion.
static func roll_tier(floor_num: int, rng: RandomNumberGenerator) -> int:
	var band: int = _floor_band(floor_num)
	var weights: Array = _FLOOR_WEIGHTS[band]
	var tier: int = _weighted_pick(rng, weights)
	# 5% chance to promote +1 tier.
	if rng.randf() < ELITE_PROMOTION_CHANCE:
		tier = mini(tier + 1, Tier.ELITE)
	return tier


## Display name with tier prefix.  Normal tier returns the base name as-is.
static func display_name(base_name: String, tier: int) -> String:
	if tier <= 0 or tier >= TIER_NAMES.size():
		return base_name
	return TIER_NAMES[tier] + " " + base_name


## Apply tier color shift on top of a creature's base tint.
static func apply_color(base_tint: Color, tier: int) -> Color:
	if tier <= 0 or tier >= TINT_FACTORS.size():
		return base_tint
	var factor: Color = TINT_FACTORS[tier]
	return Color(
		base_tint.r * factor.r,
		base_tint.g * factor.g,
		base_tint.b * factor.b,
		base_tint.a,
	)


## Map floor number to distribution band index.
static func _floor_band(floor_num: int) -> int:
	if floor_num < 5:
		return 0
	elif floor_num < 10:
		return 1
	elif floor_num < 15:
		return 2
	elif floor_num < 20:
		return 3
	else:
		return 4


## Weighted random pick from an Array of int weights; returns the index.
static func _weighted_pick(rng: RandomNumberGenerator, weights: Array) -> int:
	var total: int = 0
	for w: int in weights:
		total += w
	var roll: int = rng.randi_range(0, total - 1)
	var accum: int = 0
	for i in weights.size():
		accum += int(weights[i])
		if roll < accum:
			return i
	return weights.size() - 1
