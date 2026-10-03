## Procedural Legendary Item Generator: orchestrates legendary item creation
##
## Generates legendary items from scratch or upgrades existing magical items
## with perfect stats, synergistic enchantments, unique effects, and lore

class_name ProceduralLegendaryItemGenerator


const MIN_PERFECT_STAT = 95
const MAX_PERFECT_STAT = 100
const MIN_SECONDARY_STAT = 90
const LEGENDARY_ENCHANTMENT_MIN = 4
const LEGENDARY_ENCHANTMENT_MAX = 5
const MIN_SYNERGY_SCORE = 0.7
const MAX_SYNERGY_RETRIES = 3
const BASE_HEROIC_LEGENDARY_RATE = 0.005
const BASE_LEGENDARY_LEGENDARY_RATE = 0.01
const LEGENDARY_VALUE_MULTIPLIER = 5.0
const SYNERGY_VALUE_BOOST = 0.2


func generate_legendary(
	seed: int,
	difficulty: int,
	item_type: String = "Equipment",
	hero_generation: int = 1,
	defeated_enemy: String = ""
) -> Equipment:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	var item = Equipment.new()
	item.rarity = Item.Rarity.LEGENDARY

	apply_perfect_stats(item, seed, item_type)

	var enchantment_count = rng.randi_range(LEGENDARY_ENCHANTMENT_MIN, LEGENDARY_ENCHANTMENT_MAX)
	var enchantments = select_synergistic_enchantments(seed, enchantment_count, difficulty)
	item.set_property("enchantments", _enchantments_to_ids(enchantments))

	var synergy_score = _score_enchantments(enchantments)
	var retry_count = 0
	while synergy_score < MIN_SYNERGY_SCORE and retry_count < MAX_SYNERGY_RETRIES:
		enchantments = select_synergistic_enchantments(seed + retry_count + 1, enchantment_count, difficulty)
		item.set_property("enchantments", _enchantments_to_ids(enchantments))
		synergy_score = _score_enchantments(enchantments)
		retry_count += 1

	apply_legendary_effect(item, seed, "")

	var name_result = _generate_legendary_name(seed, item_type, enchantments, defeated_enemy)
	item.name = name_result.name
	item.description = name_result.lore

	if not item.tags:
		item.tags = []
	if "Legendary" not in item.tags:
		item.tags.append("Legendary")

	item.set_property("is_procedural_legendary", true)
	item.set_property("legendary_seed", seed)
	item.set_property("legendary_generation_index", hero_generation)
	item.set_property("legendary_synergy_score", synergy_score)
	item.set_property("generated_year", hero_generation * 20)

	set_soulbound_if_eligible(item, hero_generation)

	var base_value = _get_base_value_for_type(item_type)
	item.value = Currency.new(0, calculate_legendary_value(base_value, enchantment_count, synergy_score), 0, 0)

	item.is_identified = false

	return item


func upgrade_to_legendary(
	item: Equipment,
	seed: int,
	difficulty: int,
	hero_generation: int = 1,
	defeated_enemy: String = ""
) -> Equipment:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	apply_perfect_stats(item, seed, item.item_type if item.item_type else "Equipment")

	var existing_enchantments = _get_enchantments_from_item(item)
	var existing_enchantment_count = mini(2, existing_enchantments.size())
	var new_enchantment_count = rng.randi_range(
		LEGENDARY_ENCHANTMENT_MIN - existing_enchantment_count,
		LEGENDARY_ENCHANTMENT_MAX - existing_enchantment_count
	)

	var kept_enchantments = existing_enchantments.slice(0, existing_enchantment_count) if existing_enchantment_count > 0 else []
	var new_enchantments = select_synergistic_enchantments(seed, new_enchantment_count, difficulty)
	var all_enchantments = kept_enchantments + new_enchantments

	item.set_property("enchantments", _enchantments_to_ids(all_enchantments))

	var synergy_score = _score_enchantments(all_enchantments)
	var retry_count = 0
	while synergy_score < MIN_SYNERGY_SCORE and retry_count < MAX_SYNERGY_RETRIES:
		new_enchantments = select_synergistic_enchantments(seed + retry_count + 1, new_enchantment_count, difficulty)
		all_enchantments = kept_enchantments + new_enchantments
		item.set_property("enchantments", _enchantments_to_ids(all_enchantments))
		synergy_score = _score_enchantments(all_enchantments)
		retry_count += 1

	if not item.get_property("legendary_effect"):
		apply_legendary_effect(item, seed, "")

	var name_result = _generate_legendary_name(seed, item.item_type if item.item_type else "Equipment", all_enchantments, defeated_enemy)
	item.name = name_result.name
	item.description = name_result.lore

	item.rarity = Item.Rarity.LEGENDARY
	if not item.tags:
		item.tags = []
	if "Legendary" not in item.tags:
		item.tags.append("Legendary")

	item.set_property("is_procedural_legendary", true)
	item.set_property("legendary_seed", seed)
	item.set_property("legendary_generation_index", hero_generation)
	item.set_property("legendary_synergy_score", synergy_score)
	item.set_property("generated_year", hero_generation * 20)

	set_soulbound_if_eligible(item, hero_generation)

	var base_value = _get_base_value_for_type(item.item_type if item.item_type else "Equipment")
	item.value = Currency.new(0, calculate_legendary_value(base_value, all_enchantments.size(), synergy_score), 0, 0)

	item.is_identified = false

	return item


func can_generate_legendary(seed: int, difficulty: int) -> bool:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	var legendary_rate = get_legendary_rate_for_difficulty(difficulty)
	return rng.randf() < legendary_rate


