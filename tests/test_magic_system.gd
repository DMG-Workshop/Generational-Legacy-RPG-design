## Tests for magic item system (enchantments, magical items)
##
## Tests: enchantment creation, magical item generation, value scaling

extends GutTest


var enchantment: Enchantment
var item: Item


func before_each() -> void:
	enchantment = Enchantment.new()
	item = Item.new("test_item", "Test Item")


## Test: Create basic enchantment
func test_create_enchantment() -> void:
	var ench = Enchantment.new("sharp", "Sharpness", "strength", 3.0)

	assert_eq(ench.enchantment_id, "sharp")
	assert_eq(ench.name, "Sharpness")
	assert_eq(ench.effect_name, "strength")
	assert_eq(ench.effect_value, 3.0)


## Test: Enchantment rarity names
func test_enchantment_rarity_names() -> void:
	enchantment.rarity = Enchantment.EnchantmentRarity.MINOR
	assert_eq(enchantment.get_rarity_name(), "Minor")

	enchantment.rarity = Enchantment.EnchantmentRarity.LEGENDARY
	assert_eq(enchantment.get_rarity_name(), "Legendary")


## Test: Enchantment type names
func test_enchantment_type_names() -> void:
	enchantment.enchantment_type = Enchantment.EnchantmentType.OFFENSIVE
	assert_eq(enchantment.get_type_name(), "Offensive")

	enchantment.enchantment_type = Enchantment.EnchantmentType.DEFENSIVE
	assert_eq(enchantment.get_type_name(), "Defensive")


## Test: Enchantment compatibility check
func test_enchantment_item_compatibility() -> void:
	enchantment.compatible_item_types = [Item.ItemType.WEAPON]

	assert_true(enchantment.can_enchant_type(Item.ItemType.WEAPON))
	assert_false(enchantment.can_enchant_type(Item.ItemType.ARMOR))


## Test: Enchantment power by rarity
func test_enchantment_power_by_rarity() -> void:
	enchantment.rarity = Enchantment.EnchantmentRarity.MINOR
	assert_eq(enchantment.get_power(), 1)

	enchantment.rarity = Enchantment.EnchantmentRarity.LEGENDARY
	assert_eq(enchantment.get_power(), 5)


## Test: Single enchantment cost multiplier
func test_single_enchantment_multiplier() -> void:
	enchantment.cost_multiplier = 1.5
	var enchantments = [enchantment]

	var multiplier = Enchantment.get_stacked_multiplier(enchantments)
	assert_eq(multiplier, 1.5)


## Test: Multiple enchantment stacking penalty
func test_multiple_enchantments_stacking() -> void:
	var ench1 = Enchantment.new("e1", "", "", 0.0)
	ench1.cost_multiplier = 1.5

	var ench2 = Enchantment.new("e2", "", "", 0.0)
	ench2.cost_multiplier = 1.4

	var enchantments = [ench1, ench2]
	var multiplier = Enchantment.get_stacked_multiplier(enchantments)

	# Should be 1.5 * 1.4 * 1.1 (stacking penalty)
	assert_between(multiplier, 2.0, 2.3)


## Test: Enchantment string representation
func test_enchantment_to_string() -> void:
	enchantment.name = "Sharpness"
	enchantment.enchantment_type = Enchantment.EnchantmentType.OFFENSIVE
	enchantment.rarity = Enchantment.EnchantmentRarity.MINOR

	var str = enchantment.to_string()
	assert_true("Sharpness" in str)
	assert_true("Offensive" in str)


## Test: Create enchantment from catalog
func test_create_enchantment_from_catalog() -> void:
	var ench = EnchantmentCatalog.create_enchantment("sharpness")

	assert_not_null(ench)
	assert_eq(ench.name, "Sharpness")
	assert_eq(ench.effect_name, "strength")


## Test: Get enchantments by type
func test_get_enchantments_by_type() -> void:
	var offensive = EnchantmentCatalog.get_enchantments_by_type(Enchantment.EnchantmentType.OFFENSIVE)

	assert_gt(offensive.size(), 0)
	for ench_id in offensive:
		var ench = EnchantmentCatalog.create_enchantment(ench_id)
		assert_eq(ench.enchantment_type, Enchantment.EnchantmentType.OFFENSIVE)


