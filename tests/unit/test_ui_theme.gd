extends GutTest

func test_col_constants_are_defined() -> void:
	assert_eq(UITheme.COL_BG, Color(0.16, 0.11, 0.09, 0.95))
	assert_eq(UITheme.COL_FRAME, Color(0.62, 0.42, 0.22))
	assert_eq(UITheme.COL_SLOT_BG, Color(0.22, 0.14, 0.09, 0.85))
	assert_eq(UITheme.COL_SLOT_BRD, Color(0.50, 0.34, 0.18))
	assert_eq(UITheme.COL_TITLE_BG, Color(0.34, 0.21, 0.13))
	assert_eq(UITheme.COL_PARCHMENT, Color(0.28, 0.20, 0.14, 0.60))
	assert_eq(UITheme.COL_SILHOUETTE, Color(0.45, 0.34, 0.24, 0.35))
	assert_eq(UITheme.COL_LABEL, Color(0.88, 0.82, 0.70))
	assert_eq(UITheme.COL_LABEL_DIM, Color(0.55, 0.48, 0.38))
	assert_eq(UITheme.COL_TAB_ACTIVE, Color(0.34, 0.21, 0.13))
	assert_eq(UITheme.COL_TAB_INACTIVE, Color(0.20, 0.14, 0.10))
	assert_eq(UITheme.COL_CURSOR, Color(0.95, 0.85, 0.45, 0.9))
	assert_eq(UITheme.COL_TAB_GOLD, Color(0.95, 0.80, 0.40))


func test_slot_sz_is_48() -> void:
	assert_eq(UITheme.SLOT_SZ, 48.0)


func test_build_returns_theme() -> void:
	var t: Theme = UITheme.build()
	assert_not_null(t)
	assert_true(t is Theme)


func test_build_has_wood_panel_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"WoodPanel"), &"PanelContainer")


func test_build_has_wood_button_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"WoodButton"), &"Button")


func test_build_has_title_label_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"TitleLabel"), &"Label")


func test_build_has_dim_label_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"DimLabel"), &"Label")


func test_build_has_slot_panel_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"SlotPanel"), &"Panel")


func test_build_has_cursor_panel_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"CursorPanel"), &"Panel")


func test_build_has_wood_inner_panel_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"WoodInnerPanel"), &"PanelContainer")


func test_build_has_title_bar_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"TitleBar"), &"PanelContainer")


func test_build_has_wood_tab_button_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"WoodTabButton"), &"Button")


func test_build_has_wood_tab_button_active_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"WoodTabButtonActive"), &"Button")


func test_build_has_hint_label_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"HintLabel"), &"Label")


func test_build_has_wood_sep_variation() -> void:
	var t: Theme = UITheme.build()
	assert_eq(t.get_type_variation_base(&"WoodSep"), &"Panel")
