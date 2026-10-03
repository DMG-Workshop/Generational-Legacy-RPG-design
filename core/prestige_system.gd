## Prestige System: Track prestige points and grant bonuses to future generations
##
## Manages prestige accumulation, benefits, and multi-generational scaling

extends Node

class_name PrestigeSystem


signal prestige_added(amount: int, source: String)
signal prestige_spent(amount: int, benefit: String)
signal prestige_milestone_reached(threshold: int, total: int)


var total_prestige: int = 0
var prestige_by_generation: Dictionary = {}
var prestige_by_source: Dictionary = {}
var prestige_spent_total: int = 0


func _init() -> void:
	total_prestige = 0
	prestige_by_generation = {}
	prestige_by_source = {}


func add_prestige(amount: int, source: String = "general", generation: int = 1) -> void:
	total_prestige += amount

	if not prestige_by_generation.has(generation):
		prestige_by_generation[generation] = 0
	prestige_by_generation[generation] += amount

	if not prestige_by_source.has(source):
		prestige_by_source[source] = 0
	prestige_by_source[source] += amount

	prestige_added.emit(amount, source)

	# Milestone checks at multiples of 500
	if total_prestige % 500 == 0 and total_prestige > 0:
		prestige_milestone_reached.emit(total_prestige, total_prestige)


func spend_prestige(amount: int, benefit: String = "general") -> bool:
	if total_prestige >= amount:
		total_prestige -= amount
		prestige_spent_total += amount
		prestige_spent.emit(amount, benefit)
		return true
	return false


func get_available_prestige() -> int:
	return total_prestige


func get_prestige_by_generation(generation: int) -> int:
	return prestige_by_generation.get(generation, 0)


func get_prestige_by_source(source: String) -> int:
	return prestige_by_source.get(source, 0)


func get_prestige_spent() -> int:
	return prestige_spent_total


func get_prestige_multiplier() -> float:
	if total_prestige < 100:
		return 1.0
	elif total_prestige < 500:
		return 1.05
	elif total_prestige < 1000:
		return 1.10
	elif total_prestige < 2500:
		return 1.15
	else:
		return 1.20


func get_heir_stat_bonus(heir_index: int = 1) -> Dictionary:
	var bonus = {
		"strength": 0,
		"dexterity": 0,
		"constitution": 0,
		"intelligence": 0,
		"wisdom": 0,
		"charisma": 0
	}

	if total_prestige < 100:
		return bonus

	# Stat bonus scales with prestige: +1 per 100 prestige (capped at +15)
	var stat_points = min(15, total_prestige / 100)

	# Distribute bonus based on prestige tier
	if total_prestige >= 5000:
		# Legendary tier: balanced distribution
		for stat in bonus.keys():
			bonus[stat] = stat_points / 6
	elif total_prestige >= 2500:
		# Platinum tier: +2 to all, +1 to primary
		for stat in bonus.keys():
			bonus[stat] = 2
		bonus["strength"] += 1
	elif total_prestige >= 1000:
		# Gold tier: +1 to primary stats
		bonus["strength"] += 1
		bonus["constitution"] += 1
	elif total_prestige >= 500:
		# Silver tier: +1 to main stat
		bonus["strength"] += 1

	return bonus


func get_equipment_bonus() -> Dictionary:
	var bonus = {
		"damage_multiplier": 1.0,
		"defense_multiplier": 1.0,
		"health_multiplier": 1.0
	}

	if total_prestige < 250:
		return bonus

	# Equipment bonus scales with prestige
	var bonus_percent = min(25, (total_prestige - 250) / 100)

	bonus["damage_multiplier"] = 1.0 + (bonus_percent / 100.0)
	bonus["defense_multiplier"] = 1.0 + (bonus_percent / 100.0 * 0.75)
	bonus["health_multiplier"] = 1.0 + (bonus_percent / 100.0 * 0.5)

	return bonus


