## ItemDefinition
##
## Static description of a single item kind. Loaded from `resources/items.json`
## using Type Object inheritance (copy-down delegation). Designer `.tres`
## overrides under `res://resources/items/<id>.tres` still layer on top.
##
## Equipment items use `slot` (else SLOT_NONE for materials/consumables) and
## may carry `power` (damage bonus for weapons, defense bonus for armor).
class_name ItemDefinition
extends Resource

enum Slot { NONE, WEAPON, TOOL, HEAD, BODY, FEET, OFF_HAND }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum AttackType { NONE, MELEE, RANGED }
enum WeaponCategory { NONE, SWORD, AXE, SPEAR, BOW, STAFF, DAGGER }
enum Element { NONE, FIRE, ICE, LIGHTNING, POISON }

const RARITY_COLORS: Dictionary = {
	Rarity.COMMON: Color(1.0, 1.0, 1.0),
	Rarity.UNCOMMON: Color(0.3, 0.9, 0.3),
	Rarity.RARE: Color(0.3, 0.5, 1.0),
	Rarity.EPIC: Color(0.7, 0.3, 0.9),
	Rarity.LEGENDARY: Color(1.0, 0.6, 0.1),
}

# --- Core fields (backward-compat) ---
@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D = null
@export var stack_size: int = 99
@export var slot: Slot = Slot.NONE
@export var power: int = 0
@export var description: String = ""

# --- New equipment fields ---
@export var rarity: Rarity = Rarity.COMMON
@export var hands: int = 1
@export var attack_type: AttackType = AttackType.NONE
@export var attack_speed: float = 0.0
@export var reach: float = 0.0
@export var knockback: float = 0.0
@export var weapon_category: WeaponCategory = WeaponCategory.NONE
@export var tier: String = ""
@export var element: Element = Element.NONE
@export var set_id: String = ""
@export var stat_bonuses: Dictionary = {}
@export var weapon_sprite: Vector2i = Vector2i(-1, -1)
@export var armor_sprite: Vector2i = Vector2i(-1, -1)
@export var armor_tint: Color = Color(1, 1, 1, 1)
@export var shield_sprite: Vector2i = Vector2i(-1, -1)
@export var description_flavor: String = ""

# --- Economy fields ---
@export var buy_price: int = 0
@export var sell_price: int = 0

# --- Consumable fields ---
@export var consumable: bool = false
@export var heal_amount: int = 0
@export var cure_status: StringName = &""

# --- Caravan / crafting fields ---
@export var is_crafting_ingredient: bool = false


func generate_description() -> String:
	var parts: PackedStringArray = []
	if power > 0:
		if slot == Slot.WEAPON or slot == Slot.TOOL:
			parts.append("%d ATK" % power)
		else:
			parts.append("%d DEF" % power)
	if attack_speed > 0:
		var spd_str: String = str(snappedf(attack_speed, 0.01))
		parts.append(spd_str + "s")
	if attack_type != AttackType.NONE:
		parts.append(AttackType.keys()[attack_type].capitalize())
	if element != Element.NONE:
		parts.append(Element.keys()[element].capitalize())

	var bonus_parts: PackedStringArray = []
	for stat_key in stat_bonuses:
		var val: int = int(stat_bonuses[stat_key])
		if val != 0:
			var sign_str: String = "+" if val > 0 else ""
			bonus_parts.append("%s%d %s" % [sign_str, val, str(stat_key).to_upper()])
	if bonus_parts.size() > 0:
		parts.append(", ".join(bonus_parts))

	if set_id != "":
		parts.append(set_id.capitalize() + " Set")

	if consumable:
		if heal_amount > 0:
			parts.append("Heal %d" % heal_amount)
		if cure_status != &"":
			parts.append("Cure %s" % str(cure_status).capitalize())

	var line: String = " · ".join(parts) if parts.size() > 0 else ""
	if description_flavor != "":
		if line != "":
			line += "\n" + description_flavor
		else:
			line = description_flavor
	return line
