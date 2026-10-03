## Manages all 9 realms and cross-world teleportation
##
## The player's family expands across multiple worlds linked by portals,
## each with unique resources, dangers, and time dilation.

extends Node

class_name WorldManager


## All realms in the game
var realms: Dictionary = {}

## Current realm
var current_realm: Realm = null

## Player location in current realm
var player_chunk: Vector3i = Vector3i.ZERO

## Teleport network (graph of connected portals)
var teleport_network: Dictionary = {}  # key: "realm:x,y,z", value: ["realm:x,y,z", ...]

## Cross-realm properties (estates, businesses, etc.)
var family_properties: Array[Dictionary] = []


func _init() -> void:
	_initialize_realms()


## Create all 9 realms
func _initialize_realms() -> void:
	# Material Realm (home)
	realms["material"] = Realm.new("material", "Material Realm", 42)
	realms["material"].time_multiplier = 1.0
	realms["material"].unique_resources = ["iron", "copper", "wheat"]
	realms["material"].danger_level = 2

	# Verdant Court (Fae realm)
	realms["verdant"] = Realm.new("verdant", "Verdant Court", 123)
	realms["verdant"].time_multiplier = 365.0  # 1 day = 1 year
	realms["verdant"].unique_resources = ["fae_silk", "glamour_crystal", "moonwood"]
	realms["verdant"].danger_level = 3
	realms["verdant"].access_restrictions = ["faetouched"]

	# Hollow Below (realm of the dead)
	realms["hollow"] = Realm.new("hollow", "Hollow Below", 456)
	realms["hollow"].time_multiplier = 0.01  # Time barely passes
	realms["hollow"].unique_resources = ["soul_gem", "grave_iron", "ancestral_relic"]
	realms["hollow"].danger_level = 4
	realms["hollow"].access_restrictions = ["marked_by_death"]

	# Celestial Spires (divine realm)
	realms["celestial"] = Realm.new("celestial", "Celestial Spires", 789)
	realms["celestial"].time_multiplier = 120.0  # 1 month = 10 years
	realms["celestial"].unique_resources = ["starmetal", "holy_essence", "god_stone"]
	realms["celestial"].danger_level = 4
	realms["celestial"].access_restrictions = ["divine_favor"]

	# Elemental Planes (4 variants: fire, frost, storm, earth)
	var elements = ["fire", "frost", "storm", "earth"]
	for element in elements:
		var realm_id = "elemental_" + element
		realms[realm_id] = Realm.new(realm_id, "Elemental Plane: " + element.capitalize(), hash(element))
		realms[realm_id].time_multiplier = 2.0
		realms[realm_id].unique_resources = [element + "_core", "elemental_essence"]
		realms[realm_id].danger_level = 5  # Extreme

	# Dragon Isles (floating sky archipelago)
	realms["dragon_isles"] = Realm.new("dragon_isles", "Dragon Isles", 1011)
	realms["dragon_isles"].time_multiplier = 1.5
	realms["dragon_isles"].unique_resources = ["dragonbone", "dragon_scale", "sky_ore"]
	realms["dragon_isles"].danger_level = 5
	realms["dragon_isles"].access_restrictions = ["dragonblood"]

	# Dreamlands (self-reshaping)
	realms["dreamlands"] = Realm.new("dreamlands", "Dreamlands", 1213)
	realms["dreamlands"].time_multiplier = randf_range(0.5, 2.0)  # Random time
	realms["dreamlands"].unique_resources = ["dream_essence", "memory_shard"]
	realms["dreamlands"].danger_level = 3

	# The Void (appears after Sundering)
	realms["void"] = Realm.new("void", "The Void", 1415)
	realms["void"].time_multiplier = -1.0  # Time flows backward
	realms["void"].unique_resources = ["voidglass", "rift_crystal"]
	realms["void"].danger_level = 5
	realms["void"].access_restrictions = ["after_sundering"]

	# Clockwork Expanse (Arcane Industry age)
	realms["clockwork"] = Realm.new("clockwork", "Clockwork Expanse", 1617)
	realms["clockwork"].time_multiplier = 1.2
	realms["clockwork"].unique_resources = ["aetherium", "gear", "golem_core"]
	realms["clockwork"].danger_level = 4
	realms["clockwork"].access_restrictions = ["arcane_industry"]

	# Set Material Realm as current
	current_realm = realms["material"]


