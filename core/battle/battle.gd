## Layered combat engine (no rendering)
##
## Turn-based side-view battle system with:
## - Front/back row positioning
## - Class mechanics (stances, spell-weaving, oath meter, etc.)
## - Keystones (special rules that rewrite combat)
## - Trait effects
## - Equipment and job effects
## - Era modifiers (ley strength, wild magic surges, etc.)

extends Node

class_name Battle


## Combat state
class CombatState:
	var party: Array[Combatant] = []
	var enemies: Array[Combatant] = []
	var turn_order: Array[Combatant] = []
	var current_turn_index: int = 0
	var round: int = 1
	var is_player_turn: bool = true
	var battle_over: bool = false
	var player_won: bool = false
	var elapsed_time: float = 0.0


class Combatant:
	var name: String = ""
	var class_id: String = ""
	var job_id: String = ""
	var faction: String = "party"  # "party" or "enemy"

	var hp: int = 100
	var max_hp: int = 100
	var mp: int = 50
	var max_mp: int = 50

	var row: String = "front"  # "front" or "back"
	var is_alive: bool = true

	var stats: Dictionary = {
		"strength": 10,
		"dexterity": 10,
		"constitution": 10,
		"intelligence": 10,
		"wisdom": 10,
		"charisma": 10,
	}

	var traits: Array[String] = []
	var equipment: Array[String] = []

	# Class-specific mechanics
	var rage_meter: float = 0.0  # Martial classes
	var spell_queue: Array[String] = []  # Arcane classes
	var oath_meter: float = 0.0  # Divine classes
	var beast_form: String = ""  # Primal classes
	var active_spells: Array[String] = []  # Craft classes

	# Battle state
	var buffs: Dictionary = {}
	var debuffs: Dictionary = {}
	var active_surfaces: Array[String] = []  # Elemental surfaces


var state: CombatState


func _init() -> void:
	state = CombatState.new()


## Start a battle between party and enemies
func start_battle(party_members: Array[Combatant], enemies: Array[Combatant]) -> void:
	state.party = party_members
	state.enemies = enemies
	state.battle_over = false
	state.player_won = false
	state.round = 1

	_calculate_turn_order()


## Calculate turn order based on speed/dexterity
func _calculate_turn_order() -> void:
	state.turn_order.clear()

	for combatant in state.party + state.enemies:
		if combatant.is_alive:
			state.turn_order.append(combatant)

	# Sort by speed (dexterity + haste effects)
	state.turn_order.sort_custom(func(a, b): return a.stats["dexterity"] > b.stats["dexterity"])


## Execute one turn of combat
func execute_turn(combatant: Combatant, action: String, target: Combatant = null) -> Dictionary:
	if not combatant.is_alive:
		return {"success": false, "reason": "Combatant is dead"}

	var result = {"action": action, "actor": combatant, "target": target}

	match action:
		"attack":
			result["damage"] = _calculate_damage(combatant, target)
			result["critical"] = _check_critical(combatant)
			_apply_damage(target, result["damage"], result["critical"])

		"defend":
			result["defense_boost"] = 0.5
			combatant.buffs["defend"] = 1

		"cast_spell":
			result["spell"] = target  # Using target as spell ID for simplicity
			result["mp_cost"] = _get_spell_cost(target)
			if combatant.mp >= result["mp_cost"]:
				combatant.mp -= result["mp_cost"]
				result["success"] = true
			else:
				result["success"] = false
				result["reason"] = "Not enough MP"

		"use_item":
			result["item"] = target  # Using target as item ID
			result["success"] = true

		"stance":
			_apply_stance(combatant, target)
			result["success"] = true

	# Update meters
	_update_class_mechanics(combatant, action)

	# Check battle end
	_check_battle_end()

	return result


## Calculate damage from attacker to defender
func _calculate_damage(attacker: Combatant, defender: Combatant) -> int:
	var base_damage = attacker.stats["strength"] * 2
	var defense = defender.stats["constitution"]

	# Row modifier: back row takes reduced melee damage
	if defender.row == "back":
		defense += 5

	# Trait modifiers
	if "warriors_steel" in attacker.traits:
		base_damage += int(base_damage * 0.30)

	if "mageblood" in attacker.traits:
		base_damage += int(base_damage * 0.20)

	var final_damage = max(1, base_damage - defense)

	# Job modifier (Blacksmith can repair instead of damage, etc.)
	if attacker.job_id == "blacksmith":
		final_damage = int(final_damage * 1.1)  # +10% damage

	return final_damage


