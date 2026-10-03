## Class Evolution System: Fate-triggered class transformations and advancement
##
## Manages class evolution (transformation to advanced forms based on Fate),
## class respec mechanics, evolution prerequisites, and stat scaling

class_name ClassEvolutionSystem


signal class_evolved(heir_name: String, from_class: String, to_class: String)
signal class_respawned(heir_name: String, class_name: String)
signal evolution_prerequisites_met(heir_name: String, evolution_path: String)


# Base classes that can evolve
var base_classes: Dictionary = {
	"Warrior": {
		"base_stats": {"strength": 3, "constitution": 2, "dexterity": 1},
		"evolutions": ["Berserker", "Paladin", "Void Knight"],
	},
	"Rogue": {
		"base_stats": {"dexterity": 3, "intelligence": 2, "charisma": 1},
		"evolutions": ["Assassin", "Shadow Master", "Trickster"],
	},
	"Mage": {
		"base_stats": {"intelligence": 3, "wisdom": 2, "charisma": 1},
		"evolutions": ["Sorcerer", "Sage", "Arcanist"],
	},
	"Priest": {
		"base_stats": {"wisdom": 3, "charisma": 2, "constitution": 1},
		"evolutions": ["Cleric", "Holy Knight", "Prophet"],
	},
}

# Advanced classes (evolution targets)
var advanced_classes: Dictionary = {
	# Warrior evolutions
	"Berserker": {
		"base_class": "Warrior",
		"base_stats": {"strength": 5, "constitution": 3, "dexterity": 1, "charisma": -2},
		"fate_requirement": 100,
		"description": "Unbridled fury unleashed",
		"special_trait": "battle_fury",
	},
	"Paladin": {
		"base_class": "Warrior",
		"base_stats": {"strength": 4, "constitution": 3, "wisdom": 2, "charisma": 1},
		"fate_requirement": 80,
		"description": "Divine warrior blessed by the heavens",
		"special_trait": "divine_protection",
	},
	"Void Knight": {
		"base_class": "Warrior",
		"base_stats": {"strength": 4, "constitution": 4, "intelligence": 2, "wisdom": -2},
		"fate_requirement": 120,
		"description": "Corrupted warrior channeling void power",
		"special_trait": "void_armament",
	},
	# Rogue evolutions
	"Assassin": {
		"base_class": "Rogue",
		"base_stats": {"dexterity": 5, "intelligence": 2, "strength": -1, "wisdom": -2},
		"fate_requirement": 100,
		"description": "Master of death from the shadows",
		"special_trait": "instant_kill",
	},
	"Shadow Master": {
		"base_class": "Rogue",
		"base_stats": {"dexterity": 4, "intelligence": 3, "charisma": 1, "wisdom": -1},
		"fate_requirement": 90,
		"description": "One with shadow and illusion",
		"special_trait": "shadow_clone",
	},
	"Trickster": {
		"base_class": "Rogue",
		"base_stats": {"dexterity": 4, "intelligence": 3, "charisma": 3, "strength": -1},
		"fate_requirement": 75,
		"description": "Master of deception and wit",
		"special_trait": "lucky_dodge",
	},
	# Mage evolutions
	"Sorcerer": {
		"base_class": "Mage",
		"base_stats": {"intelligence": 5, "charisma": 2, "wisdom": -1, "constitution": -2},
		"fate_requirement": 110,
		"description": "Raw magical power unleashed",
		"special_trait": "spell_amplification",
	},
	"Sage": {
		"base_class": "Mage",
		"base_stats": {"intelligence": 4, "wisdom": 4, "charisma": 1, "strength": -1},
		"fate_requirement": 85,
		"description": "Wise seeker of arcane knowledge",
		"special_trait": "mana_efficiency",
	},
	"Arcanist": {
		"base_class": "Mage",
		"base_stats": {"intelligence": 5, "wisdom": 2, "charisma": 2, "constitution": -2},
		"fate_requirement": 100,
		"description": "Keeper of forbidden secrets",
		"special_trait": "arcane_mastery",
	},
	# Priest evolutions
	"Cleric": {
		"base_class": "Priest",
		"base_stats": {"wisdom": 4, "charisma": 3, "constitution": 2, "strength": -1},
		"fate_requirement": 80,
		"description": "Devoted servant of divinity",
		"special_trait": "healing_grace",
	},
	"Holy Knight": {
		"base_class": "Priest",
		"base_stats": {"wisdom": 3, "charisma": 3, "constitution": 3, "strength": 2},
		"fate_requirement": 100,
		"description": "Divine warrior and protector",
		"special_trait": "holy_wrath",
	},
	"Prophet": {
		"base_class": "Priest",
		"base_stats": {"wisdom": 5, "charisma": 3, "intelligence": 2, "dexterity": -2},
		"fate_requirement": 120,
		"description": "Visionary channeling divine will",
		"special_trait": "prophecy",
	},
}

# Current classes per heir
var heir_current_class: Dictionary = {}  # heir_name -> current_class
var heir_advanced_class: Dictionary = {}  # heir_name -> advanced_class (if evolved)

# Track evolution eligibility
var heir_evolution_data: Dictionary = {}  # heir_name -> {base_class, evolved_to, evolution_count}


