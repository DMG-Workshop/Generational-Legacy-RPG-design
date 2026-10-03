## Magic Item Generator: creates enchanted items
##
## Applies enchantments to items, scales with rarity, adjusts value

class_name MagicItemGenerator


## Maximum enchantments per item (increases with rarity)
static var MAX_ENCHANTMENTS_BY_RARITY: Dictionary = {
	Item.Rarity.COMMON: 0,
	Item.Rarity.UNCOMMON: 1,
	Item.Rarity.RARE: 2,
	Item.Rarity.VERY_RARE: 3,
	Item.Rarity.LEGENDARY: 4
}

## Probability of getting enchanted version (varies by rarity)
static var ENCHANT_CHANCE_BY_RARITY: Dictionary = {
	Item.Rarity.COMMON: 0.0,
	Item.Rarity.UNCOMMON: 0.3,
	Item.Rarity.RARE: 0.7,
	Item.Rarity.VERY_RARE: 0.95,
	Item.Rarity.LEGENDARY: 1.0
}

## Enchantment rarity distribution by source item rarity
static var ENCHANTMENT_RARITY_WEIGHTS: Dictionary = {
	Item.Rarity.UNCOMMON: {
		Enchantment.EnchantmentRarity.MINOR: 0.8,
		Enchantment.EnchantmentRarity.MODERATE: 0.2
	},
	Item.Rarity.RARE: {
		Enchantment.EnchantmentRarity.MINOR: 0.3,
		Enchantment.EnchantmentRarity.MODERATE: 0.5,
		Enchantment.EnchantmentRarity.MAJOR: 0.2
	},
	Item.Rarity.VERY_RARE: {
		Enchantment.EnchantmentRarity.MODERATE: 0.2,
		Enchantment.EnchantmentRarity.MAJOR: 0.5,
		Enchantment.EnchantmentRarity.SUPREME: 0.3
	},
	Item.Rarity.LEGENDARY: {
		Enchantment.EnchantmentRarity.MAJOR: 0.2,
		Enchantment.EnchantmentRarity.SUPREME: 0.5,
		Enchantment.EnchantmentRarity.LEGENDARY: 0.3
	}
}


## Create enchanted version of an item
static func create_enchanted_item(
	base_item: Item,
	force_enchantments: int = -1,
	seed_value: int = 0
) -> Item:
	if seed_value > 0:
		seed(seed_value)

	# Check if item can be enchanted
	var enchant_chance = ENCHANT_CHANCE_BY_RARITY.get(base_item.rarity, 0.0)
	if randf() > enchant_chance:
		return base_item

	# Determine number of enchantments
	var max_enchants = MAX_ENCHANTMENTS_BY_RARITY.get(base_item.rarity, 0)
	if max_enchants == 0:
		return base_item

	var num_enchants = force_enchantments if force_enchantments >= 0 else randi_range(1, max_enchants)

	# Apply enchantments
	var enchantments: Array[Enchantment] = []
	for i in range(num_enchants):
		var ench = _select_random_enchantment(base_item.rarity)
		if ench:
			enchantments.append(ench)

	# Apply to item
	if not enchantments.is_empty():
		_apply_enchantments(base_item, enchantments)

	return base_item


