## Tests for loot system (loot tables, drop rates, difficulty scaling)
##
## Tests: loot generation, rarity distribution, source variations, difficulty effects

extends GutTest


var loot_table: LootTable


func before_each() -> void:
	loot_table = LootTable.new()


## Test: Create basic loot table
func test_create_loot_table() -> void:
	assert_not_null(loot_table)
	assert_eq(loot_table.min_items, 1)
	assert_eq(loot_table.max_items, 3)
	assert_gt(loot_table.get_total_drop_rate(), 0.95)


## Test: Drop rates sum is valid
func test_drop_rates_total() -> void:
	var total = loot_table.get_total_drop_rate()
	assert_between(total, 0.95, 1.05)


## Test: Rarity weights are normalized
func test_rarity_weights_total() -> void:
	var total = 0.0
	for weight in loot_table.rarity_weights.values():
		total += weight
	assert_between(total, 0.95, 1.05)


## Test: Generate loot returns array
func test_generate_loot_returns_array() -> void:
	var loot = loot_table.generate_loot()
	assert_true(loot is Array)


## Test: Generated loot count is in range
func test_generate_loot_count() -> void:
	var loot = loot_table.generate_loot()
	assert_between(loot.size(), loot_table.min_items, loot_table.max_items + 1)


## Test: All generated items are Items
func test_generated_items_are_items() -> void:
	var loot = loot_table.generate_loot()
	for item in loot:
		assert_true(item is Item)


## Test: Difficulty easy generates common items
func test_difficulty_easy_generates_lower_rarity() -> void:
	var rarities: Array[int] = []
	for i in range(20):
		var loot = loot_table.generate_loot(LootTable.Difficulty.EASY)
		for item in loot:
			rarities.append(item.rarity)

	var common_count = rarities.filter(func(r): return r == Item.Rarity.COMMON).size()
	assert_gt(common_count, rarities.size() / 3)


## Test: Difficulty legendary has higher legendary chance
func test_difficulty_legendary_better_drops() -> void:
	var legendary_count = 0
	var total_items = 0

	for i in range(30):
		var loot = loot_table.generate_loot(LootTable.Difficulty.LEGENDARY)
		total_items += loot.size()
		for item in loot:
			if item.rarity == Item.Rarity.LEGENDARY:
				legendary_count += 1

	var legendary_rate = float(legendary_count) / total_items
	assert_gt(legendary_rate, 0.01)  # At least 1% legendary


## Test: Enemy loot table
func test_enemy_loot_table() -> void:
	var table = LootCatalog.create_loot_table(
		LootTable.LootSource.ENEMY_LOOT,
		LootTable.Difficulty.NORMAL
	)

	assert_not_null(table)
	assert_eq(table.min_items, 1)
	assert_eq(table.max_items, 2)


## Test: Chest loot table has more items
func test_chest_loot_table_more_items() -> void:
	var table = LootCatalog.create_loot_table(
		LootTable.LootSource.CHEST,
		LootTable.Difficulty.NORMAL
	)

	assert_eq(table.min_items, 2)
	assert_eq(table.max_items, 4)


## Test: Quest reward table
func test_quest_reward_table() -> void:
	var table = LootCatalog.create_loot_table(
		LootTable.LootSource.QUEST_REWARD,
		LootTable.Difficulty.NORMAL
	)

	assert_not_null(table)
	assert_between(table.min_items, 1, 3)


## Test: Crafting output table (heavy materials)
func test_crafting_output_table() -> void:
	var table = LootCatalog.create_loot_table(
		LootTable.LootSource.CRAFTING_OUTPUT,
		LootTable.Difficulty.NORMAL
	)

	assert_eq(table.min_items, 1)
	assert_eq(table.max_items, 5)


## Test: Generate enemy loot
func test_generate_enemy_loot() -> void:
	var loot = LootCatalog.generate_loot(
		LootTable.LootSource.ENEMY_LOOT,
		LootTable.Difficulty.NORMAL
	)

	assert_gt(loot.size(), 0)
	for item in loot:
		assert_true(item is Item)


## Test: Generate chest loot
func test_generate_chest_loot() -> void:
	var loot = LootCatalog.generate_loot(
		LootTable.LootSource.CHEST,
		LootTable.Difficulty.HEROIC
	)

	assert_gt(loot.size(), 1)  # Chest should have multiple items


## Test: Generate quest reward loot
func test_generate_quest_loot() -> void:
	var loot = LootCatalog.generate_loot(
		LootTable.LootSource.QUEST_REWARD,
		LootTable.Difficulty.NORMAL
	)

	assert_gt(loot.size(), 0)


