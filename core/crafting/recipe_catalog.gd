## Recipe Catalog: hundreds of crafting recipes
##
## Organized by skill type, difficulty, and rarity
## Includes legendary multi-generational recipes

class_name RecipeCatalog


## Predefined recipes (sample of hundreds)
## Format: recipe_id -> {output, skill, level, time_hours, difficulty, xp, ingredients}
static var RECIPES: Dictionary = {
	# BLACKSMITHING (Weapons & Armor)
	"iron_sword": {
		"output": "iron_sword",
		"skill": CraftingSkill.SkillType.BLACKSMITHING,
		"level": 1,
		"time": 2,
		"difficulty": 1,
		"xp": 50,
		"ingredients": [{"material": "iron_ore", "qty": 3}]
	},
	"steel_sword": {
		"output": "steel_sword",
		"skill": CraftingSkill.SkillType.BLACKSMITHING,
		"level": 10,
		"time": 4,
		"difficulty": 2,
		"xp": 100,
		"ingredients": [{"material": "iron_ore", "qty": 2}, {"material": "coal", "qty": 2}]
	},
	"mithril_sword": {
		"output": "mithril_sword",
		"skill": CraftingSkill.SkillType.BLACKSMITHING,
		"level": 25,
		"time": 6,
		"difficulty": 3,
		"xp": 200,
		"ingredients": [{"material": "mithril_ore", "qty": 3}, {"material": "diamond", "qty": 1}]
	},
	"dragon_forge": {
		"output": "dragon_slayer",
		"skill": CraftingSkill.SkillType.BLACKSMITHING,
		"level": 50,
		"time": 12,
		"difficulty": 5,
		"xp": 500,
		"ingredients": [{"material": "mithril_ore", "qty": 5}, {"material": "dragon_scale", "qty": 3}, {"material": "starlight_gem", "qty": 2}]
	},
	"leather_armor": {
		"output": "leather_armor",
		"skill": CraftingSkill.SkillType.LEATHERWORKING,
		"level": 1,
		"time": 3,
		"difficulty": 1,
		"xp": 60,
		"ingredients": [{"material": "leather", "qty": 5}]
	},
	"plate_armor": {
		"output": "plate_armor",
		"skill": CraftingSkill.SkillType.BLACKSMITHING,
		"level": 20,
		"time": 8,
		"difficulty": 3,
		"xp": 150,
		"ingredients": [{"material": "iron_ore", "qty": 5}, {"material": "coal", "qty": 3}]
	},

	# ALCHEMY (Potions & Elixirs)
	"health_potion": {
		"output": "health_potion",
		"skill": CraftingSkill.SkillType.ALCHEMY,
		"level": 1,
		"time": 1,
		"difficulty": 1,
		"xp": 40,
		"ingredients": [{"material": "moonpetal_herb", "qty": 2}, {"material": "crystal_vial", "qty": 1}]
	},
	"mana_potion": {
		"output": "mana_potion",
		"skill": CraftingSkill.SkillType.ALCHEMY,
		"level": 5,
		"time": 1,
		"difficulty": 1,
		"xp": 45,
		"ingredients": [{"material": "starflower", "qty": 2}, {"material": "crystal_vial", "qty": 1}]
	},
	"greater_health_potion": {
		"output": "greater_health_potion",
		"skill": CraftingSkill.SkillType.ALCHEMY,
		"level": 15,
		"time": 2,
		"difficulty": 2,
		"xp": 100,
		"ingredients": [{"material": "moonpetal_herb", "qty": 4}, {"material": "dragon_scale", "qty": 1}, {"material": "crystal_vial", "qty": 1}]
	},
	"elixir_of_strength": {
		"output": "elixir_strength",
		"skill": CraftingSkill.SkillType.ALCHEMY,
		"level": 30,
		"time": 3,
		"difficulty": 3,
		"xp": 150,
		"ingredients": [{"material": "dragonroot", "qty": 3}, {"material": "ruby", "qty": 1}, {"material": "essence_fire", "qty": 1}]
	},

	# LEATHERWORKING (Armor & Gear)
	"leather_boots": {
		"output": "leather_boots",
		"skill": CraftingSkill.SkillType.LEATHERWORKING,
		"level": 3,
		"time": 2,
		"difficulty": 1,
		"xp": 50,
		"ingredients": [{"material": "leather", "qty": 3}]
	},
	"dragon_hide_armor": {
		"output": "dragon_hide_armor",
		"skill": CraftingSkill.SkillType.LEATHERWORKING,
		"level": 40,
		"time": 10,
		"difficulty": 4,
		"xp": 300,
		"ingredients": [{"material": "dragon_scale", "qty": 5}, {"material": "leather", "qty": 5}]
	},

	# CARPENTRY (Staffs, Bows, Structures)
	"wooden_bow": {
		"output": "wooden_bow",
		"skill": CraftingSkill.SkillType.CARPENTRY,
		"level": 1,
		"time": 2,
		"difficulty": 1,
		"xp": 50,
		"ingredients": [{"material": "pine_log", "qty": 2}]
	},
	"longbow": {
		"output": "longbow",
		"skill": CraftingSkill.SkillType.CARPENTRY,
		"level": 15,
		"time": 4,
		"difficulty": 2,
		"xp": 120,
		"ingredients": [{"material": "oak_log", "qty": 3}, {"material": "leather", "qty": 1}]
	},
	"mage_staff": {
		"output": "mage_staff",
		"skill": CraftingSkill.SkillType.CARPENTRY,
		"level": 25,
		"time": 5,
		"difficulty": 3,
		"xp": 180,
		"ingredients": [{"material": "oak_log", "qty": 2}, {"material": "amethyst", "qty": 2}]
	},

	# ENCHANTING (Runes & Magical Items)
	"minor_rune": {
		"output": "minor_rune",
		"skill": CraftingSkill.SkillType.ENCHANTING,
		"level": 10,
		"time": 2,
		"difficulty": 2,
		"xp": 80,
		"ingredients": [{"material": "crystal", "qty": 1}, {"material": "essence_magic", "qty": 1}]
	},
	"major_rune": {
		"output": "major_rune",
		"skill": CraftingSkill.SkillType.ENCHANTING,
		"level": 30,
		"time": 4,
		"difficulty": 3,
		"xp": 200,
		"ingredients": [{"material": "crystal", "qty": 2}, {"material": "diamond", "qty": 1}, {"material": "essence_magic", "qty": 2}]
	},

	# COOKING (Food & Buffs)
	"bread": {
		"output": "bread",
		"skill": CraftingSkill.SkillType.COOKING,
		"level": 1,
		"time": 1,
		"difficulty": 1,
		"xp": 30,
		"ingredients": [{"material": "wheat", "qty": 2}]
	},
	"roasted_meat": {
		"output": "roasted_meat",
		"skill": CraftingSkill.SkillType.COOKING,
		"level": 5,
		"time": 1,
		"difficulty": 1,
		"xp": 40,
		"ingredients": [{"material": "raw_meat", "qty": 1}]
	},
	"legendary_feast": {
		"output": "legendary_feast",
		"skill": CraftingSkill.SkillType.COOKING,
		"level": 35,
		"time": 3,
		"difficulty": 4,
		"xp": 250,
		"ingredients": [{"material": "raw_meat", "qty": 3}, {"material": "moonpetal_herb", "qty": 2}, {"material": "starflower", "qty": 1}]
	},

	# WEAVING (Cloth & Tapestries)
	"simple_cloth": {
		"output": "simple_cloth",
		"skill": CraftingSkill.SkillType.WEAVING,
		"level": 1,
		"time": 1,
		"difficulty": 1,
		"xp": 35,
		"ingredients": [{"material": "wool", "qty": 2}]
	},
	"silk_robe": {
		"output": "silk_robe",
		"skill": CraftingSkill.SkillType.WEAVING,
		"level": 20,
		"time": 3,
		"difficulty": 2,
		"xp": 110,
		"ingredients": [{"material": "silk", "qty": 4}]
	},

	# STONEWORK (Blocks, Structures)
	"stone_block": {
		"output": "stone_block",
		"skill": CraftingSkill.SkillType.STONEWORK,
		"level": 1,
		"time": 2,
		"difficulty": 1,
		"xp": 40,
		"ingredients": [{"material": "stone", "qty": 3}]
	},
	"marble_sculpture": {
		"output": "marble_sculpture",
		"skill": CraftingSkill.SkillType.STONEWORK,
		"level": 30,
		"time": 8,
		"difficulty": 3,
		"xp": 200,
		"ingredients": [{"material": "marble", "qty": 5}, {"material": "chisel", "qty": 1}]
	}
}


