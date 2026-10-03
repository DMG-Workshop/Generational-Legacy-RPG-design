## Achievement Persistence: Save/load achievement and prestige state
##
## Serializes achievements, legendary deeds, and prestige across generations

extends Node

class_name AchievementPersistence


signal achievement_state_saved
signal achievement_state_loaded


func save_achievement_state(
	achievement_system: AchievementSystem,
	legendary_deed_system: LegendaryDeedSystem,
	prestige_system: PrestigeSystem
) -> Dictionary:
	var state = {
		"achievements": {},
		"heir_achievements": achievement_system.heir_achievements.duplicate(true),
		"generation_achievements": achievement_system.generation_achievements.duplicate(true),
		"legendary_deeds": [],
		"records": legendary_deed_system.records.duplicate(true),
		"total_prestige": prestige_system.total_prestige,
		"prestige_by_generation": prestige_system.prestige_by_generation.duplicate(true),
		"prestige_by_source": prestige_system.prestige_by_source.duplicate(true),
		"prestige_spent": prestige_system.prestige_spent_total
	}

	# Save achievement metadata
	for achievement_id in achievement_system.achievements.keys():
		var achievement = achievement_system.achievements[achievement_id]
		state["achievements"][achievement_id] = {
			"name": achievement.name,
			"description": achievement.description,
			"type": achievement.type,
			"requirement": achievement.requirement.duplicate(),
			"reward_prestige": achievement.reward_prestige,
			"tier": achievement.tier,
			"unlock_count": achievement.unlock_count
		}

	# Save legendary deeds
	for deed_id in legendary_deed_system.legendary_deeds.keys():
		var deed = legendary_deed_system.legendary_deeds[deed_id]
		state["legendary_deeds"].append({
			"id": deed.id,
			"type": deed.deed_type,
			"heir_id": deed.heir_id,
			"generation": deed.generation,
			"timestamp": deed.timestamp,
			"value": deed.value,
			"description": deed.description,
			"witnesses": deed.witnesses.duplicate()
		})

	achievement_state_saved.emit()
	return state


func load_achievement_state(
	state: Dictionary,
	achievement_system: AchievementSystem,
	legendary_deed_system: LegendaryDeedSystem,
	prestige_system: PrestigeSystem
) -> void:
	if not state:
		achievement_state_loaded.emit()
		return

	# Restore achievement system state
	achievement_system.heir_achievements = state.get("heir_achievements", {}).duplicate(true)
	achievement_system.generation_achievements = state.get("generation_achievements", {}).duplicate(true)

	# Restore achievements with updated unlock counts
	for achievement_id in state.get("achievements", {}).keys():
		var achievement_data = state["achievements"][achievement_id]
		if achievement_system.achievements.has(achievement_id):
			var achievement = achievement_system.achievements[achievement_id]
			achievement.unlock_count = achievement_data.get("unlock_count", 0)

	# Restore legendary deeds
	legendary_deed_system.legendary_deeds = {}
	legendary_deed_system.deeds_by_type = {}
	legendary_deed_system.deeds_by_heir = {}
	legendary_deed_system.deed_counter = 0

	for deed_data in state.get("legendary_deeds", []):
		var deed = LegendaryDeedSystem.LegendaryDeed.new(
			deed_data["id"],
			deed_data["type"],
			deed_data["heir_id"],
			deed_data["generation"],
			deed_data.get("value", 0)
		)
		deed.timestamp = deed_data.get("timestamp", 0)
		deed.description = deed_data.get("description", "")
		deed.witnesses = deed_data.get("witnesses", []).duplicate()

		legendary_deed_system.legendary_deeds[deed.id] = deed

		if not legendary_deed_system.deeds_by_type.has(deed.deed_type):
			legendary_deed_system.deeds_by_type[deed.deed_type] = []
		legendary_deed_system.deeds_by_type[deed.deed_type].append(deed.id)

		if not legendary_deed_system.deeds_by_heir.has(deed.heir_id):
			legendary_deed_system.deeds_by_heir[deed.heir_id] = []
		legendary_deed_system.deeds_by_heir[deed.heir_id].append(deed.id)

		legendary_deed_system.deed_counter += 1

	# Restore records
	legendary_deed_system.records = state.get("records", {}).duplicate(true)

	# Restore prestige system
	prestige_system.total_prestige = state.get("total_prestige", 0)
	prestige_system.prestige_by_generation = state.get("prestige_by_generation", {}).duplicate(true)
	prestige_system.prestige_by_source = state.get("prestige_by_source", {}).duplicate(true)
	prestige_system.prestige_spent_total = state.get("prestige_spent", 0)

	achievement_state_loaded.emit()


