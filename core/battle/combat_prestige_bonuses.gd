## Combat Prestige Bonuses: Tier-based combat abilities and perks
##
## Unlock special abilities and combat enhancements based on prestige tier

extends Node

class_name CombatPrestigeBonus


signal ability_unlocked(tier: int, ability_name: String)
signal tier_bonus_granted(tier: int, heir_id: String)


enum CombatAbility { EXECUTE, RIPOSTE, RALLY, SHATTER_DEFENSE, LAST_STAND, DESTINY_STRIKE }

var tier_abilities: Dictionary = {
	0: [],  # Bronze: no special abilities
	1: [CombatAbility.RIPOSTE],  # Silver
	2: [CombatAbility.RIPOSTE, CombatAbility.RALLY],  # Gold
	3: [CombatAbility.RIPOSTE, CombatAbility.RALLY, CombatAbility.SHATTER_DEFENSE],  # Platinum
	4: [CombatAbility.EXECUTE, CombatAbility.RALLY, CombatAbility.SHATTER_DEFENSE, CombatAbility.LAST_STAND],  # Diamond
	5: [CombatAbility.EXECUTE, CombatAbility.RIPOSTE, CombatAbility.RALLY, CombatAbility.SHATTER_DEFENSE, CombatAbility.LAST_STAND, CombatAbility.DESTINY_STRIKE]  # Eternal
}

var ability_costs: Dictionary = {
	CombatAbility.EXECUTE: 30,
	CombatAbility.RIPOSTE: 15,
	CombatAbility.RALLY: 20,
	CombatAbility.SHATTER_DEFENSE: 25,
	CombatAbility.LAST_STAND: 35,
	CombatAbility.DESTINY_STRIKE: 50
}

var ability_effects: Dictionary = {
	CombatAbility.EXECUTE: {"damage_bonus": 1.5, "accuracy_bonus": 0.1},
	CombatAbility.RIPOSTE: {"counterattack": 1.0, "defense_bonus": 0.2},
	CombatAbility.RALLY: {"healing": 0.3, "buff_turn_duration": 2},
	CombatAbility.SHATTER_DEFENSE: {"armor_penetration": 0.5, "damage_bonus": 1.2},
	CombatAbility.LAST_STAND: {"health_threshold": 0.1, "damage_reduction": 0.8},
	CombatAbility.DESTINY_STRIKE: {"damage_bonus": 2.5, "critical_chance": 0.5}
}


class TierBonus:
	var tier: int
	var heir_id: String
	var abilities_unlocked: Array
	var damage_bonus: float
	var defense_bonus: float
	var health_bonus: float
	var status_resistance: float
	var ability_uses_per_combat: int

	func _init(p_tier: int, p_heir_id: String) -> void:
		tier = p_tier
		heir_id = p_heir_id
		abilities_unlocked = []
		damage_bonus = 0.0
		defense_bonus = 0.0
		health_bonus = 0.0
		status_resistance = 0.0
		ability_uses_per_combat = 2


func _init() -> void:
	pass


func calculate_tier_bonus(prestige_tier: int, heir_id: String) -> TierBonus:
	var bonus = TierBonus.new(prestige_tier, heir_id)

	# Add unlocked abilities for this tier
	if tier_abilities.has(prestige_tier):
		bonus.abilities_unlocked = tier_abilities[prestige_tier].duplicate()

	# Calculate stat bonuses by tier
	match prestige_tier:
		0:  # Bronze
			bonus.damage_bonus = 0.0
			bonus.defense_bonus = 0.0
			bonus.health_bonus = 0.0
			bonus.status_resistance = 0.0
			bonus.ability_uses_per_combat = 0
		1:  # Silver
			bonus.damage_bonus = 0.05
			bonus.defense_bonus = 0.05
			bonus.health_bonus = 0.05
			bonus.status_resistance = 0.1
			bonus.ability_uses_per_combat = 1
		2:  # Gold
			bonus.damage_bonus = 0.10
			bonus.defense_bonus = 0.10
			bonus.health_bonus = 0.10
			bonus.status_resistance = 0.2
			bonus.ability_uses_per_combat = 2
		3:  # Platinum
			bonus.damage_bonus = 0.15
			bonus.defense_bonus = 0.15
			bonus.health_bonus = 0.15
			bonus.status_resistance = 0.3
			bonus.ability_uses_per_combat = 2
		4:  # Diamond
			bonus.damage_bonus = 0.20
			bonus.defense_bonus = 0.20
			bonus.health_bonus = 0.20
			bonus.status_resistance = 0.4
			bonus.ability_uses_per_combat = 3
		5:  # Eternal
			bonus.damage_bonus = 0.25
			bonus.defense_bonus = 0.25
			bonus.health_bonus = 0.25
			bonus.status_resistance = 0.5
			bonus.ability_uses_per_combat = 3

	for ability in bonus.abilities_unlocked:
		ability_unlocked.emit(prestige_tier, CombatAbility.keys()[ability])

	tier_bonus_granted.emit(prestige_tier, heir_id)
	return bonus


