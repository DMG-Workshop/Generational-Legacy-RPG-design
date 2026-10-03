## Heir Crafting: helper class for managing heir crafting skills and recipes
##
## Wraps crafting skills and provides methods to check recipes, track progress

class_name HeirCrafting


var heir: Heir
var multi_gen_recipes: Dictionary = {}  # recipe_id -> MultiGenRecipe


func _init(p_heir: Heir) -> void:
	heir = p_heir


## Get crafting skill by type
func get_skill(skill_type: int) -> CraftingSkill:
	return heir.crafting_skills.get(skill_type, null)


## Get crafting skill by name
func get_skill_by_name(skill_name: String) -> CraftingSkill:
	for skill_type in heir.crafting_skills:
		var skill = heir.crafting_skills[skill_type]
		if skill.skill_name.to_lower() == skill_name.to_lower():
			return skill
	return null


## Get all crafting skills
func get_all_skills() -> Array[CraftingSkill]:
	var skills: Array[CraftingSkill] = []
	for skill_type in heir.crafting_skills:
		skills.append(heir.crafting_skills[skill_type])
	return skills


## Check if heir can craft a recipe
func can_craft_recipe(recipe: Recipe) -> bool:
	var skill = get_skill(recipe.required_skill)
	if not skill:
		return false

	if skill.level < recipe.required_skill_level:
		return false

	# Check if heir has all ingredients
	for ingredient in recipe.ingredients:
		var material_id = ingredient["material_id"]
		var needed = ingredient["quantity"]
		var have = _count_material(material_id)
		if have < needed:
			return false

	return true


## Check if heir can craft a multi-gen recipe
func can_contribute_to_multi_gen(recipe: MultiGenRecipe) -> bool:
	var skill = get_skill(recipe.required_skill) if recipe.has_meta("required_skill") else null
	if skill and recipe.get_meta("required_skill_level", 0) > 0:
		if skill.level < recipe.get_meta("required_skill_level", 0):
			return false
	return true


## Add progress to a multi-gen recipe
func contribute_to_multi_gen(recipe_id: String, amount: int) -> Dictionary:
	if recipe_id not in multi_gen_recipes:
		return {"success": false, "error": "Recipe not found"}

	var recipe = multi_gen_recipes[recipe_id]
	return recipe.add_progress(amount, heir.name, heir.birth_year)


## Track a new multi-gen recipe
func track_multi_gen_recipe(recipe: MultiGenRecipe) -> void:
	multi_gen_recipes[recipe.recipe_id] = recipe


## Get multi-gen recipe by ID
func get_multi_gen_recipe(recipe_id: String) -> MultiGenRecipe:
	return multi_gen_recipes.get(recipe_id, null)


## Get all active multi-gen recipes
func get_active_multi_gen_recipes() -> Array[MultiGenRecipe]:
	var active: Array[MultiGenRecipe] = []
	for recipe_id in multi_gen_recipes:
		var recipe = multi_gen_recipes[recipe_id]
		if not recipe.is_complete():
			active.append(recipe)
	return active


## Get all completed multi-gen recipes
func get_completed_multi_gen_recipes() -> Array[MultiGenRecipe]:
	var completed: Array[MultiGenRecipe] = []
	for recipe_id in multi_gen_recipes:
		var recipe = multi_gen_recipes[recipe_id]
		if recipe.is_complete():
			completed.append(recipe)
	return completed


## Add XP to a crafting skill
func add_skill_xp(skill_type: int, amount: int) -> Array[int]:
	var skill = get_skill(skill_type)
	if skill:
		return skill.add_xp(amount)
	return [0, 0]


## Get total XP across all crafting skills
func get_total_xp() -> int:
	var total = 0
	for skill in get_all_skills():
		total += skill.total_xp
	return total


## Get crafting summary
func get_summary() -> String:
	var skills_maxed = 0
	var total_crafted = 0

	for skill in get_all_skills():
		if skill.is_maxed():
			skills_maxed += 1
		total_crafted += skill.items_crafted

	var multi_gen_count = multi_gen_recipes.size()
	var multi_gen_active = get_active_multi_gen_recipes().size()

	return "Crafting: %d skills, %d maxed, %d items crafted, %d multi-gen recipes (%d active)" % [
		heir.crafting_skills.size(), skills_maxed, total_crafted, multi_gen_count, multi_gen_active
	]


## Get skills by level (sorted)
func get_skills_by_level() -> Array[CraftingSkill]:
	var sorted = get_all_skills()
	sorted.sort_custom(func(a, b): return a.level > b.level)
	return sorted


## Get unlocked recipes for all skills
func get_all_unlocked_recipes() -> Array[String]:
	var recipes: Array[String] = []
	for skill in get_all_skills():
		recipes.append_array(skill.get_unlocked_recipes())
	return recipes


## Internal: Count how many of a material the heir has
func _count_material(material_id: String) -> int:
	var count = 0
	for item in heir.inventory:
		if item.item_id == material_id:
			count += 1
	return count
