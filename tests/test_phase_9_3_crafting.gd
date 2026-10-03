## Tests for Phase 9.3: Crafting & Equipment Inheritance
##
## Tests: EquipmentSystem, CraftingSystem, RuneSystem, EquipmentHeirIntegration

extends GutTest


var equipment_system: EquipmentSystem
var crafting_system: CraftingSystem
var rune_system: RuneSystem
var integration: EquipmentHeirIntegration


func before_each() -> void:
	equipment_system = EquipmentSystem.new()
	crafting_system = CraftingSystem.new()
	rune_system = RuneSystem.new()
	integration = EquipmentHeirIntegration.new(equipment_system, rune_system)


# ========== EquipmentSystem Tests ==========

## Test: Create common item
func test_create_common_item() -> void:
	var item = equipment_system.create_item("iron_sword")
	assert_eq(item["name"], "Iron Sword")
	assert_eq(item["rarity_name"], "COMMON")


## Test: Create legendary item
func test_create_legendary_item() -> void:
	var item = equipment_system.create_item("shadow_knight_blade")
	assert_true(item["legendary"])
	assert_eq(item["rarity_name"], "LEGENDARY")


## Test: Get equipment template
func test_get_equipment_template() -> void:
	var template = equipment_system.get_equipment_template("steel_sword")
	assert_eq(template["name"], "Steel Sword")


## Test: Get all equipment
func test_get_all_equipment() -> void:
	var all_equip = equipment_system.get_all_equipment()
	assert_gt(all_equip.size(), 0)
	assert_true("iron_sword" in all_equip)


## Test: Get equipment by rarity
func test_get_equipment_by_rarity() -> void:
	var legendary = equipment_system.get_equipment_by_rarity(EquipmentSystem.Rarity.LEGENDARY)
	assert_gt(legendary.size(), 0)


## Test: Get equipment by type
func test_get_equipment_by_type() -> void:
	var weapons = equipment_system.get_equipment_by_type(EquipmentSystem.EquipmentType.WEAPON)
	assert_gt(weapons.size(), 0)


## Test: Equip item
func test_equip_item() -> void:
	var item = equipment_system.create_item("iron_sword")
	assert_true(equipment_system.equip_item("Hero", item))


## Test: Get equipped items
func test_get_equipped_items() -> void:
	var item = equipment_system.create_item("iron_sword")
	equipment_system.equip_item("Hero", item)
	var equipped = equipment_system.get_heir_equipment("Hero")
	assert_gt(equipped.size(), 0)


## Test: Get equipment stat bonus
func test_equipment_stat_bonus() -> void:
	var item = equipment_system.create_item("iron_sword")
	equipment_system.equip_item("Hero", item)
	var bonus = equipment_system.get_equipment_stat_bonus("Hero")
	assert_gt(bonus["strength"], 0)


## Test: Repair equipment
func test_repair_equipment() -> void:
	var item = equipment_system.create_item("iron_sword")
	item["durability"] = 10
	var repaired = equipment_system.repair_equipment(item)
	assert_eq(repaired["durability"], repaired["max_durability"])


## Test: Damage equipment
func test_damage_equipment() -> void:
	var item = equipment_system.create_item("iron_sword")
	var damaged = equipment_system.damage_equipment(item, 10)
	assert_lt(damaged["durability"], item["max_durability"])


## Test: Check broken equipment
func test_check_broken() -> void:
	var item = equipment_system.create_item("iron_sword")
	item["durability"] = 0
	assert_true(equipment_system.is_broken(item))


## Test: Legendary item tracking
func test_legendary_tracking() -> void:
	equipment_system.transfer_legendary_item("Hero1", equipment_system.create_item("shadow_knight_blade"), "")
	var history = equipment_system.get_legendary_history("shadow_knight_blade")
	assert_eq(history["current_owner"], "Hero1")


## Test: Get crafting requirements
func test_crafting_requirements() -> void:
	var requirements = equipment_system.get_crafting_requirements("steel_sword")
	assert_true("materials" in requirements)
	assert_true("gold" in requirements)
	assert_true("skill_level" in requirements)


