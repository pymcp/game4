## PlayerHUD
##
## Per-player overlay shown over a SubViewport in the split-screen Game scene.
## Wires a [HeartDisplay] and a [Hotbar] to a [PlayerController]'s health and
## inventory so they refresh automatically.
##
## Built programmatically so we don't need a packed scene per HUD; that keeps
## tests light and lets the Game scene instance one HUD per player at runtime.
extends Control
class_name PlayerHUD

const MARGIN: float = 12.0

var _player: PlayerController = null
var _health_bar: HeartDisplay = null
var _hotbar: Hotbar = null
var _interior_label: Label = null
var _biome_label: Label = null
var _status_container: HBoxContainer = null
var _status_labels: Dictionary = {}  # effect_id -> Label
var _clock_label: Label = null
var _xp_bar: XpBar = null
var _passive_banner: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_build()
	_refresh_all()
	# Phase 9c: refresh the interior badge whenever players enter/exit one.
	MapManager.active_interior_changed.connect(_on_active_interior_changed)
	_on_active_interior_changed(MapManager.active_interior)
	# Refresh the biome readout whenever the active region changes.
	WorldManager.active_region_changed.connect(_on_active_region_changed)
	_refresh_biome_label()


func set_player(p: PlayerController) -> void:
	_player = p
	if _hotbar != null and p != null:
		_hotbar.set_inventory(p.inventory)
	if p != null and not p.leveled_up.is_connected(_on_leveled_up):
		p.leveled_up.connect(_on_leveled_up)
	_refresh_all()


func _process(_delta: float) -> void:
	# Cheap polling for health; we don't have a `health_changed` signal yet.
	if _player != null and _health_bar != null:
		_health_bar.update(_player.health, _player.max_health)
	if _player != null and _xp_bar != null:
		_xp_bar.update(
			_player.xp,
			_player.level,
			LevelingConfig.xp_to_next(_player.level),
			_player._pending_stat_points > 0
		)
	_refresh_status_effects()
	_refresh_clock()


func _build() -> void:
	# Heart-based health display in top-left corner.
	_health_bar = HeartDisplay.new(27.0)
	_health_bar.name = "HeartDisplay"
	_health_bar.position = Vector2(MARGIN, MARGIN)
	add_child(_health_bar)

	# XP bar below hearts.
	_xp_bar = XpBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.position = Vector2(MARGIN, MARGIN + 30)
	add_child(_xp_bar)

	# Status effect icons below hearts.
	_status_container = HBoxContainer.new()
	_status_container.name = "StatusEffects"
	_status_container.position = Vector2(MARGIN, MARGIN + 50)
	_status_container.add_theme_constant_override("separation", 6)
	_status_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_container)

	# Passive unlock notification banner (hidden by default).
	_passive_banner = Label.new()
	_passive_banner.name = "PassiveBanner"
	_passive_banner.add_theme_font_size_override("font_size", 14)
	_passive_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_passive_banner.anchor_left = 0.5
	_passive_banner.anchor_right = 0.5
	_passive_banner.offset_left = -150
	_passive_banner.offset_right = 150
	_passive_banner.offset_top = 60
	_passive_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_passive_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_passive_banner.visible = false
	add_child(_passive_banner)

	# Hotbar centred along the bottom.
	_hotbar = Hotbar.new()
	_hotbar.name = "Hotbar"
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 4)
	_hotbar.add_child(row)
	_hotbar.anchor_left = 0.5
	_hotbar.anchor_right = 0.5
	_hotbar.anchor_top = 1.0
	_hotbar.anchor_bottom = 1.0
	var bar_w := HotbarSlot.SLOT_SIZE * Hotbar.DEFAULT_VISIBLE_SLOTS + 4 * (Hotbar.DEFAULT_VISIBLE_SLOTS - 1)
	_hotbar.offset_left = -bar_w * 0.5
	_hotbar.offset_right = bar_w * 0.5
	_hotbar.offset_top = -HotbarSlot.SLOT_SIZE - MARGIN
	_hotbar.offset_bottom = -MARGIN
	add_child(_hotbar)

	# Phase 9c: interior badge in top-right; hidden on the overworld.
	_interior_label = Label.new()
	_interior_label.name = "InteriorBadge"
	_interior_label.text = "DUNGEON"
	_interior_label.add_theme_font_size_override("font_size", 15)
	_interior_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	_interior_label.anchor_left = 1.0
	_interior_label.anchor_right = 1.0
	_interior_label.offset_left = -120
	_interior_label.offset_top = MARGIN
	_interior_label.offset_right = -MARGIN
	_interior_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_interior_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interior_label.visible = false
	add_child(_interior_label)

	# Biome readout sits just under the interior badge in the top-right.
	_biome_label = Label.new()
	_biome_label.name = "BiomeLabel"
	_biome_label.add_theme_font_size_override("font_size", 13)
	_biome_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	_biome_label.anchor_left = 1.0
	_biome_label.anchor_right = 1.0
	_biome_label.offset_left = -160
	_biome_label.offset_top = MARGIN + 18
	_biome_label.offset_right = -MARGIN
	_biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_biome_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_biome_label)

	# Clock label below biome readout.
	_clock_label = Label.new()
	_clock_label.name = "Clock"
	_clock_label.add_theme_font_size_override("font_size", 13)
	_clock_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	_clock_label.anchor_left = 1.0
	_clock_label.anchor_right = 1.0
	_clock_label.offset_left = -160
	_clock_label.offset_top = MARGIN + 36
	_clock_label.offset_right = -MARGIN
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clock_label)


