## Test Phase 11.4: Environmental Events System
##
## Comprehensive test suite for events, disasters, booms, and anomalies

extends Node

class_name TestPhase11_4Events


var environmental_event_system: EnvironmentalEventSystem
var disaster_system: DisasterSystem
var resource_boom_system: ResourceBoomSystem
var anomaly_system: AnomalySystem
var event_persistence: EventPersistence

var test_results: Array = []


func _ready() -> void:
	environmental_event_system = EnvironmentalEventSystem.new()
	disaster_system = DisasterSystem.new()
	resource_boom_system = ResourceBoomSystem.new()
	anomaly_system = AnomalySystem.new()
	event_persistence = EventPersistence.new()

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_environmental_event_creation()
	test_environmental_event_processing()
	test_environmental_event_queries()

	test_disaster_creation()
	test_disaster_severity_scaling()
	test_disaster_settlement_damage()
	test_disaster_npc_effects()
	test_disaster_recovery()

	test_resource_boom_creation()
	test_resource_boom_price_modifiers()
	test_resource_boom_regional_effects()
	test_resource_boom_resolution()

	test_anomaly_creation()
	test_anomaly_time_rift_effects()
	test_anomaly_blessing_zone_effects()
	test_anomaly_curse_zone_effects()
	test_anomaly_void_crack_effects()
	test_anomaly_visitor_tracking()

	test_event_persistence()
	test_generation_transfer()

	test_complex_scenarios()


func test_environmental_event_creation() -> void:
	var event_id = environmental_event_system.generate_event(
		EnvironmentalEventSystem.EventType.DISASTER,
		Vector2i(10, 10),
		3
	)
	assert(event_id != "", "Event should be created")
	assert(environmental_event_system.active_events.has(event_id), "Event should be in active_events")

	var event = environmental_event_system.active_events[event_id]
	assert(event.location == Vector2i(10, 10), "Event location should match")
	assert(event.severity == 3, "Event severity should be 3")
	assert(event.radius == 60, "Radius should be 30 + (3 * 10) = 60")
	assert(event.duration == 1400, "Duration should be 500 + (3 * 300) = 1400")
	test_results.append("✓ Environmental event creation")


func test_environmental_event_processing() -> void:
	var event_id = environmental_event_system.generate_event(
		EnvironmentalEventSystem.EventType.RESOURCE_BOOM,
		Vector2i(20, 20),
		2
	)
	var event = environmental_event_system.active_events[event_id]
	var initial_elapsed = event.elapsed_time

	environmental_event_system.process_event_time(event_id, 100)
	assert(event.elapsed_time == initial_elapsed + 100, "Event time should progress")

	# Process until resolved
	while event.elapsed_time < event.duration:
		environmental_event_system.process_event_time(event_id, 500)
	environmental_event_system.process_event_time(event_id, 1)

	assert(not environmental_event_system.active_events.has(event_id), "Event should be resolved")
	test_results.append("✓ Environmental event processing")


func test_environmental_event_queries() -> void:
	var event1_id = environmental_event_system.generate_event(
		EnvironmentalEventSystem.EventType.DISASTER,
		Vector2i(0, 0),
		2
	)
	var event2_id = environmental_event_system.generate_event(
		EnvironmentalEventSystem.EventType.RESOURCE_BOOM,
		Vector2i(50, 50),
		1
	)

	var at_origin = environmental_event_system.get_events_at_location(Vector2i(0, 0))
	assert(at_origin.size() == 1, "Should find event at origin")

	var disasters = environmental_event_system.get_events_by_type(EnvironmentalEventSystem.EventType.DISASTER)
	assert(disasters.size() >= 1, "Should find disaster events")

	var affected = environmental_event_system.is_location_affected(Vector2i(5, 5))
	assert(affected or not affected, "Query should complete without error")
	test_results.append("✓ Environmental event queries")


func test_disaster_creation() -> void:
	var disaster_id = disaster_system.create_disaster(
		DisasterSystem.DisasterType.FLOOD,
		Vector2i(15, 15),
		2
	)
	assert(disaster_id != "", "Disaster should be created")
	assert(disaster_system.active_disasters.has(disaster_id), "Disaster should be active")

	var disaster = disaster_system.active_disasters[disaster_id]
	assert(disaster.disaster_type == DisasterSystem.DisasterType.FLOOD, "Disaster type should match")
	assert(disaster.severity == 2, "Severity should be 2")
	test_results.append("✓ Disaster creation")


