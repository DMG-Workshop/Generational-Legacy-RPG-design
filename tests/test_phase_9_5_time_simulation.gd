## Test Suite for Phase 9.5: Time Simulation & Age Transitions
##
## Comprehensive tests for age progression, generation turnover, time simulation,
## realm transitions, strata compression, and integrated world time systems

extends GutTest


var age_progression_system: AgeProgressionSystem
var generation_turnover_system: GenerationTurnoverSystem
var time_simulation_system: TimeSimulationSystem
var realm_time_system: RealmTimeSystem
var strata_system: StrataSystem
var world_time_integration: WorldTimeIntegration


func before_each() -> void:
	age_progression_system = AgeProgressionSystem.new()
	generation_turnover_system = GenerationTurnoverSystem.new()
	time_simulation_system = TimeSimulationSystem.new()
	realm_time_system = RealmTimeSystem.new()
	strata_system = StrataSystem.new()
	world_time_integration = WorldTimeIntegration.new(age_progression_system, generation_turnover_system, time_simulation_system, realm_time_system, strata_system)


# ============================================================
# Age Progression System Tests
# ============================================================

func test_heir_age_initialization() -> void:
	age_progression_system.initialize_heir_age("hero1", 0)
	assert_eq(age_progression_system.get_heir_age("hero1"), 0)


func test_heir_aging_one_year() -> void:
	age_progression_system.initialize_heir_age("hero1")
	age_progression_system.age_heir("hero1")
	assert_eq(age_progression_system.get_heir_age("hero1"), 1)


func test_heir_life_stage_youth() -> void:
	age_progression_system.initialize_heir_age("hero1")
	var stage = age_progression_system.get_heir_life_stage("hero1")
	assert_eq(stage, AgeProgressionSystem.AgeStage.YOUTH)


func test_heir_life_stage_adult_at_25() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(25):
		age_progression_system.age_heir("hero1")
	var stage = age_progression_system.get_heir_life_stage("hero1")
	assert_eq(stage, AgeProgressionSystem.AgeStage.ADULT)


func test_heir_life_stage_elder_at_50() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(50):
		age_progression_system.age_heir("hero1")
	var stage = age_progression_system.get_heir_life_stage("hero1")
	assert_eq(stage, AgeProgressionSystem.AgeStage.ELDER)


func test_heir_life_stage_ancient_at_75() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(75):
		age_progression_system.age_heir("hero1")
	var stage = age_progression_system.get_heir_life_stage("hero1")
	assert_eq(stage, AgeProgressionSystem.AgeStage.ANCIENT)


func test_age_stat_penalties_youth() -> void:
	age_progression_system.initialize_heir_age("hero1")
	var penalties = age_progression_system.get_age_stat_penalties("hero1")
	assert_eq(penalties["strength"], 0, "Youth should have no penalties")


func test_age_stat_penalties_adult() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(25):
		age_progression_system.age_heir("hero1")
	var penalties = age_progression_system.get_age_stat_penalties("hero1")
	assert_eq(penalties["wisdom"], 1, "Adult should gain +1 wisdom")


func test_age_stat_penalties_elder() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(50):
		age_progression_system.age_heir("hero1")
	var penalties = age_progression_system.get_age_stat_penalties("hero1")
	assert_eq(penalties["strength"], -2, "Elder should lose -2 strength")
	assert_eq(penalties["wisdom"], 2, "Elder should gain +2 wisdom")


func test_age_stat_penalties_ancient() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(75):
		age_progression_system.age_heir("hero1")
	var penalties = age_progression_system.get_age_stat_penalties("hero1")
	assert_eq(penalties["strength"], -4, "Ancient should lose -4 strength")
	assert_eq(penalties["constitution"], -3)


func test_ready_to_retire_at_75() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(75):
		age_progression_system.age_heir("hero1")
	assert_true(age_progression_system.is_ready_to_retire("hero1"))


func test_near_death_at_90() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(90):
		age_progression_system.age_heir("hero1")
	assert_true(age_progression_system.is_near_death("hero1"))


func test_death_guaranteed_at_100() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(100):
		age_progression_system.age_heir("hero1")
	assert_true(age_progression_system.is_dead("hero1"))


func test_death_probability_at_75() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(75):
		age_progression_system.age_heir("hero1")
	var prob = age_progression_system.get_death_probability("hero1")
	assert_eq(prob, 0.05)


func test_death_probability_at_90() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(90):
		age_progression_system.age_heir("hero1")
	var prob = age_progression_system.get_death_probability("hero1")
	assert_eq(prob, 0.75)


