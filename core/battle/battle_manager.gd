## Battle Manager: Orchestrates battle system with UI layer
##
## Connects Battle engine to UI screens (BattleScreen, CombatControls, CombatLog, BattleRewards)
## Handles turn execution, player input, enemy AI, and battle flow

class_name BattleManager


signal battle_started(battle: Battle)
signal turn_executed(combatant: Battle.Combatant, action: String, result: Dictionary)
signal round_complete(round: int)
signal battle_ended(player_won: bool, rewards: BattleRewards)


var battle: Battle
var battle_screen: BattleScreen
var combat_controls: CombatControls
var combat_log: CombatLog
var battle_rewards_ui: BattleRewards

var is_player_turn: bool = false
var current_player: Battle.Combatant = null
var pending_action: Dictionary = {}
var battle_in_progress: bool = false


func _init() -> void:
	battle = Battle.new()


## Initialize battle with party and enemies
func start_battle(party: Array[Battle.Combatant], enemies: Array[Battle.Combatant]) -> void:
	battle.start_battle(party, enemies)
	battle_in_progress = true
	pending_action = {}

	_initialize_ui_screens()
	_connect_ui_signals()
	_initialize_ui_state()

	battle_started.emit(battle)

	# Start first turn
	_process_next_turn()


## Create all UI screen instances
func _initialize_ui_screens() -> void:
	battle_screen = BattleScreen.new()
	battle_screen.battle = battle

	combat_controls = CombatControls.new(battle)
	combat_log = CombatLog.new()
	battle_rewards_ui = BattleRewards.new()


## Connect UI signals to manager methods
func _connect_ui_signals() -> void:
	# Combat Controls → Manager
	if combat_controls.action_executed.is_connected(_on_action_executed):
		combat_controls.action_executed.disconnect(_on_action_executed)
	combat_controls.action_executed.connect(_on_action_executed)

	if combat_controls.action_cancelled.is_connected(_on_action_cancelled):
		combat_controls.action_cancelled.disconnect(_on_action_cancelled)
	combat_controls.action_cancelled.connect(_on_action_cancelled)

	# Battle Screen → Manager (for enemy selection in some contexts)
	if battle_screen.action_selected.is_connected(_on_battle_screen_action):
		battle_screen.action_selected.disconnect(_on_battle_screen_action)
	battle_screen.action_selected.connect(_on_battle_screen_action)


## Initialize UI displays with current battle state
func _initialize_ui_state() -> void:
	if battle_screen:
		battle_screen.set_battle(battle)
		battle_screen.refresh_all_displays()

	if combat_log:
		combat_log.clear_log()
		combat_log.add_message("Battle started!", "turn", "System")
		combat_log.add_message("Round 1 begins", "turn", "System")


## Refresh all UI displays from current battle state
func refresh_all_displays() -> void:
	if battle_screen:
		battle_screen.refresh_all_displays()

	if combat_controls and current_player:
		combat_controls.set_active_character(current_player)
		combat_controls.refresh_ability_list()
		combat_controls.update_resource_display()


## Process next turn (player or AI)
func _process_next_turn() -> void:
	if battle.state.battle_over:
		_end_battle()
		return

	var next_combatant = battle.state.turn_order[battle.state.current_turn_index] if battle.state.turn_order.size() > battle.state.current_turn_index else null

	if not next_combatant or not next_combatant.is_alive:
		# Skip dead combatants
		battle.state.current_turn_index += 1
		if battle.state.current_turn_index >= battle.state.turn_order.size():
			_complete_round()
		else:
			_process_next_turn()
		return

	current_player = next_combatant
	is_player_turn = next_combatant.faction == "party"

	combat_log.add_turn_change(next_combatant.name)

	if battle_screen:
		battle_screen.highlight_current_turn_character(next_combatant)

	if is_player_turn:
		# Await player input
		if combat_controls:
			combat_controls.set_active_character(next_combatant)
	else:
		# Execute enemy AI turn
		_execute_enemy_ai_turn(next_combatant)


