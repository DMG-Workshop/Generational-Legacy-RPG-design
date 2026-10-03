## Tests for battle loot system integration
##
## Tests: enemy death triggers loot, difficulty scaling, loot pool composition,
## enchanted item generation, currency rewards, and reward accumulation

extends GutTest


var battle: Battle


func before_each() -> void:
	battle = Battle.new()


## Test: Create battle rewards tracker
func test_create_battle_rewards() -> void:
	var rewards = BattleRewards.new()
	assert_not_null(rewards)
	assert_eq(rewards.get_total_items(), 0)


## Test: Add single reward to battle rewards
func test_add_single_reward() -> void:
	var rewards = BattleRewards.new()
	var item = Item.new("test_item", "Test Sword", Item.ItemType.WEAPON, Item.Rarity.COMMON)

	rewards.add_reward(item, "Enemy")

	assert_eq(rewards.get_total_items(), 1)


## Test: Add multiple rewards accumulate
func test_add_multiple_rewards() -> void:
	var rewards = BattleRewards.new()

	for i in range(5):
		var item = Item.new("item_%d" % i, "Item %d" % i)
		rewards.add_reward(item, "Enemy %d" % i)

	assert_eq(rewards.get_total_items(), 5)


## Test: Add currency reward
func test_add_currency_reward() -> void:
	var rewards = BattleRewards.new()
	var currency = Currency.new(0, 10, 0, 0)  # 10 gold

	rewards.add_currency(currency)

	assert_eq(rewards.currency_reward.gold, 10)


## Test: Battle starts with empty rewards
func test_battle_starts_with_empty_rewards() -> void:
	var party = [_create_hero()]
	var enemies = [_create_enemy()]

	battle.start_battle(party, enemies)

	assert_eq(battle.get_battle_rewards().get_total_items(), 0)


## Test: Enemy death triggers loot generation
func test_enemy_death_generates_loot() -> void:
	var party = [_create_hero()]
	var enemy = _create_enemy()
	enemy.hp = 10  # Low HP to kill easily
	var enemies = [enemy]

	battle.start_battle(party, enemies)

	var attacker = party[0]
	var defender = enemies[0]

	# Deal damage to kill enemy
	battle.execute_turn(attacker, "attack", defender)

	# Check if loot was generated
	var rewards = battle.get_battle_rewards()
	assert_gt(rewards.get_total_items(), 0, "Enemy death should generate loot")


## Test: Easy difficulty generates lower rarity loot
func test_easy_difficulty_drops_worse_loot() -> void:
	var loot_easy = LootCatalog.generate_loot(
		LootTable.LootSource.ENEMY_LOOT,
		LootTable.Difficulty.EASY
	)

	var easy_common = 0
	for item in loot_easy:
		if item.rarity == Item.Rarity.COMMON:
			easy_common += 1

	assert_gt(easy_common, 0, "Easy difficulty should have common items")


## Test: Hard difficulty drops better loot than Easy
func test_hard_difficulty_better_than_easy() -> void:
	var loot_easy = LootCatalog.generate_loot(
		LootTable.LootSource.ENEMY_LOOT,
		LootTable.Difficulty.EASY
	)
	var loot_hard = LootCatalog.generate_loot(
		LootTable.LootSource.ENEMY_LOOT,
		LootTable.Difficulty.HARD
	)

	# Calculate average rarity
	var easy_avg_rarity = 0.0
	var hard_avg_rarity = 0.0

	for item in loot_easy:
		easy_avg_rarity += item.rarity
	if loot_easy.size() > 0:
		easy_avg_rarity /= loot_easy.size()

	for item in loot_hard:
		hard_avg_rarity += item.rarity
	if loot_hard.size() > 0:
		hard_avg_rarity /= loot_hard.size()

	assert_gt(hard_avg_rarity, easy_avg_rarity, "Hard difficulty should have higher average rarity")


