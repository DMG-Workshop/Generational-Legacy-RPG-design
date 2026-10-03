## Combat Encounter Manager: Orchestrate battles from world encounters
##
## Manages the flow of world encounters into the battle system
## Handles difficulty scaling, enemy composition, and reward application

class_name CombatEncounterManager


signal encounter_started(encounter_id: String, battle_type: String)
signal encounter_victory(encounter_id: String, rewards: Dictionary)
signal encounter_defeat(encounter_id: String, heir_name: String)
signal boss_battle_started(boss_name: String)
signal boss_defeated(boss_name: String, heir_name: String)


var encounter_system: EncounterSystem
var boss_system: BossSystem

# Active battle encounters
var active_battles: Dictionary = {}  # encounter_id -> battle state


func _init(encounters: EncounterSystem, bosses: BossSystem) -> void:
	encounter_system = encounters
	boss_system = bosses


## Start random encounter battle
func start_encounter_battle(encounter_id: String, heir_name: String, heir_stats: Dictionary, settlement_name: String = "") -> Dictionary:
	if encounter_id not in encounter_system.active_encounters:
		return {}

	var encounter = encounter_system.get_encounter(encounter_id)
	if encounter.is_empty():
		return {}

	var battle_state = {
		"encounter_id": encounter_id,
		"heir_name": heir_name,
		"heir_stats": heir_stats.duplicate(),
		"heir_health": heir_stats.get("constitution", 10) * 5,
		"encounter_type": encounter["type_name"],
		"enemies": encounter["enemies"].duplicate(true),
		"difficulty": encounter["difficulty_name"],
		"round": 0,
		"victory": false,
		"started_at": Time.get_ticks_msec(),
		"settlement": settlement_name,
	}

	active_battles[encounter_id] = battle_state
	encounter_started.emit(encounter_id, encounter["type_name"])

	return battle_state


## Start boss battle
func start_boss_battle(boss_name: String, heir_name: String, heir_stats: Dictionary, settlement_name: String = "") -> Dictionary:
	var boss = boss_system.generate_boss_encounter(boss_name, heir_stats)
	if boss.is_empty():
		return {}

	var encounter_id = boss["encounter_id"]

	var battle_state = {
		"encounter_id": encounter_id,
		"heir_name": heir_name,
		"heir_stats": heir_stats.duplicate(),
		"heir_health": heir_stats.get("constitution", 10) * 5,
		"is_boss_battle": true,
		"boss_name": boss_name,
		"boss": boss,
		"difficulty": boss["tier_name"],
		"round": 0,
		"victory": false,
		"started_at": Time.get_ticks_msec(),
		"settlement": settlement_name,
	}

	active_battles[encounter_id] = battle_state
	boss_battle_started.emit(boss_name)

	return battle_state


## Resolve encounter battle (simulate or get results from actual battle)
func resolve_encounter_battle(encounter_id: String, heir_victory: bool) -> Dictionary:
	if encounter_id not in active_battles:
		return {}

	var battle = active_battles[encounter_id]
	battle["victory"] = heir_victory

	if heir_victory:
		var rewards = encounter_system.roll_loot(encounter_id)
		encounter_victory.emit(encounter_id, rewards)
		return rewards
	else:
		encounter_defeat.emit(encounter_id, battle["heir_name"])
		return {"gold": 0, "xp": 0, "items": []}


## Resolve boss battle
func resolve_boss_battle(encounter_id: String, boss_name: String, heir_victory: bool, heir_name: String) -> Dictionary:
	if encounter_id not in active_battles:
		return {}

	var battle = active_battles[encounter_id]
	battle["victory"] = heir_victory

	if heir_victory:
		var rewards = boss_system.defeat_boss(boss_name, heir_name)
		boss_defeated.emit(boss_name, heir_name)
		encounter_victory.emit(encounter_id, rewards)
		return rewards
	else:
		encounter_defeat.emit(encounter_id, heir_name)
		return {"gold": 0, "xp": 0, "items": []}


## Get active battle
func get_active_battle(encounter_id: String) -> Dictionary:
	return active_battles.get(encounter_id, {})


## Get battle summary
func get_battle_summary(encounter_id: String) -> Dictionary:
	if encounter_id not in active_battles:
		return {}

	var battle = active_battles[encounter_id]
	var duration = (Time.get_ticks_msec() - battle["started_at"]) / 1000.0

	var summary = {
		"encounter_id": encounter_id,
		"heir": battle["heir_name"],
		"type": battle.get("encounter_type", "Boss Battle"),
		"difficulty": battle["difficulty"],
		"victory": battle["victory"],
		"rounds": battle["round"],
		"duration_seconds": duration,
	}

	if "boss_name" in battle:
		summary["boss"] = battle["boss_name"]

	return summary


## Remove encounter after resolution
func clear_encounter(encounter_id: String) -> void:
	if encounter_id in encounter_system.active_encounters:
		encounter_system.complete_encounter(encounter_id)
	if encounter_id in active_battles:
		active_battles.erase(encounter_id)


## Get encounter difficulty for heir
func get_encounter_difficulty_rating(encounter_id: String, heir_stats: Dictionary) -> String:
	if encounter_id not in encounter_system.active_encounters:
		return "Unknown"

	var encounter = encounter_system.get_encounter(encounter_id)
	var difficulty = encounter["difficulty"]

	# Compare to heir power
	var heir_power = _calculate_heir_power(heir_stats)
	var difficulty_multiplier = [1.0, 1.3, 1.7, 2.2, 2.8][difficulty]

	var power_ratio = heir_power / (15.0 * difficulty_multiplier)

	if power_ratio < 0.5:
		return "Impossible"
	elif power_ratio < 0.8:
		return "Very Difficult"
	elif power_ratio < 1.0:
		return "Difficult"
	elif power_ratio < 1.3:
		return "Challenging"
	elif power_ratio < 1.6:
		return "Fair"
	else:
		return "Easy"


## Calculate expected encounter rewards
func get_expected_rewards(encounter_id: String) -> Dictionary:
	if encounter_id not in encounter_system.active_encounters:
		return {}

	var encounter = encounter_system.get_encounter(encounter_id)
	var gold_avg = (encounter["gold_range"][0] + encounter["gold_range"][1]) / 2.0
	var xp_avg = (encounter["xp_range"][0] + encounter["xp_range"][1]) / 2.0

	return {
		"gold": int(gold_avg),
		"xp": int(xp_avg),
		"item_chance": encounter["loot_chance"],
		"rarity": encounter["rarity"],
	}


## Get boss battle difficulty
func get_boss_difficulty_rating(boss_name: String, heir_stats: Dictionary) -> String:
	return boss_system.get_boss_difficulty_rating(boss_name, heir_stats)


## Get boss information for UI
func get_boss_info(boss_name: String) -> Dictionary:
	return boss_system.get_boss_summary(boss_name)


## Internal: Calculate heir power
func _calculate_heir_power(stats: Dictionary) -> float:
	var sum = 0.0
	for stat_value in stats.values():
		sum += stat_value
	return sum / maxf(stats.size(), 1.0)