## Apply enchantments to an item
static func _apply_enchantments(item: Item, enchantments: Array[Enchantment]) -> void:
	# Store enchantments as custom property
	var ench_ids: Array[String] = []
	for ench in enchantments:
		ench_ids.append(ench.enchantment_id)

	item.set_property("enchantments", ench_ids)

	# Update item name with prefix
	var prefix = _get_prefix_by_rarity(enchantments)
	item.name = "%s %s" % [prefix, item.name]
	item.is_identified = false  # Enchanted item is hidden until identified

	# Apply stat bonuses from enchantments
	if item is Equipment:
		for ench in enchantments:
			if ench.effect_name == "strength":
				item.add_stat_bonus("strength", int(ench.effect_value))
			elif ench.effect_name == "dexterity":
				item.add_stat_bonus("dexterity", int(ench.effect_value))
			elif ench.effect_name == "constitution":
				item.add_stat_bonus("constitution", int(ench.effect_value))
			elif ench.effect_name == "intelligence":
				item.add_stat_bonus("intelligence", int(ench.effect_value))
			elif ench.effect_name == "wisdom":
				item.add_stat_bonus("wisdom", int(ench.effect_value))
			elif ench.effect_name == "fire_resistance":
				item.add_resistance("fire", int(ench.effect_value))
			elif ench.effect_name == "cold_resistance":
				item.add_resistance("cold", int(ench.effect_value))

	# Adjust value
	var multiplier = Enchantment.get_stacked_multiplier(enchantments)
	item.value = Currency.new(
		item.value.platinum,
		item.value.gold,
		item.value.silver,
		item.value.copper
	)
	item.value = item.value.multiply(multiplier)

	# Mark as cursed if includes curse enchantment
	for ench in enchantments:
		if ench.enchantment_id == "cursed":
			item.is_cursed = true


## Select random enchantment appropriate for item rarity
static func _select_random_enchantment(item_rarity: int) -> Enchantment:
	var weights = ENCHANTMENT_RARITY_WEIGHTS.get(item_rarity, {})
	if weights.is_empty():
		return null

	# Select enchantment rarity
	var rand = randf()
	var cumulative = 0.0
	var selected_rarity = -1

	for rarity in weights:
		cumulative += weights[rarity]
		if rand <= cumulative:
			selected_rarity = rarity
			break

	if selected_rarity < 0:
		selected_rarity = weights.keys()[0]

	# Get random enchantment of that rarity
	return EnchantmentCatalog.get_random_enchantment(selected_rarity)


## Get magical prefix based on enchantments
static func _get_prefix_by_rarity(enchantments: Array[Enchantment]) -> String:
	if enchantments.is_empty():
		return ""

	var max_rarity = 0
	for ench in enchantments:
		max_rarity = max(max_rarity, ench.rarity)

	match max_rarity:
		Enchantment.EnchantmentRarity.MINOR:
			return "Enchanted"
		Enchantment.EnchantmentRarity.MODERATE:
			return "Magical"
		Enchantment.EnchantmentRarity.MAJOR:
			return "Rare"
		Enchantment.EnchantmentRarity.SUPREME:
			return "Heroic"
		Enchantment.EnchantmentRarity.LEGENDARY:
			return "Legendary"
		_:
			return "Mystical"


## Get enchantments from item
static func get_enchantments_from_item(item: Item) -> Array[Enchantment]:
	var ench_ids = item.get_property("enchantments")
	if not ench_ids or not (ench_ids is Array):
		return []

	var enchantments: Array[Enchantment] = []
	for ench_id in ench_ids:
		var ench = EnchantmentCatalog.create_enchantment(ench_id)
		if ench:
			enchantments.append(ench)

	return enchantments


## Create random magical item from any catalog item
static func create_random_magical_item(
	rarity: int,
	seed_value: int = 0
) -> Item:
	if seed_value > 0:
		seed(seed_value)

	# Create base item
	var base_item: Item = null
	match randi() % 4:
		0:
			base_item = ItemCatalog.get_random_weapon()
		1:
			base_item = ItemCatalog.get_random_armor()
		2:
			base_item = ItemCatalog.get_random_consumable()
		_:
			base_item = ItemCatalog.get_random_material()

	if not base_item:
		return null

	# Set rarity and enchant
	base_item.rarity = rarity
	return create_enchanted_item(base_item)


## Get total enchantment value bonus
static func get_enchantment_value_bonus(item: Item) -> float:
	var enchantments = get_enchantments_from_item(item)
	if enchantments.is_empty():
		return 1.0
	return Enchantment.get_stacked_multiplier(enchantments)


## Get enchantment description
static func get_enchantment_display(item: Item) -> String:
	var enchantments = get_enchantments_from_item(item)
	if enchantments.is_empty():
		return ""

	var display = "\n[Enchantments]\n"
	for ench in enchantments:
		display += "• %s: %s +%.1f\n" % [ench.name, ench.effect_name, ench.effect_value]

	return display
