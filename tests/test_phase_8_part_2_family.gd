## Tests for Phase 8 Part 2: Family & Marriage System
##
## Tests: SpouseSystem, FamilyExpansion

extends GutTest


var spouse_system: SpouseSystem
var family_expansion: FamilyExpansion
var lineage: Lineage
var test_heir: Heir


func before_each() -> void:
	spouse_system = SpouseSystem.new()
	family_expansion = FamilyExpansion.new()
	lineage = Lineage.new(42)
	
	test_heir = Heir.new()
	test_heir.name = "Aldric"
	test_heir.class_id = "warrior"
	test_heir.job_id = "fighter"
	test_heir.faction_reputation = {"party": 100}
	test_heir.stats = {
		"strength": 15,
		"dexterity": 12,
		"constitution": 14,
		"intelligence": 10,
		"wisdom": 11,
		"charisma": 13
	}


# ========== SpouseSystem Tests ==========

## Test: Spouse system initialization
func test_spouse_system_init() -> void:
	assert_not_null(spouse_system)
	assert_gt(spouse_system.spouse_pool.size(), 0)


## Test: Get available spouse options
func test_get_spouse_options() -> void:
	var options = spouse_system.get_spouse_options(test_heir, 3)
	
	assert_gt(options.size(), 0)
	assert_true("spouse" in options[0])
	assert_true("compatibility" in options[0])


## Test: Compatibility calculation
func test_calculate_compatibility() -> void:
	var spouse = spouse_system.spouse_pool[0]
	var compat = spouse_system.calculate_compatibility(test_heir, spouse)
	
	assert_gt(compat, 0.0)
	assert_lt(compat, 1.1)  # 1.0 max + floating point tolerance


## Test: Compatibility bonus for matching class
func test_compatibility_class_match() -> void:
	var spouse = Heir.new()
	spouse.class_id = test_heir.class_id  # Same class
	spouse.job_id = "ranger"  # Different job
	spouse.faction_reputation = {"party": 100}
	spouse.traits = []
	
	var compat = spouse_system.calculate_compatibility(test_heir, spouse)
	
	# Should be higher than base 0.5 due to class match
	assert_gt(compat, 0.55)


## Test: Propose marriage success
func test_propose_marriage_success() -> void:
	var spouse = Heir.new()
	spouse.class_id = test_heir.class_id  # Boost compatibility
	spouse.job_id = test_heir.job_id
	spouse.faction_reputation = {"party": 100}
	spouse.traits = []
	spouse.spouse = null
	
	var success = spouse_system.propose_marriage(test_heir, spouse)
	
	assert_true(success)
	assert_eq(test_heir.spouse, spouse)
	assert_eq(spouse.spouse, test_heir)


## Test: Marriage signal emission
func test_marriage_signal() -> void:
	var spouse = Heir.new()
	spouse.class_id = test_heir.class_id
	spouse.job_id = test_heir.job_id
	spouse.faction_reputation = {"party": 100}
	spouse.traits = []
	spouse.spouse = null
	
	var signal_received = false
	spouse_system.marriage_occurred.connect(func(h, s): signal_received = true)
	
	spouse_system.propose_marriage(test_heir, spouse)
	
	assert_true(signal_received)


## Test: Cannot marry if already married
func test_cannot_marry_already_married() -> void:
	var spouse1 = Heir.new()
	spouse1.class_id = "warrior"
	spouse1.job_id = "fighter"
	spouse1.faction_reputation = {"party": 100}
	spouse1.traits = []
	spouse1.spouse = null
	
	spouse_system.propose_marriage(test_heir, spouse1)
	assert_not_null(test_heir.spouse)
	
	var spouse2 = Heir.new()
	spouse2.class_id = "warrior"
	spouse2.faction_reputation = {"party": 100}
	spouse2.traits = []
	
	var success = spouse_system.propose_marriage(test_heir, spouse2)
	assert_false(success)


## Test: Marriage bonus to charisma
func test_marriage_charisma_bonus() -> void:
	var initial_charisma = test_heir.stats["charisma"]
	
	var spouse = Heir.new()
	spouse.class_id = test_heir.class_id
	spouse.job_id = test_heir.job_id
	spouse.faction_reputation = {"party": 100}
	spouse.traits = []
	spouse.spouse = null
	spouse.stats = {"charisma": 12}
	
	spouse_system.propose_marriage(test_heir, spouse)
	
	assert_gt(test_heir.stats["charisma"], initial_charisma)


