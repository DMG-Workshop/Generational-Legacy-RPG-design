## Crafting System: main crafting mechanics
##
## Skill progression, recipe crafting, multi-gen tracking

class_name CraftingSystem


## Skills dictionary (one per craft type)
var skills: Dictionary = {}

## Crafting queue (active crafting jobs)
var crafting_queue: Array[Dictionary] = []  # {recipe_id, completion_time, heir_name}

## Multi-gen recipes being worked on
var multi_gen_recipes: Dictionary = {}  # recipe_id -> MultiGenRecipe

## Inventory of materials
var inventory: Dictionary = {}  # material_id -> quantity

## Completed recipes
var crafted_items: Array[Dictionary] = []  # {recipe_id, qty, heir_name, year}


func _init() -> void:
	# Initialize all crafting skills
	for skill_type in range(CraftingSkill.SkillType.GLASSBLOWING + 1):
		skills[skill_type] = CraftingSkill.new(skill_type)


## Get skill by type
func get_skill(skill_type: int) -> CraftingSkill:
	return skills.get(skill_type)


## Add material to inventory
func add_material(material_id: String, quantity: int) -> void:
	if material_id not in inventory:
		inventory[material_id] = 0
	inventory[material_id] += quantity


## Remove material from inventory
func remove_material(material_id: String, quantity: int) -> bool:
	if not material_id in inventory or inventory[material_id] < quantity:
		return false
	inventory[material_id] -= quantity
	return true


## Get material quantity
func get_material_quantity(material_id: String) -> int:
	return inventory.get(material_id, 0)


## Check if can craft recipe
func can_craft(recipe_id: String) -> Dictionary:  # {can_craft, reason}
	var recipe = RecipeCatalog.create_recipe(recipe_id)
	if not recipe:
		return {"can_craft": false, "reason": "Recipe not found"}

	var skill = get_skill(recipe.required_skill)
	if skill.level < recipe.required_skill_level:
		return {"can_craft": false, "reason": "Skill level too low"}

	# Check all ingredients
	for ing in recipe.ingredients:
		if get_material_quantity(ing["material_id"]) < ing["quantity"]:
			return {"can_craft": false, "reason": "Missing materials"}

	return {"can_craft": true, "reason": "Ready to craft"}


## Start crafting a recipe
func craft_recipe(
	recipe_id: String,
	heir_name: String,
	year: int
) -> Dictionary:  # {success, item_created, xp_gained, message}
	var can_craft_result = can_craft(recipe_id)
	if not can_craft_result["can_craft"]:
		return {"success": false, "message": can_craft_result["reason"]}

	var recipe = RecipeCatalog.create_recipe(recipe_id)
	var skill = get_skill(recipe.required_skill)

	# Remove ingredients
	for ing in recipe.ingredients:
		remove_material(ing["material_id"], ing["quantity"])

	# Grant XP (varies by difficulty)
	var xp_multiplier = 1.0 + (recipe.difficulty * 0.2)
	var xp_gain = int(recipe.xp_reward * xp_multiplier)
	var level_up = skill.add_xp(xp_gain)

	# Track crafted item
	crafted_items.append({
		"recipe_id": recipe_id,
		"quantity": recipe.output_quantity,
		"heir_name": heir_name,
		"year": year,
		"level_at_craft": skill.level
	})

	return {
		"success": true,
		"recipe_id": recipe_id,
		"output": recipe.output_item_id,
		"quantity": recipe.output_quantity,
		"xp_gained": xp_gain,
		"skill_name": skill.skill_name,
		"level_up": level_up[0],
		"new_level": level_up[1],
		"message": "Crafted %d %s! Gained %d XP" % [recipe.output_quantity, recipe.output_item_id, xp_gain]
	}


## Start working on multi-gen recipe
func start_multi_gen_recipe(recipe_id: String) -> Dictionary:
	if recipe_id in multi_gen_recipes:
		return {"success": false, "message": "Recipe already in progress"}

	var recipe = RecipeCatalog.create_multi_gen_recipe(recipe_id)
	if not recipe:
		return {"success": false, "message": "Multi-gen recipe not found"}

	multi_gen_recipes[recipe_id] = recipe
	return {"success": true, "message": "Started working on %s" % recipe_id}


## Add progress to multi-gen recipe
func contribute_to_multi_gen(
	recipe_id: String,
	progress_amount: int,
	heir_name: String,
	year: int
) -> Dictionary:  # {success, milestone, is_complete, message}
	if recipe_id not in multi_gen_recipes:
		return {"success": false, "message": "Recipe not in progress"}

	var recipe = multi_gen_recipes[recipe_id]
	var result = recipe.add_progress(progress_amount, heir_name, year)

	var message = "%s contributed %d progress to %s\n" % [heir_name, progress_amount, recipe_id]
	message += "Progress: %s" % recipe.get_progress_bar()

	if result["milestone_reached"]:
		message += "\n✨ Milestone: %s" % result["milestone_reached"]

	if result["is_complete"]:
		message += "\n✅ LEGENDARY ITEM COMPLETE!"

	return {
		"success": true,
		"recipe_id": recipe_id,
		"progress": result["progress_after"],
		"progress_percent": recipe.get_progress_percent(),
		"milestone": result["milestone_reached"],
		"is_complete": result["is_complete"],
		"message": message
	}


## Get multi-gen recipe
func get_multi_gen_recipe(recipe_id: String) -> MultiGenRecipe:
	return multi_gen_recipes.get(recipe_id)


## Get all active multi-gen recipes
func get_active_multi_gen_recipes() -> Array[String]:
	return multi_gen_recipes.keys()


## Get completed multi-gen recipes
func get_completed_multi_gen_recipes() -> Array[String]:
	var completed: Array[String] = []
	for recipe_id in multi_gen_recipes:
		if multi_gen_recipes[recipe_id].is_complete():
			completed.append(recipe_id)
	return completed


## Get stats
func get_crafting_stats() -> Dictionary:
	var total_items = 0
	for craft in crafted_items:
		total_items += craft["quantity"]

	return {
		"total_recipes_crafted": crafted_items.size(),
		"total_items_crafted": total_items,
		"active_multi_gen": multi_gen_recipes.size(),
		"completed_multi_gen": get_completed_multi_gen_recipes().size(),
		"skills": {
			"blacksmithing": skills[CraftingSkill.SkillType.BLACKSMITHING].level,
			"alchemy": skills[CraftingSkill.SkillType.ALCHEMY].level,
			"leatherworking": skills[CraftingSkill.SkillType.LEATHERWORKING].level,
			"carpentry": skills[CraftingSkill.SkillType.CARPENTRY].level,
			"enchanting": skills[CraftingSkill.SkillType.ENCHANTING].level
		}
	}


## Get crafting summary string
func get_summary_string() -> String:
	var summary = "=== CRAFTING SUMMARY ===\n"
	for skill_type in skills:
		var skill = skills[skill_type]
		summary += "%s: %s\n" % [skill.skill_name, skill.to_string()]

	summary += "\nRecipes Crafted: %d\n" % crafted_items.size()
	summary += "Active Legendary Recipes: %d\n" % multi_gen_recipes.size()
	summary += "Completed Legendary Recipes: %d\n" % get_completed_multi_gen_recipes().size()

	if not get_completed_multi_gen_recipes().is_empty():
		summary += "\nCompleted Legendary Items:\n"
		for recipe_id in get_completed_multi_gen_recipes():
			summary += "• %s\n" % recipe_id

	return summary
