## Event Persistence: Save/load event state across generations
##
## Serializes disasters, resource booms, anomalies, and active event tracking

extends Node

class_name EventPersistence


signal event_state_saved
signal event_state_loaded


func save_event_state(
	environmental_event_system: EnvironmentalEventSystem,
	disaster_system: DisasterSystem,
	resource_boom_system: ResourceBoomSystem,
	anomaly_system: AnomalySystem
) -> Dictionary:
	var state = {
		"events": [],
		"disasters": [],
		"booms": [],
		"anomalies": [],
		"event_counter": environmental_event_system.event_counter if environmental_event_system.has_meta("event_counter") else 0,
		"disaster_counter": disaster_system.disaster_counter if disaster_system.has_meta("disaster_counter") else 0,
		"boom_counter": resource_boom_system.boom_counter if resource_boom_system.has_meta("boom_counter") else 0,
		"anomaly_counter": anomaly_system.anomaly_counter if anomaly_system.has_meta("anomaly_counter") else 0
	}

	# Save events from environmental system
	for event_id in environmental_event_system.active_events.keys():
		var event = environmental_event_system.active_events[event_id]
		state["events"].append({
			"id": event.id,
			"type": event.event_type,
			"location": {"x": event.location.x, "y": event.location.y},
			"epicenter": {"x": event.epicenter.x, "y": event.epicenter.y},
			"radius": event.radius,
			"severity": event.severity,
			"duration": event.duration,
			"elapsed_time": event.elapsed_time,
			"affected_locations": event.affected_locations.duplicate(),
			"data": event.data.duplicate()
		})

	# Save disasters
	for disaster_id in disaster_system.active_disasters.keys():
		var disaster = disaster_system.active_disasters[disaster_id]
		state["disasters"].append({
			"id": disaster.id,
			"type": disaster.disaster_type,
			"location": {"x": disaster.location.x, "y": disaster.location.y},
			"severity": disaster.severity,
			"affected_settlements": disaster.affected_settlements.duplicate(),
			"affected_npcs": disaster.affected_npcs.duplicate(),
			"damage_dealt": disaster.damage_dealt.duplicate(),
			"recovery_progress": disaster.recovery_progress.duplicate()
		})

	# Save resource booms
	for boom_id in resource_boom_system.active_booms.keys():
		var boom = resource_boom_system.active_booms[boom_id]
		state["booms"].append({
			"id": boom.id,
			"resource_type": boom.resource_type,
			"boom_type": boom.boom_type,
			"location": {"x": boom.location.x, "y": boom.location.y},
			"radius": boom.radius,
			"duration": boom.duration,
			"elapsed_time": boom.elapsed_time,
			"price_multiplier": boom.price_multiplier
		})

	# Save anomalies
	for anomaly_id in anomaly_system.active_anomalies.keys():
		var anomaly = anomaly_system.active_anomalies[anomaly_id]
		state["anomalies"].append({
			"id": anomaly.id,
			"type": anomaly.anomaly_type,
			"location": {"x": anomaly.location.x, "y": anomaly.location.y},
			"radius": anomaly.radius,
			"duration": anomaly.duration,
			"elapsed_time": anomaly.elapsed_time,
			"effects": anomaly.effects.duplicate(),
			"visitors": anomaly.visitors.duplicate()
		})

	event_state_saved.emit()
	return state


func load_event_state(
	state: Dictionary,
	environmental_event_system: EnvironmentalEventSystem,
	disaster_system: DisasterSystem,
	resource_boom_system: ResourceBoomSystem,
	anomaly_system: AnomalySystem
) -> void:
	if not state:
		event_state_loaded.emit()
		return

	# Restore counters
	if state.has("event_counter"):
		environmental_event_system.set_meta("event_counter", state["event_counter"])
	if state.has("disaster_counter"):
		disaster_system.set_meta("disaster_counter", state["disaster_counter"])
	if state.has("boom_counter"):
		resource_boom_system.set_meta("boom_counter", state["boom_counter"])
	if state.has("anomaly_counter"):
		anomaly_system.set_meta("anomaly_counter", state["anomaly_counter"])

	# Restore events
	for event_data in state.get("events", []):
		var event = EnvironmentalEventSystem.Event.new()
		event.id = event_data["id"]
		event.event_type = event_data["type"]
		event.location = Vector2i(event_data["location"]["x"], event_data["location"]["y"])
		event.epicenter = Vector2i(event_data["epicenter"]["x"], event_data["epicenter"]["y"])
		event.radius = event_data["radius"]
		event.severity = event_data["severity"]
		event.duration = event_data["duration"]
		event.elapsed_time = event_data["elapsed_time"]
		event.affected_locations = event_data["affected_locations"].duplicate()
		event.data = event_data["data"].duplicate()
		environmental_event_system.active_events[event.id] = event

	# Restore disasters
	for disaster_data in state.get("disasters", []):
		var disaster = DisasterSystem.Disaster.new()
		disaster.id = disaster_data["id"]
		disaster.disaster_type = disaster_data["type"]
		disaster.location = Vector2i(disaster_data["location"]["x"], disaster_data["location"]["y"])
		disaster.severity = disaster_data["severity"]
		disaster.affected_settlements = disaster_data["affected_settlements"].duplicate()
		disaster.affected_npcs = disaster_data["affected_npcs"].duplicate()
		disaster.damage_dealt = disaster_data["damage_dealt"].duplicate()
		disaster.recovery_progress = disaster_data["recovery_progress"].duplicate()
		disaster_system.active_disasters[disaster.id] = disaster

	# Restore booms
	for boom_data in state.get("booms", []):
		var boom = ResourceBoomSystem.ResourceBoom.new()
		boom.id = boom_data["id"]
		boom.resource_type = boom_data["resource_type"]
		boom.boom_type = boom_data["boom_type"]
		boom.location = Vector2i(boom_data["location"]["x"], boom_data["location"]["y"])
		boom.radius = boom_data["radius"]
		boom.duration = boom_data["duration"]
		boom.elapsed_time = boom_data["elapsed_time"]
		boom.price_multiplier = boom_data["price_multiplier"]
		resource_boom_system.active_booms[boom.id] = boom

	# Restore anomalies
	for anomaly_data in state.get("anomalies", []):
		var anomaly = AnomalySystem.Anomaly.new()
		anomaly.id = anomaly_data["id"]
		anomaly.anomaly_type = anomaly_data["type"]
		anomaly.location = Vector2i(anomaly_data["location"]["x"], anomaly_data["location"]["y"])
		anomaly.radius = anomaly_data["radius"]
		anomaly.duration = anomaly_data["duration"]
		anomaly.elapsed_time = anomaly_data["elapsed_time"]
		anomaly.effects = anomaly_data["effects"].duplicate()
		anomaly.visitors = anomaly_data["visitors"].duplicate()
		anomaly_system.active_anomalies[anomaly.id] = anomaly

	event_state_loaded.emit()


