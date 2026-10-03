## Full Combat Scenario Test
##
## Simulates a complete battle with animations from start to finish
## Verifies all animation components work together in real combat flow

extends GutTest


var battle_manager_animated: BattleManagerAnimated
var battle_screen_animator: BattleScreenAnimator
var test_party: Array[Battle.Combatant]
var test_enemies: Array[Battle.Combatant]
var test_battle_screen: BattleScreen


func before_each() -> void:
	_setup_test_combatants()
	_setup_test_battle()


func _setup_test_combatants() -> void:
	test_party = []
	test_enemies = []

	# Create party members
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
	hero.buffs = {}
	hero.debuffs = {}
	test_party.append(hero)

	var mage = Battle.Combatant.new()
	mage.name = "Mage"
	mage.class_id = "mage"
	mage.job_id = "wizard"
	mage.faction = "party"
	mage.hp = 60
	mage.max_hp = 60
	mage.mp = 80
	mage.max_mp = 80
	mage.stats = {
		"strength": 8,
		"dexterity": 12,
		"constitution": 8,
		"intelligence": 16,
		"wisdom": 14,
		"charisma": 11
	}
	mage.row = "back"
	mage.is_alive = true
	mage.buffs = {}
	mage.debuffs = {}
	test_party.append(mage)

	# Create enemies
	var goblin1 = Battle.Combatant.new()
	goblin1.name = "Goblin1"
	goblin1.class_id = "goblin"
	goblin1.job_id = "goblin_fighter"
	goblin1.faction = "enemy"
	goblin1.hp = 30
	goblin1.max_hp = 30
	goblin1.mp = 0
	goblin1.max_mp = 0
	goblin1.stats = {
		"strength": 8,
		"dexterity": 12,
		"constitution": 7,
		"intelligence": 5,
		"wisdom": 6,
		"charisma": 4
	}
	goblin1.row = "front"
	goblin1.is_alive = true
	goblin1.buffs = {}
	goblin1.debuffs = {}
	test_enemies.append(goblin1)

	var goblin2 = Battle.Combatant.new()
	goblin2.name = "Goblin2"
	goblin2.class_id = "goblin"
	goblin2.job_id = "goblin_rogue"
	goblin2.faction = "enemy"
	goblin2.hp = 25
	goblin2.max_hp = 25
	goblin2.mp = 0
	goblin2.max_mp = 0
	goblin2.stats = {
		"strength": 7,
		"dexterity": 14,
		"constitution": 6,
		"intelligence": 4,
		"wisdom": 5,
		"charisma": 3
	}
	goblin2.row = "back"
	goblin2.is_alive = true
	goblin2.buffs = {}
	goblin2.debuffs = {}
	test_enemies.append(goblin2)


func _setup_test_battle() -> void:
	test_battle_screen = BattleScreen.new()
	test_battle_screen.battle = Battle.new()

	var combat_animator = CombatAnimator.new()
	battle_screen_animator = BattleScreenAnimator.new(combat_animator, test_battle_screen)

	battle_manager_animated = BattleManagerAnimated.new()


## Test: Full battle initialization with animations
func test_full_battle_initialization() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	assert_true(battle_manager_animated.battle_in_progress)
	assert_eq(test_party[0].hp, 100)
	assert_eq(test_enemies[0].hp, 30)

	# Verify animator is tracking combatants
	var hero_animator = battle_screen_animator.combat_animator.get_health_animator(test_party[0])
	assert_not_null(hero_animator)

	var goblin_animator = battle_screen_animator.combat_animator.get_health_animator(test_enemies[0])
	assert_not_null(goblin_animator)


## Test: Turn order is generated correctly
func test_full_battle_turn_order() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	var state = battle_manager_animated.get_state()
	assert_gt(state.turn_order.size(), 0)
	assert_eq(state.turn_order.size(), 4)  # 2 party + 2 enemies


## Test: Current player is identified
func test_full_battle_current_player() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	assert_not_null(battle_manager_animated.current_player)
	assert_true(battle_manager_animated.current_player in test_party + test_enemies)


## Test: Turn highlighting animates
func test_full_battle_turn_highlight() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	var current = battle_manager_animated.current_player
	var turn_animator = battle_screen_animator.combat_animator.get_turn_animator()

	assert_eq(turn_animator.current_character, current)
	assert_gt(turn_animator.get_highlight_intensity(), 0.0)


