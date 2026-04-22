## PlayerHUD
##
## Per-player overlay shown over a SubViewport in the split-screen Game scene.
## Wires a [HealthBar] and a [Hotbar] to a [PlayerController]'s health and
## inventory so they refresh automatically.
##
## Built programmatically so we don't need a packed scene per HUD; that keeps
## tests light and lets the Game scene instance one HUD per player at runtime.
extends Control
class_name PlayerHUD

const MARGIN: float = 12.0

var _player: PlayerController = null
var _health_bar: HealthBar = null
var _hotbar: Hotbar = null
var _interior_label: Label = null
var _biome_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_refresh_all()


func _process(_delta: float) -> void:
	# Cheap polling for health; we don't have a `health_changed` signal yet.
	if _player != null and _health_bar != null:
		_health_bar.update(_player.health, _player.max_health)


func _build() -> void:
	# Health bar in top-left corner.
	_health_bar = HealthBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.position = Vector2(MARGIN, MARGIN)
	_health_bar.size = Vector2(HealthBar.BAR_WIDTH, HealthBar.BAR_HEIGHT + 14)
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0, 0, 0, 0.4)
	bg.size = Vector2(HealthBar.BAR_WIDTH, HealthBar.BAR_HEIGHT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_child(bg)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.30, 0.78, 0.30)
	fill.size = Vector2(HealthBar.BAR_WIDTH, HealthBar.BAR_HEIGHT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_child(fill)
	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(0, HealthBar.BAR_HEIGHT)
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.add_child(label)
	add_child(_health_bar)

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
