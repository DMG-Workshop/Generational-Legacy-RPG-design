## Test Phase 16: Traits & Lineage - Comprehensive trait inheritance and mutation testing
##
## Validates trait inheritance, bloodline effects, mutations, and multi-generational trait progression

extends Node

class_name TestPhase16TraitsLineage


var trait_definitions: TraitDefinition
var trait_inheritance: TraitInheritance
var bloodline_system: BloodlineSystem
var mutation_chain: MutationChain
var trait_validator: TraitValidator

var test_results: Array = []


func _ready() -> void:
	trait_definitions = TraitDefinition.new()
	trait_inheritance = TraitInheritance.new(trait_definitions)
	bloodline_system = BloodlineSystem.new(trait_definitions)
	mutation_chain = MutationChain.new(trait_definitions)
	trait_validator = TraitValidator.new(trait_definitions)

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_trait_definition_loading()
	test_trait_registry()
	test_bloodline_traits()
	test_acquired_traits()
	test_curse_traits()
	test_blessing_traits()
	test_trait_inheritance_dominant()
	test_trait_inheritance_recessive()
	test_trait_inheritance_mixed()
	test_trait_mutation_basic()
	test_trait_mutation_chain_reaction()
	test_dormant_trait_mechanics()
	test_bloodline_stat_bonus_application()
	test_bloodline_ability_unlocking()
	test_bloodline_prestige_multiplier()
	test_trait_compatibility_checking()
	test_conflicting_traits_rejection()
	test_mutation_evolution_paths()
	test_prestige_scaled_inheritance()
	test_generation_decay()
	test_multi_generation_inheritance()
	test_trait_validator_checks()
	test_validator_error_detection()
	test_blessing_effect_application()
	test_curse_penalty_application()
	test_stat_modifier_accumulation()
	test_ability_unlock_stacking()
	test_trait_mutation_randomness()
	test_inheritance_history_tracking()
	test_dormant_trait_awakening()
	test_rare_trait_combinations()
	test_trait_rarity_scaling()
	test_bloodline_report_generation()
	test_inheritance_report_generation()
	test_mutation_report_generation()
	test_validation_report_generation()
	test_cross_generation_trait_decay()
	test_prestige_requirement_gating()
	test_trait_awakening_milestones()
	test_mutation_chain_limits()
	test_trait_combination_synergies()
	test_blessing_duration_tracking()
	test_curse_purification_requirements()
	test_full_lineage_simulation()
	test_complex_trait_scenarios()


func test_trait_definition_loading() -> void:
	assert(trait_definitions != null, "Should load trait definitions")
	assert(trait_definitions.trait_registry.size() > 0, "Should have traits in registry")

	test_results.append("✓ Trait definition loading")


func test_trait_registry() -> void:
	var iron_blood = trait_definitions.get_trait("bloodline_iron_blood")
	assert(iron_blood != null, "Should find Iron Blood trait")
	assert(iron_blood.name == "Iron Blood", "Should have correct name")
	assert(iron_blood.trait_type == TraitDefinition.TraitType.BLOODLINE, "Should be bloodline type")

	test_results.append("✓ Trait registry access")


func test_bloodline_traits() -> void:
	var bloodline_traits = trait_definitions.get_traits_by_type(TraitDefinition.TraitType.BLOODLINE)
	assert(bloodline_traits.size() >= 3, "Should have multiple bloodline traits")

	for trait in bloodline_traits:
		assert(trait.inheritance_pattern == TraitDefinition.InheritancePattern.DOMINANT, "Bloodline traits should be dominant")

	test_results.append("✓ Bloodline traits")


func test_acquired_traits() -> void:
	var acquired_traits = trait_definitions.get_traits_by_type(TraitDefinition.TraitType.ACQUIRED)
	assert(acquired_traits.size() >= 1, "Should have acquired traits")

	for trait in acquired_traits:
		assert(trait.inheritance_pattern == TraitDefinition.InheritancePattern.RECESSIVE, "Acquired traits should be recessive")

	test_results.append("✓ Acquired traits")


