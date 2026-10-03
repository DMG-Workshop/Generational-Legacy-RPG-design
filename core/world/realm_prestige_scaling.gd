## Realm Prestige Scaling: Scale realm challenges by prestige tier
##
## Manages realm difficulty, resource scaling, and prestige-based realm bonuses

extends Node

class_name RealmPrestigeScaling


signal realm_unlocked(realm_id: String, prestige_tier: int)
signal realm_challenge_scaled(realm_id: String, difficulty: float)
signal realm_bonus_applied(realm_id: String, bonus_type: String)


var realms: Dictionary = {}
var realm_prestige_locks: Dictionary = {}
var realm_scaling_multipliers: Dictionary = {}


class Realm:
	var realm_id: String
	var realm_name: String
	var min_prestige_to_access: int
	var prestige_tier_unlocked: int
	var base_difficulty: float
	var resource_multiplier: float
	var creature_level_boost: int
	var rare_encounter_rate: float
	var special_events_available: Array
	var time_multiplier: float

	func _init(p_id: String, p_name: String, p_min_prestige: int, p_tier: int) -> void:
		realm_id = p_id
		realm_name = p_name
		min_prestige_to_access = p_min_prestige
		prestige_tier_unlocked = p_tier
		base_difficulty = 1.0 + (p_tier * 0.3)
		resource_multiplier = 1.0 + (p_tier * 0.2)
		creature_level_boost = p_tier * 5
		rare_encounter_rate = 0.05 + (p_tier * 0.05)
		special_events_available = []
		time_multiplier = 1.0 + (p_tier * 0.1)


class RealmChallenge:
	var realm_id: String
	var challenge_type: String
	var base_difficulty: float
	var prestige_scaling: float
	var completion_reward: int
	var completion_prestige_reward: int

	func _init(p_realm_id: String, p_type: String, p_base_diff: float) -> void:
		realm_id = p_realm_id
		challenge_type = p_type
		base_difficulty = p_base_diff
		prestige_scaling = 1.0
		completion_reward = 100
		completion_prestige_reward = 50


func _init() -> void:
	_initialize_realms()
	_initialize_realm_scaling()


func create_realm(realm_id: String, realm_name: String, min_prestige: int, tier: int) -> Realm:
	var realm = Realm.new(realm_id, realm_name, min_prestige, tier)
	realms[realm_id] = realm
	realm_unlocked.emit(realm_id, tier)
	return realm


func is_realm_unlocked(realm_id: String, prestige_amount: int) -> bool:
	if not realms.has(realm_id):
		return false

	var realm = realms[realm_id]
	return prestige_amount >= realm.min_prestige_to_access


func get_accessible_realms(prestige_amount: int) -> Array:
	var accessible = []

	for realm in realms.values():
		if is_realm_unlocked(realm.realm_id, prestige_amount):
			accessible.append(realm.realm_id)

	return accessible


func calculate_realm_difficulty(realm_id: String, prestige_amount: int) -> float:
	if not realms.has(realm_id):
		return 1.0

	var realm = realms[realm_id]
	if not is_realm_unlocked(realm_id, prestige_amount):
		return 0.0  # Not accessible

	# Base difficulty + scaling from prestige
	var prestige_above_requirement = prestige_amount - realm.min_prestige_to_access
	var scaling = 1.0 + (prestige_above_requirement / 5000.0) * 0.2
	scaling = clamp(scaling, 1.0, 2.5)

	return realm.base_difficulty * scaling


func calculate_realm_creature_level(realm_id: String, prestige_amount: int, base_level: int) -> int:
	if not realms.has(realm_id):
		return base_level

	var realm = realms[realm_id]
	var prestige_tiers = prestige_amount / 5000
	var bonus_level = int(realm.creature_level_boost + prestige_tiers)

	return base_level + bonus_level


func get_realm_resource_multiplier(realm_id: String, prestige_amount: int) -> float:
	if not realms.has(realm_id):
		return 1.0

	var realm = realms[realm_id]
	var prestige_tiers = prestige_amount / 5000
	var multiplier = realm.resource_multiplier + (prestige_tiers * 0.1)

	return clamp(multiplier, 1.0, 3.0)


