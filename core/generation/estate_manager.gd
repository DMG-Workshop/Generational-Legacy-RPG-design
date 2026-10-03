## Estate Manager: manages family properties across generations
##
## Properties (estates, businesses, tombs, shrines) persist and decay.
## Maintenance level determines structure of inherited properties.

extends Node

class_name EstateManager


## Family property (estate, smithy, tomb, trading post, etc.)
class Property:
	var realm: String
	var chunk_pos: Vector3i
	var property_type: String  # "estate", "smithy", "business", "tomb", "shrine"
	var owner_generation: int  # Who built/claimed it
	var built_year: int

	## Maintenance (0-100)
	var maintenance: int = 100
	var last_maintained_generation: int = 0
	var residents: Array[String] = []  # NPCs living here

	## Upgrades increase functionality
	var upgrades: Dictionary = {
		"forge": 0,  # Level 0-3 (affects crafting speed)
		"library": 0,  # Affects spell learning
		"barracks": 0,  # Affects warrior training
		"market": 0,  # Affects trading
	}

	## Income/upkeep
	var annual_upkeep: int = 10
	var annual_income: int = 0


## All family properties
var properties: Array[Property] = []

## Current primary estate (the family home)
var primary_estate: Property = null

## Property income tracker (wealth generation)
var property_income: int = 0


func _init() -> void:
	properties = []
	property_income = 0


## Create a new property
func create_property(
	realm: String,
	chunk_pos: Vector3i,
	property_type: String,
	owner_generation: int = 0
) -> Property:
	var property = Property.new()
	property.realm = realm
	property.chunk_pos = chunk_pos
	property.property_type = property_type
	property.owner_generation = owner_generation
	property.built_year = owner_generation * 25

	# Set upkeep based on type
	match property_type:
		"estate":
			property.annual_upkeep = 20
			property.annual_income = 30
			property_income += 30
			if primary_estate == null:
				primary_estate = property

		"smithy":
			property.annual_upkeep = 15
			property.upgrades["forge"] = 1
			property.annual_income = 25
			property_income += 25

		"library":
			property.annual_upkeep = 10
			property.upgrades["library"] = 1
			property.annual_income = 15
			property_income += 15

		"trading_post":
			property.annual_upkeep = 12
			property.upgrades["market"] = 1
			property.annual_income = 40
			property_income += 40

		"tomb":
			property.annual_upkeep = 5  # Tombs need less maintenance
			property.annual_income = 0

		"shrine":
			property.annual_upkeep = 8
			property.annual_income = 10
			property_income += 10

	properties.append(property)
	return property


## Get a property by realm and position
func get_property(realm: String, chunk_pos: Vector3i) -> Property:
	for prop in properties:
		if prop.realm == realm and prop.chunk_pos == chunk_pos:
			return prop
	return null


## Maintain a property (heir spends time and wealth on it)
func maintain_property(property: Property, heir: Heir, wealth_spent: int) -> Dictionary:
	property.maintenance = min(100, property.maintenance + 20)
	property.last_maintained_generation = heir.generation

	return {
		"property": property.property_type,
		"maintenance_level": property.maintenance,
		"wealth_spent": wealth_spent,
		"success": true
	}


## Upgrade a property feature
func upgrade_feature(property: Property, feature: String) -> Dictionary:
	if not property.upgrades.has(feature):
		return {"success": false, "reason": "Feature not available"}

	var current_level = property.upgrades[feature]
	if current_level >= 3:
		return {"success": false, "reason": "Already max level"}

	property.upgrades[feature] += 1

	# Upgrade effects
	match feature:
		"forge":
			property.annual_income += 10
			property_income += 10
		"library":
			property.annual_income += 5
			property_income += 5
		"barracks":
			property.annual_income += 15
			property_income += 15
		"market":
			property.annual_income += 20
			property_income += 20

	return {
		"success": true,
		"feature": feature,
		"new_level": property.upgrades[feature],
		"new_income": property.annual_income
	}


## Apply annual maintenance decay
func apply_decay(generations_passed: int) -> void:
	for property in properties:
		var generations_since_maintenance = generations_passed - (property.last_maintained_generation - property.owner_generation)

		# Decay accelerates over time
		if generations_since_maintenance > 5:
			property.maintenance -= 10
		if generations_since_maintenance > 20:
			property.maintenance -= 15
		if generations_since_maintenance > 50:
			property.maintenance = 0  # Completely ruined

		property.maintenance = max(0, property.maintenance)


## Get structural condition description
func get_condition(maintenance: int) -> String:
	if maintenance >= 90:
		return "pristine"
	elif maintenance >= 70:
		return "good"
	elif maintenance >= 50:
		return "fair"
	elif maintenance >= 25:
		return "poor"
	else:
		return "ruins"


## Get property efficiency (maintenance affects output)
func get_property_efficiency(property: Property) -> float:
	# Maintenance at 0% = 0% efficiency; 100% = 100%
	return property.maintenance / 100.0


## Get crafting bonus from smithy
func get_smithy_bonus(smithy: Property) -> int:
	if smithy == null or smithy.property_type != "smithy":
		return 0

	var efficiency = get_property_efficiency(smithy)
	var forge_bonus = 10 + (smithy.upgrades["forge"] * 10)  # 10, 20, 30, 40%

	return int(forge_bonus * efficiency)


## Get spell learning bonus from library
func get_library_bonus(library: Property) -> int:
	if library == null or library.property_type != "library":
		return 0

	var efficiency = get_property_efficiency(library)
	var library_bonus = 15 + (library.upgrades["library"] * 10)  # 15, 25, 35, 45%

	return int(library_bonus * efficiency)


## Get all properties in a realm
func get_properties_in_realm(realm: String) -> Array[Property]:
	return properties.filter(func(p): return p.realm == realm)


## Get all properties of a type
func get_properties_by_type(property_type: String) -> Array[Property]:
	return properties.filter(func(p): return p.property_type == property_type)


## Calculate total property value
func get_total_property_value() -> int:
	var value = 0

	for property in properties:
		var base_value = 500  # Base property value
		match property.property_type:
			"estate":
				base_value = 1000
			"smithy":
				base_value = 800
			"library":
				base_value = 600
			"trading_post":
				base_value = 900

		# Maintenance affects value
		var maintenance_factor = property.maintenance / 100.0
		value += int(base_value * maintenance_factor)

	return value


## Get annual income from properties
func get_annual_income() -> int:
	var income = 0

	for property in properties:
		if property.maintenance > 0:
			var efficiency = get_property_efficiency(property)
			income += int(property.annual_income * efficiency)

	return income


## Get property summary
func get_property_summary(property: Property) -> Dictionary:
	return {
		"type": property.property_type,
		"realm": property.realm,
		"position": property.chunk_pos,
		"maintenance": property.maintenance,
		"condition": get_condition(property.maintenance),
		"owner_generation": property.owner_generation,
		"annual_income": int(property.annual_income * get_property_efficiency(property)),
		"annual_upkeep": property.annual_upkeep,
		"upgrades": property.upgrades,
		"residents": property.residents.size(),
	}


## Get all properties summary
func get_all_properties_summary() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []

	for property in properties:
		summaries.append(get_property_summary(property))

	return summaries


## Reclaim a ruined property
func reclaim_property(property: Property) -> Dictionary:
	property.maintenance = 50  # Half-restored
	property.last_maintained_generation = 0  # Reset maintenance timer

	return {
		"success": true,
		"property": property.property_type,
		"new_maintenance": property.maintenance
	}
