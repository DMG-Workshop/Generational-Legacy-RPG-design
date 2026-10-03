## Reputation System: tracks faction standing and legacy echoes
##
## Every heir's actions create echoes that affect their descendants.
## Factions remember your bloodline and judge each heir accordingly.

extends Node

class_name ReputationSystem


## Faction standing for a bloodline
class FactionStanding:
	var faction: String
	var reputation: int = 0  # -100 to +100
	var standing_level: String = "neutral"
	var last_action_generation: int = 0
	var memory_decay: int = 0  # Generations; higher = forgotten faster


## Legacy echo (remembered ancestor action)
class LegacyEcho:
	var description: String
	var from_generation: int
	var event_type: String  # "heroic", "betrayal", "curse", "blessing"
	var factions_affected: Array[String] = []
	var reputation_impact: int = 0  # Impact on heirs
	var decay_rate: int = 5  # Generations until half-forgotten
	var resolution: String = ""  # How it was resolved


## All factions
var factions: Dictionary = {}

## All legacy echoes (bloodline memory)
var legacy_echoes: Array[LegacyEcho] = []

## Bloodline reputation scores
var bloodline_reputation: Dictionary = {}


func _init() -> void:
	_initialize_factions()


## Initialize all factions
func _initialize_factions() -> void:
	var faction_list = [
		"mages_circle",
		"thieves_guild",
		"warriors_order",
		"church",
		"draconic_council",
		"noble_houses",
		"beast_clans",
		"fae_courts",
		"general"  # Commoners and unaffiliated
	]

	for faction in faction_list:
		factions[faction] = FactionStanding.new()
		factions[faction].faction = faction
		bloodline_reputation[faction] = 0


## Add reputation (positive or negative)
func add_reputation(generation: int, faction: String, amount: int) -> void:
	if not factions.has(faction):
		return

	var standing = factions[faction]
	standing.reputation = clamp(standing.reputation + amount, -100, 100)
	standing.last_action_generation = generation

	# Update standing level
	if standing.reputation >= 50:
		standing.standing_level = "honored"
	elif standing.reputation >= 20:
		standing.standing_level = "trusted"
	elif standing.reputation > -20:
		standing.standing_level = "neutral"
	elif standing.reputation > -50:
		standing.standing_level = "distrusted"
	else:
		standing.standing_level = "enemy"


## Create a legacy echo (memorable ancestral action)
func create_legacy_echo(
	description: String,
	generation: int,
	event_type: String,
	affected_factions: Array[String],
	reputation_impact: int
) -> LegacyEcho:
	var echo = LegacyEcho.new()
	echo.description = description
	echo.from_generation = generation
	echo.event_type = event_type
	echo.factions_affected = affected_factions
	echo.reputation_impact = reputation_impact

	# Apply impact to factions
	for faction in affected_factions:
		add_reputation(generation, faction, reputation_impact)

	legacy_echoes.append(echo)
	return echo


## Get how an ancestor is remembered
func get_memory_of_ancestor(generation: int, current_generation: int) -> Dictionary:
	var generations_ago = current_generation - generation

	var memory = {
		"generation": generation,
		"time_elapsed": generations_ago,
		"memory_tier": "forgotten",
		"known_by_factions": []
	}

	# Memory decay
	if generations_ago <= 3:
		memory["memory_tier"] = "personal"  # People who knew them
	elif generations_ago <= 20:
		memory["memory_tier"] = "history"  # Recorded
	elif generations_ago <= 100:
		memory["memory_tier"] = "legend"  # Exaggerated
	else:
		memory["memory_tier"] = "myth"  # Mostly forgotten

	# Which factions remember
	for faction_name in factions.keys():
		var faction = factions[faction_name]
		if faction.last_action_generation == generation:
			memory["known_by_factions"].append(faction_name)

	return memory


## Get all legacy echoes relevant to current heir
func get_relevant_echoes(current_generation: int) -> Array[LegacyEcho]:
	var relevant: Array[LegacyEcho] = []

	for echo in legacy_echoes:
		var generations_ago = current_generation - echo.from_generation

		# Echoes are relevant up to their decay point
		if generations_ago < echo.decay_rate * 2:
			relevant.append(echo)

	relevant.sort_custom(func(a, b): return a.from_generation > b.from_generation)
	return relevant