func calculate_rare_encounter_rate(realm_id: String, prestige_amount: int) -> float:
	if not realms.has(realm_id):
		return 0.0

	var realm = realms[realm_id]
	var prestige_tiers = prestige_amount / 5000
	var rate = realm.rare_encounter_rate + (prestige_tiers * 0.05)

	return clamp(rate, 0.0, 0.5)


func get_realm_time_multiplier(realm_id: String) -> float:
	if not realms.has(realm_id):
		return 1.0

	return realms[realm_id].time_multiplier


func calculate_realm_challenge_reward(challenge: RealmChallenge, prestige_amount: int) -> Dictionary:
	var difficulty = calculate_realm_difficulty(challenge.realm_id, prestige_amount)

	var reward = {
		"gold": int(challenge.completion_reward * difficulty),
		"prestige": int(challenge.completion_prestige_reward * difficulty),
		"experience": int(challenge.completion_reward * difficulty * 1.5),
		"rare_drop_chance": calculate_rare_encounter_rate(challenge.realm_id, prestige_amount)
	}

	return reward


func unlock_special_realm_event(realm_id: String, prestige_tier: int) -> void:
	if not realms.has(realm_id):
		return

	var realm = realms[realm_id]
	var event_name = ""

	match prestige_tier:
		1:
			event_name = "Silver Storm"
		2:
			event_name = "Golden Fortune"
		3:
			event_name = "Platinum Trials"
		4:
			event_name = "Diamond Convergence"
		5:
			event_name = "Eternal Ascension"

	if event_name != "" and event_name not in realm.special_events_available:
		realm.special_events_available.append(event_name)
		realm_bonus_applied.emit(realm_id, event_name)


func get_realm_description(realm_id: String, prestige_amount: int) -> String:
	if not realms.has(realm_id):
		return "Unknown realm."

	var realm = realms[realm_id]

	if not is_realm_unlocked(realm_id, prestige_amount):
		return "Realm '%s' locked. Requires %d prestige." % [realm.realm_name, realm.min_prestige_to_access]

	var difficulty = calculate_realm_difficulty(realm_id, prestige_amount)
	var resource_mult = get_realm_resource_multiplier(realm_id, prestige_amount)
	var rare_rate = calculate_rare_encounter_rate(realm_id, prestige_amount)

	var desc = "Realm: %s\n" % realm.realm_name
	desc += "- Difficulty: %.2fx\n" % difficulty
	desc += "- Resource Multiplier: %.2fx\n" % resource_mult
	desc += "- Time Multiplier: %.2fx\n" % realm.time_multiplier
	desc += "- Rare Encounter Rate: %.1f%%\n" % (rare_rate * 100)
	desc += "- Creature Level Boost: +%d\n" % realm.creature_level_boost

	if realm.special_events_available.size() > 0:
		desc += "- Special Events:\n"
		for event in realm.special_events_available:
			desc += "  * %s\n" % event

	return desc


func get_realm_stats() -> Dictionary:
	var stats = {
		"total_realms": realms.size(),
		"avg_difficulty": 0.0,
		"max_time_multiplier": 0.0,
		"total_special_events": 0
	}

	var total_difficulty = 0.0
	var max_time = 0.0
	var event_count = 0

	for realm in realms.values():
		total_difficulty += realm.base_difficulty
		max_time = max(max_time, realm.time_multiplier)
		event_count += realm.special_events_available.size()

	if realms.size() > 0:
		stats["avg_difficulty"] = total_difficulty / realms.size()

	stats["max_time_multiplier"] = max_time
	stats["total_special_events"] = event_count

	return stats


func _initialize_realms() -> void:
	create_realm("starter_lands", "Starter Lands", 0, 0)
	create_realm("silver_reach", "Silver Reach", 1000, 1)
	create_realm("golden_expanse", "Golden Expanse", 5000, 2)
	create_realm("platinum_peaks", "Platinum Peaks", 15000, 3)
	create_realm("diamond_wastes", "Diamond Wastes", 35000, 4)
	create_realm("eternal_abyss", "Eternal Abyss", 75000, 5)


func _initialize_realm_scaling() -> void:
	realm_scaling_multipliers = {
		0: 1.0,    # Bronze realm
		1: 1.05,   # Silver realm
		2: 1.1,    # Gold realm
		3: 1.15,   # Platinum realm
		4: 1.2,    # Diamond realm
		5: 1.25    # Eternal realm
	}
