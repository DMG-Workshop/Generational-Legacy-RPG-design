## Tests for Phase 9: World Systems
##
## Tests: WorldTileSystem, SettlementSystem, NPCSystem, WorldHeirIntegration

extends GutTest


var world_system: WorldTileSystem
var settlement_system: SettlementSystem
var npc_system: NPCSystem
var world_integration: WorldHeirIntegration


func before_each() -> void:
	world_system = WorldTileSystem.new()
	settlement_system = SettlementSystem.new()
	npc_system = NPCSystem.new()
	world_integration = WorldHeirIntegration.new(world_system, settlement_system, npc_system)


# ========== WorldTileSystem Tests ==========

## Test: World initialization
func test_world_init() -> void:
	world_system.initialize_world(12345)
	assert_eq(world_system.world_seed, 12345)


## Test: Chunk loading
func test_world_chunk_loading() -> void:
	world_system.initialize_world(12345)
	var chunk = world_system.load_chunk(Vector2i(0, 0))
	assert_true("tiles" in chunk)
	assert_eq(chunk["tiles"].size(), world_system.chunk_size)


## Test: Tile access
func test_world_tile_access() -> void:
	world_system.initialize_world(12345)
	var tile = world_system.get_tile(Vector2i(0, 0))
	assert_true(tile in WorldTileSystem.TileType.keys())


## Test: Tile setting
func test_world_tile_setting() -> void:
	world_system.initialize_world(12345)
	world_system.set_tile(Vector2i(0, 0), "SETTLEMENT")
	assert_eq(world_system.get_tile(Vector2i(0, 0)), "SETTLEMENT")


## Test: Region retrieval
func test_world_region_retrieval() -> void:
	world_system.initialize_world(12345)
	var region = world_system.get_region_tiles(Vector2i(0, 0), 5, 5)
	assert_eq(region.size(), 5)
	assert_eq(region[0].size(), 5)


## Test: Multiple chunk loading
func test_world_multiple_chunks() -> void:
	world_system.initialize_world(12345)
	world_system.load_chunk(Vector2i(0, 0))
	world_system.load_chunk(Vector2i(1, 0))
	world_system.load_chunk(Vector2i(0, 1))
	assert_eq(world_system.loaded_chunks.size(), 3)


## Test: Chunk unloading
func test_world_chunk_unload() -> void:
	world_system.initialize_world(12345)
	world_system.load_chunk(Vector2i(0, 0))
	assert_eq(world_system.loaded_chunks.size(), 1)
	world_system.unload_chunk(Vector2i(0, 0))
	assert_eq(world_system.loaded_chunks.size(), 0)


## Test: Deterministic generation (same seed produces same world)
func test_world_deterministic() -> void:
	world_system.initialize_world(12345)
	var tile1 = world_system.get_tile(Vector2i(100, 100))

	var world_system2 = WorldTileSystem.new()
	world_system2.initialize_world(12345)
	var tile2 = world_system2.get_tile(Vector2i(100, 100))

	assert_eq(tile1, tile2)


## Test: World statistics
func test_world_stats() -> void:
	world_system.initialize_world(12345)
	world_system.load_chunk(Vector2i(0, 0))
	var stats = world_system.get_world_stats()
	assert_eq(stats["seed"], 12345)
	assert_gt(stats["loaded_chunks"], 0)


# ========== SettlementSystem Tests ==========

## Test: Settlement creation
func test_settlement_creation() -> void:
	var settlement = settlement_system.create_settlement("TestTown", Vector2i(100, 100), "neutral")
	assert_eq(settlement["name"], "TestTown")
	assert_eq(settlement["position"], Vector2i(100, 100))


## Test: Settlement retrieval
func test_settlement_retrieval() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	var settlement = settlement_system.get_settlement("TestTown")
	assert_eq(settlement["name"], "TestTown")


## Test: All settlements
func test_settlement_get_all() -> void:
	settlement_system.create_settlement("Town1", Vector2i(0, 0))
	settlement_system.create_settlement("Town2", Vector2i(100, 100))
	var all = settlement_system.get_all_settlements()
	assert_eq(all.size(), 2)


## Test: Nearest settlement
func test_settlement_nearest() -> void:
	settlement_system.create_settlement("Town1", Vector2i(0, 0))
	settlement_system.create_settlement("Town2", Vector2i(500, 500))
	var nearest = settlement_system.get_nearest_settlement(Vector2i(10, 10))
	assert_eq(nearest, "Town1")


## Test: Building upgrade
func test_settlement_building_upgrade() -> void:
	var settlement = settlement_system.create_settlement("TestTown", Vector2i(0, 0))
	var initial_level = settlement["buildings"][SettlementSystem.BuildingType.SHRINE]
	assert_true(settlement_system.upgrade_building("TestTown", SettlementSystem.BuildingType.SHRINE))
	var updated = settlement_system.get_settlement("TestTown")
	assert_gt(updated["buildings"][SettlementSystem.BuildingType.SHRINE], initial_level)


