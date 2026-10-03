## Tests for Combat Animation System
##
## Tests: DamagePopup, HealthBarAnimator, TurnTransitionAnimator, StatusEffectAnimator, AbilityAnimator, CombatAnimator

extends GutTest


var combat_animator: CombatAnimator
var test_combatant: Battle.Combatant
var test_target: Battle.Combatant


func before_each() -> void:
	combat_animator = CombatAnimator.new()
	_setup_test_combatants()


func _setup_test_combatants() -> void:
	test_combatant = Battle.Combatant.new()
	test_combatant.name = "Hero"
	test_combatant.faction = "party"
	test_combatant.hp = 100
	test_combatant.max_hp = 100
	test_combatant.mp = 50
	test_combatant.max_mp = 50
	test_combatant.stats = {
		"strength": 15,
		"dexterity": 10,
		"constitution": 12
	}
	test_combatant.is_alive = true
	test_combatant.buffs = {}
	test_combatant.debuffs = {}

	test_target = Battle.Combatant.new()
	test_target.name = "Enemy"
	test_target.faction = "enemy"
	test_target.hp = 50
	test_target.max_hp = 50
	test_target.is_alive = true


## Test: DamagePopup initialization
func test_damage_popup_init() -> void:
	var popup = DamagePopup.new(25, false, false)
	assert_not_null(popup)
	assert_eq(popup.damage, 25)
	assert_false(popup.is_critical)
	assert_false(popup.is_healing)


## Test: DamagePopup critical hit formatting
func test_damage_popup_critical_formatting() -> void:
	var popup = DamagePopup.new(50, true, false)
	var text = popup.get_display_text()
	assert_true(text.contains("!"))


## Test: DamagePopup healing display
func test_damage_popup_healing_display() -> void:
	var popup = DamagePopup.new(20, false, true)
	var text = popup.get_display_text()
	assert_true(text.contains("+"))


## Test: DamagePopup color based on type
func test_damage_popup_colors() -> void:
	var dmg_popup = DamagePopup.new(25, false, false)
	var crit_popup = DamagePopup.new(50, true, false)
	var heal_popup = DamagePopup.new(20, false, true)

	assert_eq(dmg_popup.get_color(), Color.WHITE)
	assert_eq(crit_popup.get_color(), Color.YELLOW)
	assert_eq(heal_popup.get_color(), Color.GREEN)


## Test: DamagePopup scale for criticals
func test_damage_popup_critical_scale() -> void:
	var normal_popup = DamagePopup.new(25, false, false)
	var crit_popup = DamagePopup.new(50, true, false)

	assert_lt(normal_popup.get_scale(), crit_popup.get_scale())


## Test: DamagePopup animation progression
func test_damage_popup_animation() -> void:
	var popup = DamagePopup.new(25, false, false)
	popup.animate_from(Vector2(100, 100))

	assert_false(popup.is_complete())
	popup.update(popup.duration / 2)
	assert_false(popup.is_complete())
	popup.update(popup.duration)
	assert_true(popup.is_complete())


## Test: HealthBarAnimator initialization
func test_health_bar_animator_init() -> void:
	var animator = HealthBarAnimator.new(100, 100, HealthBarAnimator.BarType.HEALTH)
	assert_not_null(animator)
	assert_eq(animator.current_value, 100)
	assert_eq(animator.max_value, 100)
	assert_eq(animator.get_fill_percentage(), 1.0)


## Test: HealthBarAnimator fill percentage
func test_health_bar_fill_percentage() -> void:
	var animator = HealthBarAnimator.new(50, 100, HealthBarAnimator.BarType.HEALTH)
	assert_eq(animator.get_fill_percentage(), 0.5)


## Test: HealthBarAnimator color changes by health
func test_health_bar_color_changes() -> void:
	var animator = HealthBarAnimator.new(100, 100, HealthBarAnimator.BarType.HEALTH)
	var full_color = animator.get_bar_color()

	animator.current_value = 50
	var warning_color = animator.get_bar_color()
	assert_ne(full_color, warning_color)


## Test: HealthBarAnimator critical detection
func test_health_bar_critical_detection() -> void:
	var animator = HealthBarAnimator.new(100, 100, HealthBarAnimator.BarType.HEALTH)
	assert_false(animator.is_critical_health())

	animator.current_value = 20
	assert_true(animator.is_critical_health())


## Test: HealthBarAnimator smooth animation
func test_health_bar_smooth_animation() -> void:
	var animator = HealthBarAnimator.new(100, 100, HealthBarAnimator.BarType.HEALTH)
	animator.animate_to(50)

	assert_true(animator.is_animating)
	animator.update(animator.animation_duration / 2)
	assert_gt(animator.current_value, 50)
	assert_lt(animator.current_value, 100)


