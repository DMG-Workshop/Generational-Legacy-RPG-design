## Legacy Echo: Player choices ripple through generations
##
## Tracks player choices, heir defeats, and legendary deeds that
## provide bonuses/penalties to subsequent heirs

class_name LegacyEcho


signal legacy_echo_created(heir: Heir, echo_type: String, effect: String)
signal reputation_carried_forward(heir: Heir, faction: String, value: int)
signal legacy_curse_inherited(heir: Heir, curse: String)
signal legacy_blessing_inherited(heir: Heir, blessing: String)


# Types of legacy echoes
enum EchoType { VICTORY, DEFEAT, MARRIAGE, QUEST, CURSE, BLESSING }

# Store all legacy echoes from ancestors
var legacy_echoes: Array[Dictionary] = []


func _init() -> void:
	legacy_echoes = []


## Record a significant event in heir's legacy
func record_legacy_event(heir: Heir, event_type: int, description: String, effect_value: float = 0.0) -> void:
	if not heir:
		return
	
	var echo = {
		"heir_name": heir.name,
		"generation": heir.generation,
		"type": EchoType.keys()[event_type],
		"description": description,
		"effect": effect_value,
		"year": heir.birth_year,
		"timestamp": Time.get_ticks_msec()
	}
	
	legacy_echoes.append(echo)
	legacy_echo_created.emit(heir, echo["type"], description)


## Transfer faction reputation from previous heir to next
func carry_forward_reputation(previous_heir: Heir, next_heir: Heir, reputation_multiplier: float = 0.7) -> void:
	if not previous_heir or not next_heir:
		return
	
	for faction in previous_heir.faction_reputation:
		var previous_rep = previous_heir.faction_reputation[faction]
		var carried_rep = int(previous_rep * reputation_multiplier)
		
		if faction not in next_heir.faction_reputation:
			next_heir.faction_reputation[faction] = 0
		
		next_heir.faction_reputation[faction] += carried_rep
		
		reputation_carried_forward.emit(next_heir, faction, carried_rep)


## Apply legacy blessing from ancestor
func apply_legacy_blessing(heir: Heir, ancestor_generation: int) -> void:
	# Find most recent blessing from that generation line
	var blessing_echo = null
	
	for echo in legacy_echoes:
		if echo["type"] == "BLESSING" and echo["generation"] <= ancestor_generation:
			blessing_echo = echo
	
	if not blessing_echo:
		return
	
	# Apply stat bonus based on blessing
	var blessing_bonus = int(blessing_echo["effect"])
	for stat in heir.stats:
		heir.stats[stat] += blessing_bonus
	
	legacy_blessing_inherited.emit(heir, blessing_echo["description"])


## Apply legacy curse from ancestor
func apply_legacy_curse(heir: Heir, ancestor_generation: int) -> void:
	# Find most recent curse from that generation line
	var curse_echo = null
	
	for echo in legacy_echoes:
		if echo["type"] == "CURSE" and echo["generation"] <= ancestor_generation:
			curse_echo = echo
	
	if not curse_echo:
		return
	
	# Apply stat penalty based on curse
	var curse_penalty = int(curse_echo["effect"])
	for stat in heir.stats:
		heir.stats[stat] = maxi(heir.stats[stat] - curse_penalty, 1)
	
	legacy_curse_inherited.emit(heir, curse_echo["description"])


## Get all echoes from a specific heir
func get_heir_echoes(heir_name: String) -> Array[Dictionary]:
	var echoes: Array[Dictionary] = []
	for echo in legacy_echoes:
		if echo["heir_name"] == heir_name:
			echoes.append(echo)
	return echoes


## Get echoes of a specific type
func get_echoes_by_type(echo_type: String) -> Array[Dictionary]:
	var echoes: Array[Dictionary] = []
	for echo in legacy_echoes:
		if echo["type"] == echo_type:
			echoes.append(echo)
	return echoes


## Get legendary deeds (major victories or quests)
func get_legendary_deeds() -> Array[Dictionary]:
	var deeds: Array[Dictionary] = []
	
	for echo in legacy_echoes:
		if echo["type"] in ["VICTORY", "QUEST"] and echo["effect"] >= 50.0:
			deeds.append(echo)
	
	return deeds


## Calculate total legacy score for heir lineage
func calculate_legacy_score(heir: Heir) -> int:
	var score = 0
	
	for echo in legacy_echoes:
		if echo["generation"] < heir.generation:
			match echo["type"]:
				"VICTORY":
					score += int(echo["effect"])
				"DEFEAT":
					score -= int(echo["effect"])
				"BLESSING":
					score += 50
				"CURSE":
					score -= 50
				"QUEST":
					score += int(echo["effect"] * 2)
	
	return maxi(score, 0)


## Create legacy inheritance bonus based on lineage achievements
func get_legacy_inheritance_bonus(heir: Heir) -> Dictionary:
	var bonus = {
		"stat_bonus": 0,
		"reputation_bonus": 0,
		"starting_wealth": 0
	}
	
	# Calculate based on legendary deeds
	var deeds = get_legendary_deeds()
	
	for deed in deeds:
		if deed["generation"] < heir.generation:
			bonus["stat_bonus"] += int(deed["effect"] / 10)
			bonus["starting_wealth"] += int(deed["effect"] * 10)
	
	# Cap bonuses
	bonus["stat_bonus"] = mini(bonus["stat_bonus"], 20)
	bonus["starting_wealth"] = mini(bonus["starting_wealth"], 5000)
	
	return bonus


## Record heir death with context (victory or defeat)
func record_heir_death(heir: Heir, death_cause: String, was_heroic: bool = false) -> void:
	var echo_type = EchoType.DEFEAT
	var effect = 25.0
	
	if was_heroic:
		echo_type = EchoType.VICTORY
		effect = 50.0
	
	record_legacy_event(heir, echo_type, "Death: %s (Heroic: %s)" % [death_cause, was_heroic], effect)


## Get legacy echo history as display text
func get_legacy_history() -> Array[String]:
	var history: Array[String] = []
	
	# Sort by generation
	var sorted_echoes = legacy_echoes.duplicate()
	sorted_echoes.sort_custom(func(a, b): return a["generation"] < b["generation"])
	
	for echo in sorted_echoes:
		var line = "Gen %d: %s - %s" % [echo["generation"], echo["heir_name"], echo["description"]]
		history.append(line)
	
	return history


## Check if heir qualifies for legendary status
func is_heir_legendary(heir: Heir) -> bool:
	var heir_echoes = get_heir_echoes(heir.name)
	
	if heir_echoes.is_empty():
		return false
	
	# Legendary if: 3+ significant events or any BLESSING echo
	var significant_count = 0
	for echo in heir_echoes:
		if echo["effect"] >= 50.0 or echo["type"] == "BLESSING":
			significant_count += 1
	
	return significant_count >= 3


## Apply all legacy modifiers to new heir
func apply_all_legacy_modifiers(heir: Heir, previous_heir: Heir) -> void:
	# Carry forward reputation
	carry_forward_reputation(previous_heir, heir, 0.7)
	
	# Apply blessings and curses
	apply_legacy_blessing(heir, previous_heir.generation)
	apply_legacy_curse(heir, previous_heir.generation)
	
	# Apply inheritance bonus
	var bonus = get_legacy_inheritance_bonus(heir)
	for stat in heir.stats:
		heir.stats[stat] += bonus["stat_bonus"]
	heir.wallet.gold += bonus["starting_wealth"]
