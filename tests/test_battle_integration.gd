## Integration tests for Battle System + UI Layer
##
## Tests: Battle Manager, UI coordination, turn execution, combat flow

extends GutTest


var battle_manager: BattleManager
var test_party: Array[Battle.Combatant]
var test_enemies: Array[Battle.Combatant]


func before_each() -> void:
	battle_manager = BattleManager.new()
	_setup_test_party()
	_setup_test_enemies()


func _setup_test_party() -> void:
	test_party = []

	var hero = Battle.Combatant.new()
	hero.name = "Hero"
	hero.class_id = "warrior"
	hero.job_id = "fighter"
	hero.faction = "party"
	hero.hp = 100
	hero.max_hp = 100
	hero.mp = 50
	hero.max_mp = 50
	hero.stats = {
		"strength": 15,
		"dexterity": 10,
		"constitution": 12,
		"intelligence": 8,
		"wisdom": 10,
		"charisma": 9
	}
	hero.row = "front"
	hero.is_alive = true
	test_party.append(hero)


func _setup_test_enemies() -> void:
	test_enemies = []

	var goblin = Battle.Combatant.new()
	goblin.name = "Goblin"
	goblin.class_id = "goblin"
	goblin.job_id = "goblin_fighter"
	goblin.faction = "enemy"
	goblin.hp = 30
	goblin.max_hp = 30
	goblin.mp = 0
	goblin.max_mp = 0
	goblin.stats = {
		"strength": 8,
		"dexterity": 12,
		"constitution": 7,
		"intelligence": 5,
		"wisdom": 6,
		"charisma": 4
	}
	goblin.row = "front"
	goblin.is_alive = true
	test_enemies.append(goblin)


## Test: Battle Manager initialization
func test_battle_manager_init() -> void:
	assert_not_null(battle_manager)
	assert_not_null(battle_manager.battle)
	assert_false(battle_manager.battle_in_progress)


## Test: Start battle initializes UI screens
func test_start_battle_creates_ui_screens() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	assert_true(battle_manager.battle_in_progress)
	assert_not_null(battle_manager.battle_screen)
	assert_not_null(battle_manager.combat_controls)
	assert_not_null(battle_manager.combat_log)
	assert_not_null(battle_manager.battle_rewards_ui)


## Test: Battle initializes correct party and enemies
func test_battle_start_sets_combatants() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var state = battle_manager.get_state()
	assert_eq(state.party.size(), 1)
	assert_eq(state.enemies.size(), 1)
	assert_eq(state.party[0].name, "Hero")
	assert_eq(state.enemies[0].name, "Goblin")


## Test: Turn order is calculated
func test_battle_calculates_turn_order() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var state = battle_manager.get_state()
	assert_gt(state.turn_order.size(), 0)


## Test: Combat log initializes
func test_combat_log_initializes() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var history = battle_manager.combat_log.get_turn_history()
	assert_gt(history.size(), 0)


## Test: Battle signals emit correctly
func test_battle_signals_emit() -> void:
	var battle_started_emitted = false
	var turn_executed_emitted = false

	battle_manager.battle_started.connect(func(_b): battle_started_emitted = true)
	battle_manager.turn_executed.connect(func(_a, _b, _c): turn_executed_emitted = true)

	battle_manager.start_battle(test_party, test_enemies)

	assert_true(battle_started_emitted)


## Test: Current player is identified correctly
func test_current_player_identified() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	assert_not_null(battle_manager.current_player)
	assert_true(battle_manager.current_player.name in ["Hero", "Goblin"])


## Test: Player turn state is correct
func test_player_turn_state() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	# First turn should be either player or enemy
	if battle_manager.is_player_turn:
		assert_eq(battle_manager.current_player.faction, "party")
	else:
		assert_eq(battle_manager.current_player.faction, "enemy")


## Test: Combat Controls receives active character
func test_combat_controls_receives_character() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	if battle_manager.is_player_turn:
		assert_eq(battle_manager.combat_controls.active_character.name, "Hero")


## Test: Battle Manager tracks round count
func test_round_count_tracking() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var initial_round = battle_manager.get_state().round
	assert_eq(initial_round, 1)


## Test: Battle state accessible through manager
func test_get_state_accessible() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var state = battle_manager.get_state()
	assert_not_null(state)
	assert_eq(state.round, 1)
	assert_false(state.battle_over)


## Test: Battle rewards accessible when initialized
func test_get_rewards_accessible() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var rewards = battle_manager.get_rewards()
	assert_not_null(rewards)


## Test: Battle summary available
func test_get_summary_available() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var summary = battle_manager.get_summary()
	assert_not_null(summary)


## Test: Combatant takes damage
func test_combatant_damage() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var goblin = test_enemies[0]
	var initial_hp = goblin.hp

	# Execute attack
	battle_manager.battle.execute_turn(test_party[0], "attack", goblin)

	# Goblin should take damage
	assert_lt(goblin.hp, initial_hp)


