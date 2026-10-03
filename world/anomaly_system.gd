## Anomaly System: Temporal and spatial disturbances
##
## Manages anomalies with persistent effects and player interaction

extends Node

class_name AnomalySystem


signal anomaly_created(anomaly_id: String, anomaly_type: String)
signal anomaly_resolved(anomaly_id: String)
signal player_entered_anomaly(anomaly_id: String, effects: Dictionary)
signal player_left_anomaly(anomaly_id: String)


enum AnomalyType { TIME_RIFT, BLESSING_ZONE, CURSE_ZONE, VOID_CRACK }

var event_system: EnvironmentalEventSystem
var anomalies: Dictionary = {}


class Anomaly:
	var id: String
	var anomaly_type: int
	var location: Vector2i
	var radius: int = 40
	var duration: int = 5000
	var elapsed_time: int = 0
	var effects: Dictionary = {}
	var visitors: Array = []
	
	func _init(p_id: String, p_type: int, p_location: Vector2i) -> void:
		id = p_id
		anomaly_type = p_type
		location = p_location


func _init(p_event_system: EnvironmentalEventSystem = null) -> void:
	if p_event_system:
		event_system = p_event_system
	else:
		event_system = EnvironmentalEventSystem.new()
	
	anomalies = {}


func create_anomaly(anomaly_type: int, location: Vector2i) -> String:
	var anomaly_id = "anomaly_%d_%s" % [anomalies.size(), AnomalyType.keys()[anomaly_type].to_lower()]
	
	var anomaly = Anomaly.new(anomaly_id, anomaly_type, location)
	anomaly.effects = _generate_anomaly_effects(anomaly_type)
	
	anomalies[anomaly_id] = anomaly
	
	var event_id = event_system.generate_event(EnvironmentalEventSystem.EventType.ANOMALY, location, 1)
	anomaly_created.emit(anomaly_id, AnomalyType.keys()[anomaly_type])
	
	return anomaly_id


func _generate_anomaly_effects(anomaly_type: int) -> Dictionary:
	var effects = {}
	
	match anomaly_type:
		AnomalyType.TIME_RIFT:
			effects["time_multiplier"] = 3.0 + randf() * 2.0
		AnomalyType.BLESSING_ZONE:
			effects["stat_bonus"] = 5
			effects["blessed"] = true
		AnomalyType.CURSE_ZONE:
			effects["stat_penalty"] = -5
			effects["cursed"] = true
		AnomalyType.VOID_CRACK:
			effects["stat_penalty"] = -3
			effects["damage_taken_increase"] = 1.5
	
	return effects


func get_anomaly(anomaly_id: String) -> Anomaly:
	return anomalies.get(anomaly_id)


func process_anomaly_time(anomaly_id: String, tick_delta: int) -> void:
	var anomaly = anomalies.get(anomaly_id)
	if not anomaly:
		return
	
	anomaly.elapsed_time += tick_delta
	
	if anomaly.elapsed_time >= anomaly.duration:
		resolve_anomaly(anomaly_id)


func resolve_anomaly(anomaly_id: String) -> void:
	if anomalies.has(anomaly_id):
		anomalies.erase(anomaly_id)
		anomaly_resolved.emit(anomaly_id)


func enter_anomaly(anomaly_id: String, visitor_id: String) -> Dictionary:
	var anomaly = anomalies.get(anomaly_id)
	if not anomaly:
		return {}
	
	if visitor_id not in anomaly.visitors:
		anomaly.visitors.append(visitor_id)
	
	player_entered_anomaly.emit(anomaly_id, anomaly.effects)
	return anomaly.effects


func leave_anomaly(anomaly_id: String, visitor_id: String) -> void:
	var anomaly = anomalies.get(anomaly_id)
	if anomaly and visitor_id in anomaly.visitors:
		anomaly.visitors.erase(visitor_id)
		player_left_anomaly.emit(anomaly_id)


func get_anomalies_at_location(location: Vector2i, radius: int = 40) -> Array:
	var nearby = []
	for anomaly in anomalies.values():
		var distance = anomaly.location.distance_to(location)
		if distance <= radius:
			nearby.append(anomaly)
	return nearby


func is_location_in_anomaly(location: Vector2i) -> bool:
	for anomaly in anomalies.values():
		if anomaly.location.distance_to(location) <= anomaly.radius:
			return true
	return false


func get_anomaly_effect_at_location(location: Vector2i) -> Dictionary:
	var combined_effects = {}
	
	for anomaly in anomalies.values():
		var distance = anomaly.location.distance_to(location)
		if distance <= anomaly.radius:
			var intensity = 1.0 - (distance / anomaly.radius)
			
			for effect_key in anomaly.effects.keys():
				var value = anomaly.effects[effect_key]
				if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
					combined_effects[effect_key] = combined_effects.get(effect_key, 0) + value * intensity
				else:
					combined_effects[effect_key] = value
	
	return combined_effects


func get_anomaly_info(anomaly_id: String) -> Dictionary:
	var anomaly = anomalies.get(anomaly_id)
	if not anomaly:
		return {}
	
	return {
		"id": anomaly.id,
		"type": AnomalyType.keys()[anomaly.anomaly_type],
		"location": anomaly.location,
		"radius": anomaly.radius,
		"effects": anomaly.effects.duplicate(),
		"visitors": anomaly.visitors.duplicate(),
		"duration_remaining": anomaly.duration - anomaly.elapsed_time
	}


func get_all_anomalies() -> Array:
	return anomalies.values()


func get_anomaly_by_type(anomaly_type: int) -> Array:
	var of_type = []
	for anomaly in anomalies.values():
		if anomaly.anomaly_type == anomaly_type:
			of_type.append(anomaly)
	return of_type