## Check for critical hit
func _check_critical(attacker: Combatant) -> bool:
	var base_crit = 5  # 5% base
	var dex_bonus = attacker.stats["dexterity"] - 10
	var crit_chance = base_crit + dex_bonus

	return randf() * 100 < crit_chance


## Apply damage to defender
func _apply_damage(defender: Combatant, damage: int, is_critical: bool) -> void:
	var final_damage = damage
	if is_critical:
		final_damage = int(damage * 1.5)

	defender.hp -= final_damage
	if defender.hp <= 0:
		defender.hp = 0
		defender.is_alive = false


## Get MP cost for a spell
func _get_spell_cost(spell_id: String) -> int:
	# TODO: Load from spell database
	return 20  # Default cost


## Apply a stance (Martial class mechanic)
func _apply_stance(combatant: Combatant, stance_id: String) -> void:
	match stance_id:
		"offensive":
			combatant.buffs["offense"] = 1.5
			combatant.buffs["defense"] = 0.7
		"defensive":
			combatant.buffs["offense"] = 0.7
			combatant.buffs["defense"] = 1.5
		"counter":
			combatant.buffs["counter_chance"] = 0.3


## Update class-specific mechanics after action
func _update_class_mechanics(combatant: Combatant, action: String) -> void:
	# Martial: rage meter builds from hits taken
	if combatant.class_id == "warrior" or combatant.class_id in ["berserker", "knight"]:
		if action == "take_damage":
			combatant.rage_meter += 15.0
			if combatant.rage_meter >= 100.0:
				# Rage is full; can use ultimate ability
				combatant.rage_meter = 100.0

	# Divine: oath meter fills when oath conditions are met
	if combatant.class_id == "acolyte" or combatant.class_id in ["paladin", "oracle"]:
		if action == "heal" or action == "protect":
			combatant.oath_meter += 20.0
			if combatant.oath_meter >= 100.0:
				combatant.oath_meter = 100.0


## Check if battle is over
func _check_battle_end() -> void:
	var party_alive = state.party.any(func(c): return c.is_alive)
	var enemies_alive = state.enemies.any(func(c): return c.is_alive)

	if not party_alive or not enemies_alive:
		state.battle_over = true
		state.player_won = party_alive and not enemies_alive


## Get all valid actions for a combatant
func get_valid_actions(combatant: Combatant) -> Array[String]:
	var actions = ["attack", "defend"]

	if combatant.mp > 0:
		actions.append("cast_spell")

	# Class-specific actions
	if combatant.class_id in ["warrior", "berserker", "knight", "dragoon"]:
		actions.append("stance")

	if combatant.class_id in ["rogue", "assassin", "shadowdancer"]:
		actions.append("steal")
		actions.append("dodge")

	if combatant.rage_meter >= 100.0:
		actions.append("ultimate")

	return actions


## Get available targets (based on combat rules)
func get_valid_targets(attacker: Combatant, action: String) -> Array[Combatant]:
	var targets: Array[Combatant] = []

	# Determine target pool
	var enemy_pool = state.enemies.filter(func(c): return c.is_alive)

	# Melee attacks default to front row
	if action == "attack":
		targets = enemy_pool.filter(func(c): return c.row == "front")
		# If no front-row enemies, can hit back row
		if targets.is_empty():
			targets = enemy_pool
	else:
		targets = enemy_pool

	return targets


## Simulate one full round of combat
func simulate_round() -> Array[Dictionary]:
	var round_results: Array[Dictionary] = []

	for combatant in state.turn_order:
		if not combatant.is_alive or state.battle_over:
			continue

		var valid_actions = get_valid_actions(combatant)
		var action = valid_actions[randi() % valid_actions.size()]

		var targets = get_valid_targets(combatant, action)
		var target = targets[randi() % targets.size()] if not targets.is_empty() else null

		var turn_result = execute_turn(combatant, action, target)
		round_results.append(turn_result)

	state.round += 1
	return round_results


## Get battle summary
func get_summary() -> Dictionary:
	return {
		"battle_over": state.battle_over,
		"player_won": state.player_won,
		"round": state.round,
		"party_alive": state.party.filter(func(c): return c.is_alive).size(),
		"enemies_alive": state.enemies.filter(func(c): return c.is_alive).size(),
	}