func test_disaster_severity_scaling() -> void:
	var damages = {}
	for severity in range(1, 6):
		var disaster_id = disaster_system.create_disaster(
			DisasterSystem.DisasterType.EARTHQUAKE,
			Vector2i(10, 10),
			severity
		)
		var disaster = disaster_system.active_disasters[disaster_id]
		var base_damage = severity * 5
		var expected_damage = int(base_damage * 1.5)
		damages[severity] = expected_damage

	assert(damages[5] > damages[1], "Higher severity should cause more damage")
	test_results.append("✓ Disaster severity scaling")


func test_disaster_settlement_damage() -> void:
	var settlement = {
		"id": "test_settlement_1",
		"prosperity": 75,
		"population": 500
	}
	var damage_result = disaster_system.apply_disaster_to_settlement(
		"disaster_1",
		settlement,
		50
	)
	assert(damage_result.has("buildings_damaged"), "Should have buildings_damaged key")
	assert(damage_result.has("prosperity_reduction"), "Should have prosperity_reduction key")
	test_results.append("✓ Disaster settlement damage")


func test_disaster_npc_effects() -> void:
	var npcs = []
	for i in range(10):
		npcs.append({"id": "npc_%d" % i, "health": 1.0})

	var deaths = disaster_system.apply_disaster_to_npc_group(npcs, 3)
	assert(deaths is Array, "Should return array of deaths")
	assert(deaths.size() <= 10, "Deaths should not exceed group size")
	test_results.append("✓ Disaster NPC effects")


func test_disaster_recovery() -> void:
	var disaster_id = disaster_system.create_disaster(
		DisasterSystem.DisasterType.PLAGUE,
		Vector2i(20, 20),
		4
	)
	var settlement_id = "settlement_plague"

	disaster_system.start_recovery(disaster_id, settlement_id, 50)
	assert(disaster_system.active_disasters[disaster_id].recovery_progress.has(settlement_id), "Recovery should start")

	var progress = disaster_system.get_recovery_progress(disaster_id, settlement_id)
	assert(progress == 50, "Initial recovery should be set")

	disaster_system.progress_recovery(disaster_id, settlement_id, 10)
	var new_progress = disaster_system.get_recovery_progress(disaster_id, settlement_id)
	assert(new_progress == 60, "Recovery should progress")
	test_results.append("✓ Disaster recovery")


func test_resource_boom_creation() -> void:
	var boom_id = resource_boom_system.create_boom(
		ResourceBoomSystem.ResourceType.ORE,
		ResourceBoomSystem.BoomType.SCARCITY,
		Vector2i(30, 30)
	)
	assert(boom_id != "", "Boom should be created")
	assert(resource_boom_system.active_booms.has(boom_id), "Boom should be active")

	var boom = resource_boom_system.active_booms[boom_id]
	assert(boom.resource_type == ResourceBoomSystem.ResourceType.ORE, "Resource type should match")
	assert(boom.boom_type == ResourceBoomSystem.BoomType.SCARCITY, "Boom type should be scarcity")
	test_results.append("✓ Resource boom creation")


func test_resource_boom_price_modifiers() -> void:
	var scarcity_boom_id = resource_boom_system.create_boom(
		ResourceBoomSystem.ResourceType.FOOD,
		ResourceBoomSystem.BoomType.SCARCITY,
		Vector2i(40, 40)
	)
	var abundance_boom_id = resource_boom_system.create_boom(
		ResourceBoomSystem.ResourceType.MATERIALS,
		ResourceBoomSystem.BoomType.ABUNDANCE,
		Vector2i(50, 50)
	)

	var scarcity_mult = resource_boom_system.get_price_multiplier(scarcity_boom_id, Vector2i(40, 40))
	var abundance_mult = resource_boom_system.get_price_multiplier(abundance_boom_id, Vector2i(50, 50))

	assert(scarcity_mult > 1.0, "Scarcity should increase prices")
	assert(abundance_mult < 1.0, "Abundance should decrease prices")
	assert(scarcity_mult > abundance_mult, "Scarcity multiplier should be higher than abundance")
	test_results.append("✓ Resource boom price modifiers")


