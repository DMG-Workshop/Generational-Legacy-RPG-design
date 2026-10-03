## Unit tests for the world system (9 realms, chunks, persistence)

extends GutTest


var world: WorldManager


func before_each() -> void:
	world = WorldManager.new()


## Test: All 9 realms initialized
func test_all_nine_realms_exist() -> void:
	var realm_ids = ["material", "verdant", "hollow", "celestial",
	                  "elemental_fire", "elemental_frost", "elemental_storm", "elemental_earth",
	                  "dragon_isles", "dreamlands", "void", "clockwork"]

	for realm_id in realm_ids:
		var realm = world.get_realm(realm_id)
		assert_not_null(realm)
		assert_eq(realm.id, realm_id)


## Test: Realm properties
func test_realm_time_multipliers() -> void:
	var material = world.get_realm("material")
	assert_eq(material.time_multiplier, 1.0)  # 1:1 time

	var verdant = world.get_realm("verdant")
	assert_eq(verdant.time_multiplier, 365.0)  # 1 day = 1 year

	var hollow = world.get_realm("hollow")
	assert_eq(hollow.time_multiplier, 0.01)  # Time barely passes


## Test: Chunk creation and retrieval
func test_chunk_generation() -> void:
	var realm = world.get_realm("material")
	var chunk = realm.get_chunk(0, 0, 0)

	assert_not_null(chunk)
	assert_eq(chunk.x, 0)
	assert_eq(chunk.y, 0)
	assert_eq(chunk.z, 0)
	assert_eq(chunk.realm, "material")


## Test: Chunks are procedurally generated
func test_chunk_procedural_generation() -> void:
	var realm = world.get_realm("material")

	var chunk1 = realm.get_chunk(0, 0, 0)
	var chunk2 = realm.get_chunk(1, 0, 0)
	var chunk3 = realm.get_chunk(0, 0, 1)

	# Different positions should have different tiles
	assert_not_equal(chunk1.get_tile(0, 0), chunk2.get_tile(0, 0))

	# Retrieving same chunk returns same object
	var chunk1_again = realm.get_chunk(0, 0, 0)
	assert_eq(chunk1, chunk1_again)


## Test: Layer-based generation (surface vs. underground vs. deep)
func test_layer_based_generation() -> void:
	var realm = world.get_realm("material")

	# Surface layer (z=0) should have grass, forest, water
	var surface = realm.get_chunk(0, 0, 0)
	var surface_tiles = []
	for x in range(16):
		for y in range(16):
			surface_tiles.append(surface.get_tile(x, y))

	# Should have variety
	var unique_surface = surface_tiles.get_slice(0).size()
	assert_gt(unique_surface, 1)

	# Underground (z=10) should have stone, ore, caves
	var underground = realm.get_chunk(0, 0, 10)
	var underground_tiles = []
	for x in range(16):
		for y in range(16):
			underground_tiles.append(underground.get_tile(x, y))

	assert_gt(underground_tiles.size(), 0)


## Test: Teleportation between realms
func test_teleport_to_realm() -> void:
	assert_eq(world.current_realm.id, "material")

	var success = world.teleport_to_realm("verdant", 10, 10, 0)

	assert_true(success)
	assert_eq(world.current_realm.id, "verdant")
	assert_true(world.current_realm.is_visited)


## Test: Move player in realm
func test_player_movement() -> void:
	var initial_pos = world.player_chunk

	world.move_player(1, 0, 0)

	assert_eq(world.player_chunk.x, initial_pos.x + 1)
	assert_eq(world.player_chunk.y, initial_pos.y)


## Test: Digging down explores deeper history
func test_dig_down_increases_z() -> void:
	var initial_z = world.player_chunk.z

	world.dig_down()

	assert_eq(world.player_chunk.z, initial_z + 1)


## Test: Build structure on chunk
func test_build_structure() -> void:
	var realm = world.get_realm("material")
	var chunk = realm.get_chunk(0, 0, 0)

	world.build_structure("house", "bloodline_1")

	assert_gt(chunk.structures.size(), 0)
	assert_eq(chunk.structures[0]["type"], "house")


