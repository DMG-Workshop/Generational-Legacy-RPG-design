## Generation Turnover System: Manage heir death, succession, and generation advancement
##
## Handles heir death events, succession to next heir, legacy transfer,
## and generation count progression

class_name GenerationTurnoverSystem


signal heir_death_triggered(heir_name: String, age: int, cause: String)
signal heir_succession_started(heir_name: String, previous_heir: String)
signal heir_succession_completed(heir_name: String, generation: int)
signal generation_advanced(new_generation: int)
signal legacy_transferred(from_heir: String, to_heir: String)
signal heir_skills_inherited(heir_name: String, previous_heir: String, skills_count: int)


# Succession tracking
var current_generation: int = 1
var current_heir: String = ""
var heir_history: Array = []  # Array of {heir_name, generation, age_at_death, cause}

# Generation-specific data
var generation_data: Dictionary = {
	# generation -> {heir_name, birth_tick, death_tick, age_at_death, legacy_value}
}


## Initialize first heir
func initialize_first_heir(heir_name: String) -> void:
	current_heir = heir_name
	current_generation = 1
	generation_data[1] = {
		"heir_name": heir_name,
		"birth_tick": 0,
		"death_tick": -1,
		"age_at_death": -1,
		"legacy_value": 0,
	}


## Get current generation
func get_current_generation() -> int:
	return current_generation


## Get current heir
func get_current_heir() -> String:
	return current_heir


## Trigger heir death
func trigger_heir_death(heir_name: String, age: int, cause: String = "old_age") -> Dictionary:
	if current_heir != heir_name:
		return {
			"success": false,
			"reason": "not_current_heir",
		}

	var death_tick = Time.get_ticks_msec()
	heir_history.append({
		"heir_name": heir_name,
		"generation": current_generation,
		"age_at_death": age,
		"cause": cause,
		"death_tick": death_tick,
	})

	if current_generation in generation_data:
		generation_data[current_generation]["death_tick"] = death_tick
		generation_data[current_generation]["age_at_death"] = age

	heir_death_triggered.emit(heir_name, age, cause)

	return {
		"success": true,
		"heir": heir_name,
		"age": age,
		"cause": cause,
		"generation_ended": current_generation,
	}


## Start succession to next heir
func start_succession(new_heir_name: String, previous_heir_name: String = "") -> Dictionary:
	if previous_heir_name == "":
		previous_heir_name = current_heir

	var next_generation = current_generation + 1

	current_heir = new_heir_name
	current_generation = next_generation

	generation_data[next_generation] = {
		"heir_name": new_heir_name,
		"birth_tick": Time.get_ticks_msec(),
		"death_tick": -1,
		"age_at_death": -1,
		"legacy_value": 0,
	}

	heir_succession_started.emit(new_heir_name, previous_heir_name)
	generation_advanced.emit(next_generation)

	return {
		"success": true,
		"new_heir": new_heir_name,
		"new_generation": next_generation,
		"previous_heir": previous_heir_name,
	}


## Complete succession (finalize inheritance)
func complete_succession(new_heir_name: String) -> Dictionary:
	if current_heir != new_heir_name:
		return {
			"success": false,
			"reason": "not_current_heir",
		}

	heir_succession_completed.emit(new_heir_name, current_generation)

	return {
		"success": true,
		"heir": new_heir_name,
		"generation": current_generation,
	}


## Transfer legacy to next heir
func transfer_legacy(new_heir_name: String, previous_heir_name: String, legacy_value: int) -> Dictionary:
	if current_heir != new_heir_name:
		return {
			"success": false,
			"reason": "not_current_heir",
		}

	if current_generation in generation_data:
		generation_data[current_generation]["legacy_value"] = legacy_value

	legacy_transferred.emit(previous_heir_name, new_heir_name)

	return {
		"success": true,
		"from_heir": previous_heir_name,
		"to_heir": new_heir_name,
		"legacy_value": legacy_value,
	}


## Record inherited skills
func record_skill_inheritance(new_heir_name: String, previous_heir_name: String, skills_count: int) -> void:
	heir_skills_inherited.emit(new_heir_name, previous_heir_name, skills_count)


## Get generation data
func get_generation_data(generation: int) -> Dictionary:
	return generation_data.get(generation, {}).duplicate()


## Get heir history
func get_heir_history() -> Array:
	return heir_history.duplicate()


## Get total generations elapsed
func get_total_generations() -> int:
	return current_generation


## Get heir count
func get_heir_count() -> int:
	return heir_history.size() + (1 if current_generation > 1 else 0)


## Calculate generation score (summary of heir achievements)
func calculate_generation_score(generation: int) -> int:
	if generation not in generation_data:
		return 0

	var gen_data = generation_data[generation]
	var score = 0

	# Age bonus (longer life = more time to achieve)
	score += gen_data.get("age_at_death", 30) * 2

	# Legacy value bonus
	score += gen_data.get("legacy_value", 0)

	return score


## Get legacy chain (sum of all generation scores)
func get_legacy_chain_total() -> int:
	var total = 0
	for generation in generation_data.keys():
		total += calculate_generation_score(generation)
	return total


## Get heir succession summary
func get_succession_summary(heir_name: String) -> Dictionary:
	for heir_record in heir_history:
		if heir_record["heir_name"] == heir_name:
			return heir_record.duplicate()

	# If not in history, it's the current heir
	return {
		"heir_name": heir_name,
		"generation": current_generation,
		"age_at_death": -1,
		"cause": "still_alive",
		"death_tick": -1,
	}


## Get generation timeline
func get_generation_timeline() -> Array:
	var timeline = []
	for generation in range(1, current_generation + 1):
		if generation in generation_data:
			timeline.append({
				"generation": generation,
				"data": generation_data[generation].duplicate(),
				"score": calculate_generation_score(generation),
			})
	return timeline


## Check if succession is needed (current heir is dead)
func is_succession_needed() -> bool:
	# This would be checked by external system
	# when heir reaches guaranteed death age
	return false


## Get heir lineage as string
func get_heir_lineage() -> String:
	var lineage = []

	for heir_record in heir_history:
		lineage.append(heir_record["heir_name"])

	lineage.append(current_heir + " (current)")

	return " → ".join(lineage)


## Calculate total family age (sum of all heir ages)
func calculate_total_family_age() -> int:
	var total = 0

	for heir_record in heir_history:
		total += heir_record.get("age_at_death", 0)

	return total


## Get average heir lifespan
func get_average_lifespan() -> float:
	if heir_history.is_empty():
		return 0.0

	var total_age = calculate_total_family_age()
	return float(total_age) / float(heir_history.size())


## Get longest-lived heir
func get_longest_lived_heir() -> Dictionary:
	if heir_history.is_empty():
		return {}

	var longest = heir_history[0]
	for heir_record in heir_history:
		if heir_record.get("age_at_death", 0) > longest.get("age_at_death", 0):
			longest = heir_record

	return longest.duplicate()


## Get generation with highest score
func get_greatest_generation() -> int:
	var greatest_gen = 1
	var greatest_score = 0

	for generation in generation_data.keys():
		var score = calculate_generation_score(generation)
		if score > greatest_score:
			greatest_score = score
			greatest_gen = generation

	return greatest_gen
