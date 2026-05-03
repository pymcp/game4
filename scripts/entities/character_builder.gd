## CharacterBuilder
##
## Assembles a paper-doll Sprite2D stack from CharacterAtlas pieces.
## All pieces share a common origin (the character's root Node2D).
##
## Usage:
##   var node := CharacterBuilder.build({
##     "torso_color": &"orange", "torso_style": 0,
##     "hair_color": &"brown",   "hair_style": CharacterAtlas.HairStyle.SHORT,
##     "weapon": "staff", "weapon_variant": 0, "weapon_color_row": 2,
##     "shield": "kite", "shield_material": &"steel",
##   })
##   add_child(node)
##
## Pieces are arranged in this z-order (back -> front):
##   torso, belt, cape, hair, face, shield, weapon
class_name CharacterBuilder
extends RefCounted

const _SHEET: Texture2D = preload("res://assets/characters/roguelike/characters_sheet.png")

## Cached SheetSpec so we only read the sidecar file once.
static var _spec: SheetSpec = null

static func _get_spec() -> SheetSpec:
	if _spec == null:
		_spec = SheetSpecReader.read(CharacterAtlas.SHEET_PATH)
	return _spec

static func build(opts: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.name = "Character"
	var layers: Array[Array] = [
		["body", _body_cell(opts)],
		["torso", _torso_cell(opts)],
		["belt", _belt_cell(opts)],
		["cape", _cape_cell(opts)],
		["hair", _hair_cell(opts)],
		["face", _face_cell(opts)],
		["shield", _shield_cell(opts)],
	]
	for entry in layers:
		var name: String = entry[0]
		var cell: Vector2i = entry[1]
		if cell.x < 0:
			continue
		var spr := _make_sprite(name, cell, 1)
		root.add_child(spr)
	var weapon: Vector2i = _weapon_cell(opts)
	if weapon.x >= 0:
		# Weapons are 2 tiles tall; offset up by 8 so the grip sits at body center.
		var wspr := _make_sprite("weapon", weapon, 2)
		wspr.position = Vector2(0, -8)
		root.add_child(wspr)
	return root

static func _make_sprite(name: String, cell: Vector2i, height_tiles: int) -> Sprite2D:
	var spec := _get_spec()
	var spr := Sprite2D.new()
	spr.name = name
	spr.texture = _SHEET
	spr.region_enabled = true
	spr.region_rect = Rect2(
		cell.x * spec.stride,
		cell.y * spec.stride,
		spec.tile_px,
		spec.tile_px * height_tiles + spec.margin_px * (height_tiles - 1),
	)
	spr.centered = true
	var sf: float = spec.scale_factor()
	if sf != 1.0:
		spr.scale = Vector2(sf, sf)
	return spr

static func _torso_cell(opts: Dictionary) -> Vector2i:
	var color: StringName = opts.get("torso_color", &"orange")
	var style: int = int(opts.get("torso_style", 0))
	var row: int = int(opts.get("torso_row", 0))
	return CharacterAtlas.torso_cell(color, style, row)

static func _body_cell(opts: Dictionary) -> Vector2i:
	# Default to light skin so callers that pre-date this layer (i.e. the
	# original torso-only callers) still render with a visible person
	# instead of just floating clothes.
	var skin: StringName = opts.get("skin", &"light")
	return CharacterAtlas.body_cell(skin)

static func _belt_cell(opts: Dictionary) -> Vector2i:
	if not opts.has("belt_row"):
		return Vector2i(-1, -1)
	var use_buckle: bool = bool(opts.get("belt_buckle", true))
	var col: int = (CharacterAtlas.BELT_COL_BUCKLE
		if use_buckle else CharacterAtlas.BELT_COL_SASH)
	return Vector2i(col, int(opts["belt_row"]))

static func _cape_cell(opts: Dictionary) -> Vector2i:
	if not opts.has("cape_color"):
		return Vector2i(-1, -1)
	return CharacterAtlas.cape_cell(opts["cape_color"], int(opts.get("cape_variant", 0)))

static func _hair_cell(opts: Dictionary) -> Vector2i:
	if not opts.has("hair_color"):
		return Vector2i(-1, -1)
	var style: int = int(opts.get("hair_style", CharacterAtlas.HairStyle.SHORT))
	var variant: int = int(opts.get("hair_variant", 0))
	return CharacterAtlas.hair_cell(opts["hair_color"], style, variant)

static func _face_cell(opts: Dictionary) -> Vector2i:
	if not opts.has("face_color"):
		return Vector2i(-1, -1)
	return CharacterAtlas.hair_cell(opts["face_color"],
		CharacterAtlas.HairStyle.FACIAL, int(opts.get("face_variant", 0)))

static func _shield_cell(opts: Dictionary) -> Vector2i:
	if not opts.has("shield_material"):
		return Vector2i(-1, -1)
	var shape: int = int(opts.get("shield_shape", CharacterAtlas.ShieldShape.KITE))
	return CharacterAtlas.shield_cell(opts["shield_material"], shape)

static func _weapon_cell(opts: Dictionary) -> Vector2i:
	var kind: String = String(opts.get("weapon", ""))
	if kind == "":
		return Vector2i(-1, -1)
	var color_row: int = int(opts.get("weapon_color_row", 0))
	var variant: int = int(opts.get("weapon_variant", 0))
	match kind:
		"staff": return CharacterAtlas.staff_cell(variant, color_row)
		"sword": return CharacterAtlas.sword_cell(variant, color_row)
		"bow":   return CharacterAtlas.bow_cell(color_row)
		_:       return Vector2i(-1, -1)
