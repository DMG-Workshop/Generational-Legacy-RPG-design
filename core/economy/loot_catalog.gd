## Loot Catalog: predefined loot tables by source and difficulty
##
## Enemy drops, chest contents, quest rewards, crafting output

class_name LootCatalog


## Standard enemy loot by difficulty
static var ENEMY_LOOT_TABLES: Dictionary = {
	LootTable.Difficulty.EASY: {
		"weapon": 0.15,
		"armor": 0.1,
		"consumable": 0.4,
		"material": 0.3,
		"gem": 0.05
	},
	LootTable.Difficulty.NORMAL: {
		"weapon": 0.25,
		"armor": 0.15,
		"consumable": 0.35,
		"material": 0.2,
		"gem": 0.05
	},
	LootTable.Difficulty.HARD: {
		"weapon": 0.3,
		"armor": 0.2,
		"consumable": 0.3,
		"material": 0.15,
		"gem": 0.05
	},
	LootTable.Difficulty.HEROIC: {
		"weapon": 0.35,
		"armor": 0.25,
		"consumable": 0.25,
		"material": 0.1,
		"gem": 0.05
	},
	LootTable.Difficulty.LEGENDARY: {
		"weapon": 0.35,
		"armor": 0.25,
		"consumable": 0.2,
		"material": 0.1,
		"gem": 0.1
	}
}

## Chest/container loot (treasure-focused)
static var CHEST_LOOT_TABLES: Dictionary = {
	LootTable.Difficulty.EASY: {
		"weapon": 0.2,
		"armor": 0.2,
		"consumable": 0.3,
		"material": 0.2,
		"gem": 0.1
	},
	LootTable.Difficulty.NORMAL: {
		"weapon": 0.3,
		"armor": 0.2,
		"consumable": 0.25,
		"material": 0.15,
		"gem": 0.1
	},
	LootTable.Difficulty.HARD: {
		"weapon": 0.35,
		"armor": 0.25,
		"consumable": 0.2,
		"material": 0.1,
		"gem": 0.1
	},
	LootTable.Difficulty.HEROIC: {
		"weapon": 0.4,
		"armor": 0.3,
		"consumable": 0.15,
		"material": 0.05,
		"gem": 0.1
	},
	LootTable.Difficulty.LEGENDARY: {
		"weapon": 0.4,
		"armor": 0.35,
		"consumable": 0.1,
		"material": 0.05,
		"gem": 0.1
	}
}

## Quest reward loot (balanced for progression)
static var QUEST_REWARD_TABLES: Dictionary = {
	LootTable.Difficulty.EASY: {
		"weapon": 0.2,
		"armor": 0.2,
		"consumable": 0.35,
		"material": 0.15,
		"gem": 0.1
	},
	LootTable.Difficulty.NORMAL: {
		"weapon": 0.25,
		"armor": 0.25,
		"consumable": 0.3,
		"material": 0.1,
		"gem": 0.1
	},
	LootTable.Difficulty.HARD: {
		"weapon": 0.3,
		"armor": 0.3,
		"consumable": 0.2,
		"material": 0.1,
		"gem": 0.1
	},
	LootTable.Difficulty.HEROIC: {
		"weapon": 0.35,
		"armor": 0.35,
		"consumable": 0.15,
		"material": 0.05,
		"gem": 0.1
	},
	LootTable.Difficulty.LEGENDARY: {
		"weapon": 0.4,
		"armor": 0.4,
		"consumable": 0.1,
		"material": 0.05,
		"gem": 0.05
	}
}

## Crafting material output (heavy on materials)
static var CRAFTING_OUTPUT_TABLES: Dictionary = {
	LootTable.Difficulty.EASY: {
		"weapon": 0.05,
		"armor": 0.05,
		"consumable": 0.1,
		"material": 0.7,
		"gem": 0.1
	},
	LootTable.Difficulty.NORMAL: {
		"weapon": 0.1,
		"armor": 0.1,
		"consumable": 0.15,
		"material": 0.6,
		"gem": 0.05
	},
	LootTable.Difficulty.HARD: {
		"weapon": 0.15,
		"armor": 0.15,
		"consumable": 0.2,
		"material": 0.4,
		"gem": 0.1
	},
	LootTable.Difficulty.HEROIC: {
		"weapon": 0.2,
		"armor": 0.2,
		"consumable": 0.25,
		"material": 0.25,
		"gem": 0.1
	},
	LootTable.Difficulty.LEGENDARY: {
		"weapon": 0.25,
		"armor": 0.25,
		"consumable": 0.25,
		"material": 0.15,
		"gem": 0.1
	}
}


## Create loot table for given source and difficulty
static func create_loot_table(
	source: int,
	difficulty: int
) -> LootTable:
	var table = LootTable.new()

	match source:
		LootTable.LootSource.ENEMY_LOOT:
			table.drop_rates = ENEMY_LOOT_TABLES.get(difficulty, {}).duplicate()
			table.min_items = 1
			table.max_items = 2
			table.multi_drop_chance = 0.2

		LootTable.LootSource.CHEST:
			table.drop_rates = CHEST_LOOT_TABLES.get(difficulty, {}).duplicate()
			table.min_items = 2
			table.max_items = 4
			table.multi_drop_chance = 0.5

		LootTable.LootSource.QUEST_REWARD:
			table.drop_rates = QUEST_REWARD_TABLES.get(difficulty, {}).duplicate()
			table.min_items = 1
			table.max_items = 3
			table.multi_drop_chance = 0.3

		LootTable.LootSource.CRAFTING_OUTPUT:
			table.drop_rates = CRAFTING_OUTPUT_TABLES.get(difficulty, {}).duplicate()
			table.min_items = 1
			table.max_items = 5
			table.multi_drop_chance = 0.6

	return table


## Generate loot for source and difficulty
static func generate_loot(
	source: int,
	difficulty: int,
	seed_value: int = 0
) -> Array[Item]:
	var table = create_loot_table(source, difficulty)
	return table.generate_loot(difficulty, source, seed_value)


## Get all difficulty levels
static func get_difficulties() -> Array[int]:
	return [
		LootTable.Difficulty.EASY,
		LootTable.Difficulty.NORMAL,
		LootTable.Difficulty.HARD,
		LootTable.Difficulty.HEROIC,
		LootTable.Difficulty.LEGENDARY
	]


## Get difficulty name
static func get_difficulty_name(difficulty: int) -> String:
	match difficulty:
		LootTable.Difficulty.EASY:
			return "Easy"
		LootTable.Difficulty.NORMAL:
			return "Normal"
		LootTable.Difficulty.HARD:
			return "Hard"
		LootTable.Difficulty.HEROIC:
			return "Heroic"
		LootTable.Difficulty.LEGENDARY:
			return "Legendary"
		_:
			return "Unknown"


## Get source name
static func get_source_name(source: int) -> String:
	match source:
		LootTable.LootSource.ENEMY_LOOT:
			return "Enemy Loot"
		LootTable.LootSource.CHEST:
			return "Chest"
		LootTable.LootSource.QUEST_REWARD:
			return "Quest Reward"
		LootTable.LootSource.CRAFTING_OUTPUT:
			return "Crafting Output"
		_:
			return "Unknown"
