## Settlement System: Manages settlements with buildings, prosperity, and population
##
## Tracks all settlements, building distribution, resource flow, and settlement prosperity

extends Node

class_name SettlementSystem


signal settlement_created(settlement_id: String, name: String)
signal settlement_prosperity_changed(settlement_id: String, prosperity: float)
signal settlement_population_changed(settlement_id: String, population: int)
signal settlement_updated(settlement_id: String)


var building_system: BuildingSystem
var settlements: Dictionary = {}


class Settlement:
	var id: String
	var name: String
	var location: Vector2i
	var buildings: Array = []
	var prosperity: float = 50.0
	var population: int = 0
	var created_at_tick: int = 0
	var total_gold_generated: int = 0
	
	func _init(p_id: String, p_name: String, p_location: Vector2i) -> void:
		id = p_id
		name = p_name
		location = p_location
		created_at_tick = 0


func _init() -> void:
	building_system = BuildingSystem.new()
	settlements = {}


func create_settlement(name: String, location: Vector2i) -> String:
	var settlement_id = "%s_%d_%d_%d" % [name.to_lower().replace(" ", "_"), location.x, location.y, randi()]
	var settlement = Settlement.new(settlement_id, name, location)
	settlements[settlement_id] = settlement
	settlement_created.emit(settlement_id, name)
	return settlement_id


func get_settlement(settlement_id: String) -> Settlement:
	return settlements.get(settlement_id)


func add_building_to_settlement(settlement_id: String, building_type: int, owner: String = "settlement") -> String:
	var settlement = settlements.get(settlement_id)
	if not settlement:
		return ""
	
	var building_id = building_system.create_building(building_type, settlement.location, owner)
	settlement.buildings.append(building_id)
	settlement_updated.emit(settlement_id)
	return building_id


func get_settlement_buildings(settlement_id: String) -> Array:
	var settlement = settlements.get(settlement_id)
	if not settlement:
		return []
	
	var result = []
	for building_id in settlement.buildings:
		var building = building_system.get_building(building_id)
		if building:
			result.append(building)
	return result


func process_settlement_production(settlement_id: String, realm_multiplier: float = 1.0) -> Dictionary:
	var settlement = settlements.get(settlement_id)
	if not settlement:
		return {}
	
	var total_production = {}
	var settlement_gold = 0
	
	for building_id in settlement.buildings:
		var produced = building_system.produce_resources(building_id, settlement.prosperity, realm_multiplier)
		
		for resource_type in produced.keys():
			if resource_type == "gold":
				settlement_gold += produced[resource_type]
			else:
				total_production[resource_type] = total_production.get(resource_type, 0) + produced[resource_type]
	
	settlement.total_gold_generated += settlement_gold
	total_production["gold"] = settlement_gold
	
	return total_production


func update_settlement_prosperity(settlement_id: String, delta: float) -> void:
	var settlement = settlements.get(settlement_id)
	if settlement:
		settlement.prosperity = clamp(settlement.prosperity + delta, 0.0, 100.0)
		settlement_prosperity_changed.emit(settlement_id, settlement.prosperity)


func update_settlement_population(settlement_id: String, delta: int) -> void:
	var settlement = settlements.get(settlement_id)
	if settlement:
		settlement.population = max(0, settlement.population + delta)
		settlement_population_changed.emit(settlement_id, settlement.population)


func get_settlement_info(settlement_id: String) -> Dictionary:
	var settlement = settlements.get(settlement_id)
	if not settlement:
		return {}
	
	var buildings_info = []
	for building_id in settlement.buildings:
		buildings_info.append(building_system.get_building_info(building_id))
	
	return {
		"id": settlement.id,
		"name": settlement.name,
		"location": settlement.location,
		"prosperity": settlement.prosperity,
		"population": settlement.population,
		"buildings": buildings_info,
		"total_gold_generated": settlement.total_gold_generated
	}


func get_all_settlements() -> Array:
	return settlements.values()


func settlement_exists(settlement_id: String) -> bool:
	return settlements.has(settlement_id)


func get_nearby_settlements(location: Vector2i, radius: int = 50) -> Array:
	var result = []
	for settlement in settlements.values():
		var distance = settlement.location.distance_to(location)
		if distance <= radius:
			result.append(settlement)
	return result


func calculate_settlement_wealth(settlement_id: String) -> int:
	var settlement = settlements.get(settlement_id)
	if not settlement:
		return 0
	
	var total_stock_value = 0
	for building_id in settlement.buildings:
		var building = building_system.get_building(building_id)
		if building:
			for resource_type in building.resource_stockpile.keys():
				var amount = building.resource_stockpile[resource_type]
				total_stock_value += amount * 10
	
	return settlement.total_gold_generated + total_stock_value


func get_settlement_summary(settlement_id: String) -> Dictionary:
	var settlement = settlements.get(settlement_id)
	if not settlement:
		return {}
	
	var building_types = {}
	for building_id in settlement.buildings:
		var building = building_system.get_building(building_id)
		if building:
			var type_name = BuildingSystem.BuildingType.keys()[building.type]
			building_types[type_name] = building_types.get(type_name, 0) + 1
	
	return {
		"name": settlement.name,
		"prosperity": settlement.prosperity,
		"population": settlement.population,
		"building_count": settlement.buildings.size(),
		"building_types": building_types,
		"wealth": calculate_settlement_wealth(settlement_id)
	}
