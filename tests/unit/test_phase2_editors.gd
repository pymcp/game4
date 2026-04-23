## Tests for Phase 2 editors: LootTable, Crafting, ArmorSet, Biome.
extends GutTest


var _loot_backup: Dictionary = {}
var _crafting_backup: Dictionary = {}
var _armor_backup: Dictionary = {}
var _biome_backup: Dictionary = {}


func before_all() -> void:
	LootTableRegistry.reset()
	_loot_backup = LootTableRegistry.get_raw_data().duplicate(true)
	CraftingRegistry.reset()
	_crafting_backup = CraftingRegistry.get_raw_data().duplicate(true)
	ArmorSetRegistry.reset()
	_armor_backup = ArmorSetRegistry.get_raw_data().duplicate(true)
	BiomeRegistry.reset()
	_biome_backup = BiomeRegistry.get_raw_data().duplicate(true)


func before_each() -> void:
	LootTableRegistry.reset()
	CraftingRegistry.reset()
	ArmorSetRegistry.reset()
	BiomeRegistry.reset()


func after_all() -> void:
	LootTableRegistry.save_data(_loot_backup)
	LootTableRegistry.reset()
	CraftingRegistry.save_data(_crafting_backup)
	CraftingRegistry.reset()
	ArmorSetRegistry.save_data(_armor_backup)
	ArmorSetRegistry.reset()
	BiomeRegistry.save_data(_biome_backup)
	BiomeRegistry.reset()


# ═══════════════════════════════════════════════════════════════════════
#  LootTableEditor
# ═══════════════════════════════════════════════════════════════════════

func test_loot_table_editor_loads_data() -> void:
	var editor := LootTableEditor.new()
	add_child_autofree(editor)
	assert_true(editor._data.size() > 0, "should load loot table data")
	assert_false(editor.is_dirty(), "should start clean")


func test_loot_table_editor_add_creature() -> void:
	var editor := LootTableEditor.new()
	add_child_autofree(editor)
	var before: int = editor._data.size()
	editor._on_add()
	assert_eq(editor._data.size(), before + 1, "one new creature added")
	assert_true(editor.is_dirty(), "should be dirty after add")


func test_loot_table_editor_delete_creature() -> void:
	var editor := LootTableEditor.new()
	add_child_autofree(editor)
	editor._on_add()
	var before: int = editor._data.size()
	# Select the new entry and delete it.
	editor._on_delete()
	assert_eq(editor._data.size(), before - 1, "one creature removed")


func test_loot_table_editor_save_revert() -> void:
	var editor := LootTableEditor.new()
	add_child_autofree(editor)
	editor._on_add()
	assert_true(editor.is_dirty())
	editor.save()
	assert_false(editor.is_dirty(), "clean after save")
	editor._on_add()
	assert_true(editor.is_dirty())
	editor.revert()
	assert_false(editor.is_dirty(), "clean after revert")


func test_loot_table_editor_get_marks_returns_array() -> void:
	var editor := LootTableEditor.new()
	add_child_autofree(editor)
	var marks: Array = editor.get_marks()
	assert_typeof(marks, TYPE_ARRAY, "get_marks should return Array")


func test_loot_table_editor_on_atlas_cell_clicked_no_crash() -> void:
	var editor := LootTableEditor.new()
	add_child_autofree(editor)
	editor.on_atlas_cell_clicked(Vector2i(3, 4))
	assert_true(true, "no crash on atlas cell click")


# ═══════════════════════════════════════════════════════════════════════
#  CraftingEditor
# ═══════════════════════════════════════════════════════════════════════

func test_crafting_editor_loads_data() -> void:
	var editor := CraftingEditor.new()
	add_child_autofree(editor)
	assert_true(editor._data.size() > 0, "should load crafting data")
	assert_false(editor.is_dirty(), "should start clean")


func test_crafting_editor_add_recipe() -> void:
	var editor := CraftingEditor.new()
	add_child_autofree(editor)
	var before: int = editor._data.size()
	editor._on_add()
	assert_eq(editor._data.size(), before + 1, "one new recipe added")
	assert_true(editor.is_dirty())


func test_crafting_editor_delete_recipe() -> void:
	var editor := CraftingEditor.new()
	add_child_autofree(editor)
	editor._on_add()
	var before: int = editor._data.size()
	editor._on_delete()
	assert_eq(editor._data.size(), before - 1)


func test_crafting_editor_save_revert() -> void:
	var editor := CraftingEditor.new()
	add_child_autofree(editor)
	editor._on_add()
	assert_true(editor.is_dirty())
	editor.save()
	assert_false(editor.is_dirty(), "clean after save")
	editor._on_add()
	assert_true(editor.is_dirty())
	editor.revert()
	assert_false(editor.is_dirty(), "clean after revert")


func test_crafting_editor_get_marks_returns_array() -> void:
	var editor := CraftingEditor.new()
	add_child_autofree(editor)
	assert_typeof(editor.get_marks(), TYPE_ARRAY)


func test_crafting_editor_on_atlas_cell_clicked_no_crash() -> void:
	var editor := CraftingEditor.new()
	add_child_autofree(editor)
	editor.on_atlas_cell_clicked(Vector2i(1, 2))
	assert_true(true, "no crash")


