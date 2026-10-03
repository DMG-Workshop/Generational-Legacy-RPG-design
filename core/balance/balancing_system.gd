## Balancing System: Apply balance policies and evaluate progression curves
##
## Applies centralized balance configuration across all systems. Provides progression
## evaluation, curve analysis, and balance validation for multi-generational play.

extends Node

class_name BalancingSystem


signal progression_evaluated(report: Dictionary)
signal balance_policy_applied(policy_name: String)
signal curve_analysis_complete(analysis: Dictionary)


var balance_config: BalanceConfig
var progression_history: Dictionary = {}  # heir_id -> [prestige, generation, combat_power, ...]
var balance_reports: Array = []


class CombatBalancePolicy:
	var policy_name: String = "base_combat"
	var damage_scaling_enabled: bool = true
	var defense_scaling_enabled: bool = true
	var critical_scaling_enabled: bool = true
	var min_damage_multiplier: float = 1.0
	var max_damage_multiplier: float = 2.5


class ProgressionBalancePolicy:
	var policy_name: String = "base_progression"
	var prestige_gain_enabled: bool = true
	var succession_bonus_enabled: bool = true
	var generation_scaling_enabled: bool = true
	var prestige_cap: int = 100000


class LootBalancePolicy:
	var policy_name: String = "base_loot"
	var prestige_scaling_enabled: bool = true
	var rarity_weighting_enabled: bool = true
	var treasure_gating_enabled: bool = true
	var value_scaling_enabled: bool = true


class CurveAnalysis:
	var curve_name: String
	var data_points: Array
	var min_value: float
	var max_value: float
	var average_value: float
	var growth_rate: float
	var is_exponential: bool
	var is_linear: bool

	func _init(p_name: String) -> void:
		curve_name = p_name
		data_points = []
		min_value = INF
		max_value = -INF
		average_value = 0.0
		growth_rate = 1.0
		is_exponential = false
		is_linear = false


func _init() -> void:
	balance_config = BalanceConfig.new()


func apply_combat_balance(combat_power: int, prestige: int) -> Dictionary:
	var policy = CombatBalancePolicy.new()
	var balanced = {
		"base_damage": 20,
		"base_defense": 10,
		"crit_chance": 0.05,
		"attack_speed": 1.0
	}

	if policy.damage_scaling_enabled:
		var damage_bonus = balance_config.get_damage_scaling(prestige)
		balanced["base_damage"] = int(balanced["base_damage"] * (1.0 + damage_bonus))
		balanced["base_damage"] = min(balanced["base_damage"],
			int(balanced["base_damage"] * policy.max_damage_multiplier))

	if policy.defense_scaling_enabled:
		var defense_bonus = balance_config.get_defense_scaling(prestige)
		balanced["base_defense"] = int(balanced["base_defense"] * (1.0 + defense_bonus))

	if policy.critical_scaling_enabled:
		var crit_bonus = balance_config.CombatScaling.crit_chance_per_prestige * prestige
		balanced["crit_chance"] = min(crit_bonus + 0.05, balance_config.CombatScaling.max_crit_chance)

	balance_policy_applied.emit("combat_balance")
	return balanced


func apply_progression_balance(generation: int, prestige: int) -> Dictionary:
	var policy = ProgressionBalancePolicy.new()
	var balanced = {
		"prestige_this_gen": 0,
		"prestige_carry": 0,
		"generation_bonus": 0,
		"succession_bonus": 0
	}

	if policy.prestige_gain_enabled:
		balanced["prestige_this_gen"] = balance_config.get_prestige_per_generation(generation)
		balanced["generation_bonus"] = int(balanced["prestige_this_gen"] * 0.2)

	if policy.succession_bonus_enabled:
		balanced["succession_bonus"] = int(prestige * (balance_config.PrestigeMultipliers.succession_bonus - 1.0))

	var total = balanced["prestige_this_gen"] + balanced["succession_bonus"]
	if total > policy.prestige_cap:
		total = policy.prestige_cap

	balance_policy_applied.emit("progression_balance")
	return balanced


func apply_loot_balance(heir_prestige: int, boss_tier: int) -> Dictionary:
	var policy = LootBalancePolicy.new()
	var balanced = {
		"drop_chance": balance_config.LootBalance.boss_drop_base_chance,
		"rarity_weights": balance_config.LootBalance.rarity_distribution.duplicate(),
		"loot_value_multiplier": 1.0,
		"treasure_accessible": false
	}

	if policy.prestige_scaling_enabled:
		var multiplier = 1.0 + (balance_config.LootBalance.boss_drop_prestige_multiplier * (heir_prestige / 100000.0))
		balanced["drop_chance"] = min(balanced["drop_chance"] * multiplier, balance_config.LootBalance.max_drop_chance)

	if policy.value_scaling_enabled:
		balanced["loot_value_multiplier"] = 1.0 + (balance_config.LootBalance.loot_value_prestige_multiplier * (heir_prestige / 100000.0))

	if policy.treasure_gating_enabled:
		if heir_prestige >= balance_config.PrestigeThresholds.tiers[BalanceConfig.PrestigeTier.ETERNAL]:
			balanced["treasure_accessible"] = true

	balance_policy_applied.emit("loot_balance")
	return balanced


