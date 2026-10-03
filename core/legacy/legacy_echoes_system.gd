## Legacy Echoes System: Past choices echo through generations affecting present
##
## Integrates reputation and historical events to show world reactivity based on
## dynasty's actions. Previous generation choices impact current heir's opportunities.

extends Node

class_name LegacyEchoesSystem


signal echo_activated(echo_id: String, effect_type: String)
signal world_state_changed(change_type: String, affected_faction: String)
signal dynasty_reputation_updated(overall_standing: String)


var reputation_system: ReputationSystem
var event_tracker: HistoricalEventTracker
var active_echoes: Dictionary = {}  # echo_id -> EchoEffect
var world_state_modifiers: Dictionary = {}  # modifier_id -> active flag


class EchoEffect:
	var echo_id: String
	var source_event_id: String
	var source_generation: int
	var effect_type: String  # "reputation_boost", "ability_unlock", "enemy_weakness", "quest_unlock"
	var affected_faction: String
	var effect_value: float
	var duration_generations: int
	var remaining_duration: int
	var is_active: bool

	func _init(p_event_id: String, p_gen: int) -> void:
		echo_id = "echo_%s_%d" % [p_event_id, randi()]
		source_event_id = p_event_id
		source_generation = p_gen
		effect_type = ""
		affected_faction = ""
		effect_value = 1.0
		duration_generations = 5
		remaining_duration = duration_generations
		is_active = true


class LegacyPerk:
	var perk_id: String
	var perk_name: String
	var description: String
	var reputation_threshold: int
	var effect_type: String
	var effect_value: float
	var faction_id: String

	func _init(p_id: String, p_name: String, p_faction: String) -> void:
		perk_id = p_id
		perk_name = p_name
		faction_id = p_faction
		description = ""
		reputation_threshold = 0
		effect_type = ""
		effect_value = 1.0


func _init(rep_system: ReputationSystem, history: HistoricalEventTracker) -> void:
	reputation_system = rep_system
	event_tracker = history


func apply_echo(event_id: String, generation: int) -> EchoEffect:
	var echo = EchoEffect.new(event_id, generation)
	echo.effect_type = "reputation_cascade"
	echo.duration_generations = 10
	echo.remaining_duration = 10

	active_echoes[echo.echo_id] = echo
	echo_activated.emit(echo.echo_id, echo.effect_type)

	return echo


func trigger_faction_reaction(faction_id: String, prestige: int, generation: int) -> Dictionary:
	var reaction = {
		"faction_id": faction_id,
		"reaction_type": "neutral",
		"reputation_change": 0,
		"new_opportunity": false,
		"description": ""
	}

	var reputation = reputation_system.get_reputation(faction_id)
	var tier = reputation_system.get_reputation_tier(faction_id)

	# Determine faction reaction based on reputation
	match tier:
		"LEGENDARY":
			reaction["reaction_type"] = "legendary_reception"
			reaction["reputation_change"] = 500
			reaction["new_opportunity"] = true
			reaction["description"] = "The faction reveres the dynasty's legendary status"
		"REVERED":
			reaction["reaction_type"] = "warm_reception"
			reaction["reputation_change"] = 250
			reaction["new_opportunity"] = true
			reaction["description"] = "The faction welcomes this heir warmly"
		"LIKED":
			reaction["reaction_type"] = "positive_reception"
			reaction["reputation_change"] = 100
			reaction["new_opportunity"] = false
			reaction["description"] = "The faction regards this heir favorably"
		"NEUTRAL":
			reaction["reaction_type"] = "neutral_reception"
			reaction["reputation_change"] = 0
			reaction["new_opportunity"] = false
			reaction["description"] = "The faction is neutral toward this heir"
		"DISLIKED":
			reaction["reaction_type"] = "hostile_reception"
			reaction["reputation_change"] = -100
			reaction["new_opportunity"] = false
			reaction["description"] = "The faction views this heir with suspicion"
		"HATED":
			reaction["reaction_type"] = "aggressive_reception"
			reaction["reputation_change"] = -250
			reaction["new_opportunity"] = false
			reaction["description"] = "The faction is openly hostile to this heir"

	# Apply prestige scaling
	var prestige_multiplier = 1.0 + (prestige / 100000.0) * 0.5
	reaction["reputation_change"] = int(reaction["reputation_change"] * prestige_multiplier)

	world_state_changed.emit("faction_reaction", faction_id)
	return reaction


