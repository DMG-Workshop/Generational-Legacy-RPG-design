## Dynasty Prestige Persistence: Save/load prestige and succession state
##
## Serializes prestige pool and succession bonuses across generation boundaries

extends Node

class_name DynastyPrestigePersistence


signal prestige_state_saved
signal prestige_state_loaded


func save_prestige_state(
	prestige_system: DynastyPrestigeSystem,
	succession_system: SuccessionBonusSystem,
	scaling_system: PrestigeScalingSystem
) -> Dictionary:
	var state = {
		"total_prestige": prestige_system.total_prestige,
		"prestige_available": prestige_system.prestige_available,
		"prestige_spent": prestige_system.prestige_spent,
		"current_tier": prestige_system.current_tier,
		"milestone_multiplier": prestige_system.milestone_multiplier,
		"achievement_multiplier": prestige_system.achievement_multiplier,
		"combined_multiplier": prestige_system.combined_multiplier,
		"prestige_history": prestige_system.prestige_history.duplicate(),
		"tier_achievements": prestige_system.tier_achievements.duplicate(),
		"succession_bonuses": [],
		"scaling_history": scaling_system.scaling_history.duplicate()
	}

	# Save succession bonuses
	for heir_id in succession_system.succession_bonuses.keys():
		var bonus = succession_system.succession_bonuses[heir_id]
		state["succession_bonuses"].append({
			"heir_id": bonus.heir_id,
			"prestige_level": bonus.prestige_level,
			"starting_level": bonus.starting_level,
			"stat_bonuses": bonus.stat_bonuses.duplicate(),
			"starting_gold": bonus.starting_gold,
			"starting_supplies": bonus.starting_supplies,
			"skill_points": bonus.skill_points,
			"legendary_slots": bonus.legendary_slots,
			"experience_multiplier": bonus.experience_multiplier,
			"trait_inheritance_boost": bonus.trait_inheritance_boost
		})

	prestige_state_saved.emit()
	return state


func load_prestige_state(
	state: Dictionary,
	prestige_system: DynastyPrestigeSystem,
	succession_system: SuccessionBonusSystem,
	scaling_system: PrestigeScalingSystem
) -> void:
	if not state:
		prestige_state_loaded.emit()
		return

	# Restore prestige system
	prestige_system.total_prestige = state.get("total_prestige", 0)
	prestige_system.prestige_available = state.get("prestige_available", 0)
	prestige_system.prestige_spent = state.get("prestige_spent", 0)
	prestige_system.current_tier = state.get("current_tier", 0)
	prestige_system.milestone_multiplier = state.get("milestone_multiplier", 1.0)
	prestige_system.achievement_multiplier = state.get("achievement_multiplier", 1.0)
	prestige_system.combined_multiplier = state.get("combined_multiplier", 1.0)
	prestige_system.prestige_history = state.get("prestige_history", []).duplicate()
	prestige_system.tier_achievements = state.get("tier_achievements", {}).duplicate()

	# Restore succession bonuses
	succession_system.succession_bonuses = {}
	for bonus_data in state.get("succession_bonuses", []):
		var bonus = SuccessionBonusSystem.SuccessionBonus.new(
			bonus_data["heir_id"],
			bonus_data["prestige_level"]
		)
		bonus.starting_level = bonus_data.get("starting_level", 0)
		bonus.stat_bonuses = bonus_data.get("stat_bonuses", {}).duplicate()
		bonus.starting_gold = bonus_data.get("starting_gold", 0)
		bonus.starting_supplies = bonus_data.get("starting_supplies", 0)
		bonus.skill_points = bonus_data.get("skill_points", 0)
		bonus.legendary_slots = bonus_data.get("legendary_slots", 0)
		bonus.experience_multiplier = bonus_data.get("experience_multiplier", 1.0)
		bonus.trait_inheritance_boost = bonus_data.get("trait_inheritance_boost", 0.0)

		succession_system.succession_bonuses[bonus.heir_id] = bonus

	# Restore scaling history
	scaling_system.scaling_history = state.get("scaling_history", []).duplicate()

	prestige_state_loaded.emit()


func transfer_prestige_to_next_generation(state: Dictionary) -> Dictionary:
	var new_state = {
		"total_prestige": state.get("total_prestige", 0),
		"prestige_available": state.get("total_prestige", 0),
		"prestige_spent": 0,
		"current_tier": state.get("current_tier", 0),
		"milestone_multiplier": 1.0,
		"achievement_multiplier": 1.0,
		"combined_multiplier": 1.0,
		"prestige_history": state.get("prestige_history", []).duplicate(),
		"tier_achievements": state.get("tier_achievements", {}).duplicate(),
		"succession_bonuses": state.get("succession_bonuses", []).duplicate(true),
		"scaling_history": []
	}

	# Prestige carries at 100% (no decay)
	# Multipliers reset for new generation
	# History and tier achievements persist

	return new_state


func export_prestige_legacy(state: Dictionary) -> Dictionary:
	var legacy = {
		"total_prestige_accumulated": state.get("total_prestige", 0),
		"highest_tier_reached": state.get("current_tier", 0),
		"tier_name": "UNKNOWN",
		"prestige_sources": {},
		"succession_heirs_prepared": state.get("succession_bonuses", []).size(),
		"average_heir_prestige": 0,
		"peak_multiplier": 1.0
	}

	var tier_names = ["BRONZE", "SILVER", "GOLD", "PLATINUM", "DIAMOND", "ETERNAL"]
	if state.get("current_tier", 0) < tier_names.size():
		legacy["tier_name"] = tier_names[state.get("current_tier", 0)]

	# Analyze prestige sources
	for entry in state.get("prestige_history", []):
		var source = entry.get("source", "UNKNOWN")
		if not legacy["prestige_sources"].has(source):
			legacy["prestige_sources"][source] = 0
		legacy["prestige_sources"][source] += entry.get("amount", 0)

	# Calculate average heir prestige
	var bonuses = state.get("succession_bonuses", [])
	if bonuses.size() > 0:
		var total = 0
		for bonus_data in bonuses:
			total += bonus_data.get("prestige_level", 0)
		legacy["average_heir_prestige"] = total / bonuses.size()

	# Track multiplier history
	for entry in state.get("prestige_history", []):
		if entry.get("multiplier", 1.0) > legacy["peak_multiplier"]:
			legacy["peak_multiplier"] = entry.get("multiplier", 1.0)

	return legacy


func get_prestige_legacy_description(state: Dictionary) -> String:
	var prestige = state.get("total_prestige", 0)
	if prestige == 0:
		return "The dynasty's prestige awaits in the future."

	var legacy = "The dynasty has accumulated %d prestige. " % prestige

	var tier_names = ["BRONZE", "SILVER", "GOLD", "PLATINUM", "DIAMOND", "ETERNAL"]
	var tier = state.get("current_tier", 0)
	if tier < tier_names.size():
		legacy += "They have reached %s tier. " % tier_names[tier]

	var heirs_prepared = state.get("succession_bonuses", []).size()
	if heirs_prepared > 0:
		legacy += "%d successors have been prepared with enhanced starting abilities. " % heirs_prepared

	var multiplier = state.get("combined_multiplier", 1.0)
	if multiplier > 1.01:
		legacy += "Their dynasty multiplier stands at %.2fx, amplifying all future rewards. " % multiplier

	return legacy