## Multi-generational legendary recipes (RARE)
static var MULTI_GEN_RECIPES: Dictionary = {
	"eternal_crown": {
		"output": "eternal_crown",
		"description": "A crown that takes generations to forge",
		"progress": 300,
		"skill": CraftingSkill.SkillType.BLACKSMITHING,
		"lore": "The Eternal Crown requires 3+ generations of the finest craftsmen. Each heir must contribute their life's work to complete this masterpiece. Upon completion, the crown grants +5 to all stats and is bound to the bloodline forever.",
		"milestones": {
			75: "Foundation Laid: Base metal shape formed",
			150: "Gems Set: Three legendary gems embedded",
			225: "Enchantments Applied: Magical runes inscribed",
			300: "Crown Complete: Bound to bloodline forever"
		}
	},
	"sword_of_ages": {
		"output": "sword_of_ages",
		"description": "A legendary blade forged across generations",
		"progress": 250,
		"skill": CraftingSkill.SkillType.BLACKSMITHING,
		"lore": "The Sword of Ages is not forged in one lifetime. Each generation adds to its power. First generation folds the base steel a hundred times. Second generation inscribes runes of might. Third generation tempers it in dragon's fire. The resulting blade never dulls and grows stronger with each heir who wields it.",
		"milestones": {
			62: "Steel Folded: Base layers complete",
			125: "Runes Inscribed: Magical knowledge added",
			187: "Dragon's Fire: Tempered in legendary flame",
			250: "Sword Complete: Legendary weapon ready"
		}
	},
	"philosophers_stone": {
		"output": "philosophers_stone",
		"description": "The legendary alchemical achievement",
		"progress": 200,
		"skill": CraftingSkill.SkillType.ALCHEMY,
		"lore": "The Philosopher's Stone represents the ultimate alchemical achievement. Crafting it requires 2-3 generations of alchemists, each contributing rare essences and knowledge. When complete, the stone allows transmutation of any material and grants +3 INT permanently.",
		"milestones": {
			50: "Essences Gathered: Rare materials collected",
			100: "First Transmutation: Base elements bonded",
			150: "Purification Complete: Stone refined",
			200: "Stone Complete: Transmutation unlocked"
		}
	},
	"worldtree_bow": {
		"output": "worldtree_bow",
		"description": "Bow crafted from sacred wood",
		"progress": 280,
		"skill": CraftingSkill.SkillType.CARPENTRY,
		"lore": "The Worldtree Bow is carved from the heartwood of an ancient sacred tree. It requires 3 generations of master carpenters to complete: one to fell the tree, one to carve the bow, and one to string it with phoenix feathers. When complete, arrows shot from this bow never miss and deal +50% damage.",
		"milestones": {
			70: "Wood Harvested: Sacred tree felled and seasoned",
			140: "Bow Carved: Shape refined to perfection",
			210: "Strings Added: Phoenix feathers woven",
			280: "Bow Complete: Ready for legendary archer"
		}
	},
	"mask_of_ancients": {
		"output": "mask_of_ancients",
		"description": "A mask imbued with ancient wisdom",
		"progress": 220,
		"skill": CraftingSkill.SkillType.ENCHANTING,
		"lore": "Only a true bloodline can create the Mask of Ancients. Generation 1 gathers materials, Generation 2 crafts the base, Generation 3 enchants it with ancestor spirits. When complete, wearer can commune with all ancestors and gains +2 WIS per generation of the family.",
		"milestones": {
			55: "Materials Gathered: Rare components collected",
			110: "Mask Formed: Base structure complete",
			165: "Spirit Binding: Ancestors' essence captured",
			220: "Mask Complete: Ancestor communion unlocked"
		}
	}
}


