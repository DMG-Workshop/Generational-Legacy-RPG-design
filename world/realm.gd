## A world realm: Material Realm, Verdant Court, Hollow Below, etc.
##
## Each realm is a persistent world with:
## - Chunk-based tile data
## - Time multipliers relative to home
## - Unique resources and dangers
## - Maintenance and decay

extends Node

class_name Realm


## Realm definition
var id: String = ""
var name: String = ""
var description: String = ""

## Size (in chunks)
var width_chunks: int = 100
var height_chunks: int = 100
var depth_chunks: int = 50  # Vertical layers

## Time dilation relative to Material Realm
## (1 day here = X years home)
var time_multiplier: float = 1.0

## Resources found here
var unique_resources: Array[String] = []

## Dangers and creatures
var native_creatures: Array[String] = []
var danger_level: int = 1  # 1-5 (peaceful to deadly)

## Chunk data (sparse; only loaded chunks stored)
var loaded_chunks: Dictionary = {}  # key: "x,y,z", value: Chunk

## Access permissions (bloodline-locked gates, etc.)
var access_restrictions: Array[String] = []

## World seed for procedural generation
var seed_value: int = 0

## Visited state
var is_visited: bool = false
var first_visit_year: int = -1


func _init(p_id: String, p_name: String, p_seed: int = 0) -> void:
	id = p_id
	name = p_name
	seed_value = p_seed if p_seed != 0 else hash(p_id)


## Get or create a chunk at position
func get_chunk(x: int, y: int, z: int) -> Chunk:
	var chunk_key = "%d,%d,%d" % [x, y, z]

	if not loaded_chunks.has(chunk_key):
		loaded_chunks[chunk_key] = _generate_chunk(x, y, z)

	return loaded_chunks[chunk_key]


## Generate a chunk procedurally
func _generate_chunk(x: int, y: int, z: int) -> Chunk:
	var chunk = Chunk.new()
	chunk.realm = id
	chunk.x = x
	chunk.y = y
	chunk.z = z
	chunk.seed = seed_value + x * 73856093 ^ y * 19349663 ^ z * 83492791

	# Procedural generation based on seed and depth
	if z == 0:
		# Surface layer: more varied
		_generate_surface_chunk(chunk)
	elif z < 20:
		# Underground: caves, ore
		_generate_cave_chunk(chunk)
	else:
		# Deep: rare resources, ancient structures
		_generate_deep_chunk(chunk)

	return chunk


## Generate surface chunk (z=0)
func _generate_surface_chunk(chunk: Chunk) -> void:
	for x in range(16):
		for y in range(16):
			var rand = (chunk.seed + x * 7 + y * 11) % 100

			if rand < 30:
				chunk.set_tile(x, y, "grass")
			elif rand < 50:
				chunk.set_tile(x, y, "forest")
			elif rand < 60:
				chunk.set_tile(x, y, "water")
			elif rand < 65:
				chunk.set_tile(x, y, "mountain")
			else:
				chunk.set_tile(x, y, "grass")


## Generate underground chunk (z < 20)
func _generate_cave_chunk(chunk: Chunk) -> void:
	for x in range(16):
		for y in range(16):
			var rand = (chunk.seed + x * 7 + y * 11) % 100

			if rand < 70:
				chunk.set_tile(x, y, "stone")
			elif rand < 85:
				chunk.set_tile(x, y, "ore")
			elif rand < 95:
				chunk.set_tile(x, y, "cave")
			else:
				chunk.set_tile(x, y, "rare_ore")


## Generate deep chunk (z > 20)
func _generate_deep_chunk(chunk: Chunk) -> void:
	for x in range(16):
		for y in range(16):
			var rand = (chunk.seed + x * 7 + y * 11) % 100

			if rand < 50:
				chunk.set_tile(x, y, "bedrock")
			elif rand < 75:
				chunk.set_tile(x, y, "ancient_stone")
			elif rand < 90:
				chunk.set_tile(x, y, "ley_vein")
			else:
				chunk.set_tile(x, y, "void_crystal")


## Check if a chunk needs maintenance
func does_chunk_need_maintenance(chunk: Chunk) -> bool:
	return chunk.maintenance_level < 100


## Apply decay to a chunk
func apply_decay(chunk: Chunk, generations_since_visit: int) -> void:
	# Decay increases with time
	if generations_since_visit > 10:
		chunk.maintenance_level = max(0, chunk.maintenance_level - 20)
	if generations_since_visit > 20:
		chunk.maintenance_level = max(0, chunk.maintenance_level - 30)
	if generations_since_visit > 50:
		chunk.maintenance_level = 0  # Fully decayed


## Unload a chunk to save memory
func unload_chunk(x: int, y: int, z: int) -> void:
	var chunk_key = "%d,%d,%d" % [x, y, z]
	if loaded_chunks.has(chunk_key):
		loaded_chunks.erase(chunk_key)


## Get chunk count
func get_loaded_chunk_count() -> int:
	return loaded_chunks.size()


## Get realm summary for lightweight simulation
func to_summary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"time_multiplier": time_multiplier,
		"is_visited": is_visited,
		"loaded_chunks": get_loaded_chunk_count(),
		"danger_level": danger_level,
	}


## Chunk: a 16x16 tile area
class Chunk:
	var realm: String = ""
	var x: int = 0
	var y: int = 0
	var z: int = 0
	var seed: int = 0

	var tiles: Array = []  # 16x16 grid
	var structures: Array = []  # Buildings, shrines, etc.
	var entities: Array = []  # NPCs, creatures

	var maintenance_level: int = 100  # 0-100
	var last_maintained_generation: int = -1
	var owner: String = ""  # Bloodline ID if claimed


	func _init() -> void:
		tiles = []
		for x in range(16):
			var row = []
			for y in range(16):
				row.append("empty")
			tiles.append(row)


	func set_tile(x: int, y: int, tile_type: String) -> void:
		if x >= 0 and x < 16 and y >= 0 and y < 16:
			tiles[x][y] = tile_type


	func get_tile(x: int, y: int) -> String:
		if x >= 0 and x < 16 and y >= 0 and y < 16:
			return tiles[x][y]
		return "void"


	func add_structure(structure: Dictionary) -> void:
		structures.append(structure)


	func to_summary() -> Dictionary:
		return {
			"position": "%d,%d,%d" % [x, y, z],
			"tile_count": 16 * 16,
			"structures": structures.size(),
			"maintenance": maintenance_level,
			"owner": owner
		}
