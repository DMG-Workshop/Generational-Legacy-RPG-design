## Test Suite for Phase 11.2: NPC Scheduling & Dialogue
##
## Comprehensive tests for NPCs, schedules, dialogue, and reputation

extends GutTest


var npc_system: NPCSystem
var building_system: BuildingSystem
var schedule_system: NPCScheduleSystem
var dialogue_system: DialogueSystem
var reputation_system: NPCReputationSystem
var persistence_system: NPCPersistence


func before_each() -> void:
	npc_system = NPCSystem.new()
	building_system = BuildingSystem.new()
	schedule_system = NPCScheduleSystem.new(npc_system, building_system)
	dialogue_system = DialogueSystem.new()
	reputation_system = NPCReputationSystem.new(npc_system)
	persistence_system = NPCPersistence.new(npc_system, schedule_system, reputation_system)


# ============================================================
# NPC System Tests
# ============================================================

func test_npc_system_created() -> void:
	assert_not_null(npc_system)


func test_create_npc() -> void:
	var npc_id = npc_system.create_npc("Aldric", NPCSystem.NPCProfession.BLACKSMITH, Vector2i(10, 10))
	assert_true(npc_system.npc_exists(npc_id))


func test_npc_properties() -> void:
	var npc_id = npc_system.create_npc("Merchant", NPCSystem.NPCProfession.MERCHANT)
	var npc = npc_system.get_npc(npc_id)
	
	assert_eq(npc.name, "Merchant")
	assert_eq(npc.profession, NPCSystem.NPCProfession.MERCHANT)
	assert_eq(npc.age, 20)
	assert_true(npc.is_alive)


func test_npc_profession_stats() -> void:
	var blacksmith_id = npc_system.create_npc("Thorg", NPCSystem.NPCProfession.BLACKSMITH)
	var priest_id = npc_system.create_npc("Elara", NPCSystem.NPCProfession.PRIEST)
	
	var blacksmith = npc_system.get_npc(blacksmith_id)
	var priest = npc_system.get_npc(priest_id)
	
	assert_gt(blacksmith.stats["strength"], priest.stats["strength"])
	assert_gt(priest.stats["wisdom"], blacksmith.stats["wisdom"])


func test_npc_aging() -> void:
	var npc_id = npc_system.create_npc("Greybeard", NPCSystem.NPCProfession.MERCHANT)
	var npc = npc_system.get_npc(npc_id)
	
	var initial_age = npc.age
	npc_system.age_npc(npc_id)
	
	assert_eq(npc.age, initial_age + 1)


func test_npc_death() -> void:
	var npc_id = npc_system.create_npc("Mortal", NPCSystem.NPCProfession.MERCHANT)
	var npc = npc_system.get_npc(npc_id)
	
	assert_true(npc.is_alive)
	npc_system.kill_npc(npc_id)
	assert_false(npc.is_alive)


func test_npc_mood_change() -> void:
	var npc_id = npc_system.create_npc("Grumpy", NPCSystem.NPCProfession.TAVERN_KEEPER)
	var npc = npc_system.get_npc(npc_id)
	
	npc_system.set_npc_mood(npc_id, "happy")
	assert_eq(npc.mood, "happy")


func test_npc_health_tracking() -> void:
	var npc_id = npc_system.create_npc("Sickly", NPCSystem.NPCProfession.MERCHANT)
	var npc = npc_system.get_npc(npc_id)
	
	npc_system.update_npc_health(npc_id, -0.3)
	assert_lt(npc.health, 1.0)


func test_get_npc_by_profession() -> void:
	npc_system.create_npc("Smith1", NPCSystem.NPCProfession.BLACKSMITH)
	npc_system.create_npc("Smith2", NPCSystem.NPCProfession.BLACKSMITH)
	npc_system.create_npc("Priest1", NPCSystem.NPCProfession.PRIEST)
	
	var blacksmiths = npc_system.get_npcs_by_profession(NPCSystem.NPCProfession.BLACKSMITH)
	assert_eq(blacksmiths.size(), 2)


# ============================================================
# NPC Schedule Tests
# ============================================================

func test_schedule_system_created() -> void:
	assert_not_null(schedule_system)


