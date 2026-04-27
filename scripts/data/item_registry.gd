## ItemRegistry
##
## Data-driven registry of `ItemDefinition`s loaded from
## `resources/items.json`. Supports Type Object inheritance — child items
## specify a `"parent"` field and only override the fields they change.
## Designer `.tres` overrides in `res://resources/items/` still layer on top.
##
## Follows the same pattern as MineableRegistry: lazy-load, cache, save.
class_name ItemRegistry
extends RefCounted

const _JSON_PATH: String = "res://resources/items.json"
const _OVERRIDE_DIR: String = "res://resources/items/"
const _ICON_BASE: String = "res://assets/icons/generic_items/genericItem_color_%03d.png"

## Cached ItemDefinition objects keyed by StringName id.
static var _cache: Dictionary = {}
## Raw JSON data as loaded (pre-inheritance).
static var _raw: Dictionary = {}
## Resolved JSON data (post-inheritance, for editor use).
static var _resolved: Dictionary = {}
static var _loaded: bool = false

# ─── Slot / enum string helpers ───────────────────────────────────────

const _SLOT_MAP: Dictionary = {
	"none": ItemDefinition.Slot.NONE,
	"weapon": ItemDefinition.Slot.WEAPON,
	"tool": ItemDefinition.Slot.TOOL,
	"head": ItemDefinition.Slot.HEAD,
	"body": ItemDefinition.Slot.BODY,
	"feet": ItemDefinition.Slot.FEET,
	"off_hand": ItemDefinition.Slot.OFF_HAND,
}

const _RARITY_MAP: Dictionary = {
	"common": ItemDefinition.Rarity.COMMON,
	"uncommon": ItemDefinition.Rarity.UNCOMMON,
	"rare": ItemDefinition.Rarity.RARE,
	"epic": ItemDefinition.Rarity.EPIC,
	"legendary": ItemDefinition.Rarity.LEGENDARY,
}

const _ATTACK_TYPE_MAP: Dictionary = {
	"none": ItemDefinition.AttackType.NONE,
	"melee": ItemDefinition.AttackType.MELEE,
	"ranged": ItemDefinition.AttackType.RANGED,
}

const _WEAPON_CAT_MAP: Dictionary = {
	"none": ItemDefinition.WeaponCategory.NONE,
	"sword": ItemDefinition.WeaponCategory.SWORD,
	"axe": ItemDefinition.WeaponCategory.AXE,
	"spear": ItemDefinition.WeaponCategory.SPEAR,
	"bow": ItemDefinition.WeaponCategory.BOW,
	"staff": ItemDefinition.WeaponCategory.STAFF,
	"dagger": ItemDefinition.WeaponCategory.DAGGER,
}

const _ELEMENT_MAP: Dictionary = {
	"none": ItemDefinition.Element.NONE,
	"fire": ItemDefinition.Element.FIRE,
	"ice": ItemDefinition.Element.ICE,
	"lightning": ItemDefinition.Element.LIGHTNING,
	"poison": ItemDefinition.Element.POISON,
}


# ─── Public API (backward-compat) ────────────────────────────────────

static func get_item(id: StringName) -> ItemDefinition:
	_ensure_loaded()
	return _cache.get(id, null)


static func has_item(id: StringName) -> bool:
	_ensure_loaded()
	return _cache.has(id)


static func all_ids() -> Array:
	_ensure_loaded()
	return _cache.keys()


static func reset() -> void:
	_cache.clear()
	_raw.clear()
	_resolved.clear()
	_loaded = false
	HiresIconRegistry.reset()


# ─── Editor API ───────────────────────────────────────────────────────

## Return the raw (pre-inheritance) JSON data for editor display.
static func get_raw_data() -> Dictionary:
	_ensure_loaded()
	return _raw


## Return the resolved (post-inheritance) data for a single item.
static func get_resolved_entry(id: String) -> Dictionary:
	_ensure_loaded()
	return _resolved.get(id, {})


## Replace the in-memory data and write to disk, then rebuild cache.
static func save_data(data: Dictionary) -> void:
	_raw = data.duplicate(true)
	var text: String = JSON.stringify(_raw, "\t")
	var f := FileAccess.open(_JSON_PATH, FileAccess.WRITE)
	if f == null:
		push_error("ItemRegistry: cannot write %s" % _JSON_PATH)
		return
	f.store_string(text)
	f.close()
	# Rebuild resolved + cache from new raw data.
	_resolved = _resolve_inheritance(_raw)
	_cache.clear()
	_build_cache()


## Force reload from disk.
static func reload() -> void:
	reset()
	_ensure_loaded()


# ─── Loading ──────────────────────────────────────────────────────────

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_raw = _load_json()
	_resolved = _resolve_inheritance(_raw)
	_build_cache()