## Execute enemy AI action
func _execute_enemy_ai_turn(enemy: Battle.Combatant) -> void:
	# Simple AI: pick first valid action and random valid target
	var valid_actions = battle.get_valid_actions(enemy)
	if valid_actions.is_empty():
		_advance_turn()
		return

	var action = valid_actions[0]
	var valid_targets = battle.get_valid_targets(enemy, action)
	if valid_targets.is_empty():
		_advance_turn()
		return

	var target = valid_targets[randi() % valid_targets.size()]

	# Execute action
	var result = battle.execute_turn(enemy, action, target)
	_log_action_result(enemy, action, target, result)
	turn_executed.emit(enemy, action, result)

	# Check battle end
	battle._check_battle_end()

	_advance_turn()


## Handle player action execution
func _on_action_executed(action_data: Dictionary) -> void:
	if not is_player_turn or not current_player:
		return

	var action = action_data.get("action", "")
	var target = action_data.get("target", null)

	if action.is_empty() or not target:
		return

	# Execute action in battle system
	var result = battle.execute_turn(current_player, action, target)
	_log_action_result(current_player, action, target, result)
	turn_executed.emit(current_player, action, result)

	# Check battle end
	battle._check_battle_end()

	_advance_turn()


## Handle action cancellation
func _on_action_cancelled() -> void:
	# Player cancelled, stay on same turn (no action executed)
	if combat_controls and current_player:
		combat_controls.set_active_character(current_player)


## Handle battle screen action selection
func _on_battle_screen_action(action: String, target: Battle.Combatant) -> void:
	# Battle screen can also trigger actions (for quick selection, etc.)
	if is_player_turn:
		_on_action_executed({"action": action, "target": target})


## Log action result to combat log
func _log_action_result(actor: Battle.Combatant, action: String, target: Battle.Combatant, result: Dictionary) -> void:
	if not combat_log:
		return

	match action.to_lower():
		"attack":
			var damage = result.get("damage", 0)
			var is_crit = result.get("critical", false)
			combat_log.add_damage(actor.name, target.name, damage, is_crit)
		"defend":
			combat_log.add_message("%s braced for impact!" % actor.name, "buff", actor.name)
		"cast_spell":
			var spell_id = result.get("spell_id", "")
			combat_log.add_message("%s cast %s!" % [actor.name, spell_id], "buff", actor.name)
		"use_item":
			var item_id = result.get("item_id", "")
			combat_log.add_message("%s used %s!" % [actor.name, item_id], "info", actor.name)


## Advance to next turn
func _advance_turn() -> void:
	battle.state.current_turn_index += 1
	if battle.state.current_turn_index >= battle.state.turn_order.size():
		_complete_round()
	else:
		_process_next_turn()


## Complete round and start next
func _complete_round() -> void:
	battle.state.round += 1
	battle.state.current_turn_index = 0

	if combat_log:
		combat_log.add_turn_change("Round %d starts" % battle.state.round)

	round_complete.emit(battle.state.round)

	_process_next_turn()


## End battle and show rewards
func _end_battle() -> void:
	battle_in_progress = false
	var player_won = battle.state.player_won

	if combat_log:
		if player_won:
			combat_log.add_victory()
		else:
			combat_log.add_defeat()

	# Generate and display rewards
	var rewards = battle.get_battle_rewards()
	var rewards_summary = battle.get_rewards_summary()

	if battle_rewards_ui:
		battle_rewards_ui.set_rewards(
			rewards_summary.get("items", []),
			rewards_summary.get("currency", Currency.new()),
			rewards_summary.get("xp", {}),
			rewards_summary.get("combat_stats", {})
		)

	battle_ended.emit(player_won, rewards)


## Get current battle state
func get_state() -> Battle.CombatState:
	return battle.state


## Get battle rewards
func get_rewards() -> BattleRewards:
	return battle.get_battle_rewards()


## Get battle summary
func get_summary() -> Dictionary:
	return battle.get_summary()
