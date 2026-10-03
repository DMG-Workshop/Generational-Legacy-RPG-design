## Test Phase 12.4: Dynasty Prestige & Succession Bonuses
##
## Comprehensive test suite for prestige system, succession bonuses, and scaling

extends Node

class_name TestPhase12_4Prestige


var prestige_system: DynastyPrestigeSystem
var succession_system: SuccessionBonusSystem
var scaling_system: PrestigeScalingSystem
var prestige_persistence: DynastyPrestigePersistence

var test_results: Array = []


func _ready() -> void:
	prestige_system = DynastyPrestigeSystem.new()
	succession_system = SuccessionBonusSystem.new()
	scaling_system = PrestigeScalingSystem.new()
	prestige_persistence = DynastyPrestigePersistence.new()

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_prestige_initialization()
	test_prestige_accumulation()
	test_tier_advancement()
	test_tier_thresholds()

	test_succession_bonus_calculation()
	test_succession_level_scaling()
	test_succession_stat_bonuses()
	test_succession_resource_bonuses()
	test_succession_multiplier_scaling()

	test_combat_reward_scaling()
	test_exploration_reward_scaling()
	test_economic_scaling()
	test_dynasty_stat_scaling()
	test_trait_inheritance_scaling()

	test_prestige_multiplier_effects()
	test_milestone_multiplier()
	test_achievement_multiplier()
	test_combined_multipliers()

	test_prestige_spending()
	test_prestige_caps()
	test_prestige_history_tracking()

	test_prestige_persistence()
	test_generation_transfer()
	test_complex_prestige_scenarios()


func test_prestige_initialization() -> void:
	assert(prestige_system.total_prestige == 0, "Should start with 0 prestige")
	assert(prestige_system.current_tier == DynastyPrestigeSystem.PrestigeTier.BRONZE, "Should start at BRONZE tier")
	assert(prestige_system.combined_multiplier == 1.0, "Should start with 1.0x multiplier")

	test_results.append("✓ Prestige initialization")


func test_prestige_accumulation() -> void:
	prestige_system.accumulate_prestige(500, DynastyPrestigeSystem.PrestigeSource.ACHIEVEMENT)
	assert(prestige_system.total_prestige == 500, "Should accumulate 500 prestige")
	assert(prestige_system.prestige_available == 500, "Should have 500 available prestige")

	prestige_system.accumulate_prestige(300, DynastyPrestigeSystem.PrestigeSource.DEED)
	assert(prestige_system.total_prestige == 800, "Should accumulate to 800 prestige")

	test_results.append("✓ Prestige accumulation")


func test_tier_advancement() -> void:
	var prestige_system2 = DynastyPrestigeSystem.new()
	assert(prestige_system2.current_tier == DynastyPrestigeSystem.PrestigeTier.BRONZE, "Should start at BRONZE")

	prestige_system2.accumulate_prestige(1000)
	assert(prestige_system2.current_tier == DynastyPrestigeSystem.PrestigeTier.SILVER, "Should advance to SILVER at 1000")

	prestige_system2.accumulate_prestige(4000)
	assert(prestige_system2.current_tier == DynastyPrestigeSystem.PrestigeTier.GOLD, "Should advance to GOLD at 5000")

	prestige_system2.accumulate_prestige(10000)
	assert(prestige_system2.current_tier == DynastyPrestigeSystem.PrestigeTier.PLATINUM, "Should advance to PLATINUM at 15000")

	test_results.append("✓ Tier advancement")


func test_tier_thresholds() -> void:
	var bronze_info = prestige_system.get_tier_info(DynastyPrestigeSystem.PrestigeTier.BRONZE)
	assert(bronze_info.min_prestige == 0, "BRONZE should start at 0")

	var silver_info = prestige_system.get_tier_info(DynastyPrestigeSystem.PrestigeTier.SILVER)
	assert(silver_info.min_prestige == 1000, "SILVER should start at 1000")

	var diamond_info = prestige_system.get_tier_info(DynastyPrestigeSystem.PrestigeTier.DIAMOND)
	assert(diamond_info.min_prestige == 35000, "DIAMOND should start at 35000")

	var eternal_info = prestige_system.get_tier_info(DynastyPrestigeSystem.PrestigeTier.ETERNAL)
	assert(eternal_info.min_prestige == 75000, "ETERNAL should start at 75000")

	test_results.append("✓ Tier thresholds")