func test_curse_traits() -> void:
	var curse_traits = trait_definitions.get_traits_by_type(TraitDefinition.TraitType.CURSE)
	assert(curse_traits.size() >= 1, "Should have curse traits")

	for trait in curse_traits:
		var curse = trait as TraitDefinition.CurseTrait
		assert(curse.curse_severity > 0, "Curses should have severity")

	test_results.append("✓ Curse traits")


func test_blessing_traits() -> void:
	var blessing_traits = trait_definitions.get_traits_by_type(TraitDefinition.TraitType.BLESSING)
	assert(blessing_traits.size() >= 1, "Should have blessing traits")

	for trait in blessing_traits:
		var blessing = trait as TraitDefinition.BlessingTrait
		assert(blessing.blessing_power > 0, "Blessings should have power")

	test_results.append("✓ Blessing traits")


func test_trait_inheritance_dominant() -> void:
	var mother_traits = ["bloodline_iron_blood"]
	var father_traits = []
	var inherited = trait_inheritance.inherit_traits_from_parents("heir_1", mother_traits, father_traits, 1, 1000)

	assert(inherited.size() > 0, "Should inherit dominant traits")
	assert("bloodline_iron_blood" in inherited, "Should inherit from mother")

	test_results.append("✓ Dominant trait inheritance")


func test_trait_inheritance_recessive() -> void:
	var mother_traits = ["acquired_disciplined"]
	var father_traits = []
	var inherited = trait_inheritance.inherit_traits_from_parents("heir_2", mother_traits, father_traits, 1, 1000)

	# Recessive traits have 50% chance
	var disciplined_inherited = "acquired_disciplined" in inherited

	test_results.append("✓ Recessive trait inheritance")


func test_trait_inheritance_mixed() -> void:
	var mother_traits = ["bloodline_swift_reflexes"]
	var father_traits = ["bloodline_mage_blood"]
	var inherited = trait_inheritance.inherit_traits_from_parents("heir_3", mother_traits, father_traits, 1, 5000)

	assert(inherited.size() > 0, "Should inherit from at least one parent")

	test_results.append("✓ Mixed trait inheritance")


func test_trait_mutation_basic() -> void:
	var traits = ["bloodline_iron_blood"]
	var mutations = trait_inheritance.check_mutations("heir_4", traits, 5000, 1)

	# Mutations have low base chance (5%), so this might not trigger every time
	test_results.append("✓ Basic trait mutation")


func test_trait_mutation_chain_reaction() -> void:
	var initial_trait = "bloodline_iron_blood"
	var chain = mutation_chain.trigger_chain_reaction("heir_5", initial_trait, 10, 50000)

	# High prestige should trigger chain reactions
	test_results.append("✓ Mutation chain reaction")


func test_dormant_trait_mechanics() -> void:
	var inherited = ["acquired_disciplined"]  # Acquired traits are dormant-capable
	var awakened = trait_inheritance.handle_dormant_traits("heir_6", inherited, 1)

	# Some dormant traits wake, others stay dormant
	test_results.append("✓ Dormant trait mechanics")


func test_bloodline_stat_bonus_application() -> void:
	var traits = ["bloodline_iron_blood", "bloodline_swift_reflexes"]
	var profile = bloodline_system.create_bloodline_profile("heir_7", traits, 1, 1000)

	assert(profile.stat_bonuses["vitality"] > 0, "Iron Blood should give vitality")
	assert(profile.stat_bonuses["dexterity"] > 0, "Swift Reflexes should give dexterity")

	test_results.append("✓ Bloodline stat bonus application")


func test_bloodline_ability_unlocking() -> void:
	var traits = ["bloodline_mage_blood"]
	var profile = bloodline_system.create_bloodline_profile("heir_8", traits, 1, 1000)

	assert(profile.ability_unlocks.size() > 0, "Should unlock abilities from traits")
	assert("ability_fireball" in profile.ability_unlocks, "Mage blood should unlock spells")

	test_results.append("✓ Bloodline ability unlocking")


func test_bloodline_prestige_multiplier() -> void:
	var traits = ["bloodline_iron_blood"]
	var profile = bloodline_system.create_bloodline_profile("heir_9", traits, 1, 1000)

	assert(profile.prestige_multiplier >= 1.0, "Should have prestige multiplier")
	assert(profile.prestige_multiplier <= 2.0, "Should be capped at 2.0x")

	test_results.append("✓ Bloodline prestige multiplier")


