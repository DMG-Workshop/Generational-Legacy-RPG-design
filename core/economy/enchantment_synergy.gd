class_name EnchantmentSynergy

var rng: RandomNumberGenerator

const SYNERGY_PAIRS = {
	"sharpness_flaming": 1.1,
	"sharpness_frostbite": 1.1,
	"sharpness_lifesteal": 1.25,
	"sharpness_executioner": 1.15,
	"sharpness_swiftness": 1.2,
	"sharpness_wisdom": 1.05,
	"flaming_frostbite": 0.5,
	"flaming_lifesteal": 1.25,
	"flaming_executioner": 1.2,
	"flaming_fireward": 0.5,
	"flaming_swiftness": 1.05,
	"frostbite_lifesteal": 1.2,
	"frostbite_executioner": 1.15,
	"frostbite_frostward": 0.5,
	"frostbite_swiftness": 1.05,
	"lifesteal_executioner": 1.1,
	"lifesteal_fortitude": 1.15,
	"lifesteal_reflection": 1.2,
	"lifesteal_soulbound": 1.15,
	"lifesteal_bounty": 1.1,
	"executioner_swiftness": 1.15,
	"executioner_intellect": 1.1,
	"fortitude_fireward": 1.2,
	"fortitude_frostward": 1.2,
	"fortitude_reflection": 1.05,
	"fortitude_unbreakable": 1.15,
	"fortitude_swiftness": 0.9,
	"fireward_frostward": 0.75,
	"fireward_reflection": 1.1,
	"fireward_unbreakable": 1.05,
	"frostward_reflection": 1.1,
	"frostward_unbreakable": 1.05,
	"reflection_unbreakable": 1.2,
	"swiftness_wisdom": 1.1,
	"swiftness_intellect": 1.15,
	"swiftness_bounty": 1.05,
	"wisdom_intellect": 1.15,
	"wisdom_bounty": 0.95,
	"intellect_bounty": 1.05,
	"soulbound_cursed": 1.3,
	"soulbound_prophecy": 1.25,
	"cursed_prophecy": 0.8,
	"cursed_unbreakable": 0.85,
	"prophecy_lifesteal": 1.2,
}

const CATEGORY_SYNERGY_BONUSES = {
	Enchantment.EnchantmentType.OFFENSIVE: {
		Enchantment.EnchantmentType.OFFENSIVE: 1.05,
		Enchantment.EnchantmentType.DEFENSIVE: 1.1,
		Enchantment.EnchantmentType.UTILITY: 1.08,
		Enchantment.EnchantmentType.SPECIAL: 1.12
	},
	Enchantment.EnchantmentType.DEFENSIVE: {
		Enchantment.EnchantmentType.OFFENSIVE: 1.1,
		Enchantment.EnchantmentType.DEFENSIVE: 1.08,
		Enchantment.EnchantmentType.UTILITY: 1.02,
		Enchantment.EnchantmentType.SPECIAL: 1.1
	},
	Enchantment.EnchantmentType.UTILITY: {
		Enchantment.EnchantmentType.OFFENSIVE: 1.08,
		Enchantment.EnchantmentType.DEFENSIVE: 1.02,
		Enchantment.EnchantmentType.UTILITY: 1.05,
		Enchantment.EnchantmentType.SPECIAL: 1.1
	},
	Enchantment.EnchantmentType.SPECIAL: {
		Enchantment.EnchantmentType.OFFENSIVE: 1.12,
		Enchantment.EnchantmentType.DEFENSIVE: 1.1,
		Enchantment.EnchantmentType.UTILITY: 1.1,
		Enchantment.EnchantmentType.SPECIAL: 0.95
	}
}

func _init() -> void:
	rng = RandomNumberGenerator.new()

func score_combination(enchantments: Array[Enchantment]) -> float:
	if enchantments.is_empty() or enchantments.size() == 1:
		return 1.0

	var base_score = 1.0

	for i in range(enchantments.size()):
		for j in range(i + 1, enchantments.size()):
			var bonus = get_synergy_bonus(enchantments[i], enchantments[j])
			base_score *= bonus

	var count = enchantments.size()
	var diminishing_factor = pow(0.9, count - 1)
	var final_score = 1.0 + (base_score - 1.0) * diminishing_factor

	return final_score

func are_compatible(enchantment1: Enchantment, enchantment2: Enchantment) -> bool:
	var bonus = get_synergy_bonus(enchantment1, enchantment2)
	return bonus > 0.5

