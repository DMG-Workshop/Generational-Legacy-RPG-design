## Achievement System: Track accomplishments and grant unlock bonuses
##
## Manages achievement definitions, player progress, and tier-based rewards

extends Node

class_name AchievementSystem


signal achievement_unlocked(achievement_id: String, heir_id: String)
signal achievement_milestone_reached(milestone: String, count: int)


enum AchievementType { COMBAT, EXPLORATION, ECONOMIC, FAMILY, FACTION, WORLD }
enum AchievementTier { BRONZE, SILVER, GOLD, PLATINUM, LEGENDARY }


var achievements: Dictionary = {}
var heir_achievements: Dictionary = {}
var generation_achievements: Dictionary = {}


class Achievement:
	var id: String
	var name: String
	var description: String
	var type: int
	var requirement: Dictionary
	var reward_prestige: int
	var tier: int
	var icon: String
	var unlock_count: int = 0

	func _init(p_id: String, p_name: String, p_type: int, p_requirement: Dictionary, p_prestige: int, p_tier: int = 0) -> void:
		id = p_id
		name = p_name
		type = p_type
		requirement = p_requirement
		reward_prestige = p_prestige
		tier = p_tier
		icon = ""


func _init() -> void:
	achievements = {}
	heir_achievements = {}
	generation_achievements = {}
	_initialize_default_achievements()


func _initialize_default_achievements() -> void:
	# Combat achievements
	create_achievement(
		"first_victory",
		"First Blood",
		AchievementType.COMBAT,
		{"battles_won": 1},
		50,
		AchievementTier.BRONZE
	)
	create_achievement(
		"battle_master",
		"Battle Master",
		AchievementType.COMBAT,
		{"battles_won": 50},
		200,
		AchievementTier.GOLD
	)
	create_achievement(
		"unstoppable",
		"Unstoppable Force",
		AchievementType.COMBAT,
		{"battles_won": 100},
		500,
		AchievementTier.PLATINUM
	)
	create_achievement(
		"first_boss_defeat",
		"Boss Slayer",
		AchievementType.COMBAT,
		{"bosses_defeated": 1},
		300,
		AchievementTier.SILVER
	)
	create_achievement(
		"all_bosses_defeated",
		"Legendary Monster Hunter",
		AchievementType.COMBAT,
		{"all_bosses_defeated": true},
		1000,
		AchievementTier.LEGENDARY
	)

	# Exploration achievements
	create_achievement(
		"first_settlement",
		"Welcome to Civilization",
		AchievementType.EXPLORATION,
		{"settlements_visited": 1},
		50,
		AchievementTier.BRONZE
	)
	create_achievement(
		"explorer",
		"Explorer",
		AchievementType.EXPLORATION,
		{"settlements_visited": 20},
		200,
		AchievementTier.SILVER
	)
	create_achievement(
		"cartographer",
		"Cartographer",
		AchievementType.EXPLORATION,
		{"settlements_visited": 50},
		400,
		AchievementTier.GOLD
	)
	create_achievement(
		"anomaly_survivor",
		"Anomaly Survivor",
		AchievementType.EXPLORATION,
		{"anomalies_survived": 3},
		250,
		AchievementTier.SILVER
	)

	# Economic achievements
	create_achievement(
		"first_trade",
		"First Trade",
		AchievementType.ECONOMIC,
		{"trades_completed": 1},
		50,
		AchievementTier.BRONZE
	)
	create_achievement(
		"merchant",
		"Merchant",
		AchievementType.ECONOMIC,
		{"total_gold_earned": 5000},
		200,
		AchievementTier.GOLD
	)
	create_achievement(
		"tycoon",
		"Tycoon",
		AchievementType.ECONOMIC,
		{"total_gold_earned": 50000},
		600,
		AchievementTier.PLATINUM
	)
	create_achievement(
		"richest_heir",
		"Richest Heir",
		AchievementType.ECONOMIC,
		{"max_gold_held": 10000},
		400,
		AchievementTier.GOLD
	)

	# Family achievements
	create_achievement(
		"founder",
		"Founder",
		AchievementType.FAMILY,
		{"generation": 1},
		100,
		AchievementTier.SILVER
	)
	create_achievement(
		"dynasty_of_ten",
		"Dynasty of Ten",
		AchievementType.FAMILY,
		{"generation": 10},
		250,
		AchievementTier.GOLD
	)
	create_achievement(
		"century_dynasty",
		"Century Dynasty",
		AchievementType.FAMILY,
		{"generation": 100},
		1000,
		AchievementTier.PLATINUM
	)
	create_achievement(
		"married",
		"Married",
		AchievementType.FAMILY,
		{"heirs_married": 1},
		150,
		AchievementTier.BRONZE
	)
	create_achievement(
		"legacy_echo",
		"Legacy Echo",
		AchievementType.FAMILY,
		{"legacy_echoes_triggered": 5},
		300,
		AchievementTier.GOLD
	)

	# Faction achievements
	create_achievement(
		"faction_ally",
		"Faction Ally",
		AchievementType.FACTION,
		{"faction_standing": 50},
		200,
		AchievementTier.SILVER
	)
	create_achievement(
		"faction_hero",
		"Faction Hero",
		AchievementType.FACTION,
		{"faction_standing": 100},
		500,
		AchievementTier.GOLD
	)
	create_achievement(
		"multi_faction_ally",
		"Diplomat",
		AchievementType.FACTION,
		{"allied_factions": 3},
		400,
		AchievementTier.GOLD
	)
	create_achievement(
		"war_veteran",
		"War Veteran",
		AchievementType.FACTION,
		{"faction_wars_survived": 3},
		350,
		AchievementTier.GOLD
	)

	# World achievements
	create_achievement(
		"first_disaster_survived",
		"Survivor",
		AchievementType.WORLD,
		{"disasters_survived": 1},
		150,
		AchievementTier.BRONZE
	)
	create_achievement(
		"disaster_resister",
		"Disaster Resister",
		AchievementType.WORLD,
		{"disasters_survived": 10},
		400,
		AchievementTier.GOLD
	)
	create_achievement(
		"blessed_by_gods",
		"Blessed by Gods",
		AchievementType.WORLD,
		{"blessing_zones_entered": 5},
		300,
		AchievementTier.SILVER
	)