func evaluate_progression(start_gen: int = 1, end_gen: int = 999) -> Dictionary:
	var report = {
		"evaluation_range": {"start": start_gen, "end": end_gen},
		"total_prestige_accumulated": 0,
		"average_prestige_per_gen": 0.0,
		"prestige_at_each_tier": {},
		"tiers_reached": [],
		"progression_curve": [],
		"balance_issues": []
	}

	var tiers = [
		BalanceConfig.PrestigeTier.BRONZE,
		BalanceConfig.PrestigeTier.SILVER,
		BalanceConfig.PrestigeTier.GOLD,
		BalanceConfig.PrestigeTier.PLATINUM,
		BalanceConfig.PrestigeTier.DIAMOND,
		BalanceConfig.PrestigeTier.ETERNAL
	]

	var cumulative_prestige = 0
	for tier in tiers:
		report["prestige_at_each_tier"][tier] = balance_config.PrestigeThresholds.tiers[tier]

	for gen in range(start_gen, end_gen + 1):
		var prestige_this_gen = balance_config.get_prestige_per_generation(gen)
		cumulative_prestige += prestige_this_gen
		report["progression_curve"].append({
			"generation": gen,
			"prestige_gained": prestige_this_gen,
			"cumulative_prestige": cumulative_prestige
		})

		for tier in tiers:
			var tier_threshold = balance_config.PrestigeThresholds.tiers[tier]
			if cumulative_prestige >= tier_threshold and tier not in report["tiers_reached"]:
				report["tiers_reached"].append(tier)

	report["total_prestige_accumulated"] = cumulative_prestige
	report["average_prestige_per_gen"] = float(cumulative_prestige) / (end_gen - start_gen + 1)

	if cumulative_prestige < balance_config.PrestigeThresholds.tiers[BalanceConfig.PrestigeTier.ETERNAL]:
		report["balance_issues"].append("Prestige accumulation insufficient for ETERNAL tier")

	if report["average_prestige_per_gen"] < balance_config.GenerationBalance.prestige_per_generation_average * 0.8:
		report["balance_issues"].append("Prestige gain below target average")

	progression_evaluated.emit(report)
	return report


func analyze_combat_curve(generations: int, max_prestige: int) -> CurveAnalysis:
	var analysis = CurveAnalysis.new("combat_scaling")

	for gen in range(1, generations + 1):
		var prestige = min(int((float(gen) / generations) * max_prestige), max_prestige)
		var damage = balance_config.get_damage_scaling(prestige)
		analysis.data_points.append(damage)
		analysis.min_value = min(analysis.min_value, damage)
		analysis.max_value = max(analysis.max_value, damage)

	var sum = 0.0
	for point in analysis.data_points:
		sum += point
	analysis.average_value = sum / analysis.data_points.size()

	if analysis.data_points.size() > 1:
		var first_half_avg = 0.0
		for i in range(analysis.data_points.size() / 2):
			first_half_avg += analysis.data_points[i]
		first_half_avg /= (analysis.data_points.size() / 2)

		var second_half_avg = 0.0
		for i in range(analysis.data_points.size() / 2, analysis.data_points.size()):
			second_half_avg += analysis.data_points[i]
		second_half_avg /= (analysis.data_points.size() - analysis.data_points.size() / 2)

		analysis.growth_rate = second_half_avg / first_half_avg if first_half_avg > 0 else 1.0
		analysis.is_exponential = analysis.growth_rate > 1.2
		analysis.is_linear = abs(analysis.growth_rate - 1.0) < 0.1

	curve_analysis_complete.emit({"curve": "combat", "analysis": analysis})
	return analysis


func analyze_enemy_scaling(generations: int, max_prestige: int) -> CurveAnalysis:
	var analysis = CurveAnalysis.new("enemy_scaling")

	for gen in range(1, generations + 1):
		var prestige = min(int((float(gen) / generations) * max_prestige), max_prestige)
		var difficulty = balance_config.get_enemy_difficulty_scaling(gen, prestige)
		analysis.data_points.append(difficulty)
		analysis.min_value = min(analysis.min_value, difficulty)
		analysis.max_value = max(analysis.max_value, difficulty)

	var sum = 0.0
	for point in analysis.data_points:
		sum += point
	analysis.average_value = sum / analysis.data_points.size()

	if analysis.data_points.size() > 1 and analysis.data_points[0] > 0:
		analysis.growth_rate = analysis.data_points[-1] / analysis.data_points[0]

	curve_analysis_complete.emit({"curve": "enemy", "analysis": analysis})
	return analysis


func compare_player_vs_enemy(generations: int, max_prestige: int) -> Dictionary:
	var player_curve = analyze_combat_curve(generations, max_prestige)
	var enemy_curve = analyze_enemy_scaling(generations, max_prestige)

	var comparison = {
		"player_growth": player_curve.growth_rate,
		"enemy_growth": enemy_curve.growth_rate,
		"player_avg": player_curve.average_value,
		"enemy_avg": enemy_curve.average_value,
		"balance_ratio": player_curve.average_value / enemy_curve.average_value if enemy_curve.average_value > 0 else 1.0,
		"is_balanced": true,
		"recommendations": []
	}

	if comparison["balance_ratio"] < 0.5:
		comparison["is_balanced"] = false
		comparison["recommendations"].append("Enemies are too strong; increase player scaling or decrease enemy scaling")
	elif comparison["balance_ratio"] > 2.0:
		comparison["is_balanced"] = false
		comparison["recommendations"].append("Player is too strong; decrease player scaling or increase enemy scaling")

	if enemy_curve.growth_rate > player_curve.growth_rate * 1.5:
		comparison["recommendations"].append("Enemy scaling outpaces player growth; power creep risk")

	return comparison


func get_balance_report() -> Dictionary:
	var report = {
		"timestamp": Time.get_ticks_msec(),
		"config_validation": balance_config.validate_balance(),
		"progression_eval": evaluate_progression(),
		"player_vs_enemy": compare_player_vs_enemy(999, 100000)
	}

	balance_reports.append(report)
	return report
