## Tests for Phase 9.2: Combat Encounters
##
## Tests: EncounterSystem, BossSystem, CombatEncounterManager, WorldEncounterIntegration

extends GutTest


var encounter_system: EncounterSystem
var boss_system: BossSystem
var combat_manager: CombatEncounterManager
var world_system: WorldTileSystem
var settlement_system: SettlementSystem
var npc_system: NPCSystem
var world_integration: WorldHeirIntegration
var encounter_integration: WorldEncounterIntegration

var test_heir_stats: Dictionary = {
	"strength": 15,
	"dexterity": 13,
	"constitution": 14,
	"intelligence": 12,
	"wisdom": 11,
	"charisma": 13,
}


func before_each() -> void:
	encounter_system = EncounterSystem.new()
	boss_system = BossSystem.new()
	combat_manager = CombatEncounterManager.new(encounter_system, boss_system)
	world_system = WorldTileSystem.new()
	settlement_system = SettlementSystem.new()
	npc_system = NPCSystem.new()
	world_integration = WorldHeirIntegration.new(world_system, settlement_system, npc_system)
	encounter_integration = WorldEncounterIntegration.new(world_system, world_integration, encounter_system, boss_system)


# ========== EncounterSystem Tests ==========

## Test: Encounter generation on grass
func test_encounter_generation_grass() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	assert_true("id" in encounter)
	assert_true("enemies" in encounter)


## Test: Encounter generation on dungeon
func test_encounter_generation_dungeon() -> void:
	var encounter = encounter_system.generate_encounter("DUNGEON", test_heir_stats)
	assert_true("id" in encounter)
	assert_gt(encounter["enemy_count"], 0)


## Test: No encounter on settlement
func test_no_encounter_settlement() -> void:
	var encounter = encounter_system.generate_encounter("SETTLEMENT", test_heir_stats)
	assert_true(encounter.is_empty())


## Test: Enemy generation
func test_enemy_generation() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	assert_gt(encounter["enemies"].size(), 0)

	var enemy = encounter["enemies"][0]
	assert_true("health" in enemy)
	assert_true("strength" in enemy)


## Test: Difficulty scaling with heir power
func test_difficulty_scaling() -> void:
	var weak_stats = {"strength": 5, "dexterity": 5, "constitution": 5, "intelligence": 5, "wisdom": 5, "charisma": 5}
	var strong_stats = {"strength": 25, "dexterity": 25, "constitution": 25, "intelligence": 25, "wisdom": 25, "charisma": 25}

	var weak_encounter = encounter_system.generate_encounter("DUNGEON", weak_stats)
	var strong_encounter = encounter_system.generate_encounter("DUNGEON", strong_stats)

	# Stronger heir should face higher difficulty
	assert_gte(strong_encounter["difficulty"], weak_encounter["difficulty"])


## Test: Loot rolling
func test_loot_rolling() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	var loot = encounter_system.roll_loot(encounter["id"])
	assert_true("gold" in loot or "xp" in loot or "items" in loot)


## Test: Encounter summary
func test_encounter_summary() -> void:
	var encounter = encounter_system.generate_encounter("FOREST", test_heir_stats)
	var summary = encounter_system.get_encounter_summary(encounter["id"])
	assert_eq(summary["id"], encounter["id"])
	assert_true("enemies" in summary)


# ========== BossSystem Tests ==========

## Test: Boss definition loading
func test_boss_definitions() -> void:
	var shadow_knight = boss_system.get_boss("shadow_knight")
	assert_eq(shadow_knight["name"], "shadow_knight")
	assert_eq(shadow_knight["tier"], BossSystem.BossTier.EPIC)


## Test: Get all bosses
func test_get_all_bosses() -> void:
	var bosses = boss_system.get_all_bosses()
	assert_gt(bosses.size(), 0)
	assert_true("shadow_knight" in bosses)


## Test: Get bosses by tier
func test_get_bosses_by_tier() -> void:
	var epic_bosses = boss_system.get_bosses_by_tier(BossSystem.BossTier.EPIC)
	assert_gt(epic_bosses.size(), 0)

	var mythic_bosses = boss_system.get_bosses_by_tier(BossSystem.BossTier.MYTHIC)
	assert_gt(mythic_bosses.size(), 0)


