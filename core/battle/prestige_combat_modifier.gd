## Prestige Combat Modifier: Apply prestige effects to combat calculations
##
## Scales damage, defense, critical chance, and other combat metrics based on prestige

extends Node

class_name PrestigeCombatModifier


signal damage_modified(base_damage: int, modified_damage: int, prestige_multiplier: float)
signal defense_modified(base_defense: int, modified_defense: int, prestige_multiplier: float)
signal critical_chance_modified(base_chance: float, modified_chance: float)
signal combat_stat_modified(stat_name: String, base_value: int, modified_value: int)


var combat_multiplier_thresholds: Dictionary = {
	0: 1.0,      # Bronze: 1.0x
	1000: 1.05,  # Silver: 1.05x
	5000: 1.1,   # Gold: 1.10x
	15000: 1.15, # Platinum: 1.15x
	35000: 1.2,  # Diamond: 1.20x
	75000: 1.25  # Eternal: 1.25x
}

var critical_damage_scaling: float = 0.01  # +1% per 100 prestige
var critical_chance_scaling: float = 0.001  # +0.1% per 100 prestige
var speed_scaling: float = 0.02  # +2% per 100 prestige
var defense_scaling: float = 0.015  # +1.5% per 100 prestige


class CombatModifiers:
	var prestige_level: int
	var damage_multiplier: float
	var defense_multiplier: float
	var critical_damage_bonus: float
	var critical_chance_bonus: float
	var speed_bonus: float
	var status_resistance: float

	func _init(p_prestige: int) -> void:
		prestige_level = p_prestige
		damage_multiplier = 1.0
		defense_multiplier = 1.0
		critical_damage_bonus = 0.0
		critical_chance_bonus = 0.0
		speed_bonus = 0.0
		status_resistance = 0.0


func _init() -> void:
	pass


func calculate_combat_modifiers(prestige_amount: int) -> CombatModifiers:
	var modifiers = CombatModifiers.new(prestige_amount)

	# Damage multiplier from prestige tier
	modifiers.damage_multiplier = _get_prestige_multiplier(prestige_amount)

	# Defense multiplier from prestige
	modifiers.defense_multiplier = 1.0 + (prestige_amount / 1000.0) * defense_scaling
	modifiers.defense_multiplier = min(modifiers.defense_multiplier, 2.0)  # Cap at 2.0x

	# Critical damage: +1% per 100 prestige (capped at +50%)
	modifiers.critical_damage_bonus = min(
		(prestige_amount / 100.0) * critical_damage_scaling,
		0.5
	)

	# Critical chance: +0.1% per 100 prestige (capped at +25%)
	modifiers.critical_chance_bonus = min(
		(prestige_amount / 100.0) * critical_chance_scaling,
		0.25
	)

	# Speed bonus: +2% per 100 prestige (capped at +100%)
	modifiers.speed_bonus = min(
		(prestige_amount / 100.0) * speed_scaling,
		1.0
	)

	# Status resistance: +0.5% per 100 prestige (capped at +50%)
	modifiers.status_resistance = min(
		(prestige_amount / 100.0) * 0.005,
		0.5
	)

	return modifiers


func apply_damage_modifier(base_damage: int, prestige_modifiers: CombatModifiers) -> int:
	var modified = int(base_damage * prestige_modifiers.damage_multiplier)
	damage_modified.emit(base_damage, modified, prestige_modifiers.damage_multiplier)
	return modified


func apply_defense_modifier(base_defense: int, prestige_modifiers: CombatModifiers) -> int:
	var modified = int(base_defense * prestige_modifiers.defense_multiplier)
	defense_modified.emit(base_defense, modified, prestige_modifiers.defense_multiplier)
	return modified


func calculate_modified_critical_damage(base_critical_damage: float, prestige_modifiers: CombatModifiers) -> float:
	return base_critical_damage + prestige_modifiers.critical_damage_bonus


func calculate_modified_critical_chance(base_critical_chance: float, prestige_modifiers: CombatModifiers) -> float:
	var modified = base_critical_chance + prestige_modifiers.critical_chance_bonus
	critical_chance_modified.emit(base_critical_chance, modified)
	return min(modified, 1.0)  # Cap at 100%


func apply_combat_stat_modifier(stat_name: String, base_value: int, prestige_modifiers: CombatModifiers) -> int:
	var multiplier = 1.0

	match stat_name:
		"strength", "attack":
			multiplier = prestige_modifiers.damage_multiplier
		"defense", "armor":
			multiplier = prestige_modifiers.defense_multiplier
		"speed", "initiative":
			multiplier = 1.0 + prestige_modifiers.speed_bonus
		"vitality", "health":
			multiplier = 1.0 + (prestige_modifiers.defense_multiplier - 1.0) * 0.5

	var modified = int(base_value * multiplier)
	combat_stat_modified.emit(stat_name, base_value, modified)
	return modified


func calculate_combat_advantage(attacker_prestige: int, defender_prestige: int) -> float:
	var attacker_multiplier = _get_prestige_multiplier(attacker_prestige)
	var defender_multiplier = _get_prestige_multiplier(defender_prestige)

	return attacker_multiplier / defender_multiplier


func get_prestige_tier_combat_bonus(prestige_tier: int) -> Dictionary:
	var bonuses = {
		0: {"damage": 1.0, "defense": 1.0, "ability_slots": 0},      # Bronze
		1: {"damage": 1.05, "defense": 1.05, "ability_slots": 1},    # Silver
		2: {"damage": 1.1, "defense": 1.1, "ability_slots": 2},      # Gold
		3: {"damage": 1.15, "defense": 1.15, "ability_slots": 2},    # Platinum
		4: {"damage": 1.2, "defense": 1.2, "ability_slots": 3},      # Diamond
		5: {"damage": 1.25, "defense": 1.25, "ability_slots": 3}     # Eternal
	}

	return bonuses.get(prestige_tier, bonuses[0])


func get_combat_modifier_description(prestige_modifiers: CombatModifiers) -> String:
	var desc = "Combat Prestige Modifiers (Prestige: %d):\n" % prestige_modifiers.prestige_level
	desc += "- Damage: %.2fx\n" % prestige_modifiers.damage_multiplier
	desc += "- Defense: %.2fx\n" % prestige_modifiers.defense_multiplier
	desc += "- Critical Damage: +%.1f%%\n" % (prestige_modifiers.critical_damage_bonus * 100)
	desc += "- Critical Chance: +%.1f%%\n" % (prestige_modifiers.critical_chance_bonus * 100)
	desc += "- Speed: +%.1f%%\n" % (prestige_modifiers.speed_bonus * 100)
	desc += "- Status Resistance: +%.1f%%\n" % (prestige_modifiers.status_resistance * 100)

	return desc


func _get_prestige_multiplier(prestige_amount: int) -> float:
	var multiplier = 1.0

	for threshold in combat_multiplier_thresholds.keys():
		if prestige_amount >= threshold:
			multiplier = combat_multiplier_thresholds[threshold]

	return multiplier
