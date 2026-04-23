## AssetBrowser
##
## Sub-editor for the game editor that lets you browse kenney_raw/ PNGs,
## preview them on the atlas view, and import (copy) them into assets/.
## Because kenney_raw/ has .gdignore, PNGs are loaded via
## Image.load_from_file() rather than the Godot resource system.
class_name AssetBrowser
extends VBoxContainer

signal dirty_changed
signal sheet_requested(path: String)

## Absolute path to the kenney_raw directory.
const RAW_ROOT := "res://kenney_raw"
## Destination root for imports.
const ASSETS_ROOT := "res://assets"

## Currently previewed image (absolute path under kenney_raw).
var _preview_path: String = ""
## sheet_path property required by game_editor contract (unused for import).
var sheet_path: String = ""

# ─── UI refs ──────────────────────────────────────────────────────────
var _folder_tree: Tree = null
var _file_list: ItemList = null
var _search_edit: LineEdit = null
var _preview_label: Label = null
var _dest_option: OptionButton = null
var _dest_custom_edit: LineEdit = null
var _filename_edit: LineEdit = null
var _import_btn: Button = null
var _status_label: Label = null
var _image_preview: TextureRect = null
var _magenta_check: CheckBox = null

## Flat list of all png paths found under RAW_ROOT (relative to RAW_ROOT).
var _all_pngs: PackedStringArray = []
## Current folder filter path (relative to RAW_ROOT, e.g. "2D assets/Roguelike Base Pack").
var _current_folder: String = ""

## Common import destinations.
const _DEST_PRESETS: Array = [
	"tiles/roguelike",
	"tiles/runes",
	"characters/roguelike",
	"characters/monsters",
	"characters/mounts",
	"characters/pets",
	"icons/generic_items",
	"ui",
	"particles",
	"(custom)",
]


## Per-folder PNG counts, built during scan. folder_path → int.
var _folder_counts: Dictionary = {}

const _MAX_FILE_LIST := 500


func _ready() -> void:
	_build_ui()
	# Defer the scan so the UI is visible first and doesn't appear frozen.
	call_deferred(&"_deferred_init")


func _deferred_init() -> void:
	_scan_raw_pngs()
	_populate_folder_tree()


# ─── Build UI ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 600

	# Top: search bar.
	var search_row := HBoxContainer.new()
	search_row.add_child(_label("Search:"))
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Filter by filename…"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_changed)
	search_row.add_child(_search_edit)
	add_child(search_row)

	# Main split: left = folder tree, middle = file list + preview, right = import panel.
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 250
	add_child(split)

	# ── Left pane: folder tree ──
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size.x = 200
	left.add_child(_section("Packs"))
	split.add_child(left)

	_folder_tree = Tree.new()
	_folder_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_folder_tree.hide_root = true
	_folder_tree.item_selected.connect(_on_folder_selected)
	left.add_child(_folder_tree)

	# ── Right area: file list + preview + import controls (scrollable) ──
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right)

	# File list (icons mode for compact display).
	right.add_child(_section("Files"))
	_file_list = ItemList.new()
	_file_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_file_list.custom_minimum_size.y = 120
	_file_list.item_selected.connect(_on_file_selected)
	right.add_child(_file_list)

	# Inline image preview.
	_preview_label = Label.new()
	_preview_label.text = "Preview: (none)"
	right.add_child(_preview_label)

	_image_preview = TextureRect.new()
	_image_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_preview.custom_minimum_size = Vector2(256, 256)
	_image_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(_image_preview)

	# ── Import controls ──
	right.add_child(_section("Import"))

	var dest_row := HBoxContainer.new()
	dest_row.add_child(_label("Destination:"))
	_dest_option = OptionButton.new()
	_dest_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for preset in _DEST_PRESETS:
		_dest_option.add_item(preset)
	_dest_option.item_selected.connect(_on_dest_changed)
	dest_row.add_child(_dest_option)
	right.add_child(dest_row)

	var custom_row := HBoxContainer.new()
	custom_row.add_child(_label("Custom path:"))
	_dest_custom_edit = LineEdit.new()
	_dest_custom_edit.placeholder_text = "e.g. characters/new_folder"
	_dest_custom_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dest_custom_edit.visible = false
	custom_row.add_child(_dest_custom_edit)
	right.add_child(custom_row)

	var name_row := HBoxContainer.new()
	name_row.add_child(_label("Filename:"))
	_filename_edit = LineEdit.new()
	_filename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_filename_edit)
	right.add_child(name_row)

	_magenta_check = CheckBox.new()
	_magenta_check.text = "Convert magenta to transparent"
	_magenta_check.button_pressed = true
	right.add_child(_magenta_check)

	_import_btn = Button.new()
	_import_btn.text = "Import into assets/"
	_import_btn.pressed.connect(_on_import)
	right.add_child(_import_btn)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	right.add_child(_status_label)