## Test: Generate crafting output loot
func test_generate_crafting_output() -> void:
	var loot = LootCatalog.generate_loot(
		LootTable.LootSource.CRAFTING_OUTPUT,
		LootTable.Difficulty.HARD
	)

	assert_gt(loot.size(), 0)
	var material_count = loot.filter(func(i): return i.item_type == Item.ItemType.CRAFTING_MATERIAL).size()
	assert_gt(material_count, 0)


## Test: Difficulty names
func test_difficulty_names() -> void:
	assert_eq(LootCatalog.get_difficulty_name(LootTable.Difficulty.EASY), "Easy")
	assert_eq(LootCatalog.get_difficulty_name(LootTable.Difficulty.NORMAL), "Normal")
	assert_eq(LootCatalog.get_difficulty_name(LootTable.Difficulty.HARD), "Hard")
	assert_eq(LootCatalog.get_difficulty_name(LootTable.Difficulty.HEROIC), "Heroic")
	assert_eq(LootCatalog.get_difficulty_name(LootTable.Difficulty.LEGENDARY), "Legendary")


## Test: Source names
func test_source_names() -> void:
	assert_eq(LootCatalog.get_source_name(LootTable.LootSource.ENEMY_LOOT), "Enemy Loot")
	assert_eq(LootCatalog.get_source_name(LootTable.LootSource.CHEST), "Chest")
	assert_eq(LootCatalog.get_source_name(LootTable.LootSource.QUEST_REWARD), "Quest Reward")
	assert_eq(LootCatalog.get_source_name(LootTable.LootSource.CRAFTING_OUTPUT), "Crafting Output")


## Test: Get all difficulties
func test_get_difficulties() -> void:
	var difficulties = LootCatalog.get_difficulties()
	assert_eq(difficulties.size(), 5)
	assert_true(LootTable.Difficulty.EASY in difficulties)
	assert_true(LootTable.Difficulty.LEGENDARY in difficulties)


## Test: Loot table string representation
func test_loot_table_to_string() -> void:
	var str = loot_table.to_string()
	assert_true("LootTable" in str)
	assert_true("min:" in str)
	assert_true("max:" in str)


## Test: Easy difficulty generates fewer items
func test_easy_difficulty_fewer_items() -> void:
	var easy_table = LootCatalog.create_loot_table(
		LootTable.LootSource.ENEMY_LOOT,
		LootTable.Difficulty.EASY
	)

	var legendary_table = LootCatalog.create_loot_table(
		LootTable.LootSource.ENEMY_LOOT,
		LootTable.Difficulty.LEGENDARY
	)

	assert_lt(easy_table.min_items, legendary_table.max_items)


## Test: Enemy loot different from chest loot
func test_source_differences() -> void:
	var enemy_table = LootCatalog.create_loot_table(
		LootTable.LootSource.ENEMY_LOOT,
		LootTable.Difficulty.NORMAL
	)

	var chest_table = LootCatalog.create_loot_table(
		LootTable.LootSource.CHEST,
		LootTable.Difficulty.NORMAL
	)

	assert_ne(enemy_table.drop_rates, chest_table.drop_rates)


## Test: Difficulty affects rarity distribution
func test_difficulty_affects_rarity() -> void:
	var easy_legends = 0
	var hard_legends = 0
	var sample_size = 50

	for i in range(sample_size):
		var easy_loot = loot_table.generate_loot(LootTable.Difficulty.EASY)
		for item in easy_loot:
			if item.rarity == Item.Rarity.LEGENDARY:
				easy_legends += 1

	for i in range(sample_size):
		var hard_loot = loot_table.generate_loot(LootTable.Difficulty.HARD)
		for item in hard_loot:
			if item.rarity == Item.Rarity.LEGENDARY:
				hard_legends += 1

	assert_lt(easy_legends, hard_legends)


## Test: Seed produces reproducible results
func test_seed_reproducible() -> void:
	var loot1 = loot_table.generate_loot(LootTable.Difficulty.NORMAL, LootTable.LootSource.ENEMY_LOOT, 12345)
	var loot2 = loot_table.generate_loot(LootTable.Difficulty.NORMAL, LootTable.LootSource.ENEMY_LOOT, 12345)

	assert_eq(loot1.size(), loot2.size())


## Test: Gem can appear in loot
func test_gem_in_loot() -> void:
	var gem_found = false
	for i in range(20):
		var loot = loot_table.generate_loot(LootTable.Difficulty.HARD)
		for item in loot:
			if item is Gem:
				gem_found = true
				break

	assert_true(gem_found)


## Test: Crafting output has materials
func test_crafting_output_materials() -> void:
	for i in range(5):
		var loot = LootCatalog.generate_loot(
			LootTable.LootSource.CRAFTING_OUTPUT,
			LootTable.Difficulty.NORMAL
		)
		var has_material = loot.any(func(item): return item.item_type == Item.ItemType.CRAFTING_MATERIAL)
		assert_true(has_material)