func transfer_achievements_to_next_generation(state: Dictionary) -> Dictionary:
	var new_state = {
		"achievements": state.get("achievements", {}).duplicate(true),
		"heir_achievements": {},
		"generation_achievements": {},
		"legendary_deeds": state.get("legendary_deeds", []).duplicate(true),
		"records": state.get("records", {}).duplicate(true),
		"total_prestige": state.get("total_prestige", 0),
		"prestige_by_generation": {},
		"prestige_by_source": state.get("prestige_by_source", {}).duplicate(true),
		"prestige_spent": state.get("prestige_spent", 0)
	}

	# Heir achievements reset (only global achievements carry forward through deeds)
	new_state["heir_achievements"] = {}

	# Generation achievements reset
	new_state["generation_achievements"] = {}

	# Prestige carries at 100% (no decay)
	for gen in state.get("prestige_by_generation", {}).keys():
		new_state["prestige_by_generation"][gen] = state["prestige_by_generation"][gen]

	return new_state


func resolve_all_achievements(state: Dictionary) -> void:
	state["heir_achievements"] = {}
	state["generation_achievements"] = {}


func export_achievement_history(state: Dictionary) -> Dictionary:
	var history = {
		"total_achievements_defined": state.get("achievements", {}).size(),
		"total_achievements_unlocked": 0,
		"total_legendary_deeds": state.get("legendary_deeds", []).size(),
		"achievements_by_type": {},
		"achievements_by_tier": {},
		"total_prestige_earned": state.get("total_prestige", 0),
		"prestige_sources": state.get("prestige_by_source", {}).duplicate(),
		"active_records": 0,
		"records_held": {}
	}

	# Count total unlocks
	for heir_id in state.get("heir_achievements", {}).keys():
		history["total_achievements_unlocked"] += state["heir_achievements"][heir_id].size()

	# Count by type and tier from achievement definitions
	for achievement_id in state.get("achievements", {}).keys():
		var achievement = state["achievements"][achievement_id]
		var type_name = AchievementSystem.AchievementType.keys()[achievement["type"]]
		var tier_name = AchievementSystem.AchievementTier.keys()[achievement["tier"]]

		if not history["achievements_by_type"].has(type_name):
			history["achievements_by_type"][type_name] = 0
		history["achievements_by_type"][type_name] += achievement.get("unlock_count", 0)

		if not history["achievements_by_tier"].has(tier_name):
			history["achievements_by_tier"][tier_name] = 0
		history["achievements_by_tier"][tier_name] += achievement.get("unlock_count", 0)

	# Count active records
	for record_type in state.get("records", {}).keys():
		var record = state["records"][record_type]
		if record.get("heir_id", ""):
			history["active_records"] += 1
			history["records_held"][record_type] = {
				"value": record.get("value", 0),
				"heir_id": record.get("heir_id", ""),
				"generation": record.get("generation", 0)
			}

	return history


func get_achievement_legacy(state: Dictionary) -> String:
	var history = export_achievement_history(state)
	var legacy = ""

	if history["total_achievements_unlocked"] == 0:
		legacy = "The dynasty has yet to prove themselves through great deeds. "
	else:
		legacy = "The dynasty has achieved %d accomplishments. " % history["total_achievements_unlocked"]

	if history["total_legendary_deeds"] > 0:
		legacy += "%d legendary deeds mark their passage through history. " % history["total_legendary_deeds"]

	if history["active_records"] > 0:
		legacy += "They hold %d records of greatness. " % history["active_records"]

	if history["total_prestige_earned"] > 0:
		legacy += "They have accumulated %d prestige points for future generations. " % history["total_prestige_earned"]

	return legacy if legacy else "Their legacy remains to be written."


func get_heir_achievement_summary(state: Dictionary, heir_id: String) -> Dictionary:
	var summary = {
		"achievements_unlocked": 0,
		"prestige_earned": 0,
		"legendary_deeds": 0,
		"records_held": 0
	}

	# Count heir achievements
	if state.get("heir_achievements", {}).has(heir_id):
		summary["achievements_unlocked"] = state["heir_achievements"][heir_id].size()

		# Calculate prestige from their achievements
		for achievement_id in state["heir_achievements"][heir_id]:
			if state["achievements"].has(achievement_id):
				summary["prestige_earned"] += state["achievements"][achievement_id].get("reward_prestige", 0)

	# Count legendary deeds for this heir
	for deed in state.get("legendary_deeds", []):
		if deed.get("heir_id") == heir_id:
			summary["legendary_deeds"] += 1

	# Count records held by this heir
	for record_type in state.get("records", {}).keys():
		if state["records"][record_type].get("heir_id") == heir_id:
			summary["records_held"] += 1

	return summary
