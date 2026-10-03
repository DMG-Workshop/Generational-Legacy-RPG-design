## Unit tests for the Lineage system
##
## Tests trait inheritance, mutations, and 999-generation simulation

extends GutTest


var lineage: Lineage


func before_each() -> void:
	lineage = Lineage.new(42)  # Seeded RNG for reproducibility


## Test: Create a founder
func test_create_founder() -> void:
	var founder = lineage.create_founder("Theron", "warrior", "merchant")

	assert_eq(founder.name, "Theron")
	assert_eq(founder.generation, 0)
	assert_eq(founder.class_id, "warrior")
	assert_eq(founder.job_id, "merchant")
	assert_eq(lineage.generation_count(), 1)


## Test: Produce an heir from two parents
func test_produce_heir() -> void:
	var mother = lineage.create_founder("Elena", "mage", "scribe")
	var father = Heir.new()
	father.name = "Marcus"
	father.generation = 0
	father.class_id = "warrior"
	father.job_id = "guard"
	father.traits = []

	var heir = lineage.produce_heir(mother, father, "Vera", "spellblade", "bounty_hunter")

	assert_eq(heir.name, "Vera")
	assert_eq(heir.generation, 1)
	assert_eq(heir.mother, mother)
	assert_eq(heir.father, father)


## Test: Heir inherits Fate Value
func test_fate_roll() -> void:
	var heir = Heir.new()
	heir.roll_fate()

	assert_true(heir.fate_value >= 0.01)
	assert_true(heir.fate_value <= 0.30)
	assert_true(heir.fate_tier in ["Charmed", "Steady", "Uncertain", "Ill-Starred"])


## Test: Simulate 999 generations
func test_simulate_999_generations() -> void:
	var current_heir = lineage.create_founder("Theron", "warrior", "merchant")
	current_heir.traits = ["mageblood", "noble_blood"]

	for gen in range(1, 999):
		var next_heir = lineage.produce_heir(current_heir, current_heir,
			"Gen%d" % gen, "warrior", "merchant")
		next_heir.roll_fate()
		current_heir = next_heir

	assert_eq(lineage.generation_count(), 999)
	assert_eq(current_heir.generation, 998)


## Test: Trait inheritance with probability
func test_trait_inheritance() -> void:
	var mother = Heir.new()
	mother.generation = 0
	mother.traits = ["mageblood"]

	var father = Heir.new()
	father.generation = 0
	father.traits = ["mageblood"]

	# With both parents having the trait, inheritance should be frequent
	var inherited_count = 0
	for i in range(10):
		var child = lineage.produce_heir(mother, father, "Child%d" % i, "mage", "scribe")
		if "mageblood" in child.traits or "mageblood_mutated" in child.traits:
			inherited_count += 1

	# At least 5 out of 10 should inherit with 60%+ chance per parent
	assert_gt(inherited_count, 3)


## Test: Fate tier perception
func test_fate_tier_perception() -> void:
	var charmed = Heir.new()
	charmed.roll_fate(0.03)
	assert_eq(charmed.fate_tier, "Charmed")

	var steady = Heir.new()
	steady.roll_fate(0.09)
	assert_eq(steady.fate_tier, "Steady")

	var uncertain = Heir.new()
	uncertain.roll_fate(0.15)
	assert_eq(uncertain.fate_tier, "Uncertain")

	var illstarred = Heir.new()
	illstarred.roll_fate(0.25)
	assert_eq(illstarred.fate_tier, "Ill-Starred")