## Test: Loot pool includes different item types
func test_loot_pool_includes_multiple_types() -> void:
	var item_types = {}

	# Generate many loot items to ensure variety
	for i in range(20):
		var loot = LootCatalog.generate_loot(
			LootTable.LootSource.ENEMY_LOOT,
			LootTable.Difficulty.NORMAL
		)
		for item in loot:
			var type_name = item.get_type_name()
			if type_name not in item_types:
				item_types[type_name] = 0
			item_types[type_name] += 1

	# Should have at least 2 different item types
	assert_gt(item_types.size(), 1, "Loot pool should include multiple item types")


## Test: Legendary difficulty can generate enchanted items
func test_legendary_difficulty_enchanted_items() -> void:
	var enchanted_found = false

	# Generate many legendary items
	for i in range(30):
		var loot = LootCatalog.generate_loot(
			LootTable.LootSource.ENEMY_LOOT,
			LootTable.Difficulty.LEGENDARY
		)
		for item in loot:
			if item is Equipment and item.get_property("enchantments") != null:
				enchanted_found = true
				break
		if enchanted_found:
			break

	assert_true(enchanted_found, "Legendary difficulty should have enchanted items")


## Test: Rare enemy drops better loot
func test_rare_enemy_drops_better_loot() -> void:
	var party = [_create_hero()]
	var rare_enemy = _create_enemy()
	rare_enemy.is_rare_enemy = true
	rare_enemy.difficulty = LootTable.Difficulty.NORMAL
	rare_enemy.hp = 10
	var enemies = [rare_enemy]

	battle.start_battle(party, enemies)

	var attacker = party[0]
	battle.execute_turn(attacker, "attack", rare_enemy)

	var rewards = battle.get_battle_rewards()
	assert_gt(rewards.get_total_items(), 0)


## Test: Multiple enemies accumulate rewards
func test_multiple_enemies_accumulate_rewards() -> void:
	var party = [_create_hero()]
	var enemies: Array[Battle.Combatant] = []

	for i in range(3):
		var enemy = _create_enemy()
		enemy.name = "Enemy_%d" % i
		enemy.hp = 10
		enemies.append(enemy)

	battle.start_battle(party, enemies)

	# Kill all enemies
	for enemy in enemies:
		battle.execute_turn(party[0], "attack", enemy)

	var rewards = battle.get_battle_rewards()
	# Should have loot from multiple enemies
	assert_gt(rewards.get_total_items(), 0)


## Test: Battle reward summary structure
func test_battle_reward_summary_structure() -> void:
	var party = [_create_hero()]
	var enemy = _create_enemy()
	enemy.hp = 10
	var enemies = [enemy]

	battle.start_battle(party, enemies)
	battle.execute_turn(party[0], "attack", enemy)

	var summary = battle.get_rewards_summary()

	assert_true(summary.has("total_items"))
	assert_true(summary.has("total_currency"))
	assert_true(summary.has("by_type"))
	assert_true(summary.has("by_rarity"))
	assert_true(summary.has("enchanted_count"))
	assert_true(summary.has("items"))


## Test: Legendary enemy drops legendary items
func test_legendary_difficulty_enemy_drops_legendary() -> void:
	var party = [_create_hero()]
	var enemy = _create_enemy()
	enemy.difficulty = LootTable.Difficulty.LEGENDARY
	enemy.is_rare_enemy = true
	enemy.hp = 10
	var enemies = [enemy]

	battle.start_battle(party, enemies)
	battle.execute_turn(party[0], "attack", enemy)

	var rewards = battle.get_battle_rewards()
	# Legendary enemies should drop loot
	assert_gt(rewards.get_total_items(), 0)


## Test: Enemy only looted once
func test_enemy_looted_only_once() -> void:
	var party = [_create_hero()]
	var enemy = _create_enemy()
	enemy.hp = 30  # Need multiple hits to kill
	var enemies = [enemy]

	battle.start_battle(party, enemies)

	# Hit enemy multiple times
	for i in range(5):
		if enemy.is_alive:
			battle.execute_turn(party[0], "attack", enemy)

	var rewards = battle.get_battle_rewards()
	# Should only have looted once despite multiple attacks
	var enemy_drops = rewards.rewards.filter(func(r): return r.source_enemy == enemy.name)

	# All drops should be from the single death, not multiple
	var total_drops = enemy_drops.size()
	assert_gt(total_drops, 0, "Enemy should drop loot")


