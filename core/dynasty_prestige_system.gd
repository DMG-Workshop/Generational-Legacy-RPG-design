## Dynasty Prestige System: Global prestige pool and multiplier scaling
##
## Manages persistent prestige pool that carries across generations with scaling effects

extends Node

class_name DynastyPrestigeSystem


signal prestige_accumulated(amount: int, source: String)
signal prestige_spent(amount: int, reason: String)
signal prestige_tier_reached(tier: int, total_prestige: int)
signal prestige_multiplier_changed(new_multiplier: float)


enum PrestigeTier { BRONZE, SILVER, GOLD, PLATINUM, DIAMOND, ETERNAL }

enum PrestigeSource { ACHIEVEMENT, MILESTONE, DEED, COMBAT, EXPLORATION, ECONOMIC }


var total_prestige: int = 0
var prestige_spent: int = 0
var prestige_available: int = 0
var current_tier: int = PrestigeTier.BRONZE
var milestone_multiplier: float = 1.0
var achievement_multiplier: float = 1.0
var combined_multiplier: float = 1.0
var prestige_history: Array = []
var tier_achievements: Dictionary = {}


class PrestigeTierInfo:
	var tier: int
	var min_prestige: int
	var name: String
	var multiplier_bonus: float
	var stat_bonus: int
	var resource_bonus: int

	func _init(p_tier: int, p_min: int, p_name: String, p_mult: float, p_stat: int, p_res: int) -> void:
		tier = p_tier
		min_prestige = p_min
		name = p_name
		multiplier_bonus = p_mult
		stat_bonus = p_stat
		resource_bonus = p_res


var tier_thresholds: Dictionary = {
	PrestigeTier.BRONZE: PrestigeTierInfo.new(PrestigeTier.BRONZE, 0, "Bronze", 1.0, 0, 0),
	PrestigeTier.SILVER: PrestigeTierInfo.new(PrestigeTier.SILVER, 1000, "Silver", 1.05, 1, 50),
	PrestigeTier.GOLD: PrestigeTierInfo.new(PrestigeTier.GOLD, 5000, "Gold", 1.10, 3, 150),
	PrestigeTier.PLATINUM: PrestigeTierInfo.new(PrestigeTier.PLATINUM, 15000, "Platinum", 1.15, 5, 300),
	PrestigeTier.DIAMOND: PrestigeTierInfo.new(PrestigeTier.DIAMOND, 35000, "Diamond", 1.20, 8, 500),
	PrestigeTier.ETERNAL: PrestigeTierInfo.new(PrestigeTier.ETERNAL, 75000, "Eternal", 1.25, 10, 750)
}


func _init() -> void:
	prestige_history = []
	tier_achievements = {}
	_calculate_multipliers()


func accumulate_prestige(amount: int, source: int = PrestigeSource.ACHIEVEMENT) -> void:
	if amount <= 0:
		return

	total_prestige += amount
	prestige_available += amount

	var source_name = PrestigeSource.keys()[source] if source < PrestigeSource.size() else "UNKNOWN"
	prestige_history.append({
		"amount": amount,
		"source": source_name,
		"total_at_time": total_prestige,
		"generation": 0
	})

	_check_tier_advancement()
	prestige_accumulated.emit(amount, source_name)


func spend_prestige(amount: int, reason: String = "") -> bool:
	if amount <= 0 or prestige_available < amount:
		return false

	prestige_available -= amount
	prestige_spent += amount
	prestige_spent.emit(amount, reason if reason else "Unspecified")
	return true


func add_milestone_multiplier(multiplier: float) -> void:
	milestone_multiplier = move_toward(milestone_multiplier, multiplier, 0.05)
	_calculate_multipliers()


func add_achievement_multiplier(multiplier: float) -> void:
	achievement_multiplier = move_toward(achievement_multiplier, multiplier, 0.05)
	_calculate_multipliers()


func get_current_tier() -> int:
	return current_tier


func get_tier_info(tier: int) -> PrestigeTierInfo:
	return tier_thresholds.get(tier, tier_thresholds[PrestigeTier.BRONZE])


func get_multiplier() -> float:
	return combined_multiplier


func get_stat_bonus() -> int:
	var tier_info = tier_thresholds[current_tier]
	return tier_info.stat_bonus


func get_resource_bonus() -> int:
	var tier_info = tier_thresholds[current_tier]
	return tier_info.resource_bonus


func get_prestige_description() -> String:
	var tier_info = tier_thresholds[current_tier]
	return "Dynasty Tier: %s (%.2fx multiplier)" % [tier_info.name, combined_multiplier]


func get_prestige_stats() -> Dictionary:
	var stats = {
		"total_prestige": total_prestige,
		"prestige_available": prestige_available,
		"prestige_spent": prestige_spent,
		"current_tier": PrestigeTier.keys()[current_tier],
		"multiplier": combined_multiplier,
		"milestone_multiplier": milestone_multiplier,
		"achievement_multiplier": achievement_multiplier,
		"tier_breakdown": {},
		"prestige_sources": {}
	}

	for tier in tier_thresholds.keys():
		var tier_info = tier_thresholds[tier]
		stats["tier_breakdown"][tier_info.name] = {
			"min_prestige": tier_info.min_prestige,
			"multiplier_bonus": tier_info.multiplier_bonus
		}

	var sources = {}
	for entry in prestige_history:
		var source = entry["source"]
		if not sources.has(source):
			sources[source] = 0
		sources[source] += entry["amount"]

	stats["prestige_sources"] = sources
	return stats


func reset_for_new_generation() -> void:
	prestige_available = total_prestige
	prestige_spent = 0
	milestone_multiplier = 1.0
	achievement_multiplier = 1.0
	_calculate_multipliers()


func _check_tier_advancement() -> void:
	var new_tier = current_tier

	for tier in tier_thresholds.keys():
		var tier_info = tier_thresholds[tier]
		if total_prestige >= tier_info.min_prestige:
			new_tier = tier

	if new_tier != current_tier:
		current_tier = new_tier
		var tier_info = tier_thresholds[new_tier]
		if not tier_achievements.has(new_tier):
			tier_achievements[new_tier] = true
			prestige_tier_reached.emit(new_tier, total_prestige)


func _calculate_multipliers() -> void:
	var old_multiplier = combined_multiplier
	combined_multiplier = milestone_multiplier * achievement_multiplier

	if abs(combined_multiplier - old_multiplier) > 0.001:
		prestige_multiplier_changed.emit(combined_multiplier)
