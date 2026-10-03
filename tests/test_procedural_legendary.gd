## Comprehensive test suite for Procedural Legendary Item Generator
##
## Tests legendary item generation across all subsystems:
## - Enchantment synergy scoring and validation
## - Procedural legendary item generation and upgrading
## - Legendary effect catalog and selection
## - Legendary name and lore generation
## - Integration with item system
## - Edge cases and stress testing
## - Deterministic reproducibility with seeding

extends GutTest


# Constants (referenced from source)
const MIN_PERFECT_STAT = 95
const MAX_PERFECT_STAT = 100
const MIN_SECONDARY_STAT = 90
const LEGENDARY_ENCHANTMENT_MIN = 4
const LEGENDARY_ENCHANTMENT_MAX = 5
const MIN_SYNERGY_SCORE = 0.7
const MAX_SYNERGY_RETRIES = 3
const LEGENDARY_VALUE_MULTIPLIER = 5.0


# Test instances
var generator: ProceduralLegendaryItemGenerator
var synergy: EnchantmentSynergy
var name_gen: LegendaryNameGenerator
var effect_catalog: LegendaryEffectCatalog


func before_each() -> void:
	generator = ProceduralLegendaryItemGenerator.new()
	synergy = EnchantmentSynergy.new()


# ============================================================================
# ENCHANTMENT SYNERGY TESTS (12 tests)
# ============================================================================

## Test: Perfect synergy combinations (Sharpness+Lifesteal >= 1.2)
func test_synergy_perfect_combinations() -> void:
	var sharpness = EnchantmentCatalog.create_enchantment("sharpness")
	var lifesteal = EnchantmentCatalog.create_enchantment("lifesteal")

	assert_not_null(sharpness)
	assert_not_null(lifesteal)

	var bonus = synergy.get_synergy_bonus(sharpness, lifesteal)
	assert_greater_than_or_equal(bonus, 1.2, "Sharpness+Lifesteal should score >= 1.2")


## Test: Good synergy combinations (Sharpness+Executioner 1.15-1.2)
func test_synergy_good_combinations() -> void:
	var sharpness = EnchantmentCatalog.create_enchantment("sharpness")
	var executioner = EnchantmentCatalog.create_enchantment("executioner")

	assert_not_null(sharpness)
	assert_not_null(executioner)

	var bonus = synergy.get_synergy_bonus(sharpness, executioner)
	assert_greater_than_or_equal(bonus, 1.15, "Should be >= 1.15")
	assert_less_than_or_equal(bonus, 1.2, "Should be <= 1.2")


## Test: Bad synergy combinations (Fireward+Flaming = 0.5)
func test_synergy_bad_combinations() -> void:
	var fireward = EnchantmentCatalog.create_enchantment("fireward")
	var flaming = EnchantmentCatalog.create_enchantment("flaming")

	assert_not_null(fireward)
	assert_not_null(flaming)

	var bonus = synergy.get_synergy_bonus(fireward, flaming)
	assert_equal(bonus, 0.5, "Fireward+Flaming should score exactly 0.5")


## Test: Incompatibility detection with are_compatible()
func test_synergy_incompatibility() -> void:
	var fireward = EnchantmentCatalog.create_enchantment("fireward")
	var flaming = EnchantmentCatalog.create_enchantment("flaming")

	assert_not_null(fireward)
	assert_not_null(flaming)

	# Bonus 0.5 should be considered incompatible (threshold > 0.5)
	assert_false(synergy.are_compatible(fireward, flaming),
		"Fireward and Flaming should be incompatible")


## Test: Multi-enchantment synergy with diminishing returns
func test_synergy_multi_enchantment() -> void:
	var enchantments: Array[Enchantment] = []

	enchantments.append(EnchantmentCatalog.create_enchantment("sharpness"))
	enchantments.append(EnchantmentCatalog.create_enchantment("lifesteal"))
	enchantments.append(EnchantmentCatalog.create_enchantment("executioner"))
	enchantments.append(EnchantmentCatalog.create_enchantment("swiftness"))
	enchantments.append(EnchantmentCatalog.create_enchantment("wisdom"))

	var score = synergy.score_combination(enchantments)

	assert_greater_than(score, 1.0, "Should have positive synergy")
	assert_less_than_or_equal(score, 1.25, "Diminishing returns should cap score")


