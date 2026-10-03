## Environmental Event System: Generates and manages world events
##
## Handles event scheduling, probability, and cascading effects

extends Node

class_name EnvironmentalEventSystem


signal event_created(event_id: String, event_type: String)
signal event_resolved(event_id: String)
signal event_spread(from_location: Vector2i, to_location: Vector2i)


enum EventType { DISASTER, RESOURCE_BOOM, ANOMALY }

var events: Dictionary = {}
var event_counter: int = 0
var event_history: Array = []


class Event:
	var id: String
	var event_type: int
	var location: Vector2i
	var epicenter: Vector2i
	var radius: int = 50
	var severity: int = 1
	var duration: int = 1000
	var elapsed_time: int = 0
	var created_at_tick: int = 0
	var affected_locations: Array = []
	var data: Dictionary = {}
	
	func _init(p_id: String, p_type: int, p_location: Vector2i) -> void:
		id = p_id
		event_type = p_type
		location = p_location
		epicenter = p_location


func _init() -> void:
	events = {}
	event_counter = 0
	event_history = []


func generate_event(event_type: int, location: Vector2i, severity: int = 1) -> String:
	var event_id = "event_%d_%d_%d" % [event_counter, location.x, location.y]
	event_counter += 1
	
	var event = Event.new(event_id, event_type, location)
	event.severity = clamp(severity, 1, 5)
	event.radius = 30 + (severity * 10)
	event.duration = 500 + (severity * 300)
	
	events[event_id] = event
	event_history.append(event_id)
	event_created.emit(event_id, EventType.keys()[event_type])
	
	return event_id


func get_event(event_id: String) -> Event:
	return events.get(event_id)


func process_event_time(event_id: String, tick_delta: int) -> void:
	var event = events.get(event_id)
	if not event:
		return
	
	event.elapsed_time += tick_delta
	
	if event.elapsed_time >= event.duration:
		resolve_event(event_id)


func resolve_event(event_id: String) -> void:
	if events.has(event_id):
		events.erase(event_id)
		event_resolved.emit(event_id)


func get_active_events() -> Array:
	return events.values()


func get_events_at_location(location: Vector2i, radius: int = 50) -> Array:
	var nearby = []
	for event in events.values():
		var distance = event.location.distance_to(location)
		if distance <= radius:
			nearby.append(event)
	return nearby


func get_events_by_type(event_type: int) -> Array:
	var of_type = []
	for event in events.values():
		if event.event_type == event_type:
			of_type.append(event)
	return of_type


func is_location_affected(location: Vector2i) -> bool:
	for event in events.values():
		if event.location.distance_to(location) <= event.radius:
			return true
	return false


func get_event_impact_at_location(location: Vector2i) -> Dictionary:
	var impacts = {}
	
	for event in events.values():
		var distance = event.location.distance_to(location)
		if distance <= event.radius:
			var intensity = 1.0 - (distance / event.radius)
			impacts[event.id] = {
				"type": EventType.keys()[event.event_type],
				"severity": event.severity,
				"intensity": intensity,
				"distance": distance
			}
	
	return impacts


func spread_event(from_event_id: String, to_location: Vector2i) -> void:
	var event = events.get(from_event_id)
	if event:
		event_spread.emit(event.location, to_location)


func get_event_info(event_id: String) -> Dictionary:
	var event = events.get(event_id)
	if not event:
		return {}
	
	return {
		"id": event.id,
		"type": EventType.keys()[event.event_type],
		"location": event.location,
		"severity": event.severity,
		"radius": event.radius,
		"duration_remaining": event.duration - event.elapsed_time,
		"progress": event.elapsed_time / float(event.duration)
	}


func get_event_history() -> Array:
	return event_history.duplicate()


func clear_old_events(max_history: int = 100) -> void:
	if event_history.size() > max_history:
		event_history = event_history.slice(event_history.size() - max_history)
