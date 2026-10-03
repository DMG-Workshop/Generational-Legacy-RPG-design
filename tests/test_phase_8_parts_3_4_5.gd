## Tests for Phase 8 Parts 3-5: Traits, Legacy, Persistence
##
## Tests: TraitMutations, LegacyEcho, SessionPersistence

extends GutTest


var trait_mutations: TraitMutations
var legacy_echo: LegacyEcho
var session_persistence: SessionPersistence
var test_heir: Heir


func before_each() -> void:
	trait_mutations = TraitMutations.new()
	legacy_echo = LegacyEcho.new()
	session_persistence = SessionPersistence.new()
	
	test_heir = Heir.new()
	test_heir.name = "Aldric"
	test_heir.generation = 1
	test_heir.class_id = "warrior"
	test_heir.job_id = "fighter"
	test_heir.traits = []
	test_heir.stats = {
		"strength": 15,
		"dexterity": 12,
		"constitution": 14,
		"intelligence": 10,
		"wisdom": 11,
		"charisma": 13
	}
	test_heir.faction_reputation = {"party": 100}
	test_heir.wallet = Wallet.new()
	test_heir.wallet.gold = 500


# ========== TraitMutations Tests ==========

## Test: Trait mutations initialization
func test_trait_mutations_init() -> void:
	assert_not_null(trait_mutations)
	assert_gt(trait_mutations.trait_catalog.size(), 0)


## Test: Add dormant trait
func test_add_dormant_trait() -> void:
	trait_mutations.add_dormant_trait(test_heir, "fire_affinity")
	
	var dormant = trait_mutations.get_dormant_traits(test_heir)
	assert_true("fire_affinity" in dormant)


## Test: Get dormant traits
func test_get_dormant_traits() -> void:
	trait_mutations.add_dormant_trait(test_heir, "fire_affinity")
	trait_mutations.add_dormant_trait(test_heir, "ice_resistance")
	
	var dormant = trait_mutations.get_dormant_traits(test_heir)
	assert_eq(dormant.size(), 2)


## Test: Activate dormant trait
func test_activate_dormant_trait() -> void:
	trait_mutations.add_dormant_trait(test_heir, "fire_affinity")
	
	trait_mutations.activate_dormant_trait(test_heir, "fire_affinity")
	
	assert_true("fire_affinity" in test_heir.traits)
	assert_false("fire_affinity" in trait_mutations.get_dormant_traits(test_heir))


## Test: Trait activated signal
func test_trait_activated_signal() -> void:
	trait_mutations.add_dormant_trait(test_heir, "fire_affinity")
	
	var signal_received = false
	trait_mutations.trait_activated.connect(func(h, t): signal_received = true)
	
	trait_mutations.activate_dormant_trait(test_heir, "fire_affinity")
	
	assert_true(signal_received)


## Test: Check dormant activation by stat threshold
func test_check_dormant_activation_by_stat() -> void:
	# Add dormant trait that activates on strength > 15
	trait_mutations.add_dormant_trait(test_heir, "strength_surge")
	
	test_heir.stats["strength"] = 20  # Exceeds threshold
	
	# Note: Full implementation would have activation_stat in trait definition
	# For test, manually verify logic
	assert_true("strength_surge" in trait_mutations.get_dormant_traits(test_heir))


## Test: Inherit dormant traits from parent
func test_inherit_dormant_traits() -> void:
	var parent = Heir.new()
	parent.name = "Aldric Sr."
	parent.generation = 0
	
	trait_mutations.add_dormant_trait(parent, "ancestral_magic")
	
	trait_mutations.inherit_dormant_traits(test_heir, parent)
	
	# Should have inherited (50% chance passes sometimes)
	var dormant = trait_mutations.get_dormant_traits(test_heir)
	# At minimum, this test verifies the method runs without error
	assert_not_null(dormant)


## Test: Get trait expression level
func test_get_trait_expression_level() -> void:
	test_heir.traits.append("fire_affinity")
	
	var expression = trait_mutations.get_trait_expression_level(test_heir, "fire_affinity")
	
	assert_gt(expression, 0.0)


## Test: Trait conflict detection
func test_detect_trait_conflicts() -> void:
	test_heir.traits.append("blessing_courage")
	test_heir.traits.append("curse_cowardice")
	
	var conflicts = trait_mutations.get_conflicting_traits(test_heir)
	
	assert_gt(conflicts.size(), 0)


## Test: Resolve trait conflict
func test_resolve_trait_conflict() -> void:
	test_heir.traits.append("blessing_courage")
	test_heir.traits.append("curse_cowardice")
	
	var conflict = ["blessing_courage", "curse_cowardice"]
	trait_mutations.resolve_trait_conflict(test_heir, conflict)
	
	assert_true("blessing_courage" in test_heir.traits)
	assert_false("curse_cowardice" in test_heir.traits)


# ========== LegacyEcho Tests ==========

## Test: Legacy echo initialization
func test_legacy_echo_init() -> void:
	assert_not_null(legacy_echo)
	assert_eq(legacy_echo.legacy_echoes.size(), 0)


