## NPC Schedule System: Daily routines and location tracking
##
## Manages NPC daily cycles, building assignments, and activity progression

extends Node

class_name NPCScheduleSystem


signal npc_activity_changed(npc_id: String, building_id: String, activity: String)
signal npc_location_updated(npc_id: String, location: Vector2i)
signal npc_working_hours_start(npc_id: String, building_id: String)
signal npc_working_hours_end(npc_id: String)


var npc_system: NPCSystem
var building_system: BuildingSystem
var npc_assignments: Dictionary = {}


class NPCSchedule:
	var npc_id: String
	var assigned_building: String = ""
	var work_start_tick: int = 250
	var work_end_tick: int = 750
	var home_location: Vector2i = Vector2i.ZERO
	var seasonal_rotation: Array = []
	var current_season_index: int = 0
	
	func _init(p_npc_id: String) -> void:
		npc_id = p_npc_id


func _init(p_npc_system: NPCSystem = null, p_building_system: BuildingSystem = null) -> void:
	if p_npc_system:
		npc_system = p_npc_system
	else:
		npc_system = NPCSystem.new()
	
	if p_building_system:
		building_system = p_building_system
	else:
		building_system = BuildingSystem.new()
	
	npc_assignments = {}


func create_schedule_for_npc(npc_id: String, home_location: Vector2i) -> NPCSchedule:
	var schedule = NPCSchedule.new(npc_id)
	schedule.home_location = home_location
	npc_assignments[npc_id] = schedule
	return schedule


func assign_npc_to_building(npc_id: String, building_id: String) -> void:
	var schedule = npc_assignments.get(npc_id)
	if schedule:
		schedule.assigned_building = building_id
		var building = building_system.get_building(building_id)
		if building:
			npc_system.update_npc_location(npc_id, building.location)


func process_npc_schedule(npc_id: String, current_tick: int) -> void:
	var npc = npc_system.get_npc(npc_id)
	if not npc or not npc.is_alive:
		return
	
	var schedule = npc_assignments.get(npc_id)
	if not schedule:
		return
	
	var tick_in_day = current_tick % 1000
	
	if tick_in_day < 250:
		npc_system.set_npc_activity(npc_id, "sleeping")
		npc_system.update_npc_location(npc_id, schedule.home_location)
	
	elif tick_in_day < 750:
		npc_system.set_npc_activity(npc_id, "working")
		if schedule.assigned_building:
			var building = building_system.get_building(schedule.assigned_building)
			if building:
				npc_system.update_npc_location(npc_id, building.location)
	
	else:
		npc_system.set_npc_activity(npc_id, "resting")
		npc_system.update_npc_location(npc_id, schedule.home_location)


func get_npc_schedule(npc_id: String) -> NPCSchedule:
	return npc_assignments.get(npc_id)


func update_seasonal_assignments(npc_id: String, new_building: String) -> void:
	var schedule = npc_assignments.get(npc_id)
	if schedule:
		schedule.seasonal_rotation.append(new_building)


func rotate_seasonal_assignment(npc_id: String) -> void:
	var schedule = npc_assignments.get(npc_id)
	if schedule and schedule.seasonal_rotation.size() > 0:
		schedule.current_season_index = (schedule.current_season_index + 1) % schedule.seasonal_rotation.size()
		var new_building = schedule.seasonal_rotation[schedule.current_season_index]
		assign_npc_to_building(npc_id, new_building)


func get_npcs_working_at_building(building_id: String) -> Array:
	var working = []
	for npc_id in npc_assignments.keys():
		var schedule = npc_assignments[npc_id]
		if schedule.assigned_building == building_id:
			working.append(npc_id)
	return working


func get_npc_at_time(npc_id: String, current_tick: int) -> Dictionary:
	var npc = npc_system.get_npc(npc_id)
	if not npc:
		return {}
	
	var schedule = npc_assignments.get(npc_id)
	if not schedule:
		return {}
	
	var tick_in_day = current_tick % 1000
	var location = npc.location
	var activity = npc.current_activity
	
	return {
		"npc_id": npc_id,
		"name": npc.name,
		"location": location,
		"activity": activity,
		"time_of_day": tick_in_day
	}


func get_all_npc_positions(current_tick: int) -> Dictionary:
	var positions = {}
	for npc_id in npc_assignments.keys():
		var npc = npc_system.get_npc(npc_id)
		if npc and npc.is_alive:
			process_npc_schedule(npc_id, current_tick)
			positions[npc_id] = {
				"location": npc.location,
				"activity": npc.current_activity
			}
	
	return positions