## Test: TurnTransitionAnimator highlighting
func test_turn_animator_highlight() -> void:
	var animator = TurnTransitionAnimator.new()
	animator.highlight_character(test_combatant)

	assert_not_null(animator.current_character)
	assert_eq(animator.current_character.name, "Hero")
	assert_true(animator.is_animating)


## Test: TurnTransitionAnimator highlight intensity pulsing
func test_turn_animator_pulse() -> void:
	var animator = TurnTransitionAnimator.new()
	animator.highlight_character(test_combatant)

	var intensity1 = animator.get_highlight_intensity()
	animator.update(0.1)
	var intensity2 = animator.get_highlight_intensity()

	# Should pulse over time
	assert_ne(intensity1, intensity2)


## Test: TurnTransitionAnimator indicator color by faction
func test_turn_animator_faction_colors() -> void:
	var animator = TurnTransitionAnimator.new()

	test_combatant.faction = "party"
	animator.highlight_character(test_combatant)
	var party_color = animator.get_turn_indicator_color()

	test_target.faction = "enemy"
	animator.highlight_character(test_target)
	var enemy_color = animator.get_turn_indicator_color()

	assert_ne(party_color, enemy_color)


## Test: StatusEffectAnimator application
func test_status_effect_animator_apply() -> void:
	var animator = StatusEffectAnimator.new("poison")
	animator.apply_effect("poison")

	assert_true(animator.is_active)
	assert_gt(animator.get_opacity(), 0.0)


## Test: StatusEffectAnimator color mapping
func test_status_effect_animator_colors() -> void:
	var poison_animator = StatusEffectAnimator.new("poison")
	var burn_animator = StatusEffectAnimator.new("burn")

	poison_animator.apply_effect("poison")
	burn_animator.apply_effect("burn")

	var poison_color = poison_animator.get_color()
	var burn_color = burn_animator.get_color()

	assert_ne(poison_color, burn_color)


## Test: StatusEffectAnimator negative effect detection
func test_status_effect_negative_detection() -> void:
	var poison_animator = StatusEffectAnimator.new("poison")
	var buff_animator = StatusEffectAnimator.new("strength_up")

	assert_true(poison_animator.is_negative_effect())
	assert_false(buff_animator.is_negative_effect())
	assert_true(buff_animator.is_positive_effect())


## Test: StatusEffectAnimator glow for negative effects
func test_status_effect_glow_animation() -> void:
	var animator = StatusEffectAnimator.new("poison")
	animator.apply_effect("poison")

	var glow1 = animator.get_glow_intensity()
	animator.update(0.1)
	var glow2 = animator.get_glow_intensity()

	# Glow should pulse
	assert_ne(glow1, glow2)


## Test: AbilityAnimator initialization
func test_ability_animator_init() -> void:
	var animator = AbilityAnimator.new("Fireball", AbilityAnimator.AbilityType.SPELL)
	assert_not_null(animator)
	assert_eq(animator.ability_name, "Fireball")
	assert_eq(animator.ability_type, AbilityAnimator.AbilityType.SPELL)


## Test: AbilityAnimator casting animation
func test_ability_animator_cast() -> void:
	var animator = AbilityAnimator.new("Fireball", AbilityAnimator.AbilityType.SPELL)
	animator.start_cast(test_combatant, test_target)

	assert_true(animator.is_casting)
	assert_gt(animator.get_cast_progress(), 0.0)


## Test: AbilityAnimator cast progress
func test_ability_animator_cast_progress() -> void:
	var animator = AbilityAnimator.new("Fireball", AbilityAnimator.AbilityType.SPELL)
	animator.start_cast(test_combatant, test_target)

	animator.update(animator.cast_duration / 2)
	var progress = animator.get_cast_progress()
	assert_gt(progress, 0.4)
	assert_lt(progress, 0.6)


## Test: AbilityAnimator impact animation
func test_ability_animator_impact() -> void:
	var animator = AbilityAnimator.new("Fireball", AbilityAnimator.AbilityType.SPELL)
	animator.start_cast(test_combatant, test_target)
	animator.start_impact()

	assert_false(animator.is_casting)
	assert_true(animator.is_impacting)
	assert_gt(animator.get_impact_flash(), 0.0)


## Test: AbilityAnimator target shake
func test_ability_animator_shake() -> void:
	var animator = AbilityAnimator.new("Fireball", AbilityAnimator.AbilityType.SPELL)
	animator.start_cast(test_combatant, test_target)
	animator.start_impact()

	var shake = animator.get_impact_shake()
	assert_gt(shake, 0.0)


## Test: AbilityAnimator color by type
func test_ability_animator_colors() -> void:
	var attack_animator = AbilityAnimator.new("Attack", AbilityAnimator.AbilityType.ATTACK)
	var spell_animator = AbilityAnimator.new("Fireball", AbilityAnimator.AbilityType.SPELL)

	var attack_color = attack_animator.get_ability_color()
	var spell_color = spell_animator.get_ability_color()

	assert_ne(attack_color, spell_color)


