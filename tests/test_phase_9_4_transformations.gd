## Test Suite for Phase 9.4: Advanced Fate & Transformations
##
## Comprehensive tests for corruption, curses, blessings, class evolution,
## and integrated fate transformation system

extends GutTest


var corruption_system: CorruptionSystem
var curse_system: CurseSystem
var blessing_system: BlessingSystem
var class_evolution_system: ClassEvolutionSystem
var fate_transformation_manager: FateTransformationManager


func before_each() -> void:
	corruption_system = CorruptionSystem.new()
	curse_system = CurseSystem.new()
	blessing_system = BlessingSystem.new()
	class_evolution_system = ClassEvolutionSystem.new()
	fate_transformation_manager = FateTransformationManager.new(corruption_system, curse_system, blessing_system, class_evolution_system)


# ============================================================
# Corruption System Tests
# ============================================================

func test_corruption_add_and_track() -> void:
	var level = corruption_system.add_corruption("hero1", 25)
	assert_eq(level, 25, "Should add corruption correctly")
	assert_eq(corruption_system.get_corruption_level("hero1"), 25)


func test_corruption_milestone_tainted() -> void:
	corruption_system.add_corruption("hero1", 25)
	var penalties = corruption_system.get_corruption_stat_penalty("hero1")
	assert_eq(penalties["wisdom"], -1, "Should apply tainted penalties")
	assert_true(corruption_system.is_corrupted("hero1"))


func test_corruption_milestone_corrupted() -> void:
	corruption_system.add_corruption("hero1", 50)
	var penalties = corruption_system.get_corruption_stat_penalty("hero1")
	assert_eq(penalties["wisdom"], -4, "Should apply corrupted penalties (cumulative)")


func test_corruption_milestone_transformed() -> void:
	corruption_system.add_corruption("hero1", 75)
	var summary = corruption_system.get_corruption_summary("hero1")
	assert_eq(summary["stage"], "Transformed")


func test_corruption_milestone_consumed() -> void:
	corruption_system.add_corruption("hero1", 100)
	assert_true(corruption_system.is_fully_corrupted("hero1"))
	var penalties = corruption_system.get_corruption_stat_penalty("hero1")
	assert_eq(penalties["strength"], -10, "Should have massive penalties when consumed")


func test_corruption_cap_at_100() -> void:
	corruption_system.add_corruption("hero1", 150)
	assert_eq(corruption_system.get_corruption_level("hero1"), 100)


func test_corruption_removal() -> void:
	corruption_system.add_corruption("hero1", 50)
	corruption_system.remove_corruption("hero1", 25)
	assert_eq(corruption_system.get_corruption_level("hero1"), 25)


func test_corruption_inheritance() -> void:
	corruption_system.add_corruption("hero1", 100)
	var inherited = corruption_system.inherit_corruption("hero2", "hero1", 0.3)
	assert_eq(inherited, 30, "Should inherit 30% of corruption")


# ============================================================
# Curse System Tests
# ============================================================

func test_curse_apply_weakness() -> void:
	var result = curse_system.apply_curse("hero1", CurseSystem.CurseType.WEAKNESS)
	assert_true(result["success"])
	assert_eq(result["curse"], "Weakness")
	assert_true(curse_system.has_curse("hero1", CurseSystem.CurseType.WEAKNESS))


func test_curse_stat_penalty() -> void:
	curse_system.apply_curse("hero1", CurseSystem.CurseType.WEAKNESS)
	var penalty = curse_system.get_curse_stat_penalty("hero1")
	assert_eq(penalty["strength"], -3)


func test_curse_stacking_multiple() -> void:
	curse_system.apply_curse("hero1", CurseSystem.CurseType.WEAKNESS)
	curse_system.apply_curse("hero1", CurseSystem.CurseType.FRAILTY)
	var active = curse_system.get_active_curses("hero1")
	assert_eq(active.size(), 2)


func test_curse_mutation_amplify() -> void:
	curse_system.apply_curse("hero1", CurseSystem.CurseType.WEAKNESS)
	curse_system.mutate_curse("hero1", CurseSystem.CurseType.WEAKNESS, "amplify")
	var penalty = curse_system.get_curse_stat_penalty("hero1")
	assert_eq(penalty["strength"], -5, "Amplified curse should have 1.5x effect")


func test_curse_chain_to_heir() -> void:
	curse_system.apply_curse("hero1", CurseSystem.CurseType.MADNESS)
	var chained = curse_system.chain_curse_to_heir("hero2", "hero1", CurseSystem.CurseType.MADNESS)
	assert_true(chained)
	assert_true(curse_system.has_curse("hero2", CurseSystem.CurseType.MADNESS))


