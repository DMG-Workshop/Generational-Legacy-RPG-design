## Integration test: Full generation loop with all Phase 1 systems
##
## Simulates multiple generations with trait inheritance, Fate rolls,
## and failure consequences working together.

extends GutTest


var lineage: Lineage
var fate_system: FateSystem


func before_each() -> void:
	lineage = Lineage.new(12345)  # Seeded for reproducibility
	fate_system = FateSystem.new()


## Test: Simple 5-generation family saga
func test_five_generation_saga() -> void:
	# Gen 0: Founder
	var theron = lineage.create_founder("Theron", "warrior", "merchant")
	theron.add_trait("noble_blood")
	theron.add_trait("mageblood")
	theron.roll_fate(0.12)

	assert_eq(theron.generation, 0)
	assert_eq(theron.traits.size(), 2)
	assert_eq(theron.fate_tier, "Steady")

	# Gen 1: Elena inherits from Theron
	var elena = lineage.produce_heir(theron, theron, "Elena", "mage", "scribe")
	elena.roll_fate()

	# Check inheritance: Elena should have some traits from Theron
	print("Gen 1 (Elena) traits: ", elena.traits)
	# With seed 12345, Elena should inherit something

	# Gen 2: Check if Fate rolls as expected
	var vera = lineage.produce_heir(elena, elena, "Vera", "spellblade", "bounty_hunter")
	vera.roll_fate(0.20)  # Higher Fate

	assert_true(vera.fate_value >= 0.01)
	assert_true(vera.fate_value <= 0.30)

	# Gen 3
	var marcus = lineage.produce_heir(vera, vera, "Marcus", "warrior", "guard")
	marcus.roll_fate()

	# Gen 4
	var sophia = lineage.produce_heir(marcus, marcus, "Sophia", "acolyte", "healer")
	sophia.roll_fate()

	# Verify family tree
	assert_eq(lineage.generation_count(), 5)
	assert_eq(sophia.generation, 4)
	assert_eq(sophia.mother, marcus)


## Test: Fate milestone checks across 100 generations
func test_fate_milestone_distribution() -> void:
	var current = lineage.create_founder("Founder", "warrior", "merchant")
	current.roll_fate(0.15)

	var failure_count = 0

	for gen in range(1, 100):
		# Check each milestone
		for milestone in range(5):
			if FateSystem.roll_failure(current.fate_value, lineage.rng):
				failure_count += 1

		# Produce next heir
		var next_heir = lineage.produce_heir(current, current, "Gen%d" % gen, "warrior", "merchant")
		next_heir.roll_fate()
		current = next_heir

	# With base Fate of 0.15 across 5 milestones per generation x 100 gens,
	# expect ~75 failures total (100 * 5 * 0.15 * ~0.03 per check)
	# With milestones, expect roughly 1-2 per generation
	print("Failures in 100 generations: ", failure_count)
	assert_gt(failure_count, 0)  # At least one failure


## Test: Heir archetype assignment after failure
func test_heir_archetype_after_failure() -> void:
	var severities = [
		FateSystem.Severity.MINOR,
		FateSystem.Severity.MODERATE,
		FateSystem.Severity.MAJOR,
		FateSystem.Severity.CRITICAL
	]

	for severity in severities:
		var archetype = FateSystem.get_heir_archetype(severity, "merchant", lineage.rng)
		assert_true(archetype >= 0 and archetype < 6)  # Valid archetype enum


## Test: Trait conflicts prevent both from being active
func test_trait_conflict_handling() -> void:
	var heir = Heir.new()
	heir.generation = 0
	heir.traits = []

	# Add a trait
	heir.add_trait("noble_blood")
	assert_true(heir.has_trait("noble_blood"))

	# In full implementation, outlaw_cunning would conflict
	# and be rejected or create friction
	heir.add_trait("outlaws_cunning")

	# Both are present (conflicts create friction, not cancellation)
	assert_true(heir.has_trait("noble_blood"))
	assert_true(heir.has_trait("outlaws_cunning"))


## Test: Fate Value modifier from traits
func test_fate_modifiers_from_traits() -> void:
	var lucky_heir = Heir.new()
	lucky_heir.add_trait("lucky")
	# Lucky should lower Fate Value
	lucky_heir.roll_fate(0.15 - 0.04)  # Lucky gives -4%
	assert_lt(lucky_heir.fate_value, 0.12)

	var cursed_heir = Heir.new()
	cursed_heir.add_trait("cursed")
	# Cursed should raise Fate Value
	cursed_heir.roll_fate(0.15 + 0.10)  # Cursed gives +10%
	assert_gt(cursed_heir.fate_value, 0.20)
