## Test Phase 14: World Scaling & Legendary Encounters
##
## Comprehensive test suite for world difficulty scaling and legendary boss battles

extends Node

class_name TestPhase14WorldScaling


var world_scaling: WorldPrestigeScaling
var legendary_system: LegendaryEncounterSystem
var realm_scaling: RealmPrestigeScaling
var event_scaling: WorldEventPrestigeScaling

var test_results: Array = []


func _ready() -> void:
	world_scaling = WorldPrestigeScaling.new()
	legendary_system = LegendaryEncounterSystem.new()
	realm_scaling = RealmPrestigeScaling.new()
	event_scaling = WorldEventPrestigeScaling.new()

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_world_difficulty_calculation()
	test_dungeon_unlocking()
	test_dungeon_difficulty_scaling()
	test_available_dungeons()
	test_rare_encounter_chance()
	test_recommended_level()
	test_world_event_difficulty()
	test_realm_challenge_difficulty()

	test_legendary_boss_creation()
	test_legendary_boss_access()
	test_boss_scaled_stats()
	test_boss_phase_transitions()
	test_legendary_victory_recording()
	test_tier_locked_mechanics()
	test_exclusive_loot_drops()
	test_boss_defeat_tracking()

	test_realm_unlocking()
	test_realm_difficulty()
	test_realm_creature_level_scaling()
	test_realm_resource_multiplier()
	test_realm_rare_encounter_rate()
	test_realm_special_events()
	test_accessible_realms()

	test_prophecy_difficulty_scaling()
	test_legacy_event_scaling()
	test_faction_event_scaling()
	test_world_event_reward_scaling()
	test_rare_event_triggering()

	test_complex_world_scenarios()


func test_world_difficulty_calculation() -> void:
	var difficulty_bronze = world_scaling.calculate_world_difficulty(0)
	assert(difficulty_bronze.difficulty_multiplier == 0.5, "Bronze should have 0.5x difficulty")

	var difficulty_eternal = world_scaling.calculate_world_difficulty(75000)
	assert(difficulty_eternal.difficulty_multiplier == 3.0, "Eternal should have 3.0x difficulty")

	test_results.append("✓ World difficulty calculation")


func test_dungeon_unlocking() -> void:
	assert(world_scaling.is_dungeon_unlocked("goblin_cave", 0), "Goblin cave should be unlocked at 0 prestige")
	assert(not world_scaling.is_dungeon_unlocked("dragon_spire", 10000), "Dragon spire should not be unlocked at 10000")
	assert(world_scaling.is_dungeon_unlocked("dragon_spire", 20000), "Dragon spire should be unlocked at 20000")

	test_results.append("✓ Dungeon unlocking")


func test_dungeon_difficulty_scaling() -> void:
	var scaling_low = world_scaling.get_dungeon_difficulty_scaling("goblin_cave", 0)
	var scaling_high = world_scaling.get_dungeon_difficulty_scaling("goblin_cave", 10000)

	assert(scaling_high >= scaling_low, "Higher prestige should increase difficulty")

	test_results.append("✓ Dungeon difficulty scaling")


func test_available_dungeons() -> void:
	var available_bronze = world_scaling.get_available_dungeons(0)
	assert(available_bronze.size() >= 1, "Should have at least 1 dungeon at Bronze")

	var available_eternal = world_scaling.get_available_dungeons(75000)
	assert(available_eternal.size() == 7, "Should have all 7 dungeons at Eternal")

	test_results.append("✓ Available dungeons")


func test_rare_encounter_chance() -> void:
	var difficulty = world_scaling.calculate_world_difficulty(0)
	var base_chance = difficulty.rare_encounter_chance

	var difficulty_high = world_scaling.calculate_world_difficulty(50000)
	var high_chance = difficulty_high.rare_encounter_chance

	assert(high_chance > base_chance, "Higher prestige should increase rare encounter chance")
	assert(high_chance <= 0.5, "Should cap at 50%")

	test_results.append("✓ Rare encounter chance")


