## Prestige Scaling System: Convert prestige into gameplay benefits
##
## Applies prestige multipliers to rewards, progression, and dynasty bonuses

extends Node

class_name PrestigeScalingSystem


signal multiplier_applied(category: String, base_value: int, multiplied_value: int)
signal dynasty_bonus_calculated(bonus_type: String, bonus_amount: float)


var active_scalings: Dictionary = {}
var scaling_history: Array = []


class PrestigeScaling:
	var category: String
	var base_multiplier: float
	var milestone_bonus: float
	var achievement_bonus: float
	var combined_multiplier: float

	func _init(p_category: String, p_base: float = 1.0) -> void:
		category = p_category
		base_multiplier = p_base
		milestone_bonus = 0.0
		achievement_bonus = 0.0
		combined_multiplier = p_base


func _init() -> void:
	_initialize_scaling_categories()


func apply_prestige_multiplier(base_value: int, prestige_multiplier: float, category: String = "GENERAL") -> int:
	var multiplied = int(base_value * prestige_multiplier)

	scaling_history.append({
		"category": category,
		"base_value": base_value,
		"multiplier": prestige_multiplier,
		"result": multiplied
	})

	multiplier_applied.emit(category, base_value, multiplied)
	return multiplied


func calculate_combat_reward_scaling(base_reward: int, enemy_level: int, prestige_multiplier: float) -> Dictionary:
	var scaling = {
		"base_gold": base_reward,
		"prestige_scaled_gold": apply_prestige_multiplier(base_reward, prestige_multiplier, "COMBAT_GOLD"),
		"experience_multiplier": 1.0 + (enemy_level * 0.01),
		"prestige_scaled_experience": int(base_reward * 2 * prestige_multiplier),
		"loot_quality_boost": 1.0 + (prestige_multiplier - 1.0) * 0.5
	}

	return scaling


func calculate_exploration_reward_scaling(base_resources: Dictionary, prestige_multiplier: float) -> Dictionary:
	var scaled = {}

	for resource_type in base_resources.keys():
		var base = base_resources[resource_type]
		scaled[resource_type] = apply_prestige_multiplier(base, prestige_multiplier, "EXPLORATION_%s" % resource_type)

	return scaled


func calculate_economic_scaling(base_income: int, prestige_multiplier: float, faction_bonus: float = 1.0) -> Dictionary:
	var scaling = {
		"base_income": base_income,
		"prestige_scaled": apply_prestige_multiplier(base_income, prestige_multiplier, "ECONOMIC_INCOME"),
		"faction_bonus": faction_bonus,
		"total_income": int(base_income * prestige_multiplier * faction_bonus),
		"prosperity_gain": int(5 * prestige_multiplier)
	}

	return scaling


func calculate_dynasty_stat_scaling(base_stats: Dictionary, milestone_count: int, prestige_multiplier: float) -> Dictionary:
	var scaled_stats = {}

	# Each milestone adds 2% to all stats
	var milestone_bonus = 1.0 + (milestone_count * 0.02)

	# Prestige multiplier affects stat scaling
	var combined_scaling = milestone_bonus * prestige_multiplier

	for stat in base_stats.keys():
		var base = base_stats[stat]
		scaled_stats[stat] = int(base * combined_scaling)
		dynasty_bonus_calculated.emit(stat, combined_scaling)

	return scaled_stats


func calculate_trait_inheritance_scaling(base_inheritance_rate: float, milestone_count: int, achievement_bonus: float = 1.0) -> float:
	# Base inheritance + 5% per milestone + achievement bonus
	var boosted = base_inheritance_rate + (milestone_count * 0.05) + (achievement_bonus - 1.0) * 0.1
	return min(boosted, 1.0)  # Cap at 100%


func calculate_legendary_item_scaling(item_stats: Dictionary, prestige_multiplier: float, generation: int) -> Dictionary:
	var scaled = {}

	# Age scaling: +1% per generation
	var age_bonus = 1.0 + (generation * 0.01)

	# Prestige scales up item power
	var prestige_scaling = prestige_multiplier

	# Combined scaling
	var combined = age_bonus * prestige_scaling

	for stat in item_stats.keys():
		scaled[stat] = int(item_stats[stat] * combined)

	return scaled


func get_prestige_reward_breakdown(prestige_amount: int, milestone_multiplier: float, achievement_multiplier: float) -> Dictionary:
	var breakdown = {
		"base_prestige": prestige_amount,
		"from_milestones": int(prestige_amount * milestone_multiplier),
		"from_achievements": int(prestige_amount * achievement_multiplier),
		"combined": int(prestige_amount * milestone_multiplier * achievement_multiplier),
		"bonus_percentage": (milestone_multiplier + achievement_multiplier - 2.0) * 100.0
	}

	return breakdown


func get_scaling_stats() -> Dictionary:
	var stats = {
		"total_scalings_applied": scaling_history.size(),
		"average_multiplier": 0.0,
		"by_category": {},
		"total_value_added": 0
	}

	var total_multiplier = 0.0
	var category_counts = {}

	for entry in scaling_history:
		total_multiplier += entry["multiplier"]
		var category = entry["category"]
		if not category_counts.has(category):
			category_counts[category] = 0
		category_counts[category] += 1

		stats["total_value_added"] += entry["result"] - entry["base_value"]

	if scaling_history.size() > 0:
		stats["average_multiplier"] = total_multiplier / scaling_history.size()

	stats["by_category"] = category_counts

	return stats


func export_scaling_history() -> Array:
	return scaling_history.duplicate()


func clear_scaling_history() -> void:
	scaling_history.clear()


func _initialize_scaling_categories() -> void:
	active_scalings = {
		"combat_rewards": PrestigeScaling.new("COMBAT", 1.0),
		"exploration_rewards": PrestigeScaling.new("EXPLORATION", 1.0),
		"economic_income": PrestigeScaling.new("ECONOMIC", 1.0),
		"dynasty_stats": PrestigeScaling.new("DYNASTY", 1.0),
		"trait_inheritance": PrestigeScaling.new("INHERITANCE", 1.0),
		"legendary_items": PrestigeScaling.new("LEGENDARY", 1.0),
		"skill_progression": PrestigeScaling.new("SKILLS", 1.0)
	}
