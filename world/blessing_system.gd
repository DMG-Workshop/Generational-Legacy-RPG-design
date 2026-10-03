## Blessing System: Track blessings, stacking, and effects
##
## Manages active blessings on heirs, blessing stacking for compound effects,
## blessing sources (shrine, victory, event), and blessing inheritance

class_name BlessingSystem


signal blessing_granted(heir_name: String, blessing_type: String)
signal blessing_stacked(heir_name: String, blessing_type: String, stack_count: int)
signal blessing_expired(heir_name: String, blessing_type: String)
signal blessing_inherited(heir_name: String, blessing_type: String, from_heir: String)


enum BlessingType { VIGOR, CLARITY, FORTUNE, RESILIENCE, DIVINE_FAVOR }
enum BlessingSource { SHRINE, VICTORY, EVENT, RITUAL }

# Blessing definitions
var blessing_definitions: Dictionary = {
	BlessingType.VIGOR: {
		"name": "Vigor",
		"stat_bonus": {"strength": 2, "constitution": 2},
		"description": "Enhanced physical prowess",
		"base_duration": 5,
		"max_stacks": 3,
	},
	BlessingType.CLARITY: {
		"name": "Clarity",
		"stat_bonus": {"intelligence": 2, "wisdom": 2},
		"description": "Mind sharpened and focused",
		"base_duration": 5,
		"max_stacks": 3,
	},
	BlessingType.FORTUNE: {
		"name": "Fortune",
		"stat_bonus": {"charisma": 3},
		"description": "Luck follows this one",
		"base_duration": 4,
		"max_stacks": 2,
	},
	BlessingType.RESILIENCE: {
		"name": "Resilience",
		"stat_bonus": {"constitution": 3, "wisdom": 1},
		"description": "Hardened against adversity",
		"base_duration": 6,
		"max_stacks": 2,
	},
	BlessingType.DIVINE_FAVOR: {
		"name": "Divine Favor",
		"stat_bonus": {"strength": 1, "intelligence": 1, "wisdom": 3, "charisma": 2},
		"description": "Blessed by the divine",
		"base_duration": 8,
		"max_stacks": 1,
	},
}

# Active blessings per heir
var heir_blessings: Dictionary = {}  # heir_name -> {blessing_type -> {active: bool, duration: int, stacks: int, source: String}}


## Grant blessing to heir
func grant_blessing(heir_name: String, blessing_type: int, source: int = BlessingSource.SHRINE) -> Dictionary:
	if heir_name not in heir_blessings:
		heir_blessings[heir_name] = {}

	var blessing_name = blessing_definitions[blessing_type]["name"]
	var max_stacks = blessing_definitions[blessing_type]["max_stacks"]
	var duration = blessing_definitions[blessing_type]["base_duration"]

	if blessing_type in heir_blessings[heir_name]:
		# Stack blessing
		var blessing_data = heir_blessings[heir_name][blessing_type]
		if blessing_data["stacks"] < max_stacks:
			blessing_data["stacks"] += 1
			blessing_data["duration"] = duration  # Reset duration
			blessing_stacked.emit(heir_name, blessing_name, blessing_data["stacks"])
			return {
				"success": true,
				"blessing": blessing_name,
				"stacks": blessing_data["stacks"],
			}
		else:
			return {
				"success": false,
				"reason": "max_stacks_reached",
				"blessing": blessing_name,
			}

	# Grant new blessing
	heir_blessings[heir_name][blessing_type] = {
		"active": true,
		"duration": duration,
		"stacks": 1,
		"source": BlessingSource.keys()[source],
	}

	blessing_granted.emit(heir_name, blessing_name)

	return {
		"success": true,
		"blessing": blessing_name,
		"duration": duration,
		"stacks": 1,
	}


## Get active blessings on heir
func get_active_blessings(heir_name: String) -> Array[String]:
	if heir_name not in heir_blessings:
		return []

	var active = []
	for blessing_type in heir_blessings[heir_name].keys():
		if heir_blessings[heir_name][blessing_type]["active"]:
			active.append(blessing_definitions[blessing_type]["name"])

	return active