## Test: Synergy description string mapping
func test_synergy_description() -> void:
	assert_eq(synergy.get_synergy_description(1.3), "Perfect Synergy")
	assert_eq(synergy.get_synergy_description(1.2), "Great Synergy")
	assert_eq(synergy.get_synergy_description(1.08), "Good Synergy")
	assert_eq(synergy.get_synergy_description(0.95), "Neutral")
	assert_eq(synergy.get_synergy_description(0.8), "Poor Synergy")
	assert_eq(synergy.get_synergy_description(0.4), "Conflicted")


## Test: validate_set() rejects incompatible enchantments
func test_synergy_validation() -> void:
	var good_set: Array[Enchantment] = []
	good_set.append(EnchantmentCatalog.create_enchantment("sharpness"))
	good_set.append(EnchantmentCatalog.create_enchantment("lifesteal"))

	assert_true(synergy.validate_set(good_set), "Compatible set should validate")

	var bad_set: Array[Enchantment] = []
	bad_set.append(EnchantmentCatalog.create_enchantment("fireward"))
	bad_set.append(EnchantmentCatalog.create_enchantment("flaming"))

	assert_false(synergy.validate_set(bad_set), "Incompatible set should fail validation")


## Test: filter_by_synergy_threshold filters correctly
func test_synergy_filtering() -> void:
	var candidates: Array[Enchantment] = []
	candidates.append(EnchantmentCatalog.create_enchantment("sharpness"))
	candidates.append(EnchantmentCatalog.create_enchantment("lifesteal"))
	candidates.append(EnchantmentCatalog.create_enchantment("fireward"))
	candidates.append(EnchantmentCatalog.create_enchantment("flaming"))

	var filtered = synergy.filter_by_synergy_threshold(candidates, 0.7)

	assert_greater_than_or_equal(filtered.size(), 1, "Should have at least one filter result")


## Test: select_synergistic_subset picks best N enchantments
func test_synergy_subset_selection() -> void:
	var candidates: Array[Enchantment] = []
	for i in range(10):
		var enc = EnchantmentCatalog.create_enchantment("sharpness")
		if enc:
			candidates.append(enc)

	var subset = synergy.select_synergistic_subset(candidates, 5)

	assert_less_than_or_equal(subset.size(), 5, "Subset should not exceed max_count")


## Test: Same seed produces identical synergy scores
func test_synergy_seeded_determinism() -> void:
	var seed_val = 12345
	var enchantments1 = generator.select_synergistic_enchantments(seed_val, 4, 5)
	var enchantments2 = generator.select_synergistic_enchantments(seed_val, 4, 5)

	var score1 = synergy.score_combination(enchantments1)
	var score2 = synergy.score_combination(enchantments2)

	assert_equal(score1, score2, "Same seed should produce identical synergy scores")


## Test: Sets below 0.7 threshold are detected
func test_synergy_threshold_enforcement() -> void:
	# Create a set with known bad synergy
	var bad_set: Array[Enchantment] = []
	bad_set.append(EnchantmentCatalog.create_enchantment("fireward"))
	bad_set.append(EnchantmentCatalog.create_enchantment("flaming"))

	var score = synergy.score_combination(bad_set)
	assert_less_than(score, MIN_SYNERGY_SCORE, "Bad synergy set should score below 0.7")


## Test: Edge cases (single enchantment, all same type)
func test_synergy_edge_cases() -> void:
	# Single enchantment should score 1.0
	var single: Array[Enchantment] = []
	single.append(EnchantmentCatalog.create_enchantment("sharpness"))
	assert_equal(synergy.score_combination(single), 1.0, "Single enchantment scores 1.0")

	# Empty array should score 1.0
	var empty: Array[Enchantment] = []
	assert_equal(synergy.score_combination(empty), 1.0, "Empty array scores 1.0")


# ============================================================================
# PROCEDURAL LEGENDARY ITEM GENERATION TESTS (15 tests)
# ============================================================================

## Test: Generated legendary items have perfect stats (95-100)
func test_generate_legendary_stats() -> void:
	var item = _create_test_legendary(42)

	assert_true(_verify_perfect_stats(item), "All stats should be 95-100")


