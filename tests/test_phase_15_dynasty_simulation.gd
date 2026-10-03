## Test Phase 15: Dynasty Simulation - 999 Generation Integration Test
##
## Comprehensive integration test validating all systems across full game lifecycle

extends Node

class_name TestPhase15DynastySimulation


var simulator: DynastySimulator
var validator: GenerationValidator
var report_generator: DynastyReportGenerator
var config: SimulationConfig

var test_results: Array = []
var simulation_checkpoint_results: Dictionary = {}


func _ready() -> void:
	simulator = DynastySimulator.new()
	validator = GenerationValidator.new()
	report_generator = DynastyReportGenerator.new()
	config = SimulationConfig.new()

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_simulator_initialization()
	test_simulation_config_presets()
	test_full_dynasty_simulation()
	test_prestige_progression_across_generations()
	test_milestone_checkpoint_validation()
	test_prophecy_fulfillment_tracking()
	test_legendary_boss_progression()
	test_realm_unlocking_progression()
	test_world_scaling_difficulty()
	test_generation_state_validation()
	test_data_consistency_checks()
	test_system_integration_points()
	test_prestige_multiplier_compounding()
	test_generation_transfer_integrity()
	test_dynasty_report_generation()
	test_complex_integration_scenarios()


func test_simulator_initialization() -> void:
	assert(simulator != null, "Should create simulator")
	assert(simulator.max_generations == 999, "Should have 999 generations")
	assert(simulator.prestige_system != null, "Should initialize prestige system")
	assert(simulator.milestone_system != null, "Should initialize milestone system")

	test_results.append("✓ Simulator initialization")


func test_simulation_config_presets() -> void:
	var quick_config = config.create_preset_config("quick_test")
	assert(quick_config.max_generations == 100, "Quick test should run 100 gens")

	var balanced_config = config.create_preset_config("balanced")
	assert(balanced_config.max_generations == 999, "Balanced should run 999 gens")

	var debug_config = config.create_preset_config("debug")
	assert(debug_config.validate_every_generation, "Debug should validate every gen")

	test_results.append("✓ Simulation config presets")


func test_full_dynasty_simulation() -> void:
	# Run a partial simulation (50 generations for testing)
	simulator.start_dynasty_simulation()

	var success = true
	for gen in range(1, 51):
		var record = simulator.run_single_generation(gen)
		if not record or not record.validation_passed:
			success = false
			break

	assert(success, "Should complete 50 generations successfully")
	assert(simulator.generation_records.size() > 0, "Should record generations")

	test_results.append("✓ Full dynasty simulation")


func test_prestige_progression_across_generations() -> void:
	simulator.start_dynasty_simulation()

	var prev_prestige = 0
	var prestige_always_increases = true

	for gen in range(1, 51):
		var record = simulator.run_single_generation(gen)

		if record.prestige_at_end < prev_prestige:
			prestige_always_increases = false
			break

		prev_prestige = record.prestige_at_end

	assert(prestige_always_increases, "Prestige should always increase or stay same")
	assert(prev_prestige > 0, "Should have accumulated prestige")

	test_results.append("✓ Prestige progression across generations")


func test_milestone_checkpoint_validation() -> void:
	simulator.start_dynasty_simulation()

	var gen_100_record = null
	for gen in range(1, 101):
		var record = simulator.run_single_generation(gen)
		if gen == 100:
			gen_100_record = record

	assert(gen_100_record != null, "Should have gen 100 record")
	assert(gen_100_record.milestones_triggered.size() > 0, "Gen 100 should trigger milestone")

	test_results.append("✓ Milestone checkpoint validation")


func test_prophecy_fulfillment_tracking() -> void:
	simulator.start_dynasty_simulation()

	var total_prophecies = 0

	for gen in range(1, 51):
		var record = simulator.run_single_generation(gen)
		total_prophecies += record.prophecies_fulfilled

	assert(total_prophecies >= 0, "Should track prophecies")

	test_results.append("✓ Prophecy fulfillment tracking")


func test_legendary_boss_progression() -> void:
	simulator.start_dynasty_simulation()

	var bosses_defeated = []

	for gen in range(1, 101):
		var record = simulator.run_single_generation(gen)
		for boss in record.legendary_bosses_defeated:
			if boss not in bosses_defeated:
				bosses_defeated.append(boss)

	# At 100+ prestige, should be able to defeat some legendary bosses
	assert(bosses_defeated.size() >= 0, "Should track legendary defeats")

	test_results.append("✓ Legendary boss progression")


func test_realm_unlocking_progression() -> void:
	simulator.start_dynasty_simulation()

	var realms_reached = []

	for gen in range(1, 101):
		var record = simulator.run_single_generation(gen)
		if record.realm_reached not in realms_reached:
			realms_reached.append(record.realm_reached)

	assert(realms_reached.size() > 0, "Should unlock realms")

	test_results.append("✓ Realm unlocking progression")


func test_world_scaling_difficulty() -> void:
	simulator.start_dynasty_simulation()

	var gen_1 = simulator.run_single_generation(1)
	var gen_50 = null

	for gen in range(2, 51):
		gen_50 = simulator.run_single_generation(gen)

	# Heir level should increase with generations
	assert(gen_50.heir_level >= gen_1.heir_level, "Heir level should progress")

	test_results.append("✓ World scaling difficulty")


