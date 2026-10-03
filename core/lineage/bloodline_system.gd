## Bloodline System: Apply trait effects to heir stats, abilities, and progression
##
## Manages stat bonuses, passive effects, ability unlocks, and how bloodline traits
## shape each heir's capabilities and progression scaling.

extends Node

class_name BloodlineSystem


signal bloodline_effect_applied(heir_id: String, effect_type: String, power: float)
signal ability_unlocked(heir_id: String, ability_id: String)
signal stat_bonus_applied(heir_id: String, stat: String, amount: int)


var trait_definitions: TraitDefinition
var active_bloodlines: Dictionary = {}  # heir_id -> BloodlineProfile


class BloodlineProfile:
	var heir_id: String
	var traits: Array
	var stat_bonuses: Dictionary  # stat -> total bonus
	var ability_unlocks: Array
	var passive_effects: Dictionary  # effect_id -> power
	var prestige_multiplier: float
	var generation: int

	func _init(p_heir_id: String, p_gen: int) -> void:
		heir_id = p_heir_id
		generation = p_gen
		traits = []
		stat_bonuses = {"strength": 0, "dexterity": 0, "intelligence": 0, "vitality": 0}
		ability_unlocks = []
		passive_effects = {}
		prestige_multiplier = 1.0


class PassiveEffect:
	var effect_id: String
	var effect_name: String
	var power: float
	var stat_affected: String  # Which stat it modifies
	var duration_generations: int

	func _init(p_id: String, p_name: String, p_power: float) -> void:
		effect_id = p_id
		effect_name = p_name
		power = p_power
		stat_affected = ""
		duration_generations = 999  # Permanent by default


func _init(trait_defs: TraitDefinition) -> void:
	trait_definitions = trait_defs


func create_bloodline_profile(heir_id: String, inherited_traits: Array, generation: int, prestige: int) -> BloodlineProfile:
	var profile = BloodlineProfile.new(heir_id, generation)
	profile.traits = inherited_traits.duplicate()

	# Apply stat bonuses from traits
	for trait_id in inherited_traits:
		var trait = trait_definitions.get_trait(trait_id)
		if not trait:
			continue

		# Apply stat modifiers
		for stat in trait.stat_modifiers.keys():
			if stat in profile.stat_bonuses:
				profile.stat_bonuses[stat] += trait.stat_modifiers[stat]

		# Unlock abilities
		for ability in trait.ability_unlocks:
			if ability not in profile.ability_unlocks:
				profile.ability_unlocks.append(ability)

		# Apply passive effects based on trait type
		_apply_trait_effects(profile, trait_id, trait, prestige)

	# Calculate prestige multiplier from bloodline strength
	profile.prestige_multiplier = _calculate_prestige_multiplier(profile)

	active_bloodlines[heir_id] = profile
	return profile


func get_stat_bonus(heir_id: String, stat: String) -> int:
	if heir_id not in active_bloodlines:
		return 0

	var profile = active_bloodlines[heir_id]
	return profile.stat_bonuses.get(stat, 0)


func get_total_stat_bonuses(heir_id: String) -> Dictionary:
	if heir_id not in active_bloodlines:
		return {"strength": 0, "dexterity": 0, "intelligence": 0, "vitality": 0}

	return active_bloodlines[heir_id].stat_bonuses.duplicate()


func get_unlocked_abilities(heir_id: String) -> Array:
	if heir_id not in active_bloodlines:
		return []

	return active_bloodlines[heir_id].ability_unlocks.duplicate()


func has_ability(heir_id: String, ability_id: String) -> bool:
	if heir_id not in active_bloodlines:
		return false

	return ability_id in active_bloodlines[heir_id].ability_unlocks


func get_prestige_multiplier(heir_id: String) -> float:
	if heir_id not in active_bloodlines:
		return 1.0

	return active_bloodlines[heir_id].prestige_multiplier


func get_passive_effect_power(heir_id: String, effect_id: String) -> float:
	if heir_id not in active_bloodlines:
		return 0.0

	var profile = active_bloodlines[heir_id]
	return profile.passive_effects.get(effect_id, 0.0)