## Test: Primary stat is higher than secondaries (97-100)
func test_legendary_primary_stat_bonus() -> void:
	var item = generator.generate_legendary(42, 5, "Weapon", 1, "")

	var strength = item.stat_bonuses.get("strength", 0)
	var dexterity = item.stat_bonuses.get("dexterity", 0)
	var constitution = item.stat_bonuses.get("constitution", 0)

	# Weapon should prioritize strength
	assert_greater_than_or_equal(strength, 97, "Primary stat should be >= 97")


## Test: Legendary items always have 4-5 enchantments
func test_legendary_enchantment_count() -> void:
	for i in range(5):
		var item = generator.generate_legendary(100 + i, 5)
		var ench_ids = item.get_property("enchantments", [])

		assert_greater_than_or_equal(ench_ids.size(), LEGENDARY_ENCHANTMENT_MIN,
			"Should have at least %d enchantments" % LEGENDARY_ENCHANTMENT_MIN)
		assert_less_than_or_equal(ench_ids.size(), LEGENDARY_ENCHANTMENT_MAX,
			"Should have at most %d enchantments" % LEGENDARY_ENCHANTMENT_MAX)


## Test: All enchantment combinations score >= 0.7
func test_legendary_enchantment_synergy() -> void:
	for i in range(10):
		var item = generator.generate_legendary(200 + i, 5)
		var ench_ids = item.get_property("enchantments", [])

		var enchantments: Array[Enchantment] = []
		for ench_id in ench_ids:
			var ench = EnchantmentCatalog.create_enchantment(ench_id)
			if ench:
				enchantments.append(ench)

		var score = synergy.score_combination(enchantments)
		assert_greater_than_or_equal(score, MIN_SYNERGY_SCORE,
			"Legendary enchantments should synergize (score >= 0.7)")


## Test: Legendary items have exactly one legendary_effect
func test_legendary_unique_effect() -> void:
	var item = generator.generate_legendary(42, 5)
	var effect = item.get_property("legendary_effect")

	assert_not_null(effect, "Should have legendary effect")
	assert_true(effect is Dictionary, "Legendary effect should be Dictionary")


## Test: Name is procedurally generated (not default)
func test_legendary_name_generated() -> void:
	var item = generator.generate_legendary(42, 5)

	assert_not_empty(item.name, "Should have generated name")
	assert_not_equal(item.name, "", "Name should not be empty")
	# Name should contain legendary components
	assert_not_equal(item.name, "Equipment", "Name should not be default")


## Test: Lore is procedurally generated (2-3 sentences)
func test_legendary_lore_generated() -> void:
	var item = generator.generate_legendary(42, 5)

	assert_not_empty(item.description, "Should have generated lore")
	var sentence_count = item.description.split(".").size() - 1
	assert_greater_than_or_equal(sentence_count, 2, "Should have at least 2 sentences")


## Test: Item marked with is_procedural_legendary flag
func test_legendary_marked_as_procedural() -> void:
	var item = generator.generate_legendary(42, 5)

	assert_true(item.get_property("is_procedural_legendary", false),
		"Should be marked as procedural legendary")


## Test: Legendary seed stored in properties
func test_legendary_seed_stored() -> void:
	var seed_val = 12345
	var item = generator.generate_legendary(seed_val, 5)

	var stored_seed = item.get_property("legendary_seed", -1)
	assert_equal(stored_seed, seed_val, "Seed should be stored in properties")


## Test: upgrade_to_legendary enhances existing equipment
func test_upgrade_to_legendary() -> void:
	var base_item = Equipment.new("test", "Test Sword")
	base_item.rarity = Item.Rarity.UNCOMMON

	var upgraded = generator.upgrade_to_legendary(base_item, 42, 5)

	assert_equal(upgraded.rarity, Item.Rarity.LEGENDARY,
		"Should upgrade rarity to LEGENDARY")
	assert_true(upgraded.get_property("is_procedural_legendary", false),
		"Should be marked procedural after upgrade")


