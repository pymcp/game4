## UITheme
##
## Central source of truth for the game's UI palette and Godot Theme resource.
## All colour constants live here. Call [method build] to construct the
## project-wide [Theme] resource programmatically; use
## [code]tools/gen_ui_theme.gd[/code] to serialise it to
## [code]resources/ui/game_theme.tres[/code].
##
## Scripts that need a colour value should read [code]UITheme.COL_*[/code]
## directly — DO NOT duplicate these values inline.
class_name UITheme
extends RefCounted

# ---------------------------------------------------------------------------
# Palette — Pixel Adventure wood tones
# ---------------------------------------------------------------------------
const COL_BG         := Color(0.16, 0.11, 0.09, 0.95)
const COL_FRAME      := Color(0.62, 0.42, 0.22)
const COL_SLOT_BG    := Color(0.22, 0.14, 0.09, 0.85)
const COL_SLOT_BRD   := Color(0.50, 0.34, 0.18)
const COL_TITLE_BG   := Color(0.34, 0.21, 0.13)
const COL_PARCHMENT  := Color(0.28, 0.20, 0.14, 0.60)
const COL_SILHOUETTE := Color(0.45, 0.34, 0.24, 0.35)
const COL_LABEL      := Color(0.88, 0.82, 0.70)
const COL_LABEL_DIM  := Color(0.55, 0.48, 0.38)
const COL_TAB_ACTIVE   := Color(0.34, 0.21, 0.13)
const COL_TAB_INACTIVE := Color(0.20, 0.14, 0.10)
const COL_CURSOR     := Color(0.95, 0.85, 0.45, 0.9)
const COL_TAB_GOLD   := Color(0.95, 0.80, 0.40)

# Slot size shared with InventoryScreen and HotbarSlot.
const SLOT_SZ: float = 48.0


# ---------------------------------------------------------------------------
# Theme builder
# ---------------------------------------------------------------------------

## Build and return the full project-wide [Theme] resource.
## All type variations for the wood-tone fantasy UI are defined here.
## Run [code]tools/gen_ui_theme.gd[/code] to save the result to
## [code]resources/ui/game_theme.tres[/code].
static func build() -> Theme:
	var t := Theme.new()

	_add_wood_panel(t)
	_add_wood_inner_panel(t)
	_add_title_bar(t)
	_add_wood_button(t)
	_add_wood_tab_button(t)
	_add_wood_tab_button_active(t)
	_add_title_label(t)
	_add_dim_label(t)
	_add_hint_label(t)
	_add_slot_panel(t)
	_add_cursor_panel(t)
	_add_wood_sep(t)

	return t


# ---------------------------------------------------------------------------
# Private helpers — one per type variation
# ---------------------------------------------------------------------------

static func _add_wood_panel(t: Theme) -> void:
	t.add_type(&"WoodPanel")
	t.set_type_variation(&"WoodPanel", &"PanelContainer")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.border_color = COL_FRAME
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	t.set_stylebox(&"panel", &"WoodPanel", sb)


static func _add_wood_inner_panel(t: Theme) -> void:
	t.add_type(&"WoodInnerPanel")
	t.set_type_variation(&"WoodInnerPanel", &"PanelContainer")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PARCHMENT
	sb.border_color = COL_FRAME.darkened(0.2)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	t.set_stylebox(&"panel", &"WoodInnerPanel", sb)


static func _add_title_bar(t: Theme) -> void:
	t.add_type(&"TitleBar")
	t.set_type_variation(&"TitleBar", &"PanelContainer")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TITLE_BG
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	t.set_stylebox(&"panel", &"TitleBar", sb)


