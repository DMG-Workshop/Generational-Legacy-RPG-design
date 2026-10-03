## Prestige Combat Tracker: Track combat performance with prestige effects
##
## Records combat statistics influenced by prestige multipliers and bonuses

extends Node

class_name PrestigeCombatTracker


signal combat_recorded(heir_id: String, victory: bool, prestige_gain: int)
signal combat_stats_updated(heir_id: String, stat_type: String, value: int)
signal prestige_bonus_earned(heir_id: String, bonus_amount: int, reason: String)


var combat_records: Dictionary = {}
var heir_combat_stats: Dictionary = {}
var prestige_bonuses_from_combat: Dictionary = {}


class CombatRecord:
	var heir_id: String
	var enemy_id: String
	var enemy_level: int
	var player_level: int
	var victory: bool
	var damage_dealt: int
	var damage_taken: int
	var turns_taken: int
	var critical_hits: int
	var prestige_multiplier: float
	var base_reward: int
	var prestige_gained: int
	var timestamp: int

	func _init(p_heir_id: String, p_enemy_id: String) -> void:
		heir_id = p_heir_id
		enemy_id = p_enemy_id
		enemy_level = 1
		player_level = 1
		victory = false
		damage_dealt = 0
		damage_taken = 0
		turns_taken = 0
		critical_hits = 0
		prestige_multiplier = 1.0
		base_reward = 0
		prestige_gained = 0
		timestamp = 0


class HeirCombatStats:
	var heir_id: String
	var total_combats: int
	var victories: int
	var defeats: int
	var total_damage_dealt: int
	var total_damage_taken: int
	var critical_hits_landed: int
	var average_combat_turns: float
	var prestige_earned_from_combat: int
	var win_rate: float

	func _init(p_heir_id: String) -> void:
		heir_id = p_heir_id
		total_combats = 0
		victories = 0
		defeats = 0
		total_damage_dealt = 0
		total_damage_taken = 0
		critical_hits_landed = 0
		average_combat_turns = 0.0
		prestige_earned_from_combat = 0
		win_rate = 0.0


func _init() -> void:
	combat_records = {}
	heir_combat_stats = {}
	prestige_bonuses_from_combat = {}


func record_combat(heir_id: String, enemy_id: String, enemy_level: int, player_level: int,
                   victory: bool, damage_dealt: int, damage_taken: int, turns_taken: int,
                   critical_hits: int, prestige_multiplier: float, base_reward: int) -> CombatRecord:
	var record = CombatRecord.new(heir_id, enemy_id)
	record.enemy_level = enemy_level
	record.player_level = player_level
	record.victory = victory
	record.damage_dealt = damage_dealt
	record.damage_taken = damage_taken
	record.turns_taken = turns_taken
	record.critical_hits = critical_hits
	record.prestige_multiplier = prestige_multiplier
	record.base_reward = base_reward

	# Calculate prestige gained from victory
	if victory:
		var prestige_gain = _calculate_prestige_from_combat(enemy_level, player_level, damage_dealt, prestige_multiplier)
		record.prestige_gained = prestige_gain
		prestige_bonus_earned.emit(heir_id, prestige_gain, "Combat Victory")

	record.timestamp = int(Time.get_ticks_msec())

	var record_id = "%s_%s_%d" % [heir_id, enemy_id, record.timestamp]
	combat_records[record_id] = record

	_update_heir_stats(heir_id, record)
	combat_recorded.emit(heir_id, victory, record.prestige_gained)

	return record


func get_combat_record(record_id: String) -> CombatRecord:
	return combat_records.get(record_id)


func get_heir_combat_stats(heir_id: String) -> HeirCombatStats:
	if not heir_combat_stats.has(heir_id):
		heir_combat_stats[heir_id] = HeirCombatStats.new(heir_id)

	return heir_combat_stats[heir_id]


func get_heir_combats(heir_id: String) -> Array:
	var records = []
	for record in combat_records.values():
		if record.heir_id == heir_id:
			records.append(record)

	return records


func calculate_combat_prestige_multiplier(base_prestige: int, prestige_modifier: float) -> int:
	return int(base_prestige * prestige_modifier)


func get_combat_efficiency_rating(heir_id: String) -> float:
	var stats = get_heir_combat_stats(heir_id)

	if stats.total_combats == 0:
		return 0.0

	# Efficiency = (wins / total_combats) * (damage_dealt / damage_taken)
	var win_ratio = float(stats.victories) / float(stats.total_combats)
	var damage_ratio = 1.0

	if stats.total_damage_taken > 0:
		damage_ratio = float(stats.total_damage_dealt) / float(stats.total_damage_taken)

	return win_ratio * damage_ratio