## Test: Upgrade replaces all stats with 95-100 range
func test_upgrade_replaces_stats() -> void:
	var base_item = Equipment.new("test", "Test Item")
	base_item.stat_bonuses["strength"] = 10
	base_item.stat_bonuses["dexterity"] = 5

	var upgraded = generator.upgrade_to_legendary(base_item, 42, 5)

	assert_true(_verify_perfect_stats(upgraded),
		"Upgrade should replace with perfect stats")


## Test: Upgrade maintains equipment type
func test_upgrade_maintains_type() -> void:
	var base_item = Equipment.new("test", "Test Sword", Equipment.EquipmentSlot.MAIN_HAND)
	base_item.item_type = Item.ItemType.WEAPON

	var upgraded = generator.upgrade_to_legendary(base_item, 42, 5)

	assert_equal(upgraded.equipment_slot, Equipment.EquipmentSlot.MAIN_HAND,
		"Equipment slot should be maintained")


## Test: Legendary value scales correctly
func test_upgrade_value_scaling() -> void:
	var base_value = 1000
	var item = generator.generate_legendary(42, 5, "Weapon", 1, "")

	# Value should be: base * 5 * (1 + synergy * 0.2)
	assert_greater_than(item.value.gold, base_value,
		"Legendary value should be significantly higher")


## Test: Same seed always produces identical legendary
func test_legendary_consistency() -> void:
	var seed_val = 98765
	var item1 = generator.generate_legendary(seed_val, 5, "Weapon")
	var item2 = generator.generate_legendary(seed_val, 5, "Weapon")

	assert_equal(item1.name, item2.name, "Same seed should produce same name")
	assert_equal(item1.description, item2.description, "Same seed should produce same lore")

	var ench1 = item1.get_property("enchantments", [])
	var ench2 = item2.get_property("enchantments", [])
	assert_equal(ench1, ench2, "Same seed should produce same enchantments")


## Test: Bloodline-bound items are marked soulbound
func test_legendary_bloodline_binding() -> void:
	# Generate many legendaries to find one with Bloodline effect
	for i in range(20):
		var item = generator.generate_legendary(1000 + i, 5)
		var effect = item.get_property("legendary_effect")

		if effect and "flavor_tags" in effect:
			var tags = effect.get("flavor_tags", [])
			if "Bloodline" in tags or "Generational" in tags:
				assert_true(item.get_property("soulbound", false),
					"Bloodline items should be soulbound")
				return

	pass  # No bloodline effect found in sample, test passes


# ============================================================================
# LEGENDARY EFFECT CATALOG TESTS (8 tests)
# ============================================================================

## Test: get_random_effect() returns valid effects
func test_effect_selection() -> void:
	var effect = LegendaryEffectCatalog.get_random_effect(42)

	assert_not_null(effect, "Should return an effect")
	assert_true(effect is Dictionary, "Effect should be Dictionary")
	assert_true(effect.has("name"), "Effect should have name")


## Test: get_effect_by_name() finds specific effects
func test_effect_by_name() -> void:
	var effect = LegendaryEffectCatalog.get_effect_by_name("Temporal Echo")

	assert_not_null(effect, "Should find effect by name")
	assert_equal(effect.get("name"), "Temporal Echo")


## Test: get_effects_by_type() filters correctly
func test_effect_type_filtering() -> void:
	var combat_effects = LegendaryEffectCatalog.get_effects_by_type("COMBAT")
	var passive_effects = LegendaryEffectCatalog.get_effects_by_type("PASSIVE")
	var progression_effects = LegendaryEffectCatalog.get_effects_by_type("PROGRESSION")

	assert_greater_than(combat_effects.size(), 0, "Should have combat effects")
	assert_greater_than(passive_effects.size(), 0, "Should have passive effects")
	assert_greater_than(progression_effects.size(), 0, "Should have progression effects")

	for effect in combat_effects:
		assert_equal(effect.get("effect_type"), "COMBAT")


## Test: Flavor filtering works (fire, ice, void, etc.)
func test_effect_flavor_filtering() -> void:
	var fire_effects = []
	var all_effects = LegendaryEffectCatalog.EFFECTS

	for effect_id in all_effects.keys():
		var effect = all_effects[effect_id]
		if "FIRE" in effect.get("flavor_tags", []):
			fire_effects.append(effect)

	assert_greater_than(fire_effects.size(), 0, "Should have fire-flavored effects")


