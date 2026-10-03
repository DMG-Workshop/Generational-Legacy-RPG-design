## Crafting System: Craft equipment with skill progression
##
## Manages crafting recipes, skill XP, success rates, and crafting progression
## Crafting skill levels unlock better equipment and improve success rates

class_name CraftingSystem


signal craft_started(heir_name: String, equipment_key: String)
signal craft_completed(heir_name: String, equipment_key: String, success: bool, item: Dictionary)
signal skill_leveled_up(heir_name: String, skill_name: String, new_level: int)


enum CraftingSkill { BLACKSMITHING, LEATHERWORKING, RUNECRAFTING, ALCHEMY }

# Crafting skill definitions
var crafting_skills: Dictionary = {
	CraftingSkill.BLACKSMITHING: {
		"name": "Blacksmithing",
		"equipment_types": [EquipmentSystem.EquipmentType.WEAPON],
		"base_success_rate": 0.7,
	},
	CraftingSkill.LEATHERWORKING: {
		"name": "Leatherworking",
		"equipment_types": [EquipmentSystem.EquipmentType.ARMOR],
		"base_success_rate": 0.75,
	},
	CraftingSkill.RUNECRAFTING: {
		"name": "Runecrafting",
		"equipment_types": [EquipmentSystem.EquipmentType.ACCESSORY],
		"base_success_rate": 0.6,
	},
	CraftingSkill.ALCHEMY: {
		"name": "Alchemy",
		"equipment_types": [],
		"base_success_rate": 0.5,
	},
}

# Crafting skill progression
var heir_crafting_skills: Dictionary = {}  # heir_name -> {skill_name -> {level, xp}}

# Skill progression
var xp_per_level: int = 100
var max_skill_level: int = 10


## Get heir crafting skills
func get_heir_crafting_skills(heir_name: String) -> Dictionary:
	if heir_name not in heir_crafting_skills:
		heir_crafting_skills[heir_name] = _initialize_crafting_skills()

	return heir_crafting_skills[heir_name]


## Get skill level
func get_skill_level(heir_name: String, skill_name: String) -> int:
	var skills = get_heir_crafting_skills(heir_name)
	if skill_name in skills:
		return skills[skill_name]["level"]
	return 1


## Get skill XP
func get_skill_xp(heir_name: String, skill_name: String) -> int:
	var skills = get_heir_crafting_skills(heir_name)
	if skill_name in skills:
		return skills[skill_name]["xp"]
	return 0


## Attempt to craft equipment
func craft_equipment(heir_name: String, equipment_key: String, equipment_sys: EquipmentSystem, resources: Dictionary) -> Dictionary:
	var requirements = equipment_sys.get_crafting_requirements(equipment_key)
	if requirements.is_empty():
		return {}

	var skill_name = requirements["crafting_skill"]
	var skill_level = get_skill_level(heir_name, skill_name)

	# Check if skill level sufficient
	if skill_level < requirements["skill_level"]:
		return {"success": false, "reason": "insufficient_skill"}

	# Check resources
	if resources.get("materials", 0) < requirements["materials"]:
		return {"success": false, "reason": "insufficient_materials"}
	if resources.get("gold", 0) < requirements["gold"]:
		return {"success": false, "reason": "insufficient_gold"}

	craft_started.emit(heir_name, equipment_key)

	# Calculate success rate
	var base_rate = crafting_skills[_get_skill_enum(skill_name)]["base_success_rate"]
	var level_bonus = (skill_level - requirements["skill_level"]) * 0.05  # 5% per skill level above requirement
	var success_rate = clampf(base_rate + level_bonus, 0.2, 0.95)

	var success = randf() < success_rate

	if success:
		# Create item
		var item = equipment_sys.create_item(equipment_key)

		# Apply stat bonus for high skill
		if skill_level >= 5:
			var skill_bonus = (skill_level - 5) * 0.1  # 10% stat bonus per level above 5
			for stat_key in item["stats"].keys():
				item["stats"][stat_key] = int(item["stats"][stat_key] * (1.0 + skill_bonus))

		# Grant XP
		var xp_gained = requirements["skill_level"] * 10 + (requirements["materials"] / 5)
		_add_skill_xp(heir_name, skill_name, xp_gained)

		craft_completed.emit(heir_name, equipment_key, true, item)
		return {
			"success": true,
			"item": item,
			"xp_gained": xp_gained,
		}
	else:
		# Failed craft still grants some XP
		var xp_gained = int(requirements["skill_level"] * 5)
		_add_skill_xp(heir_name, skill_name, xp_gained)

		craft_completed.emit(heir_name, equipment_key, false, {})
		return {
			"success": false,
			"reason": "craft_failed",
			"xp_gained": xp_gained,
		}


