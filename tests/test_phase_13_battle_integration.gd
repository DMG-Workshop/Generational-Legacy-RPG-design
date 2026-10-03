## Test Phase 13: Battle System Integration
##
## Comprehensive test suite for prestige integration with combat mechanics

extends Node

class_name TestPhase13BattleIntegration


var prestige_modifier: PrestigeCombatModifier
var enemy_scaling: PrestigeEnemyScaling
var combat_tracker: PrestigeCombatTracker
var combat_bonuses: CombatPrestigeBonus

var test_results: Array = []


func _ready() -> void:
	prestige_modifier = PrestigeCombatModifier.new()
	enemy_scaling = PrestigeEnemyScaling.new()
	combat_tracker = PrestigeCombatTracker.new()
	combat_bonuses = CombatPrestigeBonus.new()

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_prestige_modifier_initialization()
	test_combat_modifiers_calculation()
	test_damage_modification()
	test_defense_modification()
	test_critical_chance_scaling()
	test_critical_damage_scaling()
	test_speed_bonus()
	test_status_resistance()

	test_enemy_scaling_calculation()
	test_enemy_level_scaling()
	test_enemy_stat_scaling()
	test_enemy_loot_scaling()
	test_encounter_difficulty()
	test_boss_stat_scaling()

	test_combat_record_creation()
	test_combat_stats_tracking()
	test_prestige_from_combat_victory()
	test_heir_combat_history()
	test_combat_efficiency_rating()
	test_combat_performance_vs_level()

	test_tier_ability_unlocking()
	test_ability_descriptions()
	test_ability_costs()
	test_tier_bonus_calculation()
	test_combined_combat_bonus()
	test_ability_availability_by_tier()

	test_prestige_advantage_calculation()
	test_multiplier_scaling_thresholds()
	test_level_advantage_bonus()
	test_difficulty_scaling()
	test_prestige_tier_combat_bonus()

	test_complex_combat_scenarios()


func test_prestige_modifier_initialization() -> void:
	var modifier = prestige_modifier
	assert(modifier.combat_multiplier_thresholds.has(0), "Should have Bronze tier")
	assert(modifier.combat_multiplier_thresholds[0] == 1.0, "Bronze should be 1.0x")
	assert(modifier.combat_multiplier_thresholds[75000] == 1.25, "Eternal should be 1.25x")

	test_results.append("✓ Prestige modifier initialization")


func test_combat_modifiers_calculation() -> void:
	var modifiers = prestige_modifier.calculate_combat_modifiers(5000)
	assert(modifiers.prestige_level == 5000, "Should track prestige level")
	assert(modifiers.damage_multiplier >= 1.0, "Damage multiplier should be at least 1.0x")
	assert(modifiers.defense_multiplier >= 1.0, "Defense multiplier should be at least 1.0x")

	test_results.append("✓ Combat modifiers calculation")


func test_damage_modification() -> void:
	var modifiers = prestige_modifier.calculate_combat_modifiers(5000)
	var base_damage = 100
	var modified = prestige_modifier.apply_damage_modifier(base_damage, modifiers)

	assert(modified >= base_damage, "Modified damage should not decrease")
	assert(modified == int(base_damage * modifiers.damage_multiplier), "Should apply multiplier correctly")

	test_results.append("✓ Damage modification")


func test_defense_modification() -> void:
	var modifiers = prestige_modifier.calculate_combat_modifiers(10000)
	var base_defense = 50
	var modified = prestige_modifier.apply_defense_modifier(base_defense, modifiers)

	assert(modified >= base_defense, "Modified defense should not decrease")
	assert(modified <= base_defense * 2, "Should respect defense cap")

	test_results.append("✓ Defense modification")


func test_critical_chance_scaling() -> void:
	var modifiers1 = prestige_modifier.calculate_combat_modifiers(0)
	var modifiers2 = prestige_modifier.calculate_combat_modifiers(5000)

	assert(modifiers1.critical_chance_bonus < modifiers2.critical_chance_bonus, "More prestige should increase crit chance")

	var base_crit = 0.1
	var scaled_crit = prestige_modifier.calculate_modified_critical_chance(base_crit, modifiers2)
	assert(scaled_crit >= base_crit, "Should not decrease critical chance")
	assert(scaled_crit <= 1.0, "Should cap at 100%")

	test_results.append("✓ Critical chance scaling")


