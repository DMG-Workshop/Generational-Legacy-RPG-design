## Tests for the generation loop system (Phase 4)
##
## Tests: life progression, heir transition, NPC ancestors, reputation, estates

extends GutTest


var gen_manager: GenerationManager
var lineage: Lineage
var world: WorldManager


func before_each() -> void:
	lineage = Lineage.new(42)
	world = WorldManager.new()
	gen_manager = GenerationManager.new(lineage, world)


## Test: Begin a generation with an heir
func test_begin_generation() -> void:
	var founder = lineage.create_founder("Theron", "warrior", "merchant")

	gen_manager.begin_generation(founder)

	assert_eq(gen_manager.current_heir, founder)
	assert_eq(gen_manager.current_age, 0)
	assert_eq(gen_manager.current_phase, GenerationManager.LifePhase.CHILDHOOD)


## Test: Advance through life phases
func test_life_phase_progression() -> void:
	var heir = Heir.new()
	heir.generation = 1
	heir.name = "Elena"
	heir.is_alive = true

	gen_manager.begin_generation(heir)

	# Childhood (0-12)
	for age in range(13):
		gen_manager.advance_year()
		assert_eq(gen_manager.current_phase, GenerationManager.LifePhase.CHILDHOOD)

	# Adolescence (13-17)
	gen_manager.advance_year()
	assert_eq(gen_manager.current_phase, GenerationManager.LifePhase.ADOLESCENCE)

	# Jump to adulthood
	gen_manager.current_age = 25
	gen_manager._update_life_phase()
	assert_eq(gen_manager.current_phase, GenerationManager.LifePhase.ADULTHOOD)

	# Jump to elderhood
	gen_manager.current_age = 55
	gen_manager._update_life_phase()
	assert_eq(gen_manager.current_phase, GenerationManager.LifePhase.ELDERHOOD)


## Test: Heir can marry and have children
func test_marriage_and_children() -> void:
	var heir = Heir.new()
	heir.generation = 0
	heir.name = "Marcus"
	heir.traits = ["warrior_steel"]
	heir.is_alive = true

	gen_manager.begin_generation(heir)

	# Move to adulthood
	gen_manager.current_age = 25
	gen_manager._update_life_phase()

	# Trigger marriage (might happen naturally with chance, so we'll do it directly)
	gen_manager._trigger_marriage()

	assert_not_null(gen_manager.spouse)

	# Have a child
	gen_manager._trigger_birth()

	assert_eq(gen_manager.children.size(), 1)
	assert_eq(gen_manager.children[0].mother, heir)


## Test: Natural death at age 65
func test_death_at_old_age() -> void:
	var heir = Heir.new()
	heir.generation = 0
	heir.name = "Old One"
	heir.is_alive = true

	gen_manager.begin_generation(heir)
	gen_manager.current_age = 65

	var event = gen_manager.advance_year()

	assert_false(heir.is_alive)
	assert_eq(event["event_type"], "death")


## Test: Transition to next heir
func test_generation_transition() -> void:
	var parent = Heir.new()
	parent.generation = 0
	parent.name = "Elena"
	parent.is_alive = true
	parent.traits = ["mageblood"]

	var child = Heir.new()
	child.generation = 1
	child.name = "Sophia"
	child.traits = ["ice_mage"]

	gen_manager.begin_generation(parent)
	gen_manager.children.append(child)

	var result = gen_manager.transition_to_heir(child)

	assert_true(result["success"])
	assert_eq(gen_manager.current_heir, child)
	assert_false(parent.is_alive)


## Test: NPC Ancestor creation
func test_ancestor_becomes_npc() -> void:
	var ancestor = Heir.new()
	ancestor.generation = 5
	ancestor.name = "Ancient One"
	ancestor.traits = ["dragonblood", "legendary"]

	var npc = gen_manager.npc_system.add_npc_ancestor(ancestor, 5)

	assert_not_null(npc)
	assert_eq(npc.heir, ancestor)
	assert_eq(npc.generation, 5)
	assert_true(npc.is_legendary)


## Test: Visit ancestor's tomb
func test_visit_ancestor_tomb() -> void:
	var ancestor = Heir.new()
	ancestor.generation = 10
	ancestor.name = "Wise Ancestor"
	ancestor.traits = ["the_sight"]

	var npc = gen_manager.npc_system.add_npc_ancestor(ancestor, 10)

	var heir = Heir.new()
	heir.generation = 25

	var interaction = gen_manager.npc_system.visit_ancestor(npc, heir)

	assert_not_null(interaction)
	assert_eq(interaction["ancestor"], ancestor.name)


## Test: Reputation with factions
func test_faction_reputation() -> void:
	gen_manager.reputation_system.add_reputation(0, "mages_circle", 25)

	var opinion = gen_manager.reputation_system.get_faction_opinion("mages_circle", 0)

	assert_eq(opinion["reputation"], 25)
	assert_eq(opinion["standing"], "trusted")


