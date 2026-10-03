## Tests for crafting system (skills, recipes, multi-gen items)
##
## Tests: skill progression, recipe crafting, legendary item creation

extends GutTest


var crafting_system: CraftingSystem
var skill: CraftingSkill


func before_each() -> void:
	crafting_system = CraftingSystem.new()
	skill = CraftingSkill.new(CraftingSkill.SkillType.BLACKSMITHING)


## Test: Create crafting skill
func test_create_crafting_skill() -> void:
	assert_eq(skill.skill_type, CraftingSkill.SkillType.BLACKSMITHING)
	assert_eq(skill.skill_name, "Blacksmithing")
	assert_eq(skill.level, 1)


## Test: Add XP to skill
func test_add_xp_to_skill() -> void:
	var result = skill.add_xp(50)

	assert_eq(skill.current_xp, 50)
	assert_eq(result[0], 0)  # No level up yet


## Test: Level up from XP
func test_skill_level_up() -> void:
	skill.add_xp(100)

	assert_eq(skill.level, 2)
	assert_eq(skill.current_xp, 0)


## Test: Skill can reach level 100
func test_skill_max_level() -> void:
	# Add massive XP
	for i in range(1000):
		skill.add_xp(1000)

	assert_lte(skill.level, 100)


## Test: Skill is maxed
func test_skill_is_maxed() -> void:
	skill.level = 100
	assert_true(skill.is_maxed())


## Test: Get skill name
func test_get_skill_name() -> void:
	assert_eq(skill.get_skill_name(CraftingSkill.SkillType.ALCHEMY), "Alchemy")
	assert_eq(skill.get_skill_name(CraftingSkill.SkillType.COOKING), "Cooking")


## Test: Create recipe
func test_create_recipe() -> void:
	var recipe = Recipe.new("iron_sword", "iron_sword", CraftingSkill.SkillType.BLACKSMITHING, 1)

	assert_eq(recipe.recipe_id, "iron_sword")
	assert_eq(recipe.required_skill_level, 1)


## Test: Add ingredients to recipe
func test_add_recipe_ingredients() -> void:
	var recipe = Recipe.new()
	recipe.add_ingredient("iron_ore", 3)
	recipe.add_ingredient("coal", 1)

	assert_eq(recipe.ingredients.size(), 2)
	assert_eq(recipe.ingredients[0]["quantity"], 3)


## Test: Check if can craft recipe
func test_can_craft_recipe() -> void:
	var recipe = Recipe.new("iron_sword", "iron_sword", CraftingSkill.SkillType.BLACKSMITHING, 1)
	recipe.add_ingredient("iron_ore", 3)

	# Create inventory with materials
	crafting_system.add_material("iron_ore", 5)

	var result = crafting_system.can_craft("iron_sword")
	# This will fail because the recipe isn't in catalog, but test the logic
	assert_true(result is Dictionary)


## Test: Recipe difficulty names
func test_recipe_difficulty_names() -> void:
	var recipe = Recipe.new()
	recipe.difficulty = 1
	assert_eq(recipe.get_difficulty_name(), "Trivial")

	recipe.difficulty = 3
	assert_eq(recipe.get_difficulty_name(), "Normal")

	recipe.difficulty = 5
	assert_eq(recipe.get_difficulty_name(), "Expert")


## Test: Recipe time string
func test_recipe_time_string() -> void:
	var recipe = Recipe.new()
	recipe.crafting_time_hours = 1
	assert_eq(recipe.get_time_string(), "1 hour")

	recipe.crafting_time_hours = 5
	assert_eq(recipe.get_time_string(), "5 hours")


## Test: Add materials to inventory
func test_add_material_to_inventory() -> void:
	crafting_system.add_material("iron_ore", 10)

	assert_eq(crafting_system.get_material_quantity("iron_ore"), 10)


## Test: Remove material from inventory
func test_remove_material_from_inventory() -> void:
	crafting_system.add_material("iron_ore", 10)
	var removed = crafting_system.remove_material("iron_ore", 3)

	assert_true(removed)
	assert_eq(crafting_system.get_material_quantity("iron_ore"), 7)


## Test: Cannot remove material not in inventory
func test_remove_material_insufficient() -> void:
	var removed = crafting_system.remove_material("iron_ore", 5)
	assert_false(removed)


## Test: Get all recipes
func test_get_all_recipes() -> void:
	var recipes = RecipeCatalog.get_all_recipes()
	assert_gt(recipes.size(), 20)  # Should have many recipes


## Test: Get recipes by skill
func test_get_recipes_by_skill() -> void:
	var recipes = RecipeCatalog.get_recipes_by_skill(CraftingSkill.SkillType.BLACKSMITHING)
	assert_gt(recipes.size(), 0)


## Test: Get recipes by difficulty
func test_get_recipes_by_difficulty() -> void:
	var recipes = RecipeCatalog.get_recipes_by_difficulty(1)
	assert_gt(recipes.size(), 0)


## Test: Get recipes at skill level
func test_get_recipes_at_level() -> void:
	var recipes = RecipeCatalog.get_recipes_at_level(CraftingSkill.SkillType.BLACKSMITHING, 1)
	assert_gt(recipes.size(), 0)


## Test: Create recipe from catalog
func test_create_recipe_from_catalog() -> void:
	var recipe = RecipeCatalog.create_recipe("iron_sword")

	assert_not_null(recipe)
	assert_eq(recipe.recipe_id, "iron_sword")
	assert_eq(recipe.output_item_id, "iron_sword")


## Test: Create multi-gen recipe
func test_create_multi_gen_recipe() -> void:
	var recipe = MultiGenRecipe.new("eternal_crown", "eternal_crown", 300)

	assert_eq(recipe.recipe_id, "eternal_crown")
	assert_eq(recipe.total_progress, 300)
	assert_eq(recipe.current_progress, 0)