func test_heir_viability_peak_years() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(30):
		age_progression_system.age_heir("hero1")
	var viability = age_progression_system.calculate_heir_viability("hero1")
	assert_eq(viability, 1.0, "Peak years should have 1.0 viability")


func test_heir_viability_aging() -> void:
	age_progression_system.initialize_heir_age("hero1")
	for i in range(70):
		age_progression_system.age_heir("hero1")
	var viability = age_progression_system.calculate_heir_viability("hero1")
	assert_true(viability < 1.0, "Old age reduces viability")


# ============================================================
# Generation Turnover System Tests
# ============================================================

func test_first_heir_initialization() -> void:
	generation_turnover_system.initialize_first_heir("hero1")
	assert_eq(generation_turnover_system.get_current_heir(), "hero1")
	assert_eq(generation_turnover_system.get_current_generation(), 1)


func test_heir_death_trigger() -> void:
	generation_turnover_system.initialize_first_heir("hero1")
	var result = generation_turnover_system.trigger_heir_death("hero1", 75, "old_age")
	assert_true(result["success"])


func test_succession_to_next_heir() -> void:
	generation_turnover_system.initialize_first_heir("hero1")
	generation_turnover_system.trigger_heir_death("hero1", 75)
	var result = generation_turnover_system.start_succession("hero2", "hero1")
	assert_eq(result["new_generation"], 2)
	assert_eq(generation_turnover_system.get_current_heir(), "hero2")


func test_generation_count_increases() -> void:
	generation_turnover_system.initialize_first_heir("hero1")
	generation_turnover_system.start_succession("hero2", "hero1")
	generation_turnover_system.start_succession("hero3", "hero2")
	assert_eq(generation_turnover_system.get_current_generation(), 3)


func test_heir_history_recorded() -> void:
	generation_turnover_system.initialize_first_heir("hero1")
	generation_turnover_system.trigger_heir_death("hero1", 50)
	var history = generation_turnover_system.get_heir_history()
	assert_eq(history.size(), 1)
	assert_eq(history[0]["heir_name"], "hero1")


func test_total_generations_tracked() -> void:
	generation_turnover_system.initialize_first_heir("hero1")
	generation_turnover_system.start_succession("hero2", "hero1")
	generation_turnover_system.start_succession("hero3", "hero2")
	generation_turnover_system.start_succession("hero4", "hero3")
	assert_eq(generation_turnover_system.get_total_generations(), 4)


func test_average_lifespan_calculation() -> void:
	generation_turnover_system.initialize_first_heir("hero1")
	generation_turnover_system.trigger_heir_death("hero1", 60)
	generation_turnover_system.start_succession("hero2", "hero1")
	generation_turnover_system.trigger_heir_death("hero2", 70)
	var avg = generation_turnover_system.get_average_lifespan()
	assert_eq(avg, 65.0)


func test_longest_lived_heir_tracking() -> void:
	generation_turnover_system.initialize_first_heir("hero1")
	generation_turnover_system.trigger_heir_death("hero1", 50)
	generation_turnover_system.start_succession("hero2", "hero1")
	generation_turnover_system.trigger_heir_death("hero2", 80)
	var longest = generation_turnover_system.get_longest_lived_heir()
	assert_eq(longest["heir_name"], "hero2")
	assert_eq(longest["age_at_death"], 80)


# ============================================================
# Time Simulation System Tests
# ============================================================

func test_time_initialization() -> void:
	var time = time_simulation_system.get_current_time()
	assert_eq(time["tick"], 0)
	assert_eq(time["year"], 0)


func test_time_advance_ticks() -> void:
	time_simulation_system.advance_time(100)
	var time = time_simulation_system.get_current_time()
	assert_eq(time["tick"], 100)


func test_time_advance_one_year() -> void:
	time_simulation_system.advance_time(1000)
	var time = time_simulation_system.get_current_time()
	assert_eq(time["year"], 1)


func test_season_spring() -> void:
	var time = time_simulation_system.get_current_time()
	assert_eq(time["season"], 0)


func test_season_summer_at_250_ticks() -> void:
	time_simulation_system.advance_time(250)
	var time = time_simulation_system.get_current_time()
	assert_eq(time["season"], 1)


func test_season_autumn_at_500_ticks() -> void:
	time_simulation_system.advance_time(500)
	var time = time_simulation_system.get_current_time()
	assert_eq(time["season"], 2)


func test_season_winter_at_750_ticks() -> void:
	time_simulation_system.advance_time(750)
	var time = time_simulation_system.get_current_time()
	assert_eq(time["season"], 3)


