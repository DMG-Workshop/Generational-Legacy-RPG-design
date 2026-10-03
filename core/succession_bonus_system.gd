## Succession Bonus System: Calculate bonuses for next-generation heirs
##
## Translates prestige into starting stat, resource, and progression bonuses

extends Node

class_name SuccessionBonusSystem


signal bonus_applied(heir_id: String, bonus_type: String, amount: int)
signal successor_prepared(heir_id: String, total_bonuses: Dictionary)


var succession_bonuses: Dictionary = {}
var bonus_caps: Dictionary = {
	"starting_level": 25,
	"stat_bonus": 50,
	"starting_gold": 5000,
	"starting_supplies": 100,
	"skill_points": 20,
	"legendary_slots": 10,
	"experience_multiplier": 2.0,
	"trait_inheritance_boost": 0.5
}

var prestige_conversion_rates: Dictionary = {
	"stat_bonus_per_prestige": 1.0,  # 1 stat per 100 prestige
	"level_per_prestige": 1.0,       # 1 level per 1000 prestige
	"skill_points_per_prestige": 1.0, # 1 skill point per 500 prestige
	"gold_per_prestige": 1.0,         # 5 gold per 100 prestige
	"supplies_per_prestige": 1.0,    # 1 supply per 2500 prestige
	"legendary_slot_per_prestige": 1.0 # 1 slot per 10000 prestige
}


class SuccessionBonus:
	var heir_id: String
	var prestige_level: int
	var starting_level: int
	var stat_bonuses: Dictionary
	var starting_gold: int
	var starting_supplies: int
	var skill_points: int
	var legendary_slots: int
	var experience_multiplier: float
	var trait_inheritance_boost: float

	func _init(p_heir_id: String, p_prestige: int) -> void:
		heir_id = p_heir_id
		prestige_level = p_prestige
		starting_level = 0
		stat_bonuses = {}
		starting_gold = 0
		starting_supplies = 0
		skill_points = 0
		legendary_slots = 0
		experience_multiplier = 1.0
		trait_inheritance_boost = 0.0


func _init() -> void:
	succession_bonuses = {}


func calculate_bonuses_for_heir(heir_id: String, prestige_amount: int, milestone_count: int = 0, achievement_count: int = 0) -> SuccessionBonus:
	var bonus = SuccessionBonus.new(heir_id, prestige_amount)

	# Starting level: +1 per 1000 prestige
	bonus.starting_level = min(
		int(prestige_amount / 1000),
		bonus_caps["starting_level"]
	)

	# Stat bonuses: +1 per 100 prestige (distributed across main stats)
	var stat_bonus_total = min(
		int(prestige_amount / 100),
		bonus_caps["stat_bonus"]
	)
	bonus.stat_bonuses = {
		"strength": int(stat_bonus_total * 0.25),
		"dexterity": int(stat_bonus_total * 0.25),
		"intelligence": int(stat_bonus_total * 0.25),
		"vitality": int(stat_bonus_total * 0.25)
	}

	# Starting gold: +5 gold per 100 prestige
	bonus.starting_gold = min(
		int(prestige_amount / 100) * 5,
		bonus_caps["starting_gold"]
	)

	# Starting supplies: +1 per 2500 prestige
	bonus.starting_supplies = min(
		int(prestige_amount / 2500),
		bonus_caps["starting_supplies"]
	)

	# Skill points: +1 per 500 prestige
	bonus.skill_points = min(
		int(prestige_amount / 500),
		bonus_caps["skill_points"]
	)

	# Legendary slots: +1 per 10000 prestige
	bonus.legendary_slots = min(
		int(prestige_amount / 10000),
		bonus_caps["legendary_slots"]
	)

	# Experience multiplier: 1.0 base + 0.01 per 500 prestige (capped at 2.0x)
	bonus.experience_multiplier = min(
		1.0 + (prestige_amount / 500) * 0.01,
		bonus_caps["experience_multiplier"]
	)

	# Trait inheritance boost: +5% per milestone completed (capped at +50%)
	bonus.trait_inheritance_boost = min(
		milestone_count * 0.05,
		bonus_caps["trait_inheritance_boost"]
	)

	succession_bonuses[heir_id] = bonus
	successor_prepared.emit(heir_id, _bonus_to_dict(bonus))
	return bonus


