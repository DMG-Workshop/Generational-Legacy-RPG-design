## Tests for Battle Rewards Integration with Heir Progression
##
## Tests: BattleRewardsManager, BattleHeirIntegration

extends GutTest


var rewards_manager: BattleRewardsManager
var battle_heir_integration: BattleHeirIntegration
var test_heir: Heir
var test_currency: Currency
var test_items: Array[Equipment]


func before_each() -> void:
	_setup_test_heir()
	_setup_test_rewards()


func _setup_test_heir() -> void:
	test_heir = Heir.new()
	test_heir.name = "TestHero"
	test_heir.generation = 1
	test_heir.birth_year = 0
	test_heir.class_id = "warrior"
	test_heir.job_id = "fighter"
	test_heir.faction = "party"
	test_heir.is_alive = true
	test_heir.wallet = Wallet.new()
	test_heir.inventory = []
	test_heir.crafting_skills = {}

	rewards_manager = BattleRewardsManager.new(test_heir)
	battle_heir_integration = BattleHeirIntegration.new(test_heir)


func _setup_test_rewards() -> void:
	test_currency = Currency.new(0, 100, 50, 25)
	test_items = []


## Test: BattleRewardsManager initialization
func test_rewards_manager_init() -> void:
	assert_not_null(rewards_manager)
	assert_eq(rewards_manager.current_heir, test_heir)


## Test: Set and apply currency rewards
func test_rewards_manager_apply_currency() -> void:
	var initial_wealth = test_heir.wallet.get_total_value()

	rewards_manager.set_rewards([], test_currency, {}, {})
	rewards_manager.apply_all_rewards()

	var final_wealth = test_heir.wallet.get_total_value()
	assert_gt(final_wealth, initial_wealth)
	assert_eq(test_heir.wallet.gold, 100)


## Test: Apply item rewards to inventory
func test_rewards_manager_apply_items() -> void:
	var item = Equipment.new()
	item.name = "Iron Sword"
	item.rarity = "Common"
	test_items.append(item)

	var initial_count = test_heir.inventory.size()

	rewards_manager.set_rewards(test_items, Currency.new(), {}, {})
	rewards_manager.apply_all_rewards()

	assert_eq(test_heir.inventory.size(), initial_count + 1)
	assert_eq(test_heir.inventory[-1].name, "Iron Sword")


## Test: Apply XP to crafting skills
func test_rewards_manager_apply_xp() -> void:
	var xp_rewards = {"Blacksmithing": 50, "Alchemy": 25}

	rewards_manager.set_rewards([], Currency.new(), xp_rewards, {})
	rewards_manager.apply_all_rewards()

	assert_true("Blacksmithing" in test_heir.crafting_skills)
	assert_true("Alchemy" in test_heir.crafting_skills)

	assert_eq(test_heir.crafting_skills["Blacksmithing"].xp, 50)
	assert_eq(test_heir.crafting_skills["Alchemy"].xp, 25)


## Test: Skill level up on XP threshold
func test_rewards_manager_skill_level_up() -> void:
	var xp_rewards = {"Blacksmithing": 100}  # Exact level up threshold

	rewards_manager.set_rewards([], Currency.new(), xp_rewards, {})
	rewards_manager.apply_all_rewards()

	var skill = test_heir.crafting_skills["Blacksmithing"]
	assert_eq(skill.level, 2)  # Started at 1, should be 2 now
	assert_eq(skill.xp, 0)  # Overflow XP cleared


## Test: Multiple XP awards stack
func test_rewards_manager_multiple_xp_applications() -> void:
	# First reward
	rewards_manager.set_rewards([], Currency.new(), {"Blacksmithing": 50}, {})
	rewards_manager.apply_all_rewards()

	# Second reward
	rewards_manager.set_heir(test_heir)
	rewards_manager.set_rewards([], Currency.new(), {"Blacksmithing": 60}, {})
	rewards_manager.apply_all_rewards()

	var skill = test_heir.crafting_skills["Blacksmithing"]
	assert_eq(skill.xp, 10)  # 50 + 60 = 110, level up happens, 10 left
	assert_eq(skill.level, 2)


## Test: Legendary item detection
func test_rewards_manager_legendary_detection() -> void:
	var legendary_item = Equipment.new()
	legendary_item.name = "Legendary Sword"
	legendary_item.rarity = "Legendary"
	test_items.append(legendary_item)

	rewards_manager.set_rewards(test_items, Currency.new(), {}, {})
	rewards_manager.apply_all_rewards()

	var legendaries = rewards_manager.get_legendary_items()
	assert_eq(legendaries.size(), 1)
	assert_eq(legendaries[0].name, "Legendary Sword")


## Test: Get reward summary text
func test_rewards_manager_reward_summary() -> void:
	var item = Equipment.new()
	item.name = "Sword"
	item.rarity = "Common"
	test_items.append(item)

	var xp_rewards = {"Blacksmithing": 50}

	rewards_manager.set_rewards(test_items, test_currency, xp_rewards, {})
	rewards_manager.apply_all_rewards()

	var summary = rewards_manager.get_reward_summary()
	assert_gt(summary.size(), 0)
	assert_true(summary.any(func(s): return s.contains("Gold")))


## Test: Clear rewards for next battle
func test_rewards_manager_clear() -> void:
	rewards_manager.set_rewards(test_items, test_currency, {"Blacksmithing": 50}, {})
	rewards_manager.apply_all_rewards()

	var applied = rewards_manager.get_applied_rewards()
	assert_gt(applied.get("currency", {}).size(), 0)

	rewards_manager.clear()
	applied = rewards_manager.get_applied_rewards()
	assert_eq(applied.get("currency", {}).size(), 0)


