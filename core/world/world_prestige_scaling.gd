## World Prestige Scaling: Scale world challenges by prestige tier
##
## Dynamically adjusts dungeon difficulty, world events, and realm challenges based on prestige

extends Node

class_name WorldPrestigeScaling


signal world_difficulty_updated(new_difficulty: float)
signal dungeon_unlocked(dungeon_id: String, tier: int)
signal realm_challenge_scaled(realm_id: String, challenge_level: int)
signal rare_encounter_chance_calculated(chance: float)


var prestige_to_difficulty: Dictionary = {
	0: 0.5,      # Bronze: 0.5x (trivial)
	1000: 1.0,   # Silver: 1.0x (normal)
	5000: 1.5,   # Gold: 1.5x (hard)
	15000: 2.0,  # Platinum: 2.0x (very hard)
	35000: 2.5,  # Diamond: 2.5x (extreme)
	75000: 3.0   # Eternal: 3.0x (nightmare)
}

var dungeon_tier_requirements: Dictionary = {
	"goblin_cave": 0,
	"forest_ruin": 500,
	"mountain_stronghold": 2500,
	"ancient_temple": 7500,
	"dragon_spire": 20000,
	"void_abyss": 60000,
	"eternal_citadel": 85000
}

var world_event_scaling_factor: float = 0.15  # 15% difficulty per prestige tier
var realm_scaling_factor: float = 0.2  # 20% difficulty per prestige tier
var rare_encounter_base_chance: float = 0.05  # 5% base chance
var rare_encounter_prestige_scaling: float = 0.001  # +0.1% per 100 prestige


class WorldDifficulty:
	var prestige_level: int
	var difficulty_multiplier: float
	var available_dungeons: Array
	var recommended_enemy_level: int
	var rare_encounter_chance: float
	var realm_challenge_level: int

	func _init(p_prestige: int) -> void:
		prestige_level = p_prestige
		difficulty_multiplier = 1.0
		available_dungeons = []
		recommended_enemy_level = 1
		rare_encounter_chance = 0.0
		realm_challenge_level = 0


func _init() -> void:
	pass


func calculate_world_difficulty(prestige_amount: int) -> WorldDifficulty:
	var difficulty = WorldDifficulty.new(prestige_amount)

	# Calculate difficulty multiplier from prestige
	difficulty.difficulty_multiplier = _get_difficulty_multiplier(prestige_amount)

	# Determine available dungeons
	for dungeon_id in dungeon_tier_requirements.keys():
		var requirement = dungeon_tier_requirements[dungeon_id]
		if prestige_amount >= requirement:
			difficulty.available_dungeons.append(dungeon_id)

	# Calculate recommended enemy level
	difficulty.recommended_enemy_level = _calculate_recommended_level(prestige_amount)

	# Calculate rare encounter chance
	difficulty.rare_encounter_chance = _calculate_rare_encounter_chance(prestige_amount)

	# Calculate realm challenge level
	difficulty.realm_challenge_level = _calculate_realm_challenge_level(prestige_amount)

	world_difficulty_updated.emit(difficulty.difficulty_multiplier)
	return difficulty


func get_dungeon_difficulty_scaling(dungeon_id: String, prestige_amount: int) -> float:
	if not dungeon_tier_requirements.has(dungeon_id):
		return 1.0

	var tier_requirement = dungeon_tier_requirements[dungeon_id]
	var prestige_above_requirement = max(0, prestige_amount - tier_requirement)

	# Base difficulty for dungeon tier + scaling from prestige above requirement
	var base_difficulty = 1.0
	if tier_requirement >= 20000:
		base_difficulty = 1.5
	elif tier_requirement >= 7500:
		base_difficulty = 1.25
	elif tier_requirement >= 2500:
		base_difficulty = 1.1

	# Prestige scaling above requirement
	var prestige_scaling = 1.0 + (prestige_above_requirement / 5000.0) * 0.2
	prestige_scaling = clamp(prestige_scaling, 1.0, 2.5)

	return base_difficulty * prestige_scaling


func is_dungeon_unlocked(dungeon_id: String, prestige_amount: int) -> bool:
	var requirement = dungeon_tier_requirements.get(dungeon_id, -1)
	if requirement == -1:
		return false

	return prestige_amount >= requirement


func get_dungeon_access_level(dungeon_id: String) -> int:
	# Returns which prestige tier unlocks this dungeon
	var requirement = dungeon_tier_requirements.get(dungeon_id, 0)

	var tier_names = [0, 1000, 5000, 15000, 35000, 75000]
	for i in range(tier_names.size()):
		if requirement == tier_names[i]:
			return i

	return 0


