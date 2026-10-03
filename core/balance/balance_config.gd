## Balance Configuration: Prestige, progression pacing, tier thresholds, and multipliers
##
## Centralizes all tuning parameters for prestige accumulation, tier requirements,
## combat scaling, and progression pacing to support 999-generation dynasties.

extends Node

class_name BalanceConfig


enum PrestigeTier { BRONZE, SILVER, GOLD, PLATINUM, DIAMOND, ETERNAL }


class PrestigeThresholds:
	static var tiers = {
		PrestigeTier.BRONZE: 0,
		PrestigeTier.SILVER: 1000,
		PrestigeTier.GOLD: 5000,
		PrestigeTier.PLATINUM: 15000,
		PrestigeTier.DIAMOND: 35000,
		PrestigeTier.ETERNAL: 75000
	}


class PrestigeMultipliers:
	static var base_gain = 1.0
	static var combat_victory = 500
	static var quest_completion = 300
	static var faction_action = 200
	static var realm_unlock = 1000
	static var legendary_defeat = 2000
	static var prophecy_fulfilled = 5000
	static var curse_lifted = 750

	static var generation_bonus_base = 100
	static var generation_bonus_multiplier = 0.02

	static var succession_bonus = 1.1
	static var death_penalty = 0.9


class CombatScaling:
	static var damage_per_prestige = 0.001
	static var defense_per_prestige = 0.0008
	static var attack_speed_per_prestige = 0.0005
	static var crit_chance_per_prestige = 0.0003

	static var max_damage_multiplier = 2.5
	static var max_defense_multiplier = 2.0
	static var max_crit_chance = 0.8


class EnemyScaling:
	static var difficulty_factor_per_generation = 1.03
	static var prestige_enemy_multiplier = 0.5
	static var boss_prestige_multiplier = 0.7
	static var max_enemy_health_multiplier = 5.0
	static var max_enemy_damage_multiplier = 4.0


class StatProgression:
	static var base_health = 100
	static var health_per_prestige = 0.15
	static var vitality_stat_multiplier = 2.0

	static var base_damage = 20
	static var damage_per_prestige = 0.08
	static var strength_stat_multiplier = 1.5

	static var base_defense = 10
	static var defense_per_prestige = 0.06
	static var defense_stat_multiplier = 1.2

	static var intelligence_multiplier = 1.8


class HeirloomBalance:
	static var tier_advancement_chance = 0.25
	static var tier_advancement_generation_interval = 5
	static var tier_advancement_stat_boost = 1.15

	static var reforge_stat_boost = 1.1
	static var affix_max_count = 3

	static var inheritance_multiplier_base = 0.3
	static var inheritance_multiplier_max = 1.3


class LootBalance:
	static var boss_drop_base_chance = 0.1
	static var boss_drop_prestige_multiplier = 0.5
	static var max_drop_chance = 0.8

	static var loot_value_prestige_multiplier = 0.3

	static var rarity_distribution = {
		1: 0.50,
		2: 0.30,
		3: 0.15,
		4: 0.04,
		5: 0.01
	}


class ReputationBalance:
	static var decay_rate_per_generation = 0.95
	static var gain_prestige_multiplier = 0.5

	static var tier_thresholds = {
		"HATED": -5000,
		"DISLIKED": -2000,
		"NEUTRAL": 0,
		"LIKED": 2000,
		"REVERED": 5000,
		"LEGENDARY": 8000
	}

	static var perk_unlock_reputation = {
		"basic": 1000,
		"intermediate": 3000,
		"advanced": 5000,
		"legendary": 8000
	}


class TraitBalance:
	static var mutation_chance_base = 0.05
	static var mutation_chance_prestige_bonus = 0.0001
	static var max_mutation_chance = 0.15

	static var dormant_skip_chance = 0.30
	static var inheritance_decay_rate = 0.95

	static var stat_bonus_cap_multiplier = 2.0


