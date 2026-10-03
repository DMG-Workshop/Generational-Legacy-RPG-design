## Tests for heir inventory, equipment, and crafting integration
##
## Tests: heir inventory operations, equipment equipping, stat bonuses, crafting skills

extends GutTest


var heir: Heir
var heir_inventory: HeirInventory
var heir_equipment: HeirEquipment
var heir_crafting: HeirCrafting


func before_each() -> void:
	heir = Heir.new()
	heir.name = "Test Heir"
	heir.generation = 1
	heir.class_id = "warrior"

	heir_inventory = HeirInventory.new(heir)
	heir_equipment = HeirEquipment.new(heir)
	heir_crafting = HeirCrafting.new(heir)


## Test: Create heir
func test_create_heir() -> void:
	assert_eq(heir.name, "Test Heir")
	assert_eq(heir.generation, 1)
	assert_eq(heir.class_id, "warrior")


## Test: Add item to inventory
func test_add_item_to_inventory() -> void:
	var item = Item.new("sword_1", "Iron Sword", Item.ItemType.WEAPON)

	heir_inventory.add_item(item)

	assert_eq(heir_inventory.get_total_count(), 1)
	assert_true(item in heir.inventory)


## Test: Remove item from inventory
func test_remove_item_from_inventory() -> void:
	var item = Item.new("sword_1", "Iron Sword", Item.ItemType.WEAPON)
	heir_inventory.add_item(item)

	var removed = heir_inventory.remove_item(item)

	assert_true(removed)
	assert_eq(heir_inventory.get_total_count(), 0)


## Test: Get item count by ID
func test_get_item_count() -> void:
	var item1 = Item.new("potion", "Health Potion", Item.ItemType.CONSUMABLE)
	var item2 = Item.new("potion", "Health Potion", Item.ItemType.CONSUMABLE)

	heir_inventory.add_item(item1)
	heir_inventory.add_item(item2)

	assert_eq(heir_inventory.get_item_count("potion"), 2)


## Test: Get items by type
func test_get_items_by_type() -> void:
	var weapon = Item.new("sword", "Sword", Item.ItemType.WEAPON)
	var armor = Item.new("chest", "Chest Plate", Item.ItemType.ARMOR)
	var potion = Item.new("potion", "Potion", Item.ItemType.CONSUMABLE)

	heir_inventory.add_item(weapon)
	heir_inventory.add_item(armor)
	heir_inventory.add_item(potion)

	assert_eq(heir_inventory.get_weapons().size(), 1)
	assert_eq(heir_inventory.get_armor().size(), 1)
	assert_eq(heir_inventory.get_consumables().size(), 1)


## Test: Sort inventory by rarity
func test_sort_inventory_by_rarity() -> void:
	var common = Item.new("item1", "Item", Item.ItemType.WEAPON, Item.Rarity.COMMON)
	var rare = Item.new("item2", "Rare Item", Item.ItemType.WEAPON, Item.Rarity.RARE)
	var uncommon = Item.new("item3", "Uncommon Item", Item.ItemType.WEAPON, Item.Rarity.UNCOMMON)

	heir_inventory.add_item(common)
	heir_inventory.add_item(rare)
	heir_inventory.add_item(uncommon)

	heir_inventory.sort_by_rarity()

	assert_eq(heir.inventory[0].rarity, Item.Rarity.RARE)
	assert_eq(heir.inventory[1].rarity, Item.Rarity.UNCOMMON)
	assert_eq(heir.inventory[2].rarity, Item.Rarity.COMMON)


## Test: Get inventory summary
func test_inventory_summary() -> void:
	var weapon = Item.new("sword", "Sword", Item.ItemType.WEAPON)
	var armor = Item.new("chest", "Chest", Item.ItemType.ARMOR)

	heir_inventory.add_item(weapon)
	heir_inventory.add_item(armor)

	var summary = heir_inventory.get_summary()

	assert_true("1 weapons" in summary)
	assert_true("1 armor" in summary)


## Test: Equip item
func test_equip_item() -> void:
	var weapon = Equipment.new("sword", "Iron Sword", Equipment.EquipmentSlot.MAIN_HAND)

	var success = heir_equipment.equip_item(weapon, Equipment.EquipmentSlot.MAIN_HAND)

	assert_true(success)
	assert_eq(heir_equipment.get_equipped(Equipment.EquipmentSlot.MAIN_HAND), weapon)


## Test: Unequip item
func test_unequip_item() -> void:
	var weapon = Equipment.new("sword", "Iron Sword", Equipment.EquipmentSlot.MAIN_HAND)
	heir_equipment.equip_item(weapon, Equipment.EquipmentSlot.MAIN_HAND)

	var unequipped = heir_equipment.unequip_item(Equipment.EquipmentSlot.MAIN_HAND)

	assert_eq(unequipped, weapon)
	assert_null(heir_equipment.get_equipped(Equipment.EquipmentSlot.MAIN_HAND))