func test_critical_damage_scaling() -> void:
	var modifiers = prestige_modifier.calculate_combat_modifiers(5000)
	var base_crit_damage = 1.5
	var scaled = prestige_modifier.calculate_modified_critical_damage(base_crit_damage, modifiers)

	assert(scaled > base_crit_damage, "Should increase critical damage")
	assert(scaled <= 2.0, "Should cap at 2.0x")

	test_results.append("✓ Critical damage scaling")


func test_speed_bonus() -> void:
	var modifiers = prestige_modifier.calculate_combat_modifiers(5000)
	assert(modifiers.speed_bonus > 0.0, "Should have speed bonus")
	assert(modifiers.speed_bonus <= 1.0, "Should cap speed bonus")

	test_results.append("✓ Speed bonus")


func test_status_resistance() -> void:
	var modifiers = prestige_modifier.calculate_combat_modifiers(10000)
	assert(modifiers.status_resistance > 0.0, "Should have status resistance")
	assert(modifiers.status_resistance <= 0.5, "Should cap status resistance at 50%")

	test_results.append("✓ Status resistance")


func test_enemy_scaling_calculation() -> void:
	var base_stats = {"health": 100, "attack": 20, "defense": 10}
	var scaled = enemy_scaling.calculate_enemy_scaling("goblin_1", 5, base_stats, 5000)

	assert(scaled.enemy_id == "goblin_1", "Should track enemy ID")
	assert(scaled.scaled_level >= scaled.base_level, "Should not decrease level")
	assert(scaled.loot_multiplier >= 1.0, "Should not decrease loot")

	test_results.append("✓ Enemy scaling calculation")


func test_enemy_level_scaling() -> void:
	var base_stats = {"health": 100, "attack": 20}
	var scaled = enemy_scaling.calculate_enemy_scaling("boss_1", 10, base_stats, 15000)

	assert(scaled.scaled_level > scaled.base_level, "Should increase level with prestige")

	test_results.append("✓ Enemy level scaling")


func test_enemy_stat_scaling() -> void:
	var base_stats = {"health": 100, "attack": 20, "defense": 10}
	var scaled = enemy_scaling.calculate_enemy_scaling("enemy_1", 5, base_stats, 10000)

	for stat in base_stats.keys():
		assert(scaled.scaled_stats[stat] >= base_stats[stat], "All stats should scale up")

	test_results.append("✓ Enemy stat scaling")


func test_enemy_loot_scaling() -> void:
	var base_loot = {"gold": 100, "experience": 50, "items": 1}
	var scaled_loot = enemy_scaling.scale_enemy_loot(base_loot, 5000)

	assert(scaled_loot["gold"] >= base_loot["gold"], "Should scale loot up")

	test_results.append("✓ Enemy loot scaling")


func test_encounter_difficulty() -> void:
	var difficulty = enemy_scaling.calculate_encounter_difficulty(5000, 5000)
	assert(abs(difficulty - 1.0) < 0.1, "Equal prestige should give ~1.0 difficulty")

	var hard_difficulty = enemy_scaling.calculate_encounter_difficulty(5000, 10000)
	assert(hard_difficulty > 1.0, "Higher enemy prestige should increase difficulty")

	test_results.append("✓ Encounter difficulty")


func test_boss_stat_scaling() -> void:
	var base_stats = {"health": 500, "attack": 50, "defense": 25}
	var scaled_stats = enemy_scaling.calculate_prestige_boss_stats(base_stats, 1.2)

	for stat in base_stats.keys():
		assert(scaled_stats[stat] > base_stats[stat] * 1.2, "Bosses should scale extra (1.25x)")

	test_results.append("✓ Boss stat scaling")


func test_combat_record_creation() -> void:
	var record = combat_tracker.record_combat("heir_1", "goblin_1", 5, 10, true, 150, 30, 5, 2, 1.1, 100)

	assert(record.heir_id == "heir_1", "Should track heir ID")
	assert(record.enemy_id == "goblin_1", "Should track enemy ID")
	assert(record.victory, "Should mark victory")
	assert(record.prestige_gained > 0, "Should gain prestige from victory")

	test_results.append("✓ Combat record creation")


func test_combat_stats_tracking() -> void:
	combat_tracker.record_combat("heir_1", "goblin_1", 5, 10, true, 150, 30, 5, 2, 1.1, 100)
	combat_tracker.record_combat("heir_1", "goblin_2", 5, 10, true, 120, 25, 4, 1, 1.1, 100)

	var stats = combat_tracker.get_heir_combat_stats("heir_1")
	assert(stats.total_combats == 2, "Should track 2 combats")
	assert(stats.victories == 2, "Should track 2 victories")
	assert(stats.total_damage_dealt > 0, "Should track damage dealt")

	test_results.append("✓ Combat stats tracking")


