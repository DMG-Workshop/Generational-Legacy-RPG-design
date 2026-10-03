## Tests for item system (items, equipment, consumables, materials)
##
## Tests: item creation, equipment bonuses, consumables, crafting materials

extends GutTest


var item: Item
var equipment: Equipment
var consumable: Consumable
var material: CraftingMaterial
var quest_item: QuestItem


func before_each() -> void:
	item = Item.new("test_item", "Test Item")
	equipment = Equipment.new("test_eq", "Test Equipment")
	consumable = Consumable.new("test_potion", "Test Potion")
	material = CraftingMaterial.new("test_mat", "Test Material", "ore")
	quest_item = QuestItem.new("test_quest", "Test Quest Item", "quest_1")


## Test: Create basic item
func test_create_item() -> void:
	var item = Item.new("sword", "Iron Sword", Item.ItemType.WEAPON, Item.Rarity.COMMON)

	assert_eq(item.name, "Iron Sword")
	assert_eq(item.item_type, Item.ItemType.WEAPON)
	assert_eq(item.rarity, Item.Rarity.COMMON)


## Test: Item rarity names
func test_item_rarity_names() -> void:
	var item = Item.new()
	var names = {
		Item.Rarity.COMMON: "Common",
		Item.Rarity.UNCOMMON: "Uncommon",
		Item.Rarity.RARE: "Rare",
		Item.Rarity.VERY_RARE: "Very Rare",
		Item.Rarity.LEGENDARY: "Legendary"
	}

	for rarity in range(Item.Rarity.LEGENDARY + 1):
		item.rarity = rarity
		assert_eq(item.get_rarity_name(), names[rarity])


## Test: Item type names
func test_item_type_names() -> void:
	var item = Item.new()
	item.item_type = Item.ItemType.WEAPON
	assert_eq(item.get_type_name(), "Weapon")

	item.item_type = Item.ItemType.CONSUMABLE
	assert_eq(item.get_type_name(), "Consumable")


## Test: Durability system
func test_item_durability() -> void:
	var item = Item.new()
	item.max_durability = 100
	item.current_durability = 100

	assert_eq(item.get_durability_percent(), 100.0)
	assert_false(item.is_broken())
	assert_false(item.is_nearly_broken())


## Test: Damage item
func test_damage_item() -> void:
	var item = Item.new()
	item.max_durability = 100
	item.current_durability = 100

	var broken = item.damage(50)

	assert_false(broken)
	assert_eq(item.current_durability, 50)


## Test: Break item
func test_break_item() -> void:
	var item = Item.new()
	item.max_durability = 100
	item.current_durability = 30

	var broken = item.damage(50)

	assert_true(broken)
	assert_true(item.is_broken())


## Test: Repair item
func test_repair_item() -> void:
	var item = Item.new()
	item.max_durability = 100
	item.current_durability = 30

	item.repair(20)

	assert_eq(item.current_durability, 50)


## Test: Item effects
func test_item_effects() -> void:
	var item = Item.new()

	item.add_effect("fire")
	assert_true(item.has_effect("fire"))

	item.remove_effect("fire")
	assert_false(item.has_effect("fire"))


## Test: Equipment stat bonuses
func test_equipment_stat_bonus() -> void:
	var eq = Equipment.new()

	eq.add_stat_bonus("strength", 5)
	eq.add_stat_bonus("dexterity", 3)

	assert_eq(eq.stat_bonuses["strength"], 5)
	assert_eq(eq.stat_bonuses["dexterity"], 3)
	assert_eq(eq.get_total_bonus(), 8)


## Test: Equipment resistances
func test_equipment_resistances() -> void:
	var eq = Equipment.new()

	eq.add_resistance("fire", 25)
	eq.add_resistance("cold", 15)

	assert_eq(eq.resistances["fire"], 25)
	assert_eq(eq.resistances["cold"], 15)


## Test: Equipment max resistance (capped at 100)
func test_equipment_resistance_cap() -> void:
	var eq = Equipment.new()

	eq.add_resistance("fire", 80)
	eq.add_resistance("fire", 50)  # Should cap at 100

	assert_eq(eq.resistances["fire"], 100)


## Test: Equipment special abilities
func test_equipment_abilities() -> void:
	var eq = Equipment.new()

	eq.add_ability("cleave")
	eq.add_ability("parry")

	assert_eq(eq.special_abilities.size(), 2)
	assert_true("cleave" in eq.special_abilities)


## Test: Equipment slot names
func test_equipment_slot_names() -> void:
	var eq = Equipment.new()
	eq.equipment_slot = Equipment.EquipmentSlot.MAIN_HAND
	assert_eq(eq.get_slot_name(), "Main Hand")

	eq.equipment_slot = Equipment.EquipmentSlot.CHEST
	assert_eq(eq.get_slot_name(), "Chest")


## Test: Class restriction check
func test_equipment_class_restriction() -> void:
	var eq = Equipment.new()
	eq.allowed_classes = ["warrior", "knight"]

	assert_true(eq.can_equip_class("warrior"))
	assert_false(eq.can_equip_class("mage"))


## Test: No class restriction
func test_equipment_no_restriction() -> void:
	var eq = Equipment.new()
	eq.allowed_classes = []

	assert_true(eq.can_equip_class("warrior"))
	assert_true(eq.can_equip_class("mage"))


