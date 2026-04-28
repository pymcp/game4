## StoryTellerPanel
##
## Three-tab recap panel shown in the CaravanMenu when the player
## selects their Story Teller. Views:
##   Quests          — active objectives and completed quest list.
##   Voices Overheard — NPCs met and lore tidbits from GameState flags.
##   Last Adventure  — stats from the player's most recent dungeon run.
extends Control
class_name StoryTellerPanel

const _LORE_TEXT_PATH: String = "res://resources/lore_text.json"

var _player: PlayerController = null
var _caravan_data: CaravanData = null
var _teller_name: String = "The Story Teller"
var _content: VBoxContainer = null
var _lore_text: Dictionary = {}
var _tab_buttons: Array[Button] = []

enum View { QUESTS, VOICES, ADVENTURE }
var _current_view: View = View.QUESTS


func setup(player: PlayerController, caravan_data: CaravanData) -> void:
	_player = player
	_caravan_data = caravan_data
	if caravan_data != null:
		_teller_name = caravan_data.get_member_name(&"story_teller")
	_load_lore_text()
	_build_ui()
	_show_view(View.QUESTS)


func _load_lore_text() -> void:
	var f := FileAccess.open(_LORE_TEXT_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_lore_text = parsed


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Tab row.
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_row)

	var tab_labels: Array[String] = ["Quests", "Voices Overheard", "Last Adventure"]
	var tab_views: Array[View] = [View.QUESTS, View.VOICES, View.ADVENTURE]
	_tab_buttons.clear()
	for i in 3:
		var btn := Button.new()
		btn.text = tab_labels[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.theme_type_variation = &"WoodTabButtonActive" if i == 0 else &"WoodTabButton"
		btn.pressed.connect(_show_view.bind(tab_views[i]))
		tab_row.add_child(btn)
		_tab_buttons.append(btn)

	vbox.add_child(HSeparator.new())

	# Scrollable content area inside a styled panel.
	var content_panel := PanelContainer.new()
	content_panel.theme_type_variation = &"WoodInnerPanel"
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)


func _show_view(view: View) -> void:
	if _content == null:
		return
	_current_view = view
	for i in _tab_buttons.size():
		_tab_buttons[i].theme_type_variation = \
				&"WoodTabButtonActive" if i == int(view) else &"WoodTabButton"
	for child in _content.get_children():
		child.queue_free()
	match view:
		View.QUESTS:
			_build_quests_view()
		View.VOICES:
			_build_voices_view()
		View.ADVENTURE:
			_build_adventure_view()


## Called by CaravanMenu when this panel has keyboard focus.
## [param verb] is a PlayerActions verb constant.
func navigate(verb: StringName) -> void:
	match verb:
		PlayerActions.TAB_PREV:
			var v: int = wrapi(int(_current_view) - 1, 0, 3)
			_show_view(v as View)
		PlayerActions.TAB_NEXT:
			var v: int = wrapi(int(_current_view) + 1, 0, 3)
			_show_view(v as View)
		PlayerActions.UP:
			if _content != null and _content.get_parent() is ScrollContainer:
				var sc := _content.get_parent() as ScrollContainer
				sc.scroll_vertical = max(0, sc.scroll_vertical - 32)
		PlayerActions.DOWN:
			if _content != null and _content.get_parent() is ScrollContainer:
				var sc := _content.get_parent() as ScrollContainer
				sc.scroll_vertical += 32


func _build_quests_view() -> void:
	var active_ids: Array[String] = []
	var complete_ids: Array[String] = []
	for qid: String in QuestRegistry.all_ids():
		if QuestTracker.is_quest_complete(qid):
			complete_ids.append(qid)
		elif QuestTracker.is_quest_active(qid):
			active_ids.append(qid)

	if active_ids.is_empty() and complete_ids.is_empty():
		_add_flavor_line("*%s taps her quill. 'No tales yet to tell — but the road lies ahead.'*"
				% _teller_name)
		return

	for qid in active_ids:
		_add_quest_entry(qid, false)
	if not complete_ids.is_empty():
		_add_label("─── Completed ───", true)
		for qid in complete_ids:
			_add_quest_entry(qid, true)