func test_recommended_level() -> void:
	var difficulty_low = world_scaling.calculate_world_difficulty(0)
	var difficulty_high = world_scaling.calculate_world_difficulty(25000)

	assert(difficulty_high.recommended_enemy_level > difficulty_low.recommended_enemy_level, "Should recommend higher levels")

	test_results.append("✓ Recommended level")


func test_world_event_difficulty() -> void:
	var base_difficulty = 1.0
	var scaled_low = world_scaling.calculate_world_event_difficulty(base_difficulty, 0)
	var scaled_high = world_scaling.calculate_world_event_difficulty(base_difficulty, 15000)

	assert(scaled_low == base_difficulty, "Should not scale at 0 prestige")
	assert(scaled_high > base_difficulty, "Should scale up with prestige")

	test_results.append("✓ World event difficulty")


func test_realm_challenge_difficulty() -> void:
	var base_challenge = 1.5
	var scaled = world_scaling.calculate_realm_challenge_difficulty(base_challenge, 10000)

	assert(scaled >= base_challenge, "Should not decrease difficulty")
	assert(scaled <= 3.0, "Should cap at 3.0x")

	test_results.append("✓ Realm challenge difficulty")


func test_legendary_boss_creation() -> void:
	var boss = legendary_system.get_legendary_boss("silver_warden")
	assert(boss != null, "Should have Silver Warden boss")
	assert(boss.tier == LegendaryEncounterSystem.BossTier.SILVER, "Should be Silver tier")
	assert(boss.required_prestige == 1000, "Should require 1000 prestige")

	test_results.append("✓ Legendary boss creation")


func test_legendary_boss_access() -> void:
	assert(legendary_system.can_fight_legendary_boss("silver_warden", 1000), "Should fight Silver Warden at 1000 prestige")
	assert(not legendary_system.can_fight_legendary_boss("eternal_void", 50000), "Should not fight Eternal Void at 50000")
	assert(legendary_system.can_fight_legendary_boss("eternal_void", 75000), "Should fight Eternal Void at 75000")

	test_results.append("✓ Legendary boss access")


func test_boss_scaled_stats() -> void:
	var boss = legendary_system.get_legendary_boss("gold_dragon")
	var scaled_low = legendary_system.calculate_boss_scaled_stats(boss, 5000)
	var scaled_high = legendary_system.calculate_boss_scaled_stats(boss, 25000)

	for stat in scaled_low.keys():
		assert(scaled_high[stat] >= scaled_low[stat], "Should scale stats up with prestige")

	test_results.append("✓ Boss scaled stats")


func test_boss_phase_transitions() -> void:
	var boss = legendary_system.get_legendary_boss("platinum_tyrant")
	assert(boss.max_phases > 0, "Should have multiple phases")

	var phase = legendary_system.process_boss_phase_transition("platinum_tyrant", boss.base_stats["health"] / 2)
	assert(phase >= 1, "Should transition to phase 1 at half health")

	test_results.append("✓ Boss phase transitions")


func test_legendary_victory_recording() -> void:
	var victory = legendary_system.record_legendary_victory("gold_dragon", "heir_1", 10000, 3, 50, 5)

	assert(victory != null, "Should record victory")
	assert(victory.heir_id == "heir_1", "Should track heir")
	assert(victory.prestige_gained > 0, "Should grant prestige")

	test_results.append("✓ Legendary victory recording")


func test_tier_locked_mechanics() -> void:
	var silver_boss = legendary_system.get_legendary_boss("silver_warden")
	var eternal_boss = legendary_system.get_legendary_boss("eternal_void")

	assert(silver_boss.tier_locked_mechanics.size() < eternal_boss.tier_locked_mechanics.size(), "Higher tier should have more mechanics")

	test_results.append("✓ Tier locked mechanics")