func test_heir_should_age() -> void:
	age_progression_system.initialize_heir_age("hero1")
	assert_true(time_simulation_system.should_age_heir("hero1"))
	time_simulation_system.mark_heir_aged("hero1")
	assert_false(time_simulation_system.should_age_heir("hero1"))


func test_year_progress_calculation() -> void:
	time_simulation_system.advance_time(500)  # Half year
	var progress = time_simulation_system.get_year_progress()
	assert_eq(progress, 0.5)


func test_season_progress_calculation() -> void:
	time_simulation_system.advance_time(125)  # Half season
	var progress = time_simulation_system.get_season_progress()
	assert_eq(progress, 0.5)


# ============================================================
# Realm Time System Tests
# ============================================================

func test_realm_initialization() -> void:
	var realm = realm_time_system.get_current_realm()
	assert_eq(realm, "Prime")


func test_prime_realm_multiplier() -> void:
	var multiplier = realm_time_system.get_realm_multiplier("Prime")
	assert_eq(multiplier, 1.0)


func test_aethral_realm_multiplier() -> void:
	var multiplier = realm_time_system.get_realm_multiplier("Aethral")
	assert_eq(multiplier, 5.0)


func test_chronos_realm_multiplier() -> void:
	var multiplier = realm_time_system.get_realm_multiplier("Chronos")
	assert_eq(multiplier, 3.0)


func test_travel_to_realm() -> void:
	var result = realm_time_system.set_current_realm("Aethral")
	assert_true(result)
	assert_eq(realm_time_system.get_current_realm(), "Aethral")


func test_current_multiplier_changes_with_realm() -> void:
	realm_time_system.set_current_realm("Chronos")
	var multiplier = realm_time_system.get_current_multiplier()
	assert_eq(multiplier, 3.0)


func test_apply_multiplier_to_ticks() -> void:
	realm_time_system.set_current_realm("Chronos")
	var adjusted = realm_time_system.apply_multiplier(100)
	assert_eq(adjusted, 300)


func test_realm_visit_tracking() -> void:
	realm_time_system.set_current_realm("Chronos")
	realm_time_system.set_current_realm("Prime")
	realm_time_system.set_current_realm("Chronos")
	var visits = realm_time_system.get_realm_visit_count("Chronos")
	assert_eq(visits, 2)


func test_most_visited_realm() -> void:
	realm_time_system.set_current_realm("Chronos")
	realm_time_system.set_current_realm("Chronos")
	realm_time_system.set_current_realm("Prime")
	var most = realm_time_system.get_most_visited_realm()
	assert_eq(most, "Chronos")


# ============================================================
# Strata System Tests
# ============================================================

func test_strata_creation() -> void:
	var result = strata_system.create_strata(1, 10)
	assert_true(result["success"])
	assert_eq(result["generations"], 10)


func test_strata_data_retrieval() -> void:
	strata_system.create_strata(1, 10)
	var strata = strata_system.get_strata(1)
	assert_eq(strata["start_generation"], 1)
	assert_eq(strata["end_generation"], 10)


func test_compress_generation_data() -> void:
	strata_system.create_strata(1, 10)
	var success = strata_system.compress_generation_data(1, 1, {
		"heir_name": "hero1",
		"age_at_death": 75,
		"legacy_value": 100,
	})
	assert_true(success)


func test_record_legacy_echo() -> void:
	strata_system.create_strata(1, 10)
	var success = strata_system.record_legacy_echo(1, {
		"generation": 1,
		"heir_name": "hero1",
		"description": "Great victory",
		"impact": 50,
	})
	assert_true(success)


func test_legacy_echo_retrieval() -> void:
	strata_system.create_strata(1, 10)
	strata_system.record_legacy_echo(1, {"generation": 1, "heir_name": "hero1", "description": "Victory", "impact": 50})
	var echoes = strata_system.get_legacy_echoes(1)
	assert_eq(echoes.size(), 1)


func test_strata_value_calculation() -> void:
	strata_system.create_strata(1, 10)
	strata_system.compress_generation_data(1, 1, {"legacy_value": 100})
	strata_system.compress_generation_data(1, 2, {"legacy_value": 150})
	var value = strata_system.calculate_strata_value(1)
	assert_eq(value, 250)


func test_total_legacy_calculation() -> void:
	strata_system.create_strata(1, 10)
	strata_system.compress_generation_data(1, 1, {"legacy_value": 100})
	strata_system.create_strata(11, 20)
	strata_system.compress_generation_data(2, 11, {"legacy_value": 200})
	var total = strata_system.calculate_total_legacy()
	assert_eq(total, 300)


