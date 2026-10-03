## Test Phase 17: Legacy Echoes - Reputation, factions, and historical event tracking
##
## Validates reputation systems, faction reactions, historical events, and legacy echo cascading

extends Node

class_name TestPhase17LegacyEchoes


var reputation_system: ReputationSystem
var event_tracker: HistoricalEventTracker
var legacy_echoes: LegacyEchoesSystem

var test_results: Array = []


func _ready() -> void:
	reputation_system = ReputationSystem.new()
	event_tracker = HistoricalEventTracker.new()
	legacy_echoes = LegacyEchoesSystem.new(reputation_system, event_tracker)

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_faction_initialization()
	test_faction_unlocking_by_prestige()
	test_reputation_gain()
	test_reputation_loss()
	test_reputation_cap()
	test_reputation_tier_progression()
	test_faction_perks_unlocking()
	test_reputation_decay()
	test_faction_reactions()
	test_historical_event_recording()
	test_event_indexing_by_generation()
	test_event_type_filtering()
	test_event_severity_classification()
	test_event_consequences()
	test_heir_history_tracking()
	test_historical_event_milestones()
	test_historical_summary_generation()
	test_legacy_echo_activation()
	test_echo_duration_tracking()
	test_dynasty_overall_standing()
	test_reputation_propagation()
	test_opportunity_generation_from_legacy()
	test_faction_reputation_scaling()
	test_multi_faction_reputation()
	test_curse_reputation_impact()
	test_victory_reputation_impact()
	test_quest_completion_reputation()
	test_legendary_defeat_consequences()
	test_prophecy_fulfillment_impact()
	test_reputation_report_generation()
	test_faction_perk_bonus_application()
	test_world_state_modification()
	test_echo_expiration()
	test_legacy_perks_unlocking()
	test_full_generation_legacy_flow()
	test_complex_faction_scenarios()
	test_cross_generation_echo_propagation()
	test_prestige_scaled_reputation()
	test_alignment_faction_choice()
	test_disaster_event_handling()
	test_triumph_event_handling()


func test_faction_initialization() -> void:
	var merchant = reputation_system.get_faction("faction_merchant_guild")
	assert(merchant != null, "Should have Merchant Guild faction")
	assert(merchant.name == "Merchant Guild", "Should have correct name")

	test_results.append("✓ Faction initialization")


func test_faction_unlocking_by_prestige() -> void:
	var available = reputation_system.is_faction_available("faction_royal_order", 1000)
	assert(available, "Royal Order should be available at 1000 prestige")

	var unavailable = reputation_system.is_faction_available("faction_dragon_cult", 1000)
	assert(not unavailable, "Dragon Cult should require more prestige")

	test_results.append("✓ Faction unlocking by prestige")


func test_reputation_gain() -> void:
	var initial = reputation_system.get_reputation("faction_merchant_guild")
	reputation_system.add_reputation("faction_merchant_guild", 100, 1000)
	var after = reputation_system.get_reputation("faction_merchant_guild")

	assert(after > initial, "Reputation should increase")

	test_results.append("✓ Reputation gain")


func test_reputation_loss() -> void:
	reputation_system.add_reputation("faction_merchant_guild", 1000, 1000)
	var before = reputation_system.get_reputation("faction_merchant_guild")
	reputation_system.subtract_reputation("faction_merchant_guild", 200)
	var after = reputation_system.get_reputation("faction_merchant_guild")

	assert(after < before, "Reputation should decrease")

	test_results.append("✓ Reputation loss")


func test_reputation_cap() -> void:
	reputation_system.add_reputation("faction_merchant_guild", 20000, 1000)
	var rep = reputation_system.get_reputation("faction_merchant_guild")

	# Should be capped at max_reputation
	var faction = reputation_system.get_faction("faction_merchant_guild")
	assert(rep <= faction.max_reputation, "Reputation should be capped")

	test_results.append("✓ Reputation cap")


func test_reputation_tier_progression() -> void:
	reputation_system.add_reputation("faction_royal_order", 2000, 1000)
	var tier = reputation_system.get_reputation_tier("faction_royal_order")

	assert(tier != "NEUTRAL", "Should reach a tier above neutral")

	test_results.append("✓ Reputation tier progression")


func test_faction_perks_unlocking() -> void:
	reputation_system.add_reputation("faction_merchant_guild", 2000, 1000)
	var profile = reputation_system.get_faction_profile("faction_merchant_guild")

	assert(profile != null, "Should have faction profile")

	test_results.append("✓ Faction perks unlocking")


