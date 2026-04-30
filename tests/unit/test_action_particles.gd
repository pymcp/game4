extends GutTest

func test_flash_level_up_does_not_crash_on_null() -> void:
	# Must not throw — safe to call with null
	ActionParticles.flash_level_up(null)
	assert_true(true, "flash_level_up(null) did not crash")

func test_flash_level_up_exists() -> void:
	assert_true(ActionParticles.new().has_method("flash_level_up"),
		"ActionParticles should have flash_level_up static method")