## Get a realm by ID
func get_realm(realm_id: String) -> Realm:
	return realms.get(realm_id, null)


## Switch to a different realm via teleportation
func teleport_to_realm(realm_id: String, x: int, y: int, z: int) -> bool:
	if not realms.has(realm_id):
		return false

	current_realm = realms[realm_id]
	player_chunk = Vector3i(x, y, z)

	# Mark realm as visited
	current_realm.is_visited = true

	return true


## Get tile at current location
func get_current_tile() -> String:
	if current_realm == null:
		return "void"

	var chunk = current_realm.get_chunk(player_chunk.x, player_chunk.y, player_chunk.z)
	var local_x = int(player_chunk.x) % 16
	var local_y = int(player_chunk.y) % 16

	return chunk.get_tile(local_x, local_y)


## Move player in current realm
func move_player(dx: int, dy: int, dz: int) -> bool:
	if current_realm == null:
		return false

	var new_pos = player_chunk + Vector3i(dx, dy, dz)

	# Bounds check
	if new_pos.z < 0 or new_pos.z >= current_realm.depth_chunks:
		return false

	player_chunk = new_pos
	return true


## Dig down (move to lower z-coordinate, going back in time)
func dig_down() -> bool:
	return move_player(0, 0, 1)


## Build a structure at current location
func build_structure(structure_type: String, owner: String = "") -> bool:
	if current_realm == null:
		return false

	var chunk = current_realm.get_chunk(player_chunk.x, player_chunk.y, player_chunk.z)

	var structure = {
		"type": structure_type,
		"owner": owner,
		"built_generation": 0,  # Will be set by game logic
		"maintenance": 100,
	}

	chunk.add_structure(structure)
	chunk.owner = owner

	return true


## Claim a property for the family
func claim_property(realm_id: String, property_type: String) -> Dictionary:
	var property = {
		"realm": realm_id,
		"type": property_type,  # "estate", "business", "tomb", etc.
		"chunk": player_chunk,
		"maintenance": 100,
		"built_generation": 0,
		"residents": [],
	}

	family_properties.append(property)

	return property


## Get all family properties
func get_family_properties() -> Array[Dictionary]:
	return family_properties


## Get family properties in a realm
func get_properties_in_realm(realm_id: String) -> Array[Dictionary]:
	return family_properties.filter(func(p): return p["realm"] == realm_id)


## Calculate elapsed time in a realm
func get_elapsed_time_at_home(days_in_realm: float) -> float:
	if current_realm == null:
		return days_in_realm

	return days_in_realm * current_realm.time_multiplier


## Add a waystone (fast travel point)
func add_waystone(realm_id: String, x: int, y: int, z: int) -> void:
	var key = "%s:%d,%d,%d" % [realm_id, x, y, z]

	if not teleport_network.has(key):
		teleport_network[key] = []


## Connect two waystones
func connect_waystones(from_realm: String, from_pos: Vector3i,
                       to_realm: String, to_pos: Vector3i) -> void:
	var from_key = "%s:%d,%d,%d" % [from_realm, from_pos.x, from_pos.y, from_pos.z]
	var to_key = "%s:%d,%d,%d" % [to_realm, to_pos.x, to_pos.y, to_pos.z]

	if not teleport_network.has(from_key):
		teleport_network[from_key] = []
	if not teleport_network.has(to_key):
		teleport_network[to_key] = []

	teleport_network[from_key].append(to_key)
	teleport_network[to_key].append(from_key)


## Get accessible realms (considering trait restrictions)
func get_accessible_realms(heir_traits: Array[String]) -> Array[Realm]:
	var accessible: Array[Realm] = []

	for realm in realms.values():
		var has_access = true

		for restriction in realm.access_restrictions:
			if restriction not in heir_traits:
				has_access = false
				break

		if has_access:
			accessible.append(realm)

	return accessible


## Get world summary for lightweight simulation
func to_summary() -> Dictionary:
	var realm_summaries = {}
	for realm_id in realms.keys():
		realm_summaries[realm_id] = realms[realm_id].to_summary()

	return {
		"current_realm": current_realm.id if current_realm else "none",
		"player_chunk": player_chunk,
		"realms": realm_summaries,
		"family_properties": family_properties.size(),
	}
