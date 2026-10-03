## World-Encounter Integration: Trigger encounters during world exploration
##
## Manages encounter triggering based on location, difficulty scaling, and reward application
## Ties world encounters into battle system and heir progression

class_name WorldEncounterIntegration


signal encounter_triggered(heir_name: String, encounter_type: String, difficulty: String)
signal battle_started(heir_name: String, battle_type: String)
signal battle_completed(heir_name: String, victory: bool, rewards: Dictionary)
signal boss_encountered(heir_name: String, boss_name: String)


var world_system: WorldTileSystem
var world_integration: WorldHeirIntegration
var encounter_system: EncounterSystem
var boss_system: BossSystem
var combat_manager: CombatEncounterManager

# Encounter chance per tile type
var encounter_chance: Dictionary = {
	"GRASS": 0.15,
	"FOREST": 0.25,
	"WATER": 0.10,
	"MOUNTAIN": 0.35,
	"SETTLEMENT": 0.0,
	"DUNGEON": 0.50,
	"CAVE": 0.45,
	"DESERT": 0.30,
}

# Boss locations
var boss_locations: Dictionary = {
	"shadow_knight": Vector2i(200, 300),
	"frost_warden": Vector2i(-400, 100),
	"dragon_whelp": Vector2i(500, 500),
	"void_entity": Vector2i(-600, -400),
	"tyrant_king": Vector2i(0, 400),
}


func _init(world: WorldTileSystem, integration: WorldHeirIntegration, encounters: EncounterSystem, bosses: BossSystem) -> void:
	world_system = world
	world_integration = integration
	encounter_system = encounters
	boss_system = bosses
	combat_manager = CombatEncounterManager.new(encounters, bosses)


## Check for random encounter during movement
func check_random_encounter(heir_name: String, heir_stats: Dictionary, current_tile: String) -> Dictionary:
	var chance = encounter_chance.get(current_tile, 0.0)

	if randf() > chance:
		return {}  # No encounter

	var encounter = encounter_system.generate_encounter(current_tile, heir_stats)
	if encounter.is_empty():
		return {}

	encounter_triggered.emit(heir_name, encounter["type_name"], encounter["difficulty_name"])
	return encounter


## Check for boss encounter at location
func check_boss_encounter(heir_name: String, position: Vector2i) -> Dictionary:
	for boss_name in boss_locations.keys():
		var boss_pos = boss_locations[boss_name]
		var distance = position.distance_to(boss_pos)

		# Boss encountered if within 2 tile distance
		if distance < 2.0:
			# Check if boss already defeated
			var history = boss_system.get_boss_history(boss_name)
			if history["defeats"] == 0:
				boss_encountered.emit(heir_name, boss_name)
				return {
					"is_boss": true,
					"boss_name": boss_name,
					"location": boss_pos,
					"distance": distance,
				}

	return {}


## Initiate random encounter battle
func initiate_encounter_battle(heir_name: String, encounter_id: String, heir_stats: Dictionary) -> Dictionary:
	var battle = combat_manager.start_encounter_battle(encounter_id, heir_name, heir_stats)
	if battle.is_empty():
		return {}

	battle_started.emit(heir_name, battle["encounter_type"])
	return battle


## Initiate boss battle
func initiate_boss_battle(heir_name: String, boss_name: String, heir_stats: Dictionary) -> Dictionary:
	var battle = combat_manager.start_boss_battle(boss_name, heir_name, heir_stats)
	if battle.is_empty():
		return {}

	battle_started.emit(heir_name, boss_name)
	return battle


## Process encounter battle result
func process_encounter_result(encounter_id: String, heir_name: String, heir_victory: bool, heir_stats: Dictionary) -> Dictionary:
	var rewards = combat_manager.resolve_encounter_battle(encounter_id, heir_victory)

	if heir_victory:
		# Apply rewards to heir through world_integration
		_apply_battle_rewards(heir_name, rewards, heir_stats)

	battle_completed.emit(heir_name, heir_victory, rewards)
	combat_manager.clear_encounter(encounter_id)
	return rewards


## Process boss battle result
func process_boss_result(encounter_id: String, boss_name: String, heir_name: String, heir_victory: bool, heir_stats: Dictionary) -> Dictionary:
	var rewards = combat_manager.resolve_boss_battle(encounter_id, boss_name, heir_victory, heir_name)

	if heir_victory:
		# Apply rewards to heir
		_apply_battle_rewards(heir_name, rewards, heir_stats)

		# Mark achievement: boss defeated
		_record_boss_victory(heir_name, boss_name)

	battle_completed.emit(heir_name, heir_victory, rewards)
	combat_manager.clear_encounter(encounter_id)
	return rewards


## Get encounter info for UI
func get_encounter_info(encounter_id: String, heir_stats: Dictionary) -> Dictionary:
	var encounter = encounter_system.get_encounter(encounter_id)
	if encounter.is_empty():
		return {}

	var difficulty_rating = combat_manager.get_encounter_difficulty_rating(encounter_id, heir_stats)
	var expected_rewards = combat_manager.get_expected_rewards(encounter_id)

	return {
		"type": encounter["type_name"],
		"difficulty": encounter["difficulty_name"],
		"difficulty_rating": difficulty_rating,
		"enemy_count": encounter["enemy_count"],
		"enemies": _get_enemy_names(encounter["enemies"]),
		"expected_gold": expected_rewards["gold"],
		"expected_xp": expected_rewards["xp"],
		"item_chance": expected_rewards["item_chance"],
	}


## Get boss info for UI
func get_boss_info(boss_name: String, heir_stats: Dictionary) -> Dictionary:
	var boss_info = combat_manager.get_boss_info(boss_name)
	var difficulty_rating = combat_manager.get_boss_difficulty_rating(boss_name, heir_stats)

	boss_info["difficulty_rating"] = difficulty_rating
	return boss_info


## Get all available bosses
func get_available_bosses() -> Array[String]:
	var available = []
	for boss_name in boss_system.get_all_bosses():
		var history = boss_system.get_boss_history(boss_name)
		if history["defeats"] == 0:
			available.append(boss_name)
	return available


## Get defeated bosses
func get_defeated_bosses() -> Array[String]:
	var defeated = []
	for boss_name in boss_system.get_all_bosses():
		var history = boss_system.get_boss_history(boss_name)
		if history["defeats"] > 0:
			defeated.append(boss_name)
	return defeated


## Get encounter encounter statistics
func get_encounter_statistics(heir_name: String) -> Dictionary:
	return {
		"total_encounters": 0,
		"victories": 0,
		"defeats": 0,
		"bosses_defeated": 0,
	}


## Internal: Apply battle rewards to heir through progression system
func _apply_battle_rewards(heir_name: String, rewards: Dictionary, heir_stats: Dictionary) -> void:
	# This would integrate with HeirProgression to apply:
	# - Gold rewards
	# - XP rewards
	# - Item rewards
	# For now, this is a hook for future integration
	pass


## Internal: Record boss victory
func _record_boss_victory(heir_name: String, boss_name: String) -> void:
	# Track boss victories for achievements
	pass


## Internal: Get enemy names from encounter
func _get_enemy_names(enemies: Array) -> Array[String]:
	var names = []
	for enemy in enemies:
		names.append(enemy["name"])
	return names