static func _load_json() -> Dictionary:
	if not FileAccess.file_exists(_JSON_PATH):
		return {}
	var f := FileAccess.open(_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("ItemRegistry: cannot open %s" % _JSON_PATH)
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("ItemRegistry: failed to parse %s" % _JSON_PATH)
		return {}
	return parsed as Dictionary


# ─── Inheritance resolution ───────────────────────────────────────────

## Copy-down delegation: for each item with a "parent" field, merge parent
## fields into child (child overrides win). Processes in topological order.
static func _resolve_inheritance(raw: Dictionary) -> Dictionary:
	var resolved: Dictionary = {}
	var visiting: Dictionary = {}  # cycle detection

	for id in raw:
		_resolve_one(id, raw, resolved, visiting)
	return resolved


static func _resolve_one(id: String, raw: Dictionary, resolved: Dictionary,
		visiting: Dictionary) -> Dictionary:
	if resolved.has(id):
		return resolved[id]
	if visiting.has(id):
		push_warning("ItemRegistry: circular parent for '%s'" % id)
		resolved[id] = raw[id].duplicate(true)
		return resolved[id]

	visiting[id] = true
	var entry: Dictionary = raw.get(id, {}).duplicate(true)
	var parent_id: String = entry.get("parent", "")

	if parent_id != "" and raw.has(parent_id):
		var parent_data: Dictionary = _resolve_one(parent_id, raw, resolved, visiting)
		# Merge: parent first, then child overrides.
		var merged: Dictionary = parent_data.duplicate(true)
		for key in entry:
			if key == "parent":
				continue
			merged[key] = entry[key]
		entry = merged

	entry.erase("parent")
	resolved[id] = entry
	visiting.erase(id)
	return entry


# ─── Cache building ───────────────────────────────────────────────────

static func _build_cache() -> void:
	for id_str in _resolved:
		var id := StringName(id_str)
		var entry: Dictionary = _resolved[id_str]
		var def := _build_definition(id, entry)
		_cache[id] = def

	# Layer .tres overrides on top.
	_apply_tres_overrides()


static func _build_definition(id: StringName, entry: Dictionary) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.display_name = entry.get("display_name", String(id))
	def.stack_size = int(entry.get("stack_size", 99))
	def.power = int(entry.get("power", 0))
	def.description_flavor = entry.get("description_flavor", "")

	# Economy
	def.buy_price = int(entry.get("buy_price", 0))
	def.sell_price = int(entry.get("sell_price", 0))

	# Consumable
	def.consumable = bool(entry.get("consumable", false))
	def.heal_amount = int(entry.get("heal_amount", 0))
	var cure_str: String = entry.get("cure_status", "")
	def.cure_status = StringName(cure_str) if cure_str != "" else &""

	# Caravan / crafting
	def.is_crafting_ingredient = bool(entry.get("is_crafting_ingredient", false))

	# Slot
	var slot_str: String = entry.get("slot", "none").to_lower()
	def.slot = _SLOT_MAP.get(slot_str, ItemDefinition.Slot.NONE)

	# Rarity
	var rarity_str: String = entry.get("rarity", "common").to_lower()
	def.rarity = _RARITY_MAP.get(rarity_str, ItemDefinition.Rarity.COMMON)

	# Combat fields
	def.hands = int(entry.get("hands", 1))
	var at_str: String = entry.get("attack_type", "none").to_lower()
	def.attack_type = _ATTACK_TYPE_MAP.get(at_str, ItemDefinition.AttackType.NONE)
	def.attack_speed = float(entry.get("attack_speed", 0.0))
	def.reach = float(entry.get("reach", 0.0))
	def.knockback = float(entry.get("knockback", 0.0))

	var wc_str: String = entry.get("weapon_category", "none").to_lower()
	def.weapon_category = _WEAPON_CAT_MAP.get(wc_str, ItemDefinition.WeaponCategory.NONE)

	# Element
	var elem_str: String = entry.get("element", "none").to_lower()
	def.element = _ELEMENT_MAP.get(elem_str, ItemDefinition.Element.NONE)

	# Misc
	def.tier = entry.get("tier", "")
	def.set_id = entry.get("set_id", "")
	def.stat_bonuses = entry.get("stat_bonuses", {}).duplicate()

	# Sprite cells
	var ws: Variant = entry.get("weapon_sprite", null)
	if ws is Array and ws.size() >= 2:
		def.weapon_sprite = Vector2i(int(ws[0]), int(ws[1]))
	var as_val: Variant = entry.get("armor_sprite", null)
	if as_val is Array and as_val.size() >= 2:
		def.armor_sprite = Vector2i(int(as_val[0]), int(as_val[1]))
	var at_val: Variant = entry.get("armor_tint", null)
	if at_val is Array and at_val.size() >= 4:
		def.armor_tint = Color(float(at_val[0]), float(at_val[1]),
			float(at_val[2]), float(at_val[3]))
	var ss: Variant = entry.get("shield_sprite", null)
	if ss is Array and ss.size() >= 2:
		def.shield_sprite = Vector2i(int(ss[0]), int(ss[1]))

	# Icon texture — prefer hires PNG if available, fall back to icon_idx sheet.
	var hires_tex: Texture2D = HiresIconRegistry.get_icon(id)
	if hires_tex != null:
		def.icon = hires_tex
	else:
		var icon_idx: int = int(entry.get("icon_idx", -1))
		if icon_idx >= 0:
			var path: String = _ICON_BASE % icon_idx
			if ResourceLoader.exists(path):
				def.icon = load(path) as Texture2D

	# Auto-generate description from fields.
	def.description = def.generate_description()

	return def


static func _apply_tres_overrides() -> void:
	if not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(_OVERRIDE_DIR)):
		return
	var d := DirAccess.open(_OVERRIDE_DIR)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		if n.ends_with(".tres"):
			var tres_def := load(_OVERRIDE_DIR + n) as ItemDefinition
			if tres_def != null and tres_def.id != &"":
				if _cache.has(tres_def.id):
					# Merge: only take the icon from .tres (hand-picked PNGs).
					var existing: ItemDefinition = _cache[tres_def.id]
					if tres_def.icon != null:
						existing.icon = tres_def.icon
				else:
					# Item only exists in .tres (not in JSON) — use as-is.
					_cache[tres_def.id] = tres_def
		n = d.get_next()
