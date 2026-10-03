## NPC Reputation System: Tracks reputation with each NPC
##
## Affects dialogue options, prices, quest rewards, and NPC behavior

extends Node

class_name NPCReputationSystem


signal reputation_changed(npc_id: String, reputation: int)
signal reputation_milestone_reached(npc_id: String, milestone: String)


var npc_system: NPCSystem
var reputation_data: Dictionary = {}


class NPCReputation:
	var npc_id: String
	var reputation: int = 0
	var last_interaction_tick: int = 0
	var interaction_count: int = 0
	var relationship_tier: String = "stranger"
	
	func _init(p_npc_id: String) -> void:
		npc_id = p_npc_id


func _init(p_npc_system: NPCSystem = null) -> void:
	if p_npc_system:
		npc_system = p_npc_system
	else:
		npc_system = NPCSystem.new()
	
	reputation_data = {}


func initialize_npc_reputation(npc_id: String) -> void:
	if not reputation_data.has(npc_id):
		var rep = NPCReputation.new(npc_id)
		reputation_data[npc_id] = rep


func add_reputation(npc_id: String, amount: int) -> void:
	if not reputation_data.has(npc_id):
		initialize_npc_reputation(npc_id)
	
	var rep = reputation_data[npc_id]
	rep.reputation = clamp(rep.reputation + amount, -100, 100)
	rep.interaction_count += 1
	
	_update_relationship_tier(npc_id)
	reputation_changed.emit(npc_id, rep.reputation)


func remove_reputation(npc_id: String, amount: int) -> void:
	add_reputation(npc_id, -amount)


func get_reputation(npc_id: String) -> int:
	if not reputation_data.has(npc_id):
		return 0
	return reputation_data[npc_id].reputation


func get_relationship_tier(npc_id: String) -> String:
	if not reputation_data.has(npc_id):
		return "stranger"
	return reputation_data[npc_id].relationship_tier


func _update_relationship_tier(npc_id: String) -> void:
	var rep = reputation_data.get(npc_id)
	if not rep:
		return
	
	var old_tier = rep.relationship_tier
	
	if rep.reputation < -50:
		rep.relationship_tier = "enemy"
	elif rep.reputation < -25:
		rep.relationship_tier = "hostile"
	elif rep.reputation < 0:
		rep.relationship_tier = "disliked"
	elif rep.reputation == 0:
		rep.relationship_tier = "stranger"
	elif rep.reputation < 25:
		rep.relationship_tier = "acquaintance"
	elif rep.reputation < 50:
		rep.relationship_tier = "friend"
	else:
		rep.relationship_tier = "ally"
	
	if old_tier != rep.relationship_tier:
		reputation_milestone_reached.emit(npc_id, rep.relationship_tier)


func calculate_price_modifier(npc_id: String) -> float:
	var reputation = get_reputation(npc_id)
	var modifier = 1.0 - (reputation / 100.0) * 0.3
	return max(0.5, min(2.0, modifier))


func can_access_dialogue_option(npc_id: String, required_reputation: int) -> bool:
	var reputation = get_reputation(npc_id)
	return reputation >= required_reputation


func get_quest_reward_modifier(npc_id: String) -> float:
	var reputation = get_reputation(npc_id)
	if reputation < 0:
		return 0.5
	elif reputation < 25:
		return 1.0
	elif reputation < 50:
		return 1.25
	else:
		return 1.5


func get_reputation_info(npc_id: String) -> Dictionary:
	if not reputation_data.has(npc_id):
		initialize_npc_reputation(npc_id)
	
	var rep = reputation_data[npc_id]
	return {
		"npc_id": npc_id,
		"reputation": rep.reputation,
		"relationship_tier": rep.relationship_tier,
		"interactions": rep.interaction_count,
		"price_modifier": calculate_price_modifier(npc_id),
		"reward_modifier": get_quest_reward_modifier(npc_id)
	}


func decay_reputation_over_time(npc_id: String, tick_delta: int, decay_rate: float = 0.01) -> void:
	var rep = reputation_data.get(npc_id)
	if rep:
		var decay_amount = int(decay_rate * (tick_delta / 1000.0) * rep.reputation.abs())
		if rep.reputation > 0:
			remove_reputation(npc_id, decay_amount)
		elif rep.reputation < 0:
			add_reputation(npc_id, decay_amount)


func get_all_reputation_data() -> Dictionary:
	var data = {}
	for npc_id in reputation_data.keys():
		data[npc_id] = reputation_data[npc_id].reputation
	return data


func reset_npc_reputation(npc_id: String) -> void:
	if reputation_data.has(npc_id):
		reputation_data[npc_id].reputation = 0
		_update_relationship_tier(npc_id)
