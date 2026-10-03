## Curse System: Track curse application, mutation, and chaining
##
## Manages active curses on heirs, curse mutations through generations,
## curse chaining effects, and curse removal

class_name CurseSystem


signal curse_applied(heir_name: String, curse_type: String)
signal curse_mutated(heir_name: String, curse_type: String, mutation_type: String)
signal curse_chained(heir_name: String, from_heir: String, curse_type: String)
signal curse_removed(heir_name: String, curse_type: String)


enum CurseType { WEAKNESS, FRAILTY, MISFORTUNE, MADNESS, VOID_MARK }

# Curse definitions
var curse_definitions: Dictionary = {
	CurseType.WEAKNESS: {
		"name": "Weakness",
		"stat_penalty": {"strength": -3, "dexterity": -2},
		"description": "Muscles feel weak and sluggish",
		"base_duration": 3,
	},
	CurseType.FRAILTY: {
		"name": "Frailty",
		"stat_penalty": {"constitution": -4, "wisdom": -1},
		"description": "Body is fragile and vulnerable",
		"base_duration": 3,
	},
	CurseType.MISFORTUNE: {
		"name": "Misfortune",
		"stat_penalty": {"charisma": -3, "intelligence": -2},
		"description": "Luck abandons the cursed",
		"base_duration": 4,
	},
	CurseType.MADNESS: {
		"name": "Madness",
		"stat_penalty": {"intelligence": -4, "wisdom": -4, "charisma": -2},
		"description": "Sanity slips away",
		"base_duration": 5,
	},
	CurseType.VOID_MARK: {
		"name": "Void Mark",
		"stat_penalty": {"strength": -2, "dexterity": -2, "constitution": -2, "intelligence": -2, "wisdom": -2, "charisma": -2},
		"description": "Marked by the void, weakened across all aspects",
		"base_duration": 6,
	},
}

# Curse mutations that can occur
var curse_mutations: Dictionary = {
	"amplify": {
		"name": "Amplified",
		"multiplier": 1.5,
		"description": "Curse effects intensify",
	},
	"spread": {
		"name": "Spreading",
		"multiplier": 1.0,
		"description": "Curse spreads to family members",
	},
	"chain": {
		"name": "Chained",
		"multiplier": 1.2,
		"description": "Curse links to next heir",
	},
	"corrupt": {
		"name": "Corrupting",
		"multiplier": 2.0,
		"description": "Curse accelerates corruption",
	},
}

# Active curses per heir
var heir_curses: Dictionary = {}  # heir_name -> {curse_type -> {active: bool, duration: int, mutation: String}}


## Apply curse to heir
func apply_curse(heir_name: String, curse_type: int) -> Dictionary:
	if heir_name not in heir_curses:
		heir_curses[heir_name] = {}

	var curse_name = curse_definitions[curse_type]["name"]
	var duration = curse_definitions[curse_type]["base_duration"]

	heir_curses[heir_name][curse_type] = {
		"active": true,
		"duration": duration,
		"mutation": "",
		"original_curse": curse_type,
	}

	curse_applied.emit(heir_name, curse_name)

	return {
		"success": true,
		"curse": curse_name,
		"duration": duration,
	}


## Get active curses on heir
func get_active_curses(heir_name: String) -> Array[String]:
	if heir_name not in heir_curses:
		return []

	var active = []
	for curse_type in heir_curses[heir_name].keys():
		if heir_curses[heir_name][curse_type]["active"]:
			active.append(curse_definitions[curse_type]["name"])

	return active


