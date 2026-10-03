## Test Phase 12.1: Legendary Deeds & Achievements
##
## Comprehensive test suite for achievement, legendary deed, and prestige systems

extends Node

class_name TestPhase12_1Achievements


var achievement_system: AchievementSystem
var legendary_deed_system: LegendaryDeedSystem
var prestige_system: PrestigeSystem
var achievement_persistence: AchievementPersistence

var test_results: Array = []


func _ready() -> void:
	achievement_system = AchievementSystem.new()
	legendary_deed_system = LegendaryDeedSystem.new()
	prestige_system = PrestigeSystem.new()
	achievement_persistence = AchievementPersistence.new()

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_achievement_system()
	test_achievement_unlocking()
	test_achievement_queries()
	test_achievement_tiers()

	test_legendary_deed_creation()
	test_legendary_deed_records()
	test_legendary_deed_queries()

	test_prestige_accumulation()
	test_prestige_benefits()
	test_prestige_multipliers()
	test_prestige_stat_bonuses()
	test_prestige_equipment_bonuses()
	test_prestige_starting_resources()

	test_achievement_persistence()
	test_generation_transfer()

	test_complex_scenarios()


func test_achievement_system() -> void:
	assert(achievement_system.achievements.size() > 0, "Should have default achievements")

	var achievement = achievement_system.get_achievement("first_victory")
	assert(achievement != null, "Should have first_victory achievement")
	assert(achievement.name == "First Blood", "Achievement should have correct name")
	assert(achievement.reward_prestige == 50, "Should grant 50 prestige")
	test_results.append("✓ Achievement system initialization")


func test_achievement_unlocking() -> void:
	var heir_id = "heir_1"
	var success = achievement_system.unlock_achievement("first_victory", heir_id, 1)
	assert(success, "Should unlock achievement")
	assert(achievement_system.has_achievement(heir_id, "first_victory"), "Heir should have achievement")

	# Try unlocking same achievement again
	var duplicate = achievement_system.unlock_achievement("first_victory", heir_id, 1)
	assert(not duplicate, "Should not double-unlock achievement")

	test_results.append("✓ Achievement unlocking")


func test_achievement_queries() -> void:
	var heir_id = "heir_2"
	achievement_system.unlock_achievement("first_victory", heir_id, 1)
	achievement_system.unlock_achievement("first_settlement", heir_id, 2)
	achievement_system.unlock_achievement("first_trade", heir_id, 3)

	var heir_achievements = achievement_system.get_heir_achievements(heir_id)
	assert(heir_achievements.size() == 3, "Should have 3 achievements")

	var combat_achievements = achievement_system.get_achievements_by_type(AchievementSystem.AchievementType.COMBAT)
	assert(combat_achievements.size() > 0, "Should find combat achievements")

	var gen_achievements = achievement_system.get_generation_achievements(1)
	assert(gen_achievements.size() > 0, "Should find generation 1 achievements")

	test_results.append("✓ Achievement queries")


func test_achievement_tiers() -> void:
	var bronze_achievements = achievement_system.get_achievements_by_tier(AchievementSystem.AchievementTier.BRONZE)
	var gold_achievements = achievement_system.get_achievements_by_tier(AchievementSystem.AchievementTier.GOLD)

	assert(bronze_achievements.size() > 0, "Should have bronze achievements")
	assert(gold_achievements.size() > 0, "Should have gold achievements")
	assert(gold_achievements.size() < bronze_achievements.size(), "Should have fewer gold than bronze")

	test_results.append("✓ Achievement tier filtering")


func test_legendary_deed_creation() -> void:
	var deed_id = legendary_deed_system.record_deed(
		LegendaryDeedSystem.DeedType.FIRST_BOSS_DEFEAT,
		"heir_1",
		5,
		1,
		"Defeated the Shadow Knight"
	)
	assert(deed_id != "", "Should create deed")
	assert(legendary_deed_system.legendary_deeds.has(deed_id), "Deed should be recorded")

	var deed = legendary_deed_system.get_deed(deed_id)
	assert(deed.heir_id == "heir_1", "Deed should have correct heir")
	assert(deed.generation == 5, "Deed should have correct generation")
	test_results.append("✓ Legendary deed creation")


func test_legendary_deed_records() -> void:
	# Set richest heir record
	var success = legendary_deed_system.check_and_update_record(
		"richest_heir",
		"heir_2",
		1,
		5000
	)
	assert(success, "Should set new record")

	var record = legendary_deed_system.get_record("richest_heir")
	assert(record["value"] == 5000, "Record should have correct value")
	assert(record["heir_id"] == "heir_2", "Record should track heir")

	# Try to set lower value
	var fail = legendary_deed_system.check_and_update_record(
		"richest_heir",
		"heir_3",
		2,
		3000
	)
	assert(not fail, "Should not replace with lower value")

	# Set higher value
	var success2 = legendary_deed_system.check_and_update_record(
		"richest_heir",
		"heir_4",
		3,
		7000
	)
	assert(success2, "Should replace with higher value")
	assert(legendary_deed_system.get_record("richest_heir")["heir_id"] == "heir_4", "Record should update")

	test_results.append("✓ Legendary deed records")