## Get heir's starting reputation from ancestry
func get_inherited_reputation(generation: int, lineage: Lineage) -> Dictionary:
	var heir = lineage.get_heir(generation)
	var inherited: Dictionary = {}

	# Find parent
	var parent = heir.mother if heir.mother else heir.father
	if parent == null:
		return inherited

	# Inherit parent's faction standing (partial)
	for faction_name in factions.keys():
		var parent_standing = factions[faction_name]
		var inherited_amount = int(parent_standing.reputation * 0.5)  # 50% inherit
		inherited[faction_name] = inherited_amount

	return inherited


## Apply failure's reputation consequences
func apply_failure_consequences(generation: int, failure_type: String) -> void:
	# Different failures damage different factions
	match failure_type:
		"betrayal_by_ally":
			create_legacy_echo(
				"Betrayed an ally",
				generation,
				"betrayal",
				["general", "warriors_order"],
				-30
			)

		"curse_activation":
			create_legacy_echo(
				"Activated a curse",
				generation,
				"curse",
				["mages_circle", "church"],
				-20
			)

		"military_defeat":
			create_legacy_echo(
				"Suffered military defeat",
				generation,
				"defeat",
				["warriors_order", "noble_houses"],
				-25
			)

		"magical_catastrophe":
			create_legacy_echo(
				"Caused magical catastrophe",
				generation,
				"catastrophe",
				["mages_circle"],
				-40
			)


## Apply success's reputation gains
func apply_success_consequences(generation: int, success_type: String) -> void:
	match success_type:
		"saved_village":
			create_legacy_echo(
				"Saved a village from destruction",
				generation,
				"heroic",
				["general", "church"],
				+30
			)

		"slew_dragon":
			create_legacy_echo(
				"Slew a dragon",
				generation,
				"heroic",
				["warriors_order", "draconic_council"],
				+40
			)

		"cured_plague":
			create_legacy_echo(
				"Cured a plague",
				generation,
				"heroic",
				["church", "general"],
				+25
			)

		"forged_alliance":
			create_legacy_echo(
				"Forged an alliance",
				generation,
				"heroic",
				["noble_houses", "fae_courts"],
				+20
			)


## Get faction's opinion of current heir
func get_faction_opinion(faction_name: String, current_generation: int) -> Dictionary:
	if not factions.has(faction_name):
		return {}

	var faction = factions[faction_name]
	var opinion = {
		"faction": faction_name,
		"reputation": faction.reputation,
		"standing": faction.standing_level,
		"last_interaction": current_generation - faction.last_action_generation,
		"memory_echoes": []
	}

	# Get relevant echoes for this faction
	for echo in get_relevant_echoes(current_generation):
		if faction_name in echo.factions_affected:
			opinion["memory_echoes"].append(echo.description)

	return opinion


## Get all faction opinions
func get_all_opinions(current_generation: int) -> Array[Dictionary]:
	var opinions: Array[Dictionary] = []

	for faction_name in factions.keys():
		opinions.append(get_faction_opinion(faction_name, current_generation))

	return opinions


## Reputation decay (forget old events)
func apply_decay(generations_passed: int) -> void:
	for echo in legacy_echoes:
		echo.decay_rate += generations_passed

	# Fade faction memories over time
	for faction in factions.values():
		faction.memory_decay += generations_passed

		# After 100+ generations, reputation slowly resets
		if faction.memory_decay > 100:
			if faction.reputation > 0:
				faction.reputation = max(0, faction.reputation - 1)
			elif faction.reputation < 0:
				faction.reputation = min(0, faction.reputation + 1)


## Get summary of bloodline reputation
func get_reputation_summary() -> Dictionary:
	var summary = {
		"total_echoes": legacy_echoes.size(),
		"heroic_echoes": legacy_echoes.filter(func(e): return e.event_type == "heroic").size(),
		"negative_echoes": legacy_echoes.filter(func(e): return e.event_type in ["betrayal", "curse", "catastrophe"]).size(),
		"most_favorable_faction": null,
		"most_hostile_faction": null,
	}

	var best_rep = -200
	var worst_rep = 200

	for faction_name in factions.keys():
		var rep = factions[faction_name].reputation

		if rep > best_rep:
			best_rep = rep
			summary["most_favorable_faction"] = faction_name

		if rep < worst_rep:
			worst_rep = rep
			summary["most_hostile_faction"] = faction_name

	return summary
