## Historical Event Tracker: Record and track major events that shape dynasty legacy
##
## Maintains historical records of significant dynasty actions, their consequences,
## and how they cascade through generations affecting world state and faction standings.

extends Node

class_name HistoricalEventTracker


signal event_recorded(event_id: String, generation: int)
signal consequence_triggered(event_id: String, consequence_type: String)
signal history_milestone_reached(milestone_type: String, generation: int)


enum EventType { COMBAT_VICTORY, QUEST_COMPLETION, FACTION_ACTION, REALM_UNLOCK, LEGENDARY_DEFEAT, PROPHECY_FULFILLED, CURSE_LIFTED }
enum EventSeverity { MINOR, MODERATE, MAJOR, CRITICAL }


var all_events: Array = []  # Complete historical record
var event_index: Dictionary = {}  # generation -> [events]
var consequence_log: Dictionary = {}  # event_id -> [consequences]


class HistoricalEvent:
	var event_id: String
	var event_type: int
	var severity: int
	var generation: int
	var title: String
	var description: String
	var involved_heir: String
	var faction_affected: String
	var reputation_impact: int
	var prestige_impact: int
	var world_impact: String
	var cascading_consequences: Array
	var timestamp: float

	func _init(p_type: int, p_gen: int) -> void:
		event_id = "event_%d_%d" % [p_gen, randi()]
		event_type = p_type
		severity = EventSeverity.MINOR
		generation = p_gen
		title = ""
		description = ""
		involved_heir = ""
		faction_affected = ""
		reputation_impact = 0
		prestige_impact = 0
		world_impact = ""
		cascading_consequences = []
		timestamp = Time.get_ticks_msec()


class EventConsequence:
	var consequence_id: String
	var source_event_id: String
	var consequence_type: String  # "reputation", "prestige", "trait", "ability", "world_state"
	var trigger_generation: int
	var target_faction: String
	var value_change: int
	var duration_generations: int

	func _init(p_event_id: String, p_type: String) -> void:
		consequence_id = "consequence_%s_%d" % [p_event_id, randi()]
		source_event_id = p_event_id
		consequence_type = p_type
		trigger_generation = 0
		target_faction = ""
		value_change = 0
		duration_generations = 5


func _init() -> void:
	pass


func record_event(event_type: int, generation: int, heir_id: String) -> HistoricalEvent:
	var event = HistoricalEvent.new(event_type, generation)
	event.involved_heir = heir_id
	event.severity = _determine_severity(event_type, generation)

	all_events.append(event)

	# Index by generation for quick lookup
	if generation not in event_index:
		event_index[generation] = []
	event_index[generation].append(event)

	event_recorded.emit(event.event_id, generation)
	return event


func add_event_consequence(event_id: String, consequence_type: String, trigger_generation: int, target_faction: String = "", value_change: int = 0) -> EventConsequence:
	var consequence = EventConsequence.new(event_id, consequence_type)
	consequence.trigger_generation = trigger_generation
	consequence.target_faction = target_faction
	consequence.value_change = value_change

	if event_id not in consequence_log:
		consequence_log[event_id] = []

	consequence_log[event_id].append(consequence)
	consequence_triggered.emit(event_id, consequence_type)

	return consequence


func get_events_at_generation(generation: int) -> Array:
	if generation in event_index:
		return event_index[generation].duplicate()
	return []


func get_events_in_range(start_gen: int, end_gen: int) -> Array:
	var results = []
	for gen in range(start_gen, end_gen + 1):
		if gen in event_index:
			results.append_array(event_index[gen])
	return results


func get_events_by_type(event_type: int) -> Array:
	var results = []
	for event in all_events:
		if event.event_type == event_type:
			results.append(event)
	return results


func get_events_by_severity(severity: int) -> Array:
	var results = []
	for event in all_events:
		if event.severity == severity:
			results.append(event)
	return results


func get_faction_events(faction_id: String) -> Array:
	var results = []
	for event in all_events:
		if event.faction_affected == faction_id:
			results.append(event)
	return results


func get_consequences_for_event(event_id: String) -> Array:
	if event_id in consequence_log:
		return consequence_log[event_id].duplicate()
	return []


func get_heir_history(heir_id: String) -> Array:
	var results = []
	for event in all_events:
		if event.involved_heir == heir_id:
			results.append(event)
	return results


func get_most_impactful_events(limit: int = 10) -> Array:
	var sorted_events = all_events.duplicate()

	# Sort by prestige impact + reputation impact
	sorted_events.sort_custom(func(a: HistoricalEvent, b: HistoricalEvent):
		var impact_a = abs(a.prestige_impact) + abs(a.reputation_impact)
		var impact_b = abs(b.prestige_impact) + abs(b.reputation_impact)
		return impact_a > impact_b
	)

	return sorted_events.slice(0, min(limit, sorted_events.size()))