func get_ability_description(ability: int) -> String:
	var name_map = {
		CombatAbility.EXECUTE: "Execute",
		CombatAbility.RIPOSTE: "Riposte",
		CombatAbility.RALLY: "Rally",
		CombatAbility.SHATTER_DEFENSE: "Shatter Defense",
		CombatAbility.LAST_STAND: "Last Stand",
		CombatAbility.DESTINY_STRIKE: "Destiny Strike"
	}

	var description_map = {
		CombatAbility.EXECUTE: "Deal 1.5x damage with guaranteed hit",
		CombatAbility.RIPOSTE: "Counterattack enemy attacks with +0.2x defense",
		CombatAbility.RALLY: "Heal 30% health and grant +1 buff",
		CombatAbility.SHATTER_DEFENSE: "Ignore 50% armor and deal 1.2x damage",
		CombatAbility.LAST_STAND: "Reduce all damage by 80% while health > 10%",
		CombatAbility.DESTINY_STRIKE: "Deal 2.5x damage with 50% critical chance"
	}

	var cost_map = {
		CombatAbility.EXECUTE: 30,
		CombatAbility.RIPOSTE: 15,
		CombatAbility.RALLY: 20,
		CombatAbility.SHATTER_DEFENSE: 25,
		CombatAbility.LAST_STAND: 35,
		CombatAbility.DESTINY_STRIKE: 50
	}

	var name = name_map.get(ability, "Unknown")
	var desc = description_map.get(ability, "")
	var cost = cost_map.get(ability, 0)

	return "%s (Cost: %d): %s" % [name, cost, desc]


func get_ability_effect(ability: int) -> Dictionary:
	return ability_effects.get(ability, {}).duplicate()


func get_ability_cost(ability: int) -> int:
	return ability_costs.get(ability, 0)


func is_ability_available_in_tier(ability: int, prestige_tier: int) -> bool:
	if not tier_abilities.has(prestige_tier):
		return false

	return ability in tier_abilities[prestige_tier]


func get_tier_bonus_description(tier_bonus: TierBonus) -> String:
	var tier_names = ["Bronze", "Silver", "Gold", "Platinum", "Diamond", "Eternal"]
	var name = tier_names[tier_bonus.tier] if tier_bonus.tier < tier_names.size() else "Unknown"

	var desc = "%s Tier Combat Bonuses (Heir: %s):\n" % [name, tier_bonus.heir_id]
	desc += "- Damage: +%.0f%%\n" % (tier_bonus.damage_bonus * 100)
	desc += "- Defense: +%.0f%%\n" % (tier_bonus.defense_bonus * 100)
	desc += "- Health: +%.0f%%\n" % (tier_bonus.health_bonus * 100)
	desc += "- Status Resistance: +%.0f%%\n" % (tier_bonus.status_resistance * 100)
	desc += "- Ability Uses/Combat: %d\n" % tier_bonus.ability_uses_per_combat

	if tier_bonus.abilities_unlocked.size() > 0:
		desc += "- Unlocked Abilities:\n"
		for ability in tier_bonus.abilities_unlocked:
			desc += "  * %s\n" % get_ability_description(ability)

	return desc


func get_all_tier_bonuses() -> Dictionary:
	var all_bonuses = {}

	for tier in tier_abilities.keys():
		all_bonuses[tier] = {
			"tier_name": ["Bronze", "Silver", "Gold", "Platinum", "Diamond", "Eternal"][tier],
			"abilities": tier_abilities[tier].duplicate(),
			"base_damage_bonus": [0.0, 0.05, 0.10, 0.15, 0.20, 0.25][tier],
			"base_defense_bonus": [0.0, 0.05, 0.10, 0.15, 0.20, 0.25][tier],
			"ability_uses": [0, 1, 2, 2, 3, 3][tier]
		}

	return all_bonuses


func calculate_combined_combat_bonus(prestige_tier: int, damage_multiplier: float, defense_multiplier: float) -> Dictionary:
	var tier_bonus = calculate_tier_bonus(prestige_tier, "")

	var combined = {
		"damage": (1.0 + tier_bonus.damage_bonus) * damage_multiplier,
		"defense": (1.0 + tier_bonus.defense_bonus) * defense_multiplier,
		"health": 1.0 + tier_bonus.health_bonus,
		"status_resistance": tier_bonus.status_resistance,
		"abilities": tier_bonus.abilities_unlocked.size()
	}

	return combined


func get_combat_prestige_bonus_stats() -> Dictionary:
	var stats = {
		"total_tiers": tier_abilities.size(),
		"total_abilities": 0,
		"abilities_by_tier": {},
		"highest_damage_bonus": 0.25,
		"highest_defense_bonus": 0.25
	}

	for tier in tier_abilities.keys():
		stats["total_abilities"] += tier_abilities[tier].size()
		stats["abilities_by_tier"][tier] = tier_abilities[tier].size()

	return stats
