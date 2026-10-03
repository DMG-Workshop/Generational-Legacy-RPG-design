## Test Suite for Phase 11.3: Faction & Reputation Systems
##
## Comprehensive tests for factions, standing, incidents, and effects

extends GutTest


var faction_system: FactionSystem
var reputation_system: FactionReputationSystem
var effects_system: FactionEffectsSystem
var incident_system: FactionIncidentSystem
var persistence_system: FactionPersistence


func before_each() -> void:
	faction_system = FactionSystem.new()
	reputation_system = FactionReputationSystem.new(faction_system)
	effects_system = FactionEffectsSystem.new(reputation_system)
	incident_system = FactionIncidentSystem.new(faction_system)
	persistence_system = FactionPersistence.new(faction_system, reputation_system, incident_system)


# ============================================================
# Faction System Tests
# ============================================================

func test_faction_system_created() -> void:
	assert_not_null(faction_system)


func test_default_factions_created() -> void:
	var all_factions = faction_system.get_all_factions()
	assert_eq(all_factions.size(), 4)


func test_faction_by_name() -> void:
	var empire = faction_system.get_faction("empire")
	assert_not_null(empire)
	assert_eq(empire.name, "The Empire")


func test_faction_alignment() -> void:
	var empire = faction_system.get_faction("empire")
	var syndicate = faction_system.get_faction("syndicate")
	
	assert_eq(empire.alignment, FactionSystem.FactionAlignment.GOOD)
	assert_eq(syndicate.alignment, FactionSystem.FactionAlignment.EVIL)


func test_add_faction_reputation() -> void:
	faction_system.add_faction_reputation("empire", 25)
	assert_eq(faction_system.get_faction_reputation("empire"), 25)


func test_faction_reputation_clamped() -> void:
	faction_system.add_faction_reputation("empire", 200)
	assert_eq(faction_system.get_faction_reputation("empire"), 100)


func test_faction_war_declaration() -> void:
	faction_system.declare_war("empire", "syndicate")
	assert_true(faction_system.are_factions_at_war("empire", "syndicate"))


func test_faction_alliance() -> void:
	faction_system.form_alliance("empire", "ancients")
	assert_true(faction_system.are_factions_allied("empire", "ancients"))


func test_faction_truce() -> void:
	faction_system.declare_war("empire", "syndicate")
	faction_system.declare_truce("empire", "syndicate")
	assert_false(faction_system.are_factions_at_war("empire", "syndicate"))


func test_get_faction_tier() -> void:
	faction_system.add_faction_reputation("empire", 60)
	assert_eq(faction_system.get_faction_tier("empire"), "allied")


# ============================================================
# Reputation System Tests
# ============================================================

func test_reputation_system_created() -> void:
	assert_not_null(reputation_system)


func test_initialize_standings() -> void:
	var all_standings = reputation_system.get_all_standings()
	assert_eq(all_standings.size(), 4)


func test_add_faction_standing() -> void:
	reputation_system.add_standing("empire", 30)
	assert_eq(reputation_system.get_standing("empire"), 30)


func test_remove_faction_standing() -> void:
	reputation_system.add_standing("empire", 50)
	reputation_system.remove_standing("empire", 20)
	assert_eq(reputation_system.get_standing("empire"), 30)


func test_standing_tiers() -> void:
	reputation_system.add_standing("empire", 60)
	assert_eq(reputation_system.get_tier("empire"), "allied")
	
	reputation_system.add_standing("empire", -100)
	assert_eq(reputation_system.get_tier("empire"), "hostile")


func test_dominant_faction() -> void:
	reputation_system.add_standing("empire", 50)
	reputation_system.add_standing("syndicate", 30)
	
	assert_eq(reputation_system.get_dominant_faction(), "empire")


func test_allied_factions() -> void:
	reputation_system.add_standing("empire", 75)
	reputation_system.add_standing("ancients", 60)
	
	var allied = reputation_system.get_allied_factions()
	assert_eq(allied.size(), 2)