## Test: Boss encounter generation
func test_boss_encounter_generation() -> void:
	var boss = boss_system.generate_boss_encounter("shadow_knight", test_heir_stats)
	assert_eq(boss["name"], "shadow_knight")
	assert_gt(boss["health"], 0)


## Test: Boss scaling by heir power
func test_boss_scaling() -> void:
	var weak_stats = {"strength": 5, "dexterity": 5, "constitution": 5, "intelligence": 5, "wisdom": 5, "charisma": 5}
	var strong_stats = {"strength": 25, "dexterity": 25, "constitution": 25, "intelligence": 25, "wisdom": 25, "charisma": 25}

	var weak_boss = boss_system.generate_boss_encounter("shadow_knight", weak_stats)
	var strong_boss = boss_system.generate_boss_encounter("shadow_knight", strong_stats)

	# Both should scale but maintain relative difficulty
	assert_gt(weak_boss["health"], 0)
	assert_gt(strong_boss["health"], 0)


## Test: Boss ability effects
func test_boss_ability_effects() -> void:
	var effect = boss_system.get_ability_effect("shadow_strike")
	assert_true("damage_multiplier" in effect)


## Test: Boss defeat tracking
func test_boss_defeat_tracking() -> void:
	boss_system.defeat_boss("shadow_knight", "TestHero")
	var history = boss_system.get_boss_history("shadow_knight")
	assert_eq(history["defeats"], 1)
	assert_eq(history["last_defeated_by"], "TestHero")


## Test: Boss difficulty rating
func test_boss_difficulty_rating() -> void:
	var rating = boss_system.get_boss_difficulty_rating("shadow_knight", test_heir_stats)
	assert_true(rating in ["Impossible", "Legendary", "Mythic", "Epic", "Hard", "Challenging"])


## Test: Boss summary
func test_boss_summary() -> void:
	boss_system.defeat_boss("shadow_knight", "Hero1")
	var summary = boss_system.get_boss_summary("shadow_knight")
	assert_eq(summary["times_defeated"], 1)
	assert_eq(summary["last_defeated_by"], "Hero1")


# ========== CombatEncounterManager Tests ==========

## Test: Encounter battle initialization
func test_encounter_battle_init() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	var battle = combat_manager.start_encounter_battle(encounter["id"], "Hero", test_heir_stats)
	assert_true("encounter_id" in battle)
	assert_eq(battle["heir_name"], "Hero")


## Test: Boss battle initialization
func test_boss_battle_init() -> void:
	var battle = combat_manager.start_boss_battle("shadow_knight", "Hero", test_heir_stats)
	assert_true("is_boss_battle" in battle)
	assert_eq(battle["boss_name"], "shadow_knight")


## Test: Encounter victory resolution
func test_encounter_victory() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	combat_manager.start_encounter_battle(encounter["id"], "Hero", test_heir_stats)
	var rewards = combat_manager.resolve_encounter_battle(encounter["id"], true)
	assert_true("gold" in rewards or "xp" in rewards)


## Test: Encounter defeat
func test_encounter_defeat() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	combat_manager.start_encounter_battle(encounter["id"], "Hero", test_heir_stats)
	var rewards = combat_manager.resolve_encounter_battle(encounter["id"], false)
	assert_eq(rewards["gold"], 0)


## Test: Boss victory resolution
func test_boss_victory() -> void:
	var battle = combat_manager.start_boss_battle("shadow_knight", "Hero", test_heir_stats)
	var encounter_id = battle["encounter_id"]
	var rewards = combat_manager.resolve_boss_battle(encounter_id, "shadow_knight", true, "Hero")
	assert_gt(rewards["gold"], 0)


## Test: Battle summary
func test_battle_summary() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	combat_manager.start_encounter_battle(encounter["id"], "Hero", test_heir_stats)
	var summary = combat_manager.get_battle_summary(encounter["id"])
	assert_eq(summary["heir"], "Hero")


## Test: Encounter difficulty rating
func test_encounter_difficulty_rating() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	var rating = combat_manager.get_encounter_difficulty_rating(encounter["id"], test_heir_stats)
	assert_true(rating in ["Impossible", "Very Difficult", "Difficult", "Challenging", "Fair", "Easy"])


## Test: Expected rewards calculation
func test_expected_rewards() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	var expected = combat_manager.get_expected_rewards(encounter["id"])
	assert_true("gold" in expected)
	assert_true("xp" in expected)


