## Faction Reputation System: Track player standing with each faction
##
## Manages per-faction reputation, affinity, and reputation history

extends Node

class_name FactionReputationSystem


signal faction_standing_changed(faction_id: String, standing: int)
signal faction_affinity_changed(faction_id: String, affinity: float)
signal faction_tier_changed(faction_id: String, old_tier: String, new_tier: String)
signal faction_milestone_reached(faction_id: String, milestone: String)


var faction_system: FactionSystem
var standing_history: Dictionary = {}


class FactionStanding:
	var faction_id: String
	var standing: int = 0
	var interaction_count: int = 0
	var actions_taken: Array = []
	var current_tier: String = "neutral"
	var tier_change_tick: int = 0
	
	func _init(p_faction_id: String) -> void:
		faction_id = p_faction_id


func _init(p_faction_system: FactionSystem = null) -> void:
	if p_faction_system:
		faction_system = p_faction_system
	else:
		faction_system = FactionSystem.new()
	
	standing_history = {}
	_initialize_standings()


func _initialize_standings() -> void:
	for faction in faction_system.get_all_factions():
		var standing = FactionStanding.new(faction.id)
		standing_history[faction.id] = standing


func add_standing(faction_id: String, amount: int) -> void:
	if not standing_history.has(faction_id):
		standing_history[faction_id] = FactionStanding.new(faction_id)
	
	var standing = standing_history[faction_id]
	var old_tier = standing.current_tier
	
	standing.standing = clamp(standing.standing + amount, -100, 100)
	standing.interaction_count += 1
	standing.actions_taken.append({"amount": amount, "tick": 0})
	
	_update_tier(faction_id)
	faction_standing_changed.emit(faction_id, standing.standing)
	
	var new_tier = standing.current_tier
	if old_tier != new_tier:
		faction_tier_changed.emit(faction_id, old_tier, new_tier)


func remove_standing(faction_id: String, amount: int) -> void:
	add_standing(faction_id, -amount)


func get_standing(faction_id: String) -> int:
	if standing_history.has(faction_id):
		return standing_history[faction_id].standing
	return 0


func get_tier(faction_id: String) -> String:
	if standing_history.has(faction_id):
		return standing_history[faction_id].current_tier
	return "neutral"


func _update_tier(faction_id: String) -> void:
	var standing = standing_history.get(faction_id)
	if not standing:
		return
	
	var rep = standing.standing
	var new_tier = "neutral"
	
	if rep < -50:
		new_tier = "hostile"
	elif rep < -25:
		new_tier = "unfriendly"
	elif rep < 25:
		new_tier = "neutral"
	elif rep < 50:
		new_tier = "friendly"
	else:
		new_tier = "allied"
	
	standing.current_tier = new_tier


func get_affinity_vector() -> Dictionary:
	var affinity = {}
	for faction_id in standing_history.keys():
		var standing = standing_history[faction_id].standing
		affinity[faction_id] = standing / 100.0
	return affinity


func get_dominant_faction() -> String:
	var max_standing = -101
	var dominant = ""
	
	for faction_id in standing_history.keys():
		var standing = standing_history[faction_id].standing
		if standing > max_standing and standing > 0:
			max_standing = standing
			dominant = faction_id
	
	return dominant


func get_allied_factions() -> Array:
	var allied = []
	for faction_id in standing_history.keys():
		if get_tier(faction_id) == "allied":
			allied.append(faction_id)
	return allied


func get_hostile_factions() -> Array:
	var hostile = []
	for faction_id in standing_history.keys():
		if get_tier(faction_id) == "hostile":
			hostile.append(faction_id)
	return hostile


func can_access_faction_quest(faction_id: String, required_tier: String = "neutral") -> bool:
	var tier = get_tier(faction_id)
	
	match required_tier:
		"hostile":
			return true
		"unfriendly":
			return tier in ["unfriendly", "neutral", "friendly", "allied"]
		"neutral":
			return tier in ["neutral", "friendly", "allied"]
		"friendly":
			return tier in ["friendly", "allied"]
		"allied":
			return tier == "allied"
	
	return false


func get_faction_interaction_bonus(faction_id: String) -> float:
	var tier = get_tier(faction_id)
	
	match tier:
		"hostile":
			return 0.5
		"unfriendly":
			return 0.75
		"neutral":
			return 1.0
		"friendly":
			return 1.25
		"allied":
			return 1.5
	
	return 1.0


func get_faction_standing_info(faction_id: String) -> Dictionary:
	if not standing_history.has(faction_id):
		return {}
	
	var standing = standing_history[faction_id]
	return {
		"faction_id": faction_id,
		"standing": standing.standing,
		"tier": standing.current_tier,
		"interactions": standing.interaction_count,
		"bonus": get_faction_interaction_bonus(faction_id)
	}


func get_all_standings() -> Dictionary:
	var all_standings = {}
	for faction_id in standing_history.keys():
		all_standings[faction_id] = get_faction_standing_info(faction_id)
	return all_standings


func reset_faction_standing(faction_id: String) -> void:
	if standing_history.has(faction_id):
		standing_history[faction_id].standing = 0
		_update_tier(faction_id)


func decay_factions_over_time(faction_id: String, tick_delta: int, decay_rate: float = 0.01) -> void:
	var standing = standing_history.get(faction_id)
	if standing:
		var decay = int(decay_rate * (tick_delta / 1000.0) * standing.standing.abs())
		if standing.standing > 0:
			remove_standing(faction_id, decay)
		elif standing.standing < 0:
			add_standing(faction_id, decay)
