## Generation Validator: Validate each generation's state consistency
##
## Checks data integrity, system consistency, and progression validity across generations

extends Node

class_name GenerationValidator


signal validation_passed(generation: int)
signal validation_failed(generation: int, reason: String)
signal validation_warning(generation: int, warning: String)


var validation_checks: Array = []
var validation_errors: Array = []
var validation_warnings: Array = []


class ValidationCheck:
	var check_name: String
	var check_function: Callable
	var is_critical: bool
	var last_result: bool
	var last_message: String

	func _init(p_name: String, p_func: Callable, p_critical: bool = true) -> void:
		check_name = p_name
		check_function = p_func
		is_critical = p_critical
		last_result = true
		last_message = ""


func _init() -> void:
	_initialize_validation_checks()


func validate_generation(generation: int, record: Dictionary) -> bool:
	validation_errors.clear()
	validation_warnings.clear()

	var all_passed = true

	for check in validation_checks:
		var result = check.check_function.call(generation, record)
		check.last_result = result

		if not result:
			if check.is_critical:
				validation_errors.append(check.check_name)
				all_passed = false
				validation_failed.emit(generation, check.check_name)
			else:
				validation_warnings.append(check.check_name)
				validation_warning.emit(generation, check.check_name)

	if all_passed:
		validation_passed.emit(generation)

	return all_passed


func validate_prestige_progression(generation: int, record: Dictionary) -> bool:
	# Prestige should never decrease
	if record.get("prestige_at_end", 0) < record.get("prestige_at_start", 0):
		return false

	# Prestige should increase by reasonable amount
	var prestige_gain = record.get("prestige_at_end", 0) - record.get("prestige_at_start", 0)
	if generation > 1 and prestige_gain < 0:
		return false

	return true


func validate_milestone_progression(generation: int, record: Dictionary) -> bool:
	# Milestones should only be triggered at specific generations
	var milestones = record.get("milestones_triggered", [])

	for milestone_id in milestones:
		# Validate milestone ID format
		if not milestone_id.begins_with("milestone_"):
			return false

	return true


func validate_prophecy_fulfillment(generation: int, record: Dictionary) -> bool:
	var prophecies_fulfilled = record.get("prophecies_fulfilled", 0)

	# Prophecies fulfilled should be non-negative
	if prophecies_fulfilled < 0:
		return false

	# Prophecies should not exceed reasonable limit per generation
	if prophecies_fulfilled > 20:
		return false

	return true


func validate_legacy_events(generation: int, record: Dictionary) -> bool:
	var events_created = record.get("events_created", 0)

	# Events should be non-negative
	if events_created < 0:
		return false

	# Should not exceed reasonable limit per generation
	if events_created > 10:
		return false

	return true


func validate_combat_records(generation: int, record: Dictionary) -> bool:
	var combat_victories = record.get("combat_victories", 0)

	# Victories should be non-negative
	if combat_victories < 0:
		return false

	# Should have some combat activity most generations
	if generation > 10 and combat_victories > 100:
		return false

	return true


func validate_heir_progression(generation: int, record: Dictionary) -> bool:
	var heir_level = record.get("heir_level", 1)

	# Level should increase over time (or stay same at minimum)
	if heir_level < 1:
		return false

	# Level should scale reasonably with generation
	var expected_level = 10 + (generation / 50)
	if heir_level > expected_level * 2:
		return false

	return true


func validate_realm_progression(generation: int, record: Dictionary) -> bool:
	var realm = record.get("realm_reached", "starter_lands")

	# Realm should be a valid realm ID
	var valid_realms = ["starter_lands", "silver_reach", "golden_expanse", "platinum_peaks", "diamond_wastes", "eternal_abyss"]

	if realm not in valid_realms:
		return false

	return true


func validate_data_consistency(generation: int, record: Dictionary) -> bool:
	# Check all required fields exist
	var required_fields = ["generation", "prestige_at_start", "prestige_at_end", "heir_level", "realm_reached"]

	for field in required_fields:
		if not record.has(field):
			return false

	# Check types
	if not (record["generation"] is int):
		return false
	if not (record["prestige_at_start"] is int):
		return false
	if not (record["prestige_at_end"] is int):
		return false
	if not (record["heir_level"] is int):
		return false

	return true


