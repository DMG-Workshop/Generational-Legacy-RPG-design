## World Time Integration: Orchestrates all time systems
##
## Coordinates age progression, generation turnover, time simulation,
## realm transitions, and strata management

class_name WorldTimeIntegration


signal world_tick_complete(tick: int, year: int)
signal heir_aged_system(heir_name: String, new_age: int)
signal generation_turnover_triggered(from_heir: String, to_heir: String, generation: int)
signal legacy_milestone_reached(generation: int, legacy_value: int)


var age_progression_system: AgeProgressionSystem
var generation_turnover_system: GenerationTurnoverSystem
var time_simulation_system: TimeSimulationSystem
var realm_time_system: RealmTimeSystem
var strata_system: StrataSystem

# Tracked heirs
var active_heirs: Array = []  # Current and historical heirs
var heir_vital_status: Dictionary = {}  # heir_name -> {alive: bool, death_cause: String}


func _init(age: AgeProgressionSystem, turnover: GenerationTurnoverSystem, time: TimeSimulationSystem, realm: RealmTimeSystem, strata: StrataSystem) -> void:
	age_progression_system = age
	generation_turnover_system = turnover
	time_simulation_system = time
	realm_time_system = realm
	strata_system = strata


## Initialize world with first heir
func initialize_world(heir_name: String) -> void:
	age_progression_system.initialize_heir_age(heir_name)
	generation_turnover_system.initialize_first_heir(heir_name)
	active_heirs.append(heir_name)
	heir_vital_status[heir_name] = {"alive": true, "death_cause": ""}


## Process one world tick (applies time, ages heirs, checks death)
func process_world_tick(ticks: int = 1) -> Dictionary:
	var time_result = time_simulation_system.advance_time(ticks)
	var year = time_result["years"]
	var current_tick = time_result["ticks"]

	# Apply realm multiplier
	var realm_multiplier = realm_time_system.get_current_multiplier()
	var adjusted_ticks = int(ticks * realm_multiplier)

	# Check which heirs need aging
	var heirs_to_age = time_simulation_system.get_heirs_needing_aging(active_heirs)

	for heir_name in heirs_to_age:
		_age_heir(heir_name)

	# Check for deaths and succession
	var current_heir = generation_turnover_system.get_current_heir()
	if heir_vital_status[current_heir].get("alive", true):
		_check_heir_death(current_heir, year)

	world_tick_complete.emit(current_tick, year)

	return {
		"tick": current_tick,
		"year": year,
		"heirs_aged": heirs_to_age.size(),
		"realm_multiplier": realm_multiplier,
	}


## Age a single heir
func _age_heir(heir_name: String) -> void:
	var age_result = age_progression_system.age_heir(heir_name)

	if age_result.get("success", false):
		time_simulation_system.mark_heir_aged(heir_name)
		heir_aged_system.emit(heir_name, age_result["age"])

		# Check if entering elderly stage
		if age_result["stage"] == AgeProgressionSystem.AgeStage.ELDER:
			_handle_elder_transition(heir_name, age_result["age"])


## Check if heir should die
func _check_heir_death(heir_name: String, year: int) -> void:
	var age = age_progression_system.get_heir_age(heir_name)

	# Guaranteed death at 100+
	if age >= 100:
		_trigger_heir_death(heir_name, age, "old_age")
		return

	# Probabilistic death after 75
	if age >= 75:
		var death_probability = age_progression_system.get_death_probability(heir_name)
		if randf() < death_probability:
			_trigger_heir_death(heir_name, age, "natural_causes")


## Trigger heir death and succession
func _trigger_heir_death(heir_name: String, age: int, cause: String) -> void:
	heir_vital_status[heir_name]["alive"] = false
	heir_vital_status[heir_name]["death_cause"] = cause

	generation_turnover_system.trigger_heir_death(heir_name, age, cause)


## Handle heir entering elderly stage
func _handle_elder_transition(heir_name: String, age: int) -> void:
	# Could trigger special events or UI notifications
	pass


## Succession to next heir (called externally when next heir is ready)
func succession_to_heir(new_heir_name: String) -> Dictionary:
	var current_heir = generation_turnover_system.get_current_heir()

	var succession = generation_turnover_system.start_succession(new_heir_name, current_heir)

	# Initialize age for new heir
	age_progression_system.initialize_heir_age(new_heir_name)

	# Add to active heirs
	active_heirs.append(new_heir_name)
	heir_vital_status[new_heir_name] = {"alive": true, "death_cause": ""}

	# Create strata for compressed generations
	_create_generational_strata(generation_turnover_system.get_current_generation() - 1)

	generation_turnover_triggered.emit(current_heir, new_heir_name, succession["new_generation"])

	return succession