func test_legendary_deed_queries() -> void:
	# Create multiple deeds
	legendary_deed_system.record_deed(LegendaryDeedSystem.DeedType.RICHEST_HEIR, "heir_5", 2, 4000)
	legendary_deed_system.record_deed(LegendaryDeedSystem.DeedType.RICHEST_HEIR, "heir_6", 5, 6000)
	legendary_deed_system.record_deed(LegendaryDeedSystem.DeedType.OLDEST_HEIR, "heir_5", 10, 72)

	var richest_deeds = legendary_deed_system.get_deeds_by_type(LegendaryDeedSystem.DeedType.RICHEST_HEIR)
	assert(richest_deeds.size() >= 2, "Should find richest heir deeds")

	var heir_deeds = legendary_deed_system.get_deeds_by_heir("heir_5")
	assert(heir_deeds.size() >= 2, "Should find heir deeds")

	var top_deeds = legendary_deed_system.get_top_deeds(5)
	assert(top_deeds.size() > 0, "Should return top deeds")

	test_results.append("✓ Legendary deed queries")


func test_prestige_accumulation() -> void:
	prestige_system.add_prestige(100, "achievement", 1)
	assert(prestige_system.get_available_prestige() == 100, "Should have 100 prestige")

	prestige_system.add_prestige(50, "legendary_deed", 1)
	assert(prestige_system.get_available_prestige() == 150, "Should accumulate prestige")

	assert(prestige_system.get_prestige_by_source("achievement") == 100, "Should track by source")
	assert(prestige_system.get_prestige_by_generation(1) == 150, "Should track by generation")

	test_results.append("✓ Prestige accumulation")


func test_prestige_benefits() -> void:
	prestige_system.add_prestige(500, "test")

	var benefits = prestige_system.get_prestige_benefits()
	assert(benefits.has("stat_bonus"), "Should have stat bonuses")
	assert(benefits.has("equipment_bonus"), "Should have equipment bonuses")
	assert(benefits.has("starting_resources"), "Should have starting resources")
	assert(benefits.has("heir_progression_bonus"), "Should have progression bonuses")

	test_results.append("✓ Prestige benefits structure")


func test_prestige_multipliers() -> void:
	# Test prestige multiplier scaling
	prestige_system.total_prestige = 0
	assert(prestige_system.get_prestige_multiplier() == 1.0, "No prestige = 1.0x")

	prestige_system.total_prestige = 250
	assert(prestige_system.get_prestige_multiplier() == 1.05, "250 prestige = 1.05x")

	prestige_system.total_prestige = 1000
	assert(prestige_system.get_prestige_multiplier() == 1.10, "1000 prestige = 1.10x")

	prestige_system.total_prestige = 5000
	assert(prestige_system.get_prestige_multiplier() == 1.20, "5000 prestige = 1.20x")

	test_results.append("✓ Prestige multiplier scaling")


func test_prestige_stat_bonuses() -> void:
	prestige_system.total_prestige = 0
	var bonus = prestige_system.get_heir_stat_bonus()
	assert(bonus["strength"] == 0, "No prestige = no stat bonus")

	prestige_system.total_prestige = 300
	bonus = prestige_system.get_heir_stat_bonus()
	assert(bonus["strength"] > 0, "300 prestige should grant stat bonus")

	prestige_system.total_prestige = 1000
	bonus = prestige_system.get_heir_stat_bonus()
	var prev_strength = bonus["strength"]

	prestige_system.total_prestige = 2000
	bonus = prestige_system.get_heir_stat_bonus()
	assert(bonus["strength"] >= prev_strength, "Higher prestige should grant equal or more stat")

	test_results.append("✓ Prestige stat bonuses")


func test_prestige_equipment_bonuses() -> void:
	prestige_system.total_prestige = 0
	var bonus = prestige_system.get_equipment_bonus()
	assert(bonus["damage_multiplier"] == 1.0, "No prestige = 1.0x multiplier")

	prestige_system.total_prestige = 500
	bonus = prestige_system.get_equipment_bonus()
	assert(bonus["damage_multiplier"] > 1.0, "500 prestige should increase damage")
	assert(bonus["defense_multiplier"] > 1.0, "Should increase defense too")

	prestige_system.total_prestige = 2500
	bonus = prestige_system.get_equipment_bonus()
	assert(bonus["damage_multiplier"] >= 1.25, "2500 prestige should grant at least 25% bonus")

	test_results.append("✓ Prestige equipment bonuses")