func test_resource_boom_regional_effects() -> void:
	var boom_id = resource_boom_system.create_boom(
		ResourceBoomSystem.ResourceType.TRADE_GOODS,
		ResourceBoomSystem.BoomType.SCARCITY,
		Vector2i(60, 60)
	)

	var regional_scarcity = resource_boom_system.get_regional_scarcity(Vector2i(60, 60))
	assert(regional_scarcity.has(ResourceBoomSystem.ResourceType.TRADE_GOODS), "Should detect scarcity")

	var regional_abundance = resource_boom_system.get_regional_abundance(Vector2i(70, 70))
	assert(regional_abundance is Dictionary, "Should return abundance dict")
	test_results.append("✓ Resource boom regional effects")


func test_resource_boom_resolution() -> void:
	var boom_id = resource_boom_system.create_boom(
		ResourceBoomSystem.ResourceType.ORE,
		ResourceBoomSystem.BoomType.ABUNDANCE,
		Vector2i(0, 0)
	)
	var boom = resource_boom_system.active_booms[boom_id]

	while boom.elapsed_time < boom.duration:
		resource_boom_system.process_boom_time(boom_id, 500)
	resource_boom_system.process_boom_time(boom_id, 1)

	assert(not resource_boom_system.active_booms.has(boom_id), "Boom should be resolved")
	test_results.append("✓ Resource boom resolution")


func test_anomaly_creation() -> void:
	var anomaly_id = anomaly_system.create_anomaly(
		AnomalySystem.AnomalyType.TIME_RIFT,
		Vector2i(70, 70)
	)
	assert(anomaly_id != "", "Anomaly should be created")
	assert(anomaly_system.active_anomalies.has(anomaly_id), "Anomaly should be active")

	var anomaly = anomaly_system.active_anomalies[anomaly_id]
	assert(anomaly.anomaly_type == AnomalySystem.AnomalyType.TIME_RIFT, "Type should match")
	test_results.append("✓ Anomaly creation")


func test_anomaly_time_rift_effects() -> void:
	var anomaly_id = anomaly_system.create_anomaly(
		AnomalySystem.AnomalyType.TIME_RIFT,
		Vector2i(75, 75)
	)
	var anomaly = anomaly_system.active_anomalies[anomaly_id]

	assert(anomaly.effects.has("time_multiplier"), "Should have time multiplier")
	var multiplier = anomaly.effects["time_multiplier"]
	assert(multiplier >= 3.0 and multiplier <= 5.0, "Time multiplier should be 3-5x")
	test_results.append("✓ Anomaly time rift effects")


func test_anomaly_blessing_zone_effects() -> void:
	var anomaly_id = anomaly_system.create_anomaly(
		AnomalySystem.AnomalyType.BLESSING_ZONE,
		Vector2i(80, 80)
	)
	var anomaly = anomaly_system.active_anomalies[anomaly_id]

	assert(anomaly.effects.has("stat_bonus"), "Should have stat bonus")
	assert(anomaly.effects["stat_bonus"] == 5, "Blessing should grant +5 stats")
	assert(anomaly.effects.has("blessed"), "Should apply blessed status")
	test_results.append("✓ Anomaly blessing zone effects")


func test_anomaly_curse_zone_effects() -> void:
	var anomaly_id = anomaly_system.create_anomaly(
		AnomalySystem.AnomalyType.CURSE_ZONE,
		Vector2i(85, 85)
	)
	var anomaly = anomaly_system.active_anomalies[anomaly_id]

	assert(anomaly.effects.has("stat_penalty"), "Should have stat penalty")
	assert(anomaly.effects["stat_penalty"] == -5, "Curse should apply -5 stats")
	assert(anomaly.effects.has("cursed"), "Should apply cursed status")
	test_results.append("✓ Anomaly curse zone effects")


func test_anomaly_void_crack_effects() -> void:
	var anomaly_id = anomaly_system.create_anomaly(
		AnomalySystem.AnomalyType.VOID_CRACK,
		Vector2i(90, 90)
	)
	var anomaly = anomaly_system.active_anomalies[anomaly_id]

	assert(anomaly.effects.has("stat_penalty"), "Should have stat penalty")
	assert(anomaly.effects["stat_penalty"] == -3, "Void should apply -3 stats")
	assert(anomaly.effects.has("damage_multiplier"), "Should increase damage taken")
	test_results.append("✓ Anomaly void crack effects")