func test_heroes_from_strata() -> void:
	strata_system.create_strata(1, 10)
	strata_system.compress_generation_data(1, 1, {"heir_name": "hero1", "legacy_value": 150})
	strata_system.compress_generation_data(1, 2, {"heir_name": "hero2", "legacy_value": 80})
	var heroes = strata_system.get_heroes_from_strata(100)
	assert_eq(heroes.size(), 1)
	assert_eq(heroes[0]["heir_name"], "hero1")


# ============================================================
# World Time Integration Tests
# ============================================================

func test_world_initialization() -> void:
	world_time_integration.initialize_world("hero1")
	var state = world_time_integration.get_world_state()
	assert_eq(state["current_heir"], "hero1")
	assert_eq(state["generation"], 1)


func test_process_world_tick() -> void:
	world_time_integration.initialize_world("hero1")
	var result = world_time_integration.process_world_tick(100)
	assert_eq(result["tick"], 100)


func test_world_year_advancement() -> void:
	world_time_integration.initialize_world("hero1")
	world_time_integration.process_world_tick(1000)
	var state = world_time_integration.get_world_state()
	assert_eq(state["year"], 1)


func test_heir_ages_in_world() -> void:
	world_time_integration.initialize_world("hero1")
	for i in range(25):
		world_time_integration.process_world_tick(1000)  # 1 year per tick
	var state = world_time_integration.get_world_state()
	assert_eq(state["heir_age"], 25)


func test_fast_forward_years() -> void:
	world_time_integration.initialize_world("hero1")
	var result = world_time_integration.fast_forward_years(10)
	assert_eq(result["years_advanced"], 10)


func test_realm_travel() -> void:
	world_time_integration.initialize_world("hero1")
	var result = world_time_integration.travel_to_realm("Chronos")
	assert_true(result)
	var state = world_time_integration.get_world_state()
	assert_eq(state["current_realm"], "Chronos")


func test_age_stat_penalties_in_world() -> void:
	world_time_integration.initialize_world("hero1")
	for i in range(50):
		world_time_integration.process_world_tick(1000)
	var penalties = world_time_integration.get_current_heir_age_penalties()
	assert_true(penalties["strength"] < 0, "Elder should have strength penalty")


func test_legacy_summary() -> void:
	world_time_integration.initialize_world("hero1")
	var summary = world_time_integration.get_legacy_summary()
	assert_eq(summary["current_generation"], 1)
	assert_eq(summary["heir_count"], 1)


# ============================================================
# Complex Scenario Tests
# ============================================================

func test_full_life_cycle_single_heir() -> void:
	world_time_integration.initialize_world("hero1")

	# Let hero1 live 75 years
	for i in range(75):
		world_time_integration.process_world_tick(1000)

	var state = world_time_integration.get_world_state()
	assert_eq(state["heir_age"], 75)


func test_generational_progression() -> void:
	world_time_integration.initialize_world("hero1")

	# Let hero1 reach 75
	for i in range(75):
		world_time_integration.process_world_tick(1000)

	# Succession
	world_time_integration.succession_to_heir("hero2")
	var state = world_time_integration.get_world_state()
	assert_eq(state["current_heir"], "hero2")
	assert_eq(state["generation"], 2)


func test_multi_generational_legacy() -> void:
	world_time_integration.initialize_world("hero1")

	for i in range(75):
		world_time_integration.process_world_tick(1000)

	world_time_integration.succession_to_heir("hero2")

	for i in range(75):
		world_time_integration.process_world_tick(1000)

	world_time_integration.succession_to_heir("hero3")

	var summary = world_time_integration.get_legacy_summary()
	assert_eq(summary["current_generation"], 3)
	assert_eq(summary["heir_count"], 3)


func test_realm_time_acceleration() -> void:
	world_time_integration.initialize_world("hero1")

	world_time_integration.travel_to_realm("Aethral")  # 5x multiplier
	world_time_integration.process_world_tick(1000)

	var state = world_time_integration.get_world_state()
	# Should have accumulated more ticks/years due to multiplier
	assert_true(state["year"] >= 5)


func test_season_progression() -> void:
	world_time_integration.initialize_world("hero1")

	var initial_time = time_simulation_system.get_current_time()
	assert_eq(initial_time["season"], 0)  # Spring

	world_time_integration.process_world_tick(250)
	var after_ticks = time_simulation_system.get_current_time()
	assert_eq(after_ticks["season"], 1)  # Summer


func test_time_analysis() -> void:
	world_time_integration.initialize_world("hero1")
	world_time_integration.travel_to_realm("Chronos")  # 3x

	var analysis = world_time_integration.get_time_analysis()
	assert_eq(analysis["current_multiplier"], 3.0)
	assert_true(analysis["time_compression"])
	assert_false(analysis["time_dilation"])
