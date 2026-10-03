## World Event Prestige Scaling: Scale events by prestige tier
##
## Adjusts prophecy difficulty, legacy event consequences, and faction events based on prestige

extends Node

class_name WorldEventPrestigeScaling


signal event_difficulty_scaled(event_id: String, difficulty: float)
signal event_consequence_magnitude_scaled(event_id: String, magnitude: float)
signal faction_event_triggered(faction_id: String, event_difficulty: float)


var event_base_difficulties: Dictionary = {}
var faction_event_scaling: Dictionary = {}


class ScaledEvent:
	var event_id: String
	var event_type: String
	var base_difficulty: float
	var scaled_difficulty: float
	var prestige_multiplier: float
	var consequence_magnitude: float
	var reward_scaling: float

	func _init(p_id: String, p_type: String, p_base_diff: float) -> void:
		event_id = p_id
		event_type = p_type
		base_difficulty = p_base_diff
		scaled_difficulty = p_base_diff
		prestige_multiplier = 1.0
		consequence_magnitude = 1.0
		reward_scaling = 1.0


class FactionEventInstance:
	var faction_id: String
	var event_type: String
	var difficulty: float
	var standing_impact: int
	var prestige_reward: int
	var cooldown_duration: int

	func _init(p_faction_id: String, p_type: String, p_difficulty: float) -> void:
		faction_id = p_faction_id
		event_type = p_type
		difficulty = p_difficulty
		standing_impact = int(100 * p_difficulty)
		prestige_reward = int(50 * p_difficulty)
		cooldown_duration = 5  # turns


func _init() -> void:
	_initialize_event_difficulties()
	_initialize_faction_events()


func scale_prophecy_difficulty(base_difficulty: float, prestige_amount: int) -> float:
	var prestige_tiers = prestige_amount / 5000
	var scaling = 1.0 + (prestige_tiers * 0.15)
	scaling = clamp(scaling, 0.8, 3.0)

	var scaled = base_difficulty * scaling
	event_difficulty_scaled.emit("prophecy", scaled)
	return scaled


func scale_legacy_event_consequences(base_consequences: Dictionary, prestige_amount: int) -> Dictionary:
	var prestige_tiers = prestige_amount / 5000
	var magnitude = 1.0 + (prestige_tiers * 0.2)
	magnitude = clamp(magnitude, 1.0, 3.0)

	var scaled_consequences = {}

	for consequence_type in base_consequences.keys():
		var base_value = base_consequences[consequence_type]

		if consequence_type == "prestige_bonus" or consequence_type == "prosperity_change":
			scaled_consequences[consequence_type] = int(base_value * magnitude)
		else:
			scaled_consequences[consequence_type] = base_value

	event_consequence_magnitude_scaled.emit("legacy_event", magnitude)
	return scaled_consequences


func scale_faction_standing_event(faction_id: String, base_standing_impact: int, prestige_amount: int) -> FactionEventInstance:
	var prestige_tiers = prestige_amount / 5000
	var difficulty = 1.0 + (prestige_tiers * 0.1)
	difficulty = clamp(difficulty, 0.5, 2.0)

	var event = FactionEventInstance.new(faction_id, "standing_challenge", difficulty)
	event.standing_impact = int(base_standing_impact * difficulty)
	event.prestige_reward = int(50 * difficulty)

	faction_event_triggered.emit(faction_id, difficulty)
	return event


func calculate_world_event_encounter_difficulty(event_tier: int, prestige_amount: int) -> float:
	# World events have inherent tier difficulty
	var base_difficulty = 1.0 + (event_tier * 0.25)

	# Scale with prestige
	var prestige_tiers = prestige_amount / 5000
	var prestige_scaling = 1.0 + (prestige_tiers * 0.1)
	prestige_scaling = clamp(prestige_scaling, 1.0, 2.5)

	return base_difficulty * prestige_scaling


func get_event_reward_scaling(event_type: String, prestige_amount: int) -> float:
	var prestige_tiers = prestige_amount / 5000
	var scaling = 1.0 + (prestige_tiers * 0.15)

	match event_type:
		"prophecy":
			scaling = clamp(scaling, 1.0, 2.5)
		"legacy_event":
			scaling = clamp(scaling, 1.0, 3.0)
		"faction_event":
			scaling = clamp(scaling, 0.8, 2.0)
		_:
			scaling = clamp(scaling, 1.0, 2.0)

	return scaling


func calculate_prophecy_fulfillment_prestige(base_prestige: int, difficulty_multiplier: float, prestige_multiplier: float) -> int:
	var scaled = int(base_prestige * difficulty_multiplier * prestige_multiplier)
	return scaled


func should_trigger_rare_event(prestige_amount: int, base_chance: float = 0.05) -> bool:
	var prestige_tiers = prestige_amount / 5000
	var modified_chance = base_chance + (prestige_tiers * 0.02)
	modified_chance = clamp(modified_chance, 0.0, 0.4)

	return randf() < modified_chance


func get_event_consequence_description(event_type: String, consequence: Dictionary, prestige_multiplier: float) -> String:
	var desc = "Event Consequences (%s, %.2fx multiplier):\n" % [event_type, prestige_multiplier]

	for consequence_type in consequence.keys():
		var value = consequence[consequence_type]
		desc += "- %s: %s\n" % [consequence_type, str(value)]

	return desc


func get_faction_event_description(faction_event: FactionEventInstance) -> String:
	var desc = "Faction Event: %s\n" % faction_event.event_type
	desc += "- Faction: %s\n" % faction_event.faction_id
	desc += "- Difficulty: %.2fx\n" % faction_event.difficulty
	desc += "- Standing Impact: %d\n" % faction_event.standing_impact
	desc += "- Prestige Reward: %d\n" % faction_event.prestige_reward

	return desc


func get_event_scaling_stats() -> Dictionary:
	var stats = {
		"base_event_types": event_base_difficulties.size(),
		"faction_event_types": faction_event_scaling.size(),
		"prophecy_scaling_factor": 0.15,
		"legacy_event_scaling_factor": 0.2,
		"faction_event_scaling_factor": 0.1
	}

	return stats


func calculate_combined_event_difficulty(event_type: String, base_difficulty: float, prestige_amount: int, other_modifiers: float = 1.0) -> float:
	var prestige_scaling = 1.0 + (prestige_amount / 5000.0) * 0.15
	prestige_scaling = clamp(prestige_scaling, 0.5, 2.5)

	var combined = base_difficulty * prestige_scaling * other_modifiers
	return combined


func _initialize_event_difficulties() -> void:
	event_base_difficulties = {
		"prophecy_tier_1": 0.8,
		"prophecy_tier_2": 1.2,
		"prophecy_tier_3": 1.8,
		"legacy_event_minor": 0.5,
		"legacy_event_major": 1.5,
		"legacy_event_catastrophic": 2.5,
		"faction_favor": 0.3,
		"faction_challenge": 1.0,
		"world_calamity": 2.0
	}


func _initialize_faction_events() -> void:
	faction_event_scaling = {
		"council_of_kings": 1.0,
		"merchant_guilds": 0.8,
		"dark_coven": 1.2,
		"celestial_order": 0.9,
		"shadow_syndicate": 1.3,
		"druid_circle": 0.7
	}