func create_achievement(p_id: String, p_name: String, p_type: int, p_requirement: Dictionary, p_prestige: int, p_tier: int = 0) -> void:
	var achievement = Achievement.new(p_id, p_name, p_type, p_requirement, p_prestige, p_tier)
	achievements[p_id] = achievement


func unlock_achievement(achievement_id: String, heir_id: String, generation: int) -> bool:
	var achievement = achievements.get(achievement_id)
	if not achievement:
		return false

	if not heir_achievements.has(heir_id):
		heir_achievements[heir_id] = []
	if achievement_id in heir_achievements[heir_id]:
		return false

	heir_achievements[heir_id].append(achievement_id)
	achievement.unlock_count += 1

	if not generation_achievements.has(generation):
		generation_achievements[generation] = []
	generation_achievements[generation].append(achievement_id)

	achievement_unlocked.emit(achievement_id, heir_id)

	if achievement.unlock_count % 10 == 0:
		achievement_milestone_reached.emit(achievement_id, achievement.unlock_count)

	return true


func get_achievement(achievement_id: String) -> Achievement:
	return achievements.get(achievement_id)


func get_achievements_by_type(achievement_type: int) -> Array:
	var result = []
	for achievement in achievements.values():
		if achievement.type == achievement_type:
			result.append(achievement)
	return result


func get_achievements_by_tier(tier: int) -> Array:
	var result = []
	for achievement in achievements.values():
		if achievement.tier == tier:
			result.append(achievement)
	return result


func get_heir_achievements(heir_id: String) -> Array:
	return heir_achievements.get(heir_id, [])


func get_generation_achievements(generation: int) -> Array:
	return generation_achievements.get(generation, [])


func has_achievement(heir_id: String, achievement_id: String) -> bool:
	return achievement_id in heir_achievements.get(heir_id, [])


func get_total_prestige_from_achievements(heir_id: String) -> int:
	var total = 0
	for achievement_id in get_heir_achievements(heir_id):
		var achievement = achievements.get(achievement_id)
		if achievement:
			total += achievement.reward_prestige
	return total


func get_achievement_stats() -> Dictionary:
	var stats = {
		"total_achievements": achievements.size(),
		"total_unlocks": 0,
		"by_tier": {},
		"by_type": {},
		"most_common": ""
	}

	var max_unlocks = 0
	var most_common_id = ""

	for achievement in achievements.values():
		stats["total_unlocks"] += achievement.unlock_count

		var tier_name = AchievementTier.keys()[achievement.tier]
		if not stats["by_tier"].has(tier_name):
			stats["by_tier"][tier_name] = 0
		stats["by_tier"][tier_name] += achievement.unlock_count

		var type_name = AchievementType.keys()[achievement.type]
		if not stats["by_type"].has(type_name):
			stats["by_type"][type_name] = 0
		stats["by_type"][type_name] += achievement.unlock_count

		if achievement.unlock_count > max_unlocks:
			max_unlocks = achievement.unlock_count
			most_common_id = achievement.id

	stats["most_common"] = most_common_id

	return stats