## Test: Apply spouse rewards
func test_apply_spouse_rewards() -> void:
	var spouse = Heir.new()
	spouse.class_id = "warrior"
	spouse.faction_reputation = {"party": 100}
	spouse.traits = []
	spouse.spouse = test_heir
	spouse.crafting_skills = {}
	test_heir.spouse = spouse
	
	var rewards = {
		"victory": true,
		"crafting_xp": {"Blacksmithing": 100}
	}
	
	spouse_system.apply_spouse_rewards(test_heir, rewards)
	
	assert_true("Blacksmithing" in spouse.crafting_skills)
	# Spouse gets 60% of heir's XP
	assert_eq(spouse.crafting_skills["Blacksmithing"].xp, 60)


## Test: Spouse skill progression
func test_spouse_skill_progression() -> void:
	var spouse = Heir.new()
	spouse.class_id = "warrior"
	spouse.faction_reputation = {"party": 100}
	spouse.traits = []
	spouse.crafting_skills = {}
	
	var crafting_xp = {"Alchemy": 80}
	spouse_system._apply_spouse_skill_progression(spouse, crafting_xp)
	
	assert_true("Alchemy" in spouse.crafting_skills)
	assert_eq(spouse.crafting_skills["Alchemy"].xp, 80)


## Test: Divorce
func test_divorce() -> void:
	var spouse = Heir.new()
	spouse.spouse = null
	test_heir.spouse = spouse
	spouse.spouse = test_heir
	
	var success = spouse_system.initiate_divorce(test_heir)
	
	assert_true(success)
	assert_null(test_heir.spouse)
	assert_null(spouse.spouse)


## Test: Divorce reputation penalty
func test_divorce_reputation_penalty() -> void:
	var spouse = Heir.new()
	test_heir.spouse = spouse
	spouse.spouse = test_heir
	test_heir.faction_reputation["party"] = 100
	
	spouse_system.initiate_divorce(test_heir)
	
	assert_eq(test_heir.faction_reputation["party"], 50)  # -50


## Test: Get spouse summary
func test_get_spouse_summary() -> void:
	var spouse = Heir.new()
	spouse.name = "Elena"
	spouse.class_id = "mage"
	spouse.job_id = "wizard"
	spouse.stats = {"intelligence": 16}
	spouse.crafting_skills = {"Alchemy": Heir.new()}
	spouse.traits = ["fire_affinity"]
	test_heir.spouse = spouse
	
	var summary = spouse_system.get_spouse_summary(test_heir)
	
	assert_eq(summary["name"], "Elena")
	assert_eq(summary["class"], "mage")
	assert_true("Alchemy" in summary["skills"])


# ========== FamilyExpansion Tests ==========

## Test: Family expansion initialization
func test_family_expansion_init() -> void:
	assert_not_null(family_expansion)
	assert_eq(family_expansion.family_reputation.size(), 0)


## Test: Add child
func test_add_child() -> void:
	var child = Heir.new()
	child.name = "Arwyn"
	
	family_expansion.add_child(test_heir, child)
	
	var children = family_expansion.get_children(test_heir)
	assert_eq(children.size(), 1)
	assert_eq(children[0], child)


## Test: Child born signal
func test_child_born_signal() -> void:
	var child = Heir.new()
	var signal_received = false
	
	family_expansion.child_born.connect(func(p, c): signal_received = true)
	family_expansion.add_child(test_heir, child)
	
	assert_true(signal_received)


## Test: Multiple children
func test_multiple_children() -> void:
	for i in range(3):
		var child = Heir.new()
		child.name = "Child %d" % i
		family_expansion.add_child(test_heir, child)
	
	var children = family_expansion.get_children(test_heir)
	assert_eq(children.size(), 3)


## Test: Choose heir bonus
func test_choose_heir_stat_bonus() -> void:
	var child1 = Heir.new()
	child1.stats = {"strength": 10}
	
	var child2 = Heir.new()
	child2.stats = {"strength": 10}
	
	family_expansion.add_child(test_heir, child1)
	family_expansion.add_child(test_heir, child2)
	
	var children = family_expansion.get_children(test_heir)
	family_expansion.choose_heir(test_heir, child1)
	
	# Chosen gets +15%, others get -10%
	assert_gt(child1.stats["strength"], 10)
	assert_lt(child2.stats["strength"], 10)


## Test: Heir chosen signal
func test_heir_chosen_signal() -> void:
	var child = Heir.new()
	family_expansion.add_child(test_heir, child)
	
	var signal_received = false
	family_expansion.heir_chosen.connect(func(c, s): signal_received = true)
	
	family_expansion.choose_heir(test_heir, child)
	
	assert_true(signal_received)


