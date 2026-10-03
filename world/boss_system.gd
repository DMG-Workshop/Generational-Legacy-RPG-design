## Boss System: Boss encounters with special mechanics and progression
##
## Manages boss definitions, abilities, boss-specific rewards, and defeat tracking
## Bosses scale with heir progression and provide legendary rewards

class_name BossSystem


signal boss_encountered(boss_name: String, boss_tier: int)
signal boss_defeated(boss_name: String, heir_name: String, reward_value: int)
signal boss_ability_used(boss_name: String, ability_name: String)


enum BossTier { ELITE, EPIC, LEGENDARY, MYTHIC }

# Boss definitions
var boss_definitions: Dictionary = {
	"shadow_knight": {
		"tier": BossTier.EPIC,
		"level": 5,
		"health": 150,
		"strength": 18,
		"dexterity": 16,
		"constitution": 17,
		"intelligence": 14,
		"wisdom": 12,
		"charisma": 15,
		"abilities": ["shadow_strike", "dark_aura", "life_drain"],
		"loot": {
			"gold": 500,
			"xp": 300,
			"legendary_item": "Shadow Knight's Blade",
		},
		"difficulty_multiplier": 2.0,
		"description": "A fallen warrior clad in dark armor, commanded by malevolent shadows",
	},
	"frost_warden": {
		"tier": BossTier.EPIC,
		"level": 5,
		"health": 140,
		"strength": 15,
		"dexterity": 14,
		"constitution": 16,
		"intelligence": 18,
		"wisdom": 15,
		"charisma": 13,
		"abilities": ["ice_spear", "blizzard", "frozen_prison"],
		"loot": {
			"gold": 480,
			"xp": 280,
			"legendary_item": "Glacial Staff",
		},
		"difficulty_multiplier": 1.9,
		"description": "An ancient mage bound to the frozen peaks, wielding primal ice magic",
	},
	"dragon_whelp": {
		"tier": BossTier.LEGENDARY,
		"level": 8,
		"health": 250,
		"strength": 22,
		"dexterity": 18,
		"constitution": 20,
		"intelligence": 16,
		"wisdom": 16,
		"charisma": 17,
		"abilities": ["fire_breath", "wing_strike", "hoard_guardian"],
		"loot": {
			"gold": 1000,
			"xp": 600,
			"legendary_item": "Whelp's Fang",
		},
		"difficulty_multiplier": 3.0,
		"description": "A young dragon with devastating power, guarding its precious hoard",
	},
	"void_entity": {
		"tier": BossTier.MYTHIC,
		"level": 10,
		"health": 350,
		"strength": 20,
		"dexterity": 22,
		"constitution": 18,
		"intelligence": 25,
		"wisdom": 20,
		"charisma": 16,
		"abilities": ["reality_tear", "void_step", "mind_shatter", "existence_drain"],
		"loot": {
			"gold": 2000,
			"xp": 1000,
			"legendary_item": "Void Fragment",
		},
		"difficulty_multiplier": 4.0,
		"description": "A being of pure entropy, existing between dimensions",
	},
	"tyrant_king": {
		"tier": BossTier.LEGENDARY,
		"level": 7,
		"health": 200,
		"strength": 20,
		"dexterity": 17,
		"constitution": 19,
		"intelligence": 17,
		"wisdom": 14,
		"charisma": 19,
		"abilities": ["devastating_strike", "rally_troops", "royal_decree"],
		"loot": {
			"gold": 800,
			"xp": 500,
			"legendary_item": "Tyrant's Crown",
		},
		"difficulty_multiplier": 2.8,
		"description": "An immortal despot who rules with an iron fist, commanding legions",
	},
}

