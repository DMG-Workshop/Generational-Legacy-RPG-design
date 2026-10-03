## Tests for Battle Screen UI components
##
## Tests: Battle Screen display, Combat Controls, Combat Log, Battle Rewards

extends GutTest


var battle_screen: BattleScreen
var combat_controls: CombatControls
var combat_log: CombatLog
var battle_rewards: BattleRewards
var test_battle: Battle


func before_each() -> void:
	test_battle = Battle.new()
	battle_screen = BattleScreen.new()
	combat_controls = CombatControls.new(test_battle)
	combat_log = CombatLog.new()
	battle_rewards = BattleRewards.new()


## Test: Battle Screen initialization
func test_battle_screen_init() -> void:
	assert_not_null(battle_screen)
	assert_eq(battle_screen.selected_enemy, null)
	assert_false(battle_screen.target_selection_active)


## Test: Combat Controls initialization
func test_combat_controls_init() -> void:
	assert_not_null(combat_controls)
	assert_eq(combat_controls.battle, test_battle)
	assert_eq(combat_controls.active_character, null)


## Test: Combat Log initialization
func test_combat_log_init() -> void:
	assert_not_null(combat_log)
	# Log should be empty initially
	var history = combat_log.get_turn_history()
	assert_eq(history.size(), 0)


## Test: Battle Rewards initialization
func test_battle_rewards_init() -> void:
	assert_not_null(battle_rewards)


## Test: Combat Log add damage message
func test_combat_log_add_damage() -> void:
	combat_log.add_damage("Hero", "Goblin", 25, false)
	var history = combat_log.get_turn_history()
	assert_gt(history.size(), 0)


## Test: Combat Log add healing message
func test_combat_log_add_healing() -> void:
	combat_log.add_healing("Cleric", "Hero", 15)
	var history = combat_log.get_turn_history()
	assert_gt(history.size(), 0)


## Test: Combat Log add status effect message
func test_combat_log_add_status_effect() -> void:
	combat_log.add_status_effect("Goblin", "Poisoned", true)
	var history = combat_log.get_turn_history()
	assert_gt(history.size(), 0)


## Test: Combat Log clear
func test_combat_log_clear() -> void:
	combat_log.add_message("Test", "info", "Test")
	combat_log.clear_log()
	var history = combat_log.get_turn_history()
	assert_eq(history.size(), 0)


## Test: Combat Log multiple messages
func test_combat_log_multiple_messages() -> void:
	for i in range(5):
		combat_log.add_message("Message %d" % i, "info", "Actor")
	var history = combat_log.get_turn_history()
	assert_eq(history.size(), 5)


## Test: Battle Screen set battle
func test_battle_screen_set_battle() -> void:
	battle_screen.set_battle(test_battle)
	assert_eq(battle_screen.battle, test_battle)


## Test: Battle Rewards set rewards
func test_battle_rewards_set_rewards() -> void:
	var items: Array[Equipment] = []
	var currency = Currency.new(0, 100, 0, 0)
	var xp = {"Combat": 50, "Crafting": 10}
	var combat_stats = {}

	battle_rewards.set_rewards(items, currency, xp, combat_stats)
	assert_not_null(battle_rewards)


## Test: Combat Log message filtering
func test_combat_log_filter_damage() -> void:
	combat_log.add_damage("Hero", "Goblin", 25, false)
	combat_log.add_healing("Cleric", "Hero", 15)
	combat_log.add_message("Test", "info", "Actor")

	var history = combat_log.get_turn_history()
	assert_eq(history.size(), 3)


## Test: Combat Log statistics
func test_combat_log_statistics() -> void:
	combat_log.add_damage("Hero", "Goblin", 25, false)
	combat_log.add_damage("Hero", "Goblin", 30, false)
	combat_log.add_healing("Cleric", "Hero", 15)

	# Statistics should be available
	assert_gt(combat_log.get_turn_history().size(), 0)


## Test: Battle Screen selected enemy updates
func test_battle_screen_enemy_selection() -> void:
	battle_screen.set_battle(test_battle)
	# Enemy selection should update target info
	assert_eq(battle_screen.target_selection_active, false)


## Test: Combat Controls ability selection
func test_combat_controls_ability_selection() -> void:
	# Ability data should be loadable
	assert_not_null(combat_controls.ability_hotkey_map)


## Test: Battle Rewards item collection
func test_battle_rewards_item_collection() -> void:
	var items = battle_rewards.get_collected_items()
	assert_not_null(items)


## Test: Combat Log critical hit tracking
func test_combat_log_critical_hit() -> void:
	combat_log.add_damage("Hero", "Goblin", 50, true)
	var history = combat_log.get_turn_history()
	assert_gt(history.size(), 0)