func test_create_npc_schedule() -> void:
	var npc_id = npc_system.create_npc("Scheduled", NPCSystem.NPCProfession.MERCHANT)
	var schedule = schedule_system.create_schedule_for_npc(npc_id, Vector2i(5, 5))
	
	assert_not_null(schedule)
	assert_eq(schedule.home_location, Vector2i(5, 5))


func test_assign_npc_to_building() -> void:
	var npc_id = npc_system.create_npc("Worker", NPCSystem.NPCProfession.BLACKSMITH)
	var building_id = building_system.create_building(BuildingSystem.BuildingType.BLACKSMITH, Vector2i(0, 0), "owner")
	
	schedule_system.create_schedule_for_npc(npc_id, Vector2i(0, 0))
	schedule_system.assign_npc_to_building(npc_id, building_id)
	
	var schedule = schedule_system.get_npc_schedule(npc_id)
	assert_eq(schedule.assigned_building, building_id)


func test_npc_activity_progression() -> void:
	var npc_id = npc_system.create_npc("Busy", NPCSystem.NPCProfession.MERCHANT)
	schedule_system.create_schedule_for_npc(npc_id, Vector2i(0, 0))
	
	schedule_system.process_npc_schedule(npc_id, 100)
	assert_eq(npc_system.get_npc(npc_id).current_activity, "sleeping")
	
	schedule_system.process_npc_schedule(npc_id, 500)
	assert_eq(npc_system.get_npc(npc_id).current_activity, "working")
	
	schedule_system.process_npc_schedule(npc_id, 900)
	assert_eq(npc_system.get_npc(npc_id).current_activity, "resting")


func test_npc_location_updates_with_schedule() -> void:
	var npc_id = npc_system.create_npc("Mobile", NPCSystem.NPCProfession.MERCHANT)
	var building_id = building_system.create_building(BuildingSystem.BuildingType.MARKET, Vector2i(50, 50), "owner")
	
	schedule_system.create_schedule_for_npc(npc_id, Vector2i(0, 0))
	schedule_system.assign_npc_to_building(npc_id, building_id)
	schedule_system.process_npc_schedule(npc_id, 500)
	
	var npc = npc_system.get_npc(npc_id)
	assert_eq(npc.location, Vector2i(50, 50))


func test_npcs_working_at_building() -> void:
	var npc1 = npc_system.create_npc("Worker1", NPCSystem.NPCProfession.MERCHANT)
	var npc2 = npc_system.create_npc("Worker2", NPCSystem.NPCProfession.MERCHANT)
	var building_id = building_system.create_building(BuildingSystem.BuildingType.MARKET, Vector2i(0, 0), "owner")
	
	schedule_system.create_schedule_for_npc(npc1, Vector2i(0, 0))
	schedule_system.create_schedule_for_npc(npc2, Vector2i(0, 0))
	schedule_system.assign_npc_to_building(npc1, building_id)
	schedule_system.assign_npc_to_building(npc2, building_id)
	
	var working = schedule_system.get_npcs_working_at_building(building_id)
	assert_eq(working.size(), 2)


# ============================================================
# Dialogue System Tests
# ============================================================

func test_dialogue_system_created() -> void:
	assert_not_null(dialogue_system)


func test_create_dialogue_tree() -> void:
	dialogue_system.create_dialogue_tree("test_dialogue")
	dialogue_system.add_dialogue_node("test_dialogue", "start", "Hello there!")
	
	var tree = dialogue_system.get_dialogue_tree("test_dialogue")
	assert_true("start" in tree)


func test_add_dialogue_choices() -> void:
	dialogue_system.create_dialogue_tree("quest")
	dialogue_system.add_dialogue_node("quest", "start", "Will you help me?")
	dialogue_system.add_dialogue_choice("quest", "start", "Yes", "accept")
	dialogue_system.add_dialogue_choice("quest", "start", "No", "reject")
	
	var tree = dialogue_system.get_dialogue_tree("quest")
	var start_node = tree["start"]
	assert_eq(start_node.choices.size(), 2)


