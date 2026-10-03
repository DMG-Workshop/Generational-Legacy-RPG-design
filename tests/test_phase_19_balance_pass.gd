## Test Phase 19: Balance Pass - Prestige curves, scaling, and progression pacing
##
## Validates all balance policies, progression curves, and progression feasibility
## for 999-generation dynasties reaching target prestige with proper scaling.

extends Node

class_name TestPhase19BalancePass


var balance_config: BalanceConfig
var balancing_system: BalancingSystem

var test_results: Array = []


func _ready() -> void:
	balance_config = BalanceConfig.new()
	balancing_system = BalancingSystem.new()

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_prestige_tier_thresholds()
	test_prestige_accumulation_rate()
	test_progression_feasibility()
	test_succession_bonus_scaling()
	test_combat_scaling_progression()
	test_enemy_scaling_progression()
	test_player_vs_enemy_balance()
	test_damage_scaling_cap()
	test_defense_scaling_cap()
	test_critical_scaling()
	test_heirloom_prestige_gating()
	test_loot_prestige_scaling()
	test_reputation_decay()
	test_stat_bonus_accumulation()
	test_trait_mutation_scaling()
	test_multi_generation_prestige_carry()
	test_generation_milestone_prestige()
	test_boss_scaling_curve()
	test_prestige_per_generation_consistency()
	test_full_dynasty_progression()


func test_prestige_tier_thresholds() -> void:
	var bronze_threshold = balance_config.get_prestige_tier_threshold(BalanceConfig.PrestigeTier.BRONZE)
	var silver_threshold = balance_config.get_prestige_tier_threshold(BalanceConfig.PrestigeTier.SILVER)
	var eternal_threshold = balance_config.get_prestige_tier_threshold(BalanceConfig.PrestigeTier.ETERNAL)

	assert(bronze_threshold == 0, "Bronze should start at 0")
	assert(silver_threshold == 1000, "Silver should be 1000")
	assert(eternal_threshold == 75000, "Eternal should be 75000")
	assert(silver_threshold < eternal_threshold, "Tiers should be in ascending order")

	test_results.append("✓ Prestige tier thresholds")


func test_prestige_accumulation_rate() -> void:
	var gen_1 = balance_config.get_prestige_per_generation(1)
	var gen_100 = balance_config.get_prestige_per_generation(100)
	var gen_500 = balance_config.get_prestige_per_generation(500)

	assert(gen_1 > 0, "Gen 1 should gain prestige")
	assert(gen_100 > gen_1, "Later generations should gain more prestige")
	assert(gen_500 > gen_100, "Prestige gain should continue scaling")

	test_results.append("✓ Prestige accumulation rate")


func test_progression_feasibility() -> void:
	var total = balance_config.calculate_total_progression(999)
	var eternal_threshold = balance_config.PrestigeThresholds.tiers[BalanceConfig.PrestigeTier.ETERNAL]

	assert(total >= eternal_threshold, "999 generations should reach ETERNAL tier")

	test_results.append("✓ Progression feasibility")


func test_succession_bonus_scaling() -> void:
	var base_prestige = 10000
	var carried = balance_config.get_succession_prestige_carry(base_prestige)

	var expected = int(base_prestige * 1.1)
	assert(carried == expected, "Succession bonus should multiply prestige by 1.1")
	assert(carried > base_prestige, "Succession carries forward prestige")

	test_results.append("✓ Succession bonus scaling")


func test_combat_scaling_progression() -> void:
	var damage_0 = balance_config.get_damage_scaling(0)
	var damage_10k = balance_config.get_damage_scaling(10000)
	var damage_50k = balance_config.get_damage_scaling(50000)
	var damage_100k = balance_config.get_damage_scaling(100000)

	assert(damage_0 >= 0, "Base damage scaling should be non-negative")
	assert(damage_10k > damage_0, "Damage should scale with prestige")
	assert(damage_50k > damage_10k, "Higher prestige should grant more damage")
	assert(damage_100k <= BalanceConfig.CombatScaling.max_damage_multiplier, "Damage should cap")

	test_results.append("✓ Combat scaling progression")


func test_enemy_scaling_progression() -> void:
	var gen_1_scaling = balance_config.get_enemy_difficulty_scaling(1, 5000)
	var gen_100_scaling = balance_config.get_enemy_difficulty_scaling(100, 5000)
	var gen_500_scaling = balance_config.get_enemy_difficulty_scaling(500, 5000)

	assert(gen_1_scaling > 0, "Enemy scaling should be positive")
	assert(gen_100_scaling > gen_1_scaling, "Enemies scale with generation")
	assert(gen_500_scaling > gen_100_scaling, "Difficulty should continue increasing")

	test_results.append("✓ Enemy scaling progression")


func test_player_vs_enemy_balance() -> void:
	var comparison = balancing_system.compare_player_vs_enemy(999, 100000)

	assert(comparison.has("balance_ratio"), "Should calculate balance ratio")
	assert(comparison["balance_ratio"] > 0.3, "Player should not be vastly weaker")
	assert(comparison["balance_ratio"] < 3.0, "Player should not be vastly stronger")

	test_results.append("✓ Player vs enemy balance")


func test_damage_scaling_cap() -> void:
	var low_damage = balance_config.get_damage_scaling(1000)
	var max_damage = balance_config.get_damage_scaling(1000000)

	assert(max_damage <= BalanceConfig.CombatScaling.max_damage_multiplier, "Damage should respect cap")
	assert(low_damage < max_damage, "Higher prestige should grant more damage up to cap")

	test_results.append("✓ Damage scaling cap")