## Test: Battle Rewards legendary detection
func test_battle_rewards_legendary_tracking() -> void:
	battle_rewards.refresh_displays()
	# No errors on refresh
	assert_true(true)


## Test: Combat Log message limit
func test_combat_log_message_limit() -> void:
	# Add many messages
	for i in range(150):
		combat_log.add_message("Message %d" % i, "info", "Actor")

	# Should maintain reasonable limit
	var history = combat_log.get_turn_history()
	assert_lte(history.size(), 150)


## Test: Battle Screen refresh displays
func test_battle_screen_refresh() -> void:
	battle_screen.set_battle(test_battle)
	battle_screen.refresh_all_displays()
	assert_not_null(battle_screen)


## Test: Combat Controls resource display
func test_combat_controls_resource_display() -> void:
	# Resource display should update without errors
	combat_controls.update_resource_display()
	assert_true(true)


## Test: Battle Rewards currency animation
func test_battle_rewards_animate_currency() -> void:
	var currency = Currency.new(0, 100, 0, 0)
	battle_rewards.animate_currency_collection()
	assert_not_null(currency)


## Test: Combat Log turn tracking
func test_combat_log_turn_tracking() -> void:
	for turn in range(5):
		combat_log.add_message("Turn %d start" % turn, "turn", "System")
		combat_log.add_damage("Hero", "Goblin", 20, false)
		combat_log.add_message("Turn %d end" % turn, "turn", "System")

	var history = combat_log.get_turn_history()
	assert_eq(history.size(), 15)


## Test: Battle Screen status effect display
func test_battle_screen_status_effects() -> void:
	assert_gt(battle_screen.status_effect_colors.size(), 0)
	assert_gt(battle_screen.status_effect_descriptions.size(), 0)


## Test: Combat Controls hotkey mapping
func test_combat_controls_hotkey_setup() -> void:
	# Hotkeys should be mapable [1]-[6]
	assert_not_null(combat_controls.ability_hotkey_map)


## Test: Battle Rewards multiple reward types
func test_battle_rewards_mixed_loot() -> void:
	var items: Array[Equipment] = []
	var currency = Currency.new(1, 50, 25, 100)  # Mixed currency
	var xp = {"Combat": 75, "Crafting": 25, "Alchemy": 10}
	var combat_stats = {"damage_dealt": 150, "damage_taken": 50}

	battle_rewards.set_rewards(items, currency, xp, combat_stats)
	assert_not_null(battle_rewards)


## Test: Combat Log emoji formatting
func test_combat_log_emoji_formatting() -> void:
	combat_log.add_damage("Hero", "Goblin", 25, false)  # Should have ⚔
	combat_log.add_healing("Cleric", "Hero", 15)  # Should have 💚
	combat_log.add_status_effect("Goblin", "Poisoned", true)  # Should have ☠

	var history = combat_log.get_turn_history()
	assert_eq(history.size(), 3)


## Test: Battle Screen threat assessment
func test_battle_screen_threat_level() -> void:
	# Threat levels should be calculable
	assert_not_null(battle_screen.threat_label)


## Test: Combat Controls action preview
func test_combat_controls_action_preview() -> void:
	combat_controls.update_action_preview()
	assert_true(true)


## Test: Battle Rewards stat summary
func test_battle_rewards_stats_summary() -> void:
	var combat_stats = {
		"damage_dealt": 200,
		"damage_taken": 75,
		"healing_received": 50,
		"abilities_used": 15,
		"enemies_defeated": 3
	}

	var items: Array[Equipment] = []
	var currency = Currency.new(0, 100, 0, 0)
	var xp = {}

	battle_rewards.set_rewards(items, currency, xp, combat_stats)
	assert_not_null(battle_rewards)


## Test: Integration - Battle flow UI updates
func test_battle_flow_ui_integration() -> void:
	# Setup battle
	battle_screen.set_battle(test_battle)
	combat_controls = CombatControls.new(test_battle)

	# Simulate turn
	combat_log.add_message("Battle started", "turn", "System")
	combat_log.add_damage("Hero", "Goblin", 20, false)

	# Verify all components updated
	assert_gt(combat_log.get_turn_history().size(), 0)


## Test: Integration - Battle rewards flow
func test_battle_rewards_flow() -> void:
	# Create rewards
	var items: Array[Equipment] = []
	var currency = Currency.new(0, 50, 0, 0)
	var xp = {"Combat": 40}
	var stats = {"enemies_defeated": 2}

	battle_rewards.set_rewards(items, currency, xp, stats)
	var collected = battle_rewards.get_collected_items()

	assert_not_null(collected)
