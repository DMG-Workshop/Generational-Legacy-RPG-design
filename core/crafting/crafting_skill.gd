## Crafting Skill: tracks proficiency in a craft
##
## Levels 1-100, XP-based progression, gains from crafting

class_name CraftingSkill


## Skill names
enum SkillType {
	BLACKSMITHING,
	ALCHEMY,
	LEATHERWORKING,
	CARPENTRY,
	ENCHANTING,
	COOKING,
	WEAVING,
	METALWORKING,
	STONEWORK,
	GLASSBLOWING
}

## Skill identifier
var skill_type: int = SkillType.BLACKSMITHING

## Display name
var skill_name: String = ""

## Current level (1-100)
var level: int = 1

## Current XP in this level
var current_xp: int = 0

## XP needed for next level
var xp_for_next_level: int = 100

## Total XP across all levels
var total_xp: int = 0

## Recipes unlocked at each level
var recipes_by_level: Dictionary = {}

## Items crafted with this skill
var items_crafted: int = 0


func _init(p_skill_type: int = SkillType.BLACKSMITHING) -> void:
	skill_type = p_skill_type
	skill_name = get_skill_name(p_skill_type)


## Get skill name
func get_skill_name(skill: int) -> String:
	match skill:
		SkillType.BLACKSMITHING:
			return "Blacksmithing"
		SkillType.ALCHEMY:
			return "Alchemy"
		SkillType.LEATHERWORKING:
			return "Leatherworking"
		SkillType.CARPENTRY:
			return "Carpentry"
		SkillType.ENCHANTING:
			return "Enchanting"
		SkillType.COOKING:
			return "Cooking"
		SkillType.WEAVING:
			return "Weaving"
		SkillType.METALWORKING:
			return "Metalworking"
		SkillType.STONEWORK:
			return "Stonework"
		SkillType.GLASSBLOWING:
			return "Glassblowing"
		_:
			return "Unknown"


## Add XP to skill
func add_xp(amount: int) -> Array[int]:  # Returns [levels_gained, new_level]
	current_xp += amount
	total_xp += amount

	var levels_gained = 0
	while current_xp >= xp_for_next_level and level < 100:
		current_xp -= xp_for_next_level
		level += 1
		levels_gained += 1
		# XP requirement increases slightly each level
		xp_for_next_level = int(100 * pow(1.05, level - 1))

	return [levels_gained, level]


## Get progress to next level (0.0 to 1.0)
func get_progress_to_next() -> float:
	return float(current_xp) / xp_for_next_level


## Get level progress string
func get_progress_string() -> String:
	return "%d/%d XP" % [current_xp, xp_for_next_level]


## Check if skill is maxed
func is_maxed() -> bool:
	return level >= 100


## Add recipe to skill
func unlock_recipe(recipe_id: String, required_level: int) -> void:
	if required_level not in recipes_by_level:
		recipes_by_level[required_level] = []
	if recipe_id not in recipes_by_level[required_level]:
		recipes_by_level[required_level].append(recipe_id)


## Get all unlocked recipes
func get_unlocked_recipes() -> Array[String]:
	var unlocked: Array[String] = []
	for req_level in recipes_by_level:
		if req_level <= level:
			unlocked.append_array(recipes_by_level[req_level])
	return unlocked


## String representation
func to_string() -> String:
	return "%s Level %d (%s)" % [skill_name, level, get_progress_string()]
