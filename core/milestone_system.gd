## Milestone System: Track major generational milestones and events
##
## Manages milestone triggering, rewards, and dynasty celebrations

extends Node

class_name MilestoneSystem


signal milestone_triggered(milestone_id: String, milestone_type: int)
signal milestone_reward_claimed(milestone_id: String, reward_type: String, amount: int)
signal generation_milestone_reached(generation: int)


enum MilestoneType { GENERATION_100, GENERATION_250, GENERATION_500, GENERATION_750, GENERATION_999 }


var milestones: Dictionary = {}
var completed_milestones: Array = []
var active_milestones: Array = []
var milestone_counter: int = 0
var milestone_generations: Dictionary = {
	MilestoneType.GENERATION_100: 100,
	MilestoneType.GENERATION_250: 250,
	MilestoneType.GENERATION_500: 500,
	MilestoneType.GENERATION_750: 750,
	MilestoneType.GENERATION_999: 999
}


class Milestone:
	var id: String
	var type: int
	var generation: int
	var triggered: bool
	var triggered_at_generation: int
	var rewards: Dictionary
	var description: String
	var dynasty_stats: Dictionary

	func _init(p_id: String, p_type: int, p_generation: int) -> void:
		id = p_id
		type = p_type
		generation = p_generation
		triggered = false
		triggered_at_generation = 0
		rewards = {}
		description = ""
		dynasty_stats = {}


func _init() -> void:
	milestones = {}
	completed_milestones = []
	active_milestones = []
	_initialize_milestones()


func _initialize_milestones() -> void:
	for milestone_type in milestone_generations.keys():
		var generation = milestone_generations[milestone_type]
		create_milestone(milestone_type, generation)


func create_milestone(milestone_type: int, generation: int) -> String:
	var milestone_id = "milestone_%d_%d" % [milestone_counter, randi()]
	milestone_counter += 1

	var milestone = Milestone.new(milestone_id, milestone_type, generation)
	milestone.description = _get_milestone_description(milestone_type, generation)
	milestone.rewards = _get_milestone_rewards(milestone_type)

	milestones[milestone_id] = milestone
	active_milestones.append(milestone_id)
	return milestone_id


func check_generation_milestone(current_generation: int, dynasty_stats: Dictionary = {}) -> String:
	for milestone_id in active_milestones:
		var milestone = milestones[milestone_id]
		if current_generation == milestone.generation and not milestone.triggered:
			return trigger_milestone(milestone_id, current_generation, dynasty_stats)

	return ""


func trigger_milestone(milestone_id: String, current_generation: int, dynasty_stats: Dictionary = {}) -> String:
	var milestone = milestones.get(milestone_id)
	if not milestone or milestone.triggered:
		return ""

	milestone.triggered = true
	milestone.triggered_at_generation = current_generation
	milestone.dynasty_stats = dynasty_stats.duplicate()

	active_milestones.erase(milestone_id)
	completed_milestones.append(milestone_id)

	milestone_triggered.emit(milestone_id, milestone.type)
	generation_milestone_reached.emit(current_generation)

	return milestone_id


func get_milestone(milestone_id: String) -> Milestone:
	return milestones.get(milestone_id)


func get_milestone_by_generation(generation: int) -> Milestone:
	for milestone in milestones.values():
		if milestone.generation == generation:
			return milestone
	return null


func get_milestone_rewards(milestone_id: String) -> Dictionary:
	var milestone = milestones.get(milestone_id)
	if not milestone:
		return {}

	return milestone.rewards.duplicate()


func claim_milestone_reward(milestone_id: String, reward_type: String) -> int:
	var milestone = milestones.get(milestone_id)
	if not milestone or not milestone.triggered:
		return 0

	var reward_amount = milestone.rewards.get(reward_type, 0)
	if reward_amount > 0:
		milestone_reward_claimed.emit(milestone_id, reward_type, reward_amount)

	return reward_amount


func get_completed_milestones() -> Array:
	var result = []
	for milestone_id in completed_milestones:
		result.append(milestones[milestone_id])
	return result


func get_active_milestones() -> Array:
	var result = []
	for milestone_id in active_milestones:
		result.append(milestones[milestone_id])
	return result


func get_milestones_by_type(milestone_type: int) -> Array:
	var result = []
	for milestone in milestones.values():
		if milestone.type == milestone_type:
			result.append(milestone)
	return result


func has_reached_milestone(generation: int) -> bool:
	for milestone in completed_milestones:
		if milestones[milestone].generation == generation:
			return true
	return false


func get_next_milestone(current_generation: int) -> Milestone:
	var nearest = null
	var nearest_distance = 9999

	for milestone in active_milestones:
		var m = milestones[milestone]
		var distance = m.generation - current_generation
		if distance > 0 and distance < nearest_distance:
			nearest = m
			nearest_distance = distance

	return nearest


