## Combat Animator: Orchestrates all battle animations
##
## Coordinates damage popups, health bar animations, turn transitions, and ability effects
## Manages animation queue and timing for smooth combat feedback

class_name CombatAnimator


signal animation_queue_updated
signal all_animations_complete


var damage_popups: Array[DamagePopup] = []
var health_animators: Dictionary = {}  # Combatant -> HealthBarAnimator
var turn_animator: TurnTransitionAnimator = null
var status_animators: Dictionary = {}  # Combatant -> Array[StatusEffectAnimator]
var ability_animators: Dictionary = {}  # Ability name -> AbilityAnimator

var is_processing: bool = false


func _init() -> void:
	turn_animator = TurnTransitionAnimator.new()


## Register combatant for health bar animations
func register_combatant(combatant: Battle.Combatant) -> void:
	if combatant not in health_animators:
		health_animators[combatant] = HealthBarAnimator.new(
			combatant.hp,
			combatant.max_hp,
			HealthBarAnimator.BarType.HEALTH
		)
		status_animators[combatant] = []


## Unregister combatant
func unregister_combatant(combatant: Battle.Combatant) -> void:
	health_animators.erase(combatant)
	status_animators.erase(combatant)


## Create and queue damage popup
func queue_damage_popup(damage: int, position: Vector2, is_critical: bool = false, is_healing: bool = false) -> void:
	var popup = DamagePopup.new(damage, is_critical, is_healing)
	popup.animate_from(position)
	damage_popups.append(popup)
	animation_queue_updated.emit()


## Animate health bar change
func animate_health_change(combatant: Battle.Combatant, new_health: float) -> void:
	if combatant in health_animators:
		health_animators[combatant].animate_to(new_health)


## Animate mana bar change
func animate_mana_change(combatant: Battle.Combatant, new_mana: float) -> void:
	# Create mana animator if not exists
	var key = "%s_mana" % combatant.name
	if key not in health_animators:
		health_animators[key] = HealthBarAnimator.new(
			combatant.mp,
			combatant.max_mp,
			HealthBarAnimator.BarType.MANA
		)
	health_animators[key].animate_to(new_mana)


## Apply status effect animation
func apply_status_effect(combatant: Battle.Combatant, effect_name: String) -> void:
	if combatant not in status_animators:
		status_animators[combatant] = []

	var animator = StatusEffectAnimator.new(effect_name)
	animator.apply_effect(effect_name)
	status_animators[combatant].append(animator)


## Remove status effect animation
func remove_status_effect(combatant: Battle.Combatant, effect_name: String) -> void:
	if combatant not in status_animators:
		return

	for animator in status_animators[combatant]:
		if animator.effect_name.to_lower() == effect_name.to_lower():
			animator.remove_effect()


## Highlight character for turn
func highlight_turn(character: Battle.Combatant) -> void:
	turn_animator.highlight_character(character)


## Animate round transition
func animate_round_transition(round_number: int) -> void:
	turn_animator.animate_round_transition(round_number)


## Start ability animation
func start_ability_animation(ability_name: String, ability_type: AbilityAnimator.AbilityType, caster: Battle.Combatant, target: Battle.Combatant = null) -> AbilityAnimator:
	var animator = AbilityAnimator.new(ability_name, ability_type)
	animator.start_cast(caster, target)
	ability_animators[ability_name] = animator
	return animator


## Trigger impact phase for ability
func trigger_ability_impact(ability_name: String) -> void:
	if ability_name in ability_animators:
		ability_animators[ability_name].start_impact()


## Update all animations (call once per frame)
func update(delta: float) -> void:
	is_processing = true

	# Update damage popups
	var completed_popups = []
	for popup in damage_popups:
		popup.update(delta)
		if popup.is_complete():
			completed_popups.append(popup)

	for popup in completed_popups:
		damage_popups.erase(popup)

	# Update health animators
	for combatant in health_animators.keys():
		if combatant is Battle.Combatant and health_animators[combatant] is HealthBarAnimator:
			health_animators[combatant].update(delta)

	# Update status effect animators
	for combatant in status_animators.keys():
		if combatant is Battle.Combatant:
			var completed_effects = []
			for animator in status_animators[combatant]:
				animator.update(delta)
				if not animator.is_active and animator.get_opacity() <= 0.0:
					completed_effects.append(animator)

			for effect in completed_effects:
				status_animators[combatant].erase(effect)

	# Update turn animator
	turn_animator.update(delta)

	# Update ability animators
	var completed_abilities = []
	for ability_name in ability_animators.keys():
		ability_animators[ability_name].update(delta)
		if ability_animators[ability_name].is_impact_complete():
			completed_abilities.append(ability_name)

	for ability in completed_abilities:
		ability_animators.erase(ability)

	is_processing = false

	# Check if all animations are complete
	if damage_popups.is_empty() and not has_active_animations():
		all_animations_complete.emit()


## Check if any animations are currently active
func has_active_animations() -> bool:
	if not damage_popups.is_empty():
		return true

	for combatant in health_animators.keys():
		if combatant is Battle.Combatant:
			if health_animators[combatant].is_animating:
				return true

	for combatant in status_animators.keys():
		if combatant is Battle.Combatant:
			if not status_animators[combatant].is_empty():
				return true

	if not turn_animator.is_complete():
		return true

	if not ability_animators.is_empty():
		return true

	return false


## Get all active damage popups
func get_active_popups() -> Array[DamagePopup]:
	return damage_popups


## Get health animator for combatant
func get_health_animator(combatant: Battle.Combatant) -> HealthBarAnimator:
	if combatant in health_animators:
		return health_animators[combatant]
	return null


## Get turn animator
func get_turn_animator() -> TurnTransitionAnimator:
	return turn_animator


## Get status animators for combatant
func get_status_animators(combatant: Battle.Combatant) -> Array[StatusEffectAnimator]:
	if combatant in status_animators:
		return status_animators[combatant]
	return []


## Clear all animations
func clear_all() -> void:
	damage_popups.clear()
	health_animators.clear()
	status_animators.clear()
	ability_animators.clear()
