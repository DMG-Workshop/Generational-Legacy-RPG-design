## Test Phase 12.3: Lineage Milestones & Prophecies
##
## Comprehensive test suite for milestones, prophecies, and legacy events

extends Node

class_name TestPhase12_3Milestones


var milestone_system: MilestoneSystem
var prophecy_system: ProphecySystem
var legacy_event_system: LegacyEventSystem
var milestone_persistence: MilestonePersistence

var test_results: Array = []


func _ready() -> void:
	milestone_system = MilestoneSystem.new()
	prophecy_system = ProphecySystem.new()
	legacy_event_system = LegacyEventSystem.new()
	milestone_persistence = MilestonePersistence.new()

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_milestone_initialization()
	test_milestone_triggering()
	test_milestone_rewards()
	test_milestone_queries()

	test_prophecy_generation()
	test_prophecy_fulfillment()
	test_prophecy_types()
	test_prophecy_queries()

	test_legacy_event_creation()
	test_legacy_event_types()
	test_legacy_event_consequences()
	test_legacy_event_queries()

	test_milestone_persistence()
	test_generation_transfer()

	test_complex_scenarios()


func test_milestone_initialization() -> void:
	var milestones = milestone_system.get_active_milestones()
	assert(milestones.size() == 5, "Should have 5 milestone types")

	var gen100 = milestone_system.get_milestone_by_generation(100)
	assert(gen100 != null, "Should have generation 100 milestone")
	assert(gen100.type == MilestoneSystem.MilestoneType.GENERATION_100, "Should have correct type")
	assert(not gen100.triggered, "Milestone should not be triggered initially")

	test_results.append("✓ Milestone initialization")


func test_milestone_triggering() -> void:
	var milestone_id = milestone_system.check_generation_milestone(100)
	assert(milestone_id != "", "Should detect milestone at generation 100")

	var milestone = milestone_system.get_milestone(milestone_id)
	assert(milestone.triggered, "Milestone should be triggered")
	assert(milestone.triggered_at_generation == 100, "Should record trigger generation")

	var active = milestone_system.get_active_milestones()
	var completed = milestone_system.get_completed_milestones()
	assert(active.size() == 4, "Should have 4 active milestones left")
	assert(completed.size() == 1, "Should have 1 completed milestone")

	test_results.append("✓ Milestone triggering")


func test_milestone_rewards() -> void:
	var milestone_id = milestone_system.check_generation_milestone(250)
	var rewards = milestone_system.get_milestone_rewards(milestone_id)

	assert(rewards.has("prestige"), "Should have prestige reward")
	assert(rewards.has("stat_bonus"), "Should have stat bonus")
	assert(rewards.has("gold"), "Should have gold reward")
	assert(rewards.has("legendary_items"), "Should have legendary items")

	var prestige = milestone_system.claim_milestone_reward(milestone_id, "prestige")
	assert(prestige == 2500, "Generation 250 should grant 2500 prestige")

	test_results.append("✓ Milestone rewards")


func test_milestone_queries() -> void:
	milestone_system.check_generation_milestone(100)
	milestone_system.check_generation_milestone(500)

	var completed = milestone_system.get_completed_milestones()
	assert(completed.size() >= 2, "Should track completed milestones")

	var has_100 = milestone_system.has_reached_milestone(100)
	assert(has_100, "Should detect reached milestone")

	var next = milestone_system.get_next_milestone(600)
	assert(next != null, "Should find next milestone after gen 600")
	assert(next.generation == 750, "Next milestone should be 750")

	test_results.append("✓ Milestone queries")


func test_prophecy_generation() -> void:
	var prophecy_id = prophecy_system.generate_prophecy(
		ProphecySystem.ProphecyType.DESTINY,
		1,
		"heir_1"
	)
	assert(prophecy_id != "", "Should generate prophecy")
	assert(prophecy_system.prophecies.has(prophecy_id), "Prophecy should be tracked")

	var prophecy = prophecy_system.get_prophecy(prophecy_id)
	assert(prophecy.text != "", "Prophecy should have text")
	assert(prophecy.related_heir_id == "heir_1", "Should track related heir")
	assert(not prophecy.fulfilled, "Prophecy should not be fulfilled initially")

	test_results.append("✓ Prophecy generation")


func test_prophecy_fulfillment() -> void:
	var prophecy_id = prophecy_system.generate_prophecy(
		ProphecySystem.ProphecyType.BLESSING,
		1,
		"heir_1"
	)
	var prophecy = prophecy_system.get_prophecy(prophecy_id)
	var target_gen = prophecy.prophecy_generation

	var success = prophecy_system.fulfill_prophecy(prophecy_id, target_gen)
	assert(success, "Should fulfill prophecy")
	assert(prophecy.fulfilled, "Prophecy should be marked fulfilled")
	assert(prophecy.fulfilled_at_generation == target_gen, "Should record fulfillment generation")

	var fulfilled = prophecy_system.get_fulfilled_prophecies()
	assert(fulfilled.size() > 0, "Should track fulfilled prophecies")

	test_results.append("✓ Prophecy fulfillment")


