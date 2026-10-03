## Battle Manager Animated: BattleManager with animation integration
##
## Extends BattleManager to trigger animations on combat actions
## Connects Battle engine logic to visual feedback layer

extends BattleManager


var battle_screen_animator: BattleScreenAnimator = null


func _init() -> void:
	super()


## Initialize battle with animations enabled
func start_battle_animated(party: Array[Battle.Combatant], enemies: Array[Battle.Combatant], screen_animator: BattleScreenAnimator) -> void:
	battle_screen_animator = screen_animator

	# Register combatants with animator
	for combatant in party:
		battle_screen_animator.combat_animator.register_combatant(combatant)
	for combatant in enemies:
		battle_screen_animator.combat_animator.register_combatant(combatant)

	# Start battle normally
	start_battle(party, enemies)


## Override _process_next_turn to add animations
func _process_next_turn_animated() -> void:
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
			_process_next_turn_animated()
		return

	current_player = next_combatant
	is_player_turn = next_combatant.faction == "party"

	# Trigger turn highlight animation
	if battle_screen_animator:
		battle_screen_animator.highlight_character_turn(next_combatant)

	combat_log.add_turn_change(next_combatant.name)

	if battle_screen:
		battle_screen.highlight_current_turn_character(next_combatant)

	if is_player_turn:
		if combat_controls:
			combat_controls.set_active_character(next_combatant)
	else:
		_execute_enemy_ai_turn_animated(next_combatant)


## Override enemy AI turn to add animations
func _execute_enemy_ai_turn_animated(enemy: Battle.Combatant) -> void:
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

	# Trigger ability animation
	if battle_screen_animator:
		var ability_type = _get_ability_type(action)
		var animator = battle_screen_animator.combat_animator.start_ability_animation(
			action,
			ability_type,
			enemy,
			target
		)
		# Would normally await animator completion, but for now continues

	# Execute action
	var result = battle.execute_turn(enemy, action, target)

	# Trigger damage/effect animations
	_animate_action_result(enemy, target, action, result)

	_log_action_result(enemy, action, target, result)
	turn_executed.emit(enemy, action, result)

	battle._check_battle_end()
	_advance_turn()


## Override player action execution to add animations
func _on_action_executed_animated(action_data: Dictionary) -> void:
	if not is_player_turn or not current_player:
		return

	var action = action_data.get("action", "")
	var target = action_data.get("target", null)

	if action.is_empty() or not target:
		return

	# Trigger ability animation
	if battle_screen_animator:
		var ability_type = _get_ability_type(action)
		var animator = battle_screen_animator.combat_animator.start_ability_animation(
			action,
			ability_type,
			current_player,
			target
		)

	# Execute action
	var result = battle.execute_turn(current_player, action, target)

	# Trigger damage/effect animations
	_animate_action_result(current_player, target, action, result)

	_log_action_result(current_player, action, target, result)
	turn_executed.emit(current_player, action, result)

	battle._check_battle_end()
	_advance_turn()


## Animate action results (damage, healing, effects)
func _animate_action_result(actor: Battle.Combatant, target: Battle.Combatant, action: String, result: Dictionary) -> void:
	if not battle_screen_animator:
		return

	match action.to_lower():
		"attack":
			var damage = result.get("damage", 0)
			var is_crit = result.get("critical", false)
			if damage > 0:
				# Show damage popup at target position
				battle_screen_animator.show_damage(damage, _get_combatant_position(target), is_crit)
				# Animate health bar
				battle_screen_animator.animate_health_change(target, target.hp)

		"defend":
			# Show defense buff effect
			battle_screen_animator.show_status_effect(actor, "defense_up")
			battle_screen_animator.animate_health_change(actor, actor.hp)

		"cast_spell":
			var healing = result.get("healing", 0)
			if healing > 0:
				battle_screen_animator.show_healing(healing, _get_combatant_position(target))
				battle_screen_animator.animate_health_change(target, target.hp)
			else:
				var damage = result.get("damage", 0)
				if damage > 0:
					battle_screen_animator.show_damage(damage, _get_combatant_position(target))
					battle_screen_animator.animate_health_change(target, target.hp)

		"use_item":
			var healing = result.get("healing", 0)
			if healing > 0:
				battle_screen_animator.show_healing(healing, _get_combatant_position(target))
				battle_screen_animator.animate_health_change(target, target.hp)


## Get ability type for animation
func _get_ability_type(action: String) -> AbilityAnimator.AbilityType:
	match action.to_lower():
		"attack":
			return AbilityAnimator.AbilityType.ATTACK
		"cast_spell":
			return AbilityAnimator.AbilityType.SPELL
		"defend":
			return AbilityAnimator.AbilityType.BUFF
		"use_item":
			return AbilityAnimator.AbilityType.UTILITY
		_:
			return AbilityAnimator.AbilityType.ATTACK


## Get screen position for combatant (placeholder)
func _get_combatant_position(combatant: Battle.Combatant) -> Vector2:
	# This would return actual screen position from battle_screen
	# For now, returns center of screen
	return Vector2(640, 360)