## Get success rate for craft
func get_craft_success_rate(heir_name: String, equipment_key: String, equipment_sys: EquipmentSystem) -> float:
	var requirements = equipment_sys.get_crafting_requirements(equipment_key)
	if requirements.is_empty():
		return 0.0

	var skill_name = requirements["crafting_skill"]
	var skill_level = get_skill_level(heir_name, skill_name)

	if skill_level < requirements["skill_level"]:
		return 0.0  # Cannot craft

	var base_rate = crafting_skills[_get_skill_enum(skill_name)]["base_success_rate"]
	var level_bonus = (skill_level - requirements["skill_level"]) * 0.05
	return clampf(base_rate + level_bonus, 0.2, 0.95)


## Get crafting recommendations for heir
func get_craftable_equipment(heir_name: String, equipment_sys: EquipmentSystem) -> Array[String]:
	var all_equipment = equipment_sys.get_all_equipment()
	var craftable = []

	for equipment_key in all_equipment:
		var requirements = equipment_sys.get_crafting_requirements(equipment_key)
		var skill_level = get_skill_level(heir_name, requirements["crafting_skill"])

		if skill_level >= requirements["skill_level"]:
			craftable.append(equipment_key)

	return craftable


## Get all crafting skills
func get_all_crafting_skills() -> Array[String]:
	var skills = []
	for skill_id in crafting_skills.keys():
		skills.append(crafting_skills[skill_id]["name"])
	return skills


## Get crafting skill progress
func get_skill_progress(heir_name: String, skill_name: String) -> Dictionary:
	var skills = get_heir_crafting_skills(heir_name)
	if skill_name not in skills:
		return {}

	var skill = skills[skill_name]
	var xp_to_next = xp_per_level - skill["xp"]

	return {
		"skill": skill_name,
		"level": skill["level"],
		"xp": skill["xp"],
		"xp_to_next": xp_to_next,
		"max_level": max_skill_level,
		"progress": float(skill["xp"]) / float(xp_per_level),
	}


## Transfer crafting skills to next heir (with penalty)
func inherit_crafting_skills(heir_name: String, previous_heir_name: String, inheritance_multiplier: float = 0.5) -> void:
	if previous_heir_name not in heir_crafting_skills:
		heir_crafting_skills[heir_name] = _initialize_crafting_skills()
		return

	var previous_skills = heir_crafting_skills[previous_heir_name]
	var inherited_skills = _initialize_crafting_skills()

	for skill_name in previous_skills.keys():
		var previous_level = previous_skills[skill_name]["level"]
		var inherited_level = int(previous_level * inheritance_multiplier)
		inherited_level = clampi(inherited_level, 1, max_skill_level)

		inherited_skills[skill_name]["level"] = inherited_level

	heir_crafting_skills[heir_name] = inherited_skills


## Get mastery bonus for equipment crafting
func get_mastery_bonus(heir_name: String, skill_name: String) -> float:
	var level = get_skill_level(heir_name, skill_name)
	if level < 5:
		return 1.0  # No bonus

	# 10% bonus per level above 5
	return 1.0 + ((level - 5) * 0.1)


## Internal: Initialize crafting skills for heir
func _initialize_crafting_skills() -> Dictionary:
	var skills = {}
	for skill_id in crafting_skills.keys():
		skills[crafting_skills[skill_id]["name"]] = {
			"level": 1,
			"xp": 0,
		}
	return skills


## Internal: Add XP to skill
func _add_skill_xp(heir_name: String, skill_name: String, xp_amount: int) -> void:
	var skills = get_heir_crafting_skills(heir_name)
	if skill_name not in skills:
		return

	skills[skill_name]["xp"] += xp_amount

	# Check for level up
	while skills[skill_name]["xp"] >= xp_per_level and skills[skill_name]["level"] < max_skill_level:
		skills[skill_name]["xp"] -= xp_per_level
		skills[skill_name]["level"] += 1
		skill_leveled_up.emit(heir_name, skill_name, skills[skill_name]["level"])


## Internal: Get skill enum from name
func _get_skill_enum(skill_name: String) -> int:
	for skill_id in crafting_skills.keys():
		if crafting_skills[skill_id]["name"] == skill_name:
			return skill_id
	return CraftingSkill.BLACKSMITHING


## Get crafting summary for heir
func get_crafting_summary(heir_name: String) -> Dictionary:
	var skills = get_heir_crafting_skills(heir_name)
	var summary = {}

	for skill_name in skills.keys():
		var skill = skills[skill_name]
		summary[skill_name] = {
			"level": skill["level"],
			"xp": skill["xp"],
			"xp_to_next": xp_per_level - skill["xp"],
		}

	return summary