func test_prestige_starting_resources() -> void:
	prestige_system.total_prestige = 0
	var resources = prestige_system.get_starting_resources()
	assert(resources["gold"] == 500, "Base starting gold = 500")

	prestige_system.total_prestige = 500
	resources = prestige_system.get_starting_resources()
	assert(resources["gold"] > 500, "500 prestige should increase starting gold")

	prestige_system.total_prestige = 2000
	resources = prestige_system.get_starting_resources()
	assert(resources["gold"] >= 1000, "2000 prestige should grant at least 1000 gold")

	test_results.append("✓ Prestige starting resources")


func test_achievement_persistence() -> void:
	# Setup systems with some data
	achievement_system.unlock_achievement("first_victory", "heir_1", 1)
	achievement_system.unlock_achievement("first_settlement", "heir_1", 2)

	legendary_deed_system.record_deed(LegendaryDeedSystem.DeedType.FIRST_BOSS_DEFEAT, "heir_1", 3, 1)
	prestige_system.add_prestige(150, "test", 1)

	# Save state
	var state = achievement_persistence.save_achievement_state(
		achievement_system,
		legendary_deed_system,
		prestige_system
	)

	assert(state.has("achievements"), "State should have achievements")
	assert(state.has("legendary_deeds"), "State should have deeds")
	assert(state["total_prestige"] == 150, "State should preserve prestige")

	# Load into new systems
	var new_achievement_system = AchievementSystem.new()
	var new_legendary_system = LegendaryDeedSystem.new()
	var new_prestige_system = PrestigeSystem.new()

	achievement_persistence.load_achievement_state(
		state,
		new_achievement_system,
		new_legendary_system,
		new_prestige_system
	)

	assert(new_prestige_system.get_available_prestige() == 150, "Prestige should load")
	assert(new_legendary_system.legendary_deeds.size() > 0, "Deeds should load")

	test_results.append("✓ Achievement persistence")


func test_generation_transfer() -> void:
	achievement_system.unlock_achievement("first_victory", "heir_1", 1)
	legendary_deed_system.record_deed(LegendaryDeedSystem.DeedType.RICHEST_HEIR, "heir_1", 1, 5000)
	prestige_system.add_prestige(300, "achievement", 1)

	var state = achievement_persistence.save_achievement_state(
		achievement_system,
		legendary_deed_system,
		prestige_system
	)

	var transferred = achievement_persistence.transfer_achievements_to_next_generation(state)

	# Prestige should carry forward
	assert(transferred["total_prestige"] == 300, "Prestige should carry at 100%")

	# Legendary deeds should carry
	assert(transferred["legendary_deeds"].size() > 0, "Deeds should carry forward")

	# Heir achievements reset
	assert(transferred["heir_achievements"].size() == 0, "Heir achievements should reset")

	test_results.append("✓ Generation transfer")


func test_complex_scenarios() -> void:
	# Scenario: Multi-heir achievement chain
	achievement_system.unlock_achievement("first_victory", "heir_1", 1)
	achievement_system.unlock_achievement("first_settlement", "heir_2", 2)
	achievement_system.unlock_achievement("married", "heir_3", 5)

	var heir_1_achievements = achievement_system.get_heir_achievements("heir_1")
	var heir_2_achievements = achievement_system.get_heir_achievements("heir_2")
	assert(heir_1_achievements.size() == 1, "Heir 1 should have 1 achievement")
	assert(heir_2_achievements.size() == 1, "Heir 2 should have 1 achievement")

	# Scenario: Record tracking across heirs
	legendary_deed_system.check_and_update_record("richest_heir", "heir_1", 1, 3000)
	legendary_deed_system.check_and_update_record("richest_heir", "heir_2", 5, 5000)
	legendary_deed_system.check_and_update_record("richest_heir", "heir_3", 10, 4000)

	var richest_record = legendary_deed_system.get_record("richest_heir")
	assert(richest_record["heir_id"] == "heir_2", "Should track highest value")
	assert(richest_record["generation"] == 5, "Should track generation of record")

	# Scenario: Prestige scaling with generations
	prestige_system.add_prestige(100, "generation_1", 1)
	prestige_system.add_prestige(150, "generation_2", 2)
	prestige_system.add_prestige(200, "generation_3", 3)

	assert(prestige_system.get_total_prestige() == 450, "Total should accumulate")
	assert(prestige_system.get_prestige_by_generation(2) == 150, "Should track per generation")

	test_results.append("✓ Complex scenarios")


func print_results() -> void:
	print("\n=== Test Phase 12.1: Legendary Deeds & Achievements ===")
	for result in test_results:
		print(result)
	print("\nTotal: %d test groups passed" % test_results.size())


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
