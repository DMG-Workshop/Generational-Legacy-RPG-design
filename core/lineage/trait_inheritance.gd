## Trait Inheritance: Calculate trait passing from parent to child through generations
##
## Implements dominant/recessive inheritance patterns, mutation triggers, dormant trait
## mechanics, and prestige-scaled inheritance probabilities.

extends Node

class_name TraitInheritance


signal trait_inherited(heir_id: String, trait_id: String, source: String)
signal trait_mutated(heir_id: String, original_trait: String, mutated_trait: String)
signal trait_awakened(heir_id: String, trait_id: String)
signal trait_dormant(heir_id: String, trait_id: String)


var trait_definitions: TraitDefinition
var inheritance_history: Dictionary = {}  # heir_id -> {trait_id: {source, inherited_gen, mutations}}


class InheritanceRecord:
	var trait_id: String
	var source_parent: String  # Which parent trait came from
	var inherited_generation: int
	var mutation_chain: Array  # All mutations applied
	var times_inherited: int  # How many times passed down
	var current_prestige_boost: float

	func _init(p_trait_id: String, p_source: String, p_gen: int) -> void:
		trait_id = p_trait_id
		source_parent = p_source
		inherited_generation = p_gen
		mutation_chain = []
		times_inherited = 1
		current_prestige_boost = 1.0


func _init(trait_defs: TraitDefinition) -> void:
	trait_definitions = trait_defs


func inherit_traits_from_parents(heir_id: String, mother_traits: Array, father_traits: Array, generation: int, prestige: int) -> Array:
	var inherited = []
	var processed_traits = {}

	# Process mother's traits (dominant)
	for trait_id in mother_traits:
		if _should_inherit_trait(trait_id, prestige, generation):
			inherited.append(trait_id)
			processed_traits[trait_id] = "mother"

	# Process father's traits (if not already inherited from mother)
	for trait_id in father_traits:
		if trait_id not in processed_traits:
			if _should_inherit_trait(trait_id, prestige, generation):
				inherited.append(trait_id)
				processed_traits[trait_id] = "father"

	# Record inheritance
	for trait_id in inherited:
		_record_inheritance(heir_id, trait_id, processed_traits[trait_id], generation)

	return inherited


func check_mutations(heir_id: String, traits: Array, prestige: int, generation: int) -> Dictionary:
	var mutations = {}  # original -> mutated_trait_id

	for trait_id in traits:
		var trait = trait_definitions.get_trait(trait_id)
		if not trait:
			continue

		# Base mutation chance increases with prestige
		var mutation_chance = trait.mutation_chance
		mutation_chance += (prestige / 50000.0) * 0.1  # Up to +10% at max prestige

		if randf() < mutation_chance:
			# Check mutation chain
			if trait.mutation_chain.size() > 0:
				var mutated_id = trait.mutation_chain[randi() % trait.mutation_chain.size()]
				mutations[trait_id] = mutated_id
				_record_mutation(heir_id, trait_id, mutated_id, generation)
				trait_mutated.emit(heir_id, trait_id, mutated_id)

	return mutations


func handle_dormant_traits(heir_id: String, inherited_traits: Array, generation: int) -> Array:
	var awakened = []

	for trait_id in inherited_traits:
		var trait = trait_definitions.get_trait(trait_id)
		if not trait or not trait.is_dormant_capable:
			awakened.append(trait_id)
			continue

		# Dormant trait has skip chance
		if randf() > trait.dormant_skip_chance:
			awakened.append(trait_id)
			trait_awakened.emit(heir_id, trait_id)
		else:
			trait_dormant.emit(heir_id, trait_id)

	return awakened


func apply_inheritance_decay(trait_id: String, generations_inherited: int) -> float:
	var trait = trait_definitions.get_trait(trait_id)
	if not trait:
		return 1.0

	if trait is TraitDefinition.BloodlineTrait:
		# Bloodline traits decay each generation
		return pow(trait.generation_decay, generations_inherited)

	return 1.0  # Other traits don't decay


func get_inherited_stat_bonus(heir_traits: Array, generations_inherited: Dictionary) -> Dictionary:
	var total_bonus = {"strength": 0, "dexterity": 0, "intelligence": 0, "vitality": 0}

	for trait_id in heir_traits:
		var trait = trait_definitions.get_trait(trait_id)
		if not trait:
			continue

		var gens = generations_inherited.get(trait_id, 1)
		var decay = apply_inheritance_decay(trait_id, gens)

		for stat in trait.stat_modifiers.keys():
			if stat in total_bonus:
				total_bonus[stat] += int(trait.stat_modifiers[stat] * decay)

	return total_bonus


func validate_trait_compatibility(traits: Array) -> bool:
	for i in range(traits.size()):
		for j in range(i + 1, traits.size()):
			if not trait_definitions.can_traits_coexist(traits[i], traits[j]):
				return false

	return true


func get_inheritance_report(heir_id: String) -> Dictionary:
	var report = {
		"heir_id": heir_id,
		"inherited_traits": [],
		"trait_sources": {},
		"mutation_chains": {},
		"dormant_traits": []
	}

	if heir_id not in inheritance_history:
		return report

	for trait_id in inheritance_history[heir_id].keys():
		var record = inheritance_history[heir_id][trait_id]
		report["inherited_traits"].append(trait_id)
		report["trait_sources"][trait_id] = record.source_parent
		report["mutation_chains"][trait_id] = record.mutation_chain

	return report


func _should_inherit_trait(trait_id: String, prestige: int, generation: int) -> bool:
	var trait = trait_definitions.get_trait(trait_id)
	if not trait:
		return false

	# Check prestige requirement
	if prestige < trait.prestige_requirement:
		# 20% chance to inherit anyway if below prestige threshold
		return randf() < 0.2

	# Inheritance pattern affects chance
	match trait.inheritance_pattern:
		TraitDefinition.InheritancePattern.DOMINANT:
			return true  # Always inherit dominant traits
		TraitDefinition.InheritancePattern.RECESSIVE:
			return randf() < 0.5  # 50% chance for recessive
		TraitDefinition.InheritancePattern.MIXED:
			return randf() < 0.75  # 75% chance for mixed

	return true


func _record_inheritance(heir_id: String, trait_id: String, source: String, generation: int) -> void:
	if heir_id not in inheritance_history:
		inheritance_history[heir_id] = {}

	if trait_id not in inheritance_history[heir_id]:
		inheritance_history[heir_id][trait_id] = InheritanceRecord.new(trait_id, source, generation)
	else:
		inheritance_history[heir_id][trait_id].times_inherited += 1

	trait_inherited.emit(heir_id, trait_id, source)


func _record_mutation(heir_id: String, original_trait: String, mutated_trait: String, generation: int) -> void:
	if heir_id not in inheritance_history:
		inheritance_history[heir_id] = {}

	if original_trait in inheritance_history[heir_id]:
		inheritance_history[heir_id][original_trait].mutation_chain.append(mutated_trait)