func select_synergistic_enchantments(seed: int, count: int = 5, difficulty: int = 5) -> Array[Enchantment]:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	var selected: Array[Enchantment] = []

	var first = _select_random_enchantment_seeded(seed, difficulty)
	if first:
		selected.append(first)

	for i in range(1, count):
		var best_enchantment: Enchantment = null
		var best_score = -999.0

		for attempt in range(10):
			var candidate = _select_random_enchantment_seeded(seed + i * 100 + attempt, difficulty)
			if not candidate:
				continue

			var test_array = selected + [candidate]
			var score = _score_enchantments(test_array)

			if score > best_score:
				best_score = score
				best_enchantment = candidate

		if best_enchantment:
			selected.append(best_enchantment)

	return selected


func apply_perfect_stats(item: Equipment, seed: int, item_type: String) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	var stat_types = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]
	var primary_stat = _get_primary_stat_for_type(item_type)

	for stat in stat_types:
		var min_val = MIN_PERFECT_STAT
		var max_val = MAX_PERFECT_STAT

		if stat == primary_stat:
			min_val = maxi(97, MIN_PERFECT_STAT)
		else:
			min_val = MIN_SECONDARY_STAT

		item.stat_bonuses[stat] = rng.randi_range(min_val, max_val)


func apply_legendary_effect(item: Equipment, seed: int, theme: String = "") -> void:
	var effect = LegendaryEffectCatalog.get_random_effect(seed, theme)
	item.set_property("legendary_effect", effect)


func set_soulbound_if_eligible(item: Equipment, hero_generation: int) -> void:
	var effect = item.get_property("legendary_effect")
	if effect and effect is Dictionary:
		var flavor_tags = effect.get("flavor_tags", [])
		if "Bloodline" in flavor_tags or "Generational" in flavor_tags:
			item.set_property("soulbound", true)
			item.set_property("original_hero_generation", hero_generation)
			item.set_property("original_year", hero_generation * 20)
			item.set_property("cumulative_generation_bonus", 0)


static func get_legendary_rate_for_difficulty(difficulty: int) -> float:
	if difficulty <= 3:
		return BASE_HEROIC_LEGENDARY_RATE
	else:
		return BASE_LEGENDARY_LEGENDARY_RATE


static func calculate_legendary_value(base_value: int, num_enchantments: int, synergy_score: float) -> int:
	var value_multiplier = LEGENDARY_VALUE_MULTIPLIER * (1.0 + synergy_score * SYNERGY_VALUE_BOOST)
	return int(base_value * value_multiplier)


func _score_enchantments(enchantments: Array[Enchantment]) -> float:
	if enchantments.is_empty():
		return 1.0

	var synergy = EnchantmentSynergy.new()
	return synergy.score_combination(enchantments)


func _enchantments_to_ids(enchantments: Array[Enchantment]) -> Array[String]:
	var ids: Array[String] = []
	for ench in enchantments:
		ids.append(ench.enchantment_id)
	return ids


func _get_enchantments_from_item(item: Item) -> Array[Enchantment]:
	var ench_ids = item.get_property("enchantments")
	if not ench_ids or not (ench_ids is Array):
		return []

	var enchantments: Array[Enchantment] = []
	for ench_id in ench_ids:
		var ench = EnchantmentCatalog.create_enchantment(ench_id)
		if ench:
			enchantments.append(ench)

	return enchantments


func _select_random_enchantment_seeded(seed: int, difficulty: int) -> Enchantment:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	var legendary_chance = 0.15 if difficulty > 5 else 0.1
	var supreme_chance = 0.25
	var major_chance = 0.35
	var moderate_chance = 0.25
	var minor_chance = 0.05

	var rand = rng.randf()
	var selected_rarity = Enchantment.EnchantmentRarity.MINOR

	if rand < legendary_chance:
		selected_rarity = Enchantment.EnchantmentRarity.LEGENDARY
	elif rand < legendary_chance + supreme_chance:
		selected_rarity = Enchantment.EnchantmentRarity.SUPREME
	elif rand < legendary_chance + supreme_chance + major_chance:
		selected_rarity = Enchantment.EnchantmentRarity.MAJOR
	elif rand < legendary_chance + supreme_chance + major_chance + moderate_chance:
		selected_rarity = Enchantment.EnchantmentRarity.MODERATE

	return EnchantmentCatalog.get_random_enchantment(selected_rarity)


func _generate_legendary_name(
	seed: int,
	item_type: String,
	enchantments: Array[Enchantment],
	defeated_enemy: String
) -> Dictionary:
	var name = LegendaryNameGenerator.generate_name(seed, item_type)
	var lore = LegendaryNameGenerator.generate_lore(seed, defeated_enemy, enchantments, 1)

	return {
		"name": name,
		"lore": lore
	}


func _get_primary_stat_for_type(item_type: String) -> String:
	match item_type.to_lower():
		"weapon", "sword", "axe", "bow", "staff", "mace", "spear":
			return "strength"
		"armor", "chest", "plate":
			return "constitution"
		"grimoire", "staff", "book":
			return "intelligence"
		"boots", "gloves", "leggings":
			return "dexterity"
		"ring", "amulet", "necklace", "pendant":
			return "wisdom"
		_:
			return "strength"


func _get_base_value_for_type(item_type: String) -> int:
	match item_type.to_lower():
		"weapon", "sword", "axe", "bow", "mace", "spear":
			return 500
		"armor", "chest", "plate":
			return 400
		"grimoire", "staff", "book":
			return 350
		"boots", "gloves", "leggings":
			return 200
		"ring", "amulet", "necklace", "pendant":
			return 300
		_:
			return 250
