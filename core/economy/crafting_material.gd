## Crafting Material: items used in crafting recipes
##
## Ores, logs, herbs, etc.

extends Item

class_name CraftingMaterial


## Material type (ore, wood, leather, herb, etc.)
var material_type: String = ""

## Rarity of the material (affects crafting quality)
var material_rarity: int = Item.Rarity.COMMON

## Quantity harvested in one go
var harvest_amount: int = 1

## Required skill to harvest/use
var required_skill: String = ""
var required_skill_level: int = 1

## Recipes this material is used in
var used_in_recipes: Array[String] = []


func _init(
	p_id: String = "",
	p_name: String = "",
	p_material_type: String = "",
	p_value: Currency = null
) -> void:
	super._init(p_id, p_name, ItemType.CRAFTING_MATERIAL, Item.Rarity.COMMON, p_value)
	material_type = p_material_type
	is_stackable = true
	max_stack = 999


## Get material type name
func get_material_type_name() -> String:
	match material_type.to_lower():
		"ore":
			return "Ore"
		"wood":
			return "Wood"
		"leather":
			return "Leather"
		"herb":
			return "Herb"
		"cloth":
			return "Cloth"
		"bone":
			return "Bone"
		"scale":
			return "Scale"
		"gem":
			return "Gem"
		"crystal":
			return "Crystal"
		"dust":
			return "Dust"
	return material_type.capitalize()


## Check if has required skill
func can_use(character_skill: String, character_skill_level: int) -> bool:
	if required_skill.is_empty():
		return true

	return character_skill == required_skill and character_skill_level >= required_skill_level


## Get detailed string
func to_detailed_string() -> String:
	var str = super.to_detailed_string()
	str += "\nMaterial Type: %s\n" % get_material_type_name()
	if not required_skill.is_empty():
		str += "Required: %s Level %d\n" % [required_skill.capitalize(), required_skill_level]
	if not used_in_recipes.is_empty():
		str += "Used In: %s\n" % ", ".join(used_in_recipes)
	return str


## Add recipe that uses this material
func add_recipe_use(recipe_id: String) -> void:
	if recipe_id not in used_in_recipes:
		used_in_recipes.append(recipe_id)


## Create ore material
static func create_ore(
	p_id: String,
	p_name: String,
	p_rarity: int,
	value: Currency
) -> CraftingMaterial:
	var ore = CraftingMaterial.new(p_id, p_name, "ore", value)
	ore.rarity = p_rarity
	ore.required_skill = "mining"
	ore.required_skill_level = 1 + (p_rarity * 5)  # Higher rarity = higher skill needed
	return ore


## Create wood material
static func create_wood(
	p_id: String,
	p_name: String,
	p_rarity: int,
	value: Currency
) -> CraftingMaterial:
	var wood = CraftingMaterial.new(p_id, p_name, "wood", value)
	wood.rarity = p_rarity
	wood.required_skill = "logging"
	wood.required_skill_level = 1 + (p_rarity * 5)
	return wood


## Create herb material
static func create_herb(
	p_id: String,
	p_name: String,
	p_rarity: int,
	value: Currency
) -> CraftingMaterial:
	var herb = CraftingMaterial.new(p_id, p_name, "herb", value)
	herb.rarity = p_rarity
	herb.required_skill = "herbalism"
	herb.required_skill_level = 1 + (p_rarity * 3)
	return herb
