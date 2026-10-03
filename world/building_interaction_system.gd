## Building Interaction System: Player transactions with buildings
##
## Handles buying, selling, hiring, crafting, and donations

extends Node

class_name BuildingInteractionSystem


signal purchase_completed(building_id: String, item: String, price: int)
signal sale_completed(building_id: String, item: String, price: int)
signal craft_commissioned(building_id: String, craft_type: String, cost: int)
signal donation_made(building_id: String, amount: int)


var building_system: BuildingSystem
var player_gold: int = 0
var player_inventory: Dictionary = {}


func _init(p_building_system: BuildingSystem = null) -> void:
	if p_building_system:
		building_system = p_building_system
	else:
		building_system = BuildingSystem.new()
	player_gold = 500
	player_inventory = {}


func buy_item(building_id: String, item: String, quantity: int = 1) -> bool:
	var building = building_system.get_building(building_id)
	if not building:
		return false
	
	var price = calculate_purchase_price(building_id, item, quantity)
	
	if player_gold < price:
		return false
	
	if not building_system.remove_from_stock(building_id, item, quantity):
		return false
	
	player_gold -= price
	player_inventory[item] = player_inventory.get(item, 0) + quantity
	purchase_completed.emit(building_id, item, price)
	return true


func sell_item(building_id: String, item: String, quantity: int = 1) -> bool:
	var building = building_system.get_building(building_id)
	if not building:
		return false
	
	if player_inventory.get(item, 0) < quantity:
		return false
	
	var price = calculate_sale_price(building_id, item, quantity)
	
	player_gold += price
	player_inventory[item] -= quantity
	if player_inventory[item] <= 0:
		player_inventory.erase(item)
	
	building_system.add_to_stock(building_id, item, quantity)
	sale_completed.emit(building_id, item, price)
	return true


func calculate_purchase_price(building_id: String, item: String, quantity: int = 1) -> int:
	var building = building_system.get_building(building_id)
	if not building:
		return 0
	
	var stock = building.resource_stockpile.get(item, 0)
	var base_price = 10
	
	var scarcity_multiplier = 1.0
	if stock == 0:
		scarcity_multiplier = 1.5
	elif stock < 5:
		scarcity_multiplier = 1.2
	elif stock > 20:
		scarcity_multiplier = 0.8
	
	return int(base_price * quantity * scarcity_multiplier)


func calculate_sale_price(building_id: String, item: String, quantity: int = 1) -> int:
	var building = building_system.get_building(building_id)
	if not building:
		return 0
	
	var stock = building.resource_stockpile.get(item, 0)
	var base_price = 10
	
	var demand_multiplier = 1.0
	if stock > 30:
		demand_multiplier = 1.3
	elif stock > 20:
		demand_multiplier = 1.1
	elif stock == 0:
		demand_multiplier = 0.6
	
	return int(base_price * quantity * demand_multiplier * 0.8)


func hire_npc(building_id: String, cost: int = 50) -> bool:
	if player_gold < cost:
		return false
	
	player_gold -= cost
	player_inventory["hired_npc"] = player_inventory.get("hired_npc", 0) + 1
	return true


func donate_to_temple(building_id: String, amount: int) -> bool:
	var building = building_system.get_building(building_id)
	if building.type != BuildingSystem.BuildingType.TEMPLE:
		return false
	
	if player_gold < amount:
		return false
	
	player_gold -= amount
	building_system.add_to_stock(building_id, "blessing_essence", 1)
	donation_made.emit(building_id, amount)
	return true


func commission_craft(building_id: String, craft_type: String, cost: int = 100) -> bool:
	var building = building_system.get_building(building_id)
	if building.type != BuildingSystem.BuildingType.CRAFT_SHOP:
		return false
	
	if player_gold < cost:
		return false
	
	player_gold -= cost
	building_system.add_to_stock(building_id, "crafted_" + craft_type, 1)
	craft_commissioned.emit(building_id, craft_type, cost)
	return true


func get_player_gold() -> int:
	return player_gold


func add_player_gold(amount: int) -> void:
	player_gold += amount


func remove_player_gold(amount: int) -> bool:
	if player_gold >= amount:
		player_gold -= amount
		return true
	return false


func get_player_inventory() -> Dictionary:
	return player_inventory.duplicate()


func add_to_player_inventory(item: String, quantity: int = 1) -> void:
	player_inventory[item] = player_inventory.get(item, 0) + quantity


func remove_from_player_inventory(item: String, quantity: int = 1) -> bool:
	if player_inventory.get(item, 0) >= quantity:
		player_inventory[item] -= quantity
		if player_inventory[item] <= 0:
			player_inventory.erase(item)
		return true
	return false


func get_building_stock(building_id: String) -> Dictionary:
	var building = building_system.get_building(building_id)
	if building:
		return building.resource_stockpile.duplicate()
	return {}


func get_available_items_at_building(building_id: String) -> Array:
	var building = building_system.get_building(building_id)
	if not building:
		return []
	
	var items = []
	for item in building.resource_stockpile.keys():
		if building.resource_stockpile[item] > 0:
			items.append(item)
	
	return items
