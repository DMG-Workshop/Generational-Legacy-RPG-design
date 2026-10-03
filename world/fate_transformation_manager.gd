## Fate Transformation Manager: Orchestrates corruption, curses, blessings, and class evolution
##
## Integrates all transformation systems and applies Fate-driven progression

class_name FateTransformationManager


signal heir_transformation_triggered(heir_name: String, transformation_type: String)
signal heir_redemption_available(heir_name: String)
signal heir_ascension_triggered(heir_name: String)
signal transformation_state_changed(heir_name: String, new_state: String)


var corruption_system: CorruptionSystem
var curse_system: CurseSystem
var blessing_system: BlessingSystem
var class_evolution_system: ClassEvolutionSystem

# Transformation tracking per heir
var heir_transformations: Dictionary = {}  # heir_name -> {state, last_event, corruption_level, curse_count, blessing_count}


func _init(corruption: CorruptionSystem, curses: CurseSystem, blessings: BlessingSystem, evolution: ClassEvolutionSystem) -> void:
	corruption_system = corruption
	curse_system = curses
	blessing_system = blessings
	class_evolution_system = evolution


## Initialize transformation state for heir
func initialize_heir_transformation(heir_name: String) -> void:
	heir_transformations[heir_name] = {
		"state": "pure",
		"last_event": "",
		"corruption_level": 0,
		"curse_count": 0,
		"blessing_count": 0,
	}


## Get heir transformation state
func get_heir_transformation_state(heir_name: String) -> Dictionary:
	if heir_name not in heir_transformations:
		initialize_heir_transformation(heir_name)

	var corruption_level = corruption_system.get_corruption_level(heir_name)
	var curses = curse_system.get_active_curses(heir_name)
	var blessings = blessing_system.get_active_blessings(heir_name)
	var state = _determine_transformation_state(heir_name, corruption_level, curses.size(), blessings.size())

	heir_transformations[heir_name]["state"] = state
	heir_transformations[heir_name]["corruption_level"] = corruption_level
	heir_transformations[heir_name]["curse_count"] = curses.size()
	heir_transformations[heir_name]["blessing_count"] = blessings.size()

	return heir_transformations[heir_name].duplicate()


## Apply encounter corruption (enemy defeat = risk)
func apply_encounter_corruption(heir_name: String, encounter_difficulty: int) -> int:
	var corruption_risk = 0

	match encounter_difficulty:
		0:  # Easy
			corruption_risk = randi_range(0, 5)
		1:  # Normal
			corruption_risk = randi_range(2, 8)
		2:  # Hard
			corruption_risk = randi_range(5, 15)
		3:  # Epic
			corruption_risk = randi_range(10, 25)
		4:  # Legendary
			corruption_risk = randi_range(15, 35)

	if corruption_risk > 0:
		corruption_system.add_corruption(heir_name, corruption_risk)
		heir_transformation_triggered.emit(heir_name, "corruption_gained")

	return corruption_risk


## Apply encounter curse (dark forces at work)
func apply_encounter_curse(heir_name: String, encounter_type: String) -> bool:
	var curse_type = _get_curse_from_encounter(encounter_type)
	if curse_type == -1:
		return false

	curse_system.apply_curse(heir_name, curse_type)
	heir_transformation_triggered.emit(heir_name, "curse_applied")
	return true


## Apply shrine blessing (purification and grace)
func apply_shrine_blessing(heir_name: String, blessing_type: int = BlessingSystem.BlessingType.DIVINE_FAVOR) -> Dictionary:
	var result = blessing_system.grant_blessing(heir_name, blessing_type, BlessingSystem.BlessingSource.SHRINE)

	if result.get("success", false):
		# Shrine blessing also reduces corruption
		var corruption_reduction = 10
		corruption_system.remove_corruption(heir_name, corruption_reduction)
		heir_transformation_triggered.emit(heir_name, "shrine_blessing")

	return result


## Apply victory blessing (triumph grants favor)
func apply_victory_blessing(heir_name: String) -> Dictionary:
	var blessing_type = randi() % BlessingSystem.BlessingType.size()
	return blessing_system.grant_blessing(heir_name, blessing_type, BlessingSystem.BlessingSource.VICTORY)


## Check for class evolution opportunity (Fate milestone)
func check_evolution_opportunity(heir_name: String, heir_fate_value: int) -> Array[String]:
	var available = class_evolution_system.get_available_evolutions(heir_name)
	var possible = []

	for advanced_class in available:
		var requirements = class_evolution_system.get_evolution_requirements(advanced_class)
		if heir_fate_value >= requirements["fate_requirement"]:
			possible.append(advanced_class)

	if possible.size() > 0:
		heir_ascension_triggered.emit(heir_name)

	return possible


## Trigger class evolution
func trigger_class_evolution(heir_name: String, target_class: String, heir_fate_value: int) -> Dictionary:
	var result = class_evolution_system.evolve_class(heir_name, target_class, heir_fate_value)

	if result.get("success", false):
		# Evolution reduces corruption significantly
		corruption_system.remove_corruption(heir_name, 30)
		transformation_state_changed.emit(heir_name, "evolved_to_%s" % target_class)

	return result