## Test: Building effects
func test_settlement_building_effects() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(0, 0))
	var effects = settlement_system.get_building_effects("TestTown")
	assert_gt(effects.size(), 0)


## Test: Resource management
func test_settlement_add_resources() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(0, 0))
	var initial = settlement_system.get_settlement("TestTown")["resources"]["gold"]
	settlement_system.add_resources("TestTown", {"gold": 100})
	var updated = settlement_system.get_settlement("TestTown")["resources"]["gold"]
	assert_gt(updated, initial)


## Test: Remove resources
func test_settlement_remove_resources() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(0, 0))
	var success = settlement_system.remove_resources("TestTown", {"gold": 100})
	assert_true(success)


## Test: Production simulation
func test_settlement_production() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(0, 0))
	var produced = settlement_system.simulate_production("TestTown", 1)
	assert_gt(produced.size(), 0)


## Test: Settlement summary
func test_settlement_summary() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(0, 0))
	var summary = settlement_system.get_settlement_summary("TestTown")
	assert_eq(summary["name"], "TestTown")
	assert_true("buildings" in summary)


# ========== NPCSystem Tests ==========

## Test: NPC creation
func test_npc_creation() -> void:
	var npc = npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	assert_eq(npc["name"], "Bob")
	assert_eq(npc["settlement"], "TestTown")


## Test: NPC retrieval
func test_npc_retrieval() -> void:
	npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	var npc = npc_system.get_npc("Bob")
	assert_eq(npc["name"], "Bob")


## Test: Settlement NPCs
func test_npc_settlement_npcs() -> void:
	npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	npc_system.create_npc("Alice", "TestTown", "mage", "wizard")
	npc_system.create_npc("Charlie", "OtherTown", "rogue", "thief")
	var town_npcs = npc_system.get_settlement_npcs("TestTown")
	assert_eq(town_npcs.size(), 2)


## Test: Quest generation
func test_npc_quest_generation() -> void:
	npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	var heir_stats = {"strength": 15, "dexterity": 12, "constitution": 14, "intelligence": 10, "wisdom": 11, "charisma": 13}
	var quest = npc_system.generate_quest("Bob", "Hero", heir_stats)
	assert_true("id" in quest)
	assert_eq(quest["npc"], "Bob")


## Test: Quest completion
func test_npc_quest_completion() -> void:
	npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	var heir_stats = {"strength": 15, "dexterity": 12, "constitution": 14, "intelligence": 10, "wisdom": 11, "charisma": 13}
	var quest = npc_system.generate_quest("Bob", "Hero", heir_stats)
	var rewards = npc_system.complete_quest(quest["id"], "Hero", true)
	assert_gt(rewards["gold"], 0)
	assert_gt(rewards["xp"], 0)


## Test: Quest failure penalty
func test_npc_quest_failure() -> void:
	npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	var heir_stats = {"strength": 15, "dexterity": 12, "constitution": 14, "intelligence": 10, "wisdom": 11, "charisma": 13}
	var quest = npc_system.generate_quest("Bob", "Hero", heir_stats)
	var rewards = npc_system.complete_quest(quest["id"], "Hero", false)
	assert_true("reputation" in rewards)


## Test: NPC recruitment
func test_npc_recruitment() -> void:
	npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	var success = npc_system.recruit_npc("Bob", "Hero", 100)
	assert_true(success)


## Test: Reputation tracking
func test_npc_reputation() -> void:
	npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	var initial_rep = npc_system.get_reputation("Hero", "Bob")
	assert_eq(initial_rep, 0)

	var heir_stats = {"strength": 15, "dexterity": 12, "constitution": 14, "intelligence": 10, "wisdom": 11, "charisma": 13}
	var quest = npc_system.generate_quest("Bob", "Hero", heir_stats)
	npc_system.complete_quest(quest["id"], "Hero", true)

	var new_rep = npc_system.get_reputation("Hero", "Bob")
	assert_gt(new_rep, initial_rep)


## Test: NPC summary
func test_npc_summary() -> void:
	npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	var summary = npc_system.get_npc_summary("Bob")
	assert_eq(summary["name"], "Bob")
	assert_true("personality" in summary)


# ========== WorldHeirIntegration Tests ==========

## Test: Heir initialization in world
func test_integration_heir_init() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	var pos = world_integration.initialize_heir_in_world("Hero", "TestTown")
	assert_eq(pos, Vector2i(100, 100))


## Test: Heir movement
func test_integration_heir_movement() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	world_integration.initialize_heir_in_world("Hero", "TestTown")
	var new_pos = world_integration.move_heir("Hero", Vector2i(1, 0), 10)
	assert_eq(new_pos, Vector2i(110, 100))


## Test: Get heir position
func test_integration_get_heir_position() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	world_integration.initialize_heir_in_world("Hero", "TestTown")
	var pos = world_integration.get_heir_position("Hero")
	assert_eq(pos, Vector2i(100, 100))


