## Tests for the event system (Phase 5 - Events)
##
## Tests: event generation, event consequences, year advancement with events

extends GutTest


var event_system: EventSystem
var generation_manager: GenerationManager
var lineage: Lineage
var world: WorldManager


func before_each() -> void:
	event_system = EventSystem.new()
	lineage = Lineage.new(42)
	world = WorldManager.new()
	generation_manager = GenerationManager.new(lineage, world)


## Test: EventSystem initializes
func test_event_system_creates() -> void:
	assert_not_null(event_system)


## Test: Generate quest event
func test_generate_quest_event() -> void:
	var heir = Heir.new()
	heir.name = "Hero"
	heir.traits = []

	var event = event_system.generate_event(heir, 20, GenerationManager.LifePhase.ADULTHOOD, {})

	assert_not_null(event)
	assert_true(event.has("type"))


## Test: Generate marriage event in adulthood
func test_generate_marriage_event() -> void:
	var heir = Heir.new()
	heir.name = "Eligible"
	heir.traits = []

	# Marriage events only occur in adulthood (18-50)
	var event = event_system.generate_event(heir, 25, GenerationManager.LifePhase.ADULTHOOD, {})

	assert_not_null(event)
	# Might not be marriage, but should be some event
	assert_true(event.has("type"))


## Test: No marriage events in childhood
func test_no_marriage_in_childhood() -> void:
	var heir = Heir.new()
	heir.name = "Child"
	heir.traits = []

	# Generate many events to check distribution
	for i in range(10):
		var event = event_system.generate_event(heir, 10, GenerationManager.LifePhase.CHILDHOOD, {})
		# Childhood events should not include marriage
		assert_not_equal(event.get("type"), "marriage")


## Test: Apply quest consequences
func test_apply_quest_consequences() -> void:
	var heir = Heir.new()
	var quest_event = {
		"type": "quest",
		"reward": 100
	}

	var result = event_system.apply_event_consequences(heir, quest_event, true)

	assert_eq(result["wealth_change"], 100)


## Test: Apply marriage consequences
func test_apply_marriage_consequences() -> void:
	var heir = Heir.new()
	var marriage_event = {
		"type": "marriage",
		"bonuses": {"wealth": 50, "heirs": 1}
	}

	var result = event_system.apply_event_consequences(heir, marriage_event, true)

	assert_eq(result["wealth_change"], 50)
	assert_true("married" in result["trait_changes"])


## Test: Apply betrayal consequences
func test_apply_betrayal_consequences() -> void:
	var heir = Heir.new()
	var betrayal_event = {
		"type": "betrayal",
		"affected_faction": "warriors_order",
		"reputation_loss": 25
	}

	var result = event_system.apply_event_consequences(heir, betrayal_event, true)

	assert_eq(result["reputation_changes"]["warriors_order"], -25)


## Test: Year advancement includes events
func test_year_advancement_includes_events() -> void:
	var founder = lineage.create_founder("Test", "warrior", "merchant")
	generation_manager.begin_generation(founder)
	generation_manager.current_age = 20

	var event = generation_manager.advance_year()

	assert_not_null(event)
	assert_eq(generation_manager.current_age, 21)


## Test: Heir ages and phases progress correctly with events
func test_life_phases_with_events() -> void:
	var founder = lineage.create_founder("Lifer", "warrior", "merchant")
	generation_manager.begin_generation(founder)

	# Advance through childhood
	for age in range(13):
		generation_manager.advance_year()

	assert_eq(generation_manager.current_phase, GenerationManager.LifePhase.ADOLESCENCE)

	# Advance through adolescence
	for age in range(5):
		generation_manager.advance_year()

	assert_eq(generation_manager.current_phase, GenerationManager.LifePhase.ADULTHOOD)

	# Advance through adulthood
	for age in range(33):
		generation_manager.advance_year()

	assert_eq(generation_manager.current_phase, GenerationManager.LifePhase.ELDERHOOD)


## Test: Natural death at 65
func test_death_at_65_with_events() -> void:
	var founder = lineage.create_founder("Elder", "warrior", "merchant")
	generation_manager.begin_generation(founder)

	# Advance to age 65
	for age in range(65):
		generation_manager.advance_year()

	assert_eq(generation_manager.current_age, 65)

	# Next advance should trigger death
	var death_event = generation_manager.advance_year()

	assert_false(founder.is_alive)
	assert_eq(death_event["event_type"], "death")


## Test: Reputation consequences from events
func test_reputation_changes_from_events() -> void:
	var founder = lineage.create_founder("Noble", "warrior", "merchant")
	generation_manager.begin_generation(founder)

	var initial_standing = generation_manager.reputation_system.factions["general"].reputation

	# Generate a success event and apply consequences
	var success_event = {
		"type": "success",
		"reputation_gain": 25
	}

	var result = event_system.apply_event_consequences(founder, success_event, true)

	assert_eq(result["reputation_changes"]["general"], 25)
