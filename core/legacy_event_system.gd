## Legacy Event System: Track major world events tied to dynasty
##
## Manages legacy events and their consequences across generations

extends Node

class_name LegacyEventSystem


signal legacy_event_created(event_id: String, event_type: int)
signal legacy_event_resolved(event_id: String, generation: int)


enum EventType { PROPHECY_FULFILLMENT, DYNASTY_AWAKENING, FATE_REVERSAL, LEGACY_ECHO, WORLD_TRANSFORMATION }


var legacy_events: Dictionary = {}
var events_by_generation: Dictionary = {}
var event_counter: int = 0


class LegacyEvent:
	var id: String
	var type: int
	var name: String
	var description: String
	var affected_heirs: Array
	var generation_triggered: int
	var generation_resolved: int
	var consequences: Dictionary
	var resolved: bool

	func _init(p_id: String, p_type: int, p_name: String, p_generation: int) -> void:
		id = p_id
		type = p_type
		name = p_name
		generation_triggered = p_generation
		generation_resolved = 0
		affected_heirs = []
		consequences = {}
		resolved = false
		description = ""


func _init() -> void:
	legacy_events = {}
	events_by_generation = {}


func create_legacy_event(event_type: int, generation: int, affected_heirs: Array = [], consequences: Dictionary = {}) -> String:
	var event_id = "legacy_event_%d_%d" % [event_counter, randi()]
	event_counter += 1

	var event = LegacyEvent.new(event_id, event_type, EventType.keys()[event_type], generation)
	event.affected_heirs = affected_heirs.duplicate()
	event.consequences = consequences.duplicate()
	event.description = _get_event_description(event_type, generation)

	legacy_events[event_id] = event

	if not events_by_generation.has(generation):
		events_by_generation[generation] = []
	events_by_generation[generation].append(event_id)

	legacy_event_created.emit(event_id, event_type)
	return event_id


func resolve_legacy_event(event_id: String, generation: int) -> bool:
	var event = legacy_events.get(event_id)
	if not event or event.resolved:
		return false

	event.resolved = true
	event.generation_resolved = generation
	legacy_event_resolved.emit(event_id, generation)
	return true


func get_legacy_event(event_id: String) -> LegacyEvent:
	return legacy_events.get(event_id)


func get_events_by_generation(generation: int) -> Array:
	var event_ids = events_by_generation.get(generation, [])
	var result = []
	for event_id in event_ids:
		result.append(legacy_events[event_id])
	return result


func get_events_by_type(event_type: int) -> Array:
	var result = []
	for event in legacy_events.values():
		if event.type == event_type:
			result.append(event)
	return result


func get_events_affecting_heir(heir_id: String) -> Array:
	var result = []
	for event in legacy_events.values():
		if heir_id in event.affected_heirs:
			result.append(event)
	return result


func get_unresolved_events() -> Array:
	var result = []
	for event in legacy_events.values():
		if not event.resolved:
			result.append(event)
	return result


func get_resolved_events() -> Array:
	var result = []
	for event in legacy_events.values():
		if event.resolved:
			result.append(event)
	return result


func get_event_consequences(event_id: String) -> Dictionary:
	var event = legacy_events.get(event_id)
	if not event:
		return {}
	return event.consequences.duplicate()


func apply_event_consequences(event_id: String, heir_id: String) -> Dictionary:
	var event = legacy_events.get(event_id)
	if not event:
		return {}

	var applied = {}
	for consequence_type in event.consequences.keys():
		var value = event.consequences[consequence_type]
		applied[consequence_type] = value

	return applied


func get_event_stats() -> Dictionary:
	var stats = {
		"total_events": legacy_events.size(),
		"resolved": 0,
		"unresolved": 0,
		"by_type": {},
		"generations_affected": 0,
		"total_heirs_affected": 0
	}

	var generations_set = {}
	var heirs_set = {}

	for event in legacy_events.values():
		var type_name = EventType.keys()[event.type]
		if not stats["by_type"].has(type_name):
			stats["by_type"][type_name] = {"total": 0, "resolved": 0}

		stats["by_type"][type_name]["total"] += 1

		if event.resolved:
			stats["resolved"] += 1
			stats["by_type"][type_name]["resolved"] += 1
		else:
			stats["unresolved"] += 1

		generations_set[event.generation_triggered] = true
		for heir in event.affected_heirs:
			heirs_set[heir] = true

	stats["generations_affected"] = generations_set.size()
	stats["total_heirs_affected"] = heirs_set.size()

	return stats


func export_event_history() -> Dictionary:
	var history = {
		"total_events": legacy_events.size(),
		"resolved_events": 0,
		"event_timeline": [],
		"most_impactful_generation": 0,
		"max_events_in_generation": 0,
		"total_affected_heirs": {}
	}

	var generation_event_counts = {}

	for event in legacy_events.values():
		if event.resolved:
			history["resolved_events"] += 1

		var gen = event.generation_triggered
		if not generation_event_counts.has(gen):
			generation_event_counts[gen] = 0
		generation_event_counts[gen] += 1

		for heir in event.affected_heirs:
			if not history["total_affected_heirs"].has(heir):
				history["total_affected_heirs"][heir] = 0
			history["total_affected_heirs"][heir] += 1

		history["event_timeline"].append({
			"generation": gen,
			"type": EventType.keys()[event.type],
			"resolved": event.resolved,
			"affected_heirs": event.affected_heirs.size()
		})

	# Find most impactful generation
	var max_count = 0
	for gen in generation_event_counts.keys():
		if generation_event_counts[gen] > max_count:
			max_count = generation_event_counts[gen]
			history["most_impactful_generation"] = gen

	history["max_events_in_generation"] = max_count

	return history


func get_legacy_event_legacy() -> String:
	var total = legacy_events.size()
	if total == 0:
		return "No major legacy events have yet shaped this dynasty's history."

	var resolved = 0
	for event in legacy_events.values():
		if event.resolved:
			resolved += 1

	var legacy = "The dynasty has been shaped by %d major legacy events. " % total

	if resolved > 0:
		legacy += "%d of these events have come to their resolution. " % resolved

	var prophecy_fulfillments = get_events_by_type(EventType.PROPHECY_FULFILLMENT)
	if prophecy_fulfillments.size() > 0:
		legacy += "Their destiny has been marked by fulfilled prophecies. "

	var world_transformations = get_events_by_type(EventType.WORLD_TRANSFORMATION)
	if world_transformations.size() > 0:
		legacy += "Through their actions, they have transformed the very world. "

	return legacy


func _get_event_description(event_type: int, generation: int) -> String:
	match event_type:
		EventType.PROPHECY_FULFILLMENT:
			return "An ancient prophecy comes to fruition, shaping the dynasty's destiny."
		EventType.DYNASTY_AWAKENING:
			return "The true power of the dynasty awakens, revealing hidden potential."
		EventType.FATE_REVERSAL:
			return "A moment of dramatic reversal: the dynasty's fate shifts unexpectedly."
		EventType.LEGACY_ECHO:
			return "Echoes of the dynasty's past ancestors influence the present."
		EventType.WORLD_TRANSFORMATION:
			return "Through the dynasty's actions, the world itself is transformed."
		_:
			return "A significant event shapes the dynasty's legacy."
