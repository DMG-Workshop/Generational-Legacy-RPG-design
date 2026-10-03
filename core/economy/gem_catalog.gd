## Gem Catalog: database of all gem types with base values
##
## Defines gem types, rarities, and pricing

class_name GemCatalog


## Gem database: [type] = {rarity, base_value}
static var GEMS: Dictionary = {
	# Common gems (10-50 gp)
	"quartz": {
		"rarity": Gem.Rarity.COMMON,
		"base_value": 15,
		"description": "Clear crystal, mildly valuable"
	},
	"tourmaline": {
		"rarity": Gem.Rarity.COMMON,
		"base_value": 25,
		"description": "Prismatic crystal"
	},
	"topaz": {
		"rarity": Gem.Rarity.COMMON,
		"base_value": 30,
		"description": "Golden-yellow gem"
	},

	# Uncommon gems (50-150 gp)
	"garnet": {
		"rarity": Gem.Rarity.UNCOMMON,
		"base_value": 75,
		"description": "Deep red gem, symbol of passion"
	},
	"pearl": {
		"rarity": Gem.Rarity.UNCOMMON,
		"base_value": 80,
		"description": "Lustrous gem from the sea"
	},
	"opal": {
		"rarity": Gem.Rarity.UNCOMMON,
		"base_value": 90,
		"description": "Iridescent gem with shifting colors"
	},
	"amethyst": {
		"rarity": Gem.Rarity.UNCOMMON,
		"base_value": 100,
		"description": "Purple crystalline gem"
	},

	# Rare gems (150-500 gp)
	"ruby": {
		"rarity": Gem.Rarity.RARE,
		"base_value": 250,
		"description": "Deep crimson gem, hardest but diamond"
	},
	"sapphire": {
		"rarity": Gem.Rarity.RARE,
		"base_value": 240,
		"description": "Azure gem of nobility"
	},
	"emerald": {
		"rarity": Gem.Rarity.RARE,
		"base_value": 260,
		"description": "Verdant gem of life and growth"
	},
	"jade": {
		"rarity": Gem.Rarity.RARE,
		"base_value": 200,
		"description": "Green stone of balance"
	},

	# Very Rare gems (500-2000 gp)
	"diamond": {
		"rarity": Gem.Rarity.VERY_RARE,
		"base_value": 1000,
		"description": "The hardest and most precious gem"
	},
	"alexandrite": {
		"rarity": Gem.Rarity.VERY_RARE,
		"base_value": 900,
		"description": "Color-changing gem of rare magic"
	},
	"tanzanite": {
		"rarity": Gem.Rarity.VERY_RARE,
		"base_value": 850,
		"description": "Violet gem of mystical properties"
	},

	# Legendary gems (2000+ gp)
	"dragonstone": {
		"rarity": Gem.Rarity.LEGENDARY,
		"base_value": 3000,
		"description": "Gem infused with draconic essence"
	},
	"starlight": {
		"rarity": Gem.Rarity.LEGENDARY,
		"base_value": 3500,
		"description": "Gem containing captured starlight"
	},
	"moonstone": {
		"rarity": Gem.Rarity.LEGENDARY,
		"base_value": 2500,
		"description": "Gem reflecting lunar magic"
	},
}


## Get gem data from catalog
static func get_gem_data(gem_type: String) -> Dictionary:
	var normalized = gem_type.to_lower()
	if normalized in GEMS:
		return GEMS[normalized]

	# Return default common gem if not found
	return {
		"rarity": Gem.Rarity.COMMON,
		"base_value": 10,
		"description": "Unknown gem"
	}


## Create a gem from type (with optional condition)
static func create_gem(gem_type: String, condition: int = Gem.Condition.EXCELLENT) -> Gem:
	var data = get_gem_data(gem_type)
	return Gem.new(
		gem_type,
		condition,
		data["rarity"],
		data["base_value"]
	)


## Create a random gem (for loot generation)
static func create_random_gem(rarity: int = -1) -> Gem:
	var gems_by_rarity: Array[String] = []

	# Determine which gems to choose from
	if rarity == -1:
		# Random rarity with weights
		var roll = randf() * 100.0
		if roll < 50:
			rarity = Gem.Rarity.COMMON
		elif roll < 75:
			rarity = Gem.Rarity.UNCOMMON
		elif roll < 90:
			rarity = Gem.Rarity.RARE
		elif roll < 98:
			rarity = Gem.Rarity.VERY_RARE
		else:
			rarity = Gem.Rarity.LEGENDARY

	# Collect gems of that rarity
	for gem_type in GEMS:
		if GEMS[gem_type]["rarity"] == rarity:
			gems_by_rarity.append(gem_type)

	if gems_by_rarity.is_empty():
		return create_gem("quartz")

	var chosen_type = gems_by_rarity[randi() % gems_by_rarity.size()]

	# Random condition with weights (weighted toward better conditions)
	var condition_roll = randf() * 100.0
	var condition: int
	if condition_roll < 30:
		condition = Gem.Condition.FLAWLESS
	elif condition_roll < 50:
		condition = Gem.Condition.EXCELLENT
	elif condition_roll < 70:
		condition = Gem.Condition.GOOD
	elif condition_roll < 85:
		condition = Gem.Condition.FAIR
	elif condition_roll < 95:
		condition = Gem.Condition.POOR
	else:
		condition = Gem.Condition.DAMAGED

	return create_gem(chosen_type, condition)


## Get all gem types
static func get_all_gem_types() -> Array[String]:
	var result: Array[String] = []
	for gem_type in GEMS:
		result.append(gem_type)
	return result


## Get gems by rarity
static func get_gems_by_rarity(rarity: int) -> Array[String]:
	var result: Array[String] = []
	for gem_type in GEMS:
		if GEMS[gem_type]["rarity"] == rarity:
			result.append(gem_type)
	return result


## Get all gems worth at least this much gold
static func get_gems_worth_at_least(min_gp: int) -> Array[String]:
	var result: Array[String] = []
	for gem_type in GEMS:
		if GEMS[gem_type]["base_value"] >= min_gp:
			result.append(gem_type)
	return result