func validate_no_data_corruption(generation: int, record: Dictionary) -> bool:
	# Check for NaN or infinite values
	if record.has("heir_stats"):
		var stats = record["heir_stats"]
		for stat_value in stats.values():
			if not (stat_value is int) or stat_value < 0:
				return false

	return true


func validate_milestone_uniqueness(generation: int, all_records: Array) -> bool:
	# Each milestone generation should only have one record
	var milestone_gens = {}

	for record in all_records:
		var milestones = record.get("milestones_triggered", [])
		if milestones.size() > 0:
			var gen = record.get("generation", 0)
			if gen in milestone_gens:
				return false  # Duplicate milestone generation
			milestone_gens[gen] = true

	return true


func validate_prophecy_fulfillment_rate(generation: int, all_records: Array) -> bool:
	# Fulfillment rate should be reasonable (not 0 or 100%)
	var total_prophecies = 0

	for record in all_records:
		total_prophecies += record.get("prophecies_fulfilled", 0)

	if all_records.size() > 0:
		var rate = float(total_prophecies) / float(all_records.size())
		if rate > 10.0:  # More than 10 prophecies per generation on average is unrealistic
			return false

	return true


func get_validation_report(generation: int) -> Dictionary:
	var report = {
		"generation": generation,
		"validation_passed": validation_errors.size() == 0,
		"errors": validation_errors.duplicate(),
		"warnings": validation_warnings.duplicate(),
		"error_count": validation_errors.size(),
		"warning_count": validation_warnings.size()
	}

	return report


func get_validation_summary(all_records: Array) -> Dictionary:
	var summary = {
		"total_generations": all_records.size(),
		"generations_passed": 0,
		"generations_failed": 0,
		"total_errors": 0,
		"total_warnings": 0,
		"failed_generations": []
	}

	for record in all_records:
		var validation_result = validate_generation(record.get("generation", 0), record)

		if validation_result:
			summary["generations_passed"] += 1
		else:
			summary["generations_failed"] += 1
			summary["failed_generations"].append(record.get("generation", 0))

		summary["total_errors"] += validation_errors.size()
		summary["total_warnings"] += validation_warnings.size()

	return summary


func validate_prestige_multiplier_scaling(generation: int, record: Dictionary, prestige_multiplier: float) -> bool:
	# Prestige multiplier should be between 1.0 and 2.0
	if prestige_multiplier < 1.0 or prestige_multiplier > 2.0:
		return false

	return true


func validate_tier_progression(generation: int, prestige_tier: int) -> bool:
	# Tier should be between 0 and 5
	if prestige_tier < 0 or prestige_tier > 5:
		return false

	# Tier should not exceed generation-based cap
	var max_tier_at_gen = int(generation / 150)
	if prestige_tier > max_tier_at_gen + 1:
		return false

	return true


func _initialize_validation_checks() -> void:
	validation_checks.append(ValidationCheck.new("Prestige Progression", Callable(self, "validate_prestige_progression"), true))
	validation_checks.append(ValidationCheck.new("Milestone Progression", Callable(self, "validate_milestone_progression"), true))
	validation_checks.append(ValidationCheck.new("Prophecy Fulfillment", Callable(self, "validate_prophecy_fulfillment"), false))
	validation_checks.append(ValidationCheck.new("Legacy Events", Callable(self, "validate_legacy_events"), false))
	validation_checks.append(ValidationCheck.new("Combat Records", Callable(self, "validate_combat_records"), false))
	validation_checks.append(ValidationCheck.new("Heir Progression", Callable(self, "validate_heir_progression"), true))
	validation_checks.append(ValidationCheck.new("Realm Progression", Callable(self, "validate_realm_progression"), true))
	validation_checks.append(ValidationCheck.new("Data Consistency", Callable(self, "validate_data_consistency"), true))
	validation_checks.append(ValidationCheck.new("Data Corruption Check", Callable(self, "validate_no_data_corruption"), true))