# ─── Scanning ──────────────────────────────────────────────────────────

func _scan_raw_pngs() -> void:
	_all_pngs = PackedStringArray()
	_folder_counts = {}
	var abs_root: String = ProjectSettings.globalize_path(RAW_ROOT)
	_scan_dir_recursive(abs_root, "")


func _scan_dir_recursive(abs_base: String, rel: String) -> void:
	var abs_path: String = abs_base if rel == "" else abs_base + "/" + rel
	var da := DirAccess.open(abs_path)
	if da == null:
		return
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if name.begins_with("."):
			name = da.get_next()
			continue
		var child_rel: String = name if rel == "" else rel + "/" + name
		if da.current_is_dir():
			_scan_dir_recursive(abs_base, child_rel)
		elif name.to_lower().ends_with(".png"):
			_all_pngs.append(child_rel)
			# Tally per-folder count.
			var dir: String = child_rel.get_base_dir()
			_folder_counts[dir] = _folder_counts.get(dir, 0) + 1
		name = da.get_next()
	da.list_dir_end()


# ─── Folder tree ───────────────────────────────────────────────────────

func _populate_folder_tree() -> void:
	_folder_tree.clear()
	var root := _folder_tree.create_item()
	# Build unique folder set from pre-computed counts + parent paths.
	var folders: Dictionary = {}  # path → true
	for folder_path in _folder_counts:
		var dir: String = folder_path
		while dir != "":
			folders[dir] = true
			var parent_dir: String = dir.get_base_dir()
			if parent_dir == dir:
				break
			dir = parent_dir

	# Sort and build tree.
	var sorted_folders: Array = folders.keys()
	sorted_folders.sort()
	# Map folder path → TreeItem for parenting.
	var tree_items: Dictionary = {}
	tree_items[""] = root

	# Add an "All" entry at top.
	var all_item := _folder_tree.create_item(root)
	all_item.set_text(0, "(All %d PNGs)" % _all_pngs.size())
	all_item.set_metadata(0, "")

	for folder_path in sorted_folders:
		var parent_path: String = folder_path.get_base_dir()
		var parent_item: TreeItem = tree_items.get(parent_path, root)
		var item := _folder_tree.create_item(parent_item)
		var folder_name: String = folder_path.get_file()
		var count: int = _folder_counts.get(folder_path, 0)
		if count > 0:
			item.set_text(0, "%s (%d)" % [folder_name, count])
		else:
			item.set_text(0, folder_name)
		item.set_metadata(0, folder_path)
		tree_items[folder_path] = item
		# Collapse deeply nested folders by default.
		if folder_path.count("/") >= 3:
			item.collapsed = true


func _on_folder_selected() -> void:
	var item: TreeItem = _folder_tree.get_selected()
	if item == null:
		return
	_current_folder = item.get_metadata(0)
	_populate_file_list()


# ─── File list ─────────────────────────────────────────────────────────

func _populate_file_list() -> void:
	_file_list.clear()
	var filter: String = _search_edit.text.strip_edges().to_lower()
	var added: int = 0
	for png_path in _all_pngs:
		# Folder filter: show files whose base_dir starts with _current_folder.
		if _current_folder != "":
			if not png_path.get_base_dir().begins_with(_current_folder):
				continue
		# Search filter.
		if filter != "" and png_path.to_lower().find(filter) < 0:
			continue
		var display: String = png_path.get_file()
		if _current_folder == "":
			# Show relative path when browsing "all".
			display = png_path
		_file_list.add_item(display)
		_file_list.set_item_metadata(_file_list.item_count - 1, png_path)
		added += 1
		if added >= _MAX_FILE_LIST:
			_file_list.add_item("… (%d+ results, narrow your search)" % _MAX_FILE_LIST)
			break


