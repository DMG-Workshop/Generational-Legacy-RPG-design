## Settlement System: Manages settlements and building progression
##
## Each settlement has buildings with levels and resource production
## Buildings provide stat bonuses and special effects to heirs

class_name SettlementSystem


signal settlement_created(settlement_name: String, position: Vector2i)
signal building_upgraded(settlement_name: String, building_type: String, level: int)
signal resources_produced(settlement_name: String, resources: Dictionary)


enum BuildingType { SHRINE, SMITHY, TAVERN, BARRACKS, MARKET }

# Settlement data structure
var settlements: Dictionary = {}  # name -> settlement data
var building_effects: Dictionary = {
	BuildingType.SHRINE: {"healing_bonus": 0.1, "bless_chance": 0.05},
	BuildingType.SMITHY: {"damage_bonus": 0.05, "durability": 0.1},
	BuildingType.TAVERN: {"recruit_chance": 0.2, "quest_variety": 1.0},
	BuildingType.BARRACKS: {"training_speed": 0.15, "stat_gain": 0.05},
	BuildingType.MARKET: {"item_variety": 0.3, "gold_bonus": 0.1},
}

# Building progression
var building_costs: Dictionary = {
	1: {"gold": 100, "materials": 10},
	2: {"gold": 250, "materials": 25},
	3: {"gold": 500, "materials": 50},
	4: {"gold": 1000, "materials": 100},
	5: {"gold": 2000, "materials": 200},
}

var building_production: Dictionary = {
	BuildingType.SHRINE: {"blessing_per_day": 1},
	BuildingType.SMITHY: {"equipment_per_day": 2},
	BuildingType.TAVERN: {"quest_per_day": 3},
	BuildingType.BARRACKS: {"trained_per_day": 2},
	BuildingType.MARKET: {"gold_per_day": 50},
}


## Create settlement at position
func create_settlement(name: String, position: Vector2i, faction: String = "neutral") -> Dictionary:
	if name in settlements:
		return settlements[name]

	var settlement = {
		"name": name,
		"position": position,
		"faction": faction,
		"level": 1,
		"population": 10,
		"morale": 1.0,
		"resources": {"gold": 500, "materials": 50},
		"buildings": {
			BuildingType.SHRINE: 1,
			BuildingType.SMITHY: 1,
			BuildingType.TAVERN: 1,
			BuildingType.BARRACKS: 1,
			BuildingType.MARKET: 1,
		},
		"quests_available": 0,
		"npcs": [],
		"created_at": Time.get_ticks_msec(),
	}

	settlements[name] = settlement
	settlement_created.emit(name, position)
	return settlement


## Get settlement
func get_settlement(name: String) -> Dictionary:
	return settlements.get(name, {})


## Get all settlements
func get_all_settlements() -> Array[String]:
	return settlements.keys()


## Get nearest settlement to position
func get_nearest_settlement(from_pos: Vector2i) -> String:
	var nearest = ""
	var min_distance = INT_MAX

	for settlement_name in settlements.keys():
		var settlement = settlements[settlement_name]
		var distance = from_pos.distance_to(settlement["position"])
		if distance < min_distance:
			min_distance = distance
			nearest = settlement_name

	return nearest


## Upgrade building in settlement
func upgrade_building(settlement_name: String, building_type: int) -> bool:
	if settlement_name not in settlements:
		return false

	var settlement = settlements[settlement_name]
	var current_level = settlement["buildings"].get(building_type, 1)

	if current_level >= 5:
		return false

	var next_level = current_level + 1
	var cost = building_costs.get(next_level, {})

	if settlement["resources"]["gold"] >= cost.get("gold", 0):
		if settlement["resources"]["materials"] >= cost.get("materials", 0):
			settlement["resources"]["gold"] -= cost.get("gold", 0)
			settlement["resources"]["materials"] -= cost.get("materials", 0)
			settlement["buildings"][building_type] = next_level
			building_upgraded.emit(settlement_name, BuildingType.keys()[building_type], next_level)
			return true

	return false


## Get building effects for heir stats
func get_building_effects(settlement_name: String) -> Dictionary:
	if settlement_name not in settlements:
		return {}

	var settlement = settlements[settlement_name]
	var effects = {}

	for building_type in settlement["buildings"].keys():
		var level = settlement["buildings"][building_type]
		var building_effect = building_effects.get(building_type, {})

		for effect_key in building_effect.keys():
			var base_effect = building_effect[effect_key]
			var level_multiplier = 1.0 + (level - 1) * 0.2  # 20% per level
			effects[effect_key] = effects.get(effect_key, 0.0) + (base_effect * level_multiplier)

	return effects


## Add resources to settlement
func add_resources(settlement_name: String, resources: Dictionary) -> void:
	if settlement_name not in settlements:
		return

	var settlement = settlements[settlement_name]
	for resource_type in resources.keys():
		settlement["resources"][resource_type] = settlement["resources"].get(resource_type, 0) + resources[resource_type]


## Remove resources from settlement
func remove_resources(settlement_name: String, resources: Dictionary) -> bool:
	if settlement_name not in settlements:
		return false

	var settlement = settlements[settlement_name]
	for resource_type in resources.keys():
		if settlement["resources"].get(resource_type, 0) < resources[resource_type]:
			return false

	for resource_type in resources.keys():
		settlement["resources"][resource_type] -= resources[resource_type]

	return true


## Simulate settlement production
func simulate_production(settlement_name: String, days_passed: int = 1) -> Dictionary:
	if settlement_name not in settlements:
		return {}

	var settlement = settlements[settlement_name]
	var produced = {}

	for building_type in settlement["buildings"].keys():
		var level = settlement["buildings"][building_type]
		var production = building_production.get(building_type, {})

		for production_type in production.keys():
			var base_amount = production[production_type]
			var total = base_amount * level * days_passed
			produced[production_type] = produced.get(production_type, 0) + total

	resources_produced.emit(settlement_name, produced)
	return produced


## Get settlement summary
func get_settlement_summary(settlement_name: String) -> Dictionary:
	if settlement_name not in settlements:
		return {}

	var settlement = settlements[settlement_name]
	var buildings_summary = {}

	for building_type in settlement["buildings"].keys():
		buildings_summary[BuildingType.keys()[building_type]] = settlement["buildings"][building_type]

	return {
		"name": settlement_name,
		"position": settlement["position"],
		"faction": settlement["faction"],
		"level": settlement["level"],
		"population": settlement["population"],
		"morale": settlement["morale"],
		"resources": settlement["resources"].duplicate(),
		"buildings": buildings_summary,
		"npcs_count": settlement["npcs"].size(),
	}