# ═══════════════════════════════════════════════════════════════════════
#  ArmorSetEditor
# ═══════════════════════════════════════════════════════════════════════

func test_armor_set_editor_loads_data() -> void:
	var editor := ArmorSetEditor.new()
	add_child_autofree(editor)
	assert_true(editor._data.size() > 0, "should load armor set data")
	assert_false(editor.is_dirty())


func test_armor_set_editor_add_set() -> void:
	var editor := ArmorSetEditor.new()
	add_child_autofree(editor)
	var before: int = editor._data.size()
	editor._on_add()
	assert_eq(editor._data.size(), before + 1, "one new set added")
	assert_true(editor.is_dirty())


func test_armor_set_editor_delete_set() -> void:
	var editor := ArmorSetEditor.new()
	add_child_autofree(editor)
	editor._on_add()
	var before: int = editor._data.size()
	editor._on_delete()
	assert_eq(editor._data.size(), before - 1)


func test_armor_set_editor_save_revert() -> void:
	var editor := ArmorSetEditor.new()
	add_child_autofree(editor)
	editor._on_add()
	assert_true(editor.is_dirty())
	editor.save()
	assert_false(editor.is_dirty(), "clean after save")
	editor._on_add()
	assert_true(editor.is_dirty())
	editor.revert()
	assert_false(editor.is_dirty(), "clean after revert")


func test_armor_set_editor_get_marks_returns_array() -> void:
	var editor := ArmorSetEditor.new()
	add_child_autofree(editor)
	assert_typeof(editor.get_marks(), TYPE_ARRAY)


func test_armor_set_editor_on_atlas_cell_clicked_no_crash() -> void:
	var editor := ArmorSetEditor.new()
	add_child_autofree(editor)
	editor.on_atlas_cell_clicked(Vector2i(0, 0))
	assert_true(true, "no crash")


# ═══════════════════════════════════════════════════════════════════════
#  BiomeEditor
# ═══════════════════════════════════════════════════════════════════════

func test_biome_editor_loads_data() -> void:
	var editor := BiomeEditor.new()
	add_child_autofree(editor)
	assert_true(editor._data.size() > 0, "should load biome data")
	assert_false(editor.is_dirty())


func test_biome_editor_add_biome() -> void:
	var editor := BiomeEditor.new()
	add_child_autofree(editor)
	var before: int = editor._data.size()
	editor._on_add()
	assert_eq(editor._data.size(), before + 1, "one new biome added")
	assert_true(editor.is_dirty())


func test_biome_editor_delete_biome() -> void:
	var editor := BiomeEditor.new()
	add_child_autofree(editor)
	editor._on_add()
	var before: int = editor._data.size()
	editor._on_delete()
	assert_eq(editor._data.size(), before - 1)


func test_biome_editor_save_revert() -> void:
	var editor := BiomeEditor.new()
	add_child_autofree(editor)
	editor._on_add()
	assert_true(editor.is_dirty())
	editor.save()
	assert_false(editor.is_dirty(), "clean after save")
	editor._on_add()
	assert_true(editor.is_dirty())
	editor.revert()
	assert_false(editor.is_dirty(), "clean after revert")


func test_biome_editor_set_field() -> void:
	var editor := BiomeEditor.new()
	add_child_autofree(editor)
	# Select first biome and modify a field.
	if editor._biome_list.item_count > 0:
		editor._biome_list.select(0)
		editor._on_biome_selected(0)
		var id: String = editor._selected_id
		editor._set_field("npc_density", 0.05)
		assert_eq(editor._data[id]["npc_density"], 0.05, "field updated")
		assert_true(editor.is_dirty())


func test_biome_editor_npc_kinds_add_remove() -> void:
	var editor := BiomeEditor.new()
	add_child_autofree(editor)
	if editor._biome_list.item_count > 0:
		editor._biome_list.select(0)
		editor._on_biome_selected(0)
		var id: String = editor._selected_id
		var before: int = editor._data[id].get("npc_kinds", []).size()
		editor._on_add_npc_kind()
		assert_eq(editor._data[id]["npc_kinds"].size(), before + 1)
		editor._on_remove_npc_kind(editor._data[id]["npc_kinds"].size() - 1)
		assert_eq(editor._data[id]["npc_kinds"].size(), before)


func test_biome_editor_decoration_add_remove() -> void:
	var editor := BiomeEditor.new()
	add_child_autofree(editor)
	if editor._biome_list.item_count > 0:
		editor._biome_list.select(0)
		editor._on_biome_selected(0)
		var id: String = editor._selected_id
		var before: int = editor._data[id].get("decoration_weights", {}).size()
		editor._on_add_decoration()
		assert_eq(editor._data[id]["decoration_weights"].size(), before + 1)


func test_biome_editor_get_marks_returns_array() -> void:
	var editor := BiomeEditor.new()
	add_child_autofree(editor)
	assert_typeof(editor.get_marks(), TYPE_ARRAY)


func test_biome_editor_on_atlas_cell_clicked_no_crash() -> void:
	var editor := BiomeEditor.new()
	add_child_autofree(editor)
	editor.on_atlas_cell_clicked(Vector2i(2, 3))
	assert_true(true, "no crash")