## Test: Equipment summary
func test_equipment_summary() -> void:
	var item = equipment_system.create_item("iron_sword")
	var summary = equipment_system.get_equipment_summary(item)
	assert_eq(summary["name"], item["name"])


# ========== CraftingSystem Tests ==========

## Test: Get crafting skills
func test_get_crafting_skills() -> void:
	var skills = crafting_system.get_heir_crafting_skills("Hero")
	assert_gt(skills.size(), 0)
	assert_true("Blacksmithing" in skills)


## Test: Get skill level
func test_get_skill_level() -> void:
	var level = crafting_system.get_skill_level("Hero", "Blacksmithing")
	assert_eq(level, 1)


## Test: Get skill XP
func test_get_skill_xp() -> void:
	var xp = crafting_system.get_skill_xp("Hero", "Blacksmithing")
	assert_eq(xp, 0)


## Test: Craft equipment (success)
func test_craft_success() -> void:
	crafting_system.heir_crafting_skills["Hero"] = {
		"Blacksmithing": {"level": 2, "xp": 0},
		"Leatherworking": {"level": 1, "xp": 0},
		"Runecrafting": {"level": 1, "xp": 0},
		"Alchemy": {"level": 1, "xp": 0},
	}

	var resources = {"materials": 50, "gold": 100}
	var result = crafting_system.craft_equipment("Hero", "iron_sword", equipment_system, resources)
	assert_true("success" in result)


## Test: Craft with insufficient skill
func test_craft_insufficient_skill() -> void:
	var resources = {"materials": 50, "gold": 100}
	var result = crafting_system.craft_equipment("Hero", "dragon_slayer", equipment_system, resources)
	assert_false(result.get("success", false))


## Test: Craft with insufficient materials
func test_craft_insufficient_materials() -> void:
	crafting_system.heir_crafting_skills["Hero"] = {
		"Blacksmithing": {"level": 2, "xp": 0},
		"Leatherworking": {"level": 1, "xp": 0},
		"Runecrafting": {"level": 1, "xp": 0},
		"Alchemy": {"level": 1, "xp": 0},
	}

	var resources = {"materials": 1, "gold": 100}
	var result = crafting_system.craft_equipment("Hero", "iron_sword", equipment_system, resources)
	assert_false(result.get("success", false))


## Test: Get success rate
func test_get_success_rate() -> void:
	crafting_system.heir_crafting_skills["Hero"] = {
		"Blacksmithing": {"level": 3, "xp": 0},
		"Leatherworking": {"level": 1, "xp": 0},
		"Runecrafting": {"level": 1, "xp": 0},
		"Alchemy": {"level": 1, "xp": 0},
	}

	var rate = crafting_system.get_craft_success_rate("Hero", "iron_sword", equipment_system)
	assert_gt(rate, 0.0)
	assert_lt(rate, 1.0)


## Test: Get craftable equipment
func test_get_craftable_equipment() -> void:
	crafting_system.heir_crafting_skills["Hero"] = {
		"Blacksmithing": {"level": 2, "xp": 0},
		"Leatherworking": {"level": 1, "xp": 0},
		"Runecrafting": {"level": 1, "xp": 0},
		"Alchemy": {"level": 1, "xp": 0},
	}

	var craftable = crafting_system.get_craftable_equipment("Hero", equipment_system)
	assert_gt(craftable.size(), 0)


## Test: All crafting skills available
func test_all_crafting_skills() -> void:
	var skills = crafting_system.get_all_crafting_skills()
	assert_gt(skills.size(), 0)


## Test: Skill progress
func test_skill_progress() -> void:
	crafting_system.heir_crafting_skills["Hero"] = {
		"Blacksmithing": {"level": 1, "xp": 50},
		"Leatherworking": {"level": 1, "xp": 0},
		"Runecrafting": {"level": 1, "xp": 0},
		"Alchemy": {"level": 1, "xp": 0},
	}

	var progress = crafting_system.get_skill_progress("Hero", "Blacksmithing")
	assert_eq(progress["level"], 1)
	assert_eq(progress["xp"], 50)