static func _add_wood_button(t: Theme) -> void:
	t.add_type(&"WoodButton")
	t.set_type_variation(&"WoodButton", &"Button")
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = COL_TAB_INACTIVE
	sb_normal.border_color = COL_FRAME
	sb_normal.border_width_left = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_bottom = 2
	sb_normal.corner_radius_top_left = 3
	sb_normal.corner_radius_top_right = 3
	sb_normal.corner_radius_bottom_left = 3
	sb_normal.corner_radius_bottom_right = 3
	sb_normal.content_margin_left = 10.0
	sb_normal.content_margin_right = 10.0
	sb_normal.content_margin_top = 5.0
	sb_normal.content_margin_bottom = 5.0
	t.set_stylebox(&"normal", &"WoodButton", sb_normal)
	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = COL_TAB_ACTIVE
	sb_hover.border_color = COL_FRAME
	t.set_stylebox(&"hover", &"WoodButton", sb_hover)
	t.set_stylebox(&"pressed", &"WoodButton", sb_hover)
	var sb_focus := StyleBoxFlat.new()
	sb_focus.bg_color = Color(0, 0, 0, 0)
	sb_focus.border_color = COL_CURSOR
	sb_focus.border_width_left = 2
	sb_focus.border_width_right = 2
	sb_focus.border_width_top = 2
	sb_focus.border_width_bottom = 2
	sb_focus.corner_radius_top_left = 3
	sb_focus.corner_radius_top_right = 3
	sb_focus.corner_radius_bottom_left = 3
	sb_focus.corner_radius_bottom_right = 3
	t.set_stylebox(&"focus", &"WoodButton", sb_focus)
	t.set_color(&"font_color", &"WoodButton", COL_LABEL)
	t.set_color(&"font_hover_color", &"WoodButton", Color.WHITE)
	t.set_color(&"font_pressed_color", &"WoodButton", Color.WHITE)
	t.set_color(&"font_disabled_color", &"WoodButton", COL_LABEL_DIM)
	t.set_font_size(&"font_size", &"WoodButton", 13)


static func _add_wood_tab_button(t: Theme) -> void:
	t.add_type(&"WoodTabButton")
	t.set_type_variation(&"WoodTabButton", &"Button")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TAB_INACTIVE
	sb.border_color = COL_FRAME.darkened(0.3)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 3
	sb.corner_radius_bottom_left = 3
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	t.set_stylebox(&"normal", &"WoodTabButton", sb)
	t.set_stylebox(&"hover", &"WoodTabButton", sb)
	t.set_stylebox(&"pressed", &"WoodTabButton", sb)
	t.set_color(&"font_color", &"WoodTabButton", COL_LABEL_DIM)
	t.set_color(&"font_hover_color", &"WoodTabButton", Color.WHITE)
	t.set_font_size(&"font_size", &"WoodTabButton", 13)


static func _add_wood_tab_button_active(t: Theme) -> void:
	t.add_type(&"WoodTabButtonActive")
	t.set_type_variation(&"WoodTabButtonActive", &"Button")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_TAB_ACTIVE
	sb.border_color = COL_TAB_GOLD
	sb.border_width_left = 4
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 3
	sb.corner_radius_bottom_left = 3
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	t.set_stylebox(&"normal", &"WoodTabButtonActive", sb)
	t.set_stylebox(&"hover", &"WoodTabButtonActive", sb)
	t.set_stylebox(&"pressed", &"WoodTabButtonActive", sb)
	t.set_color(&"font_color", &"WoodTabButtonActive", Color.WHITE)
	t.set_color(&"font_hover_color", &"WoodTabButtonActive", Color.WHITE)
	t.set_font_size(&"font_size", &"WoodTabButtonActive", 13)


static func _add_title_label(t: Theme) -> void:
	t.add_type(&"TitleLabel")
	t.set_type_variation(&"TitleLabel", &"Label")
	t.set_color(&"font_color", &"TitleLabel", COL_LABEL)
	t.set_font_size(&"font_size", &"TitleLabel", 16)


static func _add_dim_label(t: Theme) -> void:
	t.add_type(&"DimLabel")
	t.set_type_variation(&"DimLabel", &"Label")
	t.set_color(&"font_color", &"DimLabel", COL_LABEL_DIM)
	t.set_font_size(&"font_size", &"DimLabel", 13)


static func _add_hint_label(t: Theme) -> void:
	t.add_type(&"HintLabel")
	t.set_type_variation(&"HintLabel", &"Label")
	t.set_color(&"font_color", &"HintLabel", COL_LABEL_DIM)
	t.set_font_size(&"font_size", &"HintLabel", 11)


static func _add_slot_panel(t: Theme) -> void:
	t.add_type(&"SlotPanel")
	t.set_type_variation(&"SlotPanel", &"Panel")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_SLOT_BG
	sb.border_color = COL_SLOT_BRD
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	t.set_stylebox(&"panel", &"SlotPanel", sb)


static func _add_cursor_panel(t: Theme) -> void:
	t.add_type(&"CursorPanel")
	t.set_type_variation(&"CursorPanel", &"Panel")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = COL_CURSOR
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	t.set_stylebox(&"panel", &"CursorPanel", sb)


static func _add_wood_sep(t: Theme) -> void:
	t.add_type(&"WoodSep")
	t.set_type_variation(&"WoodSep", &"Panel")
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_FRAME.darkened(0.3)
	t.set_stylebox(&"panel", &"WoodSep", sb)