## Test: Get enchantments by rarity
func test_get_enchantments_by_rarity() -> void:
	var minor = EnchantmentCatalog.get_enchantments_by_rarity(Enchantment.EnchantmentRarity.MINOR)

	assert_gt(minor.size(), 0)
	for ench_id in minor:
		var ench = EnchantmentCatalog.create_enchantment(ench_id)
		assert_eq(ench.rarity, Enchantment.EnchantmentRarity.MINOR)


## Test: Get random enchantment
func test_get_random_enchantment() -> void:
	var ench = EnchantmentCatalog.get_random_enchantment()

	assert_not_null(ench)
	assert_true(ench.enchantment_id in EnchantmentCatalog.ENCHANTMENTS)


## Test: Get random enchantment by rarity
func test_get_random_enchantment_by_rarity() -> void:
	for i in range(5):
		var ench = EnchantmentCatalog.get_random_enchantment(Enchantment.EnchantmentRarity.MAJOR)
		if ench:
			assert_eq(ench.rarity, Enchantment.EnchantmentRarity.MAJOR)


## Test: Common items cannot be enchanted
func test_common_items_no_enchant() -> void:
	var common = Item.new("test", "Test Item")
	common.rarity = Item.Rarity.COMMON

	var enchanted = MagicItemGenerator.create_enchanted_item(common)
	var enchants = MagicItemGenerator.get_enchantments_from_item(enchanted)

	assert_eq(enchants.size(), 0)


## Test: Uncommon items can have 1 enchantment
func test_uncommon_items_single_enchant() -> void:
	var uncommon = Item.new("test", "Test Item")
	uncommon.rarity = Item.Rarity.UNCOMMON

	var enchanted = MagicItemGenerator.create_enchanted_item(uncommon, 1)
	var enchants = MagicItemGenerator.get_enchantments_from_item(enchanted)

	assert_eq(enchants.size(), 1)


## Test: Rare items can have up to 2 enchantments
func test_rare_items_multiple_enchants() -> void:
	var rare = Item.new("test", "Test Item")
	rare.rarity = Item.Rarity.RARE

	var enchanted = MagicItemGenerator.create_enchanted_item(rare, 2)
	var enchants = MagicItemGenerator.get_enchantments_from_item(enchanted)

	assert_eq(enchants.size(), 2)


## Test: Legendary items can have max enchantments
func test_legendary_items_max_enchants() -> void:
	var legendary = Item.new("test", "Test Item")
	legendary.rarity = Item.Rarity.LEGENDARY

	var enchanted = MagicItemGenerator.create_enchanted_item(legendary, 4)
	var enchants = MagicItemGenerator.get_enchantments_from_item(enchanted)

	assert_eq(enchants.size(), 4)


## Test: Enchantment changes item name
func test_enchanted_item_name_prefix() -> void:
	var item_to_enchant = Item.new("sword", "Iron Sword")
	item_to_enchant.rarity = Item.Rarity.RARE

	var enchanted = MagicItemGenerator.create_enchanted_item(item_to_enchant, 1)

	assert_true("Rare" in enchanted.name or "Magical" in enchanted.name or "Enchanted" in enchanted.name)


## Test: Enchanted equipment gets stat bonuses
func test_enchanted_equipment_stat_bonus() -> void:
	var sword = Equipment.new("test", "Sword")
	sword.rarity = Item.Rarity.RARE
	sword.item_type = Item.ItemType.WEAPON

	var enchanted = MagicItemGenerator.create_enchanted_item(sword, 1)

	var enchants = MagicItemGenerator.get_enchantments_from_item(enchanted)
	if enchants.size() > 0:
		var total_bonus = enchanted.get_total_bonus()
		assert_gt(total_bonus, 0)


## Test: Enchantment increases item value
func test_enchanted_item_value_increased() -> void:
	var item_to_enchant = Item.new("test", "Test Item")
	item_to_enchant.rarity = Item.Rarity.RARE
	item_to_enchant.value = Currency.new(0, 100, 0, 0)

	var original_value = item_to_enchant.value.to_copper()

	var enchanted = MagicItemGenerator.create_enchanted_item(item_to_enchant, 1)
	var new_value = enchanted.value.to_copper()

	assert_gt(new_value, original_value)


## Test: Multiple enchantments increase value more
func test_multiple_enchantments_higher_value() -> void:
	var item1 = Item.new("test", "Item 1")
	item1.rarity = Item.Rarity.RARE
	item1.value = Currency.new(0, 100, 0, 0)

	var item2 = Item.new("test", "Item 2")
	item2.rarity = Item.Rarity.RARE
	item2.value = Currency.new(0, 100, 0, 0)

	var enchant1 = MagicItemGenerator.create_enchanted_item(item1, 1)
	var enchant2 = MagicItemGenerator.create_enchanted_item(item2, 2)

	assert_lt(enchant1.value.to_copper(), enchant2.value.to_copper())