func test_hostile_factions() -> void:
	reputation_system.add_standing("syndicate", -60)
	
	var hostile = reputation_system.get_hostile_factions()
	assert_true("syndicate" in hostile)


func test_can_access_faction_quest() -> void:
	reputation_system.add_standing("empire", 30)
	assert_true(reputation_system.can_access_faction_quest("empire", "friendly"))


func test_interaction_bonus() -> void:
	reputation_system.add_standing("empire", 75)
	var bonus = reputation_system.get_faction_interaction_bonus("empire")
	assert_gt(bonus, 1.0)


# ============================================================
# Faction Effects Tests
# ============================================================

func test_effects_system_created() -> void:
	assert_not_null(effects_system)


func test_price_modifier_from_reputation() -> void:
	reputation_system.add_standing("empire", 50)
	var modifier = effects_system.calculate_price_modifier("empire")
	assert_lt(modifier, 1.0)


func test_dialogue_options_by_tier() -> void:
	reputation_system.add_standing("empire", 75)
	var options = effects_system.get_faction_dialogue_options("empire")
	assert_gt(options.size(), 0)


func test_encounter_type_by_standing() -> void:
	reputation_system.add_standing("syndicate", -60)
	var encounter = effects_system.get_encounter_type_for_faction("syndicate")
	assert_eq(encounter, "enemy_ambush")


func test_quest_reward_modifier() -> void:
	reputation_system.add_standing("empire", 60)
	var modifier = effects_system.get_quest_reward_modifier("empire")
	assert_gt(modifier, 1.0)


func test_commerce_effect() -> void:
	reputation_system.add_standing("empire", 40)
	var effect = effects_system.get_faction_commerce_effect("empire")
	
	assert_true("tier" in effect)
	assert_true("price_modifier" in effect)


func test_combat_effect() -> void:
	reputation_system.add_standing("empire", 50)
	var effect = effects_system.get_faction_combat_effect("empire")
	
	assert_gt(effect["encounter_modifier"], 1.0)
	assert_gt(effect["reward_multiplier"], 1.0)


func test_npc_reaction() -> void:
	var reaction = effects_system.get_faction_npc_reaction("empire", "empire")
	assert_eq(reaction, "friendly")


# ============================================================
# Incident System Tests
# ============================================================

func test_incident_system_created() -> void:
	assert_not_null(incident_system)


func test_create_war_incident() -> void:
	var incident_id = incident_system.create_incident(FactionIncidentSystem.IncidentType.WAR_DECLARATION, "empire", "syndicate")
	assert_true(incident_system.incidents.has(incident_id))


func test_create_alliance_incident() -> void:
	var incident_id = incident_system.create_incident(FactionIncidentSystem.IncidentType.ALLIANCE_FORMED, "empire", "ancients")
	
	var incident = incident_system.get_incident(incident_id)
	assert_eq(incident.type, FactionIncidentSystem.IncidentType.ALLIANCE_FORMED)


func test_escalate_incident() -> void:
	var incident_id = incident_system.create_incident(FactionIncidentSystem.IncidentType.WAR_DECLARATION, "empire", "syndicate")
	var old_level = incident_system.get_incident(incident_id).escalation_level
	
	incident_system.escalate_incident(incident_id)
	var new_level = incident_system.get_incident(incident_id).escalation_level
	
	assert_gt(new_level, old_level)


func test_resolve_incident() -> void:
	var incident_id = incident_system.create_incident(FactionIncidentSystem.IncidentType.WAR_DECLARATION, "empire", "syndicate")
	incident_system.resolve_incident(incident_id, "peace_treaty")
	
	var incident = incident_system.get_incident(incident_id)
	assert_eq(incident.escalation_level, FactionIncidentSystem.EscalationLevel.RESOLVED)


