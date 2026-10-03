## Rune System: Equipment enchanting with affinities and slot progression
##
## Manages rune definitions, equipment slot upgrading, and affinity bonuses
## Runes provide stat bonuses and scale with heir affinity levels

class_name RuneSystem


signal rune_applied(item_id: String, rune_type: String)
signal affinity_increased(heir_name: String, affinity_type: String, new_level: int)


enum RuneType { FIRE, FROST, LIGHTNING, NATURE, VOID, HOLY }
enum Affinity { FIRE, FROST, LIGHTNING, NATURE, VOID, HOLY }

# Rune definitions
var rune_definitions: Dictionary = {
	RuneType.FIRE: {
		"name": "Fire Rune",
		"affinity": Affinity.FIRE,
		"base_stats": {"strength": 2, "intelligence": 1},
		"passive_effect": "deal 10% extra fire damage",
		"cost": 100,
	},
	RuneType.FROST: {
		"name": "Frost Rune",
		"affinity": Affinity.FROST,
		"base_stats": {"intelligence": 2, "wisdom": 1},
		"passive_effect": "slow enemy attacks by 20%",
		"cost": 100,
	},
	RuneType.LIGHTNING: {
		"name": "Lightning Rune",
		"affinity": Affinity.LIGHTNING,
		"base_stats": {"dexterity": 2, "intelligence": 1},
		"passive_effect": "100% chance to chain attacks",
		"cost": 100,
	},
	RuneType.NATURE: {
		"name": "Nature Rune",
		"affinity": Affinity.NATURE,
		"base_stats": {"wisdom": 2, "constitution": 1},
		"passive_effect": "regenerate 10% health per turn",
		"cost": 100,
	},
	RuneType.VOID: {
		"name": "Void Rune",
		"affinity": Affinity.VOID,
		"base_stats": {"intelligence": 3},
		"passive_effect": "ignore 20% of enemy defense",
		"cost": 150,
	},
	RuneType.HOLY: {
		"name": "Holy Rune",
		"affinity": Affinity.HOLY,
		"base_stats": {"wisdom": 3, "charisma": 1},
		"passive_effect": "heal allies for 15% of damage dealt",
		"cost": 150,
	},
}

# Heir affinities
var heir_affinities: Dictionary = {}  # heir_name -> {affinity_type -> level}

# Equipment rune slots (upgraded as heir progresses)
var equipment_rune_slots: Dictionary = {}  # heir_name -> max_slots (1-6)

# Applied runes per item
var item_runes: Dictionary = {}  # item_id -> [rune_types]


## Get heir affinities
func get_heir_affinities(heir_name: String) -> Dictionary:
	if heir_name not in heir_affinities:
		heir_affinities[heir_name] = _initialize_affinities()
	return heir_affinities[heir_name]


## Get rune slots available
func get_rune_slots(heir_name: String) -> int:
	return equipment_rune_slots.get(heir_name, 1)


## Upgrade rune slots
func upgrade_rune_slots(heir_name: String, new_slot_count: int) -> bool:
	new_slot_count = clampi(new_slot_count, 1, 6)
	equipment_rune_slots[heir_name] = new_slot_count
	return true


## Increase affinity level
func increase_affinity(heir_name: String, affinity_type: int, amount: int = 1) -> int:
	var affinities = get_heir_affinities(heir_name)
	if affinity_type not in affinities:
		return 0

	affinities[affinity_type] = mini(affinities[affinity_type] + amount, 10)
	affinity_increased.emit(heir_name, Affinity.keys()[affinity_type], affinities[affinity_type])
	return affinities[affinity_type]


## Apply rune to item
func apply_rune_to_item(item_id: String, rune_type: int, heir_name: String, heir_affinities_dict: Dictionary = {}) -> Dictionary:
	if rune_type not in rune_definitions:
		return {"success": false, "reason": "invalid_rune"}

	# Check if item has slot available
	if item_id not in item_runes:
		item_runes[item_id] = []

	var max_slots = get_rune_slots(heir_name)
	if item_runes[item_id].size() >= max_slots:
		return {"success": false, "reason": "no_slots_available"}

	var rune = rune_definitions[rune_type]
	item_runes[item_id].append(rune_type)

	rune_applied.emit(item_id, rune["name"])

	return {
		"success": true,
		"rune_name": rune["name"],
		"stats": rune["base_stats"],
		"effect": rune["passive_effect"],
	}


