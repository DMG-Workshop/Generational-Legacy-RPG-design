## Faction Effects System: Apply faction effects to world gameplay
##
## Handles price modifiers, encounter generation, dialogue gating, settlement effects

extends Node

class_name FactionEffectsSystem


signal faction_price_modified(faction_id: String, modifier: float)
signal faction_encounter_affected(faction_id: String, encounter_type: String)
signal faction_settlement_affected(settlement_id: String, prosperity_delta: float)


var faction_reputation_system: FactionReputationSystem
var settlement_system: Object


func _init(p_faction_reputation_system: FactionReputationSystem = null, p_settlement_system: Object = null) -> void:
	if p_faction_reputation_system:
		faction_reputation_system = p_faction_reputation_system
	else:
		faction_reputation_system = FactionReputationSystem.new()
	
	settlement_system = p_settlement_system


func calculate_price_modifier(faction_id: String) -> float:
	var bonus = faction_reputation_system.get_faction_interaction_bonus(faction_id)
	var modifier = 2.0 - bonus
	return clamp(modifier, 0.7, 1.5)


func calculate_encounter_modifier(faction_id: String) -> float:
	var bonus = faction_reputation_system.get_faction_interaction_bonus(faction_id)
	return bonus


func calculate_settlement_prosperity_modifier(settlement_location: Vector2i, faction_id: String) -> float:
	var bonus = faction_reputation_system.get_faction_interaction_bonus(faction_id)
	return (bonus - 1.0) * 10.0


func can_access_dialogue_option(faction_id: String, required_tier: String) -> bool:
	return faction_reputation_system.can_access_faction_quest(faction_id, required_tier)


func get_faction_dialogue_options(faction_id: String) -> Array:
	var tier = faction_reputation_system.get_tier(faction_id)
	var options = []
	
	match tier:
		"hostile":
			options = ["Demand answers!", "Threaten them"]
		"unfriendly":
			options = ["What do you want?", "State your business"]
		"neutral":
			options = ["Hello", "What's new?", "Any work?"]
		"friendly":
			options = ["Good to see you", "Anything I can help with?"]
		"allied":
			options = ["My friend", "What can I do for the faction?", "How goes the cause?"]
	
	return options


func get_encounter_type_for_faction(faction_id: String) -> String:
	var tier = faction_reputation_system.get_tier(faction_id)
	var faction = faction_reputation_system.faction_system.get_faction(faction_id)
	
	match tier:
		"hostile":
			return "enemy_ambush"
		"unfriendly":
			return "enemy_patrol"
		"neutral":
			return "neutral_encounter"
		"friendly":
			return "faction_ally"
		"allied":
			return "faction_escort"
	
	return "random"


func apply_settlement_faction_bonus(settlement_id: String, faction_id: String) -> float:
	var modifier = calculate_settlement_prosperity_modifier(Vector2i.ZERO, faction_id)
	
	if settlement_system:
		settlement_system.update_settlement_prosperity(settlement_id, modifier)
	
	return modifier


func get_quest_reward_modifier(faction_id: String) -> float:
	var bonus = faction_reputation_system.get_faction_interaction_bonus(faction_id)
	return bonus


func get_faction_commerce_effect(faction_id: String) -> Dictionary:
	var tier = faction_reputation_system.get_tier(faction_id)
	var price_mod = calculate_price_modifier(faction_id)
	
	var effect = {
		"tier": tier,
		"price_modifier": price_mod,
		"discount": max(0.0, (1.0 - price_mod) * 100.0),
		"markup": max(0.0, (price_mod - 1.0) * 100.0)
	}
	
	return effect


func get_faction_combat_effect(faction_id: String) -> Dictionary:
	var tier = faction_reputation_system.get_tier(faction_id)
	var encounter_mod = calculate_encounter_modifier(faction_id)
	
	return {
		"tier": tier,
		"encounter_modifier": encounter_mod,
		"difficulty_adjustment": (encounter_mod - 1.0) * 0.25,
		"reward_multiplier": encounter_mod
	}


func get_faction_npc_reaction(npc_faction_id: String, player_faction_id: String) -> String:
	var faction_system = faction_reputation_system.faction_system
	var relation = faction_system.get_faction_relation(npc_faction_id, player_faction_id)
	
	if relation < -50:
		return "hostile"
	elif relation < -25:
		return "cold"
	elif relation < 25:
		return "neutral"
	elif relation < 50:
		return "warm"
	else:
		return "friendly"


func get_all_faction_effects() -> Dictionary:
	var effects = {}
	
	for faction in faction_reputation_system.faction_system.get_all_factions():
		effects[faction.id] = {
			"standing": faction_reputation_system.get_faction_standing_info(faction.id),
			"commerce": get_faction_commerce_effect(faction.id),
			"combat": get_faction_combat_effect(faction.id)
		}
	
	return effects