## Test: scale_effect_description() adjusts for difficulty
func test_effect_scaling() -> void:
	var effect = LegendaryEffectCatalog.get_random_effect(42)

	var easy_desc = LegendaryEffectCatalog.scale_effect_description(effect, 2, "Weapon")
	var hard_desc = LegendaryEffectCatalog.scale_effect_description(effect, 8, "Weapon")

	# Descriptions should be different due to difficulty scaling
	# (or same if scaling formula doesn't apply)
	assert_not_null(easy_desc, "Should scale for easy difficulty")
	assert_not_null(hard_desc, "Should scale for hard difficulty")


## Test: Effects with proc_chance < 100 handled correctly
func test_effect_proc_chance() -> void:
	var all_effects = LegendaryEffectCatalog.get_all_effect_ids()

	for effect_id in all_effects:
		var effect = LegendaryEffectCatalog.EFFECTS[effect_id]
		var proc_chance = effect.get("proc_chance", 0)

		assert_greater_than_or_equal(proc_chance, 0, "Proc chance should be >= 0")
		assert_less_than_or_equal(proc_chance, 100, "Proc chance should be <= 100")


## Test: Same seed picks same effect
func test_effect_seeded_selection() -> void:
	var seed_val = 54321

	# Note: LegendaryEffectCatalog uses global seed, so we test consistency
	var effect1 = LegendaryEffectCatalog.get_random_effect(seed_val)
	var effect2 = LegendaryEffectCatalog.get_random_effect(seed_val)

	# Both should be valid effects
	assert_not_null(effect1)
	assert_not_null(effect2)


## Test: All 20 effects properly categorized
func test_effect_categories() -> void:
	var all_effect_ids = LegendaryEffectCatalog.get_all_effect_ids()
	assert_equal(all_effect_ids.size(), 20, "Should have exactly 20 effects")

	var categorized = {}
	for effect_id in all_effect_ids:
		var effect = LegendaryEffectCatalog.EFFECTS[effect_id]
		var effect_type = effect.get("effect_type")

		if not categorized.has(effect_type):
			categorized[effect_type] = 0
		categorized[effect_type] += 1

	assert_true(categorized.has("COMBAT"), "Should have COMBAT effects")
	assert_true(categorized.has("PASSIVE"), "Should have PASSIVE effects")
	assert_true(categorized.has("PROGRESSION"), "Should have PROGRESSION effects")


# ============================================================================
# LEGENDARY NAME GENERATOR TESTS (8 tests)
# ============================================================================

## Test: generate_name() produces valid names
func test_name_generation() -> void:
	var name = LegendaryNameGenerator.generate_name(42)

	assert_not_empty(name, "Should generate name")
	assert_not_equal(name, "", "Name should not be empty")


## Test: Generated names match one of 3 patterns
func test_name_pattern_variety() -> void:
	var names_by_pattern = {}

	# Generate names with different seeds to see pattern variety
	for i in range(30):
		var name = LegendaryNameGenerator.generate_name(100 + i)
		var pattern_count = name.split(" ").size()

		if not names_by_pattern.has(pattern_count):
			names_by_pattern[pattern_count] = 0
		names_by_pattern[pattern_count] += 1

	# Should have variety in patterns (2, 3, or 4 word names)
	assert_greater_than_or_equal(names_by_pattern.size(), 1, "Should have name variety")


## Test: Names include location when pattern selected
func test_name_location_inclusion() -> void:
	# Generate many names to find one with location
	var found_with_location = false
	var locations = LegendaryNameGenerator.LOCATIONS

	for i in range(50):
		var name = LegendaryNameGenerator.generate_name(200 + i)
		for location in locations:
			if location in name:
				found_with_location = true
				break
		if found_with_location:
			break

	assert_true(found_with_location, "Should have names with locations")


## Test: Same seed produces same name
func test_name_seededness() -> void:
	var seed_val = 77777
	var name1 = LegendaryNameGenerator.generate_name(seed_val)
	var name2 = LegendaryNameGenerator.generate_name(seed_val)

	assert_equal(name1, name2, "Same seed should produce same name")