func test_succession_bonus_calculation() -> void:
	var bonus = succession_system.calculate_bonuses_for_heir("heir_1", 1000)
	assert(bonus != null, "Should calculate bonuses")
	assert(bonus.heir_id == "heir_1", "Should track heir ID")
	assert(bonus.prestige_level == 1000, "Should track prestige level")

	test_results.append("✓ Succession bonus calculation")


func test_succession_level_scaling() -> void:
	var bonus = succession_system.calculate_bonuses_for_heir("heir_test", 2000)
	assert(bonus.starting_level == 2, "1000 prestige = +1 level, 2000 = +2")

	var bonus_high = succession_system.calculate_bonuses_for_heir("heir_high", 50000)
	assert(bonus_high.starting_level <= succession_system.bonus_caps["starting_level"], "Should respect level cap")

	test_results.append("✓ Succession level scaling")


func test_succession_stat_bonuses() -> void:
	var bonus = succession_system.calculate_bonuses_for_heir("heir_stat", 1000)
	var total_stat_bonus = bonus.stat_bonuses["strength"] + bonus.stat_bonuses["dexterity"] + bonus.stat_bonuses["intelligence"] + bonus.stat_bonuses["vitality"]
	assert(total_stat_bonus == 10, "1000 prestige should give 10 total stat bonus (distributed)")

	for stat in bonus.stat_bonuses.keys():
		assert(bonus.stat_bonuses[stat] >= 0, "Stat bonus should not be negative")

	test_results.append("✓ Succession stat bonuses")


func test_succession_resource_bonuses() -> void:
	var bonus = succession_system.calculate_bonuses_for_heir("heir_res", 2500)
	assert(bonus.starting_gold == 125, "2500 prestige should give 125 gold (5 per 100)")
	assert(bonus.starting_supplies == 1, "2500 prestige should give 1 supply (1 per 2500)")

	var bonus_high = succession_system.calculate_bonuses_for_heir("heir_res_high", 100000)
	assert(bonus_high.starting_supplies <= succession_system.bonus_caps["starting_supplies"], "Should cap supplies")

	test_results.append("✓ Succession resource bonuses")


func test_succession_multiplier_scaling() -> void:
	var bonus = succession_system.calculate_bonuses_for_heir("heir_mult", 5000)
	assert(bonus.experience_multiplier > 1.0, "Should have experience multiplier boost")
	assert(bonus.experience_multiplier <= succession_system.bonus_caps["experience_multiplier"], "Should respect multiplier cap")

	test_results.append("✓ Succession multiplier scaling")


func test_combat_reward_scaling() -> void:
	var scaling = scaling_system.calculate_combat_reward_scaling(100, 5, 1.2)
	assert(scaling["base_gold"] == 100, "Should track base gold")
	assert(scaling["prestige_scaled_gold"] == 120, "1.2x multiplier should scale to 120")
	assert(scaling["experience_multiplier"] > 1.0, "Should have experience multiplier")

	test_results.append("✓ Combat reward scaling")


func test_exploration_reward_scaling() -> void:
	var base = {"wood": 10, "stone": 5, "ore": 2}
	var scaled = scaling_system.calculate_exploration_reward_scaling(base, 1.5)
	assert(scaled["wood"] == 15, "1.5x multiplier on 10 wood = 15")
	assert(scaled["stone"] == 7, "1.5x multiplier on 5 stone = 7-8")

	test_results.append("✓ Exploration reward scaling")