## Test: Claim family property
func test_claim_property() -> void:
	var property = world.claim_property("material", "estate")

	assert_eq(property["realm"], "material")
	assert_eq(property["type"], "estate")
	assert_eq(property["maintenance"], 100)


## Test: List family properties in realm
func test_get_properties_by_realm() -> void:
	world.claim_property("material", "estate")
	world.claim_property("material", "smithy")
	world.claim_property("verdant", "trading_post")

	var material_props = world.get_properties_in_realm("material")
	var verdant_props = world.get_properties_in_realm("verdant")

	assert_eq(material_props.size(), 2)
	assert_eq(verdant_props.size(), 1)


## Test: Time dilation calculation
func test_time_dilation() -> void:
	world.teleport_to_realm("verdant", 0, 0, 0)
	var elapsed_time = world.get_elapsed_time_at_home(1.0)

	assert_eq(elapsed_time, 365.0)  # 1 day in Verdant = 365 days at home


## Test: Access restrictions (trait-gated realms)
func test_access_restrictions() -> void:
	var heir_traits = ["noble_blood", "mageblood"]
	var accessible = world.get_accessible_realms(heir_traits)

	# Should have material, dreamlands, and others without restrictions
	var accessible_ids = accessible.map(func(r): return r.id)

	assert_true("material" in accessible_ids)

	# Verdant requires "faetouched" - heir doesn't have it
	assert_false("verdant" in accessible_ids)


## Test: Accessible realms with correct traits
func test_accessible_realms_with_traits() -> void:
	var heir_traits = ["faetouched", "dragonblood", "marked_by_death"]
	var accessible = world.get_accessible_realms(heir_traits)

	var accessible_ids = accessible.map(func(r): return r.id)

	# Should have trait-gated realms now
	assert_true("verdant" in accessible_ids)  # Faetouched
	assert_true("dragon_isles" in accessible_ids)  # Dragonblood
	assert_true("hollow" in accessible_ids)  # Marked by Death


## Test: Waystone network
func test_waystone_teleportation() -> void:
	world.add_waystone("material", 10, 10, 0)
	world.add_waystone("verdant", 20, 20, 0)

	world.connect_waystones("material", Vector3i(10, 10, 0), "verdant", Vector3i(20, 20, 0))

	# Teleport via waystone
	var success = world.teleport_to_realm("verdant", 20, 20, 0)
	assert_true(success)


## Test: World summary
func test_world_summary() -> void:
	world.claim_property("material", "estate")
	world.claim_property("verdant", "trading_post")

	var summary = world.to_summary()

	assert_eq(summary["current_realm"], "material")
	assert_eq(summary["family_properties"], 2)
	assert_true(summary.has("realms"))
	assert_eq(summary["realms"].size(), 12)  # All realms


## Test: Chunk decay over generations
func test_chunk_decay_over_time() -> void:
	var realm = world.get_realm("material")
	var chunk = realm.get_chunk(0, 0, 0)

	assert_eq(chunk.maintenance_level, 100)

	# Simulate 15 generations of neglect
	realm.apply_decay(chunk, 15)

	assert_lt(chunk.maintenance_level, 100)


## Test: Multiple chunks in realm
func test_multiple_chunks_loading() -> void:
	var realm = world.get_realm("material")

	for x in range(3):
		for y in range(3):
			realm.get_chunk(x, y, 0)

	assert_eq(realm.get_loaded_chunk_count(), 9)


## Test: Chunk unloading
func test_chunk_unloading() -> void:
	var realm = world.get_realm("material")

	realm.get_chunk(0, 0, 0)
	realm.get_chunk(1, 0, 0)

	assert_eq(realm.get_loaded_chunk_count(), 2)

	realm.unload_chunk(0, 0, 0)

	assert_eq(realm.get_loaded_chunk_count(), 1)
