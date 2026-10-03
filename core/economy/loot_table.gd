## Loot Table: defines drop rates and loot generation
##
## Difficulty modifies drop rates. Sources: enemy_loot, chest, quest_reward, crafting

class_name LootTable


## Difficulty tiers (affect drop rates)
enum Difficulty {
	EASY,
	NORMAL,
	HARD,
	HEROIC,
	LEGENDARY
}

## Loot source types
enum LootSource {
	ENEMY_LOOT,
	CHEST,
	QUEST_REWARD,
	CRAFTING_OUTPUT
}

## Probability of getting each item type (0.0 to 1.0)
var drop_rates: Dictionary = {
	"weapon": 0.3,
	"armor": 0.2,
	"consumable": 0.3,
	"material": 0.15,
	"gem": 0.05
}

## Rarity weighting for drops
var rarity_weights: Dictionary = {
	Item.Rarity.COMMON: 0.5,
	Item.Rarity.UNCOMMON: 0.25,
	Item.Rarity.RARE: 0.15,
	Item.Rarity.VERY_RARE: 0.08,
	Item.Rarity.LEGENDARY: 0.02
}

## Difficulty multipliers for legendary drop rate
var difficulty_legendary_multipliers: Dictionary = {
	Difficulty.EASY: 0.5,
	Difficulty.NORMAL: 1.0,
	Difficulty.HARD: 1.5,
	Difficulty.HEROIC: 2.0,
	Difficulty.LEGENDARY: 3.0
}

## Number of items dropped
var min_items: int = 1
var max_items: int = 3

## Chance of multiple drops (0.0 to 1.0)
var multi_drop_chance: float = 0.3


## Generate loot table result
func generate_loot(
	difficulty: int = Difficulty.NORMAL,
	source: int = LootSource.ENEMY_LOOT,
	seed_value: int = 0
) -> Array[Item]:
	if seed_value > 0:
		seed(seed_value)

	var loot: Array[Item] = []
	var item_count = randi_range(min_items, max_items)

	# Legendary difficulty can generate extra items
	if difficulty == Difficulty.LEGENDARY and randf() < 0.2:
		item_count += 1

	for i in range(item_count):
		var item = _generate_single_item(difficulty, source)
		if item:
			loot.append(item)

		# Chance to stop generating early
		if i > 0 and randf() > (1.0 - multi_drop_chance):
			break

	return loot


## Generate a single item
func _generate_single_item(difficulty: int, source: int) -> Item:
	var item_type = _select_item_type()
	if not item_type:
		return null

	var rarity = _select_rarity(difficulty)

	match item_type:
		"weapon":
			return ItemCatalog.get_random_weapon()
		"armor":
			return ItemCatalog.get_random_armor()
		"consumable":
			return ItemCatalog.get_random_consumable()
		"material":
			return ItemCatalog.get_random_material()
		"gem":
			return _generate_gem(rarity, difficulty)
		_:
			return null


## Select random item type based on drop rates
func _select_item_type() -> String:
	var rand = randf()
	var cumulative = 0.0

	for item_type in drop_rates:
		cumulative += drop_rates[item_type]
		if rand <= cumulative:
			return item_type

	return "material"  # Default fallback


## Select rarity based on difficulty
func _select_rarity(difficulty: int) -> int:
	var rand = randf()
	var cumulative = 0.0

	# Apply difficulty modifier to legendary chance
	var adjusted_rarity_weights = rarity_weights.duplicate()
	var difficulty_multiplier = difficulty_legendary_multipliers.get(difficulty, 1.0)

	var legendary_chance = adjusted_rarity_weights[Item.Rarity.LEGENDARY] * difficulty_multiplier
	var legendary_over = max(0.0, legendary_chance - 0.2)  # Cap at 20%

	if legendary_over > 0:
		adjusted_rarity_weights[Item.Rarity.LEGENDARY] = 0.2
		adjusted_rarity_weights[Item.Rarity.RARE] = max(0.0, adjusted_rarity_weights[Item.Rarity.RARE] - legendary_over)

	for rarity in range(Item.Rarity.LEGENDARY + 1):
		if rarity not in adjusted_rarity_weights:
			continue
		cumulative += adjusted_rarity_weights[rarity]
		if rand <= cumulative:
			return rarity

	return Item.Rarity.COMMON


## Generate gem for loot
func _generate_gem(rarity: int, difficulty: int) -> Gem:
	var gem = GemCatalog.create_random_gem(rarity)

	# Higher difficulty = better condition
	if difficulty >= Difficulty.HARD and randf() < 0.3:
		gem.condition = max(0, gem.condition - 1)

	return gem


## Get total drop chance (useful for validation)
func get_total_drop_rate() -> float:
	var total = 0.0
	for rate in drop_rates.values():
		total += rate
	return total


## String representation
func to_string() -> String:
	return "LootTable(min:%d, max:%d, types:%d)" % [min_items, max_items, drop_rates.size()]
