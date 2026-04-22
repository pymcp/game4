## Tests for ArmorAtlas, take_hit defense, and armor sprite wiring.
extends GutTest


# --- ArmorAtlas ---------------------------------------------------

func test_armor_returns_valid_cell() -> void:
	var cell: Vector2i = ArmorAtlas.cell_for(&"armor")
	assert_ne(cell, Vector2i(-1, -1), "armor should have an atlas cell")


func test_helmet_returns_valid_cell() -> void:
	var cell: Vector2i = ArmorAtlas.cell_for(&"helmet")
	assert_ne(cell, Vector2i(-1, -1), "helmet should have an atlas cell")


func test_boots_placeholder_returns_no_cell() -> void:
	var cell: Vector2i = ArmorAtlas.cell_for(&"boots")
	assert_eq(cell, Vector2i(-1, -1), "boots should be placeholder (-1,-1)")


func test_unknown_item_returns_no_cell() -> void:
	var cell: Vector2i = ArmorAtlas.cell_for(&"wood")
	assert_eq(cell, Vector2i(-1, -1), "materials should have no armor cell")


func test_empty_id_returns_no_cell() -> void:
	var cell: Vector2i = ArmorAtlas.cell_for(&"")
	assert_eq(cell, Vector2i(-1, -1))


func test_region_for_armor() -> void:
	var r: Rect2 = ArmorAtlas.region_for(&"armor")
	assert_gt(r.size.x, 0.0, "armor region should have positive width")
	assert_eq(int(r.size.x), 16, "armor region should be 16px wide")
	assert_eq(int(r.size.y), 16, "armor region should be 16px tall")


func test_region_for_unknown() -> void:
	var r: Rect2 = ArmorAtlas.region_for(&"stone")
	assert_eq(r.size, Vector2.ZERO, "unknown items should return empty region")


func test_tint_default_is_white() -> void:
	var tint: Color = ArmorAtlas.tint_for(&"armor")
	assert_eq(tint, Color(1, 1, 1), "default armor tint should be white")


func test_tint_unknown_is_white() -> void:
	var tint: Color = ArmorAtlas.tint_for(&"wood")
	assert_eq(tint, Color(1, 1, 1), "unknown item tint should be white")


func test_lookup_armor_has_cell_and_tint() -> void:
	var info: Dictionary = ArmorAtlas.lookup(&"armor")
	assert_has(info, "cell")
	assert_has(info, "tint")


# --- take_hit & armor defense ------------------------------------

func test_take_hit_no_armor() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	player.health = 10
	player.max_health = 10
	player.take_hit(3)
	assert_eq(player.health, 7, "3 damage with no armor = 7 health")


func test_take_hit_with_armor() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	player.health = 10
	player.max_health = 10
	# Equip body armor (power=3) to reduce damage.
	player.equipment.equip(ItemDefinition.Slot.BODY, &"armor")
	player.take_hit(5)
	# effective = max(1, 5-3) = 2
	assert_eq(player.health, 8, "5 damage minus 3 armor = 2 effective")


func test_take_hit_minimum_one_damage() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	player.health = 10
	player.max_health = 10
	# Equip body armor (power=3) + helmet (power=2) = 5 defense.
	player.equipment.equip(ItemDefinition.Slot.BODY, &"armor")
	player.equipment.equip(ItemDefinition.Slot.HEAD, &"helmet")
	player.take_hit(2)
	# effective = max(1, 2-5) = 1
	assert_eq(player.health, 9, "2 damage minus 5 defense should still deal 1")


func test_take_hit_full_stack() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	player.health = 10
	player.max_health = 10
	# All three armor slots: body(3) + head(2) + feet(1) = 6.
	# Plus leather set 3pc bonus: +1 defense = 7 total.
	player.equipment.equip(ItemDefinition.Slot.BODY, &"armor")
	player.equipment.equip(ItemDefinition.Slot.HEAD, &"helmet")
	player.equipment.equip(ItemDefinition.Slot.FEET, &"boots")
	player.take_hit(10)
	# effective = max(1, 10-7) = 3
	assert_eq(player.health, 7, "10 damage minus 7 defense = 3 effective")


func test_take_hit_no_damage_when_dead() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	player.health = 0
	player.take_hit(5)
	assert_eq(player.health, 0, "no further damage when already at 0 hp")


func test_take_hit_floors_at_zero() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	player.health = 2
	player.max_health = 10
	player.take_hit(10)
	assert_eq(player.health, 0, "health should not go below 0")


func test_armor_defense_empty_equipment() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	assert_eq(player._armor_defense(), 0, "no equipment = 0 defense")


func test_armor_defense_only_counts_armor_slots() -> void:
	var player := PlayerController.new()
	add_child_autofree(player)
	# Weapon has power but should NOT count as defense.
	player.equipment.equip(ItemDefinition.Slot.WEAPON, &"sword")
	assert_eq(player._armor_defense(), 0, "weapon power should not be defense")