func check_history_milestones(generation: int) -> Array:
	var milestones = []

	# Check major event counts
	if all_events.size() == 100:
		history_milestone_reached.emit("100_events_recorded", generation)
		milestones.append("100_events_recorded")

	if all_events.size() == 500:
		history_milestone_reached.emit("500_events_recorded", generation)
		milestones.append("500_events_recorded")

	if all_events.size() == 1000:
		history_milestone_reached.emit("1000_events_recorded", generation)
		milestones.append("1000_events_recorded")

	# Check for perfect generations (no negative events)
	var gen_events = get_events_at_generation(generation)
	var has_negative = false
	for event in gen_events:
		if event.severity == EventSeverity.CRITICAL and event.prestige_impact < 0:
			has_negative = true
			break

	if gen_events.size() > 0 and not has_negative:
		history_milestone_reached.emit("perfect_generation", generation)
		milestones.append("perfect_generation")

	return milestones


func get_historical_summary(start_gen: int, end_gen: int) -> Dictionary:
	var summary = {
		"generation_range": {"start": start_gen, "end": end_gen},
		"total_events": 0,
		"events_by_type": {},
		"total_prestige_impact": 0,
		"total_reputation_impact": 0,
		"critical_events": [],
		"major_events": [],
		"affected_factions": []
	}

	var events = get_events_in_range(start_gen, end_gen)

	for event in events:
		summary["total_events"] += 1
		summary["total_prestige_impact"] += event.prestige_impact
		summary["total_reputation_impact"] += event.reputation_impact

		# Count by type
		var type_name = _get_event_type_name(event.event_type)
		summary["events_by_type"][type_name] = summary["events_by_type"].get(type_name, 0) + 1

		# Track critical/major events
		if event.severity == EventSeverity.CRITICAL:
			summary["critical_events"].append({
				"generation": event.generation,
				"title": event.title,
				"impact": event.prestige_impact
			})

		if event.severity == EventSeverity.MAJOR:
			summary["major_events"].append({
				"generation": event.generation,
				"title": event.title
			})

		# Track affected factions
		if event.faction_affected and event.faction_affected not in summary["affected_factions"]:
			summary["affected_factions"].append(event.faction_affected)

	return summary


func export_historical_record() -> Dictionary:
	var record = {
		"total_events": all_events.size(),
		"events": [],
		"timeline": {}
	}

	for event in all_events:
		record["events"].append({
			"event_id": event.event_id,
			"generation": event.generation,
			"title": event.title,
			"description": event.description,
			"type": _get_event_type_name(event.event_type),
			"severity": _get_severity_name(event.severity),
			"prestige_impact": event.prestige_impact,
			"reputation_impact": event.reputation_impact,
			"consequences": get_consequences_for_event(event.event_id).size()
		})

		# Index by generation
		if event.generation not in record["timeline"]:
			record["timeline"][event.generation] = []
		record["timeline"][event.generation].append(event.title)

	return record


func _determine_severity(event_type: int, generation: int) -> int:
	match event_type:
		EventType.COMBAT_VICTORY:
			return EventSeverity.MINOR
		EventType.QUEST_COMPLETION:
			return EventSeverity.MODERATE
		EventType.FACTION_ACTION:
			return EventSeverity.MODERATE
		EventType.REALM_UNLOCK:
			return EventSeverity.MAJOR
		EventType.LEGENDARY_DEFEAT:
			return EventSeverity.MAJOR
		EventType.PROPHECY_FULFILLED:
			return EventSeverity.CRITICAL
		EventType.CURSE_LIFTED:
			return EventSeverity.MODERATE
		_:
			return EventSeverity.MINOR


func _get_event_type_name(event_type: int) -> String:
	match event_type:
		EventType.COMBAT_VICTORY:
			return "Combat Victory"
		EventType.QUEST_COMPLETION:
			return "Quest Completion"
		EventType.FACTION_ACTION:
			return "Faction Action"
		EventType.REALM_UNLOCK:
			return "Realm Unlock"
		EventType.LEGENDARY_DEFEAT:
			return "Legendary Defeat"
		EventType.PROPHECY_FULFILLED:
			return "Prophecy Fulfilled"
		EventType.CURSE_LIFTED:
			return "Curse Lifted"
		_:
			return "Unknown"


func _get_severity_name(severity: int) -> String:
	match severity:
		EventSeverity.MINOR:
			return "Minor"
		EventSeverity.MODERATE:
			return "Moderate"
		EventSeverity.MAJOR:
			return "Major"
		EventSeverity.CRITICAL:
			return "Critical"
		_:
			return "Unknown"