## Get combined stat modifiers (corruption, curses, blessings, class)
func get_combined_stat_modifiers(heir_name: String) -> Dictionary:
	var modifiers = {
		"strength": 0,
		"dexterity": 0,
		"constitution": 0,
		"intelligence": 0,
		"wisdom": 0,
		"charisma": 0,
	}

	# Apply corruption penalties
	var corruption_penalty = corruption_system.get_corruption_stat_penalty(heir_name)
	for stat_key in corruption_penalty.keys():
		modifiers[stat_key] += corruption_penalty[stat_key]

	# Apply curse penalties
	var curse_penalty = curse_system.get_curse_stat_penalty(heir_name)
	for stat_key in curse_penalty.keys():
		modifiers[stat_key] += curse_penalty[stat_key]

	# Apply blessing bonuses
	var blessing_bonus = blessing_system.get_blessing_stat_bonus(heir_name)
	for stat_key in blessing_bonus.keys():
		modifiers[stat_key] += blessing_bonus[stat_key]

	# Apply class bonuses
	var current_class = class_evolution_system.get_heir_advanced_class(heir_name)
	if current_class == "":
		current_class = class_evolution_system.get_heir_class(heir_name)

	var class_stats = class_evolution_system.get_class_stats(current_class)
	for stat_key in class_stats.keys():
		modifiers[stat_key] += class_stats[stat_key]

	return modifiers


## Get full transformation summary
func get_transformation_summary(heir_name: String) -> Dictionary:
	var state = get_heir_transformation_state(heir_name)
	var corruption_data = corruption_system.get_corruption_summary(heir_name)
	var curse_data = curse_system.get_curse_summary(heir_name)
	var blessing_data = blessing_system.get_blessing_summary(heir_name)
	var class_data = class_evolution_system.get_class_summary(heir_name)

	return {
		"state": state["state"],
		"corruption": corruption_data,
		"curses": curse_data,
		"blessings": blessing_data,
		"class": class_data,
		"stat_modifiers": get_combined_stat_modifiers(heir_name),
	}


## Redemption event (cleanse corruption and curses)
func trigger_redemption(heir_name: String) -> Dictionary:
	var curses_cleansed = curse_system.cleanse_curses(heir_name)
	var corruption_purged = corruption_system.purge_corruption(heir_name, 50)

	# Grant blessing for redemption
	blessing_system.grant_blessing(heir_name, BlessingSystem.BlessingType.CLARITY, BlessingSystem.BlessingSource.RITUAL)

	heir_redemption_available.emit(heir_name)
	transformation_state_changed.emit(heir_name, "redeemed")

	return {
		"success": true,
		"curses_removed": curses_cleansed,
		"corruption_reduced": corruption_purged,
	}


## Age tick (progress curse/blessing durations, check corruption effects)
func tick_heir_age(heir_name: String) -> void:
	curse_system.tick_curse_durations(heir_name)
	blessing_system.tick_blessing_durations(heir_name)


## Inherit transformations to next heir (reduced)
func inherit_transformations(heir_name: String, previous_heir_name: String) -> Dictionary:
	var inherited = {
		"corruption_inherited": 0,
		"curses_chained": 0,
		"blessings_inherited": 0,
	}

	# Inherit corruption (30% of previous)
	var corruption_level = corruption_system.get_corruption_level(previous_heir_name)
	if corruption_level > 0:
		inherited["corruption_inherited"] = corruption_system.inherit_corruption(heir_name, previous_heir_name)

	# Chain curses
	for curse_type in range(CurseSystem.CurseType.size()):
		if curse_system.has_curse(previous_heir_name, curse_type):
			if curse_system.chain_curse_to_heir(heir_name, previous_heir_name, curse_type):
				inherited["curses_chained"] += 1

	# Inherit blessings (50% stacks)
	inherited["blessings_inherited"] = blessing_system.inherit_blessings(heir_name, previous_heir_name)

	return inherited


## Internal: Determine transformation state
func _determine_transformation_state(heir_name: String, corruption_level: int, curse_count: int, blessing_count: int) -> String:
	if corruption_level >= CorruptionSystem.CorruptionMilestone.CONSUMED:
		return "consumed"
	elif corruption_level >= CorruptionSystem.CorruptionMilestone.TRANSFORMED and curse_count >= 3:
		return "cursed_transformed"
	elif corruption_level >= CorruptionSystem.CorruptionMilestone.CORRUPTED:
		return "corrupted"
	elif curse_count >= 2:
		return "cursed"
	elif blessing_count >= 3:
		return "blessed"
	elif corruption_level >= CorruptionSystem.CorruptionMilestone.TAINTED:
		return "tainted"
	else:
		return "pure"


## Internal: Get curse type from encounter
func _get_curse_from_encounter(encounter_type: String) -> int:
	match encounter_type:
		"bandits":
			return CurseSystem.CurseType.WEAKNESS
		"undead":
			return CurseSystem.CurseType.VOID_MARK
		"cult":
			return CurseSystem.CurseType.MADNESS
		"boss":
			return CurseSystem.CurseType.FRAILTY
		_:
			return -1