func get_available_dungeons(prestige_amount: int) -> Array:
	var available = []

	for dungeon_id in dungeon_tier_requirements.keys():
		if is_dungeon_unlocked(dungeon_id, prestige_amount):
			available.append(dungeon_id)

	return available


func calculate_world_event_difficulty(base_event_difficulty: float, prestige_amount: int) -> float:
	var prestige_tiers = prestige_amount / 5000
	var scaling = 1.0 + (prestige_tiers * world_event_scaling_factor)
	scaling = clamp(scaling, 1.0, 3.0)

	return base_event_difficulty * scaling


func calculate_realm_challenge_difficulty(base_challenge: float, prestige_amount: int) -> float:
	var prestige_tiers = prestige_amount / 5000
	var scaling = 1.0 + (prestige_tiers * realm_scaling_factor)
	scaling = clamp(scaling, 1.0, 3.0)

	return base_challenge * scaling


func get_world_prestige_description(difficulty: WorldDifficulty) -> String:
	var desc = "World Prestige Scaling (Prestige: %d):\n" % difficulty.prestige_level
	desc += "- Difficulty Multiplier: %.2fx\n" % difficulty.difficulty_multiplier
	desc += "- Recommended Enemy Level: %d\n" % difficulty.recommended_enemy_level
	desc += "- Rare Encounter Chance: %.1f%%\n" % (difficulty.rare_encounter_chance * 100)
	desc += "- Available Dungeons: %d\n" % difficulty.available_dungeons.size()
	desc += "- Realm Challenge Level: %d\n" % difficulty.realm_challenge_level

	return desc


func get_prestige_scaling_stats() -> Dictionary:
	var stats = {
		"total_dungeons": dungeon_tier_requirements.size(),
		"difficulty_tiers": prestige_to_difficulty.size(),
		"world_event_scaling_per_tier": world_event_scaling_factor,
		"realm_scaling_per_tier": realm_scaling_factor,
		"base_rare_encounter_chance": rare_encounter_base_chance,
		"max_difficulty_multiplier": 3.0
	}

	return stats


func calculate_prestige_milestone_rewards(prestige_tier: int) -> Dictionary:
	var rewards = {
		"dungeon_access": [],
		"exclusive_loot_pool": false,
		"rare_spawn_unlock": false,
		"special_event_unlock": false
	}

	match prestige_tier:
		0:
			rewards["dungeon_access"] = ["goblin_cave"]
		1:
			rewards["dungeon_access"] = ["goblin_cave", "forest_ruin"]
		2:
			rewards["dungeon_access"] = ["goblin_cave", "forest_ruin", "mountain_stronghold"]
			rewards["exclusive_loot_pool"] = true
		3:
			rewards["dungeon_access"] = ["goblin_cave", "forest_ruin", "mountain_stronghold", "ancient_temple"]
			rewards["rare_spawn_unlock"] = true
		4:
			rewards["dungeon_access"] = ["goblin_cave", "forest_ruin", "mountain_stronghold", "ancient_temple", "dragon_spire"]
			rewards["exclusive_loot_pool"] = true
			rewards["special_event_unlock"] = true
		5:
			rewards["dungeon_access"] = ["goblin_cave", "forest_ruin", "mountain_stronghold", "ancient_temple", "dragon_spire", "void_abyss", "eternal_citadel"]
			rewards["rare_spawn_unlock"] = true
			rewards["special_event_unlock"] = true

	return rewards


func _get_difficulty_multiplier(prestige_amount: int) -> float:
	var multiplier = 0.5

	for threshold in prestige_to_difficulty.keys():
		if prestige_amount >= threshold:
			multiplier = prestige_to_difficulty[threshold]

	return multiplier


func _calculate_recommended_level(prestige_amount: int) -> int:
	# Recommended level increases with prestige (1 per 2500 prestige)
	var base_level = 10
	var prestige_levels = prestige_amount / 2500

	return base_level + prestige_levels


func _calculate_rare_encounter_chance(prestige_amount: int) -> float:
	var chance = rare_encounter_base_chance + (prestige_amount / 100.0) * rare_encounter_prestige_scaling
	return clamp(chance, 0.0, 0.5)  # Cap at 50%


func _calculate_realm_challenge_level(prestige_amount: int) -> int:
	# Challenge level increases with prestige
	var base_level = 1
	var prestige_tiers = prestige_amount / 5000

	return base_level + prestige_tiers