func test_curse_removal() -> void:
	curse_system.apply_curse("hero1", CurseSystem.CurseType.WEAKNESS)
	var removed = curse_system.remove_curse("hero1", CurseSystem.CurseType.WEAKNESS)
	assert_true(removed)
	assert_false(curse_system.has_curse("hero1", CurseSystem.CurseType.WEAKNESS))


func test_curse_cleanse_all() -> void:
	curse_system.apply_curse("hero1", CurseSystem.CurseType.WEAKNESS)
	curse_system.apply_curse("hero1", CurseSystem.CurseType.MADNESS)
	var count = curse_system.cleanse_curses("hero1")
	assert_eq(count, 2)
	assert_eq(curse_system.get_active_curses("hero1").size(), 0)


# ============================================================
# Blessing System Tests
# ============================================================

func test_blessing_grant_vigor() -> void:
	var result = blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	assert_true(result["success"])
	assert_eq(result["blessing"], "Vigor")
	assert_true(blessing_system.has_blessing("hero1", BlessingSystem.BlessingType.VIGOR))


func test_blessing_stat_bonus() -> void:
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	var bonus = blessing_system.get_blessing_stat_bonus("hero1")
	assert_eq(bonus["strength"], 2)
	assert_eq(bonus["constitution"], 2)


func test_blessing_stacking() -> void:
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	var stacks = blessing_system.get_blessing_stacks("hero1", BlessingSystem.BlessingType.VIGOR)
	assert_eq(stacks, 3)


func test_blessing_max_stacks_cap() -> void:
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.FORTUNE)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.FORTUNE)
	var result = blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.FORTUNE)
	assert_false(result["success"], "Should not exceed max stacks")


func test_blessing_scaled_bonus() -> void:
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	var bonus = blessing_system.get_blessing_stat_bonus("hero1")
	assert_eq(bonus["strength"], 4, "Bonus should scale with stacks (2 * 2)")


func test_blessing_inheritance() -> void:
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	var inherited = blessing_system.inherit_blessings("hero2", "hero1")
	assert_eq(inherited, 1, "Should inherit 1 blessing")
	var stacks = blessing_system.get_blessing_stacks("hero2", BlessingSystem.BlessingType.VIGOR)
	assert_eq(stacks, 1, "Should inherit at 50% stacks (2 * 0.5 = 1)")


func test_blessing_multiple_types() -> void:
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.CLARITY)
	var blessings = blessing_system.get_active_blessings("hero1")
	assert_eq(blessings.size(), 2)


# ============================================================
# Class Evolution System Tests
# ============================================================

func test_class_initialization() -> void:
	var success = class_evolution_system.initialize_heir_class("hero1", "Warrior")
	assert_true(success)
	assert_eq(class_evolution_system.get_heir_class("hero1"), "Warrior")


func test_class_get_stats() -> void:
	class_evolution_system.initialize_heir_class("hero1", "Warrior")
	var stats = class_evolution_system.get_class_stats("Warrior")
	assert_eq(stats["strength"], 3)


func test_class_evolution_available() -> void:
	class_evolution_system.initialize_heir_class("hero1", "Warrior")
	var available = class_evolution_system.get_available_evolutions("hero1")
	assert_eq(available.size(), 3, "Warrior should have 3 evolution options")
	assert_true(available.has("Berserker"))


func test_class_evolution_berserker() -> void:
	class_evolution_system.initialize_heir_class("hero1", "Warrior")
	var result = class_evolution_system.evolve_class("hero1", "Berserker", 100)
	assert_true(result["success"])
	assert_eq(class_evolution_system.get_heir_advanced_class("hero1"), "Berserker")


func test_class_evolution_insufficient_fate() -> void:
	class_evolution_system.initialize_heir_class("hero1", "Warrior")
	var result = class_evolution_system.evolve_class("hero1", "Berserker", 50)
	assert_false(result["success"], "Should fail with insufficient Fate")
	assert_eq(result["reason"], "insufficient_fate")


func test_class_evolution_prevents_double_evolution() -> void:
	class_evolution_system.initialize_heir_class("hero1", "Warrior")
	class_evolution_system.evolve_class("hero1", "Berserker", 100)
	var result = class_evolution_system.evolve_class("hero1", "Paladin", 100)
	assert_false(result["success"], "Should not allow evolving again")


