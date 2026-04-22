## Tests for Phase 6: Editor Enhancement + Loot Pickup
extends GutTest


var _backup: Dictionary = {}


func before_all() -> void:
	ItemRegistry.reset()
	_backup = ItemRegistry.get_raw_data().duplicate(true)


func before_each() -> void:
	ItemRegistry.reset()


func after_all() -> void:
	ItemRegistry.save_data(_backup)
	ItemRegistry.reset()


# --- ItemEditor CRUD ------------------------------------------------

func test_item_editor_creates_and_loads() -> void:
	var editor := ItemEditor.new()
	add_child_autofree(editor)
	assert_true(editor._items.size() >= 42, "should load items from registry")


func test_item_editor_add_item() -> void:
	var editor := ItemEditor.new()
	add_child_autofree(editor)
	var before: int = editor._items.size()
	editor._on_add_item()
	assert_eq(editor._items.size(), before + 1, "one new item added")
	assert_true(editor._items.has("new_item"), "default id is new_item")


func test_item_editor_delete_item() -> void:
	var editor := ItemEditor.new()
	add_child_autofree(editor)
	# Add and then delete.
	editor._on_add_item()
	var before: int = editor._items.size()
	editor.select_item(&"new_item")
	editor._on_delete_item()
	assert_eq(editor._items.size(), before - 1)


func test_item_editor_rename_item() -> void:
	var editor := ItemEditor.new()
	add_child_autofree(editor)
	editor._on_add_item()
	editor.select_item(&"new_item")
	editor._id_edit.text = "renamed_item"
	editor._id_edit.editable = true
	editor._on_rename_item()
	assert_true(editor._items.has("renamed_item"), "renamed entry exists")
	assert_false(editor._items.has("new_item"), "old entry removed")


func test_item_editor_rename_updates_parent_refs() -> void:
	var editor := ItemEditor.new()
	add_child_autofree(editor)
	editor._on_add_item()
	# Make another item that inherits from new_item.
	var data: Dictionary = editor._items
	data["child_item"] = {"display_name": "Child", "parent": "new_item"}
	editor.select_item(&"new_item")
	editor._id_edit.text = "base_item"
	editor._on_rename_item()
	assert_eq(data["child_item"]["parent"], "base_item")


# --- ItemEditor property editing ----------------------------------

func test_set_field_updates_data() -> void:
	var editor := ItemEditor.new()
	add_child_autofree(editor)
	editor.select_item(&"sword")
	editor._set_field("power", 99)
	assert_eq(editor._items["sword"]["power"], 99)
	assert_true(editor.is_dirty())


func test_parent_selector_populated() -> void:
	var editor := ItemEditor.new()
	add_child_autofree(editor)
	editor.select_item(&"sword")
	# Parent opt should have (none) + all items except sword.
	assert_true(editor._parent_opt.item_count >= 42,
		"parent dropdown has entries")


func test_stat_bonus_edit() -> void:
	var editor := ItemEditor.new()
	add_child_autofree(editor)
	editor.select_item(&"sword")
	editor._on_stat_bonus_changed(&"strength", 5)
	var bonuses: Dictionary = editor._items["sword"].get("stat_bonuses", {})
	assert_eq(int(bonuses.get("strength", 0)), 5)


func test_stat_bonus_zero_removes() -> void:
	var editor := ItemEditor.new()
	add_child_autofree(editor)
	editor.select_item(&"sword")
	editor._on_stat_bonus_changed(&"strength", 5)
	editor._on_stat_bonus_changed(&"strength", 0)
	var bonuses: Dictionary = editor._items["sword"].get("stat_bonuses", {})
	assert_false(bonuses.has("strength"), "0 bonus should be erased")


# --- ItemEditor save flow -----------------------------------------

func test_save_writes_to_registry() -> void:
	var editor := ItemEditor.new()
	add_child_autofree(editor)
	editor._on_add_item()
	editor._items["new_item"]["display_name"] = "Test Save Item"
	editor.save()
	ItemRegistry.reset()
	assert_true(ItemRegistry.has_item(&"new_item"))
	var def: ItemDefinition = ItemRegistry.get_item(&"new_item")
	assert_eq(def.display_name, "Test Save Item")
	# Clean up: remove the test item.
	var data: Dictionary = ItemRegistry.get_raw_data()
	data.erase("new_item")
	ItemRegistry.save_data(data)


# --- ItemEditor balance table ------------------------------------

func test_balance_table_has_columns() -> void:
	var editor := ItemEditor.new()
	add_child_autofree(editor)
	assert_eq(ItemEditor._TABLE_COLS.size(), 12)


# --- LootPickup bob animation ------------------------------------

func test_loot_pickup_has_bob_constants() -> void:
	assert_eq(LootPickup._BOB_AMP_PX, 2.0)
	assert_eq(LootPickup._BOB_HZ, 1.0)


# --- LootPickup equipment sprite fallback -------------------------

func test_equipment_sprite_for_sword() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"sword")
	var tex: Texture2D = LootPickup._try_equipment_sprite(def)
	assert_not_null(tex, "sword has weapon_sprite → should get atlas texture")
	assert_true(tex is AtlasTexture)


func test_equipment_sprite_for_material_returns_null() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"wood")
	var tex: Texture2D = LootPickup._try_equipment_sprite(def)
	assert_null(tex, "wood has no equipment sprites → null")


func test_equipment_sprite_null_def() -> void:
	var tex: Texture2D = LootPickup._try_equipment_sprite(null)
	assert_null(tex)


# --- Description preview generation --------------------------------

func test_generate_description_sword() -> void:
	var def: ItemDefinition = ItemRegistry.get_item(&"sword")
	var desc: String = def.generate_description()
	assert_true(desc.contains("ATK"), "sword description should contain ATK")
	assert_true(desc.contains("Melee"), "sword description should contain Melee")