func test_get_active_incidents() -> void:
	incident_system.create_incident(FactionIncidentSystem.IncidentType.WAR_DECLARATION, "empire", "syndicate")
	incident_system.create_incident(FactionIncidentSystem.IncidentType.ALLIANCE_FORMED, "empire", "ancients")
	
	var active = incident_system.get_active_incidents()
	assert_eq(active.size(), 2)


func test_get_incidents_between_factions() -> void:
	var id1 = incident_system.create_incident(FactionIncidentSystem.IncidentType.WAR_DECLARATION, "empire", "syndicate")
	var id2 = incident_system.create_incident(FactionIncidentSystem.IncidentType.TRADE_DISPUTE, "empire", "syndicate")
	
	var relevant = incident_system.get_incidents_between_factions("empire", "syndicate")
	assert_eq(relevant.size(), 2)


func test_incident_prosperity_modifier() -> void:
	var incident_id = incident_system.create_incident(FactionIncidentSystem.IncidentType.WAR_DECLARATION, "empire", "syndicate")
	incident_system.escalate_incident(incident_id)
	
	var modifier = incident_system.get_incident_prosperity_modifier(incident_id)
	assert_lt(modifier, 0.0)


# ============================================================
# Persistence Tests
# ============================================================

func test_persistence_system_created() -> void:
	assert_not_null(persistence_system)


func test_save_faction_state() -> void:
	reputation_system.add_standing("empire", 40)
	var state = persistence_system.save_faction_state()
	
	assert_true("standings" in state)
	assert_true("empire" in state["standings"])


func test_load_faction_state() -> void:
	reputation_system.add_standing("empire", 50)
	var state = persistence_system.save_faction_state()
	
	reputation_system.standing_history["empire"].standing = 0
	persistence_system.load_faction_state(state)
	
	assert_eq(reputation_system.get_standing("empire"), 50)


func test_export_faction_history() -> void:
	reputation_system.add_standing("empire", 60)
	var history = persistence_system.export_faction_history()
	
	assert_true("current_standings" in history)
	assert_true("allied_factions" in history)


func test_faction_legacy() -> void:
	reputation_system.add_standing("empire", 75)
	var legacy = persistence_system.get_faction_legacy("empire")
	
	assert_eq(legacy["faction_id"], "empire")
	assert_eq(legacy["final_tier"], "allied")


# ============================================================
# Complex Scenario Tests
# ============================================================

func test_full_faction_lifecycle() -> void:
	var start_standing = reputation_system.get_standing("empire")
	
	reputation_system.add_standing("empire", 30)
	assert_gt(reputation_system.get_standing("empire"), start_standing)
	
	var info = reputation_system.get_faction_standing_info("empire")
	assert_eq(info["tier"], "friendly")


func test_multi_faction_conflict() -> void:
	incident_system.create_incident(FactionIncidentSystem.IncidentType.WAR_DECLARATION, "empire", "syndicate")
	incident_system.create_incident(FactionIncidentSystem.IncidentType.ALLIANCE_FORMED, "empire", "ancients")
	
	var active = incident_system.get_active_incidents()
	assert_eq(active.size(), 2)


func test_faction_effects_cascade() -> void:
	reputation_system.add_standing("empire", 50)
	
	var commerce = effects_system.get_faction_commerce_effect("empire")
	var combat = effects_system.get_faction_combat_effect("empire")
	
	assert_lt(commerce["price_modifier"], 1.0)
	assert_gt(combat["reward_multiplier"], 1.0)


func test_incident_to_persistence() -> void:
	reputation_system.add_standing("empire", 40)
	incident_system.create_incident(FactionIncidentSystem.IncidentType.WAR_DECLARATION, "empire", "syndicate")
	
	var state = persistence_system.save_faction_state()
	assert_true("incidents" in state)


func test_faction_decay_over_generations() -> void:
	reputation_system.add_standing("empire", 75)
	var initial = reputation_system.get_standing("empire")
	
	persistence_system.transfer_faction_state_to_next_generation()
	var degraded = reputation_system.get_standing("empire")
	
	assert_lt(degraded, initial)
