## NPC System: NPCs with quests, reputation, and recruitment
##
## NPCs are assigned to settlements and offer quests based on heir stats
## Reputation affects quest difficulty and rewards

class_name NPCSystem


signal npc_created(npc_name: String, settlement_name: String)
signal quest_offered(npc_name: String, quest_id: String)
signal quest_completed(npc_name: String, quest_id: String, heir_name: String)
signal npc_recruited(npc_name: String, heir_name: String)


enum QuestType { COMBAT, GATHERING, EXPLORATION, CRAFTING, DELIVERY }
enum QuestDifficulty { EASY, NORMAL, HARD, EPIC }

var npcs: Dictionary = {}  # npc_name -> npc data
var quests: Dictionary = {}  # quest_id -> quest data
var npc_reputation: Dictionary = {}  # heir_name + "_" + npc_name -> reputation value

# Quest templates
var quest_templates: Dictionary = {
	QuestType.COMBAT: {
		"title": "Slay %d enemies",
		"difficulty_scaling": 1.2,
		"reward_base": {"gold": 100, "xp": 50},
	},
	QuestType.GATHERING: {
		"title": "Gather %d materials",
		"difficulty_scaling": 0.8,
		"reward_base": {"gold": 75, "xp": 30},
	},
	QuestType.EXPLORATION: {
		"title": "Explore region",
		"difficulty_scaling": 1.0,
		"reward_base": {"gold": 120, "xp": 60},
	},
	QuestType.CRAFTING: {
		"title": "Craft %d items",
		"difficulty_scaling": 0.9,
		"reward_base": {"gold": 90, "xp": 40},
	},
	QuestType.DELIVERY: {
		"title": "Deliver items",
		"difficulty_scaling": 0.7,
		"reward_base": {"gold": 60, "xp": 25},
	},
}


## Create NPC
func create_npc(name: String, settlement_name: String, class_id: String, job_id: String, faction: String = "neutral") -> Dictionary:
	if name in npcs:
		return npcs[name]

	var npc = {
		"name": name,
		"settlement": settlement_name,
		"class": class_id,
		"job": job_id,
		"faction": faction,
		"level": 1,
		"personality": _generate_personality(),
		"quests_offered": 0,
		"recruitment_cost": 50,
		"created_at": Time.get_ticks_msec(),
	}

	npcs[name] = npc
	npc_created.emit(name, settlement_name)
	return npc


## Get NPC
func get_npc(name: String) -> Dictionary:
	return npcs.get(name, {})


## Get NPCs in settlement
func get_settlement_npcs(settlement_name: String) -> Array[String]:
	var settlement_npcs = []
	for npc_name in npcs.keys():
		if npcs[npc_name]["settlement"] == settlement_name:
			settlement_npcs.append(npc_name)
	return settlement_npcs


## Generate quest for heir
func generate_quest(npc_name: String, heir_name: String, heir_stats: Dictionary) -> Dictionary:
	if npc_name not in npcs:
		return {}

	var npc = npcs[npc_name]
	var quest_id = "%s_%d" % [npc_name, Time.get_ticks_msec()]
	var quest_type = randi_range(QuestType.COMBAT, QuestType.DELIVERY)
	var template = quest_templates.get(quest_type, {})

	# Determine difficulty based on heir stats and reputation
	var reputation = get_reputation(heir_name, npc_name)
	var heir_power = _calculate_heir_power(heir_stats)
	var difficulty = _determine_difficulty(heir_power, reputation)

	var base_reward = template.get("reward_base", {})
	var difficulty_multiplier = 1.0 + (difficulty * 0.3)
	var reputation_bonus = max(1.0, 1.0 + (reputation / 100.0) * 0.2)

	var quest = {
		"id": quest_id,
		"npc": npc_name,
		"type": quest_type,
		"difficulty": difficulty,
		"title": template.get("title", "Unknown Quest"),
		"description": _generate_quest_description(quest_type, difficulty),
		"objective_count": _generate_objective_count(quest_type, difficulty),
		"rewards": {
			"gold": int(base_reward.get("gold", 0) * difficulty_multiplier * reputation_bonus),
			"xp": int(base_reward.get("xp", 0) * difficulty_multiplier * reputation_bonus),
		},
		"reputation_reward": int(10 * (difficulty + 1)),
		"completion_chance": _calculate_completion_chance(heir_power, difficulty),
		"offered_at": Time.get_ticks_msec(),
		"expires_in": 86400,  # 24 hours in seconds
	}

	quests[quest_id] = quest
	quest_offered.emit(npc_name, quest_id)
	return quest