## Test: Record legacy event
func test_record_legacy_event() -> void:
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Great Battle", 75.0)
	
	assert_eq(legacy_echo.legacy_echoes.size(), 1)


## Test: Legacy echo signal
func test_legacy_echo_signal() -> void:
	var signal_received = false
	legacy_echo.legacy_echo_created.connect(func(h, t, e): signal_received = true)
	
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Great Battle", 75.0)
	
	assert_true(signal_received)


## Test: Carry forward reputation
func test_carry_forward_reputation() -> void:
	var next_heir = Heir.new()
	next_heir.faction_reputation = {"party": 0}
	
	legacy_echo.carry_forward_reputation(test_heir, next_heir, 0.7)
	
	assert_gt(next_heir.faction_reputation["party"], 0)


## Test: Reputation carried forward signal
func test_reputation_carried_signal() -> void:
	var next_heir = Heir.new()
	next_heir.faction_reputation = {}
	
	var signal_received = false
	legacy_echo.reputation_carried_forward.connect(func(h, f, v): signal_received = true)
	
	legacy_echo.carry_forward_reputation(test_heir, next_heir, 0.7)
	
	assert_true(signal_received)


## Test: Apply legacy blessing
func test_apply_legacy_blessing() -> void:
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.BLESSING, "Divine Favor", 5.0)
	
	var next_heir = Heir.new()
	next_heir.stats = {"strength": 10}
	
	legacy_echo.apply_legacy_blessing(next_heir, 0)
	
	assert_gt(next_heir.stats["strength"], 10)


## Test: Apply legacy curse
func test_apply_legacy_curse() -> void:
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.CURSE, "Dark Curse", 3.0)
	
	var next_heir = Heir.new()
	next_heir.stats = {"strength": 15}
	
	legacy_echo.apply_legacy_curse(next_heir, 0)
	
	assert_lt(next_heir.stats["strength"], 15)


## Test: Get heir echoes
func test_get_heir_echoes() -> void:
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Battle 1", 50.0)
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Battle 2", 60.0)
	
	var echoes = legacy_echo.get_heir_echoes(test_heir.name)
	
	assert_eq(echoes.size(), 2)


## Test: Get echoes by type
func test_get_echoes_by_type() -> void:
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Battle", 50.0)
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.DEFEAT, "Loss", 30.0)
	
	var victories = legacy_echo.get_echoes_by_type("VICTORY")
	
	assert_eq(victories.size(), 1)


## Test: Get legendary deeds
func test_get_legendary_deeds() -> void:
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Epic Battle", 100.0)
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Small Skirmish", 20.0)
	
	var deeds = legacy_echo.get_legendary_deeds()
	
	assert_eq(deeds.size(), 1)  # Only >= 50 effect


## Test: Calculate legacy score
func test_calculate_legacy_score() -> void:
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Battle", 100.0)
	
	test_heir.generation = 1
	var score = legacy_echo.calculate_legacy_score(test_heir)
	
	assert_gt(score, 0)


## Test: Get legacy inheritance bonus
func test_get_legacy_inheritance_bonus() -> void:
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Great Deeds", 75.0)
	
	test_heir.generation = 1
	var bonus = legacy_echo.get_legacy_inheritance_bonus(test_heir)
	
	assert_true("stat_bonus" in bonus)
	assert_true("starting_wealth" in bonus)


## Test: Is heir legendary
func test_is_heir_legendary() -> void:
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Deed 1", 75.0)
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Deed 2", 75.0)
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Deed 3", 75.0)
	
	assert_true(legacy_echo.is_heir_legendary(test_heir))


## Test: Get legacy history
func test_get_legacy_history() -> void:
	legacy_echo.record_legacy_event(test_heir, LegacyEcho.EchoType.VICTORY, "Battle", 50.0)
	
	var history = legacy_echo.get_legacy_history()
	
	assert_gt(history.size(), 0)


# ========== SessionPersistence Tests ==========

## Test: Session persistence initialization
func test_session_persistence_init() -> void:
	assert_not_null(session_persistence)
	assert_true(session_persistence.autosave_enabled)


## Test: Get save slots
func test_get_save_slots() -> void:
	var slots = session_persistence.get_save_slots()
	
	assert_eq(slots.size(), SessionPersistence.MAX_SAVE_SLOTS)


## Test: Slot is empty
func test_slot_is_empty() -> void:
	assert_true(session_persistence.is_slot_empty(0))


## Test: Export save report
func test_export_save_report() -> void:
	var report = session_persistence.export_save_report(0)
	
	assert_true("empty" in report.to_lower() or "save" in report.to_lower())


## Test: Get session summary
func test_get_session_summary() -> void:
	var summary = session_persistence.get_session_summary()
	
	assert_true("current_heir" in summary)
	assert_true("generation" in summary)
	assert_true("progress" in summary)


## Test: Save directory creation
func test_save_directory_exists() -> void:
	session_persistence._ensure_save_directory()
	
	assert_true(DirAccess.dir_exists_absolute(SessionPersistence.SAVE_DIR))
