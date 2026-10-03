## Encounter System: Random encounters based on world location
##
## Manages encounter types, difficulty scaling, enemy composition, and loot tables
## Encounters scale with heir stats and progression

class_name EncounterSystem


signal encounter_generated(encounter_id: String, encounter_type: String, difficulty: int)
signal loot_rolled(encounter_id: String, items: Array)


enum EncounterType { BANDITS, WILDLIFE, RUINS, CULT, MERCENARIES, UNDEAD }
enum Difficulty { EASY, NORMAL, HARD, EPIC, LEGENDARY }

# Encounter templates
var encounter_templates: Dictionary = {
	EncounterType.BANDITS: {
		"name": "Bandit Ambush",
		"enemy_count_range": [2, 4],
		"difficulty_base": 1.0,
		"enemy_classes": ["rogue", "warrior"],
		"loot_chance": 0.6,
	},
	EncounterType.WILDLIFE: {
		"name": "Wild Beasts",
		"enemy_count_range": [1, 3],
		"difficulty_base": 0.8,
		"enemy_classes": ["beast"],
		"loot_chance": 0.4,
	},
	EncounterType.RUINS: {
		"name": "Ruins Guardian",
		"enemy_count_range": [1, 2],
		"difficulty_base": 1.3,
		"enemy_classes": ["construct", "undead"],
		"loot_chance": 0.8,
	},
	EncounterType.CULT: {
		"name": "Cult Ritual",
		"enemy_count_range": [3, 5],
		"difficulty_base": 1.5,
		"enemy_classes": ["cultist", "mage"],
		"loot_chance": 0.7,
	},
	EncounterType.MERCENARIES: {
		"name": "Mercenary Band",
		"enemy_count_range": [2, 4],
		"difficulty_base": 1.4,
		"enemy_classes": ["warrior", "ranger"],
		"loot_chance": 0.75,
	},
	EncounterType.UNDEAD: {
		"name": "Undead Horde",
		"enemy_count_range": [3, 6],
		"difficulty_base": 1.2,
		"enemy_classes": ["undead", "skeleton"],
		"loot_chance": 0.65,
	},
}

# Tile type to encounter type mapping
var tile_encounter_map: Dictionary = {
	"GRASS": [EncounterType.BANDITS, EncounterType.WILDLIFE],
	"FOREST": [EncounterType.WILDLIFE, EncounterType.BANDITS],
	"WATER": [EncounterType.WILDLIFE],
	"MOUNTAIN": [EncounterType.RUINS, EncounterType.UNDEAD],
	"SETTLEMENT": [],  # No random encounters
	"DUNGEON": [EncounterType.RUINS, EncounterType.UNDEAD, EncounterType.CULT],
	"CAVE": [EncounterType.RUINS, EncounterType.WILDLIFE, EncounterType.UNDEAD],
	"DESERT": [EncounterType.BANDITS, EncounterType.RUINS],
}

# Loot tables by encounter type
var loot_tables: Dictionary = {
	EncounterType.BANDITS: {
		"gold_range": [50, 150],
		"xp_range": [30, 60],
		"items": ["leather_armor", "short_sword", "health_potion"],
		"rarity": "common",
	},
	EncounterType.WILDLIFE: {
		"gold_range": [30, 80],
		"xp_range": [20, 50],
		"items": ["fur", "bones", "health_potion"],
		"rarity": "common",
	},
	EncounterType.RUINS: {
		"gold_range": [100, 250],
		"xp_range": [60, 120],
		"items": ["ancient_coin", "enchanted_ring", "scroll"],
		"rarity": "rare",
	},
	EncounterType.CULT: {
		"gold_range": [150, 300],
		"xp_range": [80, 150],
		"items": ["cursed_artifact", "dark_grimoire", "cult_robe"],
		"rarity": "rare",
	},
	EncounterType.MERCENARIES: {
		"gold_range": [120, 280],
		"xp_range": [70, 140],
		"items": ["steel_sword", "iron_shield", "mercenary_badge"],
		"rarity": "uncommon",
	},
	EncounterType.UNDEAD: {
		"gold_range": [80, 200],
		"xp_range": [50, 120],
		"items": ["bone_dust", "tattered_cloak", "cursed_locket"],
		"rarity": "uncommon",
	},
}