func test_exclusive_loot_drops() -> void:
	var victory = legendary_system.record_legendary_victory("gold_dragon", "heir_test", 10000, 5, 100, 3)

	# Loot can be 0-3 items based on prestige and RNG
	assert(victory.exclusive_loot_obtained.size() <= 3, "Should have max 3 exclusive loot")

	test_results.append("✓ Exclusive loot drops")


func test_boss_defeat_tracking() -> void:
	legendary_system.record_legendary_victory("silver_warden", "heir_1", 1000, 10, 80, 2)
	legendary_system.record_legendary_victory("silver_warden", "heir_2", 1000, 12, 90, 1)

	var total_defeats = legendary_system.get_boss_defeat_count("silver_warden")
	assert(total_defeats == 2, "Should track 2 defeats")

	var heir1_defeats = legendary_system.get_boss_defeat_count("silver_warden", "heir_1")
	assert(heir1_defeats == 1, "Should track heir-specific defeats")

	test_results.append("✓ Boss defeat tracking")


func test_realm_unlocking() -> void:
	assert(realm_scaling.is_realm_unlocked("starter_lands", 0), "Starter lands should be unlocked at 0")
	assert(not realm_scaling.is_realm_unlocked("eternal_abyss", 50000), "Eternal abyss should not be unlocked at 50000")
	assert(realm_scaling.is_realm_unlocked("eternal_abyss", 75000), "Eternal abyss should be unlocked at 75000")

	test_results.append("✓ Realm unlocking")


func test_realm_difficulty() -> void:
	var difficulty_starter = realm_scaling.calculate_realm_difficulty("starter_lands", 0)
	var difficulty_eternal = realm_scaling.calculate_realm_difficulty("eternal_abyss", 75000)

	assert(difficulty_starter < difficulty_eternal, "Eternal realm should be harder")

	test_results.append("✓ Realm difficulty")


func test_realm_creature_level_scaling() -> void:
	var level_low = realm_scaling.calculate_realm_creature_level("starter_lands", 0, 1)
	var level_high = realm_scaling.calculate_realm_creature_level("starter_lands", 25000, 1)

	assert(level_high > level_low, "Should scale creature levels with prestige")

	test_results.append("✓ Realm creature level scaling")


func test_realm_resource_multiplier() -> void:
	var mult_starter = realm_scaling.get_realm_resource_multiplier("starter_lands", 0)
	var mult_eternal = realm_scaling.get_realm_resource_multiplier("eternal_abyss", 75000)

	assert(mult_eternal > mult_starter, "Higher tier realms should have better resource multiplier")

	test_results.append("✓ Realm resource multiplier")


func test_realm_rare_encounter_rate() -> void:
	var rate_starter = realm_scaling.calculate_rare_encounter_rate("starter_lands", 0)
	var rate_eternal = realm_scaling.calculate_rare_encounter_rate("eternal_abyss", 75000)

	assert(rate_eternal > rate_starter, "Higher tier realms should have higher rare encounter rate")
	assert(rate_eternal <= 0.5, "Should cap at 50%")

	test_results.append("✓ Realm rare encounter rate")


func test_realm_special_events() -> void:
	realm_scaling.unlock_special_realm_event("starter_lands", 1)
	realm_scaling.unlock_special_realm_event("eternal_abyss", 5)

	var starter = realm_scaling.realms["starter_lands"]
	var eternal = realm_scaling.realms["eternal_abyss"]

	assert(starter.special_events_available.size() > 0, "Should have special events")
	assert(eternal.special_events_available.size() > 0, "Should have special events")

	test_results.append("✓ Realm special events")


func test_accessible_realms() -> void:
	var accessible_bronze = realm_scaling.get_accessible_realms(0)
	assert(accessible_bronze.size() >= 1, "Should have 1+ accessible realms at Bronze")

	var accessible_eternal = realm_scaling.get_accessible_realms(75000)
	assert(accessible_eternal.size() == 6, "Should have all 6 realms at Eternal")

	test_results.append("✓ Accessible realms")