func test_class_respec() -> void:
	class_evolution_system.initialize_heir_class("hero1", "Warrior")
	class_evolution_system.evolve_class("hero1", "Berserker", 100)
	var result = class_evolution_system.respec_class("hero1")
	assert_true(result["success"])
	assert_eq(class_evolution_system.get_heir_advanced_class("hero1"), "")


func test_class_rogue_evolution() -> void:
	class_evolution_system.initialize_heir_class("hero1", "Rogue")
	var available = class_evolution_system.get_available_evolutions("hero1")
	assert_true(available.has("Assassin"))
	var result = class_evolution_system.evolve_class("hero1", "Assassin", 100)
	assert_true(result["success"])


func test_class_mage_evolution_paths() -> void:
	class_evolution_system.initialize_heir_class("hero1", "Mage")
	var evolutions = class_evolution_system.get_available_evolutions("hero1")
	assert_true(evolutions.has("Sorcerer"))
	assert_true(evolutions.has("Sage"))
	assert_true(evolutions.has("Arcanist"))


# ============================================================
# Fate Transformation Manager Tests
# ============================================================

func test_initialization_sets_pure_state() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	var state = fate_transformation_manager.get_heir_transformation_state("hero1")
	assert_eq(state["state"], "pure")


func test_corruption_applies_to_state() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	corruption_system.add_corruption("hero1", 25)
	var state = fate_transformation_manager.get_heir_transformation_state("hero1")
	assert_eq(state["corruption_level"], 25)


func test_encounter_corruption_risk() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	# Easy encounter
	var risk_easy = fate_transformation_manager.apply_encounter_corruption("hero1", 0)
	assert_true(risk_easy >= 0 and risk_easy <= 5)

	# Hard encounter
	var initial = corruption_system.get_corruption_level("hero1")
	var risk_hard = fate_transformation_manager.apply_encounter_corruption("hero2", 2)
	assert_true(risk_hard >= 5 and risk_hard <= 15)


func test_shrine_blessing_reduces_corruption() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	corruption_system.add_corruption("hero1", 50)
	fate_transformation_manager.apply_shrine_blessing("hero1")
	var corruption = corruption_system.get_corruption_level("hero1")
	assert_eq(corruption, 40, "Shrine should reduce corruption by 10")


func test_evolution_opportunity_detection() -> void:
	class_evolution_system.initialize_heir_class("hero1", "Warrior")
	var opportunities = fate_transformation_manager.check_evolution_opportunity("hero1", 100)
	assert_eq(opportunities.size(), 1, "Should detect one possible evolution")
	assert_true(opportunities.has("Berserker"))


func test_evolution_reduces_corruption() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	class_evolution_system.initialize_heir_class("hero1", "Warrior")
	corruption_system.add_corruption("hero1", 60)
	fate_transformation_manager.trigger_class_evolution("hero1", "Berserker", 100)
	var corruption = corruption_system.get_corruption_level("hero1")
	assert_eq(corruption, 30, "Evolution should reduce corruption by 30")


func test_combined_stat_modifiers() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	class_evolution_system.initialize_heir_class("hero1", "Warrior")
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)

	var modifiers = fate_transformation_manager.get_combined_stat_modifiers("hero1")
	assert_eq(modifiers["strength"], 5, "Warrior (3) + Vigor (2) = 5")


func test_transformation_summary_complete() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	class_evolution_system.initialize_heir_class("hero1", "Warrior")
	corruption_system.add_corruption("hero1", 25)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)

	var summary = fate_transformation_manager.get_transformation_summary("hero1")
	assert_eq(summary["state"], "tainted")
	assert_eq(summary["corruption"]["level"], 25)
	assert_eq(summary["blessing"]["count"], 1)


func test_redemption_event() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	curse_system.apply_curse("hero1", CurseSystem.CurseType.MADNESS)
	curse_system.apply_curse("hero1", CurseSystem.CurseType.WEAKNESS)
	corruption_system.add_corruption("hero1", 60)

	var result = fate_transformation_manager.trigger_redemption("hero1")
	assert_true(result["success"])
	assert_eq(result["curses_removed"], 2)
	assert_true(corruption_system.get_corruption_level("hero1") < 60)