# Active encounters
var active_encounters: Dictionary = {}  # encounter_id -> encounter data


## Generate random encounter at location
func generate_encounter(tile_type: String, heir_stats: Dictionary) -> Dictionary:
	var possible_types = tile_encounter_map.get(tile_type, [])
	if possible_types.is_empty():
		return {}

	var encounter_type = possible_types.pick_random()
	var encounter_id = "enc_%d" % Time.get_ticks_msec()

	var encounter = _build_encounter(encounter_id, encounter_type, heir_stats)
	active_encounters[encounter_id] = encounter

	encounter_generated.emit(encounter_id, EncounterType.keys()[encounter_type], encounter["difficulty"])
	return encounter


## Get active encounter
func get_encounter(encounter_id: String) -> Dictionary:
	return active_encounters.get(encounter_id, {})


## Determine encounter difficulty
func _determine_difficulty(heir_power: float, template_difficulty: float) -> int:
	var power_modifier = 0.7 + (heir_power / 30.0)  # 0.7 to 1.7 based on stats
	var final_difficulty = template_difficulty * power_modifier

	if final_difficulty < 1.2:
		return Difficulty.EASY
	elif final_difficulty < 1.8:
		return Difficulty.NORMAL
	elif final_difficulty < 2.5:
		return Difficulty.HARD
	elif final_difficulty < 3.5:
		return Difficulty.EPIC
	else:
		return Difficulty.LEGENDARY


## Build encounter with enemies
func _build_encounter(encounter_id: String, encounter_type: int, heir_stats: Dictionary) -> Dictionary:
	var template = encounter_templates.get(encounter_type, {})
	var heir_power = _calculate_heir_power(heir_stats)

	var difficulty = _determine_difficulty(heir_power, template.get("difficulty_base", 1.0))
	var enemy_count_range = template.get("enemy_count_range", [1, 2])
	var enemy_count = randi_range(enemy_count_range[0], enemy_count_range[1])

	# Adjust enemy count by difficulty
	if difficulty >= Difficulty.HARD:
		enemy_count += 1
	if difficulty >= Difficulty.EPIC:
		enemy_count += 1

	var enemies = []
	for i in range(enemy_count):
		var enemy = _generate_enemy(encounter_type, difficulty, heir_stats)
		enemies.append(enemy)

	var loot_table = loot_tables.get(encounter_type, {})

	return {
		"id": encounter_id,
		"type": encounter_type,
		"type_name": template.get("name", "Unknown"),
		"difficulty": difficulty,
		"difficulty_name": Difficulty.keys()[difficulty],
		"enemies": enemies,
		"enemy_count": enemy_count,
		"loot_chance": template.get("loot_chance", 0.5),
		"gold_range": loot_table.get("gold_range", [0, 0]),
		"xp_range": loot_table.get("xp_range", [0, 0]),
		"possible_items": loot_table.get("items", []),
		"rarity": loot_table.get("rarity", "common"),
		"created_at": Time.get_ticks_msec(),
	}