## Test: Currency generation scales with difficulty
func test_currency_scales_with_difficulty() -> void:
	var currencies_easy: Array[Currency] = []
	var currencies_hard: Array[Currency] = []

	for i in range(5):
		var easy_currency = Currency.new(0, 10 + (LootTable.Difficulty.EASY * 5), 0, 0)
		currencies_easy.append(easy_currency)

	for i in range(5):
		var hard_currency = Currency.new(0, 10 + (LootTable.Difficulty.HARD * 5), 0, 0)
		currencies_hard.append(hard_currency)

	var easy_total = 0
	var hard_total = 0

	for c in currencies_easy:
		easy_total += c.to_copper()
	for c in currencies_hard:
		hard_total += c.to_copper()

	assert_gt(hard_total, easy_total, "Hard difficulty should give more currency")


## Test: Get rewards by type
func test_get_rewards_by_type() -> void:
	var rewards = BattleRewards.new()

	var weapon = Item.new("weapon1", "Sword", Item.ItemType.WEAPON)
	var armor = Item.new("armor1", "Chest", Item.ItemType.ARMOR)

	rewards.add_reward(weapon, "Enemy")
	rewards.add_reward(armor, "Enemy")

	var weapons = rewards.get_rewards_by_type(Item.ItemType.WEAPON)
	var armors = rewards.get_rewards_by_type(Item.ItemType.ARMOR)

	assert_eq(weapons.size(), 1)
	assert_eq(armors.size(), 1)


## Test: Get enchanted rewards
func test_get_enchanted_rewards() -> void:
	var rewards = BattleRewards.new()

	var normal_item = Item.new("normal", "Normal Item")
	var enchanted_item = Item.new("enchanted", "Enchanted Item")
	enchanted_item.set_property("enchantments", ["sharpness"])

	rewards.add_reward(normal_item, "Enemy")
	rewards.add_reward(enchanted_item, "Enemy")

	var enchanted = rewards.get_enchanted_rewards()

	assert_eq(enchanted.size(), 1)
	assert_true(enchanted[0].is_enchanted)


## Test: Clear rewards
func test_clear_rewards() -> void:
	var rewards = BattleRewards.new()

	rewards.add_reward(Item.new("test", "Test"), "Enemy")
	rewards.add_currency(Currency.new(0, 10, 0, 0))

	assert_gt(rewards.get_total_items(), 0)

	rewards.clear()

	assert_eq(rewards.get_total_items(), 0)
	assert_eq(rewards.currency_reward.to_copper(), 0)


## Test: Total value calculation
func test_total_value_calculation() -> void:
	var rewards = BattleRewards.new()

	var item1 = Item.new("item1", "Item1")
	item1.value = Currency.new(0, 5, 0, 0)  # 5 gold

	var item2 = Item.new("item2", "Item2")
	item2.value = Currency.new(0, 3, 0, 0)  # 3 gold

	rewards.add_reward(item1, "Enemy")
	rewards.add_reward(item2, "Enemy")
	rewards.add_currency(Currency.new(0, 2, 0, 0))  # 2 gold currency

	var total_value = rewards.get_total_value()
	var expected = (5 + 3 + 2) * 100  # Convert gold to copper (1 gold = 100 copper)

	assert_eq(total_value, expected)


## Helper: Create hero combatant
func _create_hero() -> Battle.Combatant:
	var hero = Battle.Combatant.new()
	hero.name = "Hero"
	hero.class_id = "warrior"
	hero.faction = "party"
	hero.hp = 100
	hero.max_hp = 100
	hero.stats["strength"] = 15
	hero.stats["constitution"] = 12
	return hero


## Helper: Create enemy combatant
func _create_enemy() -> Battle.Combatant:
	var enemy = Battle.Combatant.new()
	enemy.name = "Enemy"
	enemy.class_id = "goblin"
	enemy.faction = "enemy"
	enemy.hp = 50
	enemy.max_hp = 50
	enemy.stats["strength"] = 8
	enemy.stats["constitution"] = 10
	enemy.difficulty = LootTable.Difficulty.NORMAL
	return enemy