## Test: CombatAnimator initialization
func test_combat_animator_init() -> void:
	assert_not_null(combat_animator)
	assert_not_null(combat_animator.turn_animator)
	assert_true(combat_animator.damage_popups.is_empty())


## Test: CombatAnimator register combatant
func test_combat_animator_register() -> void:
	combat_animator.register_combatant(test_combatant)

	assert_true(test_combatant in combat_animator.health_animators)
	assert_not_null(combat_animator.get_health_animator(test_combatant))


## Test: CombatAnimator queue damage popup
func test_combat_animator_queue_popup() -> void:
	combat_animator.queue_damage_popup(25, Vector2(100, 100))

	assert_eq(combat_animator.damage_popups.size(), 1)


## Test: CombatAnimator damage popup cleanup
func test_combat_animator_popup_cleanup() -> void:
	combat_animator.queue_damage_popup(25, Vector2(100, 100))

	assert_eq(combat_animator.damage_popups.size(), 1)
	combat_animator.update(2.0)  # More than animation duration
	assert_eq(combat_animator.damage_popups.size(), 0)


## Test: CombatAnimator health animation
func test_combat_animator_health_animation() -> void:
	combat_animator.register_combatant(test_combatant)
	combat_animator.animate_health_change(test_combatant, 50)

	var animator = combat_animator.get_health_animator(test_combatant)
	assert_true(animator.is_animating)


## Test: CombatAnimator mana animation
func test_combat_animator_mana_animation() -> void:
	combat_animator.register_combatant(test_combatant)
	combat_animator.animate_mana_change(test_combatant, 25)

	# Should create mana animator
	assert_true(combat_animator.has_active_animations())


## Test: CombatAnimator status effect
func test_combat_animator_status_effect() -> void:
	combat_animator.register_combatant(test_combatant)
	combat_animator.apply_status_effect(test_combatant, "poison")

	var effects = combat_animator.get_status_animators(test_combatant)
	assert_gt(effects.size(), 0)


## Test: CombatAnimator turn highlighting
func test_combat_animator_turn_highlight() -> void:
	combat_animator.highlight_turn(test_combatant)

	var animator = combat_animator.get_turn_animator()
	assert_eq(animator.current_character.name, "Hero")


## Test: CombatAnimator ability animation
func test_combat_animator_ability() -> void:
	var ability = combat_animator.start_ability_animation(
		"Fireball",
		AbilityAnimator.AbilityType.SPELL,
		test_combatant,
		test_target
	)

	assert_not_null(ability)
	assert_true(ability.is_casting)


## Test: CombatAnimator has active animations
func test_combat_animator_has_active() -> void:
	assert_false(combat_animator.has_active_animations())

	combat_animator.queue_damage_popup(25, Vector2(100, 100))
	assert_true(combat_animator.has_active_animations())


## Test: CombatAnimator update loop
func test_combat_animator_update() -> void:
	combat_animator.queue_damage_popup(25, Vector2(100, 100))
	combat_animator.register_combatant(test_combatant)
	combat_animator.animate_health_change(test_combatant, 50)

	assert_true(combat_animator.has_active_animations())
	combat_animator.update(0.1)
	assert_true(combat_animator.has_active_animations())


## Test: CombatAnimator all animations complete signal
func test_combat_animator_completion_signal() -> void:
	var signal_emitted = false
	combat_animator.all_animations_complete.connect(func(): signal_emitted = true)

	combat_animator.queue_damage_popup(25, Vector2(100, 100))
	combat_animator.update(2.0)  # More than animation duration

	assert_true(signal_emitted)


## Test: CombatAnimator clear all
func test_combat_animator_clear() -> void:
	combat_animator.queue_damage_popup(25, Vector2(100, 100))
	combat_animator.register_combatant(test_combatant)
	combat_animator.apply_status_effect(test_combatant, "poison")

	combat_animator.clear_all()

	assert_true(combat_animator.damage_popups.is_empty())
	assert_true(combat_animator.health_animators.is_empty())
	assert_true(combat_animator.status_animators.is_empty())


## Test: Multiple simultaneous animations
func test_combat_animator_multiple_simultaneous() -> void:
	combat_animator.register_combatant(test_combatant)
	combat_animator.register_combatant(test_target)

	# Queue multiple animations at once
	combat_animator.queue_damage_popup(25, Vector2(100, 100))
	combat_animator.queue_damage_popup(50, Vector2(200, 200), true)
	combat_animator.animate_health_change(test_combatant, 75)
	combat_animator.animate_health_change(test_target, 30)
	combat_animator.highlight_turn(test_combatant)

	assert_eq(combat_animator.damage_popups.size(), 2)
	assert_true(combat_animator.has_active_animations())

	combat_animator.update(0.2)
	assert_true(combat_animator.has_active_animations())
