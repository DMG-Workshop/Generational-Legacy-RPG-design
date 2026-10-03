## Family tree and trait inheritance system
##
## Handles:
## - Creating new heirs from parents
## - Trait inheritance with probability
## - Trait mutations and dormancy
## - Tracking the bloodline across 999 generations

extends Node

class_name Lineage

## The family tree, indexed by generation number
var family_tree: Array[Heir] = []

## Trait definitions, loaded from /data/traits/
var trait_catalog: Dictionary = {}

## Random number generator, seeded for reproducibility
var rng: RandomNumberGenerator

## Current generation
var current_generation: int = 0


func _init(seed_value: int = 0) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	_load_traits()


## Create the first ancestor
func create_founder(name: String, class_id: String, job_id: String) -> Heir:
	var founder = Heir.new()
	founder.name = name
	founder.generation = 0
	founder.class_id = class_id
	founder.job_id = job_id
	founder.mother = null
	founder.father = null
	founder.traits = []
	founder.birth_year = 0

	family_tree.append(founder)
	current_generation = 0
	return founder


## Produce an heir from two parents
func produce_heir(
	mother: Heir,
	father: Heir,
	name: String,
	class_id: String,
	job_id: String
) -> Heir:
	var heir = Heir.new()
	heir.name = name
	heir.generation = mother.generation + 1
	heir.mother = mother
	heir.father = father
	heir.class_id = class_id
	heir.job_id = job_id
	heir.birth_year = (mother.generation * 25)  # ~25 years per generation
	heir.traits = []

	# Inherit traits from both parents
	_inherit_traits(heir, mother, father)

	family_tree.append(heir)
	return heir


## Inherit traits from parents
func _inherit_traits(heir: Heir, mother: Heir, father: Heir) -> void:
	var inherited_traits: Dictionary = {}

	# Collect traits from both parents
	for parent in [mother, father]:
		for trait_id in parent.traits:
			if not inherited_traits.has(trait_id):
				inherited_traits[trait_id] = 0
			inherited_traits[trait_id] += 1

	# Roll inheritance for each trait
	for trait_id in inherited_traits.keys():
		if not trait_catalog.has(trait_id):
			continue

		var trait_def = trait_catalog[trait_id]
		var parents_with_trait = inherited_traits[trait_id]
		var inherit_chance = trait_def.get("inherit_chance", 0.5)

		# Modifier: if both parents have it, higher chance
		if parents_with_trait >= 2:
			inherit_chance += trait_def.get("family_bonus", 0.0)

		if rng.randf() < inherit_chance:
			heir.traits.append(trait_id)

			# Check for mutation
			var mutations = trait_def.get("mutations", [])
			if mutations.size() > 0 and rng.randf() < 0.15:  # 15% mutation chance
				var mutated_trait = mutations[rng.randi() % mutations.size()]
				heir.traits[-1] = mutated_trait
		else:
			# Trait didn't pass; check for dormancy
			var dormant_chance = trait_def.get("dormant_chance", 0.0)
			if rng.randf() < dormant_chance:
				# Mark as dormant (will be stored separately in full implementation)
				pass


## Load trait definitions from JSON files
func _load_traits() -> void:
	# TODO: Load from /data/traits/*.json
	# For now, trait_catalog is empty; data is loaded at runtime
	pass


## Get an heir by generation
func get_heir(generation: int) -> Heir:
	if generation >= 0 and generation < family_tree.size():
		return family_tree[generation]
	return null


## Get the current heir
func get_current_heir() -> Heir:
	return get_heir(current_generation)


## Advance to the next generation
func advance_generation(next_heir: Heir) -> void:
	current_generation += 1


## Return the size of the family tree
func generation_count() -> int:
	return family_tree.size()
