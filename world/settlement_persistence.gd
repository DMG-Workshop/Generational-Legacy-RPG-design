## Settlement Persistence: Save and load settlement state across generations
##
## Serializes settlements, buildings, and resources for generational continuity

extends Node

class_name SettlementPersistence


signal settlement_saved(settlement_id: String)
signal settlement_loaded(settlement_id: String)


var settlement_system: SettlementSystem
var saved_settlements: Dictionary = {}


func _init(p_settlement_system: SettlementSystem = null) -> void:
	if p_settlement_system:
		settlement_system = p_settlement_system
	else:
		settlement_system = SettlementSystem.new()


func save_settlement(settlement_id: String) -> Dictionary:
	var settlement = settlement_system.get_settlement(settlement_id)
	if not settlement:
		return {}
	
	var buildings_data = []
	for building_id in settlement.buildings:
		var building_info = settlement_system.building_system.get_building_info(building_id)
		buildings_data.append(building_info)
	
	var settlement_data = {
		"id": settlement.id,
		"name": settlement.name,
		"location": settlement.location,
		"prosperity": settlement.prosperity,
		"population": settlement.population,
		"total_gold_generated": settlement.total_gold_generated,
		"buildings": buildings_data,
		"saved_at_tick": 0
	}
	
	saved_settlements[settlement_id] = settlement_data
	settlement_saved.emit(settlement_id)
	return settlement_data


func load_settlement(settlement_data: Dictionary) -> String:
	if settlement_data.is_empty():
		return ""
	
	var settlement_id = settlement_system.create_settlement(settlement_data["name"], settlement_data["location"])
	var settlement = settlement_system.get_settlement(settlement_id)
	
	if settlement:
		settlement.prosperity = settlement_data.get("prosperity", 50.0)
		settlement.population = settlement_data.get("population", 0)
		settlement.total_gold_generated = settlement_data.get("total_gold_generated", 0)
		
		for building_data in settlement_data.get("buildings", []):
			var building_type = BuildingSystem.BuildingType.get(building_data.get("type", "INN"))
			var owner = building_data.get("owner", "settlement")
			var building_id = settlement_system.add_building_to_settlement(settlement_id, building_type, owner)
			
			var building = settlement_system.building_system.get_building(building_id)
			if building:
				building.condition = building_data.get("condition", 1.0)
				for resource in building_data.get("stock", {}):
					building.resource_stockpile[resource] = building_data["stock"][resource]
		
		settlement_loaded.emit(settlement_id)
	
	return settlement_id


func save_all_settlements() -> Dictionary:
	var all_data = {}
	
	for settlement in settlement_system.get_all_settlements():
		var data = save_settlement(settlement.id)
		all_data[settlement.id] = data
	
	return all_data


func load_all_settlements(settlements_data: Dictionary) -> void:
	for settlement_id in settlements_data.keys():
		load_settlement(settlements_data[settlement_id])


func get_settlement_save_data(settlement_id: String) -> Dictionary:
	return saved_settlements.get(settlement_id, {})


func clear_saved_data() -> void:
	saved_settlements.clear()


func export_settlement_history(settlement_id: String) -> Dictionary:
	var settlement = settlement_system.get_settlement(settlement_id)
	if not settlement:
		return {}
	
	var history = {
		"name": settlement.name,
		"location": settlement.location,
		"current_prosperity": settlement.prosperity,
		"current_population": settlement.population,
		"total_gold_generated": settlement.total_gold_generated,
		"building_count": settlement.buildings.size(),
		"wealth": settlement_system.calculate_settlement_wealth(settlement_id),
		"summary": settlement_system.get_settlement_summary(settlement_id)
	}
	
	return history


func decay_settlements_over_time(tick_delta: int, decay_rate: float = 0.01) -> void:
	for settlement in settlement_system.get_all_settlements():
		settlement_system.update_settlement_prosperity(settlement.id, -decay_rate * (tick_delta / 1000.0))
		
		for building_id in settlement.buildings:
			settlement_system.building_system.decay_building_condition(building_id, decay_rate * (tick_delta / 1000.0))


func restore_settlement_prosperity(settlement_id: String, restoration_amount: float = 5.0) -> void:
	settlement_system.update_settlement_prosperity(settlement_id, restoration_amount)
	
	var settlement = settlement_system.get_settlement(settlement_id)
	if settlement:
		for building_id in settlement.buildings:
			settlement_system.building_system.repair_building(building_id, 0.05)