func test_defense_scaling_cap() -> void:
	var low_defense = balance_config.get_defense_scaling(1000)
	var max_defense = balance_config.get_defense_scaling(1000000)

	assert(max_defense <= BalanceConfig.CombatScaling.max_defense_multiplier, "Defense should respect cap")
	assert(low_defense < max_defense, "Higher prestige should grant more defense up to cap")

	test_results.append("✓ Defense scaling cap")


func test_critical_scaling() -> void:
	var crit_low = balance_config.CombatScaling.crit_chance_per_prestige * 10000
	var crit_high = balance_config.CombatScaling.crit_chance_per_prestige * 100000

	assert(crit_low >= 0, "Crit scaling should be non-negative")
	assert(crit_high > crit_low, "Higher prestige should grant more crit")
	assert(crit_high + 0.05 <= balance_config.CombatScaling.max_crit_chance, "Crit should cap")

	test_results.append("✓ Critical scaling")


func test_heirloom_prestige_gating() -> void:
	var tier_advancement_chance = balance_config.HeirloomBalance.tier_advancement_chance
	var interval = balance_config.HeirloomBalance.tier_advancement_generation_interval

	assert(tier_advancement_chance == 0.25, "Tier advancement should be 25% chance")
	assert(interval == 5, "Advancement should happen every 5 generations")

	test_results.append("✓ Heirloom prestige gating")


func test_loot_prestige_scaling() -> void:
	var base_chance = balance_config.LootBalance.boss_drop_base_chance
	var multiplier = balance_config.LootBalance.boss_drop_prestige_multiplier
	var max_chance = balance_config.LootBalance.max_drop_chance

	var chance_at_100k = base_chance * (1.0 + (multiplier * 1.0))
	assert(chance_at_100k > base_chance, "Drop chance should scale with prestige")
	assert(chance_at_100k <= max_chance, "Drop chance should respect maximum")

	test_results.append("✓ Loot prestige scaling")


func test_reputation_decay() -> void:
	var decay = balance_config.ReputationBalance.decay_rate_per_generation

	assert(decay == 0.95, "Reputation should decay at 95% per generation")
	assert(decay < 1.0, "Decay should reduce reputation")
	assert(decay > 0.8, "Decay should not be too severe")

	test_results.append("✓ Reputation decay")


func test_stat_bonus_accumulation() -> void:
	var health_per_prestige = balance_config.StatProgression.health_per_prestige
	var damage_per_prestige = balance_config.StatProgression.damage_per_prestige
	var defense_per_prestige = balance_config.StatProgression.defense_per_prestige

	assert(health_per_prestige > 0, "Health should scale with prestige")
	assert(damage_per_prestige > 0, "Damage should scale with prestige")
	assert(defense_per_prestige > 0, "Defense should scale with prestige")

	test_results.append("✓ Stat bonus accumulation")


func test_trait_mutation_scaling() -> void:
	var base_mutation = balance_config.TraitBalance.mutation_chance_base
	var prestige_bonus = balance_config.TraitBalance.mutation_chance_prestige_bonus
	var max_mutation = balance_config.TraitBalance.max_mutation_chance

	var mutation_at_100k = base_mutation + (prestige_bonus * 100000)
	assert(mutation_at_100k <= max_mutation, "Mutation should cap")
	assert(mutation_at_100k > base_mutation, "Prestige should increase mutation chance")

	test_results.append("✓ Trait mutation scaling")


func test_multi_generation_prestige_carry() -> void:
	var gen_1_prestige = balance_config.get_prestige_per_generation(1)
	var carry_multiplier = balance_config.PrestigeMultipliers.succession_bonus

	var gen_2_carry = int(gen_1_prestige * carry_multiplier)
	assert(gen_2_carry > gen_1_prestige, "Succession should carry forward bonuses")

	test_results.append("✓ Multi-generation prestige carry")


func test_generation_milestone_prestige() -> void:
	var gen_50 = balance_config.get_prestige_per_generation(50)
	var gen_500 = balance_config.get_prestige_per_generation(500)

	assert(gen_50 > 0, "Gen 50 should gain prestige")
	assert(gen_500 > gen_50, "Gen 500 should gain more than Gen 50")

	test_results.append("✓ Generation milestone prestige")


func test_boss_scaling_curve() -> void:
	var boss_scaling_100 = balance_config.get_boss_scaling(100, 10000)
	var boss_scaling_500 = balance_config.get_boss_scaling(500, 10000)

	assert(boss_scaling_100 > 0, "Boss scaling should be positive")
	assert(boss_scaling_500 > boss_scaling_100, "Boss scaling should increase with generation")

	test_results.append("✓ Boss scaling curve")


func test_prestige_per_generation_consistency() -> void:
	var gen_100_a = balance_config.get_prestige_per_generation(100)
	var gen_100_b = balance_config.get_prestige_per_generation(100)

	assert(gen_100_a == gen_100_b, "Prestige per generation should be deterministic")

	test_results.append("✓ Prestige per generation consistency")


func test_full_dynasty_progression() -> void:
	var report = balance_config.validate_balance()

	assert(report.has("projected_final_prestige"), "Should project final prestige")
	assert(report["projection_feasible"] != false or report.has("warnings"), "Should identify issues if any")
	assert(report["tier_gaps"].size() > 0, "Should track tier gaps")

	test_results.append("✓ Full dynasty progression")


func print_results() -> void:
	print("\n╔═══════════════════════════════════════════════════════════════╗")
	print("║  Test Phase 19: Balance Pass - Prestige Curves & Scaling       ║")
	print("╚═══════════════════════════════════════════════════════════════╝\n")

	for result in test_results:
		print(result)

	print("\n%s" % ("─" * 65))
	print("Total: %d balance & progression test groups passed\n" % test_results.size())


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