## Test: Legacy echo creation
func test_create_legacy_echo() -> void:
	gen_manager.reputation_system.create_legacy_echo(
		"Slew a dragon",
		5,
		"heroic",
		["warriors_order", "draconic_council"],
		40
	)

	assert_eq(gen_manager.reputation_system.legacy_echoes.size(), 1)

	var echo = gen_manager.reputation_system.legacy_echoes[0]
	assert_eq(echo.description, "Slew a dragon")
	assert_eq(echo.from_generation, 5)


## Test: Reputation inheritance to next heir
func test_reputation_inheritance() -> void:
	gen_manager.reputation_system.add_reputation(0, "warriors_order", 50)

	var inherited = gen_manager.reputation_system.get_inherited_reputation(1, lineage)

	# Child inherits 50% of parent's reputation
	assert_eq(inherited.get("warriors_order", 0), 25)


## Test: Create and maintain estate
func test_create_estate_property() -> void:
	var estate = gen_manager.estate_manager.create_property(
		"material",
		Vector3i(0, 0, 0),
		"estate",
		0
	)

	assert_not_null(estate)
	assert_eq(estate.property_type, "estate")
	assert_eq(estate.maintenance, 100)


## Test: Property decay over generations
func test_property_decay() -> void:
	var smithy = gen_manager.estate_manager.create_property(
		"material",
		Vector3i(10, 10, 0),
		"smithy",
		0
	)

	assert_eq(smithy.maintenance, 100)

	# Simulate 30 generations of neglect
	gen_manager.estate_manager.apply_decay(30)

	assert_lt(smithy.maintenance, 100)


## Test: Property maintenance restores condition
func test_maintain_property() -> void:
	var estate = gen_manager.estate_manager.create_property(
		"material",
		Vector3i(0, 0, 0),
		"estate",
		0
	)

	gen_manager.estate_manager.apply_decay(20)
	old_maintenance = estate.maintenance

	var heir = Heir.new()
	heir.generation = 20

	gen_manager.estate_manager.maintain_property(estate, heir, 50)

	assert_gt(estate.maintenance, old_maintenance)


## Test: Property upgrades increase income
func test_upgrade_smithy() -> void:
	var smithy = gen_manager.estate_manager.create_property(
		"material",
		Vector3i(10, 10, 0),
		"smithy",
		0
	)

	var initial_income = smithy.annual_income

	gen_manager.estate_manager.upgrade_feature(smithy, "forge")

	assert_gt(smithy.annual_income, initial_income)
	assert_eq(smithy.upgrades["forge"], 2)


## Test: Annual property income
func test_property_annual_income() -> void:
	gen_manager.estate_manager.create_property("material", Vector3i(0, 0, 0), "estate", 0)
	gen_manager.estate_manager.create_property("material", Vector3i(1, 1, 0), "trading_post", 0)

	var annual = gen_manager.estate_manager.get_annual_income()

	assert_gt(annual, 0)


## Test: Condition descriptions
func test_condition_descriptions() -> void:
	assert_eq(gen_manager.estate_manager.get_condition(95), "pristine")
	assert_eq(gen_manager.estate_manager.get_condition(75), "good")
	assert_eq(gen_manager.estate_manager.get_condition(50), "fair")
	assert_eq(gen_manager.estate_manager.get_condition(25), "poor")
	assert_eq(gen_manager.estate_manager.get_condition(10), "ruins")


## Test: Quest execution
func test_execute_quest() -> void:
	gen_manager.current_wealth = 100

	var result = gen_manager.execute_quest("slay_beast")

	assert_true(result.has("success"))
	if result["success"]:
		assert_gt(gen_manager.current_wealth, 100)


## Test: Get life summary
func test_get_life_summary() -> void:
	var heir = Heir.new()
	heir.generation = 5
	heir.name = "Vera"
	heir.traits = ["noble_blood", "mageblood"]
	heir.is_alive = true

	gen_manager.begin_generation(heir)
	gen_manager.current_age = 35
	gen_manager._trigger_marriage()
	gen_manager._trigger_birth()

	var summary = gen_manager.get_life_summary()

	assert_eq(summary["heir"], "Vera")
	assert_eq(summary["generation"], 5)
	assert_eq(summary["age"], 35)
	assert_eq(summary["children"], 1)


## Test: Ancestry summary
func test_ancestry_summary() -> void:
	gen_manager.npc_system.add_npc_ancestor(Heir.new(), 0)
	gen_manager.npc_system.add_npc_ancestor(Heir.new(), 5)

	var summary = gen_manager.npc_system.get_ancestry_summary(10)

	assert_eq(summary["total_ancestors"], 2)


var old_maintenance: int = 0