## Create strata for generation compression
func _create_generational_strata(generation: int) -> void:
	var generations_per_strata = 10

	# Check if we should compress (every N generations)
	if generation % generations_per_strata == 0:
		var start_gen = (generation / generations_per_strata - 1) * generations_per_strata + 1
		var end_gen = generation

		var strata_result = strata_system.create_strata(start_gen, end_gen)

		# Compress generation data into strata
		if strata_result.get("success", false):
			var strata_id = strata_result["strata_id"]
			for gen in range(start_gen, end_gen + 1):
				var gen_data = generation_turnover_system.get_generation_data(gen)
				if not gen_data.is_empty():
					strata_system.compress_generation_data(strata_id, gen, gen_data)


## Get current world time state
func get_world_state() -> Dictionary:
	var time_info = time_simulation_system.get_current_time()
	var current_heir = generation_turnover_system.get_current_heir()
	var heir_age = age_progression_system.get_heir_age(current_heir)
	var realm = realm_time_system.get_current_realm()

	return {
		"year": time_info["year"],
		"season": time_info["season_name"],
		"day": time_info["day_in_year"],
		"current_heir": current_heir,
		"heir_age": heir_age,
		"heir_life_stage": age_progression_system.get_life_stage_name(age_progression_system.get_heir_life_stage(current_heir)),
		"generation": generation_turnover_system.get_current_generation(),
		"current_realm": realm,
		"realm_multiplier": realm_time_system.get_current_multiplier(),
		"legacy_total": strata_system.calculate_total_legacy(),
	}


## Travel to realm (changes time acceleration)
func travel_to_realm(realm_name: String) -> bool:
	return realm_time_system.set_current_realm(realm_name)


## Get age stat penalties for current heir
func get_current_heir_age_penalties() -> Dictionary:
	var current_heir = generation_turnover_system.get_current_heir()
	return age_progression_system.get_age_stat_penalties(current_heir)


## Get full legacy summary
func get_legacy_summary() -> Dictionary:
	var generation = generation_turnover_system.get_current_generation()
	var heir_count = generation_turnover_system.get_heir_count()
	var avg_lifespan = generation_turnover_system.get_average_lifespan()

	return {
		"current_generation": generation,
		"heir_count": heir_count,
		"average_lifespan": avg_lifespan,
		"total_legacy": strata_system.calculate_total_legacy(),
		"total_echoes": strata_system.count_total_legacy_echoes(),
		"lineage": generation_turnover_system.get_heir_lineage(),
		"greatest_generation": generation_turnover_system.get_greatest_generation(),
	}


## Get heir vitality status
func get_heir_status(heir_name: String) -> Dictionary:
	var vital = heir_vital_status.get(heir_name, {})
	var age = age_progression_system.get_heir_age(heir_name)
	var lifespan_info = age_progression_system.get_lifespan_summary(heir_name)

	return {
		"heir_name": heir_name,
		"alive": vital.get("alive", false),
		"death_cause": vital.get("death_cause", ""),
		"age": age,
		"life_stage": age_progression_system.get_life_stage_name(age_progression_system.get_heir_life_stage(heir_name)),
		"lifespan": lifespan_info,
	}


## Fast forward time (for testing)
func fast_forward_years(years: int) -> Dictionary:
	var results = []

	for year in range(years):
		var tick_result = process_world_tick(1000)  # 1000 ticks = 1 year
		results.append(tick_result)

	return {
		"years_advanced": years,
		"final_state": get_world_state(),
		"results": results,
	}


## Get time analysis (how time flows in current realm vs. prime)
func get_time_analysis() -> Dictionary:
	var current_multiplier = realm_time_system.get_current_multiplier()
	var prime_multiplier = realm_time_system.get_realm_multiplier("Prime")

	return {
		"current_realm": realm_time_system.get_current_realm(),
		"current_multiplier": current_multiplier,
		"relative_speed": current_multiplier / prime_multiplier,
		"time_compression": current_multiplier > 1.0,
		"time_dilation": current_multiplier < 1.0,
	}


## Record legacy echo (for important events)
func record_legacy_echo(generation: int, heir_name: String, description: String, impact: int) -> bool:
	var latest_strata = strata_system.get_latest_strata()

	if latest_strata.is_empty():
		return false

	var strata_id = latest_strata.keys()[0]

	return strata_system.record_legacy_echo(strata_id, {
		"generation": generation,
		"heir_name": heir_name,
		"description": description,
		"impact": impact,
	})