func transfer_event_state_to_next_generation(
	state: Dictionary
) -> Dictionary:
	var new_state = {
		"events": [],
		"disasters": [],
		"booms": [],
		"anomalies": [],
		"event_counter": state.get("event_counter", 0),
		"disaster_counter": state.get("disaster_counter", 0),
		"boom_counter": state.get("boom_counter", 0),
		"anomaly_counter": state.get("anomaly_counter", 0)
	}

	# Transfer only unresolved disasters with recovery in progress
	for disaster_data in state.get("disasters", []):
		if disaster_data["recovery_progress"]:
			var has_recovery = false
			for settlement_id in disaster_data["recovery_progress"].keys():
				if disaster_data["recovery_progress"][settlement_id] < 100:
					has_recovery = true
					break
			if has_recovery:
				var transferred = disaster_data.duplicate(true)
				transferred["recovery_progress"] = disaster_data["recovery_progress"].duplicate()
				for settlement_id in transferred["recovery_progress"].keys():
					transferred["recovery_progress"][settlement_id] *= 0.95
				new_state["disasters"].append(transferred)

	# Transfer only long-duration booms (lasting effects on economy)
	for boom_data in state.get("booms", []):
		if boom_data["elapsed_time"] < boom_data["duration"] * 0.7:
			new_state["booms"].append(boom_data.duplicate(true))

	# Anomalies generally resolve; transfer only stable ones
	for anomaly_data in state.get("anomalies", []):
		if anomaly_data["anomaly_type"] == AnomalySystem.AnomalyType.BLESSING_ZONE:
			new_state["anomalies"].append(anomaly_data.duplicate(true))

	return new_state


func resolve_all_active_events(state: Dictionary) -> void:
	state["events"] = []
	state["disasters"] = []
	state["booms"] = []
	state["anomalies"] = []


func export_event_history(state: Dictionary) -> Dictionary:
	var history = {
		"total_events": state.get("events", []).size() + state.get("disaster_counter", 0),
		"total_disasters": state.get("disaster_counter", 0),
		"total_booms": state.get("boom_counter", 0),
		"total_anomalies": state.get("anomaly_counter", 0),
		"active_disasters": state.get("disasters", []).size(),
		"active_booms": state.get("booms", []).size(),
		"active_anomalies": state.get("anomalies", []).size(),
		"disaster_types": {},
		"most_affected_locations": {},
		"event_severity_distribution": {"low": 0, "medium": 0, "high": 0}
	}

	for disaster in state.get("disasters", []):
		var dtype = DisasterSystem.DisasterType.keys()[disaster["type"]]
		if not history["disaster_types"].has(dtype):
			history["disaster_types"][dtype] = 0
		history["disaster_types"][dtype] += 1

		for affected_settlement in disaster["affected_settlements"]:
			if not history["most_affected_locations"].has(affected_settlement):
				history["most_affected_locations"][affected_settlement] = 0
			history["most_affected_locations"][affected_settlement] += 1

	for event in state.get("events", []):
		var severity = event.get("severity", 3)
		if severity <= 2:
			history["event_severity_distribution"]["low"] += 1
		elif severity == 3:
			history["event_severity_distribution"]["medium"] += 1
		else:
			history["event_severity_distribution"]["high"] += 1

	return history


func get_event_legacy(state: Dictionary) -> String:
	var history = export_event_history(state)
	var legacy = ""

	if history["total_disasters"] > 0:
		legacy += "This generation weathered %d disasters. " % history["total_disasters"]
		for dtype in history["disaster_types"].keys():
			legacy += "%s struck %d times. " % [dtype.capitalize(), history["disaster_types"][dtype]]

	if history["active_booms"] > 0:
		legacy += "The economy experienced %d market fluctuations. " % history["active_booms"]

	if history["active_anomalies"] > 0:
		legacy += "%d anomalies shaped the realm. " % history["active_anomalies"]

	return legacy if legacy else "Events left few scars upon this generation."