func check_bloodline_awakening(heir_id: String, milestone_generation: int) -> Array:
	if heir_id not in active_bloodlines:
		return []

	var profile = active_bloodlines[heir_id]
	var awakened_effects = []

	for trait_id in profile.traits:
		var trait = trait_definitions.get_trait(trait_id)
		if not trait or not (trait is TraitDefinition.BloodlineTrait):
			continue

		if trait.awakening_generation == milestone_generation:
			awakened_effects.append({
				"trait_id": trait_id,
				"effect": "awakening",
				"power": 1.5
			})

	return awakened_effects


func apply_blessing_effect(heir_id: String, blessing_trait: String, generations_duration: int) -> void:
	if heir_id not in active_bloodlines:
		return

	var profile = active_bloodlines[heir_id]
	var trait = trait_definitions.get_trait(blessing_trait)

	if not trait or not (trait is TraitDefinition.BlessingTrait):
		return

	var blessing = trait as TraitDefinition.BlessingTrait
	var effect = PassiveEffect.new(blessing_trait, blessing.name, float(blessing.blessing_power))
	effect.duration_generations = generations_duration

	profile.passive_effects[blessing_trait] = blessing.blessing_power

	bloodline_effect_applied.emit(heir_id, blessing.name, float(blessing.blessing_power))


func get_bloodline_report(heir_id: String) -> Dictionary:
	if heir_id not in active_bloodlines:
		return {}

	var profile = active_bloodlines[heir_id]
	var trait_names = []

	for trait_id in profile.traits:
		var trait = trait_definitions.get_trait(trait_id)
		if trait:
			trait_names.append(trait.name)

	return {
		"heir_id": heir_id,
		"generation": profile.generation,
		"traits": trait_names,
		"stat_bonuses": profile.stat_bonuses.duplicate(),
		"ability_unlocks": profile.ability_unlocks.duplicate(),
		"prestige_multiplier": profile.prestige_multiplier,
		"passive_effects": profile.passive_effects.keys()
	}


func _apply_trait_effects(profile: BloodlineProfile, trait_id: String, trait: TraitDefinition.Trait, prestige: int) -> void:
	match trait.trait_type:
		TraitDefinition.TraitType.BLOODLINE:
			# Bloodline traits grant prestige bonuses
			var effect = PassiveEffect.new(trait_id, trait.name, 1.05)
			profile.passive_effects[trait_id] = 1.05

		TraitDefinition.TraitType.BLESSING:
			# Blessings grant powerful bonuses
			var blessing = trait as TraitDefinition.BlessingTrait
			var effect = PassiveEffect.new(trait_id, trait.name, float(blessing.blessing_power))
			effect.duration_generations = blessing.duration_generations
			profile.passive_effects[trait_id] = float(blessing.blessing_power)

		TraitDefinition.TraitType.CURSE:
			# Curses apply negative effects
			var curse = trait as TraitDefinition.CurseTrait
			var effect = PassiveEffect.new(trait_id, trait.name, -float(curse.curse_severity) * 0.1)
			profile.passive_effects[trait_id] = -float(curse.curse_severity) * 0.1

		TraitDefinition.TraitType.ACQUIRED:
			# Acquired traits grant training bonuses
			var acquired = trait as TraitDefinition.AcquiredTrait
			var effect = PassiveEffect.new(trait_id, trait.name, 1.10)
			profile.passive_effects[trait_id] = 1.10


func _calculate_prestige_multiplier(profile: BloodlineProfile) -> float:
	var multiplier = 1.0

	# Each trait contributes to prestige multiplier
	for trait_id in profile.traits:
		var trait = trait_definitions.get_trait(trait_id)
		if not trait:
			continue

		match trait.trait_type:
			TraitDefinition.TraitType.BLOODLINE:
				multiplier *= 1.05  # +5% per bloodline trait
			TraitDefinition.TraitType.BLESSING:
				multiplier *= 1.10  # +10% per blessing
			TraitDefinition.TraitType.CURSE:
				multiplier *= 0.95  # -5% per curse

	return clamp(multiplier, 0.5, 2.0)  # Cap between 0.5x and 2.0x
