## Tests for ProceduralLegendaryItemGenerator
##
## Tests: legendary item generation, stat perfection, enchantment synergy, name generation

extends GutTest


## Test: Generate legendary item from scratch
func test_generate_legendary_basic() -> void:
	var item = ProceduralLegendaryItemGenerator.generate_legendary(12345, 5, "weapon", 1)

	assert_is(item, Equipment)
	assert_eq(item.rarity, Item.Rarity.LEGENDARY)
	assert_true(item.is_identified)
	assert_true(item.get_property("is_procedural_legendary"))
	assert_not_null(item.name)
	assert_not_null(item.description)


## Test: Perfect stats are generated correctly
func test_perfect_stats_in_range() -> void:
	var item = ProceduralLegendaryItemGenerator.generate_legendary(54321, 5, "weapon", 1)

	for stat in item.stat_bonuses:
		var value = item.stat_bonuses[stat]
		assert_gte(value, ProceduralLegendaryItemGenerator.MIN_SECONDARY_STAT, "Stat %s should be >= MIN_SECONDARY_STAT" % stat)
		assert_lte(value, ProceduralLegendaryItemGenerator.MAX_PERFECT_STAT, "Stat %s should be <= MAX_PERFECT_STAT" % stat)


## Test: Legendary items always have 4-5 enchantments
func test_legendary_enchantment_count() -> void:
	var item = ProceduralLegendaryItemGenerator.generate_legendary(99999, 5, "armor", 1)

	var enchantments = item.get_property("enchantments", [])
	assert_gte(enchantments.size(), ProceduralLegendaryItemGenerator.LEGENDARY_ENCHANTMENT_MIN)
	assert_lte(enchantments.size(), ProceduralLegendaryItemGenerator.LEGENDARY_ENCHANTMENT_MAX)


## Test: Upgrade item to legendary
func test_upgrade_to_legendary() -> void:
	var base_item = Equipment.new("test_item", "Base Equipment")
	base_item.rarity = Item.Rarity.RARE

	var upgraded = ProceduralLegendaryItemGenerator.upgrade_to_legendary(base_item, 11111, 5, 2)

	assert_eq(upgraded.rarity, Item.Rarity.LEGENDARY)
	assert_true(upgraded.is_identified)
	assert_true(upgraded.get_property("is_procedural_legendary"))


## Test: Synergy score meets minimum threshold
func test_synergy_score_threshold() -> void:
	var item = ProceduralLegendaryItemGenerator.generate_legendary(77777, 5, "weapon", 1)

	var synergy_score = item.get_property("legendary_synergy_score", 0.0)
	assert_gte(synergy_score, ProceduralLegendaryItemGenerator.MIN_SYNERGY_SCORE, "Synergy score should meet minimum threshold")


## Test: Soulbound eligibility check
func test_soulbound_eligibility() -> void:
	# Generate several items to see if any become soulbound (depends on effect)
	for i in range(10):
		var item = ProceduralLegendaryItemGenerator.generate_legendary(i * 1000, 5, "weapon", i + 1)
		var is_soulbound = item.get_property("soulbound", false)
		# Item may or may not be soulbound depending on the legendary effect

		if is_soulbound:
			assert_true(item.get_property("original_hero_generation") > 0)
			assert_true(item.get_property("cumulative_generation_bonus", -1) >= 0)


## Test: Legendary rate for difficulty
func test_legendary_rate_for_difficulty() -> void:
	var heroic_rate = ProceduralLegendaryItemGenerator.get_legendary_rate_for_difficulty(2)
	var legendary_rate = ProceduralLegendaryItemGenerator.get_legendary_rate_for_difficulty(6)

	assert_eq(heroic_rate, ProceduralLegendaryItemGenerator.BASE_HEROIC_LEGENDARY_RATE)
	assert_eq(legendary_rate, ProceduralLegendaryItemGenerator.BASE_LEGENDARY_LEGENDARY_RATE)
	assert_lt(heroic_rate, legendary_rate)


## Test: Can generate legendary roll
func test_can_generate_legendary() -> void:
	# With a heroic difficulty and seed, should have low chance
	var can_gen = ProceduralLegendaryItemGenerator.can_generate_legendary(1, 2)
	assert_is(can_gen, TYPE_BOOL)


## Test: Legendary item value calculation
func test_legendary_value_calculation() -> void:
	var base_value = 500
	var num_enchantments = 4
	var synergy_score = 0.9

	var value = ProceduralLegendaryItemGenerator.calculate_legendary_value(base_value, num_enchantments, synergy_score)

	assert_gt(value, base_value)
	# Value should be: 500 * 5.0 * (1 + 0.9 * 0.2) = 500 * 5.0 * 1.18 = 2950
	assert_eq(value, int(500 * 5.0 * (1 + 0.9 * 0.2)))


## Test: Seeded generation is reproducible
func test_seeded_generation_reproducible() -> void:
	var seed = 42424242
	var item1 = ProceduralLegendaryItemGenerator.generate_legendary(seed, 5, "weapon", 1)
	var item2 = ProceduralLegendaryItemGenerator.generate_legendary(seed, 5, "weapon", 1)

	assert_eq(item1.name, item2.name)
	assert_eq(item1.description, item2.description)
	assert_eq(item1.get_property("legendary_synergy_score"), item2.get_property("legendary_synergy_score"))


## Test: Select synergistic enchantments
func test_select_synergistic_enchantments() -> void:
	var enchantments = ProceduralLegendaryItemGenerator.select_synergistic_enchantments(55555, 5, 5)

	assert_eq(enchantments.size(), 5)

	for ench in enchantments:
		assert_is(ench, Enchantment)
		assert_not_empty(ench.enchantment_id)
