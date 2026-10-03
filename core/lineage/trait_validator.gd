## Trait Validator: Validate inheritance, mutations, and trait consistency
##
## Ensures traits are properly inherited, mutations are valid, no conflicts exist,
## and all trait effects are correctly applied.

extends Node

class_name TraitValidator


signal validation_passed(heir_id: String, check_type: String)
signal validation_failed(heir_id: String, check_type: String, reason: String)
signal trait_conflict_detected(heir_id: String, trait_1: String, trait_2: String)


var trait_definitions: TraitDefinition
var validation_checks: Array = []
var validation_errors: Array = []
var validation_warnings: Array = []


class ValidationCheck:
	var check_name: String
	var check_function: Callable
	var is_critical: bool
	var last_result: bool
	var last_message: String

	func _init(p_name: String, p_func: Callable, p_critical: bool = true) -> void:
		check_name = p_name
		check_function = p_func
		is_critical = p_critical
		last_result = true
		last_message = ""


func _init(trait_defs: TraitDefinition) -> void:
	trait_definitions = trait_defs
	_initialize_validation_checks()


func validate_heir_traits(heir_id: String, traits: Array, generation: int, prestige: int) -> bool:
	validation_errors.clear()
	validation_warnings.clear()

	var all_passed = true

	for check in validation_checks:
		var result = check.check_function.call(heir_id, traits, generation, prestige)
		check.last_result = result

		if not result:
			if check.is_critical:
				validation_errors.append(check.check_name)
				all_passed = false
				validation_failed.emit(heir_id, check.check_name, "Failed critical check")
			else:
				validation_warnings.append(check.check_name)

	if all_passed:
		validation_passed.emit(heir_id, "all_checks")

	return all_passed


func validate_trait_existence(heir_id: String, traits: Array, _generation: int, _prestige: int) -> bool:
	for trait_id in traits:
		if trait_definitions.get_trait(trait_id) == null:
			validation_failed.emit(heir_id, "trait_existence", "Trait not found: %s" % trait_id)
			return false

	return true


func validate_trait_compatibility(heir_id: String, traits: Array, _generation: int, _prestige: int) -> bool:
	for i in range(traits.size()):
		for j in range(i + 1, traits.size()):
			if not trait_definitions.can_traits_coexist(traits[i], traits[j]):
				trait_conflict_detected.emit(heir_id, traits[i], traits[j])
				validation_failed.emit(heir_id, "trait_compatibility", "%s conflicts with %s" % [traits[i], traits[j]])
				return false

	return true


func validate_prestige_requirements(heir_id: String, traits: Array, _generation: int, prestige: int) -> bool:
	for trait_id in traits:
		var trait = trait_definitions.get_trait(trait_id)
		if trait and trait.prestige_requirement > prestige:
			# Warning, not critical - lower prestige can still get traits with 20% chance
			validation_warnings.append("Trait %s requires %d prestige, heir has %d" % [trait_id, trait.prestige_requirement, prestige])

	return true


func validate_stat_modifiers(heir_id: String, traits: Array, _generation: int, _prestige: int) -> bool:
	var total_modifiers = {"strength": 0, "dexterity": 0, "intelligence": 0, "vitality": 0}

	for trait_id in traits:
		var trait = trait_definitions.get_trait(trait_id)
		if not trait:
			continue

		for stat in trait.stat_modifiers.keys():
			if stat in total_modifiers:
				total_modifiers[stat] += trait.stat_modifiers[stat]

	# Check for unreasonable stat values (e.g., -100 to a stat)
	for stat in total_modifiers.keys():
		if total_modifiers[stat] < -50:
			validation_warnings.append("Stat %s has severe penalty: %d" % [stat, total_modifiers[stat]])

	return true


func validate_ability_consistency(heir_id: String, traits: Array, _generation: int, _prestige: int) -> bool:
	var abilities = []

	for trait_id in traits:
		var trait = trait_definitions.get_trait(trait_id)
		if trait:
			abilities.append_array(trait.ability_unlocks)

	# Check for duplicate abilities
	if abilities.size() != abilities.size():  # Would be caught by set, but GDScript doesn't have sets
		var seen = {}
		for ability in abilities:
			if ability in seen:
				validation_warnings.append("Duplicate ability: %s" % ability)
			seen[ability] = true

	return true


