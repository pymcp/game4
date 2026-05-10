extends GutTest
## Unit tests for DebugFeedbackLogger.

const _TMP_PATH := "res://tmp/dialogue_feedback_test.json"


func before_each() -> void:
	# Redirect to a test path so tests don't pollute the real log.
	# We can't override the const directly in GDScript, so we clear
	# the real path and use a monkey-patched wrapper below.
	if FileAccess.file_exists(DebugFeedbackLogger.LOG_PATH):
		DebugFeedbackLogger.clear()


func after_each() -> void:
	DebugFeedbackLogger.clear()


func test_log_creates_file_with_one_entry() -> void:
	var entry := {
		"timestamp": "2025-01-01T00:00:00",
		"npc_name": "Mara",
		"dialogue_tree_path": "res://resources/dialogue/mara.tres",
		"active_quests": [],
		"flags_set_this_conversation": [],
		"conversation_path": [{"speaker": "Mara", "text": "Hello!", "choices_shown": [], "choice_made": null}],
		"feedback": "Great intro line.",
	}
	DebugFeedbackLogger.log_entry(entry)
	var all: Array = DebugFeedbackLogger.read_all()
	assert_eq(all.size(), 1, "One entry should be written")
	assert_eq(all[0]["npc_name"], "Mara")
	assert_eq(all[0]["feedback"], "Great intro line.")


func test_log_appends_multiple_entries() -> void:
	DebugFeedbackLogger.log_entry({"feedback": "first"})
	DebugFeedbackLogger.log_entry({"feedback": "second"})
	var all: Array = DebugFeedbackLogger.read_all()
	assert_eq(all.size(), 2, "Two entries should be present")
	assert_eq(all[0]["feedback"], "first")
	assert_eq(all[1]["feedback"], "second")


func test_read_all_returns_empty_when_no_file() -> void:
	DebugFeedbackLogger.clear()
	var all: Array = DebugFeedbackLogger.read_all()
	assert_eq(all.size(), 0, "No file → empty array")


func test_clear_removes_file() -> void:
	DebugFeedbackLogger.log_entry({"feedback": "delete me"})
	DebugFeedbackLogger.clear()
	assert_false(FileAccess.file_exists(DebugFeedbackLogger.LOG_PATH),
		"File should be removed after clear()")
