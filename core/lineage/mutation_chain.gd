## Mutation Chain: Manage cascading mutations, trait evolution, and mutation sequences
##
## Handles primary mutations triggering secondary mutations, mutation sequences across
## generations, and advanced trait evolution through accumulated mutations.

extends Node

class_name MutationChain


signal mutation_triggered(heir_id: String, source_trait: String, target_trait: String)
signal chain_reaction_started(heir_id: String, initial_mutation: String)
signal chain_reaction_completed(heir_id: String, mutation_count: int)


var trait_definitions: TraitDefinition
var mutation_sequences: Dictionary = {}  # heir_id -> [mutations in order]
var evolution_tree: Dictionary = {}  # trait_id -> [possible evolutions]


class MutationSequence:
	var heir_id: String
	var mutations: Array
	var primary_mutation: String
	var generation_triggered: int
	var chain_depth: int

	func _init(p_heir_id: String, p_primary: String, p_gen: int) -> void:
		heir_id = p_heir_id
		mutations = []
		primary_mutation = p_primary
		generation_triggered = p_gen
		chain_depth = 0


class EvolutionPath:
	var source_trait: String
	var target_trait: String
	var requirement: String  # "prestige", "generation", "milestone"
	var requirement_value: int
	var evolution_power: float  # How much stronger the evolved trait is

	func _init(p_source: String, p_target: String) -> void:
		source_trait = p_source
		target_trait = p_target
		requirement = "prestige"
		requirement_value = 1000
		evolution_power = 1.2


func _init(trait_defs: TraitDefinition) -> void:
	trait_definitions = trait_defs
	_initialize_evolution_tree()


func process_mutation(heir_id: String, source_trait: String, target_trait: String, generation: int, prestige: int) -> MutationSequence:
	var sequence = MutationSequence.new(heir_id, target_trait, generation)
	sequence.mutations.append(target_trait)

	# Check for chain reactions (mutation triggering other mutations)
	_process_chain_reactions(heir_id, target_trait, generation, prestige, sequence)

	mutation_sequences[heir_id] = sequence
	return sequence


func trigger_chain_reaction(heir_id: String, initial_trait: String, generation: int, prestige: int) -> Array:
	var chain_queue = [initial_trait]
	var processed = []
	var chain_depth = 0

	chain_reaction_started.emit(heir_id, initial_trait)

	while chain_queue.size() > 0 and chain_depth < 5:  # Limit chain depth
		var current_trait = chain_queue.pop_front()

		if current_trait in processed:
			continue

		processed.append(current_trait)

		# Check what this mutation triggers
		var trait = trait_definitions.get_trait(current_trait)
		if trait and trait.mutation_chain.size() > 0:
			for next_trait in trait.mutation_chain:
				# Random chance for secondary mutations
				if randf() < 0.4:
					chain_queue.append(next_trait)
					mutation_triggered.emit(heir_id, current_trait, next_trait)

		chain_depth += 1

	chain_reaction_completed.emit(heir_id, processed.size())
	return processed


func check_evolution_path(trait_id: String, prestige: int, generation: int) -> String:
	if trait_id not in evolution_tree:
		return ""

	var paths = evolution_tree[trait_id]

	for path in paths:
		if _check_evolution_requirement(path, prestige, generation):
			return path.target_trait

	return ""


func apply_evolution(heir_id: String, source_trait: String, evolution_trait: String) -> Dictionary:
	var source = trait_definitions.get_trait(source_trait)
	var evolved = trait_definitions.get_trait(evolution_trait)

	if not source or not evolved:
		return {}

	var evolution_data = {
		"source_trait": source_trait,
		"evolved_trait": evolution_trait,
		"source_name": source.name,
		"evolved_name": evolved.name,
		"power_increase": 1.3,
		"new_abilities": evolved.ability_unlocks.duplicate()
	}

	return evolution_data


func get_mutation_history(heir_id: String) -> Array:
	if heir_id not in mutation_sequences:
		return []

	return mutation_sequences[heir_id].mutations.duplicate()