func get_bonus_for_heir(heir_id: String) -> SuccessionBonus:
	return succession_bonuses.get(heir_id)


func apply_bonus_to_heir(heir_id: String, heir_stats: Dictionary) -> Dictionary:
	var bonus = succession_bonuses.get(heir_id)
	if not bonus:
		return heir_stats

	var updated_stats = heir_stats.duplicate()

	if bonus.starting_level > 0:
		updated_stats["level"] = updated_stats.get("level", 1) + bonus.starting_level
		bonus_applied.emit(heir_id, "starting_level", bonus.starting_level)

	for stat in bonus.stat_bonuses.keys():
		var amount = bonus.stat_bonuses[stat]
		if amount > 0:
			updated_stats[stat] = updated_stats.get(stat, 0) + amount
			bonus_applied.emit(heir_id, stat, amount)

	if bonus.starting_gold > 0:
		updated_stats["gold"] = updated_stats.get("gold", 0) + bonus.starting_gold
		bonus_applied.emit(heir_id, "gold", bonus.starting_gold)

	if bonus.starting_supplies > 0:
		updated_stats["supplies"] = updated_stats.get("supplies", 0) + bonus.starting_supplies
		bonus_applied.emit(heir_id, "supplies", bonus.starting_supplies)

	if bonus.skill_points > 0:
		updated_stats["skill_points"] = updated_stats.get("skill_points", 0) + bonus.skill_points
		bonus_applied.emit(heir_id, "skill_points", bonus.skill_points)

	updated_stats["experience_multiplier"] = bonus.experience_multiplier

	return updated_stats


func get_succession_bonus_summary(heir_id: String) -> String:
	var bonus = succession_bonuses.get(heir_id)
	if not bonus:
		return "No succession bonuses available."

	var summary = "Successor Bonuses (Prestige: %d):\n" % bonus.prestige_level
	summary += "- Starting Level: +%d\n" % bonus.starting_level
	summary += "- Starting Gold: +%d\n" % bonus.starting_gold
	summary += "- Skill Points: +%d\n" % bonus.skill_points
	summary += "- Experience Multiplier: %.2fx\n" % bonus.experience_multiplier
	summary += "- Trait Inheritance: +%.0f%%\n" % (bonus.trait_inheritance_boost * 100)

	return summary


func get_succession_stats() -> Dictionary:
	var stats = {
		"total_heirs_prepared": succession_bonuses.size(),
		"average_prestige": 0,
		"by_bonus_type": {},
		"cap_status": {}
	}

	if succession_bonuses.size() > 0:
		var total = 0
		for bonus in succession_bonuses.values():
			total += bonus.prestige_level
		stats["average_prestige"] = total / succession_bonuses.size()

	var bonus_totals = {}
	for bonus in succession_bonuses.values():
		bonus_totals["starting_level"] = bonus_totals.get("starting_level", 0) + bonus.starting_level
		bonus_totals["starting_gold"] = bonus_totals.get("starting_gold", 0) + bonus.starting_gold
		bonus_totals["skill_points"] = bonus_totals.get("skill_points", 0) + bonus.skill_points

	stats["by_bonus_type"] = bonus_totals

	for cap_type in bonus_caps.keys():
		var count = 0
		for bonus in succession_bonuses.values():
			match cap_type:
				"starting_level":
					if bonus.starting_level == bonus_caps[cap_type]:
						count += 1
				"skill_points":
					if bonus.skill_points == bonus_caps[cap_type]:
						count += 1
		if count > 0:
			stats["cap_status"][cap_type] = count

	return stats


func reset_succession_bonuses() -> void:
	succession_bonuses.clear()


func _bonus_to_dict(bonus: SuccessionBonus) -> Dictionary:
	return {
		"heir_id": bonus.heir_id,
		"prestige_level": bonus.prestige_level,
		"starting_level": bonus.starting_level,
		"stat_bonuses": bonus.stat_bonuses.duplicate(),
		"starting_gold": bonus.starting_gold,
		"starting_supplies": bonus.starting_supplies,
		"skill_points": bonus.skill_points,
		"legendary_slots": bonus.legendary_slots,
		"experience_multiplier": bonus.experience_multiplier,
		"trait_inheritance_boost": bonus.trait_inheritance_boost
	}
