## NPC Persistence: Save and load NPC state across generations
##
## Serializes NPCs, schedules, and reputation for generational continuity

extends Node

class_name NPCPersistence


signal npc_saved(npc_id: String)
signal npc_loaded(npc_id: String)


var npc_system: NPCSystem
var schedule_system: NPCScheduleSystem
var reputation_system: NPCReputationSystem
var saved_npcs: Dictionary = {}


func _init(p_npc_system: NPCSystem = null, p_schedule_system: NPCScheduleSystem = null, p_reputation_system: NPCReputationSystem = null) -> void:
	if p_npc_system:
		npc_system = p_npc_system
	else:
		npc_system = NPCSystem.new()
	
	if p_schedule_system:
		schedule_system = p_schedule_system
	else:
		schedule_system = NPCScheduleSystem.new()
	
	if p_reputation_system:
		reputation_system = p_reputation_system
	else:
		reputation_system = NPCReputationSystem.new()


func save_npc(npc_id: String) -> Dictionary:
	var npc = npc_system.get_npc(npc_id)
	if not npc:
		return {}
	
	var schedule = schedule_system.get_npc_schedule(npc_id)
	var reputation = reputation_system.get_reputation_info(npc_id)
	
	var npc_data = {
		"id": npc.id,
		"name": npc.name,
		"age": npc.age,
		"profession": NPCSystem.NPCProfession.keys()[npc.profession],
		"location": npc.location,
		"mood": npc.mood,
		"health": npc.health,
		"alive": npc.is_alive,
		"stats": npc.stats.duplicate(),
		"reputation": reputation["reputation"],
		"schedule": {
			"home_location": schedule.home_location if schedule else Vector2i.ZERO,
			"assigned_building": schedule.assigned_building if schedule else ""
		}
	}
	
	saved_npcs[npc_id] = npc_data
	npc_saved.emit(npc_id)
	return npc_data


func load_npc(npc_data: Dictionary) -> String:
	if npc_data.is_empty():
		return ""
	
	var profession_key = npc_data.get("profession", "MERCHANT")
	var profession = NPCSystem.NPCProfession.get(profession_key)
	
	var npc_id = npc_system.create_npc(npc_data["name"], profession, npc_data.get("location", Vector2i.ZERO))
	var npc = npc_system.get_npc(npc_id)
	
	if npc:
		npc.age = npc_data.get("age", 20)
		npc.mood = npc_data.get("mood", "neutral")
		npc.health = npc_data.get("health", 1.0)
		npc.is_alive = npc_data.get("alive", true)
		
		if npc_data.has("stats"):
			for stat in npc_data["stats"]:
				npc.stats[stat] = npc_data["stats"][stat]
		
		var schedule_data = npc_data.get("schedule", {})
		var schedule = schedule_system.create_schedule_for_npc(npc_id, schedule_data.get("home_location", Vector2i.ZERO))
		
		if schedule_data.has("assigned_building"):
			schedule.assigned_building = schedule_data["assigned_building"]
		
		var reputation = npc_data.get("reputation", 0)
		reputation_system.initialize_npc_reputation(npc_id)
		reputation_system.add_reputation(npc_id, reputation)
		
		npc_loaded.emit(npc_id)
	
	return npc_id


func save_all_npcs() -> Dictionary:
	var all_data = {}
	for npc in npc_system.get_all_npcs():
		all_data[npc.id] = save_npc(npc.id)
	return all_data


func load_all_npcs(npcs_data: Dictionary) -> void:
	for npc_id in npcs_data.keys():
		load_npc(npcs_data[npc_id])


func get_npc_save_data(npc_id: String) -> Dictionary:
	return saved_npcs.get(npc_id, {})


func export_npc_history(npc_id: String) -> Dictionary:
	var npc = npc_system.get_npc(npc_id)
	if not npc:
		return {}
	
	var reputation = reputation_system.get_reputation_info(npc_id)
	
	return {
		"name": npc.name,
		"age": npc.age,
		"profession": NPCSystem.NPCProfession.keys()[npc.profession],
		"alive": npc.is_alive,
		"stats": npc.stats.duplicate(),
		"reputation": reputation
	}


func transfer_npc_to_next_generation(npc_id: String) -> String:
	var npc = npc_system.get_npc(npc_id)
	if not npc or not npc.is_alive:
		return ""
	
	var npc_data = save_npc(npc_id)
	npc_data["age"] = npc_data.get("age", 20) + 20
	
	return load_npc(npc_data)


func clear_saved_data() -> void:
	saved_npcs.clear()


func get_npc_legacy(npc_id: String) -> Dictionary:
	var npc = npc_system.get_npc(npc_id)
	if not npc:
		return {}
	
	var reputation = reputation_system.get_reputation_info(npc_id)
	
	return {
		"name": npc.name,
		"lived_to_age": npc.age,
		"final_profession": NPCSystem.NPCProfession.keys()[npc.profession],
		"final_reputation": reputation["reputation"],
		"relationship": reputation["relationship_tier"]
	}
