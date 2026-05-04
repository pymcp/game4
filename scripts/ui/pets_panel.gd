## PetsPanel
##
## Right-panel content for the "Pets" tab in [CaravanMenu].
##
## Displays the player's full pet roster. UP/DOWN move the cursor;
## INTERACT follows the highlighted pet (calls swap_active_pet).
## The active pet is shown in green; the cursor row is highlighted in gold.
class_name PetsPanel
extends VBoxContainer

signal pet_follow_requested(player_id: int, species: StringName)

var _player_id: int = 0
var _world_node: Node = null

var _roster: Array[StringName] = []
var _active_species: StringName = &""
var _cursor: int = 0
var _rows: Array[Label] = []


func setup(player_id: int, world_node: Node) -> void:
	_player_id = player_id
	_world_node = world_node
	anchor_right = 1.0
	anchor_bottom = 1.0
	_refresh()


## Called by CaravanMenu after a swap so the panel reflects the new active pet.
func refresh_active() -> void:
	if _world_node != null and _world_node.has_method("get_active_pet_species"):
		_active_species = _world_node.call("get_active_pet_species", _player_id)
	_rebuild_rows()


func navigate(verb: StringName) -> void:
	if _roster.is_empty():
		return
	if verb == PlayerActions.UP:
		_cursor = wrapi(_cursor - 1, 0, _roster.size())
		_refresh_cursor()
	elif verb == PlayerActions.DOWN:
		_cursor = wrapi(_cursor + 1, 0, _roster.size())
		_refresh_cursor()
	elif verb == PlayerActions.INTERACT:
		var sp: StringName = _roster[_cursor]
		if sp != _active_species:
			pet_follow_requested.emit(_player_id, sp)
			_active_species = sp  # optimistic update before signal is processed
			_rebuild_rows()


func _refresh() -> void:
	_roster.clear()
	_active_species = &""
	if _world_node == null:
		_rebuild_rows()
		return
	if _world_node.has_method("get_pet_roster"):
		_roster = _world_node.call("get_pet_roster", _player_id)
	if _world_node.has_method("get_active_pet_species"):
		_active_species = _world_node.call("get_active_pet_species", _player_id)
	# Keep cursor in range.
	_cursor = clampi(_cursor, 0, max(0, _roster.size() - 1))
	_rebuild_rows()


func _rebuild_rows() -> void:
	for child in get_children():
		child.queue_free()
	_rows.clear()

	if _roster.is_empty():
		var empty := Label.new()
		empty.text = "No pets yet."
		empty.theme_type_variation = &"DimLabel"
		add_child(empty)
		return

	for sp: StringName in _roster:
		var lbl := Label.new()
		lbl.text = _row_text(sp)
		add_child(lbl)
		_rows.append(lbl)

	_refresh_cursor()


func _row_text(species: StringName) -> String:
	var name: String = PetRegistry.get_display_name(species)
	var ability: StringName = PetRegistry.get_ability(species)
	var suffix: String = ""
	if ability != &"none":
		suffix = "  (%s)" % PetRegistry.get_ability_description(species)
	if species == _active_species:
		return name + suffix + "  [Following]"
	return name + suffix


func _refresh_cursor() -> void:
	for i: int in _rows.size():
		var lbl: Label = _rows[i]
		lbl.remove_theme_color_override("font_color")
		if i == _cursor:
			lbl.add_theme_color_override("font_color", UITheme.COL_CURSOR)
		elif _roster[i] == _active_species:
			lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