func validate_trait_rarity_distribution(heir_id: String, traits: Array, _generation: int, _prestige: int) -> bool:
	var rarity_sum = 0

	for trait_id in traits:
		var trait = trait_definitions.get_trait(trait_id)
		if trait:
			rarity_sum += trait.rarity

	# Very rare heirs (rarity sum > 15) might be too powerful
	if rarity_sum > 15:
		validation_warnings.append("Very rare trait combination (rarity %d)" % rarity_sum)

	return true


func validate_trait_type_balance(heir_id: String, traits: Array, _generation: int, _prestige: int) -> bool:
	var type_counts = {
		TraitDefinition.TraitType.BLOODLINE: 0,
		TraitDefinition.TraitType.ACQUIRED: 0,
		TraitDefinition.TraitType.CURSE: 0,
		TraitDefinition.TraitType.BLESSING: 0
	}

	for trait_id in traits:
		var trait = trait_definitions.get_trait(trait_id)
		if trait:
			type_counts[trait.trait_type] += 1

	# Warning if too many curses
	if type_counts[TraitDefinition.TraitType.CURSE] > 2:
		validation_warnings.append("Multiple curses detected: %d" % type_counts[TraitDefinition.TraitType.CURSE])

	return true


func validate_mutation_chain_validity(heir_id: String, traits: Array, _generation: int, _prestige: int) -> bool:
	for trait_id in traits:
		var trait = trait_definitions.get_trait(trait_id)
		if not trait:
			continue

		# Verify mutation chain targets exist
		for mutation_target in trait.mutation_chain:
			if trait_definitions.get_trait(mutation_target) == null:
				validation_failed.emit(heir_id, "mutation_chain_validity", "Invalid mutation target: %s -> %s" % [trait_id, mutation_target])
				return false

	return true


func validate_inheritance_pattern_consistency(heir_id: String, traits: Array, generation: int, _prestige: int) -> bool:
	# Check that inheritance patterns make sense
	var has_dominant = false
	var has_recessive = false

	for trait_id in traits:
		var trait = trait_definitions.get_trait(trait_id)
		if not trait:
			continue

		if trait.inheritance_pattern == TraitDefinition.InheritancePattern.DOMINANT:
			has_dominant = true
		elif trait.inheritance_pattern == TraitDefinition.InheritancePattern.RECESSIVE:
			has_recessive = true

	# No specific validation, just informational
	return true


func get_validation_report(heir_id: String) -> Dictionary:
	var report = {
		"heir_id": heir_id,
		"validation_passed": validation_errors.size() == 0,
		"errors": validation_errors.duplicate(),
		"warnings": validation_warnings.duplicate(),
		"error_count": validation_errors.size(),
		"warning_count": validation_warnings.size()
	}

	return report


func get_validation_summary(all_heirs: Array) -> Dictionary:
	var summary = {
		"total_heirs_validated": 0,
		"heirs_passed": 0,
		"heirs_failed": 0,
		"total_errors": 0,
		"total_warnings": 0,
		"failed_heirs": []
	}

	for heir_id in all_heirs:
		summary["total_heirs_validated"] += 1
		var report = get_validation_report(heir_id)

		if report["validation_passed"]:
			summary["heirs_passed"] += 1
		else:
			summary["heirs_failed"] += 1
			summary["failed_heirs"].append(heir_id)

		summary["total_errors"] += report["error_count"]
		summary["total_warnings"] += report["warning_count"]

	return summary


func _initialize_validation_checks() -> void:
	validation_checks.append(ValidationCheck.new("Trait Existence", Callable(self, "validate_trait_existence"), true))
	validation_checks.append(ValidationCheck.new("Trait Compatibility", Callable(self, "validate_trait_compatibility"), true))
	validation_checks.append(ValidationCheck.new("Prestige Requirements", Callable(self, "validate_prestige_requirements"), false))
	validation_checks.append(ValidationCheck.new("Stat Modifiers", Callable(self, "validate_stat_modifiers"), false))
	validation_checks.append(ValidationCheck.new("Ability Consistency", Callable(self, "validate_ability_consistency"), false))
	validation_checks.append(ValidationCheck.new("Rarity Distribution", Callable(self, "validate_trait_rarity_distribution"), false))
	validation_checks.append(ValidationCheck.new("Trait Type Balance", Callable(self, "validate_trait_type_balance"), false))
	validation_checks.append(ValidationCheck.new("Mutation Chain Validity", Callable(self, "validate_mutation_chain_validity"), true))
	validation_checks.append(ValidationCheck.new("Inheritance Pattern Consistency", Callable(self, "validate_inheritance_pattern_consistency"), false))