## Test: Family reputation bonus
func test_family_reputation_bonus() -> void:
	family_expansion.increase_family_reputation(test_heir, 200)
	
	var bonus = family_expansion.get_family_reputation_bonus(test_heir)
	
	# 200 rep = +2% stat bonus (200 / 100 * 0.01)
	assert_gt(bonus, 0.01)
	assert_lt(bonus, 0.03)


## Test: Apply family reputation to heir
func test_apply_family_reputation_to_heir() -> void:
	var initial_strength = test_heir.stats["strength"]
	
	family_expansion.increase_family_reputation(test_heir, 150)
	family_expansion.apply_family_reputation_to_heir(test_heir)
	
	assert_gt(test_heir.stats["strength"], initial_strength)


## Test: Increase family reputation signal
func test_family_reputation_signal() -> void:
	var signal_received = false
	family_expansion.family_reputation_changed.connect(func(f, r): signal_received = true)
	
	family_expansion.increase_family_reputation(test_heir, 50)
	
	assert_true(signal_received)


## Test: Decrease family reputation
func test_decrease_family_reputation() -> void:
	family_expansion.increase_family_reputation(test_heir, 100)
	var initial = family_expansion.get_family_reputation(test_heir)
	
	family_expansion.decrease_family_reputation(test_heir, 50)
	var after = family_expansion.get_family_reputation(test_heir)
	
	assert_eq(after, initial - 50)


## Test: Get family reputation
func test_get_family_reputation() -> void:
	family_expansion.increase_family_reputation(test_heir, 175)
	
	var reputation = family_expansion.get_family_reputation(test_heir)
	
	assert_eq(reputation, 175)


## Test: Produce children from parents
func test_produce_children() -> void:
	var spouse = Heir.new()
	spouse.name = "Elena"
	test_heir.spouse = spouse
	
	var children = family_expansion.produce_children(lineage, test_heir, spouse, 2)
	
	assert_eq(children.size(), 2)
	assert_eq(family_expansion.get_child_count(test_heir), 2)


## Test: Calculate inheritance split
func test_calculate_inheritance_split() -> void:
	var child1 = Heir.new()
	var child2 = Heir.new()
	
	family_expansion.add_child(test_heir, child1)
	family_expansion.add_child(test_heir, child2)
	
	family_expansion.choose_heir(test_heir, child1)
	
	var split = family_expansion.calculate_inheritance_split(test_heir, 1000)
	
	# Chosen gets 50%, others split 50%
	assert_eq(split[child1.to_string()], 500)
	assert_eq(split[child2.to_string()], 500)


## Test: Get family summary
func test_get_family_summary() -> void:
	var spouse = Heir.new()
	spouse.name = "Elena"
	test_heir.spouse = spouse
	
	var child = Heir.new()
	family_expansion.add_child(test_heir, child)
	
	var summary = family_expansion.get_family_summary(test_heir)
	
	assert_eq(summary["patriarch"], "Aldric")
	assert_eq(summary["spouse"], "Elena")
	assert_eq(summary["child_count"], 1)


## Test: Has children
func test_has_children() -> void:
	assert_false(family_expansion.has_children(test_heir))
	
	var child = Heir.new()
	family_expansion.add_child(test_heir, child)
	
	assert_true(family_expansion.has_children(test_heir))


## Test: Sibling conflict signal
func test_sibling_conflict_signal() -> void:
	var child1 = Heir.new()
	var child2 = Heir.new()
	
	family_expansion.add_child(test_heir, child1)
	family_expansion.add_child(test_heir, child2)
	
	var signal_received = false
	family_expansion.sibling_conflict.connect(func(w, l): signal_received = true)
	
	family_expansion.choose_heir(test_heir, child1)
	
	assert_true(signal_received)


## Test: Resolve sibling conflict
func test_resolve_sibling_conflict() -> void:
	var child1 = Heir.new()
	child1.name = "Arwyn"
	
	var child2 = Heir.new()
	child2.name = "Elowen"
	
	family_expansion.resolve_sibling_conflict(child1, child2)
	
	assert_gt(family_expansion.get_family_reputation(child1), 0)
	assert_lt(family_expansion.get_family_reputation(child2), 0)


## Test: Family name extraction
func test_family_name_extraction() -> void:
	test_heir.name = "Aldric Stormborn"
	var rep1 = family_expansion.get_family_reputation(test_heir)
	
	var another_heir = Heir.new()
	another_heir.name = "Aldric Second"
	family_expansion.increase_family_reputation(another_heir, 50)
	
	# Both share "Aldric" as family name
	var rep2 = family_expansion.get_family_reputation(test_heir)
	
	assert_eq(rep2, 50)