func get_synergy_bonus(enchantment1: Enchantment, enchantment2: Enchantment) -> float:
	var id1 = enchantment1.enchantment_id.to_lower()
	var id2 = enchantment2.enchantment_id.to_lower()

	var key1 = id1 + "_" + id2
	var key2 = id2 + "_" + id1

	if SYNERGY_PAIRS.has(key1):
		return SYNERGY_PAIRS[key1]
	elif SYNERGY_PAIRS.has(key2):
		return SYNERGY_PAIRS[key2]

	var type1 = enchantment1.enchantment_type
	var type2 = enchantment2.enchantment_type

	if CATEGORY_SYNERGY_BONUSES.has(type1):
		return CATEGORY_SYNERGY_BONUSES[type1].get(type2, 1.0)

	return 1.0

func get_synergy_description(score: float) -> String:
	if score >= 1.25:
		return "Perfect Synergy"
	elif score >= 1.15:
		return "Great Synergy"
	elif score >= 1.05:
		return "Good Synergy"
	elif score >= 0.95:
		return "Neutral"
	elif score >= 0.75:
		return "Poor Synergy"
	else:
		return "Conflicted"

func set_seed(seed_value: int) -> void:
	rng.seed = seed_value

func get_category_name(ench_type: int) -> String:
	match ench_type:
		Enchantment.EnchantmentType.OFFENSIVE:
			return "Offensive"
		Enchantment.EnchantmentType.DEFENSIVE:
			return "Defensive"
		Enchantment.EnchantmentType.UTILITY:
			return "Utility"
		Enchantment.EnchantmentType.SPECIAL:
			return "Special"
		_:
			return "Unknown"

func validate_set(enchantments: Array[Enchantment]) -> bool:
	for i in range(enchantments.size()):
		for j in range(i + 1, enchantments.size()):
			if not are_compatible(enchantments[i], enchantments[j]):
				return false
	return true

func find_best_pair(enchantments: Array[Enchantment]) -> Array:
	var best = []
	var best_score = 0.0

	for i in range(enchantments.size()):
		for j in range(i + 1, enchantments.size()):
			var score = get_synergy_bonus(enchantments[i], enchantments[j])
			if score > best_score:
				best_score = score
				best = [enchantments[i], enchantments[j], best_score]

	return best

func find_worst_pair(enchantments: Array[Enchantment]) -> Array:
	var worst = []
	var worst_score = 2.0

	for i in range(enchantments.size()):
		for j in range(i + 1, enchantments.size()):
			var score = get_synergy_bonus(enchantments[i], enchantments[j])
			if score < worst_score:
				worst_score = score
				worst = [enchantments[i], enchantments[j], worst_score]

	return worst

func get_synergy_report(enchantments: Array[Enchantment]) -> Dictionary:
	var report = {
		"total_score": score_combination(enchantments),
		"quality": get_synergy_description(score_combination(enchantments)),
		"is_valid": validate_set(enchantments),
		"pair_count": 0,
		"best_pair": [],
		"worst_pair": [],
		"incompatible_pairs": []
	}

	var pair_count = (enchantments.size() * (enchantments.size() - 1)) / 2
	report["pair_count"] = pair_count

	var best = find_best_pair(enchantments)
	if not best.is_empty():
		report["best_pair"] = {
			"name1": best[0].name,
			"name2": best[1].name,
			"score": best[2]
		}

	var worst = find_worst_pair(enchantments)
	if not worst.is_empty():
		report["worst_pair"] = {
			"name1": worst[0].name,
			"name2": worst[1].name,
			"score": worst[2]
		}

	for i in range(enchantments.size()):
		for j in range(i + 1, enchantments.size()):
			if not are_compatible(enchantments[i], enchantments[j]):
				report["incompatible_pairs"].append({
					"name1": enchantments[i].name,
					"name2": enchantments[j].name
				})

	return report

func filter_by_synergy_threshold(enchantments: Array[Enchantment], threshold: float) -> Array[Enchantment]:
	var filtered: Array[Enchantment] = []

	for ench in enchantments:
		var compatible = true
		for existing in filtered:
			if get_synergy_bonus(ench, existing) < threshold:
				compatible = false
				break
		if compatible:
			filtered.append(ench)

	return filtered

func select_synergistic_subset(enchantments: Array[Enchantment], max_count: int) -> Array[Enchantment]:
	if enchantments.size() <= max_count:
		return enchantments.duplicate()

	var best_subset: Array[Enchantment] = []
	var best_score = 0.0

	var indices = range(enchantments.size())
	var combinations = _generate_combinations(indices, max_count)

	for combo in combinations:
		var subset: Array[Enchantment] = []
		for idx in combo:
			subset.append(enchantments[idx])

		var score = score_combination(subset)
		if score > best_score:
			best_score = score
			best_subset = subset

	return best_subset

func _generate_combinations(items: Array, r: int) -> Array:
	if r == 0:
		return [[]]
	if items.is_empty():
		return []

	var first = items[0]
	var rest = items.slice(1)

	var with_first = []
	for combo in _generate_combinations(rest, r - 1):
		var new_combo = [first] + combo
		with_first.append(new_combo)

	var without_first = _generate_combinations(rest, r)

	return with_first + without_first