## Test: Check if slot is filled
func test_is_slot_filled() -> void:
	var weapon = Equipment.new("sword", "Iron Sword", Equipment.EquipmentSlot.MAIN_HAND)

	assert_false(heir_equipment.is_slot_filled(Equipment.EquipmentSlot.MAIN_HAND))

	heir_equipment.equip_item(weapon, Equipment.EquipmentSlot.MAIN_HAND)

	assert_true(heir_equipment.is_slot_filled(Equipment.EquipmentSlot.MAIN_HAND))


## Test: Equipment stat bonuses
func test_equipment_stat_bonuses() -> void:
	var weapon = Equipment.new("sword", "Iron Sword", Equipment.EquipmentSlot.MAIN_HAND)
	weapon.add_stat_bonus("strength", 5)

	var armor = Equipment.new("chest", "Chest Plate", Equipment.EquipmentSlot.CHEST)
	armor.add_stat_bonus("constitution", 3)

	heir_equipment.equip_item(weapon, Equipment.EquipmentSlot.MAIN_HAND)
	heir_equipment.equip_item(armor, Equipment.EquipmentSlot.CHEST)

	var bonuses = heir_equipment.get_total_stat_bonuses()

	assert_eq(bonuses["strength"], 5)
	assert_eq(bonuses["constitution"], 3)


## Test: Equipment resistances
func test_equipment_resistances() -> void:
	var armor = Equipment.new("chest", "Chest Plate", Equipment.EquipmentSlot.CHEST)
	armor.add_resistance("fire", 25)
	armor.add_resistance("cold", 15)

	heir_equipment.equip_item(armor, Equipment.EquipmentSlot.CHEST)

	var resistances = heir_equipment.get_total_resistances()

	assert_eq(resistances["fire"], 25)
	assert_eq(resistances["cold"], 15)


## Test: Resistance stacking (capped at 100)
func test_resistance_stacking() -> void:
	var armor1 = Equipment.new("chest1", "Armor 1", Equipment.EquipmentSlot.CHEST)
	armor1.add_resistance("fire", 80)

	var armor2 = Equipment.new("neck", "Amulet", Equipment.EquipmentSlot.NECK)
	armor2.add_resistance("fire", 50)

	heir_equipment.equip_item(armor1, Equipment.EquipmentSlot.CHEST)
	heir_equipment.equip_item(armor2, Equipment.EquipmentSlot.NECK)

	var resistances = heir_equipment.get_total_resistances()

	# Should cap at 100
	assert_eq(resistances["fire"], 100)


## Test: Get equipment summary
func test_equipment_summary() -> void:
	var weapon = Equipment.new("sword", "Sword", Equipment.EquipmentSlot.MAIN_HAND)
	weapon.add_stat_bonus("strength", 3)

	heir_equipment.equip_item(weapon, Equipment.EquipmentSlot.MAIN_HAND)

	var summary = heir_equipment.get_summary()

	assert_true("1 items equipped" in summary)
	assert_true("+3 total stat bonus" in summary)


## Test: Initialize crafting skills
func test_initialize_crafting_skills() -> void:
	heir.initialize_crafting_skills()

	assert_gt(heir.crafting_skills.size(), 0)
	var blacksmith = heir.crafting_skills.get(CraftingSkill.SkillType.BLACKSMITHING)
	assert_not_null(blacksmith)
	assert_eq(blacksmith.level, 1)


## Test: Get crafting skill
func test_get_crafting_skill() -> void:
	heir.initialize_crafting_skills()

	var skill = heir_crafting.get_skill(CraftingSkill.SkillType.BLACKSMITHING)

	assert_not_null(skill)
	assert_eq(skill.skill_name, "Blacksmithing")


## Test: Get all crafting skills
func test_get_all_crafting_skills() -> void:
	heir.initialize_crafting_skills()

	var skills = heir_crafting.get_all_skills()

	assert_gt(skills.size(), 0)


## Test: Check can craft recipe
func test_can_craft_recipe() -> void:
	heir.initialize_crafting_skills()

	var recipe = Recipe.new("iron_sword", "iron_sword", CraftingSkill.SkillType.BLACKSMITHING, 1)
	recipe.add_ingredient("iron_ore", 5)

	# Add materials to inventory
	for i in range(5):
		var ore = Item.new("iron_ore", "Iron Ore", Item.ItemType.CRAFTING_MATERIAL)
		heir_inventory.add_item(ore)

	# Should be able to craft (level 1, have materials)
	assert_true(heir_crafting.can_craft_recipe(recipe))


## Test: Cannot craft recipe (insufficient level)
func test_cannot_craft_recipe_low_level() -> void:
	heir.initialize_crafting_skills()

	var recipe = Recipe.new("legendary_sword", "legendary_sword", CraftingSkill.SkillType.BLACKSMITHING, 50)
	recipe.add_ingredient("steel_bar", 10)

	# Should not be able to craft (need level 50, only have 1)
	assert_false(heir_crafting.can_craft_recipe(recipe))


## Test: Cannot craft recipe (missing materials)
func test_cannot_craft_recipe_missing_materials() -> void:
	heir.initialize_crafting_skills()

	var recipe = Recipe.new("iron_sword", "iron_sword", CraftingSkill.SkillType.BLACKSMITHING, 1)
	recipe.add_ingredient("iron_ore", 5)

	# Should not be able to craft (no materials)
	assert_false(heir_crafting.can_craft_recipe(recipe))