func _add_quest_entry(quest_id: String, completed: bool) -> void:
	var quest: Dictionary = QuestRegistry.get_quest(quest_id)
	if quest.is_empty():
		return
	var header := Label.new()
	header.text = quest.get("display_name", quest_id)
	header.add_theme_color_override("font_color",
			UITheme.COL_LABEL_DIM if completed else UITheme.COL_LABEL)
	_content.add_child(header)

	if not completed:
		var branch_id: String = QuestTracker.get_active_branch(quest_id)
		var branch: Dictionary = QuestRegistry.get_branch(quest_id, branch_id)
		for obj: Dictionary in branch.get("objectives", []):
			var obj_id: String = obj.get("id", "")
			var progress: int = QuestTracker.get_objective_progress(quest_id, obj_id)
			var target: int = obj.get("count", 1)
			var done: bool = progress >= target
			var line := Label.new()
			var check: String = "✓ " if done else "• "
			line.text = "  %s%s (%d/%d)" % [check, obj.get("description", obj_id),
					progress, target]
			line.add_theme_color_override("font_color",
					Color(0.5, 0.9, 0.5) if done else UITheme.COL_LABEL)
			_content.add_child(line)
	_content.add_child(HSeparator.new())


func _build_voices_view() -> void:
	var met_keys: Array[String] = GameState.keys_with_prefix("met_")
	var lore_keys: Array[String] = GameState.keys_with_prefix("lore_")

	if met_keys.is_empty() and lore_keys.is_empty():
		_add_flavor_line("*%s flips through blank pages. 'We've kept to ourselves so far.'*"
				% _teller_name)
		return

	if not met_keys.is_empty():
		_add_label("People Met", true)
		for key: String in met_keys:
			var display: String = key.trim_prefix("met_").replace("_", " ").capitalize()
			_add_label("  • " + display)

	if not lore_keys.is_empty():
		_add_label("Things Overheard", true)
		for key: String in lore_keys:
			var text: String = _lore_text.get(key,
					key.trim_prefix("lore_").replace("_", " ").capitalize())
			_add_label("  " + text)


func _build_adventure_view() -> void:
	var pid: int = _player.player_id if _player != null else 0
	var tlog: TravelLog = null
	if _caravan_data != null and _caravan_data.travel_logs.size() > pid:
		tlog = _caravan_data.travel_logs[pid]

	if tlog == null or tlog.last_run.is_empty():
		_add_flavor_line("*%s looks up expectantly. 'Tell me about your first dungeon — I\\'ll take notes.'*"
				% _teller_name)
		return

	var run: Dictionary = tlog.last_run
	var kind: String = run.get("dungeon_kind", "dungeon")
	var region_str: String = run.get("region_id", "unknown region")
	var enemies: int = run.get("enemies_killed", 0)
	var floors: int = run.get("floors_descended", 0)
	var items: int = run.get("items_looted", 0)
	var chests: int = run.get("chests_opened", 0)

	var summary: String = (
		"*%s leans forward and reads aloud:*\n\n" % _teller_name +
		"'You descended %d floor%s into a %s near region %s, " % [
				floors, "s" if floors != 1 else "", kind, region_str] +
		"slaying %d %s, looting %d item%s from %d chest%s.'" % [
				enemies, "enemies" if enemies != 1 else "enemy",
				items, "s" if items != 1 else "",
				chests, "s" if chests != 1 else ""]
	)
	_add_flavor_line(summary)


# ─── Helpers ────────────────────────────────────────────────────────

func _add_label(text: String, bold: bool = false) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.theme_type_variation = &"DimLabel"
	if bold:
		lbl.add_theme_color_override("font_color", UITheme.COL_TAB_GOLD)
	_content.add_child(lbl)


func _add_flavor_line(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_color_override("default_color", UITheme.COL_LABEL_DIM)
	lbl.text = text
	_content.add_child(lbl)