func test_inheritance_of_transformations() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	fate_transformation_manager.initialize_heir_transformation("hero2")

	corruption_system.add_corruption("hero1", 100)
	curse_system.apply_curse("hero1", CurseSystem.CurseType.VOID_MARK)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)

	var inherited = fate_transformation_manager.inherit_transformations("hero2", "hero1")
	assert_eq(inherited["corruption_inherited"], 30, "30% of corruption inherited")
	assert_eq(inherited["curses_chained"], 1)
	assert_eq(inherited["blessings_inherited"], 1)


# ============================================================
# State Transition Tests
# ============================================================

func test_state_pure_to_tainted() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	corruption_system.add_corruption("hero1", 25)
	var state = fate_transformation_manager.get_heir_transformation_state("hero1")
	assert_eq(state["state"], "tainted")


func test_state_tainted_to_cursed() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	corruption_system.add_corruption("hero1", 20)
	curse_system.apply_curse("hero1", CurseSystem.CurseType.WEAKNESS)
	curse_system.apply_curse("hero1", CurseSystem.CurseType.MADNESS)
	var state = fate_transformation_manager.get_heir_transformation_state("hero1")
	assert_eq(state["state"], "cursed")


func test_state_cursed_to_corrupted() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	corruption_system.add_corruption("hero1", 50)
	curse_system.apply_curse("hero1", CurseSystem.CurseType.WEAKNESS)
	var state = fate_transformation_manager.get_heir_transformation_state("hero1")
	assert_eq(state["state"], "corrupted")


func test_state_blessed() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.VIGOR)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.CLARITY)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.FORTUNE)
	var state = fate_transformation_manager.get_heir_transformation_state("hero1")
	assert_eq(state["state"], "blessed")


# ============================================================
# Complex Scenario Tests
# ============================================================

func test_full_corruption_and_redemption_arc() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	class_evolution_system.initialize_heir_class("hero1", "Warrior")

	# Encounter corruption
	fate_transformation_manager.apply_encounter_corruption("hero1", 3)
	var corruption = corruption_system.get_corruption_level("hero1")
	assert_true(corruption > 0)

	# Redemption
	fate_transformation_manager.trigger_redemption("hero1")
	corruption = corruption_system.get_corruption_level("hero1")
	assert_true(corruption < 15)


func test_curse_mutation_and_blessing_relief() -> void:
	curse_system.apply_curse("hero1", CurseSystem.CurseType.MADNESS)
	curse_system.mutate_curse("hero1", CurseSystem.CurseType.MADNESS, "amplify")
	var initial_penalty = curse_system.get_curse_stat_penalty("hero1")

	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.CLARITY)
	blessing_system.grant_blessing("hero1", BlessingSystem.BlessingType.CLARITY)
	var bonus = blessing_system.get_blessing_stat_bonus("hero1")

	# Blessings should offset some curse effects
	assert_true(bonus["intelligence"] > 0)


func test_generational_curse_chain() -> void:
	fate_transformation_manager.initialize_heir_transformation("hero1")
	fate_transformation_manager.initialize_heir_transformation("hero2")
	fate_transformation_manager.initialize_heir_transformation("hero3")

	curse_system.apply_curse("hero1", CurseSystem.CurseType.VOID_MARK)
	curse_system.chain_curse_to_heir("hero2", "hero1", CurseSystem.CurseType.VOID_MARK)
	curse_system.chain_curse_to_heir("hero3", "hero2", CurseSystem.CurseType.VOID_MARK)

	assert_true(curse_system.has_curse("hero1", CurseSystem.CurseType.VOID_MARK))
	assert_true(curse_system.has_curse("hero2", CurseSystem.CurseType.VOID_MARK))
	assert_true(curse_system.has_curse("hero3", CurseSystem.CurseType.VOID_MARK))


func test_warrior_to_berserker_full_path() -> void:
	class_evolution_system.initialize_heir_class("warrior1", "Warrior")

	var available = class_evolution_system.get_available_evolutions("warrior1")
	assert_true(available.has("Berserker"))

	var requirements = class_evolution_system.get_evolution_requirements("Berserker")
	assert_eq(requirements["fate_requirement"], 100)

	var result = class_evolution_system.evolve_class("warrior1", "Berserker", 100)
	assert_true(result["success"])
	assert_eq(result["special_trait"], "battle_fury")


func test_all_class_evolution_paths() -> void:
	var classes = ["Warrior", "Rogue", "Mage", "Priest"]

	for base_class in classes:
		class_evolution_system.initialize_heir_class("hero_%s" % base_class, base_class)
		var evolutions = class_evolution_system.get_available_evolutions("hero_%s" % base_class)
		assert_true(evolutions.size() >= 3, "Each base class should have 3+ evolutions")