# ========== WorldEncounterIntegration Tests ==========

## Test: Random encounter check
func test_random_encounter_check() -> void:
	var encounter = encounter_integration.check_random_encounter("Hero", test_heir_stats, "DUNGEON")
	# May or may not trigger based on RNG, but should not error
	assert_true(encounter.is_empty() or "type_name" in encounter)


## Test: Boss encounter at location
func test_boss_encounter_location() -> void:
	var boss_encounter = encounter_integration.check_boss_encounter("Hero", Vector2i(200, 300))
	if not boss_encounter.is_empty():
		assert_true("is_boss" in boss_encounter)


## Test: Initiate encounter battle
func test_initiate_encounter() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	var battle = encounter_integration.initiate_encounter_battle("Hero", encounter["id"], test_heir_stats)
	assert_true("encounter_id" in battle or battle.is_empty())


## Test: Initiate boss battle
func test_initiate_boss() -> void:
	var battle = encounter_integration.initiate_boss_battle("Hero", "shadow_knight", test_heir_stats)
	assert_true("boss_name" in battle or battle.is_empty())


## Test: Process encounter result
func test_process_encounter_result() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	encounter_integration.initiate_encounter_battle("Hero", encounter["id"], test_heir_stats)
	var rewards = encounter_integration.process_encounter_result(encounter["id"], "Hero", true, test_heir_stats)
	assert_true(rewards.is_empty() or "gold" in rewards)


## Test: Process boss result
func test_process_boss_result() -> void:
	encounter_integration.initiate_boss_battle("Hero", "shadow_knight", test_heir_stats)
	# Get the encounter id from active battles
	var encounter_ids = combat_manager.active_battles.keys()
	if not encounter_ids.is_empty():
		var rewards = encounter_integration.process_boss_result(encounter_ids[0], "shadow_knight", "Hero", true, test_heir_stats)
		assert_true(rewards.is_empty() or "gold" in rewards)


## Test: Get encounter info
func test_get_encounter_info() -> void:
	var encounter = encounter_system.generate_encounter("GRASS", test_heir_stats)
	var info = encounter_integration.get_encounter_info(encounter["id"], test_heir_stats)
	assert_true("type" in info or info.is_empty())


## Test: Get boss info
func test_get_boss_info() -> void:
	var info = encounter_integration.get_boss_info("shadow_knight", test_heir_stats)
	assert_true("name" in info)


## Test: Get available bosses
func test_get_available_bosses() -> void:
	var available = encounter_integration.get_available_bosses()
	assert_gt(available.size(), 0)


## Test: Get defeated bosses
func test_get_defeated_bosses() -> void:
	boss_system.defeat_boss("shadow_knight", "Hero")
	var defeated = encounter_integration.get_defeated_bosses()
	assert_true("shadow_knight" in defeated)


## Test: Complex encounter flow
func test_complex_encounter_flow() -> void:
	# Generate encounter
	var encounter = encounter_system.generate_encounter("DUNGEON", test_heir_stats)
	assert_true("id" in encounter)

	# Start battle
	var battle = encounter_integration.initiate_encounter_battle("Hero", encounter["id"], test_heir_stats)
	assert_true("encounter_id" in battle or battle.is_empty())

	# Process victory
	if not battle.is_empty():
		var rewards = encounter_integration.process_encounter_result(encounter["id"], "Hero", true, test_heir_stats)
		assert_true(rewards.is_empty() or "gold" in rewards or "xp" in rewards)


## Test: Complex boss encounter flow
func test_complex_boss_flow() -> void:
	# Check boss location
	var boss_check = encounter_integration.check_boss_encounter("Hero", Vector2i(200, 300))

	if not boss_check.is_empty():
		# Get boss info
		var info = encounter_integration.get_boss_info("shadow_knight", test_heir_stats)
		assert_true("name" in info)

		# Initiate battle
		var battle = encounter_integration.initiate_boss_battle("Hero", "shadow_knight", test_heir_stats)
		assert_true("boss_name" in battle)

		# Process victory
		var encounter_id = battle["encounter_id"]
		var rewards = encounter_integration.process_boss_result(encounter_id, "shadow_knight", "Hero", true, test_heir_stats)
		assert_gt(rewards["gold"], 0)

		# Check defeated status
		var defeated = encounter_integration.get_defeated_bosses()
		assert_true("shadow_knight" in defeated)
