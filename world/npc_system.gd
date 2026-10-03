## NPC System: Individual NPC logic with state, stats, and relationships
##
## Manages NPC properties, lifecycle, and interaction state

extends Node

class_name NPCSystem


signal npc_created(npc_id: String, name: String)
signal npc_aged(npc_id: String, age: int)
signal npc_died(npc_id: String, name: String, age: int)
signal npc_mood_changed(npc_id: String, mood: String)
signal npc_health_changed(npc_id: String, health: float)


enum NPCProfession { INNKEEPER, BLACKSMITH, TAVERN_KEEPER, PRIEST, MERCHANT, CRAFTER }

var npcs: Dictionary = {}


class NPC:
	var id: String
	var name: String
	var age: int = 20
	var profession: int = NPCProfession.MERCHANT
	var stats: Dictionary = {}
	var location: Vector2i = Vector2i.ZERO
	var current_activity: String = "idle"
	var mood: String = "neutral"
	var health: float = 1.0
	var created_at_tick: int = 0
	var death_tick: int = -1
	var is_alive: bool = true
	var parent_npc_id: String = ""
	
	func _init(p_id: String, p_name: String, p_profession: int = NPCProfession.MERCHANT) -> void:
		id = p_id
		name = p_name
		profession = p_profession
		_initialize_stats()
	
	func _initialize_stats() -> void:
		var base_stats = {
			"strength": 10,
			"dexterity": 10,
			"constitution": 10,
			"intelligence": 10,
			"wisdom": 10,
			"charisma": 10
		}
		
		match profession:
			NPCProfession.BLACKSMITH:
				base_stats["strength"] += 3
				base_stats["constitution"] += 2
			NPCProfession.INNKEEPER:
				base_stats["charisma"] += 3
				base_stats["wisdom"] += 2
			NPCProfession.TAVERN_KEEPER:
				base_stats["charisma"] += 2
				base_stats["dexterity"] += 2
			NPCProfession.PRIEST:
				base_stats["wisdom"] += 3
				base_stats["intelligence"] += 2
			NPCProfession.MERCHANT:
				base_stats["intelligence"] += 2
				base_stats["charisma"] += 1
			NPCProfession.CRAFTER:
				base_stats["intelligence"] += 2
				base_stats["dexterity"] += 2
		
		stats = base_stats


func _init() -> void:
	npcs = {}


func create_npc(name: String, profession: int, initial_location: Vector2i = Vector2i.ZERO) -> String:
	var npc_id = "%s_%d_%d" % [name.to_lower().replace(" ", "_"), randi(), randi()]
	var npc = NPC.new(npc_id, name, profession)
	npc.location = initial_location
	npcs[npc_id] = npc
	npc_created.emit(npc_id, name)
	return npc_id


func get_npc(npc_id: String) -> NPC:
	return npcs.get(npc_id)


func age_npc(npc_id: String) -> void:
	var npc = npcs.get(npc_id)
	if npc and npc.is_alive:
		npc.age += 1
		npc_aged.emit(npc_id, npc.age)
		
		if npc.age >= 75 and npc.age <= 100:
			var death_chance = int((npc.age - 74) * 5)
			if randi() % 100 < death_chance:
				kill_npc(npc_id, "old_age")


func kill_npc(npc_id: String, cause: String = "unknown") -> void:
	var npc = npcs.get(npc_id)
	if npc and npc.is_alive:
		npc.is_alive = false
		npc.death_tick = 0
		npc_died.emit(npc_id, npc.name, npc.age)


func update_npc_location(npc_id: String, new_location: Vector2i) -> void:
	var npc = npcs.get(npc_id)
	if npc:
		npc.location = new_location


func set_npc_activity(npc_id: String, activity: String) -> void:
	var npc = npcs.get(npc_id)
	if npc:
		npc.current_activity = activity


func set_npc_mood(npc_id: String, mood: String) -> void:
	var npc = npcs.get(npc_id)
	if npc:
		npc.mood = mood
		npc_mood_changed.emit(npc_id, mood)


func update_npc_health(npc_id: String, delta: float) -> void:
	var npc = npcs.get(npc_id)
	if npc:
		npc.health = clamp(npc.health + delta, 0.0, 1.0)
		npc_health_changed.emit(npc_id, npc.health)
		
		if npc.health <= 0:
			kill_npc(npc_id, "illness")


func get_npc_info(npc_id: String) -> Dictionary:
	var npc = npcs.get(npc_id)
	if not npc:
		return {}
	
	return {
		"id": npc.id,
		"name": npc.name,
		"age": npc.age,
		"profession": NPCProfession.keys()[npc.profession],
		"location": npc.location,
		"activity": npc.current_activity,
		"mood": npc.mood,
		"health": npc.health,
		"stats": npc.stats.duplicate(),
		"alive": npc.is_alive
	}


func get_npc_stat(npc_id: String, stat: String) -> int:
	var npc = npcs.get(npc_id)
	if npc:
		return npc.stats.get(stat, 0)
	return 0


func get_all_npcs() -> Array:
	return npcs.values()


func get_alive_npcs() -> Array:
	var alive = []
	for npc in npcs.values():
		if npc.is_alive:
			alive.append(npc)
	return alive


func get_npcs_by_profession(profession: int) -> Array:
	var result = []
	for npc in npcs.values():
		if npc.profession == profession and npc.is_alive:
			result.append(npc)
	return result


func get_npcs_at_location(location: Vector2i) -> Array:
	var result = []
	for npc in npcs.values():
		if npc.location == location and npc.is_alive:
			result.append(npc)
	return result


func npc_exists(npc_id: String) -> bool:
	return npcs.has(npc_id)