## Remove rune from item
func remove_rune_from_item(item_id: String, rune_slot: int) -> bool:
	if item_id not in item_runes:
		return false

	if rune_slot < 0 or rune_slot >= item_runes[item_id].size():
		return false

	item_runes[item_id].remove_at(rune_slot)
	return true


## Get runes on item
func get_item_runes(item_id: String) -> Array:
	return item_runes.get(item_id, [])


## Get rune stats for item
func get_item_rune_stats(item_id: String, heir_affinities_dict: Dictionary = {}) -> Dictionary:
	if item_id not in item_runes:
		return {}

	var stats = {
		"strength": 0,
		"dexterity": 0,
		"constitution": 0,
		"intelligence": 0,
		"wisdom": 0,
		"charisma": 0,
	}

	for rune_type in item_runes[item_id]:
		var rune = rune_definitions[rune_type]
		var base_stats = rune["base_stats"]

		# Apply affinity multiplier
		var affinity_level = heir_affinities_dict.get(rune["affinity"], 1)
		var affinity_multiplier = 1.0 + ((affinity_level - 1) * 0.1)

		for stat_key in base_stats.keys():
			if stat_key in stats:
				stats[stat_key] += int(base_stats[stat_key] * affinity_multiplier)

	return stats


## Get rune effects for item
func get_item_rune_effects(item_id: String) -> Array[String]:
	if item_id not in item_runes:
		return []

	var effects = []
	for rune_type in item_runes[item_id]:
		var rune = rune_definitions[rune_type]
		effects.append(rune["passive_effect"])

	return effects


## Get all runes
func get_all_runes() -> Array[String]:
	var runes = []
	for rune_type in rune_definitions.keys():
		runes.append(rune_definitions[rune_type]["name"])
	return runes


## Get rune cost
func get_rune_cost(rune_type: int) -> int:
	if rune_type in rune_definitions:
		return rune_definitions[rune_type]["cost"]
	return 0


## Inherit affinities to next heir (with penalty)
func inherit_affinities(heir_name: String, previous_heir_name: String, inheritance_multiplier: float = 0.5) -> void:
	if previous_heir_name not in heir_affinities:
		heir_affinities[heir_name] = _initialize_affinities()
		return

	var previous_affinities = heir_affinities[previous_heir_name]
	var inherited_affinities = _initialize_affinities()

	for affinity_type in previous_affinities.keys():
		var previous_level = previous_affinities[affinity_type]
		var inherited_level = int(previous_level * inheritance_multiplier)
		inherited_level = clampi(inherited_level, 1, 10)

		inherited_affinities[affinity_type] = inherited_level

	heir_affinities[heir_name] = inherited_affinities


## Combine runes (merge two items' runes for bonus)
func combine_runes(item_a_id: String, item_b_id: String) -> Array:
	var runes_a = item_runes.get(item_a_id, [])
	var runes_b = item_runes.get(item_b_id, [])

	var combined = []
	for rune in runes_a:
		combined.append(rune)
	for rune in runes_b:
		if rune not in combined:
			combined.append(rune)

	return combined


## Internal: Initialize affinities for heir
func _initialize_affinities() -> Dictionary:
	var affinities = {}
	for affinity_type in Affinity.values():
		affinities[affinity_type] = 1
	return affinities


## Get affinity summary
func get_affinity_summary(heir_name: String) -> Dictionary:
	var affinities = get_heir_affinities(heir_name)
	var summary = {}

	for affinity_type in affinities.keys():
		summary[Affinity.keys()[affinity_type]] = affinities[affinity_type]

	return summary


## Get rune info
func get_rune_info(rune_type: int) -> Dictionary:
	if rune_type not in rune_definitions:
		return {}

	var rune = rune_definitions[rune_type]
	return {
		"name": rune["name"],
		"affinity": Affinity.keys()[rune["affinity"]],
		"stats": rune["base_stats"],
		"effect": rune["passive_effect"],
		"cost": rune["cost"],
	}