## Test: Settlement visit
func test_integration_settlement_visit() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	world_integration.initialize_heir_in_world("Hero", "TestTown")
	var visit_info = world_integration.visit_settlement("Hero", "TestTown")
	assert_true("settlement" in visit_info)
	assert_true("npcs" in visit_info)


## Test: Quest acceptance
func test_integration_quest_acceptance() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	world_integration.initialize_heir_in_world("Hero", "TestTown")

	var heir_stats = {"strength": 15, "dexterity": 12, "constitution": 14, "intelligence": 10, "wisdom": 11, "charisma": 13}
	var quest = world_integration.accept_quest("Hero", "Bob", heir_stats)
	assert_true("id" in quest)


## Test: Quest completion
func test_integration_quest_completion() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	world_integration.initialize_heir_in_world("Hero", "TestTown")

	var heir_stats = {"strength": 15, "dexterity": 12, "constitution": 14, "intelligence": 10, "wisdom": 11, "charisma": 13}
	var quest = world_integration.accept_quest("Hero", "Bob", heir_stats)
	var rewards = world_integration.complete_quest("Hero", quest["id"], true)
	assert_gt(rewards["gold"], 0)


## Test: Training at barracks
func test_integration_training() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	world_integration.initialize_heir_in_world("Hero", "TestTown")
	var rewards = world_integration.train_at_barracks("Hero", "TestTown")
	assert_true("stat_bonus" in rewards)


## Test: Crafting at smithy
func test_integration_crafting() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	world_integration.initialize_heir_in_world("Hero", "TestTown")
	var rewards = world_integration.craft_at_smithy("Hero", "TestTown", "sword")
	assert_true("success" in rewards)


## Test: Seeking blessing at shrine
func test_integration_shrine_blessing() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	world_integration.initialize_heir_in_world("Hero", "TestTown")
	var rewards = world_integration.seek_blessing_at_shrine("Hero", "TestTown")
	assert_true("blessed" in rewards)


## Test: NPC recruitment at tavern
func test_integration_tavern_recruitment() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	npc_system.create_npc("Bob", "TestTown", "warrior", "fighter")
	world_integration.initialize_heir_in_world("Hero", "TestTown")

	var rewards = world_integration.recruit_at_tavern("Hero", "TestTown", "Bob", 100)
	assert_true("success" in rewards)


## Test: Building upgrade
func test_integration_building_upgrade() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	world_integration.initialize_heir_in_world("Hero", "TestTown")
	var rewards = world_integration.upgrade_settlement_building("Hero", "TestTown", SettlementSystem.BuildingType.SMITHY)
	assert_true("success" in rewards or "reason" in rewards)


## Test: Heir world summary
func test_integration_heir_summary() -> void:
	settlement_system.create_settlement("TestTown", Vector2i(100, 100))
	world_integration.initialize_heir_in_world("Hero", "TestTown")
	var summary = world_integration.get_heir_world_summary("Hero")
	assert_eq(summary["position"], Vector2i(100, 100))
	assert_gt(summary["active_quests"], -1)


## Test: Multiple settlements with diverse NPCs
func test_integration_multi_settlement_world() -> void:
	settlement_system.create_settlement("Town1", Vector2i(0, 0), "alliance")
	settlement_system.create_settlement("Town2", Vector2i(200, 200), "empire")

	npc_system.create_npc("Bob", "Town1", "warrior", "fighter", "alliance")
	npc_system.create_npc("Alice", "Town1", "mage", "wizard", "alliance")
	npc_system.create_npc("Charlie", "Town2", "rogue", "thief", "empire")

	world_integration.initialize_heir_in_world("Hero", "Town1")

	var town1_npcs = npc_system.get_settlement_npcs("Town1")
	var town2_npcs = npc_system.get_settlement_npcs("Town2")

	assert_eq(town1_npcs.size(), 2)
	assert_eq(town2_npcs.size(), 1)


## Test: Complex hero progression through world
func test_integration_complex_progression() -> void:
	settlement_system.create_settlement("StartTown", Vector2i(0, 0))
	npc_system.create_npc("Mentor", "StartTown", "warrior", "fighter")

	world_integration.initialize_heir_in_world("Hero", "StartTown")

	# Complete initial training
	var training = world_integration.train_at_barracks("Hero", "StartTown")
	assert_true("stat_bonus" in training)

	# Accept and complete quest
	var heir_stats = {"strength": 16, "dexterity": 12, "constitution": 15, "intelligence": 10, "wisdom": 11, "charisma": 13}
	var quest = world_integration.accept_quest("Hero", "Mentor", heir_stats)
	var quest_rewards = world_integration.complete_quest("Hero", quest["id"], true)
	assert_gt(quest_rewards["gold"], 0)

	# Recruit companion
	var recruit = world_integration.recruit_at_tavern("Hero", "StartTown", "Mentor", 100)
	assert_true("npc_recruited" in recruit or "reason" in recruit)

	# Check final status
	var summary = world_integration.get_heir_world_summary("Hero")
	assert_eq(summary["position"], Vector2i(0, 0))