## Initialize heir with base class
func initialize_heir_class(heir_name: String, base_class: String) -> bool:
	if base_class not in base_classes:
		return false

	heir_current_class[heir_name] = base_class
	heir_evolution_data[heir_name] = {
		"base_class": base_class,
		"evolved_to": "",
		"evolution_count": 0,
	}
	return true


## Get heir current class
func get_heir_class(heir_name: String) -> String:
	return heir_current_class.get(heir_name, "")


## Get heir advanced class (if evolved)
func get_heir_advanced_class(heir_name: String) -> String:
	return heir_advanced_class.get(heir_name, "")


## Get class stat bonuses
func get_class_stats(class_name: String) -> Dictionary:
	if class_name in base_classes:
		return base_classes[class_name]["base_stats"].duplicate()
	elif class_name in advanced_classes:
		return advanced_classes[class_name]["base_stats"].duplicate()
	return {}


## Check if evolution is available
func can_evolve(heir_name: String, target_advanced_class: String) -> Dictionary:
	var current_class = get_heir_class(heir_name)

	if target_advanced_class not in advanced_classes:
		return {"can_evolve": false, "reason": "invalid_class"}

	var advanced_class_def = advanced_classes[target_advanced_class]
	if advanced_class_def["base_class"] != current_class:
		return {"can_evolve": false, "reason": "wrong_base_class"}

	if heir_advanced_class.get(heir_name, "") != "":
		return {"can_evolve": false, "reason": "already_evolved"}

	return {
		"can_evolve": true,
		"fate_requirement": advanced_class_def["fate_requirement"],
	}


## Evolve heir to advanced class (requires Fate check)
func evolve_class(heir_name: String, target_advanced_class: String, heir_fate_value: int) -> Dictionary:
	var evolution_check = can_evolve(heir_name, target_advanced_class)

	if not evolution_check["can_evolve"]:
		return {
			"success": false,
			"reason": evolution_check["reason"],
		}

	var advanced_class_def = advanced_classes[target_advanced_class]
	var required_fate = advanced_class_def["fate_requirement"]

	if heir_fate_value < required_fate:
		return {
			"success": false,
			"reason": "insufficient_fate",
			"required": required_fate,
			"current": heir_fate_value,
		}

	var current_class = get_heir_class(heir_name)
	heir_advanced_class[heir_name] = target_advanced_class
	heir_evolution_data[heir_name]["evolved_to"] = target_advanced_class
	heir_evolution_data[heir_name]["evolution_count"] += 1

	class_evolved.emit(heir_name, current_class, target_advanced_class)

	return {
		"success": true,
		"evolved_to": target_advanced_class,
		"special_trait": advanced_class_def["special_trait"],
	}


## Get available evolutions for heir
func get_available_evolutions(heir_name: String) -> Array[String]:
	var current_class = get_heir_class(heir_name)

	if current_class not in base_classes:
		return []

	if heir_advanced_class.get(heir_name, "") != "":
		return []  # Already evolved

	var evolutions = base_classes[current_class]["evolutions"]
	return evolutions


## Get evolution requirements for class
func get_evolution_requirements(target_advanced_class: String) -> Dictionary:
	if target_advanced_class not in advanced_classes:
		return {}

	var class_def = advanced_classes[target_advanced_class]
	return {
		"base_class": class_def["base_class"],
		"fate_requirement": class_def["fate_requirement"],
		"description": class_def["description"],
		"special_trait": class_def["special_trait"],
	}


## Respec class (returns to base class)
func respec_class(heir_name: String) -> Dictionary:
	var current_class = get_heir_class(heir_name)
	var advanced_class = get_heir_advanced_class(heir_name)

	if advanced_class == "":
		return {
			"success": false,
			"reason": "not_evolved",
		}

	heir_advanced_class[heir_name] = ""
	heir_evolution_data[heir_name]["evolved_to"] = ""

	class_respawned.emit(heir_name, current_class)

	return {
		"success": true,
		"reset_to": current_class,
	}


## Get class summary
func get_class_summary(heir_name: String) -> Dictionary:
	var base_class = get_heir_class(heir_name)
	var advanced_class = get_heir_advanced_class(heir_name)
	var available_evolutions = get_available_evolutions(heir_name)

	var description = "Base class"
	if advanced_class != "":
		description = advanced_classes[advanced_class]["description"]

	return {
		"base_class": base_class,
		"advanced_class": advanced_class,
		"is_evolved": advanced_class != "",
		"description": description,
		"available_evolutions": available_evolutions,
		"stats": get_class_stats(advanced_class if advanced_class != "" else base_class),
	}


## Get evolution path for base class
func get_evolution_paths(base_class: String) -> Array[Dictionary]:
	if base_class not in base_classes:
		return []

	var evolution_list = base_classes[base_class]["evolutions"]
	var paths = []

	for advanced_class in evolution_list:
		var req = get_evolution_requirements(advanced_class)
		paths.append({
			"class": advanced_class,
			"requirements": req,
		})

	return paths


## Inherit class to next heir
func inherit_class(heir_name: String, previous_heir_name: String) -> String:
	var previous_class = get_heir_class(previous_heir_name)

	if previous_class == "":
		return ""

	initialize_heir_class(heir_name, previous_class)
	return previous_class


## Get total evolution count
func get_evolution_count(heir_name: String) -> int:
	if heir_name not in heir_evolution_data:
		return 0
	return heir_evolution_data[heir_name]["evolution_count"]