## Test: Level requirement
func test_equipment_level_requirement() -> void:
	var eq = Equipment.new()
	eq.required_level = 10

	assert_false(eq.meets_level_requirement(5))
	assert_true(eq.meets_level_requirement(10))


## Test: Consumable effect types
func test_consumable_effect_types() -> void:
	var potion = Consumable.new()
	potion.effect_type = Consumable.EffectType.HEAL
	assert_eq(potion.get_effect_name(), "Heal")

	potion.effect_type = Consumable.EffectType.BUFF
	assert_eq(potion.get_effect_name(), "Buff")


## Test: Consumable cooldown
func test_consumable_cooldown() -> void:
	var potion = Consumable.new()
	potion.cooldown = 5

	assert_false(potion.is_on_cooldown())

	potion.mark_used()
	assert_true(potion.is_on_cooldown())


## Test: Consumable stackable
func test_consumable_stackable() -> void:
	var potion = Consumable.new()

	assert_true(potion.is_stackable)
	assert_eq(potion.max_stack, 99)


## Test: Crafting material type names
func test_material_type_names() -> void:
	var ore = CraftingMaterial.new("", "", "ore")
	assert_eq(ore.get_material_type_name(), "Ore")

	var wood = CraftingMaterial.new("", "", "wood")
	assert_eq(wood.get_material_type_name(), "Wood")


## Test: Crafting material skill requirement
func test_material_skill_requirement() -> void:
	var ore = CraftingMaterial.new()
	ore.required_skill = "mining"
	ore.required_skill_level = 5

	assert_false(ore.can_use("mining", 3))
	assert_true(ore.can_use("mining", 5))
	assert_false(ore.can_use("logging", 10))


## Test: Quest item non-tradeable
func test_quest_item_not_tradeable() -> void:
	var q_item = QuestItem.new()

	assert_false(q_item.is_tradeable)
	assert_false(q_item.can_sell())


## Test: Quest item objective
func test_quest_item_objective() -> void:
	var q_item = QuestItem.new()
	q_item.is_objective = true

	assert_true(q_item.is_objective)


## Test: Item catalog has items
func test_item_catalog_has_weapons() -> void:
	var weapons = ItemCatalog.get_weapons()

	assert_gt(weapons.size(), 0)
	assert_true("iron_sword" in weapons)


func test_item_catalog_has_armor() -> void:
	var armor = ItemCatalog.get_armor()

	assert_gt(armor.size(), 0)
	assert_true("leather_armor" in armor)


func test_item_catalog_has_consumables() -> void:
	var consumables = ItemCatalog.get_consumables()

	assert_gt(consumables.size(), 0)
	assert_true("health_potion" in consumables)


func test_item_catalog_has_materials() -> void:
	var materials = ItemCatalog.get_materials()

	assert_gt(materials.size(), 0)
	assert_true("copper_ore" in materials)


## Test: Create weapon from catalog
func test_create_weapon_from_catalog() -> void:
	var sword = ItemCatalog.create_weapon("iron_sword")

	assert_not_null(sword)
	assert_eq(sword.name, "Iron Sword")
	assert_eq(sword.stat_bonuses["strength"], 3)


## Test: Create armor from catalog
func test_create_armor_from_catalog() -> void:
	var armor = ItemCatalog.create_armor("leather_armor")

	assert_not_null(armor)
	assert_eq(armor.name, "Leather Armor")
	assert_eq(armor.stat_bonuses["constitution"], 2)


## Test: Create consumable from catalog
func test_create_consumable_from_catalog() -> void:
	var potion = ItemCatalog.create_consumable("health_potion")

	assert_not_null(potion)
	assert_eq(potion.name, "Health Potion")
	assert_eq(potion.effect_amount, 25)


## Test: Create material from catalog
func test_create_material_from_catalog() -> void:
	var ore = ItemCatalog.create_material("iron_ore")

	assert_not_null(ore)
	assert_eq(ore.name, "Iron Ore")
	assert_eq(ore.material_type, "ore")


## Test: Random weapon creation
func test_random_weapon() -> void:
	var weapon = ItemCatalog.get_random_weapon()

	assert_not_null(weapon)
	assert_true(weapon.item_type == Item.ItemType.WEAPON)


## Test: Item properties
func test_item_custom_properties() -> void:
	var item = Item.new()

	item.set_property("enchanted", true)
	item.set_property("magic_power", 50)

	assert_true(item.get_property("enchanted"))
	assert_eq(item.get_property("magic_power"), 50)


## Test: Item can equip
func test_item_can_equip() -> void:
	var weapon = Item.new("", "", Item.ItemType.WEAPON)
	var potion = Item.new("", "", Item.ItemType.CONSUMABLE)

	assert_true(weapon.can_equip())
	assert_false(potion.can_equip())


## Test: Item can use
func test_item_can_use() -> void:
	var potion = Item.new("", "", Item.ItemType.CONSUMABLE)
	var weapon = Item.new("", "", Item.ItemType.WEAPON)

	assert_true(potion.can_use())
	assert_false(weapon.can_use())


## Test: Item display with curse
func test_item_cursed_display() -> void:
	var item = Item.new("", "Cursed Sword")
	item.is_cursed = true

	var str = item.to_string()
	assert_true("[CURSED]" in str)