func _on_active_interior_changed(interior: InteriorMap) -> void:
	if _interior_label == null:
		return
	_interior_label.visible = interior != null
	_refresh_biome_label()


func _on_active_region_changed(_region) -> void:
	_refresh_biome_label()


func _refresh_biome_label() -> void:
	if _biome_label == null:
		return
	if MapManager.active_interior != null:
		_biome_label.visible = false
		return
	var reg: Region = WorldManager.active_region
	if reg == null:
		_biome_label.visible = false
		return
	_biome_label.visible = true
	_biome_label.text = "Biome: %s" % String(reg.biome).capitalize()


func _refresh_all() -> void:
	if _player == null:
		return
	if _health_bar != null:
		_health_bar.update(_player.health, _player.max_health)
	if _hotbar != null:
		_hotbar.set_inventory(_player.inventory)



func get_interior_label() -> Label:
	return _interior_label


func _refresh_clock() -> void:
	if _clock_label == null:
		return
	var h: int = int(TimeManager.time_of_day)
	var m: int = int((TimeManager.time_of_day - h) * 60.0)
	var period: String = String(TimeManager.get_period()).capitalize()
	_clock_label.text = "%02d:%02d %s" % [h, m, period]


const _ELEMENT_COLORS: Dictionary = {
	1: Color(1.0, 0.4, 0.2),   # FIRE — red-orange
	2: Color(0.3, 0.7, 1.0),   # ICE — blue
	3: Color(1.0, 0.9, 0.2),   # LIGHTNING — yellow
	4: Color(0.3, 0.9, 0.3),   # POISON — green
}


func _refresh_status_effects() -> void:
	if _status_container == null:
		return
	if _player == null:
		for lbl: Label in _status_labels.values():
			lbl.queue_free()
		_status_labels.clear()
		return
	var active_ids: Dictionary = {}
	for entry: Dictionary in _player.active_effects:
		var eid: StringName = entry["effect_id"]
		active_ids[eid] = entry["remaining"]
	# Remove labels for expired effects.
	for eid: StringName in _status_labels.keys():
		if not active_ids.has(eid):
			var lbl: Label = _status_labels[eid]
			_status_container.remove_child(lbl)
			lbl.queue_free()
			_status_labels.erase(eid)
	# Add/update labels for active effects.
	for eid: StringName in active_ids:
		var remaining: float = active_ids[eid]
		var eff: StatusEffect = StatusEffectRegistry.get_effect(eid)
		if eff == null:
			continue
		var lbl: Label
		if _status_labels.has(eid):
			lbl = _status_labels[eid]
		else:
			lbl = Label.new()
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var col: Color = _ELEMENT_COLORS.get(eff.element, Color.WHITE)
			lbl.add_theme_color_override("font_color", col)
			_status_container.add_child(lbl)
			_status_labels[eid] = lbl
		lbl.text = "%s %.1f" % [eff.display_name, remaining]


func _on_leveled_up(_pid: int, new_level: int) -> void:
	var passive: StringName = LevelingConfig.milestone_passive(new_level)
	if passive == &"" or _passive_banner == null:
		return
	var names: Dictionary = {
		&"hardy": "Hardy", &"scavenger": "Scavenger",
		&"iron_skin": "Iron Skin", &"hero": "Hero"
	}
	_passive_banner.text = "PASSIVE UNLOCKED: %s" % names.get(passive, str(passive))
	_passive_banner.visible = true
	_passive_banner.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_passive_banner, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _passive_banner.visible = false)