class WorldBalance:
	static var realm_unlock_prestige_base = 5000
	static var realm_unlock_prestige_scaling = 1.5

	static var legendary_boss_prestige_minimum = 15000
	static var legendary_boss_stat_scaling = 1.8

	static var building_cost_base = 100
	static var building_cost_prestige_multiplier = 0.02
	static var max_building_cost_multiplier = 3.0


class GenerationBalance:
	static var age_duration_base = 20
	static var age_transition_prestige_gain = 500
	static var milestone_check_generation = 50

	static var dynasty_progression_target = 999
	static var final_prestige_target = 90000
	static var prestige_per_generation_average = 90.0


func _init() -> void:
	pass


func get_prestige_tier_threshold(tier: int) -> int:
	return PrestigeThresholds.tiers.get(tier, 0)


func get_damage_scaling(prestige: int) -> float:
	return min(
		CombatScaling.damage_per_prestige * prestige,
		CombatScaling.max_damage_multiplier
	)


func get_defense_scaling(prestige: int) -> float:
	return min(
		CombatScaling.defense_per_prestige * prestige,
		CombatScaling.max_defense_multiplier
	)


func get_enemy_difficulty_scaling(generation: int, prestige: int) -> float:
	var generation_scaling = pow(EnemyScaling.difficulty_factor_per_generation, generation)
	var prestige_scaling = 1.0 + (EnemyScaling.prestige_enemy_multiplier * (prestige / 100000.0))
	return generation_scaling * prestige_scaling


func get_boss_scaling(generation: int, prestige: int) -> float:
	var generation_scaling = pow(EnemyScaling.difficulty_factor_per_generation, generation)
	var prestige_scaling = 1.0 + (EnemyScaling.prestige_enemy_multiplier * (prestige / 100000.0))
	return generation_scaling * prestige_scaling


func get_prestige_per_generation(generation: int) -> int:
	var base_gain = PrestigeMultipliers.generation_bonus_base
	var bonus = int(base_gain * (1.0 + (PrestigeMultipliers.generation_bonus_multiplier * generation)))
	return bonus


func get_succession_prestige_carry(parent_prestige: int) -> int:
	return int(parent_prestige * PrestigeMultipliers.succession_bonus)


func calculate_total_progression(target_generations: int) -> int:
	var total = 0
	for gen in range(1, target_generations + 1):
		total += get_prestige_per_generation(gen)
	return total


func validate_balance() -> Dictionary:
	var report = {
		"tier_spacing_valid": true,
		"progression_feasible": true,
		"warnings": [],
		"tier_gaps": {},
		"projected_final_prestige": 0,
		"generations_to_eternal": 0
	}

	var tier_list = [PrestigeTier.BRONZE, PrestigeTier.SILVER, PrestigeTier.GOLD,
					PrestigeTier.PLATINUM, PrestigeTier.DIAMOND, PrestigeTier.ETERNAL]

	for i in range(tier_list.size() - 1):
		var current = PrestigeThresholds.tiers[tier_list[i]]
		var next_tier = PrestigeThresholds.tiers[tier_list[i + 1]]
		var gap = next_tier - current
		report["tier_gaps"][tier_list[i]] = gap

		if gap < 1000 or gap > 100000:
			report["warnings"].append("Tier gap suspicious: %s -> %s = %d" %
				[tier_list[i], tier_list[i + 1], gap])

	var projected = calculate_total_progression(GenerationBalance.dynasty_progression_target)
	report["projected_final_prestige"] = projected

	if projected < PrestigeThresholds.tiers[PrestigeTier.ETERNAL]:
		report["progression_feasible"] = false
		report["warnings"].append("Projected prestige %.0f is below ETERNAL tier %.0f" %
			[projected, PrestigeThresholds.tiers[PrestigeTier.ETERNAL]])

	for gen in range(1, GenerationBalance.dynasty_progression_target + 1):
		if get_prestige_per_generation(gen) >= PrestigeThresholds.tiers[PrestigeTier.ETERNAL]:
			report["generations_to_eternal"] = gen
			break

	return report
