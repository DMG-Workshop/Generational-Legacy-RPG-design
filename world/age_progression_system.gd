## Age Progression System: Manage heir aging, degradation, and lifecycle
##
## Tracks heir age in years, applies stat degradation with age,
## and determines death/retirement conditions

class_name AgeProgressionSystem


signal heir_aged(heir_name: String, new_age: int)
signal heir_entering_elderly(heir_name: String, age: int)
signal heir_death_imminent(heir_name: String, age: int)
signal heir_retired(heir_name: String, age: int)
signal stat_degradation_applied(heir_name: String, stat_penalties: Dictionary)


# Age stage definitions
enum AgeStage { YOUTH, ADULT, ELDER, ANCIENT }

var age_thresholds: Dictionary = {
	AgeStage.YOUTH: {"min": 0, "max": 24, "name": "Youth"},
	AgeStage.ADULT: {"min": 25, "max": 49, "name": "Adult"},
	AgeStage.ELDER: {"min": 50, "max": 74, "name": "Elder"},
	AgeStage.ANCIENT: {"min": 75, "max": 999, "name": "Ancient"},
}

# Stat degradation per age stage
var age_stat_penalties: Dictionary = {
	AgeStage.YOUTH: {
		"strength": 0,
		"dexterity": 0,
		"constitution": 0,
		"intelligence": 0,
		"wisdom": 0,
		"charisma": 0,
	},
	AgeStage.ADULT: {
		"strength": 0,
		"dexterity": 0,
		"constitution": 0,
		"intelligence": 0,
		"wisdom": 1,  # Wisdom increases slightly
		"charisma": 0,
	},
	AgeStage.ELDER: {
		"strength": -2,
		"dexterity": -2,
		"constitution": -1,
		"intelligence": 0,
		"wisdom": 2,
		"charisma": 0,
	},
	AgeStage.ANCIENT: {
		"strength": -4,
		"dexterity": -3,
		"constitution": -3,
		"intelligence": -1,
		"wisdom": 3,
		"charisma": -1,
	},
}

# Maximum age per stage before forced retirement
var max_ages: Dictionary = {
	AgeStage.YOUTH: 24,
	AgeStage.ADULT: 49,
	AgeStage.ELDER: 74,
	AgeStage.ANCIENT: 100,  # Death at 100 is guaranteed
}

# Heir age tracking
var heir_ages: Dictionary = {}  # heir_name -> age (in years)
var heir_birth_dates: Dictionary = {}  # heir_name -> birth_tick
var heir_life_stage: Dictionary = {}  # heir_name -> AgeStage


## Initialize heir age (born at age 0)
func initialize_heir_age(heir_name: String, birth_tick: int = 0) -> void:
	heir_ages[heir_name] = 0
	heir_birth_dates[heir_name] = birth_tick
	heir_life_stage[heir_name] = AgeStage.YOUTH


## Get heir current age
func get_heir_age(heir_name: String) -> int:
	return heir_ages.get(heir_name, 0)


## Get heir life stage
func get_heir_life_stage(heir_name: String) -> int:
	var age = get_heir_age(heir_name)
	for stage in age_thresholds.keys():
		var threshold = age_thresholds[stage]
		if age >= threshold["min"] and age <= threshold["max"]:
			return stage
	return AgeStage.ANCIENT


## Get life stage name
func get_life_stage_name(stage: int) -> String:
	return age_thresholds[stage]["name"]


## Age heir by 1 year
func age_heir(heir_name: String) -> Dictionary:
	if heir_name not in heir_ages:
		return {"success": false, "reason": "heir_not_found"}

	var old_age = heir_ages[heir_name]
	var new_age = old_age + 1

	heir_ages[heir_name] = new_age

	var old_stage = heir_life_stage[heir_name]
	var new_stage = get_heir_life_stage(heir_name)
	heir_life_stage[heir_name] = new_stage

	heir_aged.emit(heir_name, new_age)

	# Check for life stage transitions
	if old_stage != new_stage:
		if new_stage == AgeStage.ELDER:
			heir_entering_elderly.emit(heir_name, new_age)
		elif new_stage == AgeStage.ANCIENT:
			heir_death_imminent.emit(heir_name, new_age)

	return {
		"success": true,
		"age": new_age,
		"stage": new_stage,
		"stage_name": get_life_stage_name(new_stage),
	}