## Get curse stat penalty
func get_curse_stat_penalty(heir_name: String) -> Dictionary:
	var penalty = {
		"strength": 0,
		"dexterity": 0,
		"constitution": 0,
		"intelligence": 0,
		"wisdom": 0,
		"charisma": 0,
	}

	if heir_name not in heir_curses:
		return penalty

	for curse_type in heir_curses[heir_name].keys():
		var curse_data = heir_curses[heir_name][curse_type]
		if curse_data["active"]:
			var curse_def = curse_definitions[curse_type]
			var curse_penalty = curse_def["stat_penalty"]

			# Apply mutation multiplier if applicable
			var multiplier = 1.0
			if curse_data["mutation"] != "":
				multiplier = curse_mutations[curse_data["mutation"]]["multiplier"]

			for stat_key in curse_penalty.keys():
				penalty[stat_key] += int(curse_penalty[stat_key] * multiplier)

	return penalty


## Mutate curse (transforms curse effect)
func mutate_curse(heir_name: String, curse_type: int, mutation_type: String) -> Dictionary:
	if heir_name not in heir_curses or curse_type not in heir_curses[heir_name]:
		return {"success": false, "reason": "curse_not_active"}

	if mutation_type not in curse_mutations:
		return {"success": false, "reason": "invalid_mutation"}

	heir_curses[heir_name][curse_type]["mutation"] = mutation_type

	curse_mutated.emit(heir_name, curse_definitions[curse_type]["name"], curse_mutations[mutation_type]["name"])

	return {
		"success": true,
		"curse": curse_definitions[curse_type]["name"],
		"mutation": curse_mutations[mutation_type]["name"],
	}


## Chain curse to next heir
func chain_curse_to_heir(new_heir_name: String, previous_heir_name: String, curse_type: int) -> bool:
	if previous_heir_name not in heir_curses or curse_type not in heir_curses[previous_heir_name]:
		return false

	var previous_curse = heir_curses[previous_heir_name][curse_type]
	if not previous_curse["active"]:
		return false

	# Apply chained curse (reduced duration)
	if new_heir_name not in heir_curses:
		heir_curses[new_heir_name] = {}

	var chained_duration = maxi(previous_curse["duration"] - 1, 1)
	heir_curses[new_heir_name][curse_type] = {
		"active": true,
		"duration": chained_duration,
		"mutation": "chain",
		"original_curse": curse_type,
	}

	curse_chained.emit(new_heir_name, previous_heir_name, curse_definitions[curse_type]["name"])
	return true


## Remove curse from heir
func remove_curse(heir_name: String, curse_type: int) -> bool:
	if heir_name not in heir_curses or curse_type not in heir_curses[heir_name]:
		return false

	heir_curses[heir_name][curse_type]["active"] = false
	curse_removed.emit(heir_name, curse_definitions[curse_type]["name"])
	return true


## Decrease curse duration (called during age progression)
func tick_curse_durations(heir_name: String) -> void:
	if heir_name not in heir_curses:
		return

	for curse_type in heir_curses[heir_name].keys():
		if heir_curses[heir_name][curse_type]["active"]:
			heir_curses[heir_name][curse_type]["duration"] -= 1

			if heir_curses[heir_name][curse_type]["duration"] <= 0:
				remove_curse(heir_name, curse_type)


## Check if heir has specific curse
func has_curse(heir_name: String, curse_type: int) -> bool:
	if heir_name not in heir_curses:
		return false

	if curse_type not in heir_curses[heir_name]:
		return false

	return heir_curses[heir_name][curse_type]["active"]


## Get curse summary
func get_curse_summary(heir_name: String) -> Dictionary:
	var active = get_active_curses(heir_name)
	var descriptions = []

	for curse_name in active:
		for curse_type in curse_definitions.keys():
			if curse_definitions[curse_type]["name"] == curse_name:
				descriptions.append(curse_definitions[curse_type]["description"])

	return {
		"active_curses": active,
		"count": active.size(),
		"stat_penalties": get_curse_stat_penalty(heir_name),
		"curse_descriptions": descriptions,
	}


## Cleanse all curses (rare event)
func cleanse_curses(heir_name: String) -> int:
	if heir_name not in heir_curses:
		return 0

	var count = 0
	for curse_type in heir_curses[heir_name].keys():
		if heir_curses[heir_name][curse_type]["active"]:
			remove_curse(heir_name, curse_type)
			count += 1

	return count