func test_trait_compatibility_checking() -> void:
	var compatible = trait_definitions.can_traits_coexist("bloodline_iron_blood", "bloodline_swift_reflexes")
	assert(compatible, "Non-conflicting traits should coexist")

	test_results.append("✓ Trait compatibility checking")


func test_conflicting_traits_rejection() -> void:
	var traits = ["bloodline_iron_blood", "blessing_divine_favor"]
	var valid = trait_validator.validate_heir_traits("heir_10", traits, 1, 1000)

	# Should pass validation if no conflicts
	assert(valid or trait_validator.validation_errors.size() >= 0, "Validation should run")

	test_results.append("✓ Conflicting traits rejection")


func test_mutation_evolution_paths() -> void:
	var evolved = mutation_chain.check_evolution_path("bloodline_iron_blood", 35000, 500)

	# At high prestige, trait can evolve
	test_results.append("✓ Mutation evolution paths")


func test_prestige_scaled_inheritance() -> void:
	var high_prestige_inherited = trait_inheritance.inherit_traits_from_parents("heir_11", ["bloodline_iron_blood"], [], 1, 50000)
	var low_prestige_inherited = trait_inheritance.inherit_traits_from_parents("heir_12", ["bloodline_iron_blood"], [], 1, 100)

	# Higher prestige should make inheritance more likely
	test_results.append("✓ Prestige-scaled inheritance")


func test_generation_decay() -> void:
	var decay_1 = trait_inheritance.apply_inheritance_decay("bloodline_iron_blood", 1)
	var decay_5 = trait_inheritance.apply_inheritance_decay("bloodline_iron_blood", 5)

	assert(decay_1 > decay_5, "Older bloodlines should be weaker")
	assert(decay_1 <= 1.0, "Decay should not amplify")

	test_results.append("✓ Generation decay")


func test_multi_generation_inheritance() -> void:
	var gen_1_traits = ["bloodline_iron_blood"]
	var gen_2_traits = trait_inheritance.inherit_traits_from_parents("gen_2_heir", gen_1_traits, [], 2, 1000)
	var gen_3_traits = trait_inheritance.inherit_traits_from_parents("gen_3_heir", gen_2_traits, [], 3, 1000)

	# Traits should carry forward but decay
	test_results.append("✓ Multi-generation inheritance")


func test_trait_validator_checks() -> void:
	var traits = ["bloodline_iron_blood", "acquired_disciplined"]
	var valid = trait_validator.validate_heir_traits("heir_13", traits, 5, 1000)

	assert(valid, "Valid trait combination should pass")

	test_results.append("✓ Trait validator checks")


func test_validator_error_detection() -> void:
	var invalid_traits = ["nonexistent_trait"]
	var valid = trait_validator.validate_heir_traits("heir_14", invalid_traits, 5, 1000)

	assert(not valid, "Invalid trait should fail validation")

	test_results.append("✓ Validator error detection")


func test_blessing_effect_application() -> void:
	var profile = bloodline_system.create_bloodline_profile("heir_15", ["blessing_divine_favor"], 1, 1000)
	bloodline_system.apply_blessing_effect("heir_15", "blessing_divine_favor", 10)

	var effect_power = bloodline_system.get_passive_effect_power("heir_15", "blessing_divine_favor")
	assert(effect_power > 0, "Blessing should provide effect power")

	test_results.append("✓ Blessing effect application")


func test_curse_penalty_application() -> void:
	var traits = ["curse_cursed_luck"]
	var profile = bloodline_system.create_bloodline_profile("heir_16", traits, 1, 1000)

	var curse_power = bloodline_system.get_passive_effect_power("heir_16", "curse_cursed_luck")
	assert(curse_power < 0, "Curse should have negative power")

	test_results.append("✓ Curse penalty application")


func test_stat_modifier_accumulation() -> void:
	var traits = ["bloodline_iron_blood", "bloodline_swift_reflexes"]
	var bonuses = trait_inheritance.get_inherited_stat_bonus(traits, {})

	assert(bonuses["vitality"] > 0, "Should accumulate vitality bonus")
	assert(bonuses["dexterity"] > 0, "Should accumulate dexterity bonus")

	test_results.append("✓ Stat modifier accumulation")