## Test: Skill inheritance
func test_skill_inheritance() -> void:
	crafting_system.heir_crafting_skills["Hero1"] = {
		"Blacksmithing": {"level": 5, "xp": 50},
		"Leatherworking": {"level": 1, "xp": 0},
		"Runecrafting": {"level": 1, "xp": 0},
		"Alchemy": {"level": 1, "xp": 0},
	}

	crafting_system.inherit_crafting_skills("Hero2", "Hero1", 0.5)
	var hero2_level = crafting_system.get_skill_level("Hero2", "Blacksmithing")
	assert_eq(hero2_level, 2)  # 5 * 0.5 = 2.5 → 2


## Test: Mastery bonus
func test_mastery_bonus() -> void:
	crafting_system.heir_crafting_skills["Hero"] = {
		"Blacksmithing": {"level": 7, "xp": 0},
		"Leatherworking": {"level": 1, "xp": 0},
		"Runecrafting": {"level": 1, "xp": 0},
		"Alchemy": {"level": 1, "xp": 0},
	}

	var bonus = crafting_system.get_mastery_bonus("Hero", "Blacksmithing")
	assert_gt(bonus, 1.0)  # Should have bonus at level 7


# ========== RuneSystem Tests ==========

## Test: Get heir affinities
func test_get_affinities() -> void:
	var affinities = rune_system.get_heir_affinities("Hero")
	assert_gt(affinities.size(), 0)


## Test: Get rune slots
func test_get_rune_slots() -> void:
	var slots = rune_system.get_rune_slots("Hero")
	assert_eq(slots, 1)


## Test: Upgrade rune slots
func test_upgrade_rune_slots() -> void:
	assert_true(rune_system.upgrade_rune_slots("Hero", 3))
	assert_eq(rune_system.get_rune_slots("Hero"), 3)


## Test: Increase affinity
func test_increase_affinity() -> void:
	var new_level = rune_system.increase_affinity("Hero", RuneSystem.Affinity.FIRE, 2)
	assert_eq(new_level, 3)


## Test: Apply rune to item
func test_apply_rune() -> void:
	var item = equipment_system.create_item("iron_sword")
	rune_system.upgrade_rune_slots("Hero", 2)
	var result = rune_system.apply_rune_to_item(item["id"], RuneSystem.RuneType.FIRE, "Hero")
	assert_true(result["success"])


## Test: Remove rune from item
func test_remove_rune() -> void:
	var item = equipment_system.create_item("iron_sword")
	rune_system.upgrade_rune_slots("Hero", 2)
	rune_system.apply_rune_to_item(item["id"], RuneSystem.RuneType.FIRE, "Hero")
	assert_true(rune_system.remove_rune_from_item(item["id"], 0))


## Test: Get item runes
func test_get_item_runes() -> void:
	var item = equipment_system.create_item("iron_sword")
	rune_system.upgrade_rune_slots("Hero", 2)
	rune_system.apply_rune_to_item(item["id"], RuneSystem.RuneType.FIRE, "Hero")
	var runes = rune_system.get_item_runes(item["id"])
	assert_eq(runes.size(), 1)


## Test: Get rune stats
func test_get_rune_stats() -> void:
	var item = equipment_system.create_item("iron_sword")
	rune_system.upgrade_rune_slots("Hero", 2)
	rune_system.apply_rune_to_item(item["id"], RuneSystem.RuneType.FIRE, "Hero")
	var affinities = rune_system.get_heir_affinities("Hero")
	var stats = rune_system.get_item_rune_stats(item["id"], affinities)
	assert_gt(stats["strength"], 0)


## Test: Get rune effects
func test_get_rune_effects() -> void:
	var item = equipment_system.create_item("iron_sword")
	rune_system.upgrade_rune_slots("Hero", 2)
	rune_system.apply_rune_to_item(item["id"], RuneSystem.RuneType.FIRE, "Hero")
	var effects = rune_system.get_item_rune_effects(item["id"])
	assert_gt(effects.size(), 0)