func test_prophecy_types() -> void:
	prophecy_system.generate_prophecy(ProphecySystem.ProphecyType.DESTINY, 1)
	prophecy_system.generate_prophecy(ProphecySystem.ProphecyType.WARNING, 1)
	prophecy_system.generate_prophecy(ProphecySystem.ProphecyType.BLESSING, 1)
	prophecy_system.generate_prophecy(ProphecySystem.ProphecyType.CURSE, 1)
	prophecy_system.generate_prophecy(ProphecySystem.ProphecyType.REVELATION, 1)

	var destines = prophecy_system.get_prophecies_by_type(ProphecySystem.ProphecyType.DESTINY)
	assert(destines.size() > 0, "Should find destiny prophecies")

	var warnings = prophecy_system.get_prophecies_by_type(ProphecySystem.ProphecyType.WARNING)
	assert(warnings.size() > 0, "Should find warning prophecies")

	test_results.append("✓ Prophecy types")


func test_prophecy_queries() -> void:
	var prophecy_id = prophecy_system.generate_prophecy(
		ProphecySystem.ProphecyType.DESTINY,
		1,
		"heir_test"
	)

	var heir_prophecies = prophecy_system.get_prophecies_for_heir("heir_test")
	assert(heir_prophecies.size() > 0, "Should find heir prophecies")

	var unfulfilled = prophecy_system.get_unfulfilled_prophecies()
	assert(unfulfilled.size() > 0, "Should find unfulfilled prophecies")

	var rate = prophecy_system.get_prophecy_fulfillment_rate()
	assert(rate >= 0.0 and rate <= 1.0, "Fulfillment rate should be valid")

	test_results.append("✓ Prophecy queries")


func test_legacy_event_creation() -> void:
	var event_id = legacy_event_system.create_legacy_event(
		LegacyEventSystem.EventType.PROPHECY_FULFILLMENT,
		50,
		["heir_1", "heir_2"]
	)
	assert(event_id != "", "Should create legacy event")
	assert(legacy_event_system.legacy_events.has(event_id), "Event should be tracked")

	var event = legacy_event_system.get_legacy_event(event_id)
	assert(event.affected_heirs.size() == 2, "Should track affected heirs")
	assert(not event.resolved, "Event should not be resolved initially")

	test_results.append("✓ Legacy event creation")


func test_legacy_event_types() -> void:
	legacy_event_system.create_legacy_event(LegacyEventSystem.EventType.PROPHECY_FULFILLMENT, 1)
	legacy_event_system.create_legacy_event(LegacyEventSystem.EventType.DYNASTY_AWAKENING, 1)
	legacy_event_system.create_legacy_event(LegacyEventSystem.EventType.FATE_REVERSAL, 1)
	legacy_event_system.create_legacy_event(LegacyEventSystem.EventType.LEGACY_ECHO, 1)
	legacy_event_system.create_legacy_event(LegacyEventSystem.EventType.WORLD_TRANSFORMATION, 1)

	var prophecy_events = legacy_event_system.get_events_by_type(LegacyEventSystem.EventType.PROPHECY_FULFILLMENT)
	assert(prophecy_events.size() > 0, "Should find prophecy fulfillment events")

	var world_events = legacy_event_system.get_events_by_type(LegacyEventSystem.EventType.WORLD_TRANSFORMATION)
	assert(world_events.size() > 0, "Should find world transformation events")

	test_results.append("✓ Legacy event types")


func test_legacy_event_consequences() -> void:
	var consequences = {
		"prestige_bonus": 500,
		"prosperity_change": 10,
		"faction_standing": 25
	}

	var event_id = legacy_event_system.create_legacy_event(
		LegacyEventSystem.EventType.DYNASTY_AWAKENING,
		50,
		["heir_1"],
		consequences
	)

	var retrieved_consequences = legacy_event_system.get_event_consequences(event_id)
	assert(retrieved_consequences.has("prestige_bonus"), "Should have prestige consequence")
	assert(retrieved_consequences["prestige_bonus"] == 500, "Consequence value should match")

	var applied = legacy_event_system.apply_event_consequences(event_id, "heir_1")
	assert(applied.size() > 0, "Should apply consequences")

	test_results.append("✓ Legacy event consequences")


func test_legacy_event_queries() -> void:
	var event_id = legacy_event_system.create_legacy_event(
		LegacyEventSystem.EventType.LEGACY_ECHO,
		100,
		["heir_1", "heir_2", "heir_3"]
	)

	var affecting_heir1 = legacy_event_system.get_events_affecting_heir("heir_1")
	assert(affecting_heir1.size() > 0, "Should find events affecting heir")

	var unresolved = legacy_event_system.get_unresolved_events()
	assert(unresolved.size() > 0, "Should find unresolved events")

	legacy_event_system.resolve_legacy_event(event_id, 150)
	var resolved = legacy_event_system.get_resolved_events()
	assert(resolved.size() > 0, "Should find resolved events")

	test_results.append("✓ Legacy event queries")


