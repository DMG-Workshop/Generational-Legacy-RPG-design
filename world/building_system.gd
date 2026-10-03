## Building System: Individual building logic with resource production and state
##
## Manages building types, resource generation, ownership, and player interaction

extends Node

class_name BuildingSystem


signal resource_produced(building_id: String, resource_type: String, amount: int)
signal building_stock_changed(building_id: String, item: String, quantity: int)
signal building_condition_changed(building_id: String, condition: float)
signal owner_changed(building_id: String, old_owner: String, new_owner: String)


enum BuildingType { INN, BLACKSMITH, TAVERN, TEMPLE, MARKET, CRAFT_SHOP }

var buildings: Dictionary = {}


class Building:
	var id: String
	var type: int
	var name: String
	var location: Vector2i
	var owner: String
	var condition: float = 1.0
	var resource_stockpile: Dictionary = {}
	var gold_produced: int = 0
	var production_rate: Dictionary = {}
	var last_production_tick: int = 0
	var created_at_tick: int = 0

	func _init(p_id: String, p_type: int, p_name: String, p_location: Vector2i, p_owner: String) -> void:
		id = p_id
		type = p_type
		name = p_name
		location = p_location
		owner = p_owner
		created_at_tick = 0
		_initialize_for_type()

	func _initialize_for_type() -> void:
		resource_stockpile = {}
		production_rate = {}

		match type:
			BuildingType.INN:
				name = "Inn"
				production_rate = {"gold": 15, "supplies": 2}
				resource_stockpile = {"beds": 5, "supplies": 10}
			BuildingType.BLACKSMITH:
				name = "Blacksmith"
				production_rate = {"gold": 20, "ore": 3}
				resource_stockpile = {"ore": 15, "ingots": 5}
			BuildingType.TAVERN:
				name = "Tavern"
				production_rate = {"gold": 25, "ale": 2}
				resource_stockpile = {"ale": 20}
			BuildingType.TEMPLE:
				name = "Temple"
				production_rate = {"gold": 10, "blessing_essence": 1}
				resource_stockpile = {"blessing_essence": 3}
			BuildingType.MARKET:
				name = "Market"
				production_rate = {"gold": 30, "trade_goods": 5}
				resource_stockpile = {"trade_goods": 25}
			BuildingType.CRAFT_SHOP:
				name = "Craft Shop"
				production_rate = {"gold": 18, "components": 4}
				resource_stockpile = {"components": 12, "materials": 8}


func _init() -> void:
	buildings = {}


func create_building(building_type: int, location: Vector2i, owner: String = "settlement") -> String:
	var building_id = "%s_%d_%d_%d" % [BuildingType.keys()[building_type].to_lower(), location.x, location.y, randi()]
	var building = Building.new(building_id, building_type, BuildingType.keys()[building_type], location, owner)
	buildings[building_id] = building
	return building_id


func get_building(building_id: String) -> Building:
	return buildings.get(building_id)


func get_buildings_by_type(building_type: int) -> Array:
	var result = []
	for building in buildings.values():
		if building.type == building_type:
			result.append(building)
	return result


func get_buildings_in_settlement(settlement_location: Vector2i) -> Array:
	var result = []
	for building in buildings.values():
		if building.location == settlement_location:
			result.append(building)
	return result


func produce_resources(building_id: String, settlement_prosperity: float = 1.0, realm_multiplier: float = 1.0) -> Dictionary:
	var building = buildings.get(building_id)
	if not building:
		return {}

	var produced = {}

	for resource_type in building.production_rate.keys():
		var base_rate = building.production_rate[resource_type]
		var prosperity_factor = settlement_prosperity / 100.0
		var condition_factor = building.condition

		var amount = int(base_rate * prosperity_factor * condition_factor * realm_multiplier)
		amount = max(0, amount)

		if amount > 0:
			produced[resource_type] = amount

			if resource_type == "gold":
				building.gold_produced += amount
			else:
				var current = building.resource_stockpile.get(resource_type, 0)
				building.resource_stockpile[resource_type] = current + amount

			resource_produced.emit(building_id, resource_type, amount)

	return produced


func get_production_summary(building_id: String) -> Dictionary:
	var building = buildings.get(building_id)
	if not building:
		return {}

	var summary = {
		"gold_produced": building.gold_produced,
		"resources_produced": {},
		"current_stock": building.resource_stockpile.duplicate()
	}

	for resource_type in building.production_rate.keys():
		summary["resources_produced"][resource_type] = building.production_rate[resource_type]

	return summary


func change_owner(building_id: String, new_owner: String) -> void:
	var building = buildings.get(building_id)
	if building:
		var old_owner = building.owner
		building.owner = new_owner
		owner_changed.emit(building_id, old_owner, new_owner)


func update_condition(building_id: String, delta: float) -> void:
	var building = buildings.get(building_id)
	if building:
		building.condition = clamp(building.condition + delta, 0.0, 1.0)
		building_condition_changed.emit(building_id, building.condition)


func add_to_stock(building_id: String, resource_type: String, amount: int) -> void:
	var building = buildings.get(building_id)
	if building:
		var current = building.resource_stockpile.get(resource_type, 0)
		building.resource_stockpile[resource_type] = current + amount
		building_stock_changed.emit(building_id, resource_type, amount)


func remove_from_stock(building_id: String, resource_type: String, amount: int) -> bool:
	var building = buildings.get(building_id)
	if not building:
		return false

	var current = building.resource_stockpile.get(resource_type, 0)
	if current >= amount:
		building.resource_stockpile[resource_type] = current - amount
		building_stock_changed.emit(building_id, resource_type, -amount)
		return true

	return false


func get_building_info(building_id: String) -> Dictionary:
	var building = buildings.get(building_id)
	if not building:
		return {}

	return {
		"id": building.id,
		"type": BuildingType.keys()[building.type],
		"name": building.name,
		"location": building.location,
		"owner": building.owner,
		"condition": building.condition,
		"stock": building.resource_stockpile.duplicate(),
		"gold_produced": building.gold_produced,
		"production_rate": building.production_rate.duplicate()
	}


func get_all_buildings() -> Array:
	return buildings.values()


func building_exists(building_id: String) -> bool:
	return buildings.has(building_id)


func decay_building_condition(building_id: String, decay_rate: float = 0.01) -> void:
	var building = buildings.get(building_id)
	if building:
		update_condition(building_id, -decay_rate)


func repair_building(building_id: String, repair_amount: float = 0.1) -> void:
	var building = buildings.get(building_id)
	if building:
		update_condition(building_id, repair_amount)