func test_start_dialogue() -> void:
	dialogue_system.create_generic_greeting_tree()
	var npc_id = "npc_1"
	
	var success = dialogue_system.start_dialogue(npc_id, "greeting")
	assert_true(success)
	assert_true(dialogue_system.is_in_dialogue(npc_id))


func test_get_dialogue_text() -> void:
	dialogue_system.create_generic_greeting_tree()
	var npc_id = "npc_2"
	
	dialogue_system.start_dialogue(npc_id, "greeting")
	var text = dialogue_system.get_current_dialogue_text(npc_id)
	
	assert_true(text.length() > 0)
	assert_true("greetings" in text.to_lower())


func test_get_dialogue_choices() -> void:
	dialogue_system.create_generic_greeting_tree()
	var npc_id = "npc_3"
	
	dialogue_system.start_dialogue(npc_id, "greeting")
	var choices = dialogue_system.get_current_dialogue_choices(npc_id)
	
	assert_eq(choices.size(), 2)


func test_make_dialogue_choice() -> void:
	dialogue_system.create_generic_greeting_tree()
	var npc_id = "npc_4"
	
	dialogue_system.start_dialogue(npc_id, "greeting")
	var success = dialogue_system.make_dialogue_choice(npc_id, 0)
	
	assert_true(success)


func test_dialogue_ends() -> void:
	dialogue_system.create_generic_greeting_tree()
	var npc_id = "npc_5"
	
	dialogue_system.start_dialogue(npc_id, "greeting")
	dialogue_system.make_dialogue_choice(npc_id, 0)
	
	assert_false(dialogue_system.is_in_dialogue(npc_id))


# ============================================================
# Reputation System Tests
# ============================================================

func test_reputation_system_created() -> void:
	assert_not_null(reputation_system)


func test_initialize_npc_reputation() -> void:
	var npc_id = npc_system.create_npc("Stranger", NPCSystem.NPCProfession.MERCHANT)
	reputation_system.initialize_npc_reputation(npc_id)
	
	var rep = reputation_system.get_reputation(npc_id)
	assert_eq(rep, 0)


func test_add_reputation() -> void:
	var npc_id = npc_system.create_npc("Friend", NPCSystem.NPCProfession.MERCHANT)
	reputation_system.initialize_npc_reputation(npc_id)
	
	reputation_system.add_reputation(npc_id, 20)
	assert_eq(reputation_system.get_reputation(npc_id), 20)


func test_reputation_clamped() -> void:
	var npc_id = npc_system.create_npc("Extremist", NPCSystem.NPCProfession.MERCHANT)
	reputation_system.initialize_npc_reputation(npc_id)
	
	reputation_system.add_reputation(npc_id, 200)
	assert_eq(reputation_system.get_reputation(npc_id), 100)


func test_relationship_tiers() -> void:
	var npc_id = npc_system.create_npc("Varied", NPCSystem.NPCProfession.MERCHANT)
	reputation_system.initialize_npc_reputation(npc_id)
	
	reputation_system.add_reputation(npc_id, 60)
	assert_eq(reputation_system.get_relationship_tier(npc_id), "ally")
	
	reputation_system.add_reputation(npc_id, -80)
	assert_eq(reputation_system.get_relationship_tier(npc_id), "enemy")


func test_price_modifier_from_reputation() -> void:
	var npc_id = npc_system.create_npc("Merchant", NPCSystem.NPCProfession.MERCHANT)
	reputation_system.initialize_npc_reputation(npc_id)
	
	var neutral_price = reputation_system.calculate_price_modifier(npc_id)
	assert_eq(neutral_price, 1.0)
	
	reputation_system.add_reputation(npc_id, 50)
	var friend_price = reputation_system.calculate_price_modifier(npc_id)
	assert_lt(friend_price, 1.0)


func test_quest_reward_modifier() -> void:
	var npc_id = npc_system.create_npc("Questgiver", NPCSystem.NPCProfession.MERCHANT)
	reputation_system.initialize_npc_reputation(npc_id)
	
	reputation_system.add_reputation(npc_id, 75)
	var modifier = reputation_system.get_quest_reward_modifier(npc_id)
	assert_gt(modifier, 1.0)


# ============================================================
# NPC Persistence Tests
# ============================================================