func get_starting_resources(generation: int = 1) -> Dictionary:
	var resources = {
		"gold": 500,
		"supplies": 10
	}

	if total_prestige < 100:
		return resources

	# Gold bonus: +50 per 100 prestige (capped at +1000)
	var gold_bonus = min(1000, (total_prestige / 100) * 50)
	resources["gold"] += gold_bonus

	# Supplies bonus: +1 per 250 prestige (capped at +5)
	var supplies_bonus = min(5, total_prestige / 250)
	resources["supplies"] += supplies_bonus

	return resources


func get_experience_multiplier() -> float:
	if total_prestige < 100:
		return 1.0
	elif total_prestige < 500:
		return 1.05
	elif total_prestige < 1000:
		return 1.10
	elif total_prestige < 2500:
		return 1.15
	else:
		return 1.20


func get_heir_progression_bonus() -> Dictionary:
	var bonus = {
		"level_start": 1,
		"experience_multiplier": get_experience_multiplier(),
		"skill_points_bonus": 0
	}

	# Starting level bonus: +1 per 1000 prestige (capped at +5)
	bonus["level_start"] = 1 + min(5, total_prestige / 1000)

	# Skill points bonus: +1 per 500 prestige (capped at +3)
	bonus["skill_points_bonus"] = min(3, total_prestige / 500)

	return bonus


func get_prosperity_bonus(base_prosperity: float) -> float:
	if total_prestige < 100:
		return base_prosperity

	# Prosperity bonus: +5% per 500 prestige (capped at +25%)
	var bonus_percent = min(25, (total_prestige / 500) * 5)
	return base_prosperity * (1.0 + (bonus_percent / 100.0))


func get_prestige_benefits() -> Dictionary:
	var benefits = {
		"stat_bonus": get_heir_stat_bonus(),
		"equipment_bonus": get_equipment_bonus(),
		"starting_resources": get_starting_resources(),
		"experience_multiplier": get_experience_multiplier(),
		"heir_progression_bonus": get_heir_progression_bonus(),
		"prestige_multiplier": get_prestige_multiplier()
	}

	return benefits


func get_prestige_summary() -> Dictionary:
	var summary = {
		"total_prestige": total_prestige,
		"prestige_spent": prestige_spent_total,
		"available": get_available_prestige(),
		"multiplier": get_prestige_multiplier(),
		"sources": prestige_by_source.duplicate(),
		"by_generation": prestige_by_generation.duplicate(),
		"benefits_active": get_prestige_benefits()
	}

	return summary


func transfer_prestige_to_next_generation() -> void:
	# Prestige carries forward at 100% (accumulated across all generations)
	# No decay for prestige - it only grows
	pass


func export_prestige_history() -> Dictionary:
	var history = {
		"total_accumulated": total_prestige,
		"total_spent": prestige_spent_total,
		"net_prestige": total_prestige,
		"sources": prestige_by_source.duplicate(),
		"generations_with_prestige": 0,
		"average_per_generation": 0.0,
		"highest_generation": 0,
		"highest_generation_amount": 0
	}

	history["generations_with_prestige"] = prestige_by_generation.size()

	if prestige_by_generation.size() > 0:
		var total_gens = prestige_by_generation.size()
		history["average_per_generation"] = float(total_prestige) / float(total_gens)

		for gen in prestige_by_generation.keys():
			if prestige_by_generation[gen] > history["highest_generation_amount"]:
				history["highest_generation_amount"] = prestige_by_generation[gen]
				history["highest_generation"] = gen

	return history


func get_prestige_legacy() -> String:
	if total_prestige == 0:
		return "The dynasty has not yet begun to build prestige."

	var legacy = "The dynasty has accumulated %d prestige points through their legendary deeds. " % total_prestige

	var source_count = prestige_by_source.size()
	legacy += "This prestige comes from %d different sources. " % source_count

	var multiplier = get_prestige_multiplier()
	if multiplier > 1.0:
		var bonus_percent = int((multiplier - 1.0) * 100)
		legacy += "Future generations benefit from a %d%% bonus to their endeavors. " % bonus_percent

	return legacy
