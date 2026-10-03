## Milestone Persistence: Save/load milestone and prophecy state
##
## Serializes milestones, prophecies, and legacy events across generation boundaries

extends Node

class_name MilestonePersistence


signal milestone_state_saved
signal milestone_state_loaded


func save_milestone_state(
	milestone_system: MilestoneSystem,
	prophecy_system: ProphecySystem,
	legacy_event_system: LegacyEventSystem
) -> Dictionary:
	var state = {
		"milestones": [],
		"completed_milestones": milestone_system.completed_milestones.duplicate(),
		"active_milestones": milestone_system.active_milestones.duplicate(),
		"prophecies": [],
		"fulfilled_prophecies": prophecy_system.fulfilled_prophecies.duplicate(),
		"legacy_events": [],
		"milestone_counter": milestone_system.milestone_counter,
		"prophecy_counter": prophecy_system.prophecy_counter,
		"event_counter": legacy_event_system.event_counter
	}

	# Save milestones
	for milestone_id in milestone_system.milestones.keys():
		var milestone = milestone_system.milestones[milestone_id]
		state["milestones"].append({
			"id": milestone.id,
			"type": milestone.type,
			"generation": milestone.generation,
			"triggered": milestone.triggered,
			"triggered_at_generation": milestone.triggered_at_generation,
			"rewards": milestone.rewards.duplicate(),
			"description": milestone.description,
			"dynasty_stats": milestone.dynasty_stats.duplicate()
		})

	# Save prophecies
	for prophecy_id in prophecy_system.prophecies.keys():
		var prophecy = prophecy_system.prophecies[prophecy_id]
		state["prophecies"].append({
			"id": prophecy.id,
			"type": prophecy.type,
			"text": prophecy.text,
			"related_heir_id": prophecy.related_heir_id,
			"generation_given": prophecy.generation_given,
			"prophecy_generation": prophecy.prophecy_generation,
			"fulfilled": prophecy.fulfilled,
			"fulfilled_at_generation": prophecy.fulfilled_at_generation,
			"impact": prophecy.impact
		})

	# Save legacy events
	for event_id in legacy_event_system.legacy_events.keys():
		var event = legacy_event_system.legacy_events[event_id]
		state["legacy_events"].append({
			"id": event.id,
			"type": event.type,
			"name": event.name,
			"description": event.description,
			"affected_heirs": event.affected_heirs.duplicate(),
			"generation_triggered": event.generation_triggered,
			"generation_resolved": event.generation_resolved,
			"consequences": event.consequences.duplicate(),
			"resolved": event.resolved
		})

	milestone_state_saved.emit()
	return state


func load_milestone_state(
	state: Dictionary,
	milestone_system: MilestoneSystem,
	prophecy_system: ProphecySystem,
	legacy_event_system: LegacyEventSystem
) -> void:
	if not state:
		milestone_state_loaded.emit()
		return

	# Restore milestones
	milestone_system.milestones = {}
	for milestone_data in state.get("milestones", []):
		var milestone = MilestoneSystem.Milestone.new(
			milestone_data["id"],
			milestone_data["type"],
			milestone_data["generation"]
		)
		milestone.triggered = milestone_data.get("triggered", false)
		milestone.triggered_at_generation = milestone_data.get("triggered_at_generation", 0)
		milestone.rewards = milestone_data.get("rewards", {}).duplicate()
		milestone.description = milestone_data.get("description", "")
		milestone.dynasty_stats = milestone_data.get("dynasty_stats", {}).duplicate()

		milestone_system.milestones[milestone.id] = milestone

	milestone_system.completed_milestones = state.get("completed_milestones", []).duplicate()
	milestone_system.active_milestones = state.get("active_milestones", []).duplicate()
	milestone_system.milestone_counter = state.get("milestone_counter", 0)

	# Restore prophecies
	prophecy_system.prophecies = {}
	prophecy_system.prophecies_by_heir = {}
	for prophecy_data in state.get("prophecies", []):
		var prophecy = ProphecySystem.Prophecy.new(
			prophecy_data["id"],
			prophecy_data["type"],
			prophecy_data["text"],
			prophecy_data["generation_given"]
		)
		prophecy.related_heir_id = prophecy_data.get("related_heir_id", "")
		prophecy.prophecy_generation = prophecy_data.get("prophecy_generation", -1)
		prophecy.fulfilled = prophecy_data.get("fulfilled", false)
		prophecy.fulfilled_at_generation = prophecy_data.get("fulfilled_at_generation", 0)
		prophecy.impact = prophecy_data.get("impact", "")

		prophecy_system.prophecies[prophecy.id] = prophecy

		if prophecy.related_heir_id:
			if not prophecy_system.prophecies_by_heir.has(prophecy.related_heir_id):
				prophecy_system.prophecies_by_heir[prophecy.related_heir_id] = []
			prophecy_system.prophecies_by_heir[prophecy.related_heir_id].append(prophecy.id)

	prophecy_system.fulfilled_prophecies = state.get("fulfilled_prophecies", []).duplicate()
	prophecy_system.prophecy_counter = state.get("prophecy_counter", 0)

	# Restore legacy events
	legacy_event_system.legacy_events = {}
	legacy_event_system.events_by_generation = {}
	for event_data in state.get("legacy_events", []):
		var event = LegacyEventSystem.LegacyEvent.new(
			event_data["id"],
			event_data["type"],
			event_data["name"],
			event_data["generation_triggered"]
		)
		event.description = event_data.get("description", "")
		event.affected_heirs = event_data.get("affected_heirs", []).duplicate()
		event.generation_resolved = event_data.get("generation_resolved", 0)
		event.consequences = event_data.get("consequences", {}).duplicate()
		event.resolved = event_data.get("resolved", false)

		legacy_event_system.legacy_events[event.id] = event

		if not legacy_event_system.events_by_generation.has(event.generation_triggered):
			legacy_event_system.events_by_generation[event.generation_triggered] = []
		legacy_event_system.events_by_generation[event.generation_triggered].append(event.id)

	legacy_event_system.event_counter = state.get("event_counter", 0)

	milestone_state_loaded.emit()


