## Recipe: crafting recipe definition
##
## Ingredients, output, skill requirements, time to craft

class_name Recipe


## Recipe identifier
var recipe_id: String = ""

## Output item
var output_item_id: String = ""

## Quantity produced
var output_quantity: int = 1

## Required crafting skill type
var required_skill: int = CraftingSkill.SkillType.BLACKSMITHING

## Required skill level (1-100)
var required_skill_level: int = 1

## Time to craft in hours
var crafting_time_hours: int = 1

## Ingredients: Array of {material_id, quantity}
var ingredients: Array[Dictionary] = []

## Difficulty rating (1-5)
var difficulty: int = 1

## XP reward for crafting
var xp_reward: int = 50

## Description
var description: String = ""

## Whether this recipe is discovered or needs to be found
var is_discovered: bool = true


func _init(
	p_id: String = "",
	p_output: String = "",
	p_skill: int = CraftingSkill.SkillType.BLACKSMITHING,
	p_level: int = 1
) -> void:
	recipe_id = p_id
	output_item_id = p_output
	required_skill = p_skill
	required_skill_level = p_level


## Add ingredient requirement
func add_ingredient(material_id: String, quantity: int) -> void:
	ingredients.append({"material_id": material_id, "quantity": quantity})


## Check if player can craft this recipe
func can_craft(skill: CraftingSkill, inventory: Dictionary) -> bool:
	# Check skill level
	if skill.level < required_skill_level:
		return false

	# Check all ingredients available
	for ingredient in ingredients:
		var needed = ingredient["quantity"]
		var have = inventory.get(ingredient["material_id"], 0)
		if have < needed:
			return false

	return true


## Get required ingredients string
func get_ingredients_string() -> String:
	var str = ""
	for ing in ingredients:
		str += "%s ×%d\n" % [ing["material_id"], ing["quantity"]]
	return str.trim_suffix("\n")


## Get difficulty name
func get_difficulty_name() -> String:
	match difficulty:
		1:
			return "Trivial"
		2:
			return "Easy"
		3:
			return "Normal"
		4:
			return "Hard"
		5:
			return "Expert"
		_:
			return "Unknown"


## Get time estimate string
func get_time_string() -> String:
	if crafting_time_hours < 1:
		return "< 1 hour"
	elif crafting_time_hours == 1:
		return "1 hour"
	else:
		return "%d hours" % crafting_time_hours


## To string representation
func to_string() -> String:
	return "%s → %s [%s, Lvl %d]" % [
		get_ingredients_string().split("\n")[0],
		output_item_id,
		get_difficulty_name(),
		required_skill_level
	]