func test_persistence_system_created() -> void:
	assert_not_null(persistence_system)


func test_save_npc() -> void:
	var npc_id = npc_system.create_npc("Saveable", NPCSystem.NPCProfession.BLACKSMITH)
	schedule_system.create_schedule_for_npc(npc_id, Vector2i(0, 0))
	reputation_system.initialize_npc_reputation(npc_id)
	
	var saved = persistence_system.save_npc(npc_id)
	assert_eq(saved["name"], "Saveable")


func test_load_npc() -> void:
	var npc_id = npc_system.create_npc("Original", NPCSystem.NPCProfession.MERCHANT)
	schedule_system.create_schedule_for_npc(npc_id, Vector2i(5, 5))
	reputation_system.initialize_npc_reputation(npc_id)
	reputation_system.add_reputation(npc_id, 30)
	
	var saved = persistence_system.save_npc(npc_id)
	
	npc_system.npcs.clear()
	var loaded_id = persistence_system.load_npc(saved)
	
	var loaded = npc_system.get_npc(loaded_id)
	assert_eq(loaded.name, "Original")
	assert_eq(reputation_system.get_reputation(loaded_id), 30)


func test_npc_legacy_export() -> void:
	var npc_id = npc_system.create_npc("Hero", NPCSystem.NPCProfession.BLACKSMITH)
	reputation_system.initialize_npc_reputation(npc_id)
	reputation_system.add_reputation(npc_id, 75)
	
	var legacy = persistence_system.get_npc_legacy(npc_id)
	assert_eq(legacy["name"], "Hero")
	assert_eq(legacy["final_reputation"], 75)


# ============================================================
# Complex Scenario Tests
# ============================================================

func test_full_npc_lifecycle() -> void:
	var npc_id = npc_system.create_npc("Lifespan", NPCSystem.NPCProfession.MERCHANT)
	schedule_system.create_schedule_for_npc(npc_id, Vector2i(10, 10))
	reputation_system.initialize_npc_reputation(npc_id)
	
	for i in range(5):
		npc_system.age_npc(npc_id)
		reputation_system.add_reputation(npc_id, 5)
	
	var npc = npc_system.get_npc(npc_id)
	assert_eq(npc.age, 25)
	assert_eq(reputation_system.get_reputation(npc_id), 25)


func test_dialogue_with_npc() -> void:
	var npc_id = npc_system.create_npc("Talker", NPCSystem.NPCProfession.INNKEEPER)
	reputation_system.initialize_npc_reputation(npc_id)
	
	dialogue_system.create_innkeeper_tree()
	dialogue_system.start_dialogue(npc_id, "innkeeper")
	
	var text = dialogue_system.get_current_dialogue_text(npc_id)
	assert_true(text.length() > 0)
	
	dialogue_system.make_dialogue_choice(npc_id, 0)


func test_npc_daily_routine() -> void:
	var npc_id = npc_system.create_npc("Routine", NPCSystem.NPCProfession.MERCHANT)
	var building_id = building_system.create_building(BuildingSystem.BuildingType.MARKET, Vector2i(50, 50), "owner")
	
	schedule_system.create_schedule_for_npc(npc_id, Vector2i(20, 20))
	schedule_system.assign_npc_to_building(npc_id, building_id)
	
	for tick in [100, 500, 900]:
		schedule_system.process_npc_schedule(npc_id, tick)
	
	var npc = npc_system.get_npc(npc_id)
	assert_true(npc.is_alive)


func test_multi_npc_interaction() -> void:
	var npc1 = npc_system.create_npc("Alice", NPCSystem.NPCProfession.MERCHANT)
	var npc2 = npc_system.create_npc("Bob", NPCSystem.NPCProfession.BLACKSMITH)
	
	reputation_system.initialize_npc_reputation(npc1)
	reputation_system.initialize_npc_reputation(npc2)
	
	reputation_system.add_reputation(npc1, 30)
	reputation_system.add_reputation(npc2, -20)
	
	var rep1 = reputation_system.get_reputation(npc1)
	var rep2 = reputation_system.get_reputation(npc2)
	
	assert_gt(rep1, rep2)
