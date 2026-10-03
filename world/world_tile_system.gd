## World Tile System: Persistent tile-based world with chunk loading
##
## Manages terrain generation, chunk persistence, and tile-based exploration
## Seed-based generation ensures reproducibility across saves

class_name WorldTileSystem


signal chunk_loaded(chunk_coord: Vector2i)
signal chunk_unloaded(chunk_coord: Vector2i)
signal tile_changed(tile_pos: Vector2i, tile_type: String)


enum TileType { GRASS, FOREST, WATER, MOUNTAIN, SETTLEMENT, DUNGEON, CAVE, DESERT }

# World configuration
var world_seed: int = 12345
var chunk_size: int = 16  # tiles per chunk
var loaded_chunks: Dictionary = {}  # Vector2i -> chunk data
var max_loaded_chunks: int = 9  # 3x3 grid around player

# Tile type distribution
var tile_generation_weights: Dictionary = {
	TileType.GRASS: 0.4,
	TileType.FOREST: 0.2,
	TileType.WATER: 0.15,
	TileType.MOUNTAIN: 0.15,
	TileType.DUNGEON: 0.05,
	TileType.CAVE: 0.03,
	TileType.DESERT: 0.02,
}

# Persistence
var save_path: String = "user://world/chunks/"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(save_path):
		DirAccess.make_abs_absolute(save_path)


## Generate world with seed
func initialize_world(seed_value: int) -> void:
	world_seed = seed_value
	seed(world_seed)


## Load chunk (generate if not saved)
func load_chunk(chunk_coord: Vector2i) -> Dictionary:
	if chunk_coord in loaded_chunks:
		return loaded_chunks[chunk_coord]

	var chunk = _load_chunk_from_disk(chunk_coord)
	if chunk.is_empty():
		chunk = _generate_chunk(chunk_coord)
		_save_chunk_to_disk(chunk_coord, chunk)

	loaded_chunks[chunk_coord] = chunk
	chunk_loaded.emit(chunk_coord)
	return chunk


## Unload chunk (save before unloading)
func unload_chunk(chunk_coord: Vector2i) -> void:
	if chunk_coord in loaded_chunks:
		_save_chunk_to_disk(chunk_coord, loaded_chunks[chunk_coord])
		loaded_chunks.erase(chunk_coord)
		chunk_unloaded.emit(chunk_coord)


## Get tile at world position
func get_tile(world_pos: Vector2i) -> String:
	var chunk_coord = _world_to_chunk_coord(world_pos)
	var tile_offset = _world_to_tile_offset(world_pos)

	var chunk = load_chunk(chunk_coord)
	if "tiles" in chunk:
		if tile_offset.y < chunk["tiles"].size():
			if tile_offset.x < chunk["tiles"][tile_offset.y].size():
				return chunk["tiles"][tile_offset.y][tile_offset.x]

	return TileType.keys()[TileType.GRASS]


## Set tile at world position
func set_tile(world_pos: Vector2i, tile_type: String) -> void:
	var chunk_coord = _world_to_chunk_coord(world_pos)
	var tile_offset = _world_to_tile_offset(world_pos)

	var chunk = load_chunk(chunk_coord)
	if "tiles" in chunk:
		if tile_offset.y < chunk["tiles"].size():
			if tile_offset.x < chunk["tiles"][tile_offset.y].size():
				chunk["tiles"][tile_offset.y][tile_offset.x] = tile_type
				tile_changed.emit(world_pos, tile_type)


## Get tiles in region
func get_region_tiles(start_pos: Vector2i, width: int, height: int) -> Array:
	var tiles = []
	for y in range(height):
		var row = []
		for x in range(width):
			row.append(get_tile(start_pos + Vector2i(x, y)))
		tiles.append(row)
	return tiles


## Internal: Generate chunk procedurally
func _generate_chunk(chunk_coord: Vector2i) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed + chunk_coord.x * 73856093 ^ chunk_coord.y * 19349663

	var tiles = []
	for ty in range(chunk_size):
		var row = []
		for tx in range(chunk_size):
			var tile_type = _select_tile_type(rng)
			row.append(TileType.keys()[tile_type])
		tiles.append(row)

	return {
		"coord": chunk_coord,
		"tiles": tiles,
		"generated_at": Time.get_ticks_msec(),
		"modified": false,
	}


## Internal: Select tile type based on weights
func _select_tile_type(rng: RandomNumberGenerator) -> int:
	var rand = rng.randf()
	var cumulative = 0.0

	for tile_type in tile_generation_weights.keys():
		cumulative += tile_generation_weights[tile_type]
		if rand < cumulative:
			return tile_type

	return TileType.GRASS


## Internal: World position to chunk coordinate
func _world_to_chunk_coord(world_pos: Vector2i) -> Vector2i:
	return Vector2i(
		floordiv(world_pos.x, chunk_size),
		floordiv(world_pos.y, chunk_size)
	)


## Internal: World position to tile offset within chunk
func _world_to_tile_offset(world_pos: Vector2i) -> Vector2i:
	var chunk_coord = _world_to_chunk_coord(world_pos)
	return Vector2i(
		world_pos.x - (chunk_coord.x * chunk_size),
		world_pos.y - (chunk_coord.y * chunk_size)
	)


## Internal: Load chunk from disk
func _load_chunk_from_disk(chunk_coord: Vector2i) -> Dictionary:
	var file_path = save_path + "chunk_%d_%d.json" % [chunk_coord.x, chunk_coord.y]
	if ResourceLoader.exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			return json if json else {}
	return {}


## Internal: Save chunk to disk
func _save_chunk_to_disk(chunk_coord: Vector2i, chunk: Dictionary) -> void:
	var file_path = save_path + "chunk_%d_%d.json" % [chunk_coord.x, chunk_coord.y]
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(chunk))


## Get world statistics
func get_world_stats() -> Dictionary:
	var stats = {
		"seed": world_seed,
		"loaded_chunks": loaded_chunks.size(),
		"chunk_size": chunk_size,
	}
	return stats