# Boss abilities
var ability_effects: Dictionary = {
	"shadow_strike": {"damage_multiplier": 1.8, "accuracy": 0.95, "cooldown": 2},
	"dark_aura": {"damage_reduction": 0.2, "duration": 3, "cooldown": 4},
	"life_drain": {"steal_health_percent": 0.3, "cooldown": 3},
	"ice_spear": {"damage_multiplier": 1.6, "armor_break": true, "cooldown": 2},
	"blizzard": {"area_damage": 0.4, "slow_effect": true, "cooldown": 4},
	"frozen_prison": {"stun_duration": 2, "cooldown": 5},
	"fire_breath": {"area_damage": 0.6, "cooldown": 3},
	"wing_strike": {"damage_multiplier": 2.0, "knockback": true, "cooldown": 2},
	"hoard_guardian": {"damage_reduction": 0.3, "attack_boost": 0.2, "cooldown": 4},
	"reality_tear": {"damage_multiplier": 2.5, "ignore_defense": true, "cooldown": 3},
	"void_step": {"evasion_boost": 0.5, "duration": 2, "cooldown": 3},
	"mind_shatter": {"confusion_effect": true, "cooldown": 4},
	"existence_drain": {"steal_health_percent": 0.5, "cooldown": 5},
	"devastating_strike": {"damage_multiplier": 2.2, "cooldown": 2},
	"rally_troops": {"damage_boost": 0.3, "ally_count": 2, "cooldown": 4},
	"royal_decree": {"stun_all": true, "duration": 1, "cooldown": 5},
}

# Boss defeat tracking
var boss_defeats: Dictionary = {}  # boss_name -> {"defeats": count, "last_defeated_by": heir_name, "last_defeat_time": timestamp}


## Get boss definition
func get_boss(boss_name: String) -> Dictionary:
	return boss_definitions.get(boss_name, {})


## Get all bosses
func get_all_bosses() -> Array[String]:
	return boss_definitions.keys()


## Get bosses by tier
func get_bosses_by_tier(tier: int) -> Array[String]:
	var bosses = []
	for boss_name in boss_definitions.keys():
		if boss_definitions[boss_name]["tier"] == tier:
			bosses.append(boss_name)
	return bosses


## Generate boss encounter
func generate_boss_encounter(boss_name: String, heir_stats: Dictionary) -> Dictionary:
	if boss_name not in boss_definitions:
		return {}

	var boss_def = boss_definitions[boss_name]
	var heir_power = _calculate_heir_power(heir_stats)

	# Scale boss difficulty based on heir power
	var scaling_factor = 0.8 + (heir_power / 25.0)  # 0.8 to 1.6
	var difficulty_multiplier = boss_def["difficulty_multiplier"] * scaling_factor

	var boss = {
		"name": boss_name,
		"display_name": _format_boss_name(boss_name),
		"tier": boss_def["tier"],
		"tier_name": BossTier.keys()[boss_def["tier"]],
		"level": int(boss_def["level"] * scaling_factor),
		"health": int(boss_def["health"] * scaling_factor),
		"max_health": int(boss_def["health"] * scaling_factor),
		"strength": int(boss_def["strength"] * scaling_factor),
		"dexterity": int(boss_def["dexterity"] * scaling_factor),
		"constitution": int(boss_def["constitution"] * scaling_factor),
		"intelligence": int(boss_def["intelligence"] * scaling_factor),
		"wisdom": int(boss_def["wisdom"] * scaling_factor),
		"charisma": int(boss_def["charisma"] * scaling_factor),
		"abilities": boss_def["abilities"],
		"description": boss_def["description"],
		"difficulty_multiplier": difficulty_multiplier,
		"encounter_id": "boss_%s_%d" % [boss_name, Time.get_ticks_msec()],
	}

	boss_encountered.emit(boss_name, boss_def["tier"])
	return boss


## Get boss ability effect
func get_ability_effect(ability_name: String) -> Dictionary:
	return ability_effects.get(ability_name, {})


