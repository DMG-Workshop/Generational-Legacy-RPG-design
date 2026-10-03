## Simulation Config: Configuration for dynasty simulation
##
## Defines simulation parameters, speed, and detail levels

extends Node

class_name SimulationConfig


enum SimulationSpeed { SLOW, NORMAL, FAST, ULTRA_FAST }

enum DetailLevel { MINIMAL, NORMAL, VERBOSE, DEBUG }


var simulation_speed: int = SimulationSpeed.NORMAL
var detail_level: int = DetailLevel.NORMAL
var max_generations: int = 999
var checkpoint_interval: int = 100
var validate_every_generation: bool = true
var save_full_state: bool = false
var parallel_validation: bool = false
var random_seed: int = -1  # -1 = random, otherwise use this seed
var generation_batch_size: int = 1  # Generations to process before yielding


var speed_multipliers: Dictionary = {
	SimulationSpeed.SLOW: 1.0,
	SimulationSpeed.NORMAL: 1.0,
	SimulationSpeed.FAST: 2.0,
	SimulationSpeed.ULTRA_FAST: 5.0
}

var detail_level_verbosity: Dictionary = {
	DetailLevel.MINIMAL: 0,
	DetailLevel.NORMAL: 1,
	DetailLevel.VERBOSE: 2,
	DetailLevel.DEBUG: 3
}


func _init() -> void:
	if random_seed == -1:
		random_seed = randi()
	seed(random_seed)


func set_simulation_speed(speed: int) -> void:
	if speed in speed_multipliers:
		simulation_speed = speed


func set_detail_level(level: int) -> void:
	if level in detail_level_verbosity:
		detail_level = level


func get_speed_multiplier() -> float:
	return speed_multipliers.get(simulation_speed, 1.0)


func get_verbosity_level() -> int:
	return detail_level_verbosity.get(detail_level, 1)


func should_validate_generation() -> bool:
	match detail_level:
		DetailLevel.MINIMAL:
			return false
		DetailLevel.NORMAL:
			return randi() % 10 == 0  # Validate 10% of generations
		DetailLevel.VERBOSE:
			return randi() % 2 == 0   # Validate 50% of generations
		DetailLevel.DEBUG:
			return true  # Validate all generations

	return false


func get_config_summary() -> String:
	var speed_names = ["SLOW", "NORMAL", "FAST", "ULTRA_FAST"]
	var detail_names = ["MINIMAL", "NORMAL", "VERBOSE", "DEBUG"]

	var summary = "Simulation Configuration:\n"
	summary += "- Speed: %s (%.1fx)\n" % [speed_names[simulation_speed], get_speed_multiplier()]
	summary += "- Detail Level: %s\n" % detail_names[detail_level]
	summary += "- Max Generations: %d\n" % max_generations
	summary += "- Checkpoint Interval: %d\n" % checkpoint_interval
	summary += "- Validation: %s\n" % ("Every Generation" if validate_every_generation else "Sampled")
	summary += "- Random Seed: %d\n" % random_seed

	return summary


func get_estimated_runtime() -> float:
	# Rough estimate: 1 generation per 0.1 seconds at NORMAL speed
	var base_time = (max_generations / 10.0)  # in seconds
	var speed_factor = get_speed_multiplier()

	return base_time / speed_factor


func create_preset_config(preset_name: String) -> SimulationConfig:
	var config = SimulationConfig.new()

	match preset_name:
		"quick_test":
			config.max_generations = 100
			config.simulation_speed = SimulationSpeed.ULTRA_FAST
			config.detail_level = DetailLevel.MINIMAL
			config.checkpoint_interval = 25
			config.validate_every_generation = false

		"balanced":
			config.max_generations = 999
			config.simulation_speed = SimulationSpeed.NORMAL
			config.detail_level = DetailLevel.NORMAL
			config.checkpoint_interval = 100
			config.validate_every_generation = false

		"thorough":
			config.max_generations = 999
			config.simulation_speed = SimulationSpeed.SLOW
			config.detail_level = DetailLevel.VERBOSE
			config.checkpoint_interval = 50
			config.validate_every_generation = true
			config.parallel_validation = true

		"debug":
			config.max_generations = 999
			config.simulation_speed = SimulationSpeed.SLOW
			config.detail_level = DetailLevel.DEBUG
			config.checkpoint_interval = 10
			config.validate_every_generation = true
			config.save_full_state = true

	return config