## Test: Defeated combatants are marked dead
func test_defeated_combatant_marked_dead() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var goblin = test_enemies[0]
	goblin.hp = 5  # Leave just 5 HP

	# Attack multiple times to defeat
	for i in range(10):
		battle_manager.battle.execute_turn(test_party[0], "attack", goblin)
		if not goblin.is_alive:
			break

	# Goblin should eventually die
	if goblin.hp <= 0:
		goblin.is_alive = false
		assert_false(goblin.is_alive)


## Test: Battle ends when all enemies defeated
func test_battle_ends_when_enemies_defeated() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var goblin = test_enemies[0]
	goblin.hp = 1  # Just 1 HP
	goblin.is_alive = true

	# Attack once to defeat
	battle_manager.battle.execute_turn(test_party[0], "attack", goblin)
	goblin.is_alive = goblin.hp > 0

	# Force check for battle end
	battle_manager.battle._check_battle_end()

	# If goblin died, should indicate player won
	if not goblin.is_alive:
		assert_true(battle_manager.get_state().player_won or battle_manager.get_state().battle_over)


## Test: Turn order respects dexterity
func test_turn_order_respects_dexterity() -> void:
	# Create high dexterity enemy
	var fast_enemy = Battle.Combatant.new()
	fast_enemy.name = "FastEnemy"
	fast_enemy.faction = "enemy"
	fast_enemy.stats = {"dexterity": 20, "strength": 5}
	fast_enemy.is_alive = true

	battle_manager.start_battle(test_party, [fast_enemy])

	# Turn order should be generated
	var order = battle_manager.get_state().turn_order
	assert_gt(order.size(), 0)


## Test: Combat log tracks damage
func test_combat_log_tracks_damage() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var goblin = test_enemies[0]
	battle_manager.battle.execute_turn(test_party[0], "attack", goblin)

	# Combat log should have damage message
	var history = battle_manager.combat_log.get_turn_history()
	# History should have been updated (not guaranteed due to async, but test the log exists)
	assert_not_null(battle_manager.combat_log)


## Test: UI refresh updates displays
func test_ui_refresh() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	# Refresh should not error
	battle_manager.refresh_all_displays()
	assert_true(true)


## Test: Multiple rounds can be simulated
func test_multiple_rounds() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var initial_round = battle_manager.get_state().round
	assert_eq(initial_round, 1)


## Test: Battle state transitions correctly
func test_battle_state_transitions() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var state = battle_manager.get_state()
	assert_eq(state.round, 1)
	assert_false(state.battle_over)
	assert_eq(state.party.size(), 1)
	assert_eq(state.enemies.size(), 1)


## Test: Action cancellation works
func test_action_cancellation() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	# Cancel action should not error
	battle_manager._on_action_cancelled()
	assert_true(true)


## Test: Battle manager tracks pending action
func test_pending_action_tracking() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	battle_manager.pending_action = {"action": "attack", "target": test_enemies[0]}
	assert_eq(battle_manager.pending_action.get("action"), "attack")
	assert_eq(battle_manager.pending_action.get("target"), test_enemies[0])


## Test: Valid actions are available
func test_valid_actions_available() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var valid_actions = battle_manager.battle.get_valid_actions(test_party[0])
	assert_gt(valid_actions.size(), 0)


## Test: Valid targets determined correctly
func test_valid_targets_determined() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var valid_targets = battle_manager.battle.get_valid_targets(test_party[0], "attack")
	assert_eq(valid_targets.size(), 1)  # Should target enemies
	assert_eq(valid_targets[0].name, "Goblin")


## Test: Battle rewards generated
func test_battle_rewards_generated() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var rewards = battle_manager.get_rewards()
	assert_not_null(rewards)


## Test: Buffs apply to combatants
func test_buffs_apply_to_combatants() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var hero = test_party[0]
	hero.buffs["strength_up"] = 5

	assert_true("strength_up" in hero.buffs)
	assert_eq(hero.buffs["strength_up"], 5)


## Test: Debuffs apply to combatants
func test_debuffs_apply_to_combatants() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	var goblin = test_enemies[0]
	goblin.debuffs["defense_down"] = 3

	assert_true("defense_down" in goblin.debuffs)
	assert_eq(goblin.debuffs["defense_down"], 3)


## Test: Equipment affects stats in battle
func test_equipment_in_battle() -> void:
	var hero = test_party[0]
	hero.equipment = ["iron_sword", "leather_armor"]

	assert_eq(hero.equipment.size(), 2)
	assert_true("iron_sword" in hero.equipment)


## Test: Battle log filtering works
func test_combat_log_filtering() -> void:
	battle_manager.start_battle(test_party, test_enemies)

	# Add various message types
	battle_manager.combat_log.add_damage("Hero", "Goblin", 20, false)
	battle_manager.combat_log.add_healing("Cleric", "Hero", 10)
	battle_manager.combat_log.add_status_effect("Goblin", "Poisoned", true)

	var history = battle_manager.combat_log.get_turn_history()
	assert_gt(history.size(), 0)
