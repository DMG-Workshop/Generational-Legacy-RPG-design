## Corruption System: Track corruption progression and effects on heirs
##
## Manages corruption levels (0-100), degradation effects, corruption mutations,
## and corruption-triggered class changes

class_name CorruptionSystem


signal corruption_gained(heir_name: String, amount: int, new_level: int)
signal corruption_milestone_reached(heir_name: String, milestone: int)
signal corruption_effect_applied(heir_name: String, effect: String)
signal heir_corrupted(heir_name: String, corruption_level: int)


enum CorruptionMilestone { TAINTED = 25, CORRUPTED = 50, TRANSFORMED = 75, CONSUMED = 100 }

# Corruption levels per heir
var heir_corruption: Dictionary = {}  # heir_name -> corruption_level (0-100)

# Corruption effects database
var corruption_effects: Dictionary = {
	CorruptionMilestone.TAINTED: {
		"name": "Tainted",
		"stat_penalty": {"wisdom": -1, "charisma": -2},
		"effect_text": "Wisdom and Charisma reduced. Negative aura affects NPCs.",
	},
	CorruptionMilestone.CORRUPTED: {
		"name": "Corrupted",
		"stat_penalty": {"wisdom": -3, "charisma": -5, "constitution": -2},
		"effect_text": "Significant stat penalties. Dark thoughts plague the heir.",
	},
	CorruptionMilestone.TRANSFORMED: {
		"name": "Transformed",
		"stat_penalty": {"wisdom": -5, "charisma": -8, "constitution": -4},
		"effect_text": "Appearance shifts. Physical and mental degradation accelerated.",
	},
	CorruptionMilestone.CONSUMED: {
		"name": "Consumed",
		"stat_penalty": {"strength": -10, "dexterity": -10, "constitution": -10, "intelligence": -10, "wisdom": -10, "charisma": -10},
		"effect_text": "Heir is consumed by corruption. Barely recognizable.",
	},
}

# Active corruption effects per heir
var active_effects: Dictionary = {}  # heir_name -> [effect_names]


## Initialize corruption for heir
func _init() -> void:
	pass


## Get heir corruption level
func get_corruption_level(heir_name: String) -> int:
	return heir_corruption.get(heir_name, 0)


## Add corruption to heir
func add_corruption(heir_name: String, amount: int) -> int:
	if heir_name not in heir_corruption:
		heir_corruption[heir_name] = 0

	var old_level = heir_corruption[heir_name]
	heir_corruption[heir_name] = mini(heir_corruption[heir_name] + amount, 100)
	var new_level = heir_corruption[heir_name]

	corruption_gained.emit(heir_name, amount, new_level)

	# Check for milestone
	_check_corruption_milestone(heir_name, old_level, new_level)

	return new_level


## Remove corruption from heir
func remove_corruption(heir_name: String, amount: int) -> int:
	if heir_name not in heir_corruption:
		heir_corruption[heir_name] = 0

	heir_corruption[heir_name] = maxi(heir_corruption[heir_name] - amount, 0)
	return heir_corruption[heir_name]


## Get corruption stat penalties
func get_corruption_stat_penalty(heir_name: String) -> Dictionary:
	var corruption_level = get_corruption_level(heir_name)
	var penalty = {
		"strength": 0,
		"dexterity": 0,
		"constitution": 0,
		"intelligence": 0,
		"wisdom": 0,
		"charisma": 0,
	}

	if corruption_level >= CorruptionMilestone.TAINTED:
		_apply_milestone_penalty(penalty, CorruptionMilestone.TAINTED)

	if corruption_level >= CorruptionMilestone.CORRUPTED:
		_apply_milestone_penalty(penalty, CorruptionMilestone.CORRUPTED)

	if corruption_level >= CorruptionMilestone.TRANSFORMED:
		_apply_milestone_penalty(penalty, CorruptionMilestone.TRANSFORMED)

	if corruption_level >= CorruptionMilestone.CONSUMED:
		_apply_milestone_penalty(penalty, CorruptionMilestone.CONSUMED)

	return penalty


## Get corruption effects text
func get_corruption_effects(heir_name: String) -> Array[String]:
	var corruption_level = get_corruption_level(heir_name)
	var effects = []

	for milestone in corruption_effects.keys():
		if corruption_level >= milestone:
			effects.append(corruption_effects[milestone]["effect_text"])

	return effects


## Check if heir is fully corrupted
func is_fully_corrupted(heir_name: String) -> bool:
	return get_corruption_level(heir_name) >= CorruptionMilestone.CONSUMED


## Check if heir is corrupted (any level)
func is_corrupted(heir_name: String) -> bool:
	return get_corruption_level(heir_name) >= CorruptionMilestone.TAINTED


## Get corruption summary
func get_corruption_summary(heir_name: String) -> Dictionary:
	var corruption_level = get_corruption_level(heir_name)
	var stage = "Pure"

	if corruption_level >= CorruptionMilestone.CONSUMED:
		stage = "Consumed"
	elif corruption_level >= CorruptionMilestone.TRANSFORMED:
		stage = "Transformed"
	elif corruption_level >= CorruptionMilestone.CORRUPTED:
		stage = "Corrupted"
	elif corruption_level >= CorruptionMilestone.TAINTED:
		stage = "Tainted"

	return {
		"level": corruption_level,
		"stage": stage,
		"penalties": get_corruption_stat_penalty(heir_name),
		"effects": get_corruption_effects(heir_name),
		"is_corrupted": is_corrupted(heir_name),
	}


## Purge corruption (cleansing, rare event)
func purge_corruption(heir_name: String, amount: int = 100) -> int:
	return remove_corruption(heir_name, amount)


## Internal: Check corruption milestone reached
func _check_corruption_milestone(heir_name: String, old_level: int, new_level: int) -> void:
	for milestone in [CorruptionMilestone.TAINTED, CorruptionMilestone.CORRUPTED, CorruptionMilestone.TRANSFORMED, CorruptionMilestone.CONSUMED]:
		if old_level < milestone and new_level >= milestone:
			corruption_milestone_reached.emit(heir_name, milestone)
			heir_corrupted.emit(heir_name, new_level)


## Internal: Apply milestone penalty to penalty dict
func _apply_milestone_penalty(penalty: Dictionary, milestone: int) -> void:
	var milestone_penalty = corruption_effects[milestone]["stat_penalty"]
	for stat_key in milestone_penalty.keys():
		if stat_key in penalty:
			penalty[stat_key] += milestone_penalty[stat_key]


## Inherit corruption to next heir (reduced)
func inherit_corruption(heir_name: String, previous_heir_name: String, inheritance_multiplier: float = 0.3) -> int:
	if previous_heir_name not in heir_corruption:
		heir_corruption[heir_name] = 0
		return 0

	var previous_corruption = heir_corruption[previous_heir_name]
	var inherited_corruption = int(previous_corruption * inheritance_multiplier)

	heir_corruption[heir_name] = inherited_corruption

	if inherited_corruption > 0:
		corruption_gained.emit(heir_name, inherited_corruption, inherited_corruption)

	return inherited_corruption