## Get blessing stat bonus
func get_blessing_stat_bonus(heir_name: String) -> Dictionary:
	var bonus = {
		"strength": 0,
		"dexterity": 0,
		"constitution": 0,
		"intelligence": 0,
		"wisdom": 0,
		"charisma": 0,
	}

	if heir_name not in heir_blessings:
		return bonus

	for blessing_type in heir_blessings[heir_name].keys():
		var blessing_data = heir_blessings[heir_name][blessing_type]
		if blessing_data["active"]:
			var blessing_def = blessing_definitions[blessing_type]
			var blessing_bonus = blessing_def["stat_bonus"]
			var stacks = blessing_data["stacks"]

			for stat_key in blessing_bonus.keys():
				bonus[stat_key] += blessing_bonus[stat_key] * stacks

	return bonus


## Get blessing stack count for specific blessing
func get_blessing_stacks(heir_name: String, blessing_type: int) -> int:
	if heir_name not in heir_blessings:
		return 0

	if blessing_type not in heir_blessings[heir_name]:
		return 0

	if not heir_blessings[heir_name][blessing_type]["active"]:
		return 0

	return heir_blessings[heir_name][blessing_type]["stacks"]


## Remove blessing from heir
func remove_blessing(heir_name: String, blessing_type: int) -> bool:
	if heir_name not in heir_blessings or blessing_type not in heir_blessings[heir_name]:
		return false

	heir_blessings[heir_name][blessing_type]["active"] = false
	blessing_expired.emit(heir_name, blessing_definitions[blessing_type]["name"])
	return true


## Tick blessing durations (called during age progression)
func tick_blessing_durations(heir_name: String) -> void:
	if heir_name not in heir_blessings:
		return

	for blessing_type in heir_blessings[heir_name].keys():
		if heir_blessings[heir_name][blessing_type]["active"]:
			heir_blessings[heir_name][blessing_type]["duration"] -= 1

			if heir_blessings[heir_name][blessing_type]["duration"] <= 0:
				remove_blessing(heir_name, blessing_type)


## Check if heir has specific blessing
func has_blessing(heir_name: String, blessing_type: int) -> bool:
	if heir_name not in heir_blessings:
		return false

	if blessing_type not in heir_blessings[heir_name]:
		return false

	return heir_blessings[heir_name][blessing_type]["active"]


## Get blessing summary
func get_blessing_summary(heir_name: String) -> Dictionary:
	var active = get_active_blessings(heir_name)
	var descriptions = []
	var total_bonus = get_blessing_stat_bonus(heir_name)

	for blessing_name in active:
		for blessing_type in blessing_definitions.keys():
			if blessing_definitions[blessing_type]["name"] == blessing_name:
				descriptions.append(blessing_definitions[blessing_type]["description"])

	return {
		"active_blessings": active,
		"count": active.size(),
		"stat_bonuses": total_bonus,
		"blessing_descriptions": descriptions,
	}


## Inherit blessings to next heir (reduced stacks)
func inherit_blessings(heir_name: String, previous_heir_name: String) -> int:
	if previous_heir_name not in heir_blessings:
		return 0

	var inherited_count = 0

	for blessing_type in heir_blessings[previous_heir_name].keys():
		var previous_blessing = heir_blessings[previous_heir_name][blessing_type]
		if previous_blessing["active"]:
			# Inherit at half stacks
			var inherited_stacks = maxi(1, int(previous_blessing["stacks"] * 0.5))

			if heir_name not in heir_blessings:
				heir_blessings[heir_name] = {}

			heir_blessings[heir_name][blessing_type] = {
				"active": true,
				"duration": blessing_definitions[blessing_type]["base_duration"],
				"stacks": inherited_stacks,
				"source": "inherited",
			}

			blessing_inherited.emit(heir_name, blessing_definitions[blessing_type]["name"], previous_heir_name)
			inherited_count += 1

	return inherited_count