## Test: Cursed enchantment sets cursed flag
func test_cursed_enchantment_sets_flag() -> void:
	var item_to_enchant = Item.new("test", "Cursed Item")
	item_to_enchant.rarity = Item.Rarity.LEGENDARY

	# Force cursed enchantment by modifying internals
	var ench = EnchantmentCatalog.create_enchantment("cursed")
	MagicItemGenerator._apply_enchantments(item_to_enchant, [ench])

	assert_true(item_to_enchant.is_cursed)


## Test: Enchanted item is unidentified
func test_enchanted_item_unidentified() -> void:
	var item_to_enchant = Item.new("test", "Mystery Item")
	item_to_enchant.rarity = Item.Rarity.RARE
	item_to_enchant.is_identified = true

	var enchanted = MagicItemGenerator.create_enchanted_item(item_to_enchant, 1)

	var enchants = MagicItemGenerator.get_enchantments_from_item(enchanted)
	if enchants.size() > 0:
		assert_false(enchanted.is_identified)


## Test: Get enchantment value bonus
func test_get_enchantment_value_bonus() -> void:
	var item_to_enchant = Item.new("test", "Test")
	item_to_enchant.rarity = Item.Rarity.RARE

	var enchanted = MagicItemGenerator.create_enchanted_item(item_to_enchant, 2)
	var bonus = MagicItemGenerator.get_enchantment_value_bonus(enchanted)

	assert_gt(bonus, 1.0)


## Test: Get enchantment display string
func test_get_enchantment_display() -> void:
	var item_to_enchant = Item.new("test", "Test")
	item_to_enchant.rarity = Item.Rarity.RARE

	var enchanted = MagicItemGenerator.create_enchanted_item(item_to_enchant, 1)
	var display = MagicItemGenerator.get_enchantment_display(enchanted)

	var enchants = MagicItemGenerator.get_enchantments_from_item(enchanted)
	if enchants.size() > 0:
		assert_true("[Enchantments]" in display)
	else:
		assert_eq(display, "")


## Test: Create random magical item
func test_create_random_magical_item() -> void:
	var item = MagicItemGenerator.create_random_magical_item(Item.Rarity.RARE)

	assert_not_null(item)
	assert_true(item is Item)


## Test: Random magical item by rarity
func test_random_magical_items_different_rarities() -> void:
	var rare = MagicItemGenerator.create_random_magical_item(Item.Rarity.RARE)
	var legendary = MagicItemGenerator.create_random_magical_item(Item.Rarity.LEGENDARY)

	assert_eq(rare.rarity, Item.Rarity.RARE)
	assert_eq(legendary.rarity, Item.Rarity.LEGENDARY)


## Test: Seeded generation reproducibility
func test_seeded_magical_item_reproducibility() -> void:
	var item1 = MagicItemGenerator.create_enchanted_item(
		Item.new("test", "Test"),
		1,
		12345
	)
	var item2 = MagicItemGenerator.create_enchanted_item(
		Item.new("test", "Test"),
		1,
		12345
	)

	var enchants1 = MagicItemGenerator.get_enchantments_from_item(item1)
	var enchants2 = MagicItemGenerator.get_enchantments_from_item(item2)

	if enchants1.size() > 0 and enchants2.size() > 0:
		assert_eq(enchants1[0].enchantment_id, enchants2[0].enchantment_id)


## Test: All enchantments retrievable
func test_all_catalog_enchantments_valid() -> void:
	var all_ench_ids = EnchantmentCatalog.get_all_enchantments()

	assert_gt(all_ench_ids.size(), 0)
	for ench_id in all_ench_ids:
		var ench = EnchantmentCatalog.create_enchantment(ench_id)
		assert_not_null(ench)


## Test: Enchantment catalog has expected counts
func test_enchantment_catalog_has_items() -> void:
	var all_ench = EnchantmentCatalog.get_all_enchantments()
	var offensive = EnchantmentCatalog.get_enchantments_by_type(Enchantment.EnchantmentType.OFFENSIVE)
	var defensive = EnchantmentCatalog.get_enchantments_by_type(Enchantment.EnchantmentType.DEFENSIVE)

	assert_gt(all_ench.size(), 10)
	assert_gt(offensive.size(), 0)
	assert_gt(defensive.size(), 0)