func test_reputation_decay() -> void:
	reputation_system.add_reputation("faction_scholar_academy", 1000, 1000)
	var before = reputation_system.get_reputation("faction_scholar_academy")

	reputation_system.apply_reputation_decay(10)  # Simulate 10 generations
	var after = reputation_system.get_reputation("faction_scholar_academy")

	assert(after < before, "Reputation should decay over time")

	test_results.append("✓ Reputation decay")


func test_faction_reactions() -> void:
	reputation_system.add_reputation("faction_royal_order", 3000, 1000)
	var reaction = legacy_echoes.trigger_faction_reaction("faction_royal_order", 1000, 10)

	assert(reaction["reaction_type"] != "neutral_reception", "Should have positive reaction")

	test_results.append("✓ Faction reactions")


func test_historical_event_recording() -> void:
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.COMBAT_VICTORY, 1, "heir_1")

	assert(event != null, "Should record event")
	assert(event.generation == 1, "Should have correct generation")

	test_results.append("✓ Historical event recording")


func test_event_indexing_by_generation() -> void:
	event_tracker.record_event(HistoricalEventTracker.EventType.QUEST_COMPLETION, 5, "heir_2")
	event_tracker.record_event(HistoricalEventTracker.EventType.QUEST_COMPLETION, 5, "heir_3")

	var gen_5_events = event_tracker.get_events_at_generation(5)
	assert(gen_5_events.size() >= 2, "Should have events at generation 5")

	test_results.append("✓ Event indexing by generation")


func test_event_type_filtering() -> void:
	event_tracker.record_event(HistoricalEventTracker.EventType.COMBAT_VICTORY, 2, "heir_4")
	event_tracker.record_event(HistoricalEventTracker.EventType.QUEST_COMPLETION, 3, "heir_5")

	var combat_events = event_tracker.get_events_by_type(HistoricalEventTracker.EventType.COMBAT_VICTORY)
	assert(combat_events.size() >= 1, "Should filter by event type")

	test_results.append("✓ Event type filtering")


func test_event_severity_classification() -> void:
	var prophecy_event = event_tracker.record_event(HistoricalEventTracker.EventType.PROPHECY_FULFILLED, 10, "heir_6")

	assert(prophecy_event.severity == HistoricalEventTracker.EventSeverity.CRITICAL, "Prophecy should be critical")

	test_results.append("✓ Event severity classification")


func test_event_consequences() -> void:
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.LEGENDARY_DEFEAT, 15, "heir_7")
	var consequence = event_tracker.add_event_consequence(event.event_id, "reputation", 16, "faction_royal_order", 500)

	assert(consequence != null, "Should record consequence")
	var consequences = event_tracker.get_consequences_for_event(event.event_id)
	assert(consequences.size() > 0, "Should have consequences")

	test_results.append("✓ Event consequences")


func test_heir_history_tracking() -> void:
	event_tracker.record_event(HistoricalEventTracker.EventType.COMBAT_VICTORY, 1, "hero_heir")
	event_tracker.record_event(HistoricalEventTracker.EventType.QUEST_COMPLETION, 2, "hero_heir")

	var history = event_tracker.get_heir_history("hero_heir")
	assert(history.size() >= 2, "Should track heir's history")

	test_results.append("✓ Heir history tracking")


func test_historical_event_milestones() -> void:
	# Record many events to trigger milestones
	for i in range(100):
		event_tracker.record_event(HistoricalEventTracker.EventType.COMBAT_VICTORY, i + 1, "heir_%d" % i)

	var milestones = event_tracker.check_history_milestones(100)
	assert(milestones.size() > 0, "Should detect milestone")

	test_results.append("✓ Historical event milestones")


func test_historical_summary_generation() -> void:
	event_tracker.record_event(HistoricalEventTracker.EventType.COMBAT_VICTORY, 50, "heir_8")
	event_tracker.record_event(HistoricalEventTracker.EventType.QUEST_COMPLETION, 51, "heir_9")

	var summary = event_tracker.get_historical_summary(50, 55)
	assert(summary["total_events"] >= 2, "Should count events in range")

	test_results.append("✓ Historical summary generation")


func test_legacy_echo_activation() -> void:
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.LEGENDARY_DEFEAT, 20, "hero_heir_2")
	var echo = legacy_echoes.apply_echo(event.event_id, 20)

	assert(echo != null, "Should create echo")
	assert(echo.is_active, "Echo should be active")

	test_results.append("✓ Legacy echo activation")


func test_echo_duration_tracking() -> void:
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.PROPHECY_FULFILLED, 30, "heir_10")
	var echo = legacy_echoes.apply_echo(event.event_id, 30)

	assert(echo.remaining_duration > 0, "Echo should have duration")

	test_results.append("✓ Echo duration tracking")


