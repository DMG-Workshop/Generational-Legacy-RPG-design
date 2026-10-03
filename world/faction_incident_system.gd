## Faction Incident System: Diplomatic events and escalation
##
## Manages incidents, conflicts, truces, and their consequences

extends Node

class_name FactionIncidentSystem


signal incident_created(incident_id: String, incident_type: String)
signal incident_escalated(incident_id: String, new_level: String)
signal incident_resolved(incident_id: String, resolution: String)


enum IncidentType { WAR_DECLARATION, ALLIANCE_FORMED, BETRAYAL, TRUCE, PEACE_TREATY, TRADE_DISPUTE }
enum EscalationLevel { TENSION, CONFLICT, CEASEFIRE, RESOLVED }

var faction_system: FactionSystem
var incidents: Dictionary = {}
var incident_counter: int = 0


class Incident:
	var id: String
	var type: int
	var faction1: String
	var faction2: String
	var escalation_level: int = EscalationLevel.TENSION
	var created_at_tick: int = 0
	var last_event_tick: int = 0
	var consequences: Array = []
	var affected_settlements: Array = []
	
	func _init(p_id: String, p_type: int, p_f1: String, p_f2: String) -> void:
		id = p_id
		type = p_type
		faction1 = p_f1
		faction2 = p_f2


func _init(p_faction_system: FactionSystem = null) -> void:
	if p_faction_system:
		faction_system = p_faction_system
	else:
		faction_system = FactionSystem.new()
	
	incidents = {}
	incident_counter = 0


func create_incident(incident_type: int, faction1_id: String, faction2_id: String) -> String:
	var incident_id = "incident_%d_%s_%s" % [incident_counter, faction1_id, faction2_id]
	incident_counter += 1
	
	var incident = Incident.new(incident_id, incident_type, faction1_id, faction2_id)
	incidents[incident_id] = incident
	
	_apply_incident_effects(incident_id)
	incident_created.emit(incident_id, IncidentType.keys()[incident_type])
	
	return incident_id


func get_incident(incident_id: String) -> Incident:
	return incidents.get(incident_id)


func escalate_incident(incident_id: String) -> void:
	var incident = incidents.get(incident_id)
	if not incident:
		return
	
	var old_level = incident.escalation_level
	incident.escalation_level = min(incident.escalation_level + 1, EscalationLevel.RESOLVED)
	
	_apply_escalation_effects(incident_id)
	incident_escalated.emit(incident_id, EscalationLevel.keys()[incident.escalation_level])


func resolve_incident(incident_id: String, resolution_type: String) -> void:
	var incident = incidents.get(incident_id)
	if not incident:
		return
	
	incident.escalation_level = EscalationLevel.RESOLVED
	_clear_incident_effects(incident_id)
	incident_resolved.emit(incident_id, resolution_type)


func _apply_incident_effects(incident_id: String) -> void:
	var incident = incidents.get(incident_id)
	if not incident:
		return
	
	match incident.type:
		IncidentType.WAR_DECLARATION:
			faction_system.declare_war(incident.faction1, incident.faction2)
		IncidentType.ALLIANCE_FORMED:
			faction_system.form_alliance(incident.faction1, incident.faction2)
		IncidentType.BETRAYAL:
			faction_system.declare_war(incident.faction1, incident.faction2)
		IncidentType.TRUCE:
			faction_system.declare_truce(incident.faction1, incident.faction2)


func _apply_escalation_effects(incident_id: String) -> void:
	var incident = incidents.get(incident_id)
	if not incident:
		return
	
	match incident.escalation_level:
		EscalationLevel.TENSION:
			incident.consequences.append("Diplomatic tensions rise")
		EscalationLevel.CONFLICT:
			incident.consequences.append("Armed conflict breaks out")
			incident.consequences.append("Settlement prosperity affected")
		EscalationLevel.CEASEFIRE:
			incident.consequences.append("Ceasefire declared")


func _clear_incident_effects(incident_id: String) -> void:
	var incident = incidents.get(incident_id)
	if incident:
		incident.consequences.clear()
		incident.affected_settlements.clear()


func get_active_incidents() -> Array:
	var active = []
	for incident in incidents.values():
		if incident.escalation_level != EscalationLevel.RESOLVED:
			active.append(incident)
	return active


func get_incidents_between_factions(faction1_id: String, faction2_id: String) -> Array:
	var relevant = []
	for incident in incidents.values():
		if (incident.faction1 == faction1_id and incident.faction2 == faction2_id) or \
		   (incident.faction1 == faction2_id and incident.faction2 == faction1_id):
			relevant.append(incident)
	return relevant


func get_incident_impact(incident_id: String) -> Dictionary:
	var incident = incidents.get(incident_id)
	if not incident:
		return {}
	
	var impact_level = incident.escalation_level / float(EscalationLevel.RESOLVED)
	
	return {
		"incident_id": incident_id,
		"type": IncidentType.keys()[incident.type],
		"factions": [incident.faction1, incident.faction2],
		"escalation": EscalationLevel.keys()[incident.escalation_level],
		"impact_level": impact_level,
		"consequences": incident.consequences.duplicate(),
		"affected_settlements": incident.affected_settlements.duplicate()
	}


func mark_settlement_affected(incident_id: String, settlement_id: String) -> void:
	var incident = incidents.get(incident_id)
	if incident and settlement_id not in incident.affected_settlements:
		incident.affected_settlements.append(settlement_id)


func get_incident_prosperity_modifier(incident_id: String) -> float:
	var incident = incidents.get(incident_id)
	if not incident:
		return 0.0
	
	match incident.escalation_level:
		EscalationLevel.TENSION:
			return -2.0
		EscalationLevel.CONFLICT:
			return -10.0
		EscalationLevel.CEASEFIRE:
			return -5.0
		_:
			return 0.0
	
	return 0.0


func get_incident_history() -> Dictionary:
	var history = {}
	for incident_id in incidents.keys():
		history[incident_id] = get_incident_impact(incident_id)
	return history