## Get stat penalties for heir age
func get_age_stat_penalties(heir_name: String) -> Dictionary:
	var stage = get_heir_life_stage(heir_name)
	return age_stat_penalties[stage].duplicate()


## Check if heir is ready to retire (too old)
func is_ready_to_retire(heir_name: String) -> bool:
	var age = get_heir_age(heir_name)
	return age >= 75


## Check if heir is near death
func is_near_death(heir_name: String) -> bool:
	var age = get_heir_age(heir_name)
	return age >= 90


## Check if heir is dead (guaranteed at 100+)
func is_dead(heir_name: String) -> bool:
	var age = get_heir_age(heir_name)
	return age >= 100


## Get death probability by age
func get_death_probability(heir_name: String) -> float:
	var age = get_heir_age(heir_name)

	if age < 75:
		return 0.0
	elif age < 80:
		return 0.05  # 5%
	elif age < 85:
		return 0.15  # 15%
	elif age < 90:
		return 0.30  # 30%
	elif age < 95:
		return 0.50  # 50%
	elif age < 100:
		return 0.75  # 75%
	else:
		return 1.0  # Guaranteed


## Retire heir (end active service)
func retire_heir(heir_name: String) -> Dictionary:
	var age = get_heir_age(heir_name)

	if age < 75:
		return {
			"success": false,
			"reason": "too_young_to_retire",
			"age": age,
		}

	heir_retired.emit(heir_name, age)

	return {
		"success": true,
		"retired_age": age,
	}


## Get heir lifespan summary
func get_lifespan_summary(heir_name: String) -> Dictionary:
	var age = get_heir_age(heir_name)
	var stage = get_heir_life_stage(heir_name)
	var penalties = get_age_stat_penalties(heir_name)
	var death_prob = get_death_probability(heir_name)

	return {
		"age": age,
		"stage": get_life_stage_name(stage),
		"stat_penalties": penalties,
		"can_retire": is_ready_to_retire(heir_name),
		"is_near_death": is_near_death(heir_name),
		"death_probability": death_prob,
		"is_guaranteed_dead": is_dead(heir_name),
	}


## Get years remaining (rough estimate)
func get_years_remaining(heir_name: String) -> int:
	var age = get_heir_age(heir_name)

	if age >= 100:
		return 0
	elif age >= 90:
		return randi_range(1, 5)
	elif age >= 80:
		return randi_range(5, 15)
	elif age >= 70:
		return randi_range(10, 20)
	else:
		return randi_range(20, 50)


## Get age milestone
func get_next_age_milestone(heir_name: String) -> int:
	var age = get_heir_age(heir_name)

	var milestones = [25, 50, 75, 100]
	for milestone in milestones:
		if age < milestone:
			return milestone

	return 100


## Calculate heir viability (0-1.0 scale, affects recruitment/marriage)
func calculate_heir_viability(heir_name: String) -> float:
	var age = get_heir_age(heir_name)

	if age < 18:
		return 0.0  # Too young
	elif age < 25:
		return 0.7  # Young, less experienced
	elif age < 50:
		return 1.0  # Peak years
	elif age < 65:
		return 0.9  # Still strong
	elif age < 75:
		return 0.7  # Aging
	else:
		return 0.3  # Very old, low viability


## Get heir description by age
func get_age_description(heir_name: String) -> String:
	var age = get_heir_age(heir_name)

	if age < 18:
		return "A young and inexperienced heir"
	elif age < 25:
		return "A youthful heir finding their way"
	elif age < 35:
		return "A capable heir in their prime"
	elif age < 50:
		return "A seasoned and experienced heir"
	elif age < 65:
		return "An aging heir with deep wisdom"
	elif age < 75:
		return "An elderly heir moving slowly"
	elif age < 90:
		return "An ancient heir, barely standing"
	else:
		return "A decrepit heir at death's door"