## Complete quest
func complete_quest(quest_id: String, heir_name: String, success: bool = true) -> Dictionary:
	if quest_id not in quests:
		return {}

	var quest = quests[quest_id]
	var rewards = {"gold": 0, "xp": 0, "reputation": 0}

	if success:
		rewards["gold"] = quest["rewards"]["gold"]
		rewards["xp"] = quest["rewards"]["xp"]
		rewards["reputation"] = quest["reputation_reward"]
		_update_reputation(heir_name, quest["npc"], quest["reputation_reward"])
	else:
		rewards["reputation"] = int(-quest["reputation_reward"] * 0.5)
		_update_reputation(heir_name, quest["npc"], int(-quest["reputation_reward"] * 0.5))

	quest_completed.emit(quest["npc"], quest_id, heir_name)
	quests.erase(quest_id)
	return rewards


## Recruit NPC to heir's party
func recruit_npc(npc_name: String, heir_name: String, payment: int) -> bool:
	if npc_name not in npcs:
		return false

	var npc = npcs[npc_name]
	var recruitment_cost = npc["recruitment_cost"]

	if payment < recruitment_cost:
		return false

	npc_recruited.emit(npc_name, heir_name)
	return true


## Get reputation between heir and NPC
func get_reputation(heir_name: String, npc_name: String) -> int:
	var key = heir_name + "_" + npc_name
	return npc_reputation.get(key, 0)


## Internal: Update reputation
func _update_reputation(heir_name: String, npc_name: String, amount: int) -> void:
	var key = heir_name + "_" + npc_name
	npc_reputation[key] = npc_reputation.get(key, 0) + amount
	npc_reputation[key] = clampi(npc_reputation[key], -500, 500)


## Internal: Generate NPC personality
func _generate_personality() -> Dictionary:
	return {
		"temperament": ["friendly", "neutral", "gruff"].pick_random(),
		"ambition": randf_range(0.3, 1.0),
		"loyalty": randf_range(0.3, 1.0),
	}


## Internal: Calculate heir power from stats
func _calculate_heir_power(stats: Dictionary) -> float:
	var sum = 0.0
	for stat_value in stats.values():
		sum += stat_value
	return sum / maxf(stats.size(), 1.0)


## Internal: Determine quest difficulty
func _determine_difficulty(heir_power: float, reputation: int) -> int:
	var base_difficulty = clampi(int(heir_power / 5.0), 0, 3)
	var reputation_adjustment = clampi(int(reputation / 100.0), -1, 1)
	return clampi(base_difficulty + reputation_adjustment, 0, 3)


## Internal: Generate objective count based on type and difficulty
func _generate_objective_count(quest_type: int, difficulty: int) -> int:
	var base_count = 1
	match quest_type:
		QuestType.COMBAT:
			base_count = 2 + difficulty
		QuestType.GATHERING:
			base_count = 5 + (difficulty * 3)
		QuestType.EXPLORATION:
			base_count = 1 + difficulty
		QuestType.CRAFTING:
			base_count = 3 + difficulty
		QuestType.DELIVERY:
			base_count = 1

	return base_count


## Internal: Generate quest description
func _generate_quest_description(quest_type: int, difficulty: int) -> String:
	var difficulty_words = ["Simple", "Standard", "Challenging", "Epic"]
	var quest_words = {
		QuestType.COMBAT: "combat",
		QuestType.GATHERING: "gathering",
		QuestType.EXPLORATION: "exploration",
		QuestType.CRAFTING: "crafting",
		QuestType.DELIVERY: "delivery",
	}

	return "%s %s quest." % [difficulty_words[difficulty], quest_words.get(quest_type, "unknown")]


## Internal: Calculate completion chance
func _calculate_completion_chance(heir_power: float, difficulty: int) -> float:
	var base_chance = 0.5
	var power_bonus = (heir_power - 10.0) / 20.0  # Scales from ~0.5 to ~1.0
	var difficulty_penalty = (difficulty * 0.15)
	return clampf(base_chance + power_bonus - difficulty_penalty, 0.1, 0.95)


## Get NPC summary
func get_npc_summary(npc_name: String) -> Dictionary:
	if npc_name not in npcs:
		return {}

	var npc = npcs[npc_name]
	return {
		"name": npc_name,
		"settlement": npc["settlement"],
		"class": npc["class"],
		"job": npc["job"],
		"level": npc["level"],
		"personality": npc["personality"],
		"recruitment_cost": npc["recruitment_cost"],
	}