func transfer_milestones_to_next_generation(state: Dictionary) -> Dictionary:
	var new_state = {
		"milestones": state.get("milestones", []).duplicate(true),
		"completed_milestones": state.get("completed_milestones", []).duplicate(),
		"active_milestones": state.get("active_milestones", []).duplicate(),
		"prophecies": state.get("prophecies", []).duplicate(true),
		"fulfilled_prophecies": state.get("fulfilled_prophecies", []).duplicate(),
		"legacy_events": state.get("legacy_events", []).duplicate(true),
		"milestone_counter": state.get("milestone_counter", 0),
		"prophecy_counter": state.get("prophecy_counter", 0),
		"event_counter": state.get("event_counter", 0)
	}

	# Milestones carry completely forward (completion history preserved)
	# Prophecies carry completely forward (fulfillment history preserved)
	# Legacy events carry completely forward (consequences persist)

	return new_state


func export_milestone_history(state: Dictionary) -> Dictionary:
	var history = {
		"milestones_reached": state.get("completed_milestones", []).size(),
		"prophecies_generated": state.get("prophecies", []).size(),
		"prophecies_fulfilled": state.get("fulfilled_prophecies", []).size(),
		"legacy_events_triggered": state.get("legacy_events", []).size(),
		"total_prestige_from_milestones": 0,
		"milestone_timeline": [],
		"prophecy_fulfillment_rate": 0.0
	}

	# Count prestige from milestones
	for milestone_data in state.get("milestones", []):
		if milestone_data.get("triggered", false):
			history["total_prestige_from_milestones"] += milestone_data.get("rewards", {}).get("prestige", 0)
			history["milestone_timeline"].append({
				"generation": milestone_data.get("generation", 0),
				"type": MilestoneSystem.MilestoneType.keys()[milestone_data.get("type", 0)] if milestone_data.get("type") is int else "UNKNOWN",
				"triggered_at": milestone_data.get("triggered_at_generation", 0)
			})

	# Calculate prophecy fulfillment rate
	var total_prophecies = state.get("prophecies", []).size()
	if total_prophecies > 0:
		history["prophecy_fulfillment_rate"] = float(state.get("fulfilled_prophecies", []).size()) / float(total_prophecies)

	return history


func get_milestone_legacy(state: Dictionary) -> String:
	var milestones_reached = state.get("completed_milestones", []).size()
	if milestones_reached == 0:
		return "The dynasty's milestones lie ahead in the future."

	var legacy = "The dynasty has reached %d great milestones. " % milestones_reached

	var prophecies_fulfilled = state.get("fulfilled_prophecies", []).size()
	if prophecies_fulfilled > 0:
		var rate = 0.0
		var total_prophecies = state.get("prophecies", []).size()
		if total_prophecies > 0:
			rate = float(prophecies_fulfilled) / float(total_prophecies) * 100.0
		legacy += "%d prophecies have been fulfilled (%.0f%% rate). " % [prophecies_fulfilled, rate]

	var legacy_events = state.get("legacy_events", []).size()
	if legacy_events > 0:
		legacy += "%d major legacy events have shaped their destiny. " % legacy_events

	if milestones_reached >= 3:
		legacy += "Their name is inscribed in the annals of history eternal. "

	return legacy