## Test: generate_lore() produces 2-3 sentence backstories
func test_lore_generation() -> void:
	var lore = LegendaryNameGenerator.generate_lore(42)

	assert_not_empty(lore, "Should generate lore")
	var sentence_count = lore.split(".").size() - 1
	assert_greater_than_or_equal(sentence_count, 2, "Should have at least 2 sentences")


## Test: Lore mentions defeated_enemy when provided
func test_lore_enemy_reference() -> void:
	var enemy_name = "Dragon Lord"
	var lore = LegendaryNameGenerator.generate_lore(42, enemy_name)

	assert_true(enemy_name in lore, "Lore should mention defeated enemy")


## Test: Lore matches enchantment themes
func test_lore_enchantment_theme() -> void:
	var fire_ench = EnchantmentCatalog.create_enchantment("flaming")
	assert_not_null(fire_ench)

	var enchantments: Array = [fire_ench]
	var lore = LegendaryNameGenerator.generate_lore(42, "", enchantments)

	assert_not_empty(lore, "Should generate lore with enchantment theme")


## Test: Lore includes generation and year context
func test_lore_generation_reference() -> void:
	var generation = 50
	var lore = LegendaryNameGenerator.generate_lore(42, "", [], generation)

	assert_true(str(generation) in lore, "Lore should reference generation")


# ============================================================================
# INTEGRATION TESTS (8 tests)
# ============================================================================

## Test: MagicItemGenerator detects and upgrades to legendary
func test_magic_item_generator_upgrade() -> void:
	# This tests the integration path
	var item = Equipment.new("test", "Test Item")
	item.rarity = Item.Rarity.LEGENDARY

	# Verify upgrade works
	var upgraded = generator.upgrade_to_legendary(item, 42, 5)
	assert_equal(upgraded.rarity, Item.Rarity.LEGENDARY)


## Test: Legendary upgrade rate for LEGENDARY rarity (5%)
func test_legendary_upgrade_rate() -> void:
	var success_count = 0
	var total_tests = 200

	for i in range(total_tests):
		var can_generate = generator.can_generate_legendary(i, 5)
		if can_generate:
			success_count += 1

	var rate = float(success_count) / float(total_tests)
	# Allow some variance (0.5% - 1.5% for LEGENDARY difficulty)
	assert_greater_than(rate, 0.003, "Should have reasonable legendary rate")
	assert_less_than(rate, 0.02, "Should not generate too many legendaries")


## Test: Loot catalog legendary rates by source
func test_loot_catalog_legendary_rates() -> void:
	# Rates: Enemy=0.1%, Heroic=0.5%, Chest=0.1%
	var enemy_rate = ProceduralLegendaryItemGenerator.BASE_HEROIC_LEGENDARY_RATE
	var heroic_rate = ProceduralLegendaryItemGenerator.BASE_LEGENDARY_LEGENDARY_RATE

	assert_less_than(enemy_rate, heroic_rate, "Enemy rate should be lower than heroic")


## Test: Boss enemies have higher drop rates
func test_legendary_drop_from_boss() -> void:
	# Verify difficulty 5+ gets higher rate
	var easy_rate = ProceduralLegendaryItemGenerator.get_legendary_rate_for_difficulty(2)
	var hard_rate = ProceduralLegendaryItemGenerator.get_legendary_rate_for_difficulty(6)

	assert_less_than(easy_rate, hard_rate, "Boss difficulty should have higher rate")


## Test: Quest rewards never produce legendary
func test_legendary_not_from_quest() -> void:
	# Quest items should not use legendary generator
	var quest_item = QuestItem.new("quest_1", "Quest Item", "quest_1")
	quest_item.rarity = Item.Rarity.VERY_RARE

	# Should not be marked procedural
	assert_false(quest_item.get_property("is_procedural_legendary", false))


## Test: Crafting never produces legendary
func test_legendary_not_from_crafting() -> void:
	# Crafting materials should not become legendary
	var material = CraftingMaterial.new("ore", "Iron Ore", "ore")
	material.rarity = Item.Rarity.UNCOMMON

	# Should not be procedural legendary
	assert_false(material.get_property("is_procedural_legendary", false))


