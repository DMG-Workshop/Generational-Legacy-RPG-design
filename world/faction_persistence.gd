## Faction Persistence: Save and load faction state across generations
##
## Serializes faction standings, incidents, and relationships for continuity

extends Node

class_name FactionPersistence


signal faction_state_saved()
signal faction_state_loaded()


var faction_system: FactionSystem
var faction_reputation_system: FactionReputationSystem
var faction_incident_system: FactionIncidentSystem
var saved_state: Dictionary = {}


func _init(p_faction_system: FactionSystem = null, p_reputation_system: FactionReputationSystem = null, p_incident_system: FactionIncidentSystem = null) -> void:
	if p_faction_system:
		faction_system = p_faction_system
	else:
		faction_system = FactionSystem.new()
	
	if p_reputation_system:
		faction_reputation_system = p_reputation_system
	else:
		faction_reputation_system = FactionReputationSystem.new()
	
	if p_incident_system:
		faction_incident_system = p_incident_system
	else:
		faction_incident_system = FactionIncidentSystem.new()


func save_faction_state() -> Dictionary:
	var standings = {}
	for faction_id in faction_reputation_system.standing_history.keys():
		var standing = faction_reputation_system.standing_history[faction_id]
		standings[faction_id] = {
			"standing": standing.standing,
			"interactions": standing.interaction_count,
			"tier": standing.current_tier
		}
	
	var incidents_data = {}
	for incident_id in faction_incident_system.incidents.keys():
		var incident = faction_incident_system.incidents[incident_id]
		incidents_data[incident_id] = {
			"type": FactionIncidentSystem.IncidentType.keys()[incident.type],
			"faction1": incident.faction1,
			"faction2": incident.faction2,
			"escalation": FactionIncidentSystem.EscalationLevel.keys()[incident.escalation_level],
			"consequences": incident.consequences.duplicate(),
			"affected_settlements": incident.affected_settlements.duplicate()
		}
	
	var state = {
		"standings": standings,
		"incidents": incidents_data,
		"faction_relations": faction_system.faction_relations.duplicate()
	}
	
	saved_state = state
	faction_state_saved.emit()
	return state


func load_faction_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	
	var standings = state.get("standings", {})
	for faction_id in standings.keys():
		if faction_reputation_system.standing_history.has(faction_id):
			var standing = faction_reputation_system.standing_history[faction_id]
			standing.standing = standings[faction_id].get("standing", 0)
			standing.interaction_count = standings[faction_id].get("interactions", 0)
			standing.current_tier = standings[faction_id].get("tier", "neutral")
	
	var relations = state.get("faction_relations", {})
	for key in relations.keys():
		faction_system.faction_relations[key] = relations[key]
	
	faction_state_loaded.emit()


func export_faction_history() -> Dictionary:
	var history = {
		"current_standings": faction_reputation_system.get_all_standings(),
		"allied_factions": faction_reputation_system.get_allied_factions(),
		"hostile_factions": faction_reputation_system.get_hostile_factions(),
		"dominant_faction": faction_reputation_system.get_dominant_faction(),
		"incidents": faction_incident_system.get_incident_history()
	}
	
	return history


func get_saved_state() -> Dictionary:
	return saved_state.duplicate(true)


func clear_saved_state() -> void:
	saved_state.clear()


func transfer_faction_state_to_next_generation() -> Dictionary:
	var current_state = save_faction_state()
	
	for faction_id in faction_reputation_system.standing_history.keys():
		var standing = faction_reputation_system.standing_history[faction_id]
		standing.standing = int(standing.standing * 0.9)
		faction_reputation_system._update_tier(faction_id)
	
	return current_state


func reset_incident_history() -> void:
	faction_incident_system.incidents.clear()
	faction_incident_system.incident_counter = 0


func resolve_all_active_incidents(resolution: String = "truce") -> void:
	var active = faction_incident_system.get_active_incidents()
	for incident in active:
		faction_incident_system.resolve_incident(incident.id, resolution)


func get_faction_legacy(faction_id: String) -> Dictionary:
	var reputation = faction_reputation_system.get_faction_standing_info(faction_id)
	var incidents = faction_incident_system.get_incidents_between_factions(faction_id, "")
	
	return {
		"faction_id": faction_id,
		"final_standing": reputation["standing"],
		"final_tier": reputation["tier"],
		"interactions": reputation["interactions"],
		"incident_count": incidents.size()
	}