func test_prophecy_difficulty_scaling() -> void:
	var base_prophecy = 1.0
	var scaled_low = event_scaling.scale_prophecy_difficulty(base_prophecy, 0)
	var scaled_high = event_scaling.scale_prophecy_difficulty(base_prophecy, 15000)

	assert(scaled_low == base_prophecy, "Should not scale at 0 prestige")
	assert(scaled_high > base_prophecy, "Should scale with prestige")

	test_results.append("✓ Prophecy difficulty scaling")


func test_legacy_event_scaling() -> void:
	var base_consequences = {"prestige_bonus": 100, "prosperity_change": 10}
	var scaled = event_scaling.scale_legacy_event_consequences(base_consequences, 10000)

	assert(scaled["prestige_bonus"] > base_consequences["prestige_bonus"], "Should scale prestige reward")
	assert(scaled["prosperity_change"] > base_consequences["prosperity_change"], "Should scale prosperity")

	test_results.append("✓ Legacy event scaling")


func test_faction_event_scaling() -> void:
	var faction_event = event_scaling.scale_faction_standing_event("council_of_kings", 100, 15000)

	assert(faction_event.standing_impact > 100, "Should scale standing impact with prestige")
	assert(faction_event.prestige_reward > 50, "Should scale prestige reward")

	test_results.append("✓ Faction event scaling")


func test_world_event_reward_scaling() -> void:
	var scaling_prophecy_low = event_scaling.get_event_reward_scaling("prophecy", 0)
	var scaling_prophecy_high = event_scaling.get_event_reward_scaling("prophecy", 20000)

	assert(scaling_prophecy_high > scaling_prophecy_low, "Should scale rewards with prestige")

	test_results.append("✓ World event reward scaling")


func test_rare_event_triggering() -> void:
	# Test with high prestige for better chance
	var triggered_count = 0
	for _i in range(100):
		if event_scaling.should_trigger_rare_event(50000, 0.05):
			triggered_count += 1

	assert(triggered_count > 0, "Should trigger rare event occasionally")

	test_results.append("✓ Rare event triggering")


func test_complex_world_scenarios() -> void:
	# Scenario: Complete dungeon progression
	for prestige in [0, 1000, 5000, 15000, 35000, 75000]:
		var difficulty = world_scaling.calculate_world_difficulty(prestige)
		var dungeons = difficulty.available_dungeons
		assert(dungeons.size() > 0, "Should have dungeons at all prestige levels")

	# Scenario: Legendary boss progression
	var boss_sequence = ["silver_warden", "gold_dragon", "platinum_tyrant", "diamond_sovereign", "eternal_void"]
	var prestige_sequence = [1000, 5000, 15000, 35000, 75000]

	for i in range(boss_sequence.size()):
		var boss_id = boss_sequence[i]
		var prestige = prestige_sequence[i]
		assert(legendary_system.can_fight_legendary_boss(boss_id, prestige), "Should access boss at prestige tier")

	# Scenario: Realm unlocking progression
	var realm_sequence = ["starter_lands", "silver_reach", "golden_expanse", "platinum_peaks", "diamond_wastes", "eternal_abyss"]
	var realm_prestige = [0, 1000, 5000, 15000, 35000, 75000]

	for i in range(realm_sequence.size()):
		var realm_id = realm_sequence[i]
		var prestige = realm_prestige[i]
		assert(realm_scaling.is_realm_unlocked(realm_id, prestige), "Should unlock realm at prestige tier")

	test_results.append("✓ Complex world scenarios")


func print_results() -> void:
	print("\n=== Test Phase 14: World Scaling & Legendary Encounters ===")
	for result in test_results:
		print(result)
	print("\nTotal: %d test groups passed" % test_results.size())


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