func get_available_opportunities(generation: int, prestige: int) -> Array:
	var opportunities = []

	# Check historical events for cascading opportunities
	var recent_events = event_tracker.get_events_in_range(max(1, generation - 5), generation)

	for event in recent_events:
		if event.prestige_impact > 0:
			var opp = {
				"type": "legacy_quest",
				"description": "A reward for: %s" % event.title,
				"reward_multiplier": 1.0 + (prestige / 50000.0),
				"source_event": event.event_id
			}
			opportunities.append(opp)

	# Check reputation-based opportunities
	var factions_report = reputation_system.get_all_factions_report()
	for faction_id in factions_report["factions"].keys():
		var reputation = reputation_system.get_reputation(faction_id)
		if reputation > 3000:
			var opp = {
				"type": "faction_quest",
				"faction": faction_id,
				"description": "Special quest from respected faction",
				"reputation_threshold": 3000
			}
			opportunities.append(opp)

	return opportunities


func get_dynasty_overall_standing() -> String:
	var factions_report = reputation_system.get_all_factions_report()
	var total_rep = factions_report["total_reputation"]
	var faction_count = factions_report["factions"].size()

	if faction_count == 0:
		return "UNRECOGNIZED"

	var avg_reputation = total_rep / faction_count

	if avg_reputation >= 5000:
		dynasty_reputation_updated.emit("LEGENDARY_DYNASTY")
		return "LEGENDARY"
	elif avg_reputation >= 2000:
		dynasty_reputation_updated.emit("REVERED_DYNASTY")
		return "REVERED"
	elif avg_reputation >= 1000:
		dynasty_reputation_updated.emit("RESPECTED_DYNASTY")
		return "RESPECTED"
	elif avg_reputation >= 0:
		dynasty_reputation_updated.emit("KNOWN_DYNASTY")
		return "KNOWN"
	else:
		dynasty_reputation_updated.emit("INFAMOUS_DYNASTY")
		return "INFAMOUS"


func propagate_reputation_across_generation(parent_rep: int, current_generation: int) -> int:
	# Reputation carries forward with some decay but with bonuses from positive legacy
	var base_carry = int(parent_rep * 0.9)  # 90% decay per generation

	# Bonus from positive historical events
	var legacy_bonus = 0
	var gen_events = event_tracker.get_events_at_generation(current_generation - 1)

	for event in gen_events:
		if event.prestige_impact > 0:
			legacy_bonus += int(event.prestige_impact / 100)  # Small bonus from legacy

	return base_carry + legacy_bonus


func get_echo_status(generation: int) -> Dictionary:
	var status = {
		"active_echoes": 0,
		"expiring_soon": [],
		"expired": []
	}

	for echo_id in active_echoes.keys():
		var echo = active_echoes[echo_id]

		if echo.is_active:
			status["active_echoes"] += 1

			# Check if expiring soon (within 2 generations)
			if echo.remaining_duration <= 2:
				status["expiring_soon"].append({
					"echo_id": echo_id,
					"generations_left": echo.remaining_duration
				})

		echo.remaining_duration -= 1
		if echo.remaining_duration <= 0:
			echo.is_active = false
			status["expired"].append(echo_id)

	return status


func apply_legacy_perks(heir_id: String, generation: int, prestige: int) -> Array:
	var unlocked_perks = []

	# Check each faction for legacy perks
	var factions_report = reputation_system.get_all_factions_report()

	for faction_id in factions_report["factions"].keys():
		var reputation = reputation_system.get_reputation(faction_id)

		# Legacy perk: Great deeds unlock lasting bonuses
		if reputation > 5000 and generation > 50:
			unlocked_perks.append({
				"perk_id": "legacy_perk_%s_master" % faction_id,
				"perk_name": "Master of %s" % faction_id,
				"bonus": 1.25
			})

		if reputation > 3000:
			unlocked_perks.append({
				"perk_id": "legacy_perk_%s_expert" % faction_id,
				"perk_name": "Expert in %s" % faction_id,
				"bonus": 1.15
			})

	return unlocked_perks


func get_legacy_echoes_report() -> Dictionary:
	var report = {
		"total_active_echoes": active_echoes.size(),
		"echoes": [],
		"dynasty_standing": get_dynasty_overall_standing(),
		"world_state_modifiers": world_state_modifiers.size()
	}

	for echo_id in active_echoes.keys():
		var echo = active_echoes[echo_id]
		if echo.is_active:
			report["echoes"].append({
				"echo_id": echo_id,
				"effect_type": echo.effect_type,
				"duration_left": echo.remaining_duration,
				"affected_faction": echo.affected_faction
			})

	return report


func update_world_state(generation: int) -> void:
	# Process echo decay
	var expired_echoes = []

	for echo_id in active_echoes.keys():
		var echo = active_echoes[echo_id]
		echo.remaining_duration -= 1

		if echo.remaining_duration <= 0:
			echo.is_active = false
			expired_echoes.append(echo_id)

	# Clean up expired echoes
	for echo_id in expired_echoes:
		active_echoes.erase(echo_id)

	# Update dynasty reputation status
	var standing = get_dynasty_overall_standing()
	dynasty_reputation_updated.emit(standing)
