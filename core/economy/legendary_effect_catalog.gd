## Legendary Effect Catalog: unique procedural effects for legendary items
##
## Combat, passive, and progression effects exclusive to legendary equipment

class_name LegendaryEffectCatalog


static var EFFECTS: Dictionary = {
	"temporal_echo": {
		"name": "Temporal Echo",
		"description": "Chance to hit twice in succession",
		"effect_type": "COMBAT",
		"proc_chance": 5,
		"scaling_formula": "base",
		"flavor_tags": ["LIGHT"]
	},
	"soulrend": {
		"name": "Soulrend",
		"description": "Damage scales with missing health of target",
		"effect_type": "COMBAT",
		"proc_chance": 100,
		"scaling_formula": "missing_health",
		"flavor_tags": ["VOID", "BLOOD"]
	},
	"bloodthirst_aura": {
		"name": "Bloodthirst Aura",
		"description": "Nearby allies gain +1 to attack rolls",
		"effect_type": "COMBAT",
		"proc_chance": 100,
		"scaling_formula": "base",
		"flavor_tags": ["BLOOD"]
	},
	"cascade": {
		"name": "Cascade",
		"description": "Critical hits reduce ability cooldowns",
		"effect_type": "COMBAT",
		"proc_chance": 25,
		"scaling_formula": "base",
		"flavor_tags": ["LIGHT"]
	},
	"generational_bond": {
		"name": "Generational Bond",
		"description": "Increase all stats by 1% per generation held",
		"effect_type": "PASSIVE",
		"proc_chance": 100,
		"scaling_formula": "generation",
		"flavor_tags": ["LIGHT"]
	},
	"ancestor_favor": {
		"name": "Ancestor's Favor",
		"description": "Restore 20% health after completing 3 battles",
		"effect_type": "PASSIVE",
		"proc_chance": 100,
		"scaling_formula": "base",
		"flavor_tags": ["LIGHT"]
	},
	"radiant_defiance": {
		"name": "Radiant Defiance",
		"description": "Successful blocks grant +10% damage on next turn",
		"effect_type": "PASSIVE",
		"proc_chance": 100,
		"scaling_formula": "base",
		"flavor_tags": ["LIGHT"]
	},
	"eternal_vigil": {
		"name": "Eternal Vigil",
		"description": "Equipment slot never degrades with age",
		"effect_type": "PASSIVE",
		"proc_chance": 100,
		"scaling_formula": "base",
		"flavor_tags": ["LIGHT"]
	},
	"heirloom_blessing": {
		"name": "Heirloom Blessing",
		"description": "Grant +5 XP per battle completed",
		"effect_type": "PROGRESSION",
		"proc_chance": 100,
		"scaling_formula": "base",
		"flavor_tags": ["LIGHT"]
	},
	"legendary_chain": {
		"name": "Legendary Chain",
		"description": "Increase maximum skill rank by 1",
		"effect_type": "PROGRESSION",
		"proc_chance": 100,
		"scaling_formula": "base",
		"flavor_tags": ["LIGHT"]
	},
	"generational_mastery": {
		"name": "Generational Mastery",
		"description": "Unlock forbidden skill one generation early",
		"effect_type": "PROGRESSION",
		"proc_chance": 100,
		"scaling_formula": "base",
		"flavor_tags": ["LIGHT"]
	},
	"vortex_strike": {
		"name": "Vortex Strike",
		"description": "Attacks pull nearby enemies closer",
		"effect_type": "COMBAT",
		"proc_chance": 15,
		"scaling_formula": "base",
		"flavor_tags": ["VOID"]
	},
	"inferno_wrath": {
		"name": "Inferno Wrath",
		"description": "Critical hits trigger fire explosion",
		"effect_type": "COMBAT",
		"proc_chance": 20,
		"scaling_formula": "base",
		"flavor_tags": ["FIRE"]
	},
	"glacial_prison": {
		"name": "Glacial Prison",
		"description": "Slowing effects increase damage taken by target",
		"effect_type": "COMBAT",
		"proc_chance": 100,
		"scaling_formula": "base",
		"flavor_tags": ["ICE"]
	},
	"lifebind": {
		"name": "Lifebind",
		"description": "Damage dealt heals all nearby allies",
		"effect_type": "PASSIVE",
		"proc_chance": 30,
		"scaling_formula": "base",
		"flavor_tags": ["BLOOD"]
	},
	"shattered_defenses": {
		"name": "Shattered Defenses",
		"description": "Each hit reduces target armor by 2%",
		"effect_type": "COMBAT",
		"proc_chance": 100,
		"scaling_formula": "base",
		"flavor_tags": ["VOID"]
	},
	"fortune_seeker": {
		"name": "Fortune Seeker",
		"description": "Increase gold and rare drops by 15%",
		"effect_type": "PASSIVE",
		"proc_chance": 100,
		"scaling_formula": "base",
		"flavor_tags": ["LIGHT"]
	},
	"unstoppable_force": {
		"name": "Unstoppable Force",
		"description": "Ignore movement restrictions, deal extra damage",
		"effect_type": "COMBAT",
		"proc_chance": 100,
		"scaling_formula": "base",
		"flavor_tags": ["VOID"]
	},
	"phoenix_rebirth": {
		"name": "Phoenix Rebirth",
		"description": "Restore to full health once per generation at death",
		"effect_type": "PASSIVE",
		"proc_chance": 100,
		"scaling_formula": "generation",
		"flavor_tags": ["FIRE"]
	},
	"legacy_echo": {
		"name": "Legacy Echo",
		"description": "Attacks gain effects from previous wielder's skills",
		"effect_type": "PASSIVE",
		"proc_chance": 50,
		"scaling_formula": "generation",
		"flavor_tags": ["LIGHT"]
	}
}


static func get_random_effect(seed_value: int, flavor: String = "") -> Dictionary:
	if seed_value > 0:
		seed(seed_value)

	var candidates: Array[String] = []

	if flavor.is_empty():
		candidates = EFFECTS.keys()
	else:
		for effect_id in EFFECTS.keys():
			if flavor in EFFECTS[effect_id]["flavor_tags"]:
				candidates.append(effect_id)

	if candidates.is_empty():
		candidates = EFFECTS.keys()

	var chosen = candidates[randi() % candidates.size()]
	return EFFECTS[chosen].duplicate()


static func get_effect_by_name(name: String) -> Dictionary:
	for effect_id in EFFECTS.keys():
		if EFFECTS[effect_id]["name"] == name:
			return EFFECTS[effect_id].duplicate()
	return {}


static func get_effects_by_type(effect_type: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for effect_id in EFFECTS.keys():
		if EFFECTS[effect_id]["effect_type"] == effect_type:
			results.append(EFFECTS[effect_id].duplicate())
	return results


static func scale_effect_description(effect: Dictionary, difficulty: int, item_type: String) -> String:
	var base_desc = effect["description"]
	var scaling = ""

	if difficulty > 5:
		scaling = " (Potent)"
	elif difficulty < 3:
		scaling = " (Weakened)"

	match effect["scaling_formula"]:
		"missing_health":
			scaling += " - Scales with target health deficit"
		"generation":
			scaling += " - Strengthens with each generation held"
		"base":
			pass

	return base_desc + scaling


static func get_all_effect_ids() -> Array[String]:
	return EFFECTS.keys()


static func get_effects_count() -> int:
	return EFFECTS.size()