## Create recipe from catalog
static func create_recipe(recipe_id: String) -> Recipe:
	var data = RECIPES.get(recipe_id)
	if not data:
		return null

	var recipe = Recipe.new(recipe_id, data["output"], data["skill"], data["level"])
	recipe.crafting_time_hours = data["time"]
	recipe.difficulty = data["difficulty"]
	recipe.xp_reward = data["xp"]

	for ing in data["ingredients"]:
		recipe.add_ingredient(ing["material"], ing["qty"])

	return recipe


## Create multi-gen recipe from catalog
static func create_multi_gen_recipe(recipe_id: String) -> MultiGenRecipe:
	var data = MULTI_GEN_RECIPES.get(recipe_id)
	if not data:
		return null

	var recipe = MultiGenRecipe.new(recipe_id, data["output"], data["progress"])
	recipe.lore = data["lore"]
	recipe.milestones = data["milestones"]

	return recipe


## Get all recipe IDs
static func get_all_recipes() -> Array[String]:
	return RECIPES.keys()


## Get all multi-gen recipe IDs
static func get_all_multi_gen_recipes() -> Array[String]:
	return MULTI_GEN_RECIPES.keys()


## Get recipes by skill type
static func get_recipes_by_skill(skill_type: int) -> Array[String]:
	var results: Array[String] = []
	for recipe_id in RECIPES.keys():
		if RECIPES[recipe_id]["skill"] == skill_type:
			results.append(recipe_id)
	return results


## Get recipes by difficulty
static func get_recipes_by_difficulty(difficulty: int) -> Array[String]:
	var results: Array[String] = []
	for recipe_id in RECIPES.keys():
		if RECIPES[recipe_id]["difficulty"] == difficulty:
			results.append(recipe_id)
	return results


## Get recipes learnable at a skill level
static func get_recipes_at_level(skill_type: int, skill_level: int) -> Array[String]:
	var results: Array[String] = []
	for recipe_id in RECIPES.keys():
		var recipe_data = RECIPES[recipe_id]
		if recipe_data["skill"] == skill_type and recipe_data["level"] <= skill_level:
			results.append(recipe_id)
	return results


## Count total recipes
static func get_total_recipe_count() -> int:
	return RECIPES.size()


## Count total multi-gen recipes
static func get_multi_gen_recipe_count() -> int:
	return MULTI_GEN_RECIPES.size()