func get_prestige_earned_summary(heir_id: String) -> Dictionary:
	var summary = {
		"heir_id": heir_id,
		"total_prestige": 0,
		"combat_prestige": 0,
		"by_enemy_type": {},
		"prestige_per_combat": 0.0
	}

	var heir_records = get_heir_combats(heir_id)

	if heir_records.size() == 0:
		return summary

	for record in heir_records:
		summary["total_prestige"] += record.prestige_gained
		summary["combat_prestige"] += record.prestige_gained

		var enemy_type = record.enemy_id.split("_")[0]
		if not summary["by_enemy_type"].has(enemy_type):
			summary["by_enemy_type"][enemy_type] = 0
		summary["by_enemy_type"][enemy_type] += record.prestige_gained

	summary["prestige_per_combat"] = float(summary["total_prestige"]) / float(heir_records.size())

	return summary


func get_combat_performance_vs_level(heir_id: String, enemy_level: int) -> Dictionary:
	var heir_records = get_heir_combats(heir_id)
	var relevant_combats = []

	for record in heir_records:
		if abs(record.enemy_level - enemy_level) <= 5:  # Within 5 levels
			relevant_combats.append(record)

	var performance = {
		"level": enemy_level,
		"combats": relevant_combats.size(),
		"wins": 0,
		"average_turns": 0.0,
		"average_damage_dealt": 0,
		"average_damage_taken": 0,
		"critical_hit_rate": 0.0
	}

	if relevant_combats.size() == 0:
		return performance

	var total_turns = 0
	var total_damage_dealt = 0
	var total_damage_taken = 0
	var total_crits = 0

	for record in relevant_combats:
		if record.victory:
			performance["wins"] += 1
		total_turns += record.turns_taken
		total_damage_dealt += record.damage_dealt
		total_damage_taken += record.damage_taken
		total_crits += record.critical_hits

	performance["average_turns"] = float(total_turns) / float(relevant_combats.size())
	performance["average_damage_dealt"] = total_damage_dealt / relevant_combats.size()
	performance["average_damage_taken"] = total_damage_taken / relevant_combats.size()

	var total_attacks = performance["average_turns"] * relevant_combats.size()
	if total_attacks > 0:
		performance["critical_hit_rate"] = float(total_crits) / total_attacks

	return performance


func get_combat_tracker_stats() -> Dictionary:
	var stats = {
		"total_combats": combat_records.size(),
		"heirs_with_combats": heir_combat_stats.size(),
		"total_victories": 0,
		"total_defeats": 0,
		"total_prestige_from_combat": 0,
		"average_prestige_per_combat": 0.0
	}

	for heir_stats in heir_combat_stats.values():
		stats["total_victories"] += heir_stats.victories
		stats["total_defeats"] += heir_stats.defeats
		stats["total_prestige_from_combat"] += heir_stats.prestige_earned_from_combat

	if combat_records.size() > 0:
		stats["average_prestige_per_combat"] = float(stats["total_prestige_from_combat"]) / float(combat_records.size())

	return stats


func export_combat_history(heir_id: String) -> Array:
	var history = []

	for record in get_heir_combats(heir_id):
		history.append({
			"enemy_id": record.enemy_id,
			"enemy_level": record.enemy_level,
			"player_level": record.player_level,
			"victory": record.victory,
			"damage_dealt": record.damage_dealt,
			"damage_taken": record.damage_taken,
			"turns": record.turns_taken,
			"critical_hits": record.critical_hits,
			"prestige_multiplier": record.prestige_multiplier,
			"prestige_gained": record.prestige_gained
		})

	return history


func _calculate_prestige_from_combat(enemy_level: int, player_level: int, damage_dealt: int, prestige_multiplier: float) -> int:
	# Base prestige: 100 + (10 * enemy_level)
	var base_prestige = 100 + (enemy_level * 10)

	# Level advantage/disadvantage
	var level_diff = enemy_level - player_level
	if level_diff > 0:
		base_prestige = int(base_prestige * (1.0 + (level_diff * 0.1)))

	# Apply prestige multiplier
	var final_prestige = int(base_prestige * prestige_multiplier)

	return final_prestige


func _update_heir_stats(heir_id: String, record: CombatRecord) -> void:
	if not heir_combat_stats.has(heir_id):
		heir_combat_stats[heir_id] = HeirCombatStats.new(heir_id)

	var stats = heir_combat_stats[heir_id]
	stats.total_combats += 1

	if record.victory:
		stats.victories += 1
	else:
		stats.defeats += 1

	stats.total_damage_dealt += record.damage_dealt
	stats.total_damage_taken += record.damage_taken
	stats.critical_hits_landed += record.critical_hits
	stats.prestige_earned_from_combat += record.prestige_gained

	if stats.total_combats > 0:
		stats.average_combat_turns = float(stats.total_damage_dealt) / float(stats.total_combats)
		stats.win_rate = float(stats.victories) / float(stats.total_combats)

	combat_stats_updated.emit(heir_id, "total_combats", stats.total_combats)