## Resolve boss ability
func resolve_ability(boss_name: String, ability_name: String, target_stats: Dictionary) -> Dictionary:
	if ability_name not in ability_effects:
		return {}

	var effect = ability_effects[ability_name]
	var boss_stats = boss_definitions.get(boss_name, {})

	var result = {
		"ability": ability_name,
		"damage": 0,
		"special_effect": "",
		"effectiveness": 0.0,
	}

	# Calculate base damage from boss strength
	var base_damage = boss_stats.get("strength", 10) * 1.5
	if "damage_multiplier" in effect:
		result["damage"] = int(base_damage * effect["damage_multiplier"])

	# Add special effects to result
	for effect_key in effect.keys():
		if effect_key != "damage_multiplier" and effect_key != "cooldown":
			result["special_effect"] = effect_key
			break

	result["effectiveness"] = 0.7 + randf() * 0.3  # 70-100% effectiveness

	boss_ability_used.emit(boss_name, ability_name)
	return result


## Mark boss as defeated
func defeat_boss(boss_name: String, heir_name: String) -> Dictionary:
	if boss_name not in boss_definitions:
		return {}

	var boss_def = boss_definitions[boss_name]
	var loot = boss_def["loot"].duplicate()

	# Track defeat
	if boss_name not in boss_defeats:
		boss_defeats[boss_name] = {"defeats": 0, "last_defeated_by": "", "last_defeat_time": 0}

	boss_defeats[boss_name]["defeats"] += 1
	boss_defeats[boss_name]["last_defeated_by"] = heir_name
	boss_defeats[boss_name]["last_defeat_time"] = Time.get_ticks_msec()

	# Scale loot by tier
	var tier_multiplier = 1.0 + (boss_def["tier"] * 0.5)
	loot["gold"] = int(loot["gold"] * tier_multiplier)
	loot["xp"] = int(loot["xp"] * tier_multiplier)

	boss_defeated.emit(boss_name, heir_name, loot["gold"])
	return loot


## Get boss defeat history
func get_boss_history(boss_name: String) -> Dictionary:
	return boss_defeats.get(boss_name, {"defeats": 0, "last_defeated_by": "", "last_defeat_time": 0})


## Get boss difficulty rating for heir
func get_boss_difficulty_rating(boss_name: String, heir_stats: Dictionary) -> String:
	if boss_name not in boss_definitions:
		return "Unknown"

	var boss_def = boss_definitions[boss_name]
	var heir_power = _calculate_heir_power(heir_stats)
	var difficulty_multiplier = boss_def["difficulty_multiplier"]

	# Estimate if heir can defeat boss
	var power_ratio = heir_power / difficulty_multiplier

	if power_ratio < 0.5:
		return "Impossible"
	elif power_ratio < 0.8:
		return "Legendary"
	elif power_ratio < 1.0:
		return "Mythic"
	elif power_ratio < 1.3:
		return "Epic"
	elif power_ratio < 1.6:
		return "Hard"
	else:
		return "Challenging"


## Internal: Calculate heir power
func _calculate_heir_power(stats: Dictionary) -> float:
	var sum = 0.0
	for stat_value in stats.values():
		sum += stat_value
	return sum / maxf(stats.size(), 1.0)


## Internal: Format boss name for display
func _format_boss_name(name: String) -> String:
	var formatted = name.replace("_", " ")
	return formatted.capitalize()


## Get boss summary
func get_boss_summary(boss_name: String) -> Dictionary:
	if boss_name not in boss_definitions:
		return {}

	var boss_def = boss_definitions[boss_name]
	var defeat_history = boss_defeats.get(boss_name, {})

	return {
		"name": _format_boss_name(boss_name),
		"tier": BossTier.keys()[boss_def["tier"]],
		"level": boss_def["level"],
		"description": boss_def["description"],
		"abilities": boss_def["abilities"],
		"times_defeated": defeat_history.get("defeats", 0),
		"last_defeated_by": defeat_history.get("last_defeated_by", "Never"),
	}