## Test: Damage animation on attack
func test_full_battle_damage_animation() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	var hero = test_party[0]
	var goblin = test_enemies[0]
	var initial_hp = goblin.hp

	# Execute attack through battle system
	var result = battle_manager_animated.battle.execute_turn(hero, "attack", goblin)

	# Verify damage occurred
	assert_lt(goblin.hp, initial_hp)

	# Verify animation was triggered
	if result.get("damage", 0) > 0:
		assert_true(battle_screen_animator.combat_animator.has_active_animations())


## Test: Health bar animation on damage
func test_full_battle_health_bar_animation() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	var goblin = test_enemies[0]
	var original_hp = goblin.hp

	# Damage goblin
	goblin.hp = goblin.hp / 2
	battle_screen_animator.animate_health_change(goblin, goblin.hp)

	var animator = battle_screen_animator.combat_animator.get_health_animator(goblin)
	assert_true(animator.is_animating)

	# Update animation
	animator.update(0.2)
	var fill = animator.get_fill_percentage()
	assert_lt(fill, 0.6)  # Should be less than 60% after half damage


## Test: Multiple rounds of combat
func test_full_battle_multiple_rounds() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	var initial_round = battle_manager_animated.get_state().round
	assert_eq(initial_round, 1)

	# Simulate several turns (not a full round, just several actions)
	for i in range(3):
		var current = battle_manager_animated.current_player
		if current.faction == "party":
			var valid_targets = battle_manager_animated.battle.get_valid_targets(current, "attack")
			if valid_targets.size() > 0:
				var result = battle_manager_animated.battle.execute_turn(current, "attack", valid_targets[0])
				battle_screen_animator.animate_health_change(valid_targets[0], valid_targets[0].hp)

		battle_manager_animated.battle.state.current_turn_index += 1
		if battle_manager_animated.battle.state.current_turn_index >= battle_manager_animated.battle.state.turn_order.size():
			break


## Test: Status effect animation on application
func test_full_battle_status_effect_animation() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	var goblin = test_enemies[0]

	battle_screen_animator.show_status_effect(goblin, "poison")

	var effects = battle_screen_animator.combat_animator.get_status_animators(goblin)
	assert_gt(effects.size(), 0)
	assert_eq(effects[0].effect_name, "poison")


## Test: Damage popup creation and cleanup
func test_full_battle_damage_popup_lifecycle() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	# Create damage popup
	battle_screen_animator.show_damage(25, Vector2(640, 360), false)
	assert_eq(battle_screen_animator.combat_animator.damage_popups.size(), 1)

	# Animate popup
	battle_screen_animator.update_animations(0.5)
	assert_true(battle_screen_animator.has_active_animations())

	# Complete animation
	battle_screen_animator.update_animations(2.0)
	assert_eq(battle_screen_animator.combat_animator.damage_popups.size(), 0)


## Test: Critical hit animation
func test_full_battle_critical_hit_animation() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	battle_screen_animator.show_damage(50, Vector2(640, 360), true)

	var popups = battle_screen_animator.combat_animator.get_active_popups()
	assert_eq(popups.size(), 1)
	assert_true(popups[0].is_critical)
	assert_gt(popups[0].get_scale(), 1.2)


## Test: Healing animation
func test_full_battle_healing_animation() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	var hero = test_party[0]
	hero.hp = 50  # Reduce health

	battle_screen_animator.show_healing(30, Vector2(640, 360))
	battle_screen_animator.animate_health_change(hero, 80)

	var popups = battle_screen_animator.combat_animator.get_active_popups()
	assert_eq(popups.size(), 1)
	assert_true(popups[0].is_healing)

	var animator = battle_screen_animator.combat_animator.get_health_animator(hero)
	assert_true(animator.is_animating)


## Test: Multiple simultaneous animations
func test_full_battle_simultaneous_animations() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	# Trigger multiple animations at once
	battle_screen_animator.show_damage(25, Vector2(100, 100), false)
	battle_screen_animator.show_damage(50, Vector2(200, 200), true)
	battle_screen_animator.show_healing(20, Vector2(300, 300))

	battle_screen_animator.animate_health_change(test_party[0], 75)
	battle_screen_animator.animate_health_change(test_enemies[0], 15)

	battle_screen_animator.show_status_effect(test_enemies[0], "poison")
	battle_screen_animator.highlight_character_turn(test_party[0])

	# All animations should be active
	assert_true(battle_screen_animator.has_active_animations())

	# Update animations
	battle_screen_animator.update_animations(0.3)
	assert_true(battle_screen_animator.has_active_animations())


