## Disaster System: Natural disasters with cascading consequences
##
## Manages disaster generation, damage calculation, and recovery

extends Node

class_name DisasterSystem


signal disaster_occurred(disaster_id: String, disaster_type: String)
signal settlement_damaged(settlement_id: String, damage: float)
signal npc_death_from_disaster(npc_id: String, disaster_type: String)
signal recovery_started(settlement_id: String)


enum DisasterType { FLOOD, EARTHQUAKE, PLAGUE, DROUGHT, METEOR }

var event_system: EnvironmentalEventSystem
var disasters: Dictionary = {}


class Disaster:
	var id: String
	var disaster_type: int
	var location: Vector2i
	var severity: int = 1
	var affected_settlements: Array = []
	var affected_npcs: Array = []
	var damage_dealt: Dictionary = {}
	var recovery_progress: Dictionary = {}
	
	func _init(p_id: String, p_type: int, p_location: Vector2i, p_severity: int) -> void:
		id = p_id
		disaster_type = p_type
		location = p_location
		severity = clamp(p_severity, 1, 5)


func _init(p_event_system: EnvironmentalEventSystem = null) -> void:
	if p_event_system:
		event_system = p_event_system
	else:
		event_system = EnvironmentalEventSystem.new()
	
	disasters = {}


func create_disaster(disaster_type: int, location: Vector2i, severity: int = 1) -> String:
	var event_id = event_system.generate_event(EnvironmentalEventSystem.EventType.DISASTER, location, severity)
	
	var disaster_id = "disaster_%d" % [disasters.size()]
	var disaster = Disaster.new(disaster_id, disaster_type, location, severity)
	disasters[disaster_id] = disaster
	
	disaster_occurred.emit(disaster_id, DisasterType.keys()[disaster_type])
	return disaster_id


func get_disaster(disaster_id: String) -> Disaster:
	return disasters.get(disaster_id)


func apply_disaster_to_settlement(disaster_id: String, settlement_id: String, settlement_system: Object) -> void:
	var disaster = disasters.get(disaster_id)
	if not disaster:
		return
	
	var damage = calculate_disaster_damage(disaster.disaster_type, disaster.severity)
	disaster.damage_dealt[settlement_id] = damage
	
	if settlement_system:
		settlement_system.update_settlement_prosperity(settlement_id, -damage)
	
	settlement_damaged.emit(settlement_id, damage)


func calculate_disaster_damage(disaster_type: int, severity: int) -> float:
	var base_damage = severity * 5
	
	match disaster_type:
		DisasterType.FLOOD:
			return base_damage * 1.2
		DisasterType.EARTHQUAKE:
			return base_damage * 1.5
		DisasterType.PLAGUE:
			return base_damage * 2.0
		DisasterType.DROUGHT:
			return base_damage * 0.8
		DisasterType.METEOR:
			return base_damage * 2.5
	
	return base_damage


func apply_disaster_to_npc(disaster_id: String, npc_id: String, npc_system: Object) -> bool:
	var disaster = disasters.get(disaster_id)
	if not disaster:
		return false
	
	var death_chance = disaster.severity * 10
	
	if randi() % 100 < death_chance:
		if npc_system:
			npc_system.kill_npc(npc_id, "disaster_%s" % DisasterType.keys()[disaster.disaster_type].to_lower())
		disaster.affected_npcs.append(npc_id)
		npc_death_from_disaster.emit(npc_id, DisasterType.keys()[disaster.disaster_type])
		return true
	
	return false


func start_recovery(disaster_id: String, settlement_id: String) -> void:
	var disaster = disasters.get(disaster_id)
	if disaster:
		disaster.recovery_progress[settlement_id] = 0.0
		recovery_started.emit(settlement_id)


func progress_recovery(disaster_id: String, settlement_id: String, progress_amount: float) -> void:
	var disaster = disasters.get(disaster_id)
	if disaster:
		var current = disaster.recovery_progress.get(settlement_id, 0.0)
		disaster.recovery_progress[settlement_id] = clamp(current + progress_amount, 0.0, 100.0)


func get_recovery_progress(disaster_id: String, settlement_id: String) -> float:
	var disaster = disasters.get(disaster_id)
	if disaster:
		return disaster.recovery_progress.get(settlement_id, 0.0)
	return 0.0


func get_disaster_description(disaster_id: String) -> String:
	var disaster = disasters.get(disaster_id)
	if not disaster:
		return ""
	
	var type_name = DisasterType.keys()[disaster.disaster_type]
	return "%s (Severity %d) at %s" % [type_name, disaster.severity, disaster.location]


func get_disaster_info(disaster_id: String) -> Dictionary:
	var disaster = disasters.get(disaster_id)
	if not disaster:
		return {}
	
	return {
		"id": disaster.id,
		"type": DisasterType.keys()[disaster.disaster_type],
		"location": disaster.location,
		"severity": disaster.severity,
		"affected_settlements": disaster.affected_settlements.size(),
		"npcs_lost": disaster.affected_npcs.size(),
		"recovery_progress": disaster.recovery_progress.duplicate()
	}


func get_all_disasters() -> Array:
	return disasters.values()


func get_disaster_consequences(disaster_id: String) -> Dictionary:
	var disaster = disasters.get(disaster_id)
	if not disaster:
		return {}
	
	var total_damage = 0.0
	for settlement_id in disaster.damage_dealt.keys():
		total_damage += disaster.damage_dealt[settlement_id]
	
	return {
		"total_damage": total_damage,
		"affected_settlements": disaster.affected_settlements.size(),
		"npcs_lost": disaster.affected_npcs.size(),
		"disaster_type": DisasterType.keys()[disaster.disaster_type]
	}