func get_milestone_description(milestone_type: int) -> String:
	match milestone_type:
		MilestoneType.GENERATION_100:
			return "Century Dynasty: 100 generations of unbroken lineage"
		MilestoneType.GENERATION_250:
			return "Quarter Millennium: 250 generations shape the dynasty's fate"
		MilestoneType.GENERATION_500:
			return "Half Millennium: 500 generations of legend and legacy"
		MilestoneType.GENERATION_750:
			return "Three Quarters Reached: 750 generations echo through time"
		MilestoneType.GENERATION_999:
			return "The Final Generation: 999 generations of history culminate"
		_:
			return "Unknown Milestone"


func get_milestone_stats() -> Dictionary:
	var stats = {
		"total_milestones": milestones.size(),
		"completed": completed_milestones.size(),
		"active": active_milestones.size(),
		"total_rewards_available": 0,
		"by_type": {}
	}

	for milestone_id in milestones.keys():
		var milestone = milestones[milestone_id]
		var type_name = MilestoneType.keys()[milestone.type]

		if not stats["by_type"].has(type_name):
			stats["by_type"][type_name] = {"triggered": 0, "pending": 0}

		if milestone.triggered:
			stats["by_type"][type_name]["triggered"] += 1
		else:
			stats["by_type"][type_name]["pending"] += 1

		for reward in milestone.rewards.values():
			stats["total_rewards_available"] += reward

	return stats


func export_milestone_history() -> Dictionary:
	var history = {
		"milestones_reached": completed_milestones.size(),
		"timeline": [],
		"total_prestige_earned": 0,
		"total_stat_bonuses": 0,
		"legendary_items_received": 0
	}

	for milestone_id in completed_milestones:
		var milestone = milestones[milestone_id]
		history["timeline"].append({
			"generation": milestone.generation,
			"type": MilestoneType.keys()[milestone.type],
			"triggered_at": milestone.triggered_at_generation,
			"prestige_reward": milestone.rewards.get("prestige", 0)
		})

		history["total_prestige_earned"] += milestone.rewards.get("prestige", 0)
		history["total_stat_bonuses"] += milestone.rewards.get("stat_bonus", 0) * 6
		history["legendary_items_received"] += milestone.rewards.get("legendary_items", 0)

	return history


func _get_milestone_description(milestone_type: int, generation: int) -> String:
	match milestone_type:
		MilestoneType.GENERATION_100:
			return "A dynasty of one hundred generations stands eternal. Your lineage has proven its worth."
		MilestoneType.GENERATION_250:
			return "A quarter-millennium has passed. The dynasty's name echoes across ages."
		MilestoneType.GENERATION_500:
			return "Five hundred generations. Your legacy shapes the world itself."
		MilestoneType.GENERATION_750:
			return "Seven hundred fifty generations. The dynasty approaches its final act."
		MilestoneType.GENERATION_999:
			return "Nine hundred ninety-nine generations. All of history culminates in this moment."
		_:
			return "A great milestone has been reached."


func _get_milestone_rewards(milestone_type: int) -> Dictionary:
	var rewards = {}

	match milestone_type:
		MilestoneType.GENERATION_100:
			rewards = {
				"prestige": 1000,
				"stat_bonus": 5,
				"gold": 5000,
				"legendary_items": 1
			}
		MilestoneType.GENERATION_250:
			rewards = {
				"prestige": 2500,
				"stat_bonus": 10,
				"gold": 12500,
				"legendary_items": 2
			}
		MilestoneType.GENERATION_500:
			rewards = {
				"prestige": 5000,
				"stat_bonus": 15,
				"gold": 25000,
				"legendary_items": 3
			}
		MilestoneType.GENERATION_750:
			rewards = {
				"prestige": 7500,
				"stat_bonus": 20,
				"gold": 37500,
				"legendary_items": 4
			}
		MilestoneType.GENERATION_999:
			rewards = {
				"prestige": 10000,
				"stat_bonus": 25,
				"gold": 50000,
				"legendary_items": 5
			}

	return rewards


func get_milestone_legacy() -> String:
	var completed = completed_milestones.size()
	if completed == 0:
		return "The dynasty's milestones lie ahead."

	var legacy = "The dynasty has reached %d great milestones. " % completed

	if completed >= 2:
		legacy += "Through centuries, they have proven their eternal worth. "

	if completed >= 3:
		legacy += "Their name is carved into the very fabric of history. "

	if completed >= 4:
		legacy += "They stand on the threshold of legend itself. "

	if completed >= 5:
		legacy += "They have achieved the impossible: 999 generations of unbroken glory."

	return legacy