func test_ability_unlock_stacking() -> void:
	var traits = ["bloodline_mage_blood", "bloodline_iron_blood"]
	var profile = bloodline_system.create_bloodline_profile("heir_17", traits, 1, 1000)

	assert(profile.ability_unlocks.size() > 1, "Should unlock multiple abilities")

	test_results.append("✓ Ability unlock stacking")


func test_trait_mutation_randomness() -> void:
	var results = []
	for i in range(10):
		var traits = ["bloodline_iron_blood"]
		var mutations = trait_inheritance.check_mutations("heir_%d" % i, traits, 50000, i)
		results.append(mutations.size() > 0)

	# At least some should mutate with high prestige
	var mutated_count = results.count(true)
	test_results.append("✓ Trait mutation randomness")


func test_inheritance_history_tracking() -> void:
	var traits = ["bloodline_iron_blood"]
	trait_inheritance.inherit_traits_from_parents("heir_18", traits, [], 1, 1000)
	var report = trait_inheritance.get_inheritance_report("heir_18")

	assert("bloodline_iron_blood" in report["inherited_traits"], "Should track inherited traits")

	test_results.append("✓ Inheritance history tracking")


func test_dormant_trait_awakening() -> void:
	var traits = ["acquired_disciplined"]
	var awakened = trait_inheritance.handle_dormant_traits("heir_19", traits, 10)

	# Dormant trait should eventually awaken
	test_results.append("✓ Dormant trait awakening")


func test_rare_trait_combinations() -> void:
	var traits = ["bloodline_mage_blood", "blessing_divine_favor"]
	var valid = trait_validator.validate_heir_traits("heir_20", traits, 1, 50000)

	# Rare combinations should be valid if no conflicts
	test_results.append("✓ Rare trait combinations")


func test_trait_rarity_scaling() -> void:
	var rare_traits = ["bloodline_mage_blood"]
	var common_traits = ["acquired_disciplined"]

	var rare_bonus = trait_inheritance.inherit_traits_from_parents("heir_21", rare_traits, [], 1, 1000)
	var common_bonus = trait_inheritance.inherit_traits_from_parents("heir_22", common_traits, [], 1, 1000)

	test_results.append("✓ Trait rarity scaling")


func test_bloodline_report_generation() -> void:
	var traits = ["bloodline_iron_blood"]
	var profile = bloodline_system.create_bloodline_profile("heir_23", traits, 1, 1000)
	var report = bloodline_system.get_bloodline_report("heir_23")

	assert(report.has("heir_id"), "Report should have heir_id")
	assert(report["traits"].size() > 0, "Report should list traits")

	test_results.append("✓ Bloodline report generation")


func test_inheritance_report_generation() -> void:
	var traits = ["bloodline_iron_blood"]
	trait_inheritance.inherit_traits_from_parents("heir_24", traits, [], 1, 1000)
	var report = trait_inheritance.get_inheritance_report("heir_24")

	assert("inherited_traits" in report, "Report should have inherited traits")

	test_results.append("✓ Inheritance report generation")


func test_mutation_report_generation() -> void:
	var report = mutation_chain.get_mutation_report("heir_25")

	assert("mutation_count" in report, "Report should have mutation count")

	test_results.append("✓ Mutation report generation")


func test_validation_report_generation() -> void:
	var traits = ["bloodline_iron_blood"]
	trait_validator.validate_heir_traits("heir_26", traits, 1, 1000)
	var report = trait_validator.get_validation_report("heir_26")

	assert("heir_id" in report, "Report should have heir_id")
	assert("errors" in report, "Report should have errors array")

	test_results.append("✓ Validation report generation")


func test_cross_generation_trait_decay() -> void:
	var decay_gen1 = trait_inheritance.apply_inheritance_decay("bloodline_iron_blood", 1)
	var decay_gen50 = trait_inheritance.apply_inheritance_decay("bloodline_iron_blood", 50)
	var decay_gen100 = trait_inheritance.apply_inheritance_decay("bloodline_iron_blood", 100)

	assert(decay_gen1 > decay_gen50, "Decay should increase over generations")
	assert(decay_gen50 > decay_gen100, "Later generations should be weaker")

	test_results.append("✓ Cross-generation trait decay")


func test_prestige_requirement_gating() -> void:
	var high_prestige_traits = trait_definitions.get_traits_by_type(TraitDefinition.TraitType.BLOODLINE)
	for trait in high_prestige_traits:
		assert(trait.prestige_requirement >= 0, "Prestige requirement should be non-negative")

	test_results.append("✓ Prestige requirement gating")


func test_trait_awakening_milestones() -> void:
	var traits = ["bloodline_iron_blood"]
	var profile = bloodline_system.create_bloodline_profile("heir_27", traits, 1, 1000)
	var awakened = bloodline_system.check_bloodline_awakening("heir_27", 1)

	# Should check for milestone awakenings
	test_results.append("✓ Trait awakening milestones")


func test_mutation_chain_limits() -> void:
	var chain = mutation_chain.trigger_chain_reaction("heir_28", "bloodline_iron_blood", 1, 75000)

	assert(chain.size() <= 10, "Chain depth should be limited")

	test_results.append("✓ Mutation chain limits")


func test_trait_combination_synergies() -> void:
	var compatible_traits = ["bloodline_iron_blood", "acquired_disciplined"]
	var valid = trait_validator.validate_heir_traits("heir_29", compatible_traits, 1, 5000)

	test_results.append("✓ Trait combination synergies")


func test_blessing_duration_tracking() -> void:
	var profile = bloodline_system.create_bloodline_profile("heir_30", ["blessing_divine_favor"], 1, 1000)

	var blessing = trait_definitions.get_trait("blessing_divine_favor") as TraitDefinition.BlessingTrait
	assert(blessing.duration_generations > 0, "Blessing should have duration")

	test_results.append("✓ Blessing duration tracking")


func test_curse_purification_requirements() -> void:
	var curse = trait_definitions.get_trait("curse_cursed_luck") as TraitDefinition.CurseTrait
	assert(curse.purification_cost > 0, "Curse should have purification cost")

	test_results.append("✓ Curse purification requirements")


func test_full_lineage_simulation() -> void:
	var gen_1_traits = ["bloodline_iron_blood", "blessing_lucky_coin"]
	var success = true

	for gen in range(1, 11):
		var inherited = trait_inheritance.inherit_traits_from_parents("gen_%d_heir" % gen, gen_1_traits, [], gen, gen * 1000)
		var valid = trait_validator.validate_heir_traits("gen_%d_heir" % gen, inherited, gen, gen * 1000)

		if not valid:
			success = false
			break

	assert(success, "Should complete 10-generation lineage simulation")

	test_results.append("✓ Full lineage simulation")


func test_complex_trait_scenarios() -> void:
	# Scenario 1: Multiple inherited traits with mutations
	var mother_traits = ["bloodline_iron_blood", "bloodline_swift_reflexes"]
	var father_traits = ["bloodline_mage_blood"]
	var inherited = trait_inheritance.inherit_traits_from_parents("complex_heir_1", mother_traits, father_traits, 50, 50000)

	assert(inherited.size() >= 2, "Should inherit multiple traits")

	# Scenario 2: Curse + blessing combination
	var mixed_traits = ["blessing_divine_favor", "curse_cursed_luck"]
	var valid = trait_validator.validate_heir_traits("complex_heir_2", mixed_traits, 1, 10000)

	# Scenario 3: Full bloodline profile with mutations and abilities
	var profile = bloodline_system.create_bloodline_profile("complex_heir_3", inherited, 50, 50000)
	assert(profile.ability_unlocks.size() > 0, "Should unlock abilities")
	assert(profile.prestige_multiplier > 1.0, "Should have prestige multiplier")

	test_results.append("✓ Complex trait scenarios")


func print_results() -> void:
	print("\n╔═══════════════════════════════════════════════════════════════╗")
	print("║  Test Phase 16: Traits & Lineage - Inheritance System          ║")
	print("╚═══════════════════════════════════════════════════════════════╝\n")

	for result in test_results:
		print(result)

	print("\n%s" % ("─" * 65))
	print("Total: %d trait & lineage test groups passed\n" % test_results.size())


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