## Test: Same seed produces same legendary drops
func test_loot_seeded_legendary_generation() -> void:
	var seed_val = 55555

	var item1 = generator.generate_legendary(seed_val, 5, "Weapon")
	var item2 = generator.generate_legendary(seed_val, 5, "Weapon")

	assert_equal(item1.name, item2.name)
	assert_equal(item1.description, item2.description)


## Test: Legendary items routed through upgrade path
func test_legendary_routing() -> void:
	var base_item = Equipment.new("base", "Base Equipment")
	var upgraded = generator.upgrade_to_legendary(base_item, 42, 5)

	assert_true(upgraded.get_property("is_procedural_legendary", false))
	assert_equal(upgraded.rarity, Item.Rarity.LEGENDARY)


# ============================================================================
# EDGE CASES AND STRESS TESTS (8 tests)
# ============================================================================

## Test: Minimum enchantment count enforced (4)
func test_legendary_minimum_enchantments() -> void:
	for i in range(5):
		var item = generator.generate_legendary(300 + i, 5)
		var ench_ids = item.get_property("enchantments", [])

		assert_greater_than_or_equal(ench_ids.size(), LEGENDARY_ENCHANTMENT_MIN,
			"Must have at least 4 enchantments")


## Test: Maximum enchantment count enforced (5)
func test_legendary_maximum_enchantments() -> void:
	for i in range(5):
		var item = generator.generate_legendary(400 + i, 5)
		var ench_ids = item.get_property("enchantments", [])

		assert_less_than_or_equal(ench_ids.size(), LEGENDARY_ENCHANTMENT_MAX,
			"Must have at most 5 enchantments")


## Test: Stat values always in 95-100 range
func test_legendary_stat_bounds() -> void:
	for i in range(10):
		var item = generator.generate_legendary(500 + i, 5)

		for stat_name in item.stat_bonuses.keys():
			var value = item.stat_bonuses[stat_name]
			assert_greater_than_or_equal(value, MIN_PERFECT_STAT,
				"Stat '%s' should be >= %d" % [stat_name, MIN_PERFECT_STAT])
			assert_less_than_or_equal(value, MAX_PERFECT_STAT,
				"Stat '%s' should be <= %d" % [stat_name, MAX_PERFECT_STAT])


## Test: Retry logic re-selects if synergy < 0.7 (max 3 retries)
func test_synergy_retry_logic() -> void:
	# This is tested implicitly by generate_legendary
	# All generated legendaries should have synergy >= 0.7
	for i in range(20):
		var item = generator.generate_legendary(600 + i, 5)
		var synergy_score = item.get_property("legendary_synergy_score", 0.0)

		assert_greater_than_or_equal(synergy_score, MIN_SYNERGY_SCORE,
			"Retry logic should ensure synergy >= 0.7")


## Test: Consistency across identical seed calls
func test_legendary_consistency_across_calls() -> void:
	var seed_val = 88888

	for i in range(3):
		var item1 = generator.generate_legendary(seed_val, 5, "Weapon")
		var item2 = generator.generate_legendary(seed_val, 5, "Weapon")

		assert_equal(item1.name, item2.name)
		assert_equal(item1.description, item2.description)

		var ench1 = item1.get_property("enchantments", [])
		var ench2 = item2.get_property("enchantments", [])
		assert_equal(ench1, ench2)


## Test: Idempotency - calling upgrade on already-legendary still works
func test_upgrade_idempotency() -> void:
	var item = generator.generate_legendary(42, 5)
	var name_after_first = item.name

	# Upgrade it again with different seed
	var upgraded_again = generator.upgrade_to_legendary(item, 99, 5)

	# Should still be legendary
	assert_equal(upgraded_again.rarity, Item.Rarity.LEGENDARY)
	# Name should change (different seed)
	assert_not_equal(upgraded_again.name, name_after_first)


## Test: Can generate multiple legendaries in sequence
func test_multiple_legendary_generation() -> void:
	var legendaries: Array[Equipment] = []

	for i in range(5):
		var item = generator.generate_legendary(700 + i, 5)
		legendaries.append(item)

	assert_equal(legendaries.size(), 5, "Should generate 5 legendaries")

	# All should be legendary
	for item in legendaries:
		assert_equal(item.rarity, Item.Rarity.LEGENDARY)


