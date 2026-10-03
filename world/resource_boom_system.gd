## Resource Boom System: Market fluctuations and resource scarcity
##
## Manages resource abundance/scarcity cycles and price effects

extends Node

class_name ResourceBoomSystem


signal boom_created(boom_id: String, resource_type: String)
signal boom_resolved(boom_id: String)
signal price_spiked(resource_type: String, multiplier: float)
signal price_crashed(resource_type: String, multiplier: float)


enum ResourceType { ORE, FOOD, MATERIALS, TRADE_GOODS, BLESSING_ESSENCE }
enum BoomType { ABUNDANCE, SCARCITY }

var event_system: EnvironmentalEventSystem
var booms: Dictionary = {}
var resource_prices: Dictionary = {}


class ResourceBoom:
	var id: String
	var resource_type: int
	var boom_type: int
	var location: Vector2i
	var radius: int = 75
	var duration: int = 2000
	var elapsed_time: int = 0
	var price_multiplier: float = 1.0
	
	func _init(p_id: String, p_resource: int, p_boom_type: int, p_location: Vector2i) -> void:
		id = p_id
		resource_type = p_resource
		boom_type = p_boom_type
		location = p_location
		
		if p_boom_type == BoomType.ABUNDANCE:
			price_multiplier = 0.5
		else:
			price_multiplier = 2.0


func _init(p_event_system: EnvironmentalEventSystem = null) -> void:
	if p_event_system:
		event_system = p_event_system
	else:
		event_system = EnvironmentalEventSystem.new()
	
	booms = {}
	_initialize_resource_prices()


func _initialize_resource_prices() -> void:
	for resource in ResourceType.keys():
		resource_prices[resource] = 1.0


func create_boom(resource_type: int, boom_type: int, location: Vector2i) -> String:
	var boom_id = "boom_%d_%s" % [booms.size(), ResourceType.keys()[resource_type].to_lower()]
	
	var boom = ResourceBoom.new(boom_id, resource_type, boom_type, location)
	booms[boom_id] = boom
	
	var event_id = event_system.generate_event(EnvironmentalEventSystem.EventType.RESOURCE_BOOM, location, 2)
	
	boom_created.emit(boom_id, ResourceType.keys()[resource_type])
	
	if boom_type == BoomType.ABUNDANCE:
		price_crashed.emit(ResourceType.keys()[resource_type], boom.price_multiplier)
	else:
		price_spiked.emit(ResourceType.keys()[resource_type], boom.price_multiplier)
	
	return boom_id


func get_boom(boom_id: String) -> ResourceBoom:
	return booms.get(boom_id)


func process_boom_time(boom_id: String, tick_delta: int) -> void:
	var boom = booms.get(boom_id)
	if not boom:
		return
	
	boom.elapsed_time += tick_delta
	
	if boom.elapsed_time >= boom.duration:
		resolve_boom(boom_id)


func resolve_boom(boom_id: String) -> void:
	if booms.has(boom_id):
		booms.erase(boom_id)
		boom_resolved.emit(boom_id)


func get_price_multiplier(resource_type: int, location: Vector2i) -> float:
	var multiplier = 1.0
	
	for boom in booms.values():
		if boom.resource_type == resource_type:
			var distance = boom.location.distance_to(location)
			if distance <= boom.radius:
				var intensity = 1.0 - (distance / boom.radius)
				multiplier *= (1.0 + (boom.price_multiplier - 1.0) * intensity)
	
	return multiplier


func get_active_booms() -> Array:
	return booms.values()


func get_booms_at_location(location: Vector2i, radius: int = 75) -> Array:
	var nearby = []
	for boom in booms.values():
		var distance = boom.location.distance_to(location)
		if distance <= radius:
			nearby.append(boom)
	return nearby


func get_booms_by_resource(resource_type: int) -> Array:
	var of_resource = []
	for boom in booms.values():
		if boom.resource_type == resource_type:
			of_resource.append(boom)
	return of_resource


func get_boom_info(boom_id: String) -> Dictionary:
	var boom = booms.get(boom_id)
	if not boom:
		return {}
	
	return {
		"id": boom.id,
		"resource": ResourceType.keys()[boom.resource_type],
		"type": BoomType.keys()[boom.boom_type],
		"location": boom.location,
		"price_multiplier": boom.price_multiplier,
		"duration_remaining": boom.duration - boom.elapsed_time,
		"radius": boom.radius
	}


func get_regional_scarcity(location: Vector2i) -> Dictionary:
	var scarcity = {}
	
	for boom in booms.values():
		if boom.boom_type == BoomType.SCARCITY:
			var distance = boom.location.distance_to(location)
			if distance <= boom.radius:
				var resource = ResourceType.keys()[boom.resource_type]
				var intensity = 1.0 - (distance / boom.radius)
				scarcity[resource] = max(scarcity.get(resource, 0.0), intensity)
	
	return scarcity


func get_regional_abundance(location: Vector2i) -> Dictionary:
	var abundance = {}
	
	for boom in booms.values():
		if boom.boom_type == BoomType.ABUNDANCE:
			var distance = boom.location.distance_to(location)
			if distance <= boom.radius:
				var resource = ResourceType.keys()[boom.resource_type]
				var intensity = 1.0 - (distance / boom.radius)
				abundance[resource] = max(abundance.get(resource, 0.0), intensity)
	
	return abundance