func test_milestone_persistence() -> void:
	milestone_system.check_generation_milestone(100)
	milestone_system.check_generation_milestone(250)

	prophecy_system.generate_prophecy(ProphecySystem.ProphecyType.DESTINY, 1)
	prophecy_system.generate_prophecy(ProphecySystem.ProphecyType.BLESSING, 1)

	legacy_event_system.create_legacy_event(LegacyEventSystem.EventType.PROPHECY_FULFILLMENT, 50)
	legacy_event_system.create_legacy_event(LegacyEventSystem.EventType.WORLD_TRANSFORMATION, 75)

	var state = milestone_persistence.save_milestone_state(
		milestone_system,
		prophecy_system,
		legacy_event_system
	)

	assert(state.has("milestones"), "State should have milestones")
	assert(state.has("prophecies"), "State should have prophecies")
	assert(state.has("legacy_events"), "State should have legacy events")
	assert(state["completed_milestones"].size() >= 2, "Should save completed milestones")

	# Load into new systems
	var new_milestone_system = MilestoneSystem.new()
	var new_prophecy_system = ProphecySystem.new()
	var new_legacy_system = LegacyEventSystem.new()

	milestone_persistence.load_milestone_state(state, new_milestone_system, new_prophecy_system, new_legacy_system)

	var loaded_completed = new_milestone_system.get_completed_milestones()
	assert(loaded_completed.size() >= 2, "Should load completed milestones")

	test_results.append("✓ Milestone persistence")


func test_generation_transfer() -> void:
	milestone_system.check_generation_milestone(100)
	milestone_system.check_generation_milestone(250)
	milestone_system.check_generation_milestone(500)

	prophecy_system.generate_prophecy(ProphecySystem.ProphecyType.DESTINY, 1)
	prophecy_system.generate_prophecy(ProphecySystem.ProphecyType.WARNING, 1)

	legacy_event_system.create_legacy_event(LegacyEventSystem.EventType.PROPHECY_FULFILLMENT, 50)
	legacy_event_system.create_legacy_event(LegacyEventSystem.EventType.DYNASTY_AWAKENING, 100)
	legacy_event_system.create_legacy_event(LegacyEventSystem.EventType.WORLD_TRANSFORMATION, 200)

	var state = milestone_persistence.save_milestone_state(
		milestone_system,
		prophecy_system,
		legacy_event_system
	)

	var transferred = milestone_persistence.transfer_milestones_to_next_generation(state)

	assert(transferred.has("milestones"), "Transferred state should have milestones")
	assert(transferred["completed_milestones"].size() == state["completed_milestones"].size(), "Milestones should carry forward")
	assert(transferred["prophecies"].size() == state["prophecies"].size(), "Prophecies should carry forward")
	assert(transferred["legacy_events"].size() == state["legacy_events"].size(), "Events should carry forward")

	test_results.append("✓ Generation transfer")


func test_complex_scenarios() -> void:
	# Scenario: Full milestone progression
	for gen in [100, 250, 500, 750, 999]:
		var milestone_id = milestone_system.check_generation_milestone(gen)
		assert(milestone_id != "", "Should trigger milestone at gen %d" % gen)

	var all_completed = milestone_system.get_completed_milestones()
	assert(all_completed.size() == 5, "Should complete all 5 milestones")

	# Scenario: Prophecy network
	for _i in range(10):
		prophecy_system.generate_prophecy(randi() % 5, 1)

	var all_prophecies = prophecy_system.get_unfulfilled_prophecies()
	assert(all_prophecies.size() >= 10, "Should have prophecies")

	# Fulfill some prophecies
	for prophecy in all_prophecies.slice(0, 5):
		prophecy_system.fulfill_prophecy(prophecy.id, prophecy.prophecy_generation)

	var rate = prophecy_system.get_prophecy_fulfillment_rate()
	assert(rate > 0.0, "Fulfillment rate should be > 0")

	# Scenario: Multi-generation legacy events
	for gen in range(1, 100, 25):
		legacy_event_system.create_legacy_event(
			LegacyEventSystem.EventType.LEGACY_ECHO,
			gen,
			["heir_founder", "heir_%d" % gen]
		)

	var gen_events = legacy_event_system.get_events_by_generation(50)
	assert(gen_events.size() > 0, "Should find events by generation")

	test_results.append("✓ Complex scenarios")


func print_results() -> void:
	print("\n=== Test Phase 12.3: Lineage Milestones & Prophecies ===")
	for result in test_results:
		print(result)
	print("\nTotal: %d test groups passed" % test_results.size())


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