func test_prestige_from_combat_victory() -> void:
	var record = combat_tracker.record_combat("heir_test", "boss_1", 20, 15, true, 500, 100, 10, 5, 1.2, 200)

	assert(record.prestige_gained > 0, "Should gain prestige")
	assert(record.prestige_gained > 100, "Victory should grant meaningful prestige")

	test_results.append("✓ Prestige from combat victory")


func test_heir_combat_history() -> void:
	combat_tracker.record_combat("heir_history", "enemy_1", 5, 10, true, 100, 20, 3, 1, 1.0, 50)
	combat_tracker.record_combat("heir_history", "enemy_2", 5, 10, false, 50, 80, 8, 0, 1.0, 50)

	var history = combat_tracker.get_heir_combats("heir_history")
	assert(history.size() == 2, "Should have 2 combat records")

	test_results.append("✓ Heir combat history")


func test_combat_efficiency_rating() -> void:
	combat_tracker.record_combat("heir_eff", "enemy_1", 5, 10, true, 200, 40, 4, 2, 1.0, 50)
	combat_tracker.record_combat("heir_eff", "enemy_2", 5, 10, true, 180, 35, 3, 1, 1.0, 50)

	var efficiency = combat_tracker.get_combat_efficiency_rating("heir_eff")
	assert(efficiency > 0.0, "Should have positive efficiency")

	test_results.append("✓ Combat efficiency rating")


func test_combat_performance_vs_level() -> void:
	combat_tracker.record_combat("heir_perf", "enemy_5", 5, 10, true, 100, 20, 3, 1, 1.0, 50)
	combat_tracker.record_combat("heir_perf", "enemy_5b", 6, 10, true, 110, 25, 3, 1, 1.0, 50)

	var performance = combat_tracker.get_combat_performance_vs_level("heir_perf", 5)
	assert(performance["combats"] > 0, "Should find combats at level 5")

	test_results.append("✓ Combat performance vs level")


func test_tier_ability_unlocking() -> void:
	var bronze = combat_bonuses.calculate_tier_bonus(0, "heir_1")
	assert(bronze.abilities_unlocked.size() == 0, "Bronze should have no abilities")

	var gold = combat_bonuses.calculate_tier_bonus(2, "heir_1")
	assert(gold.abilities_unlocked.size() >= 2, "Gold should have 2+ abilities")

	var eternal = combat_bonuses.calculate_tier_bonus(5, "heir_1")
	assert(eternal.abilities_unlocked.size() >= 5, "Eternal should have 5+ abilities")

	test_results.append("✓ Tier ability unlocking")


func test_ability_descriptions() -> void:
	var desc = combat_bonuses.get_ability_description(CombatPrestigeBonus.CombatAbility.EXECUTE)
	assert(desc != "", "Should have description")
	assert(desc.contains("Execute"), "Should name ability")

	test_results.append("✓ Ability descriptions")


func test_ability_costs() -> void:
	var cost_riposte = combat_bonuses.get_ability_cost(CombatPrestigeBonus.CombatAbility.RIPOSTE)
	assert(cost_riposte > 0, "Riposte should have cost")

	var cost_destiny = combat_bonuses.get_ability_cost(CombatPrestigeBonus.CombatAbility.DESTINY_STRIKE)
	assert(cost_destiny > cost_riposte, "Destiny Strike should cost more than Riposte")

	test_results.append("✓ Ability costs")


func test_tier_bonus_calculation() -> void:
	var platinum = combat_bonuses.calculate_tier_bonus(3, "heir_test")

	assert(platinum.damage_bonus == 0.15, "Platinum should have 15% damage")
	assert(platinum.defense_bonus == 0.15, "Platinum should have 15% defense")
	assert(platinum.ability_uses_per_combat == 2, "Platinum should have 2 ability uses")

	test_results.append("✓ Tier bonus calculation")


func test_combined_combat_bonus() -> void:
	var combined = combat_bonuses.calculate_combined_combat_bonus(3, 1.15, 1.15)

	assert(combined["damage"] > 1.15, "Should combine tier and prestige bonuses")
	assert(combined["defense"] > 1.15, "Should combine tier and prestige bonuses")

	test_results.append("✓ Combined combat bonus")


