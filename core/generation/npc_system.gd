## NPC System: manages old heirs as NPCs in the world
##
## When a heir retires, they become:
## - An NPC ancestor in the Hollow Below (tomb)
## - A legendary companion if they had exceptional deeds
## - A ghost or spirit that can be consulted

extends Node

class_name NPCSystem


## NPC ancestor data
class NPCAncestor:
	var heir: Heir
	var generation: int
	var location: Vector3i  # Where their tomb is in Hollow Below
	var personality: String  # Based on their life
	var known_techniques: Array[String] = []  # Legacy Arts they can teach
	var can_teach: bool = true
	var relationship: int = 0  # -100 to +100 (player's relationship with them)
	var wisdom: int = 0  # Advice quality
	var is_legendary: bool = false  # Rare exceptional ancestors


var npcs: Array[NPCAncestor] = []

## Legendary companions (persist across many generations)
var legendary_companions: Array[NPCAncestor] = []


func _init() -> void:
	npcs = []
	legendary_companions = []


## Add an ancestor to the NPC list
func add_npc_ancestor(heir: Heir, generation: int) -> NPCAncestor:
	var npc = NPCAncestor.new()
	npc.heir = heir
	npc.generation = generation
	npc.location = Vector3i(generation, 0, 100)  # Tomb location in Hollow

	# Personality based on traits
	if "dragonblood" in heir.traits:
		npc.personality = "proud"
	elif "outlaws_cunning" in heir.traits:
		npc.personality = "cunning"
	elif "warriors_steel" in heir.traits:
		npc.personality = "bold"
	elif "mageblood" in heir.traits:
		npc.personality = "mystical"
	else:
		npc.personality = "humble"

	# Can teach if they had legendary life events
	npc.wisdom = int(heir.traits.size() * 10)

	# Check if legendary
	if heir.traits.size() >= 4 and "legendary" in heir.traits:
		npc.is_legendary = true
		legendary_companions.append(npc)

	npcs.append(npc)
	return npc


## Find an ancestor by generation
func get_ancestor_by_generation(generation: int) -> NPCAncestor:
	for npc in npcs:
		if npc.generation == generation:
			return npc
	return null


## Get all ancestors within a certain generation distance
func get_recent_ancestors(current_generation: int, distance: int = 20) -> Array[NPCAncestor]:
	var recent: Array[NPCAncestor] = []

	for npc in npcs:
		if current_generation - npc.generation <= distance and current_generation > npc.generation:
			recent.append(npc)

	recent.sort_custom(func(a, b): return a.generation > b.generation)
	return recent


## Visit an ancestor's tomb in Hollow Below
func visit_ancestor(npc: NPCAncestor, current_heir: Heir) -> Dictionary:
	var interaction = {
		"ancestor": npc.heir.name,
		"generation": npc.generation,
		"personality": npc.personality,
		"wisdom": npc.wisdom,
		"can_learn": false,
		"legacy_art": null
	}

	# Chance to learn ancestor's technique
	var generations_ago = current_heir.generation - npc.generation
	var learn_chance = max(0.1, 0.5 - (generations_ago * 0.02))  # Closer = higher chance

	if randf() < learn_chance:
		var technique = "ancestor_technique_%d" % npc.generation
		interaction["can_learn"] = true
		interaction["legacy_art"] = technique

	# Update relationship
	if interaction["can_learn"]:
		npc.relationship += 10

	# Chance of wisdom bonus (stat boost)
	if randf() < 0.3:
		interaction["wisdom_gained"] = int(npc.wisdom * 0.1)

	return interaction


## Get a legendary companion (rare ancestors that appear across generations)
func get_legendary_companion(name_hint: String = "") -> NPCAncestor:
	if legendary_companions.is_empty():
		return null

	# Return a random legendary companion
	return legendary_companions[randi() % legendary_companions.size()]


## Get companion biography for display
func get_companion_biography(npc: NPCAncestor) -> Dictionary:
	return {
		"name": npc.heir.name,
		"generation": npc.generation,
		"class": npc.heir.class_id,
		"job": npc.heir.job_id,
		"traits": npc.heir.traits,
		"personality": npc.personality,
		"wisdom": npc.wisdom,
		"is_legendary": npc.is_legendary,
		"known_techniques": npc.known_techniques.size(),
	}


## Ancestor passes judgment on heir's actions
func judge_heir_actions(npc: NPCAncestor, heir_actions: Array[String]) -> Dictionary:
	var judgment = {
		"ancestor": npc.heir.name,
		"approval": 0,  # -100 to +100
		"comment": ""
	}

	# Check for conflicting actions with ancestor's traits
	for action in heir_actions:
		if npc.heir.has_trait("warriors_steel") and "cowardly" in action:
			judgment["approval"] -= 20
			judgment["comment"] = "Dishonorable!"
		elif npc.heir.has_trait("outlaws_cunning") and "law_enforcement" in action:
			judgment["approval"] -= 15
			judgment["comment"] = "Betrayed our ways!"
		elif action == "noble_deed":
			judgment["approval"] += 25

	return judgment


## Get all NPCs (ancestors + legendary companions)
func get_all_npcs() -> Array[NPCAncestor]:
	var all_npcs: Array[NPCAncestor] = []
	all_npcs.append_array(npcs)
	all_npcs.append_array(legendary_companions)
	return all_npcs


## Check if an NPC is reachable (in accessible realms)
func is_npc_reachable(npc: NPCAncestor, heir_traits: Array[String]) -> bool:
	# All ancestors are in Hollow Below
	# Marked by Death trait allows access
	return "marked_by_death" in heir_traits or "faetouched" in heir_traits


## Summary of all ancestors
func get_ancestry_summary(current_generation: int) -> Dictionary:
	var summary = {
		"total_ancestors": npcs.size(),
		"legendary_count": legendary_companions.size(),
		"recent_ancestors": get_recent_ancestors(current_generation, 5).size(),
		"most_wise": null,
		"most_legendary": null
	}

	if not npcs.is_empty():
		var wisest = npcs[0]
		for npc in npcs:
			if npc.wisdom > wisest.wisdom:
				wisest = npc
		summary["most_wise"] = wisest.heir.name

	if not legendary_companions.is_empty():
		summary["most_legendary"] = legendary_companions[0].heir.name

	return summary