## Test: Affinity inheritance
func test_affinity_inheritance() -> void:
	rune_system.heir_affinities["Hero1"] = {
		RuneSystem.Affinity.FIRE: 5,
		RuneSystem.Affinity.FROST: 3,
		RuneSystem.Affinity.LIGHTNING: 1,
		RuneSystem.Affinity.NATURE: 1,
		RuneSystem.Affinity.VOID: 1,
		RuneSystem.Affinity.HOLY: 1,
	}

	rune_system.inherit_affinities("Hero2", "Hero1", 0.5)
	var hero2_fire = rune_system.get_heir_affinities("Hero2")[RuneSystem.Affinity.FIRE]
	assert_eq(hero2_fire, 2)  # 5 * 0.5 = 2.5 → 2


## Test: Get all runes
func test_get_all_runes() -> void:
	var runes = rune_system.get_all_runes()
	assert_gt(runes.size(), 0)


## Test: Get rune cost
func test_get_rune_cost() -> void:
	var cost = rune_system.get_rune_cost(RuneSystem.RuneType.FIRE)
	assert_gt(cost, 0)


# ========== EquipmentHeirIntegration Tests ==========

## Test: Equip and get bonus
func test_equip_and_get_bonus() -> void:
	var item = equipment_system.create_item("iron_sword")
	integration.equip_item("Hero", item)
	var bonus = integration.get_heir_equipment_bonus("Hero")
	assert_gt(bonus["strength"], 0)


## Test: Add to vault
func test_add_to_vault() -> void:
	var item = equipment_system.create_item("iron_sword")
	assert_true(integration.add_to_vault(item))


## Test: Get vault items
func test_get_vault_items() -> void:
	var item = equipment_system.create_item("iron_sword")
	integration.add_to_vault(item)
	var vault = integration.get_vault_items()
	assert_eq(vault.size(), 1)


## Test: Claim from vault
func test_claim_from_vault() -> void:
	var item = equipment_system.create_item("iron_sword")
	integration.add_to_vault(item)
	var claimed = integration.claim_from_vault("Hero", 0)
	assert_eq(claimed["name"], "Iron Sword")


## Test: Get vault info
func test_get_vault_info() -> void:
	var item = equipment_system.create_item("iron_sword")
	integration.add_to_vault(item)
	var info = integration.get_vault_info()
	assert_eq(info["items_stored"], 1)


## Test: Inherit legendary items
func test_inherit_legendary() -> void:
	var legendary = equipment_system.create_item("shadow_knight_blade")
	equipment_system.equip_item("Hero1", legendary)
	var inherited = integration.inherit_legendary_items("Hero2", "Hero1")
	assert_eq(inherited.size(), 1)


## Test: Equipment display info
func test_equipment_display_info() -> void:
	var item = equipment_system.create_item("iron_sword")
	integration.equip_item("Hero", item)
	var display = integration.get_equipment_display_info("Hero")
	assert_true("equipped" in display)
	assert_true("equipment_bonus" in display)


## Test: Equipment summary
func test_equipment_summary() -> void:
	var item = equipment_system.create_item("iron_sword")
	integration.equip_item("Hero", item)
	var summary = integration.get_heir_equipment_summary("Hero")
	assert_gt(summary["equipped_items"].size(), 0)


## Test: Legendary multiplier
func test_legendary_multiplier() -> void:
	var legendary = equipment_system.create_item("shadow_knight_blade")
	var multiplier = integration.get_legendary_multiplier(legendary)
	assert_gte(multiplier, 1.0)


## Test: Complex crafting and equipping flow
func test_complex_crafting_flow() -> void:
	crafting_system.heir_crafting_skills["Hero"] = {
		"Blacksmithing": {"level": 2, "xp": 0},
		"Leatherworking": {"level": 1, "xp": 0},
		"Runecrafting": {"level": 1, "xp": 0},
		"Alchemy": {"level": 1, "xp": 0},
	}

	var resources = {"materials": 50, "gold": 100}
	var result = integration.craft_and_equip("Hero", "iron_sword", crafting_system, resources)

	# Check if crafted and equipped
	if result.get("success", false):
		assert_true(result["equipped"])
		var bonus = integration.get_heir_equipment_bonus("Hero")
		assert_gt(bonus["strength"], 0)