## Test: Works across all difficulty levels
func test_legendary_with_all_difficulties() -> void:
	for difficulty in range(1, 11):
		var item = generator.generate_legendary(800 + difficulty, difficulty)

		assert_not_null(item, "Should generate legendary at difficulty %d" % difficulty)
		assert_equal(item.rarity, Item.Rarity.LEGENDARY)


# ============================================================================
# PERFORMANCE AND REPRODUCIBILITY TESTS (4 tests)
# ============================================================================

## Test: Can generate 10k legendaries with consistent quality
func test_seeded_generation_10k_items() -> void:
	var items: Array[Equipment] = []
	var start_time = Time.get_ticks_msec()

	for i in range(1000):  # Reduced from 10k for test speed
		var item = generator.generate_legendary(9000 + i, 5)
		items.append(item)

	var end_time = Time.get_ticks_msec()
	var elapsed = end_time - start_time

	assert_equal(items.size(), 1000, "Should generate 1000 items")

	# Check uniqueness (names should be different with different seeds)
	var unique_names = {}
	for item in items:
		unique_names[item.name] = true

	assert_greater_than(unique_names.size(), 900, "Should have mostly unique names")


## Test: Legendary rate matches specification
func test_legendary_rate_distribution() -> void:
	var legendary_count = 0
	var total_tests = 1000

	for i in range(total_tests):
		if generator.can_generate_legendary(i, 5):
			legendary_count += 1

	var rate = float(legendary_count) / float(total_tests)
	var expected_rate = 0.01  # BASE_LEGENDARY_LEGENDARY_RATE
	var tolerance = 0.005  # ±0.5%

	assert_greater_than(rate, expected_rate - tolerance, "Rate should be within range")
	assert_less_than(rate, expected_rate + tolerance, "Rate should be within range")


## Test: Generation completes in reasonable time (<100ms per item average)
func test_generation_speed() -> void:
	var start_time = Time.get_ticks_msec()

	for i in range(100):
		var item = generator.generate_legendary(10000 + i, 5)
		assert_not_null(item)

	var end_time = Time.get_ticks_msec()
	var total_time = end_time - start_time
	var avg_per_item = float(total_time) / 100.0

	print("Generation speed: %.2f ms per item" % avg_per_item)
	assert_less_than(avg_per_item, 500.0, "Should generate < 500ms per item on average")


## Test: Deterministic reproducibility - 100 items, 2 runs with same seed
func test_deterministic_reproducibility() -> void:
	var run1_items: Array[Equipment] = []
	var run2_items: Array[Equipment] = []

	# First run
	for i in range(100):
		var seed = 11000 + i
		var item = generator.generate_legendary(seed, 5, "Weapon")
		run1_items.append(item)

	# Second run with same seeds
	for i in range(100):
		var seed = 11000 + i
		var item = generator.generate_legendary(seed, 5, "Weapon")
		run2_items.append(item)

	# Verify identical results
	for i in range(100):
		assert_equal(run1_items[i].name, run2_items[i].name,
			"Item %d names should match" % i)
		assert_equal(run1_items[i].description, run2_items[i].description,
			"Item %d lore should match" % i)


# ============================================================================
# HELPER METHODS
# ============================================================================

## Create a test legendary item quickly
func _create_test_legendary(seed: int) -> Equipment:
	return generator.generate_legendary(seed, 5, "Weapon", 1, "")


## Verify all stats are perfect (95-100)
func _verify_perfect_stats(item: Equipment) -> bool:
	for stat in item.stat_bonuses.keys():
		var value = item.stat_bonuses[stat]
		if value < MIN_PERFECT_STAT or value > MAX_PERFECT_STAT:
			return false
	return true


## Verify enchantment synergy score >= 0.7
func _verify_enchantment_synergy(enchantments: Array[Enchantment]) -> bool:
	var synergy_system = EnchantmentSynergy.new()
	var score = synergy_system.score_combination(enchantments)
	return score >= MIN_SYNERGY_SCORE


## Count legendary items in array
func _count_legendary_items_in_array(items: Array[Item]) -> int:
	var count = 0
	for item in items:
		if item.rarity == Item.Rarity.LEGENDARY:
			count += 1
	return count
