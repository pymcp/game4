## Phase 9b: Sfx autoload smoke tests + dungeon enter/exit hooks fire.
extends GutTest


func test_sfx_has_dungeon_enter() -> void:
	assert_true(Sfx.has_key(&"dungeon_enter"))


func test_sfx_has_dungeon_exit() -> void:
	assert_true(Sfx.has_key(&"dungeon_exit"))


func test_sfx_play_returns_player_node() -> void:
	var p: AudioStreamPlayer = Sfx.play(&"dungeon_enter")
	assert_not_null(p)
	assert_true(p.is_inside_tree())
	assert_true(p.playing)
	# Cleanup happens via finished -> queue_free, but the test runner may
	# tear down before the stream ends — that's fine.


func test_sfx_play_unknown_returns_null() -> void:
	var p: AudioStreamPlayer = Sfx.play(&"nope_does_not_exist")
	assert_null(p)