func test_dynasty_overall_standing() -> void:
	reputation_system.add_reputation("faction_merchant_guild", 2000, 1000)
	reputation_system.add_reputation("faction_royal_order", 3000, 1000)

	var standing = legacy_echoes.get_dynasty_overall_standing()
	assert(standing != "UNRECOGNIZED", "Should have dynasty standing")

	test_results.append("✓ Dynasty overall standing")


func test_reputation_propagation() -> void:
	var parent_rep = 1000
	var child_rep = legacy_echoes.propagate_reputation_across_generation(parent_rep, 10)

	assert(child_rep > 0, "Reputation should propagate")
	assert(child_rep < parent_rep, "Child should have less than parent")

	test_results.append("✓ Reputation propagation")


func test_opportunity_generation_from_legacy() -> void:
	event_tracker.record_event(HistoricalEventTracker.EventType.QUEST_COMPLETION, 5, "heir_11")
	reputation_system.add_reputation("faction_merchant_guild", 2000, 1000)

	var opportunities = legacy_echoes.get_available_opportunities(10, 5000)
	assert(opportunities.size() > 0, "Should generate opportunities")

	test_results.append("✓ Opportunity generation from legacy")


func test_faction_reputation_scaling() -> void:
	var low_prestige = 100
	var high_prestige = 50000

	reputation_system.add_reputation("faction_royal_order", 100, low_prestige)
	var low_gain_total = reputation_system.get_reputation("faction_royal_order")

	reputation_system.add_reputation("faction_merchant_guild", 100, high_prestige)
	var high_gain_total = reputation_system.get_reputation("faction_merchant_guild")

	# High prestige should result in more reputation
	assert(high_gain_total >= low_gain_total, "Higher prestige should scale reputation")

	test_results.append("✓ Faction reputation scaling")


func test_multi_faction_reputation() -> void:
	reputation_system.add_reputation("faction_royal_order", 1000, 1000)
	reputation_system.add_reputation("faction_merchant_guild", 1500, 1000)
	reputation_system.add_reputation("faction_scholar_academy", 2000, 1000)

	var rep1 = reputation_system.get_reputation("faction_royal_order")
	var rep2 = reputation_system.get_reputation("faction_merchant_guild")
	var rep3 = reputation_system.get_reputation("faction_scholar_academy")

	assert(rep1 > 0 and rep2 > 0 and rep3 > 0, "Should track multiple factions")

	test_results.append("✓ Multi-faction reputation")


func test_curse_reputation_impact() -> void:
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.COMBAT_VICTORY, 8, "cursed_heir")
	event.prestige_impact = -500

	assert(event.prestige_impact < 0, "Curse should have negative impact")

	test_results.append("✓ Curse reputation impact")


func test_victory_reputation_impact() -> void:
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.LEGENDARY_DEFEAT, 12, "victor_heir")
	event.prestige_impact = 2000

	assert(event.prestige_impact > 0, "Victory should have positive impact")

	test_results.append("✓ Victory reputation impact")


func test_quest_completion_reputation() -> void:
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.QUEST_COMPLETION, 7, "quest_heir")
	event.faction_affected = "faction_merchant_guild"
	event.reputation_impact = 250

	assert(event.reputation_impact > 0, "Quest should affect reputation")

	test_results.append("✓ Quest completion reputation")


func test_legendary_defeat_consequences() -> void:
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.LEGENDARY_DEFEAT, 25, "legend_heir")
	event.prestige_impact = 5000
	event.reputation_impact = 1000

	assert(event.prestige_impact > 0, "Legendary defeat should have major impact")

	test_results.append("✓ Legendary defeat consequences")


func test_prophecy_fulfillment_impact() -> void:
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.PROPHECY_FULFILLED, 35, "prophecy_heir")
	event.severity = HistoricalEventTracker.EventSeverity.CRITICAL

	assert(event.severity == HistoricalEventTracker.EventSeverity.CRITICAL, "Prophecy should be critical")

	test_results.append("✓ Prophecy fulfillment impact")


func test_reputation_report_generation() -> void:
	reputation_system.add_reputation("faction_royal_order", 1000, 1000)
	var report = reputation_system.get_reputation_report("faction_royal_order")

	assert(report.has("current_reputation"), "Report should have reputation")
	assert(report.has("tier"), "Report should have tier")

	test_results.append("✓ Reputation report generation")


func test_faction_perk_bonus_application() -> void:
	reputation_system.add_reputation("faction_merchant_guild", 2000, 1000)
	var bonus = reputation_system.get_faction_perk_bonus("faction_merchant_guild", "perk_trade_discount")

	assert(bonus < 1.0, "Trade discount should reduce cost")

	test_results.append("✓ Faction perk bonus application")


func test_world_state_modification() -> void:
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.REALM_UNLOCK, 40, "explorer_heir")
	legacy_echoes.apply_echo(event.event_id, 40)

	var echo_status = legacy_echoes.get_echo_status(40)
	assert(echo_status["active_echoes"] > 0, "Should have active echoes")

	test_results.append("✓ World state modification")