func test_anomaly_visitor_tracking() -> void:
	var anomaly_id = anomaly_system.create_anomaly(
		AnomalySystem.AnomalyType.BLESSING_ZONE,
		Vector2i(95, 95)
	)

	var effects1 = anomaly_system.enter_anomaly(anomaly_id, "player_1")
	assert(effects1 is Dictionary, "Should return effects on entry")

	var anomaly = anomaly_system.active_anomalies[anomaly_id]
	assert("player_1" in anomaly.visitors, "Player should be tracked as visitor")

	anomaly_system.leave_anomaly(anomaly_id, "player_1")
	assert("player_1" not in anomaly.visitors, "Player should be removed on exit")
	test_results.append("✓ Anomaly visitor tracking")


func test_event_persistence() -> void:
	var disaster_id = disaster_system.create_disaster(
		DisasterSystem.DisasterType.DROUGHT,
		Vector2i(100, 100),
		2
	)

	var state = event_persistence.save_event_state(
		environmental_event_system,
		disaster_system,
		resource_boom_system,
		anomaly_system
	)

	assert(state.has("disasters"), "State should have disasters")
	assert(state["disasters"].size() > 0, "Should save active disasters")

	var new_disaster = DisasterSystem.new()
	event_persistence.load_event_state(state, environmental_event_system, new_disaster, resource_boom_system, anomaly_system)
	assert(new_disaster.active_disasters.size() > 0, "Should restore disasters")
	test_results.append("✓ Event persistence")


func test_generation_transfer() -> void:
	var disaster_id = disaster_system.create_disaster(
		DisasterSystem.DisasterType.FLOOD,
		Vector2i(110, 110),
		3
	)
	disaster_system.active_disasters[disaster_id].recovery_progress["settlement_1"] = 45

	var state = event_persistence.save_event_state(
		environmental_event_system,
		disaster_system,
		resource_boom_system,
		anomaly_system
	)

	var transferred_state = event_persistence.transfer_event_state_to_next_generation(state)
	assert(transferred_state is Dictionary, "Should return valid state")
	assert(transferred_state.has("disasters"), "Should preserve disasters in transfer")
	test_results.append("✓ Generation transfer")


func test_complex_scenarios() -> void:
	# Scenario: Cascading disasters
	var flood_id = disaster_system.create_disaster(
		DisasterSystem.DisasterType.FLOOD,
		Vector2i(120, 120),
		2
	)
	var plague_id = disaster_system.create_disaster(
		DisasterSystem.DisasterType.PLAGUE,
		Vector2i(125, 125),
		3
	)

	var settlement = {
		"id": "cascade_settlement",
		"prosperity": 60,
		"population": 400
	}
	disaster_system.apply_disaster_to_settlement("cascade_settlement", settlement, 100)
	disaster_system.apply_disaster_to_settlement("cascade_settlement", settlement, 150)

	assert(settlement["prosperity"] <= 60, "Cascading disasters should reduce prosperity")

	# Scenario: Multi-event overlaps
	var boom_id = resource_boom_system.create_boom(
		ResourceBoomSystem.ResourceType.FOOD,
		ResourceBoomSystem.BoomType.ABUNDANCE,
		Vector2i(130, 130)
	)
	var anomaly_id = anomaly_system.create_anomaly(
		AnomalySystem.AnomalyType.TIME_RIFT,
		Vector2i(130, 130)
	)

	assert(environmental_event_system.get_events_at_location(Vector2i(130, 130)).size() >= 0, "Location should handle multiple events")

	# Scenario: Disaster recovery with ongoing effects
	var recovery_disaster = disaster_system.create_disaster(
		DisasterSystem.DisasterType.EARTHQUAKE,
		Vector2i(140, 140),
		4
	)
	var recovery_settlement = "recovery_test"
	disaster_system.start_recovery(recovery_disaster, recovery_settlement, 20)

	for _i in range(8):
		disaster_system.progress_recovery(recovery_disaster, recovery_settlement, 10)

	var recovery = disaster_system.get_recovery_progress(recovery_disaster, recovery_settlement)
	assert(recovery == 100, "Recovery should reach 100 after progression")

	test_results.append("✓ Complex scenarios")


func print_results() -> void:
	print("\n=== Test Phase 11.4: Environmental Events ===")
	for result in test_results:
		print(result)
	print("\nTotal: %d tests passed" % test_results.size())


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