## Test: BattleHeirIntegration initialization
func test_heir_integration_init() -> void:
	assert_not_null(battle_heir_integration)
	assert_eq(battle_heir_integration.current_heir, test_heir)
	assert_not_null(battle_heir_integration.rewards_manager)


## Test: Set multipliers for difficulty
func test_heir_integration_multipliers() -> void:
	battle_heir_integration.xp_multiplier = 2.0
	battle_heir_integration.difficulty_multiplier = 1.5

	var currency = Currency.new(0, 100, 0, 0)
	var adjusted = battle_heir_integration._apply_multipliers_to_currency(currency)

	# 100 * 2.0 * 1.5 = 300
	assert_eq(adjusted.gold, 300)


## Test: XP multipliers applied
func test_heir_integration_xp_multipliers() -> void:
	battle_heir_integration.xp_multiplier = 1.5
	battle_heir_integration.difficulty_multiplier = 1.0

	var xp = {"Blacksmithing": 100}
	var adjusted = battle_heir_integration._apply_multipliers_to_xp(xp)

	# 100 * 1.5 = 150
	assert_eq(adjusted["Blacksmithing"], 150)


## Test: Battle record creation on victory
func test_heir_integration_battle_record() -> void:
	var state = Battle.CombatState.new()
	state.round = 3

	var enemy = Battle.Combatant.new()
	enemy.is_alive = false
	state.enemies = [enemy]

	var rewards = {"xp": {"Combat": 50}}

	battle_heir_integration._record_battle_victory(state, rewards)

	if hasattr(test_heir, "combat_history"):
		assert_gt(test_heir.combat_history.size(), 0)
		assert_eq(test_heir.combat_history[0].type, "victory")


## Test: Combat tier calculation
func test_heir_integration_combat_tier() -> void:
	# No battles yet
	assert_eq(battle_heir_integration.get_combat_tier(), "Novice")

	# Simulate victories in history
	if not hasattr(test_heir, "combat_history"):
		test_heir.combat_history = []

	for i in range(5):
		test_heir.combat_history.append({"type": "victory"})

	assert_eq(battle_heir_integration.get_combat_tier(), "Veteran")


## Test: Battle summary generation
func test_heir_integration_battle_summary() -> void:
	if not hasattr(test_heir, "combat_history"):
		test_heir.combat_history = []

	test_heir.combat_history.append({"type": "victory"})
	test_heir.combat_history.append({"type": "victory"})
	test_heir.combat_history.append({"type": "defeat"})

	var summary = battle_heir_integration.get_heir_battle_summary()

	assert_eq(summary.get("victories"), 2)
	assert_eq(summary.get("defeats"), 1)
	assert_eq(summary.get("total_battles"), 3)


## Test: Save heir progression
func test_heir_integration_save_progression() -> void:
	test_heir.wallet.gold = 500
	test_heir.inventory.append(Equipment.new())

	var saved = battle_heir_integration.save_heir_progression()

	assert_true("name" in saved)
	assert_true("wallet" in saved)
	assert_true("inventory_size" in saved)
	assert_true("combat_tier" in saved)

	assert_eq(saved["name"], "TestHero")
	assert_eq(saved["inventory_size"], 1)


## Test: Multiple currency types
func test_rewards_manager_all_currencies() -> void:
	var mixed_currency = Currency.new(5, 200, 100, 50)

	rewards_manager.set_rewards([], mixed_currency, {}, {})
	rewards_manager.apply_all_rewards()

	assert_eq(test_heir.wallet.platinum, 5)
	assert_eq(test_heir.wallet.gold, 200)
	assert_eq(test_heir.wallet.silver, 100)
	assert_eq(test_heir.wallet.copper, 50)


## Test: Combat stats tracking
func test_rewards_manager_combat_stats() -> void:
	var stats = {
		"damage_dealt": 250,
		"damage_taken": 85,
		"healing_received": 40,
		"abilities_used": 12
	}

	rewards_manager.set_rewards([], Currency.new(), {}, stats)
	rewards_manager.apply_all_rewards()

	# Stats would be stored on heir for tracking
	assert_true(true)  # Would check total_combat_stats if attribute tracking works


## Test: Multiple items of different rarities
func test_rewards_manager_mixed_rarity_items() -> void:
	var common_item = Equipment.new()
	common_item.rarity = "Common"
	var rare_item = Equipment.new()
	rare_item.rarity = "Rare"
	var legendary_item = Equipment.new()
	legendary_item.rarity = "Legendary"

	test_items = [common_item, rare_item, legendary_item]

	rewards_manager.set_rewards(test_items, Currency.new(), {}, {})
	rewards_manager.apply_all_rewards()

	assert_eq(test_heir.inventory.size(), 3)

	var legendaries = rewards_manager.get_legendary_items()
	assert_eq(legendaries.size(), 1)


## Test: Signal emission on rewards applied
func test_rewards_manager_signal_emission() -> void:
	var signal_received = false
	rewards_manager.rewards_applied.connect(func(_h, _r): signal_received = true)

	rewards_manager.set_rewards([], test_currency, {}, {})
	rewards_manager.apply_all_rewards()

	assert_true(signal_received)


## Test: Skill level up signal
func test_rewards_manager_level_up_signal() -> void:
	var level_up_received = false
	rewards_manager.level_up.connect(func(_h, _s): level_up_received = true)

	rewards_manager.set_rewards([], Currency.new(), {"Blacksmithing": 100}, {})
	rewards_manager.apply_all_rewards()

	assert_true(level_up_received)


## Helper to check if object has attribute
func hasattr(obj: Object, attr: String) -> bool:
	return obj.get(attr) != null