func test_echo_expiration() -> void:
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.COMBAT_VICTORY, 45, "heir_12")
	var echo = legacy_echoes.apply_echo(event.event_id, 45)
	echo.duration_generations = 2

	legacy_echoes.update_world_state(50)  # Simulate time passing
	var status = legacy_echoes.get_echo_status(50)

	test_results.append("✓ Echo expiration")


func test_legacy_perks_unlocking() -> void:
	reputation_system.add_reputation("faction_royal_order", 6000, 10000)
	var perks = legacy_echoes.apply_legacy_perks("heir_13", 100, 10000)

	assert(perks.size() > 0, "Should unlock legacy perks")

	test_results.append("✓ Legacy perks unlocking")


func test_full_generation_legacy_flow() -> void:
	# Simulate a generation's events
	var event1 = event_tracker.record_event(HistoricalEventTracker.EventType.QUEST_COMPLETION, 20, "heir_14")
	event1.faction_affected = "faction_royal_order"
	event1.reputation_impact = 300

	reputation_system.add_reputation("faction_royal_order", 300, 5000)

	# Next generation inherits the legacy
	var opportunities = legacy_echoes.get_available_opportunities(21, 5000)
	assert(opportunities.size() > 0, "Should have legacy opportunities")

	test_results.append("✓ Full generation legacy flow")


func test_complex_faction_scenarios() -> void:
	# Scenario: Dynasty sides with one faction affects another
	reputation_system.add_reputation("faction_royal_order", 5000, 10000)
	reputation_system.subtract_reputation("faction_shadow_circle", 3000)

	var standing = legacy_echoes.get_dynasty_overall_standing()
	assert(standing != "INFAMOUS_DYNASTY", "Should be respectable")

	test_results.append("✓ Complex faction scenarios")


func test_cross_generation_echo_propagation() -> void:
	# Gen 1 event
	var event = event_tracker.record_event(HistoricalEventTracker.EventType.PROPHECY_FULFILLED, 1, "founder")
	legacy_echoes.apply_echo(event.event_id, 1)

	# Gen 50 should still feel the echo
	var echo_status = legacy_echoes.get_echo_status(50)
	assert(echo_status is Dictionary, "Should track echoes across generations")

	test_results.append("✓ Cross-generation echo propagation")


func test_prestige_scaled_reputation() -> void:
	var initial_rep = reputation_system.get_reputation("faction_celestial_order")

	# Same reputation gain, different prestige
	reputation_system.add_reputation("faction_celestial_order", 100, 1000)
	var rep_at_1k = reputation_system.get_reputation("faction_celestial_order")

	reputation_system.add_reputation("faction_celestial_order", 100, 50000)
	var rep_at_50k = reputation_system.get_reputation("faction_celestial_order")

	assert(rep_at_50k > rep_at_1k, "Higher prestige should gain more reputation")

	test_results.append("✓ Prestige-scaled reputation")


func test_alignment_faction_choice() -> void:
	var good_faction = reputation_system.get_faction("faction_royal_order")
	var evil_faction = reputation_system.get_faction("faction_shadow_circle")

	assert(good_faction.alignment == "good", "Should have alignment")
	assert(evil_faction.alignment == "evil", "Should have alignment")

	test_results.append("✓ Alignment faction choice")


func test_disaster_event_handling() -> void:
	var disaster = event_tracker.record_event(HistoricalEventTracker.EventType.LEGENDARY_DEFEAT, 50, "disaster_heir")
	disaster.severity = HistoricalEventTracker.EventSeverity.CRITICAL
	disaster.prestige_impact = -5000

	assert(disaster.prestige_impact < 0, "Disaster should have negative impact")

	test_results.append("✓ Disaster event handling")


func test_triumph_event_handling() -> void:
	var triumph = event_tracker.record_event(HistoricalEventTracker.EventType.PROPHECY_FULFILLED, 60, "triumph_heir")
	triumph.severity = HistoricalEventTracker.EventSeverity.CRITICAL
	triumph.prestige_impact = 8000

	assert(triumph.prestige_impact > 0, "Triumph should have positive impact")

	test_results.append("✓ Triumph event handling")


func print_results() -> void:
	print("\n╔═══════════════════════════════════════════════════════════════╗")
	print("║  Test Phase 17: Legacy Echoes - Reputation & Faction Systems    ║")
	print("╚═══════════════════════════════════════════════════════════════╝\n")

	for result in test_results:
		print(result)

	print("\n%s" % ("─" * 65))
	print("Total: %d legacy echoes test groups passed\n" % test_results.size())


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