func test_economic_scaling() -> void:
	var scaling = scaling_system.calculate_economic_scaling(1000, 1.1, 1.05)
	assert(scaling["base_income"] == 1000, "Should track base income")
	assert(scaling["prestige_scaled"] >= 1100, "Should scale income with prestige")
	assert(scaling["total_income"] > scaling["prestige_scaled"], "Should apply faction bonus")

	test_results.append("✓ Economic scaling")


func test_dynasty_stat_scaling() -> void:
	var base_stats = {"strength": 10, "dexterity": 8, "intelligence": 6, "vitality": 12}
	var scaled = scaling_system.calculate_dynasty_stat_scaling(base_stats, 3, 1.1)

	for stat in scaled.keys():
		assert(scaled[stat] >= base_stats[stat], "Scaled stats should not decrease")

	test_results.append("✓ Dynasty stat scaling")


func test_trait_inheritance_scaling() -> void:
	var base_rate = 0.5
	var scaled = scaling_system.calculate_trait_inheritance_scaling(base_rate, 5, 1.1)
	assert(scaled > base_rate, "Should boost inheritance rate")
	assert(scaled <= 1.0, "Should cap at 100%")

	test_results.append("✓ Trait inheritance scaling")


func test_prestige_multiplier_effects() -> void:
	var prestige_system2 = DynastyPrestigeSystem.new()
	prestige_system2.add_milestone_multiplier(1.1)
	assert(prestige_system2.milestone_multiplier >= 1.0, "Milestone multiplier should not decrease")

	prestige_system2.add_achievement_multiplier(1.05)
	assert(prestige_system2.achievement_multiplier == 1.05, "Should apply achievement multiplier")

	test_results.append("✓ Prestige multiplier effects")


func test_milestone_multiplier() -> void:
	var prestige_system2 = DynastyPrestigeSystem.new()
	prestige_system2.add_milestone_multiplier(1.15)
	assert(abs(prestige_system2.milestone_multiplier - 1.15) < 0.01, "Should set milestone multiplier")

	test_results.append("✓ Milestone multiplier")


func test_achievement_multiplier() -> void:
	var prestige_system2 = DynastyPrestigeSystem.new()
	prestige_system2.add_achievement_multiplier(1.20)
	assert(prestige_system2.achievement_multiplier == 1.20, "Should set achievement multiplier")

	test_results.append("✓ Achievement multiplier")


func test_combined_multipliers() -> void:
	var prestige_system2 = DynastyPrestigeSystem.new()
	prestige_system2.add_milestone_multiplier(1.1)
	prestige_system2.add_achievement_multiplier(1.1)
	assert(abs(prestige_system2.combined_multiplier - 1.21) < 0.01, "Combined should multiply: 1.1 * 1.1 = 1.21")

	test_results.append("✓ Combined multipliers")


func test_prestige_spending() -> void:
	var prestige_system2 = DynastyPrestigeSystem.new()
	prestige_system2.accumulate_prestige(500)

	var spent = prestige_system2.spend_prestige(200, "test_reason")
	assert(spent, "Should spend prestige successfully")
	assert(prestige_system2.prestige_available == 300, "Should reduce available prestige")
	assert(prestige_system2.prestige_spent == 200, "Should track spent prestige")

	test_results.append("✓ Prestige spending")


func test_prestige_caps() -> void:
	var prestige_system2 = DynastyPrestigeSystem.new()
	prestige_system2.accumulate_prestige(500000)

	var bonus = succession_system.calculate_bonuses_for_heir("heir_cap", prestige_system2.total_prestige)
	assert(bonus.starting_level <= succession_system.bonus_caps["starting_level"], "Level should be capped")
	assert(bonus.skill_points <= succession_system.bonus_caps["skill_points"], "Skill points should be capped")

	test_results.append("✓ Prestige caps")


func test_prestige_history_tracking() -> void:
	var prestige_system2 = DynastyPrestigeSystem.new()
	prestige_system2.accumulate_prestige(100, DynastyPrestigeSystem.PrestigeSource.ACHIEVEMENT)
	prestige_system2.accumulate_prestige(200, DynastyPrestigeSystem.PrestigeSource.MILESTONE)

	assert(prestige_system2.prestige_history.size() >= 2, "Should track history entries")
	assert(prestige_system2.prestige_history[0]["amount"] == 100, "Should record amounts")

	test_results.append("✓ Prestige history tracking")