## Generate individual enemy
func _generate_enemy(encounter_type: int, difficulty: int, heir_stats: Dictionary) -> Dictionary:
	var template = encounter_templates.get(encounter_type, {})
	var enemy_classes = template.get("enemy_classes", ["warrior"])
	var enemy_class = enemy_classes.pick_random()

	# Scale enemy stats by difficulty
	var stat_multiplier = 0.8 + (difficulty * 0.3)  # 0.8 to 1.7
	var heir_avg_stat = _calculate_heir_power(heir_stats)

	return {
		"class": enemy_class,
		"name": _generate_enemy_name(enemy_class),
		"level": 1 + difficulty,
		"health": int(20 + (heir_avg_stat * 0.8) * stat_multiplier),
		"max_health": int(20 + (heir_avg_stat * 0.8) * stat_multiplier),
		"strength": int(max(1, (heir_avg_stat * 0.7) * stat_multiplier)),
		"dexterity": int(max(1, (heir_avg_stat * 0.6) * stat_multiplier)),
		"constitution": int(max(1, (heir_avg_stat * 0.8) * stat_multiplier)),
		"intelligence": int(max(1, (heir_avg_stat * 0.5) * stat_multiplier)),
		"wisdom": int(max(1, (heir_avg_stat * 0.5) * stat_multiplier)),
		"charisma": int(max(1, (heir_avg_stat * 0.4) * stat_multiplier)),
	}


## Roll loot from encounter
func roll_loot(encounter_id: String) -> Dictionary:
	if encounter_id not in active_encounters:
		return {}

	var encounter = active_encounters[encounter_id]

	# Check if loot drops
	if randf() > encounter["loot_chance"]:
		return {"gold": 0, "xp": 0, "items": []}

	var gold = randi_range(encounter["gold_range"][0], encounter["gold_range"][1])
	var xp = randi_range(encounter["xp_range"][0], encounter["xp_range"][1])

	var items = []
	if not encounter["possible_items"].is_empty():
		if randf() < 0.5:  # 50% chance for item
			var item = encounter["possible_items"].pick_random()
			items.append({
				"name": item,
				"rarity": encounter["rarity"],
			})

	loot_rolled.emit(encounter_id, items)

	return {
		"gold": gold,
		"xp": xp,
		"items": items,
	}


## Encounter completion (cleanup)
func complete_encounter(encounter_id: String) -> void:
	active_encounters.erase(encounter_id)


## Get encounter by tile type
func get_encounter_type_for_tile(tile_type: String) -> int:
	var possible = tile_encounter_map.get(tile_type, [])
	if possible.is_empty():
		return EncounterType.BANDITS
	return possible.pick_random()


## Internal: Calculate heir power
func _calculate_heir_power(stats: Dictionary) -> float:
	var sum = 0.0
	for stat_value in stats.values():
		sum += stat_value
	return sum / maxf(stats.size(), 1.0)


## Internal: Generate enemy name
func _generate_enemy_name(enemy_class: String) -> String:
	var names = {
		"warrior": ["Brute", "Thug", "Soldier", "Guard"],
		"rogue": ["Cutthroat", "Assassin", "Infiltrator", "Scout"],
		"mage": ["Sorcerer", "Wizard", "Cultist", "Spell-weaver"],
		"ranger": ["Archer", "Hunter", "Tracker", "Bowmaster"],
		"beast": ["Wolf", "Bear", "Dire Wolf", "Beast"],
		"construct": ["Golem", "Automaton", "Sentinel", "Guardian"],
		"undead": ["Zombie", "Wraith", "Ghoul", "Specter"],
		"skeleton": ["Bone Knight", "Skeletal Warrior", "Bone Archer", "Skull Guardian"],
		"cultist": ["Zealot", "Initiate", "Dark Priest", "Fanatic"],
	}

	var class_names = names.get(enemy_class, ["Enemy"])
	return class_names.pick_random()


## Get encounter summary
func get_encounter_summary(encounter_id: String) -> Dictionary:
	if encounter_id not in active_encounters:
		return {}

	var encounter = active_encounters[encounter_id]
	var enemy_names = []
	for enemy in encounter["enemies"]:
		enemy_names.append(enemy["name"])

	return {
		"id": encounter_id,
		"type": encounter["type_name"],
		"difficulty": encounter["difficulty_name"],
		"enemies": enemy_names,
		"loot_rarity": encounter["rarity"],
		"expected_gold": (encounter["gold_range"][0] + encounter["gold_range"][1]) / 2.0,
	}