## Test: Add skill XP
func test_add_skill_xp() -> void:
	heir.initialize_crafting_skills()

	var result = heir_crafting.add_skill_xp(CraftingSkill.SkillType.BLACKSMITHING, 100)

	var skill = heir_crafting.get_skill(CraftingSkill.SkillType.BLACKSMITHING)
	assert_eq(skill.level, 2)  # Should have leveled up from 100 XP


## Test: Get total XP
func test_get_total_xp() -> void:
	heir.initialize_crafting_skills()

	heir_crafting.add_skill_xp(CraftingSkill.SkillType.BLACKSMITHING, 50)
	heir_crafting.add_skill_xp(CraftingSkill.SkillType.ALCHEMY, 30)

	var total = heir_crafting.get_total_xp()

	assert_eq(total, 80)


## Test: Get crafting summary
func test_crafting_summary() -> void:
	heir.initialize_crafting_skills()

	var summary = heir_crafting.get_summary()

	assert_true("Crafting" in summary)
	assert_true("skills" in summary)


## Test: Equip non-equipment item fails
func test_equip_non_equipment_fails() -> void:
	var potion = Item.new("potion", "Potion", Item.ItemType.CONSUMABLE)

	var success = heir_equipment.equip_item(potion, Equipment.EquipmentSlot.MAIN_HAND)

	assert_false(success)


## Test: Class restriction check
func test_class_restriction_check() -> void:
	heir.class_id = "warrior"

	var weapon = Equipment.new("mage_staff", "Mage Staff", Equipment.EquipmentSlot.MAIN_HAND)
	weapon.allowed_classes = ["mage", "wizard"]

	var success = heir_equipment.equip_item(weapon, Equipment.EquipmentSlot.MAIN_HAND)

	assert_false(success)


## Test: Get heir stat bonuses from equipment
func test_heir_get_stat_bonuses() -> void:
	var weapon = Equipment.new("sword", "Sword", Equipment.EquipmentSlot.MAIN_HAND)
	weapon.add_stat_bonus("strength", 5)

	heir_equipment.equip_item(weapon, Equipment.EquipmentSlot.MAIN_HAND)

	var bonuses = heir.get_equipment_stat_bonuses()

	assert_eq(bonuses["strength"], 5)


## Test: Get heir resistances from equipment
func test_heir_get_resistances() -> void:
	var armor = Equipment.new("chest", "Armor", Equipment.EquipmentSlot.CHEST)
	armor.add_resistance("fire", 25)

	heir_equipment.equip_item(armor, Equipment.EquipmentSlot.CHEST)

	var resistances = heir.get_equipment_resistances()

	assert_eq(resistances["fire"], 25)


## Test: Get equipped items
func test_get_equipped_items() -> void:
	var weapon = Equipment.new("sword", "Sword", Equipment.EquipmentSlot.MAIN_HAND)
	var armor = Equipment.new("chest", "Chest", Equipment.EquipmentSlot.CHEST)

	heir_equipment.equip_item(weapon, Equipment.EquipmentSlot.MAIN_HAND)
	heir_equipment.equip_item(armor, Equipment.EquipmentSlot.CHEST)

	var equipped = heir.get_equipped_items()

	assert_eq(equipped.size(), 2)


## Test: Initialize skill tree
func test_initialize_skill_tree() -> void:
	heir.initialize_skill_tree()

	assert_not_null(heir.skill_tree)
	assert_true(heir.skill_tree.skills.size() > 0)


## Test: Get equipment slot name
func test_get_slot_name() -> void:
	var slot_name = heir_equipment.get_slot_name(Equipment.EquipmentSlot.MAIN_HAND)
	assert_eq(slot_name, "Main Hand")

	slot_name = heir_equipment.get_slot_name(Equipment.EquipmentSlot.CHEST)
	assert_eq(slot_name, "Chest")


## Test: Clear equipment
func test_clear_equipment() -> void:
	var weapon = Equipment.new("sword", "Sword", Equipment.EquipmentSlot.MAIN_HAND)
	heir_equipment.equip_item(weapon, Equipment.EquipmentSlot.MAIN_HAND)

	heir_equipment.clear()

	assert_eq(heir_equipment.get_all_equipped().size(), 0)


## Test: Clear inventory
func test_clear_inventory() -> void:
	var item = Item.new("item", "Item", Item.ItemType.WEAPON)
	heir_inventory.add_item(item)

	heir_inventory.clear()

	assert_eq(heir_inventory.get_total_count(), 0)


## Test: Find item by ID
func test_find_item_by_id() -> void:
	var item1 = Item.new("sword", "Sword 1", Item.ItemType.WEAPON)
	var item2 = Item.new("shield", "Shield", Item.ItemType.ARMOR)

	heir_inventory.add_item(item1)
	heir_inventory.add_item(item2)

	var found = heir_inventory.find_item("sword")

	assert_eq(found.item_id, "sword")


## Test: Item not found returns null
func test_find_item_not_found() -> void:
	var found = heir_inventory.find_item("nonexistent")

	assert_null(found)