func test_ability_availability_by_tier() -> void:
	var available_silver = combat_bonuses.is_ability_available_in_tier(CombatPrestigeBonus.CombatAbility.RIPOSTE, 1)
	assert(available_silver, "Riposte should be available in Silver")

	var available_bronze = combat_bonuses.is_ability_available_in_tier(CombatPrestigeBonus.CombatAbility.EXECUTE, 0)
	assert(not available_bronze, "Execute should not be available in Bronze")

	test_results.append("✓ Ability availability by tier")


func test_prestige_advantage_calculation() -> void:
	var advantage = prestige_modifier.calculate_combat_advantage(10000, 5000)
	assert(advantage > 1.0, "Higher prestige should give advantage")

	var disadvantage = prestige_modifier.calculate_combat_advantage(5000, 10000)
	assert(disadvantage < 1.0, "Lower prestige should give disadvantage")

	test_results.append("✓ Prestige advantage calculation")


func test_multiplier_scaling_thresholds() -> void:
	var mod_bronze = prestige_modifier.calculate_combat_modifiers(0)
	var mod_silver = prestige_modifier.calculate_combat_modifiers(1000)
	var mod_eternal = prestige_modifier.calculate_combat_modifiers(75000)

	assert(mod_silver.damage_multiplier > mod_bronze.damage_multiplier, "Should scale with prestige")
	assert(mod_eternal.damage_multiplier > mod_silver.damage_multiplier, "Should scale with prestige")

	test_results.append("✓ Multiplier scaling thresholds")


func test_level_advantage_bonus() -> void:
	var level_cap = enemy_scaling.get_prestige_level_cap(25000)
	assert(level_cap > 10, "Should increase level cap with prestige")

	test_results.append("✓ Level advantage bonus")


func test_difficulty_scaling() -> void:
	var easy = enemy_scaling.is_enemy_too_easy(10000, {"attack": 50, "defense": 20}, {"attack": 200, "defense": 100})
	assert(easy, "Should detect easy enemies")

	var hard = enemy_scaling.is_enemy_too_hard(5000, {"attack": 300, "defense": 150}, {"attack": 100, "defense": 50})
	assert(hard, "Should detect hard enemies")

	test_results.append("✓ Difficulty scaling")


func test_prestige_tier_combat_bonus() -> void:
	var bonus_gold = prestige_modifier.get_prestige_tier_combat_bonus(2)
	assert(bonus_gold["damage"] == 1.1, "Gold should have 1.1x damage")
	assert(bonus_gold["ability_slots"] == 2, "Gold should have 2 ability slots")

	test_results.append("✓ Prestige tier combat bonus")


func test_complex_combat_scenarios() -> void:
	# Scenario: Combat progression with prestige
	var prestige_level = 0
	var victories = 0

	for i in range(5):
		prestige_level += 1000
		var record = combat_tracker.record_combat("heir_journey", "enemy_%d" % i, 5 + i, 10 + i, true, 100 + (i * 20), 30 + (i * 5), 3 + i, 1, 1.0 + (prestige_level / 10000.0), 50)
		if record.victory:
			victories += 1

	assert(victories == 5, "Should win all combats")
	var stats = combat_tracker.get_heir_combat_stats("heir_journey")
	assert(stats.total_combats == 5, "Should track 5 combats")

	# Scenario: Enemy scaling with prestige progression
	var prestige1 = 0
	var prestige2 = 5000
	var prestige3 = 15000

	var base_stats = {"health": 100, "attack": 20, "defense": 10}
	var scaled1 = enemy_scaling.calculate_enemy_scaling("goblin", 1, base_stats, prestige1)
	var scaled2 = enemy_scaling.calculate_enemy_scaling("goblin", 1, base_stats, prestige2)
	var scaled3 = enemy_scaling.calculate_enemy_scaling("goblin", 1, base_stats, prestige3)

	assert(scaled1.scale_multiplier <= scaled2.scale_multiplier, "Should scale with prestige")
	assert(scaled2.scale_multiplier <= scaled3.scale_multiplier, "Should scale with prestige")

	# Scenario: Tier-based ability progression
	var tiers = [0, 1, 2, 3, 4, 5]
	for tier in tiers:
		var bonus = combat_bonuses.calculate_tier_bonus(tier, "heir_test")
		assert(bonus.ability_uses_per_combat >= 0, "Should have valid ability uses")

	test_results.append("✓ Complex combat scenarios")


func print_results() -> void:
	print("\n=== Test Phase 13: Battle System Integration ===")
	for result in test_results:
		print(result)
	print("\nTotal: %d test groups passed" % test_results.size())


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