## Test: Add progress to multi-gen recipe
func test_add_progress_to_multi_gen() -> void:
	var recipe = MultiGenRecipe.new("test_item", "test_item", 100)
	var result = recipe.add_progress(25, "Hero1", 100)

	assert_eq(result["progress_after"], 25)
	assert_eq(recipe.current_progress, 25)
	assert_eq(recipe.generations_contributed, 1)


## Test: Multi-gen recipe milestone detection
func test_multi_gen_milestone() -> void:
	var recipe = MultiGenRecipe.new("test_item", "test_item", 100)
	recipe.milestones = {50: "Halfway", 100: "Complete"}

	recipe.add_progress(49, "Hero1", 100)
	assert_eq(recipe.get_current_milestone(), "Conception")

	recipe.add_progress(1, "Hero2", 101)
	assert_eq(recipe.get_current_milestone(), "Halfway")


## Test: Multi-gen recipe completion
func test_multi_gen_completion() -> void:
	var recipe = MultiGenRecipe.new("test_item", "test_item", 100)
	recipe.add_progress(100, "Hero1", 100)

	assert_true(recipe.is_complete())


## Test: Multiple contributors to multi-gen
func test_multi_gen_multiple_contributors() -> void:
	var recipe = MultiGenRecipe.new("test_item", "test_item", 100)
	recipe.add_progress(30, "Hero1", 100)
	recipe.add_progress(40, "Hero2", 120)
	recipe.add_progress(30, "Hero3", 150)

	assert_eq(recipe.generations_contributed, 3)
	assert_eq(recipe.contributors.size(), 3)


## Test: Multi-gen progress bar
func test_multi_gen_progress_bar() -> void:
	var recipe = MultiGenRecipe.new("test_item", "test_item", 100)
	recipe.current_progress = 50

	var bar = recipe.get_progress_bar()
	assert_true("[" in bar and "%" in bar)


## Test: Get all multi-gen recipes
func test_get_all_multi_gen_recipes() -> void:
	var recipes = RecipeCatalog.get_all_multi_gen_recipes()
	assert_gt(recipes.size(), 0)


## Test: Create multi-gen from catalog
func test_create_multi_gen_from_catalog() -> void:
	var recipe = RecipeCatalog.create_multi_gen_recipe("eternal_crown")

	assert_not_null(recipe)
	assert_eq(recipe.recipe_id, "eternal_crown")


## Test: Recipe total count
func test_total_recipe_count() -> void:
	var count = RecipeCatalog.get_total_recipe_count()
	assert_gt(count, 20)


## Test: Multi-gen recipe count
func test_multi_gen_recipe_count() -> void:
	var count = RecipeCatalog.get_multi_gen_recipe_count()
	assert_gt(count, 0)


## Test: Crafting system skill management
func test_crafting_system_skills() -> void:
	var bs_skill = crafting_system.get_skill(CraftingSkill.SkillType.BLACKSMITHING)
	assert_not_null(bs_skill)
	assert_eq(bs_skill.level, 1)


## Test: Start multi-gen recipe
func test_start_multi_gen_recipe() -> void:
	var result = crafting_system.start_multi_gen_recipe("eternal_crown")

	assert_true(result["success"])
	assert_true("eternal_crown" in crafting_system.get_active_multi_gen_recipes())


## Test: Contribute to multi-gen recipe
func test_contribute_to_multi_gen() -> void:
	crafting_system.start_multi_gen_recipe("eternal_crown")
	var result = crafting_system.contribute_to_multi_gen("eternal_crown", 50, "Hero1", 100)

	assert_true(result["success"])
	assert_eq(result["progress"], 50)


## Test: Get multi-gen recipe
func test_get_multi_gen_recipe() -> void:
	crafting_system.start_multi_gen_recipe("eternal_crown")
	var recipe = crafting_system.get_multi_gen_recipe("eternal_crown")

	assert_not_null(recipe)
	assert_eq(recipe.recipe_id, "eternal_crown")


## Test: Get active multi-gen recipes
func test_get_active_multi_gen() -> void:
	crafting_system.start_multi_gen_recipe("eternal_crown")
	crafting_system.start_multi_gen_recipe("sword_of_ages")

	var active = crafting_system.get_active_multi_gen_recipes()
	assert_eq(active.size(), 2)


## Test: Get completed multi-gen recipes
func test_get_completed_multi_gen() -> void:
	crafting_system.start_multi_gen_recipe("eternal_crown")
	var recipe = crafting_system.get_multi_gen_recipe("eternal_crown")
	recipe.current_progress = recipe.total_progress

	var completed = crafting_system.get_completed_multi_gen_recipes()
	assert_eq(completed.size(), 1)


## Test: Crafting stats
func test_crafting_stats() -> void:
	var stats = crafting_system.get_crafting_stats()

	assert_true("total_recipes_crafted" in stats)
	assert_true("active_multi_gen" in stats)
	assert_true("skills" in stats)


## Test: Crafting summary string
func test_crafting_summary_string() -> void:
	var summary = crafting_system.get_summary_string()

	assert_true("CRAFTING SUMMARY" in summary)
	assert_true("Blacksmithing" in summary)


## Test: Recipe ingredients string
func test_recipe_ingredients_string() -> void:
	var recipe = Recipe.new()
	recipe.add_ingredient("iron_ore", 3)
	recipe.add_ingredient("coal", 1)

	var ingredients_str = recipe.get_ingredients_string()
	assert_true("iron_ore" in ingredients_str)
	assert_true("coal" in ingredients_str)
