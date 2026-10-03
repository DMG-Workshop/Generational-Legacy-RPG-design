## Event System: generates life events based on heir state and actions
##
## Creates quests, marriage opportunities, betrayals, successes, and tragedies

extends Node

class_name EventSystem


## Event types and their base chances per year
enum EventType {
	QUEST,
	MARRIAGE,
	BETRAYAL,
	SUCCESS,
	TRAGEDY,
	ROMANCE,
	RIVAL,
	INHERITANCE,
	DISCOVERY
}


## Generate a random event for the current year
func generate_event(heir: Heir, age: int, phase: int, reputation: Dictionary) -> Dictionary:
	var event_pool: Array[Dictionary] = []

	# Quest events (always possible)
	if age >= 13:
		event_pool.append({
			"type": "quest",
			"weight": 30,
			"data": _generate_quest(heir, reputation)
		})

	# Marriage opportunities (adulthood only)
	if age >= 18 and age <= 50:
		event_pool.append({
			"type": "marriage",
			"weight": 15,
			"data": _generate_marriage_event(heir)
		})

	# Romance (adulthood)
	if age >= 18 and age <= 50:
		event_pool.append({
			"type": "romance",
			"weight": 20,
			"data": _generate_romance_event(heir)
		})

	# Betrayal (affects faction standing)
	if age >= 20:
		event_pool.append({
			"type": "betrayal",
			"weight": 10,
			"data": _generate_betrayal_event(heir, reputation)
		})

	# Success/Achievement
	if age >= 15:
		event_pool.append({
			"type": "success",
			"weight": 15,
			"data": _generate_success_event(heir, reputation)
		})

	# Rivalry/Conflict
	if age >= 18:
		event_pool.append({
			"type": "rival",
			"weight": 10,
			"data": _generate_rival_event(heir)
		})

	# Inheritance/Legacy
	if age >= 45:
		event_pool.append({
			"type": "inheritance",
			"weight": 8,
			"data": _generate_inheritance_event(heir)
		})

	# Discovery/revelation
	event_pool.append({
		"type": "discovery",
		"weight": 5,
		"data": _generate_discovery_event(heir)
	})

	# Select random event based on weights
	if event_pool.is_empty():
		return {"type": "none"}

	var total_weight = 0
	for pool_item in event_pool:
		total_weight += pool_item["weight"]

	var roll = randi() % total_weight
	var current = 0

	for pool_item in event_pool:
		current += pool_item["weight"]
		if roll < current:
			return pool_item["data"]

	return event_pool[0]["data"]


func _generate_quest(heir: Heir, reputation: Dictionary) -> Dictionary:
	var quest_types = [
		"Slay the beast terrorizing the village",
		"Recover a stolen artifact",
		"Escort a merchant caravan",
		"Investigate mysterious disappearances",
		"Break an ancient curse",
		"Negotiate a peace treaty",
		"Find a lost heir to the throne",
		"Delve into ancient ruins"
	]

	var rewards = [50, 100, 150, 200, 250]

	return {
		"type": "quest",
		"title": quest_types[randi() % quest_types.size()],
		"description": "A stranger approaches with an urgent plea...",
		"reward": rewards[randi() % rewards.size()],
		"difficulty": randi() % 5,  # 0-4 difficulty
		"faction": "general"
	}


func _generate_marriage_event(heir: Heir) -> Dictionary:
	var names = ["Elena", "Theron", "Sophia", "Marcus", "Vera", "Aldric"]
	var suitor = names[randi() % names.size()]

	return {
		"type": "marriage",
		"suitor": suitor,
		"description": "%s has asked for your hand in marriage." % suitor,
		"bonuses": {
			"wealth": 50,
			"heirs": 1
		}
	}


func _generate_romance_event(heir: Heir) -> Dictionary:
	var scenarios = [
		"A charming stranger catches your eye at a tavern",
		"You meet someone during your travels",
		"An old flame reappears in your life",
		"A mysterious figure seeks you out"
	]

	return {
		"type": "romance",
		"description": scenarios[randi() % scenarios.size()],
		"outcome": "relationship"
	}


func _generate_betrayal_event(heir: Heir, reputation: Dictionary) -> Dictionary:
	var betrayals = [
		"A trusted ally reveals they were an enemy",
		"Someone steals your most prized possession",
		"A secret is revealed that damages your reputation",
		"A binding contract turns against you"
	]

	# Pick a random faction to lose standing with
	var factions = ["warriors_order", "mages_circle", "thieves_guild", "church"]
	var affected_faction = factions[randi() % factions.size()]

	return {
		"type": "betrayal",
		"description": betrayals[randi() % betrayals.size()],
		"reputation_loss": randi_range(10, 30),
		"affected_faction": affected_faction
	}


func _generate_success_event(heir: Heir, reputation: Dictionary) -> Dictionary:
	var successes = [
		"You defeat a legendary foe",
		"You discover a powerful artifact",
		"You negotiate a favorable trade deal",
		"Your deeds are celebrated throughout the realm"
	]

	return {
		"type": "success",
		"description": successes[randi() % successes.size()],
		"reputation_gain": randi_range(10, 30),
		"wealth_gain": randi_range(50, 200)
	}


func _generate_rival_event(heir: Heir) -> Dictionary:
	var rival_names = ["Kael", "Sylvia", "Mordain", "Isolde"]
	var rival = rival_names[randi() % rival_names.size()]

	return {
		"type": "rival",
		"rival": rival,
		"description": "%s emerges as your bitter rival" % rival,
		"conflict_type": "ongoing"
	}


func _generate_inheritance_event(heir: Heir) -> Dictionary:
	return {
		"type": "inheritance",
		"description": "A distant relative's estate becomes yours",
		"estate_value": randi_range(500, 2000),
		"property_type": "estate"
	}


func _generate_discovery_event(heir: Heir) -> Dictionary:
	var discoveries = [
		"You uncover a family secret",
		"You learn about your true lineage",
		"You discover a hidden talent within yourself",
		"An ancient tome reveals dangerous knowledge"
	]

	return {
		"type": "discovery",
		"description": discoveries[randi() % discoveries.size()],
		"impact": "moderate"
	}


## Apply event consequences to heir
func apply_event_consequences(heir: Heir, event: Dictionary, accepted: bool = true) -> Dictionary:
	var result = {
		"wealth_change": 0,
		"reputation_changes": {},
		"trait_changes": [],
		"relationships_affected": []
	}

	if not accepted:
		return result

	match event.get("type", ""):
		"quest":
			result["wealth_change"] = event.get("reward", 0)

		"marriage":
			result["wealth_change"] = event.get("bonuses", {}).get("wealth", 0)
			result["trait_changes"].append("married")

		"betrayal":
			var faction = event.get("affected_faction", "general")
			result["reputation_changes"][faction] = -event.get("reputation_loss", 0)

		"success":
			result["reputation_changes"]["general"] = event.get("reputation_gain", 0)
			result["wealth_change"] = event.get("wealth_gain", 0)

		"inheritance":
			result["wealth_change"] = event.get("estate_value", 0)

	return result