func _on_search_changed(_text: String) -> void:
	_populate_file_list()


func _on_file_selected(idx: int) -> void:
	if idx < 0 or idx >= _file_list.item_count:
		return
	var rel_path: String = _file_list.get_item_metadata(idx)
	var abs_root: String = ProjectSettings.globalize_path(RAW_ROOT)
	var abs_path: String = abs_root + "/" + rel_path
	_preview_path = rel_path
	_preview_label.text = "Preview: %s" % rel_path

	# Load image directly from disk (bypassing Godot import).
	var img := Image.new()
	var err := img.load(abs_path)
	if err != OK:
		_status_label.text = "Failed to load image: %s" % abs_path
		_image_preview.texture = null
		return
	var tex := ImageTexture.create_from_image(img)
	_image_preview.texture = tex

	# Pre-fill filename.
	_filename_edit.text = rel_path.get_file()
	_status_label.text = "%d × %d px" % [img.get_width(), img.get_height()]


# ─── Import controls ──────────────────────────────────────────────────

func _on_dest_changed(idx: int) -> void:
	var label: String = _dest_option.get_item_text(idx)
	_dest_custom_edit.visible = (label == "(custom)")
	_dest_custom_edit.get_parent().visible = (label == "(custom)")


func _on_import() -> void:
	if _preview_path == "":
		_status_label.text = "Select a file first."
		return
	var filename: String = _filename_edit.text.strip_edges()
	if filename == "":
		_status_label.text = "Enter a filename."
		return

	# Determine destination subfolder.
	var dest_sub: String
	var selected_text: String = _dest_option.get_item_text(_dest_option.selected)
	if selected_text == "(custom)":
		dest_sub = _dest_custom_edit.text.strip_edges()
		if dest_sub == "":
			_status_label.text = "Enter a custom destination path."
			return
	else:
		dest_sub = selected_text

	# Sanitize: no leading slashes, no ".." path traversal.
	dest_sub = dest_sub.strip_edges().trim_prefix("/").trim_suffix("/")
	if dest_sub.find("..") >= 0:
		_status_label.text = "Invalid path (no '..' allowed)."
		return

	var src_abs: String = ProjectSettings.globalize_path(RAW_ROOT) + "/" + _preview_path
	var dst_res: String = ASSETS_ROOT + "/" + dest_sub + "/" + filename
	var dst_abs: String = ProjectSettings.globalize_path(dst_res)

	# Ensure destination directory exists.
	var dst_dir: String = dst_abs.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dst_dir)

	# Check if file already exists.
	if FileAccess.file_exists(dst_res):
		_status_label.text = "Already exists: %s — rename to overwrite." % dst_res
		return

	# Copy the file, optionally converting magenta to transparent.
	var img := Image.new()
	var load_err := img.load(src_abs)
	if load_err != OK:
		_status_label.text = "Cannot read image: %s" % src_abs
		return

	if _magenta_check.button_pressed:
		_strip_magenta(img)

	img.save_png(dst_abs)

	_status_label.text = "Imported → %s" % dst_res


# ─── Contract (sub-editor interface) ──────────────────────────────────

func on_atlas_cell_clicked(_cell: Vector2i) -> void:
	pass  # Atlas clicks not used by the browser.


func get_marks() -> Array:
	return []  # No marks for browsing.


func save() -> void:
	pass  # Nothing to persist.


func revert() -> void:
	pass


func is_dirty() -> bool:
	return false


# ─── Helpers ───────────────────────────────────────────────────────────

## Replace magenta and near-magenta pixels with fully transparent.
## "Near magenta" = high red, low green, high blue (hue ≈ 300°, high sat).
const _MAGENTA_THRESHOLD := 0.15  ## Max green channel for near-magenta.
const _MAGENTA_MIN_RB := 0.75     ## Min red & blue for near-magenta.

func _strip_magenta(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			if c.r >= _MAGENTA_MIN_RB and c.g <= _MAGENTA_THRESHOLD and c.b >= _MAGENTA_MIN_RB:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


func _section(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	return lbl


func _label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl
