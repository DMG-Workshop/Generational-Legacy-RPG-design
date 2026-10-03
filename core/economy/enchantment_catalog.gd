## Enchantment Catalog: predefined magical enchantments
##
## Offensive, defensive, utility, special effects

class_name EnchantmentCatalog


## Predefined enchantments by type
static var ENCHANTMENTS: Dictionary = {
	# OFFENSIVE
	"sharpness": {
		"name": "Sharpness",
		"type": Enchantment.EnchantmentType.OFFENSIVE,
		"rarity": Enchantment.EnchantmentRarity.MINOR,
		"effect": "strength",
		"value": 3.0,
		"multiplier": 1.25,
		"description": "Blade cuts sharper, deals more damage"
	},
	"flaming": {
		"name": "Flaming",
		"type": Enchantment.EnchantmentType.OFFENSIVE,
		"rarity": Enchantment.EnchantmentRarity.MODERATE,
		"effect": "fire_damage",
		"value": 15.0,
		"multiplier": 1.5,
		"description": "Weapon wreathed in magical fire"
	},
	"frostbite": {
		"name": "Frostbite",
		"type": Enchantment.EnchantmentType.OFFENSIVE,
		"rarity": Enchantment.EnchantmentRarity.MODERATE,
		"effect": "cold_damage",
		"value": 15.0,
		"multiplier": 1.5,
		"description": "Icy magic slows enemies"
	},
	"lifesteal": {
		"name": "Lifesteal",
		"type": Enchantment.EnchantmentType.OFFENSIVE,
		"rarity": Enchantment.EnchantmentRarity.MAJOR,
		"effect": "leech",
		"value": 0.25,
		"multiplier": 2.0,
		"description": "Each hit restores health to wielder"
	},
	"executioner": {
		"name": "Executioner",
		"type": Enchantment.EnchantmentType.OFFENSIVE,
		"rarity": Enchantment.EnchantmentRarity.SUPREME,
		"effect": "crit_damage",
		"value": 50.0,
		"multiplier": 3.0,
		"description": "Critical hits deal massive damage"
	},

	# DEFENSIVE
	"fortitude": {
		"name": "Fortitude",
		"type": Enchantment.EnchantmentType.DEFENSIVE,
		"rarity": Enchantment.EnchantmentRarity.MINOR,
		"effect": "constitution",
		"value": 2.0,
		"multiplier": 1.25,
		"description": "Armor strengthens the wearer"
	},
	"fireward": {
		"name": "Fireward",
		"type": Enchantment.EnchantmentType.DEFENSIVE,
		"rarity": Enchantment.EnchantmentRarity.MODERATE,
		"effect": "fire_resistance",
		"value": 25.0,
		"multiplier": 1.4,
		"description": "Protects from fire damage"
	},
	"frostward": {
		"name": "Frostward",
		"type": Enchantment.EnchantmentType.DEFENSIVE,
		"rarity": Enchantment.EnchantmentRarity.MODERATE,
		"effect": "cold_resistance",
		"value": 25.0,
		"multiplier": 1.4,
		"description": "Protects from cold damage"
	},
	"reflection": {
		"name": "Reflection",
		"type": Enchantment.EnchantmentType.DEFENSIVE,
		"rarity": Enchantment.EnchantmentRarity.MAJOR,
		"effect": "damage_reflection",
		"value": 0.2,
		"multiplier": 2.0,
		"description": "Returns portion of damage to attackers"
	},
	"unbreakable": {
		"name": "Unbreakable",
		"type": Enchantment.EnchantmentType.DEFENSIVE,
		"rarity": Enchantment.EnchantmentRarity.SUPREME,
		"effect": "indestructible",
		"value": 1.0,
		"multiplier": 2.5,
		"description": "Never breaks or degrades"
	},

	# UTILITY
	"swiftness": {
		"name": "Swiftness",
		"type": Enchantment.EnchantmentType.UTILITY,
		"rarity": Enchantment.EnchantmentRarity.MINOR,
		"effect": "dexterity",
		"value": 3.0,
		"multiplier": 1.2,
		"description": "Increases speed and agility"
	},
	"wisdom": {
		"name": "Wisdom",
		"type": Enchantment.EnchantmentType.UTILITY,
		"rarity": Enchantment.EnchantmentRarity.MINOR,
		"effect": "wisdom",
		"value": 2.0,
		"multiplier": 1.2,
		"description": "Sharpens mind and perception"
	},
	"intellect": {
		"name": "Intellect",
		"type": Enchantment.EnchantmentType.UTILITY,
		"rarity": Enchantment.EnchantmentRarity.MINOR,
		"effect": "intelligence",
		"value": 2.0,
		"multiplier": 1.2,
		"description": "Enhances magical knowledge"
	},
	"bounty": {
		"name": "Bounty",
		"type": Enchantment.EnchantmentType.UTILITY,
		"rarity": Enchantment.EnchantmentRarity.MODERATE,
		"effect": "gold_multiplier",
		"value": 1.25,
		"multiplier": 1.6,
		"description": "Increases gold from enemies"
	},

	# SPECIAL
	"soulbound": {
		"name": "Soulbound",
		"type": Enchantment.EnchantmentType.SPECIAL,
		"rarity": Enchantment.EnchantmentRarity.MAJOR,
		"effect": "soulbound",
		"value": 1.0,
		"multiplier": 1.5,
		"description": "Bound to owner, cannot be lost"
	},
	"cursed": {
		"name": "Cursed",
		"type": Enchantment.EnchantmentType.SPECIAL,
		"rarity": Enchantment.EnchantmentRarity.LEGENDARY,
		"effect": "curse",
		"value": 2.0,
		"multiplier": 5.0,
		"description": "Immensely powerful but cursed"
	},
	"prophecy": {
		"name": "Prophecy",
		"type": Enchantment.EnchantmentType.SPECIAL,
		"rarity": Enchantment.EnchantmentRarity.LEGENDARY,
		"effect": "fate_influence",
		"value": 0.1,
		"multiplier": 4.0,
		"description": "Influences destiny itself"
	}
}


## Create enchantment from catalog
static func create_enchantment(enchantment_id: String) -> Enchantment:
	var data = ENCHANTMENTS.get(enchantment_id)
	if not data:
		return null

	var ench = Enchantment.new(
		enchantment_id,
		data["name"],
		data["effect"],
		data["value"],
		data["type"],
		data["rarity"]
	)

	ench.cost_multiplier = data["multiplier"]
	if "description" in data:
		ench.description = data["description"]

	return ench


## Get enchantments by type
static func get_enchantments_by_type(ench_type: int) -> Array[String]:
	var results: Array[String] = []
	for ench_id in ENCHANTMENTS.keys():
		if ENCHANTMENTS[ench_id]["type"] == ench_type:
			results.append(ench_id)
	return results


## Get enchantments by rarity
static func get_enchantments_by_rarity(rarity: int) -> Array[String]:
	var results: Array[String] = []
	for ench_id in ENCHANTMENTS.keys():
		if ENCHANTMENTS[ench_id]["rarity"] == rarity:
			results.append(ench_id)
	return results


## Get random enchantment
static func get_random_enchantment(
	rarity: int = -1,
	ench_type: int = -1
) -> Enchantment:
	var pool: Array[String] = []

	for ench_id in ENCHANTMENTS.keys():
		var data = ENCHANTMENTS[ench_id]
		var matches = true

		if rarity >= 0 and data["rarity"] != rarity:
			matches = false
		if ench_type >= 0 and data["type"] != ench_type:
			matches = false

		if matches:
			pool.append(ench_id)

	if pool.is_empty():
		return null

	return create_enchantment(pool[randi() % pool.size()])


## Get all enchantment IDs
static func get_all_enchantments() -> Array[String]:
	return ENCHANTMENTS.keys()


## Get enchantment rarity name
static func get_rarity_name(rarity: int) -> String:
	match rarity:
		Enchantment.EnchantmentRarity.MINOR:
			return "Minor"
		Enchantment.EnchantmentRarity.MODERATE:
			return "Moderate"
		Enchantment.EnchantmentRarity.MAJOR:
			return "Major"
		Enchantment.EnchantmentRarity.SUPREME:
			return "Supreme"
		Enchantment.EnchantmentRarity.LEGENDARY:
			return "Legendary"
		_:
			return "Unknown"


## Get enchantment type name
static func get_type_name(ench_type: int) -> String:
	match ench_type:
		Enchantment.EnchantmentType.OFFENSIVE:
			return "Offensive"
		Enchantment.EnchantmentType.DEFENSIVE:
			return "Defensive"
		Enchantment.EnchantmentType.UTILITY:
			return "Utility"
		Enchantment.EnchantmentType.SPECIAL:
			return "Special"
		_:
			return "Unknown"