func get_total_mutations(heir_id: String) -> int:
	if heir_id not in mutation_sequences:
		return 0

	return mutation_sequences[heir_id].mutations.size()


func get_mutation_report(heir_id: String) -> Dictionary:
	var report = {
		"heir_id": heir_id,
		"mutation_count": 0,
		"mutations": [],
		"primary_mutation": "",
		"generation_triggered": 0
	}

	if heir_id not in mutation_sequences:
		return report

	var sequence = mutation_sequences[heir_id]
	report["mutation_count"] = sequence.mutations.size()
	report["mutations"] = sequence.mutations.duplicate()
	report["primary_mutation"] = sequence.primary_mutation
	report["generation_triggered"] = sequence.generation_triggered

	return report


func _process_chain_reactions(heir_id: String, initial_trait: String, generation: int, prestige: int, sequence: MutationSequence) -> void:
	var trait = trait_definitions.get_trait(initial_trait)
	if not trait or trait.mutation_chain.size() == 0:
		return

	sequence.chain_depth = 0
	var chain_queue = trait.mutation_chain.duplicate()

	while chain_queue.size() > 0 and sequence.chain_depth < 3:
		var next_trait_id = chain_queue.pop_front()

		# 40% chance secondary mutation triggers
		if randf() < 0.4:
			sequence.mutations.append(next_trait_id)
			mutation_triggered.emit(heir_id, initial_trait, next_trait_id)

			# Check if this triggers more mutations
			var next_trait = trait_definitions.get_trait(next_trait_id)
			if next_trait and next_trait.mutation_chain.size() > 0:
				chain_queue.append_array(next_trait.mutation_chain)

		sequence.chain_depth += 1


func _check_evolution_requirement(path: EvolutionPath, prestige: int, generation: int) -> bool:
	match path.requirement:
		"prestige":
			return prestige >= path.requirement_value
		"generation":
			return generation >= path.requirement_value
		"milestone":
			return (generation % path.requirement_value) == 0
		_:
			return false


func _initialize_evolution_tree() -> void:
	# Iron Blood can evolve into Legendary Blood
	var iron_blood_path = EvolutionPath.new("bloodline_iron_blood", "bloodline_legendary_blood")
	iron_blood_path.requirement = "prestige"
	iron_blood_path.requirement_value = 35000
	iron_blood_path.evolution_power = 1.5

	if "bloodline_iron_blood" not in evolution_tree:
		evolution_tree["bloodline_iron_blood"] = []
	evolution_tree["bloodline_iron_blood"].append(iron_blood_path)

	# Swift Reflexes can evolve into Absolute Speed
	var swift_path = EvolutionPath.new("bloodline_swift_reflexes", "bloodline_absolute_speed")
	swift_path.requirement = "prestige"
	swift_path.requirement_value = 35000
	swift_path.evolution_power = 1.5

	if "bloodline_swift_reflexes" not in evolution_tree:
		evolution_tree["bloodline_swift_reflexes"] = []
	evolution_tree["bloodline_swift_reflexes"].append(swift_path)

	# Mage Blood can evolve into Archmage
	var mage_path = EvolutionPath.new("bloodline_mage_blood", "bloodline_archmage")
	mage_path.requirement = "prestige"
	mage_path.requirement_value = 50000
	mage_path.evolution_power = 1.8

	if "bloodline_mage_blood" not in evolution_tree:
		evolution_tree["bloodline_mage_blood"] = []
	evolution_tree["bloodline_mage_blood"].append(mage_path)

	# Disciplined can evolve into Master Warrior
	var disciplined_path = EvolutionPath.new("acquired_disciplined", "acquired_master_warrior")
	disciplined_path.requirement = "prestige"
	disciplined_path.requirement_value = 25000
	disciplined_path.evolution_power = 1.3

	if "acquired_disciplined" not in evolution_tree:
		evolution_tree["acquired_disciplined"] = []
	evolution_tree["acquired_disciplined"].append(disciplined_path)