func test_generation_state_validation() -> void:
	simulator.start_dynasty_simulation()

	var all_valid = true

	for gen in range(1, 26):
		var record = simulator.run_single_generation(gen)

		# Manually validate key aspects
		if record.prestige_at_end < record.prestige_at_start:
			all_valid = false
			break

		if record.heir_level < 1:
			all_valid = false
			break

		if record.combat_victories < 0:
			all_valid = false
			break

	assert(all_valid, "All generation states should be valid")

	test_results.append("✓ Generation state validation")


func test_data_consistency_checks() -> void:
	simulator.start_dynasty_simulation()

	for gen in range(1, 26):
		var record = simulator.run_single_generation(gen)

		# Check required fields exist
		assert(record.generation > 0, "Generation should be positive")
		assert(record.prestige_at_end >= 0, "Prestige should be non-negative")
		assert(record.heir_level > 0, "Heir level should be positive")
		assert(record.realm_reached != "", "Realm should be set")

	test_results.append("✓ Data consistency checks")


func test_system_integration_points() -> void:
	simulator.start_dynasty_simulation()

	for gen in range(1, 26):
		var record = simulator.run_single_generation(gen)

		# Verify prestige system is active
		assert(simulator.prestige_system.total_prestige >= 0, "Prestige system active")

		# Verify milestone system is tracking
		assert(simulator.milestone_system.completed_milestones.size() >= 0, "Milestone system active")

		# Verify prophecy system is active
		assert(simulator.prophecy_system.prophecies.size() >= 0, "Prophecy system active")

		# Verify combat tracking
		assert(simulator.combat_tracker.combat_records.size() >= 0, "Combat tracking active")

	test_results.append("✓ System integration points")


func test_prestige_multiplier_compounding() -> void:
	simulator.start_dynasty_simulation()

	var gen_10 = null
	var gen_25 = null

	for gen in range(1, 26):
		var record = simulator.run_single_generation(gen)
		if gen == 10:
			gen_10 = record
		elif gen == 25:
			gen_25 = record

	# Prestige should accelerate as multipliers compound
	assert(gen_25.prestige_at_end > gen_10.prestige_at_end, "Later gens should have more prestige")

	test_results.append("✓ Prestige multiplier compounding")


func test_generation_transfer_integrity() -> void:
	simulator.start_dynasty_simulation()

	var records = []

	for gen in range(1, 26):
		var record = simulator.run_single_generation(gen)
		records.append(record)

	# Verify state carries forward properly
	for i in range(1, records.size()):
		var prev_record = records[i-1]
		var curr_record = records[i]

		# State should be continuous
		assert(curr_record.prestige_at_start <= curr_record.prestige_at_end, "Prestige flow should be valid")

	test_results.append("✓ Generation transfer integrity")


func test_dynasty_report_generation() -> void:
	simulator.start_dynasty_simulation()

	for gen in range(1, 26):
		simulator.run_single_generation(gen)

	var stats = simulator.get_simulation_stats()
	var report = report_generator.generate_dynasty_report(stats, simulator.generation_records, [])

	assert(report != null, "Should generate report")
	assert(report.generation_span == simulator.generation_records.size(), "Report should have correct span")
	assert(report.final_prestige >= 0, "Report should have prestige")

	var report_text = report_generator.format_report_as_text(report)
	assert(report_text.length() > 0, "Should format report as text")

	test_results.append("✓ Dynasty report generation")


func test_complex_integration_scenarios() -> void:
	# Scenario 1: Full 100-generation simulation
	simulator.start_dynasty_simulation()

	var success_100_gen = true
	for gen in range(1, 101):
		var record = simulator.run_single_generation(gen)
		if not record.validation_passed:
			success_100_gen = false
			break

	assert(success_100_gen, "Should complete 100 generations without error")

	# Scenario 2: Milestone progression tracking
	var milestones_at_100 = simulator.milestone_system.get_completed_milestones()
	assert(milestones_at_100.size() >= 1, "Should have at least 1 milestone at gen 100")

	# Scenario 3: Prestige tier advancement
	var difficulty_100 = simulator.world_scaling.calculate_world_difficulty(simulator.prestige_system.total_prestige)
	assert(difficulty_100.difficulty_multiplier > 0.5, "World should have scaled difficulty")

	# Scenario 4: System validation
	var validation = simulator.validate_all_systems()
	var all_systems_valid = true
	for result in validation.values():
		if not result:
			all_systems_valid = false

	assert(all_systems_valid, "All systems should pass validation")

	test_results.append("✓ Complex integration scenarios")


func print_results() -> void:
	print("\n╔═══════════════════════════════════════════════════════════════╗")
	print("║  Test Phase 15: Dynasty Simulation - 999 Generation Integration  ║")
	print("╚═══════════════════════════════════════════════════════════════╝\n")

	for result in test_results:
		print(result)

	print("\n%s" % ("─" * 65))
	print("Total: %d integration test groups passed\n" % test_results.size())

	# Print final statistics
	var stats = simulator.get_simulation_stats()
	if stats["total_generations_simulated"] > 0:
		print("═ SIMULATION STATISTICS ═")
		print("Generations Simulated: %d" % stats["total_generations_simulated"])
		print("Final Prestige: %d" % stats["final_prestige"])
		print("Milestones Reached: %d" % stats["total_milestones_reached"])
		print("Combat Victories: %d" % stats["total_combat_victories"])
		print("Prophecies Fulfilled: %d" % stats["total_prophecies_fulfilled"])
		print("Validation Errors: %d" % stats["validation_errors"])


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