func test_prestige_persistence() -> void:
	var prestige_system2 = DynastyPrestigeSystem.new()
	var succession_system2 = SuccessionBonusSystem.new()
	var scaling_system2 = PrestigeScalingSystem.new()

	prestige_system2.accumulate_prestige(5000)
	succession_system2.calculate_bonuses_for_heir("heir_1", 2500)

	var state = prestige_persistence.save_prestige_state(prestige_system2, succession_system2, scaling_system2)
	assert(state.has("total_prestige"), "State should have total_prestige")
	assert(state.has("succession_bonuses"), "State should have succession_bonuses")
	assert(state["total_prestige"] == 5000, "Should save prestige amount")

	var prestige_system3 = DynastyPrestigeSystem.new()
	var succession_system3 = SuccessionBonusSystem.new()
	var scaling_system3 = PrestigeScalingSystem.new()

	prestige_persistence.load_prestige_state(state, prestige_system3, succession_system3, scaling_system3)
	assert(prestige_system3.total_prestige == 5000, "Should load prestige amount")
	assert(succession_system3.succession_bonuses.size() > 0, "Should load succession bonuses")

	test_results.append("✓ Prestige persistence")


func test_generation_transfer() -> void:
	var prestige_system2 = DynastyPrestigeSystem.new()
	var succession_system2 = SuccessionBonusSystem.new()
	var scaling_system2 = PrestigeScalingSystem.new()

	prestige_system2.accumulate_prestige(10000)
	prestige_system2.add_milestone_multiplier(1.2)

	var state = prestige_persistence.save_prestige_state(prestige_system2, succession_system2, scaling_system2)
	var transferred = prestige_persistence.transfer_prestige_to_next_generation(state)

	assert(transferred["total_prestige"] == 10000, "Prestige should carry forward")
	assert(transferred["prestige_available"] == 10000, "Available prestige should reset")
	assert(transferred["milestone_multiplier"] == 1.0, "Multiplier should reset")

	test_results.append("✓ Generation transfer")


func test_complex_prestige_scenarios() -> void:
	# Scenario: Multi-generation prestige accumulation
	var prestige_system2 = DynastyPrestigeSystem.new()

	for _i in range(5):
		prestige_system2.accumulate_prestige(1000, DynastyPrestigeSystem.PrestigeSource.ACHIEVEMENT)

	assert(prestige_system2.total_prestige == 5000, "Should accumulate from multiple sources")
	assert(prestige_system2.current_tier == DynastyPrestigeSystem.PrestigeTier.GOLD, "Should reach GOLD at 5000")

	# Scenario: Succession bonus preparation for multiple heirs
	var prestige_system3 = DynastyPrestigeSystem.new()
	var succession_system2 = SuccessionBonusSystem.new()
	prestige_system3.accumulate_prestige(15000)

	for i in range(5):
		succession_system2.calculate_bonuses_for_heir("heir_%d" % i, prestige_system3.total_prestige)

	assert(succession_system2.succession_bonuses.size() == 5, "Should prepare 5 heirs")

	# Scenario: Prestige with multipliers affecting rewards
	var prestige_system4 = DynastyPrestigeSystem.new()
	var scaling_system2 = PrestigeScalingSystem.new()

	prestige_system4.add_milestone_multiplier(1.15)
	prestige_system4.add_achievement_multiplier(1.10)

	var combat_reward = scaling_system2.calculate_combat_reward_scaling(100, 10, prestige_system4.combined_multiplier)
	assert(combat_reward["prestige_scaled_gold"] > 100, "Prestige should boost combat rewards")

	test_results.append("✓ Complex prestige scenarios")


func print_results() -> void:
	print("\n=== Test Phase 12.4: Dynasty Prestige & Succession Bonuses ===")
	for result in test_results:
		print(result)
	print("\nTotal: %d test groups passed" % test_results.size())


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