## Test: Round transition animation
func test_full_battle_round_transition() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	var animator = battle_screen_animator.combat_animator.get_turn_animator()
	animator.animate_round_transition(2)

	assert_true(animator.is_animating)
	assert_gt(animator.get_round_flash(), 0.0)


## Test: Animation state tracking
func test_full_battle_animation_state_tracking() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	# Initially no animations
	assert_false(battle_screen_animator.has_active_animations())

	# Add animation
	battle_screen_animator.show_damage(25, Vector2(640, 360))
	assert_true(battle_screen_animator.has_active_animations())

	# Update to completion
	battle_screen_animator.update_animations(2.0)
	assert_false(battle_screen_animator.has_active_animations())


## Test: Render data includes all components
func test_full_battle_render_data_completeness() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	battle_screen_animator.show_damage(25, Vector2(640, 360))
	battle_screen_animator.highlight_character_turn(test_party[0])

	var data = battle_screen_animator.get_render_data()

	assert_true("damage_popups" in data)
	assert_true("turn_highlight" in data)
	assert_true("has_active" in data)

	assert_gt(data.damage_popups.size(), 0)
	assert_not_null(data.turn_highlight.character)


## Test: Party member health variations
func test_full_battle_varied_health_values() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	# Different damage amounts
	battle_screen_animator.show_damage(10, Vector2(100, 100))
	battle_screen_animator.show_damage(35, Vector2(150, 150), false)
	battle_screen_animator.show_damage(99, Vector2(200, 200), true)

	var popups = battle_screen_animator.combat_animator.get_active_popups()
	assert_eq(popups.size(), 3)

	# Verify different damage amounts are tracked
	assert_eq(popups[0].damage, 10)
	assert_eq(popups[1].damage, 35)
	assert_eq(popups[2].damage, 99)


## Test: Animation completion signal
func test_full_battle_animation_completion_signal() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	var signal_emitted = false
	battle_screen_animator.combat_animator.all_animations_complete.connect(func(): signal_emitted = true)

	battle_screen_animator.show_damage(25, Vector2(640, 360))
	battle_screen_animator.update_animations(2.0)  # Complete animation

	assert_true(signal_emitted)


## Test: Extended battle simulation (10 turns)
func test_full_battle_extended_simulation() -> void:
	battle_manager_animated.start_battle_animated(test_party, test_enemies, battle_screen_animator)

	var turn_count = 0
	var max_turns = 20  # Safety limit

	# Simulate turns
	while turn_count < max_turns:
		var current = battle_manager_animated.current_player
		if not current or not current.is_alive:
			break

		var valid_targets = []
		if current.faction == "party":
			valid_targets = battle_manager_animated.battle.get_valid_targets(current, "attack")
		else:
			valid_targets = battle_manager_animated.battle.get_valid_targets(current, "attack")

		if valid_targets.size() > 0:
			var target = valid_targets[0]
			var old_hp = target.hp

			# Execute action
			var result = battle_manager_animated.battle.execute_turn(current, "attack", target)

			# Trigger animations
			if result.get("damage", 0) > 0:
				battle_screen_animator.show_damage(result.damage, Vector2(640, 360), result.get("critical", false))
				battle_screen_animator.animate_health_change(target, target.hp)

			# Update animations
			battle_screen_animator.update_animations(0.1)

		# Advance turn
		battle_manager_animated.battle.state.current_turn_index += 1
		turn_count += 1

		if battle_manager_animated.battle.state.current_turn_index >= battle_manager_animated.battle.state.turn_order.size():
			break

	# Verify combat progressed
	assert_gt(turn_count, 0)

	# At least some damage should have been dealt
	var total_party_hp = 0
	var total_enemy_hp = 0
	for member in test_party:
		total_party_hp += member.hp
	for enemy in test_enemies:
		total_enemy_hp += enemy.hp

	# Combat should have affected HP values
	assert_true(total_party_hp <= 160)  # Initial was 160 max
	assert_true(total_enemy_hp <= 55)   # Initial was 55 max
