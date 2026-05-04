extends GutTest

func before_each() -> void:
	NpcPortraitRegistry.reset()


func test_mara_cell() -> void:
	var cell: Vector2i = NpcPortraitRegistry.get_cell("Mara")
	assert_eq(cell, Vector2i(0, 0), "Mara should be at cell [0,0]")


func test_unknown_speaker_returns_no_portrait() -> void:
	var cell: Vector2i = NpcPortraitRegistry.get_cell("Nobody")
	assert_eq(cell, NpcPortraitRegistry.NO_PORTRAIT, "Unknown speaker returns NO_PORTRAIT")


func test_has_portrait_true_for_mara() -> void:
	assert_true(NpcPortraitRegistry.has_portrait("Mara"))


func test_has_portrait_false_for_unknown() -> void:
	assert_false(NpcPortraitRegistry.has_portrait("Nobody"))


func test_all_speakers_includes_mara() -> void:
	assert_true("Mara" in NpcPortraitRegistry.all_speakers())


func test_sheet_path_constant() -> void:
	assert_eq(NpcPortraitRegistry.SHEET_PATH,
		"res://assets/icons/hires/portraits.png")
