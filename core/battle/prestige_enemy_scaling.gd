## Prestige Enemy Scaling: Scale enemy stats based on player prestige
##
## Ensures enemies scale with prestige to maintain challenge and rewards

extends Node

class_name PrestigeEnemyScaling


signal enemy_scaled(enemy_id: String, base_level: int, scaled_level: int)
signal loot_scaled(enemy_id: String, base_reward: int, scaled_reward: int)
signal encounter_difficulty_calculated(difficulty: float)


var scaling_multiplier_per_prestige_tier: float = 0.05  # 5% per tier
var loot_scaling_factor: float = 0.1  # 10% per tier
var difficulty_scaling_factor: float = 0.2  # 20% per tier


class ScaledEnemy:
	var enemy_id: String
	var base_level: int
	var scaled_level: int
	var base_stats: Dictionary
	var scaled_stats: Dictionary
	var prestige_used: int
	var scale_multiplier: float
	var loot_multiplier: float

	func _init(p_id: String, p_level: int) -> void:
		enemy_id = p_id
		base_level = p_level
		scaled_level = p_level
		base_stats = {}
		scaled_stats = {}
		prestige_used = 0
		scale_multiplier = 1.0
		loot_multiplier = 1.0


func _init() -> void:
	pass


func calculate_enemy_scaling(enemy_id: String, base_level: int, base_stats: Dictionary, prestige_amount: int) -> ScaledEnemy:
	var scaled_enemy = ScaledEnemy.new(enemy_id, base_level)
	scaled_enemy.base_stats = base_stats.duplicate()
	scaled_enemy.prestige_used = prestige_amount

	# Scale multiplier increases with prestige tiers (assume 1 tier per 5000 prestige)
	var prestige_tiers = prestige_amount / 5000
	scaled_enemy.scale_multiplier = 1.0 + (prestige_tiers * scaling_multiplier_per_prestige_tier)
	scaled_enemy.scale_multiplier = clamp(scaled_enemy.scale_multiplier, 1.0, 3.0)

	# Scale level
	scaled_enemy.scaled_level = int(base_level * scaled_enemy.scale_multiplier)

	# Scale stats
	for stat in base_stats.keys():
		var base_value = base_stats[stat]
		scaled_enemy.scaled_stats[stat] = int(base_value * scaled_enemy.scale_multiplier)

	# Loot multiplier
	scaled_enemy.loot_multiplier = 1.0 + (prestige_tiers * loot_scaling_factor)
	scaled_enemy.loot_multiplier = clamp(scaled_enemy.loot_multiplier, 1.0, 2.5)

	enemy_scaled.emit(enemy_id, base_level, scaled_enemy.scaled_level)
	return scaled_enemy


func scale_enemy_stat(stat_name: String, base_value: int, prestige_amount: int) -> int:
	var prestige_tiers = prestige_amount / 5000
	var multiplier = 1.0 + (prestige_tiers * scaling_multiplier_per_prestige_tier)
	multiplier = clamp(multiplier, 1.0, 3.0)

	return int(base_value * multiplier)


func scale_enemy_loot(base_loot: Dictionary, prestige_amount: int) -> Dictionary:
	var prestige_tiers = prestige_amount / 5000
	var multiplier = 1.0 + (prestige_tiers * loot_scaling_factor)
	multiplier = clamp(multiplier, 1.0, 2.5)

	var scaled_loot = {}

	for loot_type in base_loot.keys():
		var base_amount = base_loot[loot_type]
		scaled_loot[loot_type] = int(base_amount * multiplier)

	loot_scaled.emit("enemy_loot", 0, int(base_loot.get("gold", 0) * multiplier))
	return scaled_loot


func calculate_encounter_difficulty(player_prestige: int, enemy_prestige_equivalent: int) -> float:
	# Difficulty as ratio of enemy to player prestige
	if player_prestige == 0:
		return 1.0

	var difficulty = float(enemy_prestige_equivalent) / float(player_prestige)
	difficulty = clamp(difficulty, 0.1, 5.0)

	encounter_difficulty_calculated.emit(difficulty)
	return difficulty


func get_prestige_level_scaling(player_level: int, prestige_amount: int) -> int:
	# Each prestige tier adds to enemy level for challenge
	var prestige_tiers = prestige_amount / 5000
	var additional_levels = int(prestige_tiers)

	return player_level + additional_levels


func calculate_prestige_boss_stats(base_stats: Dictionary, prestige_multiplier: float) -> Dictionary:
	var boss_stats = {}

	for stat in base_stats.keys():
		var base_value = base_stats[stat]
		# Bosses get extra scaling compared to regular enemies
		var boss_scaling = prestige_multiplier * 1.25  # 25% more for bosses
		boss_stats[stat] = int(base_value * boss_scaling)

	return boss_stats


func get_enemy_scaling_description(scaled_enemy: ScaledEnemy) -> String:
	var desc = "Prestige Scaled Enemy: %s\n" % scaled_enemy.enemy_id
	desc += "- Base Level: %d → Scaled Level: %d\n" % [scaled_enemy.base_level, scaled_enemy.scaled_level]
	desc += "- Scale Multiplier: %.2fx\n" % scaled_enemy.scale_multiplier
	desc += "- Loot Multiplier: %.2fx\n" % scaled_enemy.loot_multiplier

	return desc


func get_prestige_level_cap(prestige_amount: int) -> int:
	# Higher prestige allows fighting higher level enemies
	var prestige_tiers = prestige_amount / 5000
	var level_cap = 10 + (prestige_tiers * 5)

	return int(level_cap)


func is_enemy_too_easy(player_prestige: int, enemy_stats: Dictionary, player_stats: Dictionary) -> bool:
	# If enemy stats are less than 50% of player stats, it's too easy
	var enemy_total = 0
	var player_total = 0

	for stat in player_stats.keys():
		player_total += player_stats.get(stat, 0)
		enemy_total += enemy_stats.get(stat, 0)

	if player_total == 0:
		return false

	var ratio = float(enemy_total) / float(player_total)
	return ratio < 0.5


func is_enemy_too_hard(player_prestige: int, enemy_stats: Dictionary, player_stats: Dictionary) -> bool:
	# If enemy stats are more than 200% of player stats, it's too hard
	var enemy_total = 0
	var player_total = 0

	for stat in player_stats.keys():
		player_total += player_stats.get(stat, 0)
		enemy_total += enemy_stats.get(stat, 0)

	if player_total == 0:
		return true

	var ratio = float(enemy_total) / float(player_total)
	return ratio > 2.0


func get_scaling_stats() -> Dictionary:
	var stats = {
		"scaling_multiplier_per_tier": scaling_multiplier_per_prestige_tier,
		"loot_scaling_per_tier": loot_scaling_factor,
		"difficulty_scaling_per_tier": difficulty_scaling_factor,
		"max_scale_multiplier": 3.0,
		"max_loot_multiplier": 2.5,
		"prestige_per_tier": 5000
	}

	return stats
