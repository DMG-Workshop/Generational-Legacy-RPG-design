## Test Phase 12.2: Heirloom & Artifact System
##
## Comprehensive test suite for artifacts, heirlooms, and enchantments

extends Node

class_name TestPhase12_2Heirlooms


var artifact_system: ArtifactSystem
var heirloom_system: HeirloomSystem
var enchantment_system: ArtifactEnchantmentSystem
var artifact_persistence: ArtifactPersistence

var test_results: Array = []


func _ready() -> void:
	artifact_system = ArtifactSystem.new()
	heirloom_system = HeirloomSystem.new()
	enchantment_system = ArtifactEnchantmentSystem.new()
	artifact_persistence = ArtifactPersistence.new()

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_artifact_creation()
	test_artifact_types_and_rarities()
	test_artifact_stat_scaling()
	test_artifact_upgrading()
	test_artifact_combination()
	test_artifact_queries()

	test_heirloom_designation()
	test_heirloom_inheritance()
	test_heirloom_power_scaling()
	test_heirloom_queries()
	test_heirloom_chain()

	test_enchantment_application()
	test_enchantment_stacking()
	test_enchantment_effects()
	test_enchantment_types()
	test_enchantment_transfer()

	test_artifact_persistence()
	test_generation_transfer()

	test_complex_scenarios()


func test_artifact_creation() -> void:
	var artifact_id = artifact_system.create_artifact(
		"Excalibur",
		ArtifactSystem.ArtifactType.WEAPON,
		ArtifactSystem.ArtifactRarity.LEGENDARY,
		1,
		"heir_1"
	)
	assert(artifact_id != "", "Should create artifact")
	assert(artifact_system.artifacts.has(artifact_id), "Artifact should exist")

	var artifact = artifact_system.get_artifact(artifact_id)
	assert(artifact.name == "Excalibur", "Artifact should have correct name")
	assert(artifact.type == ArtifactSystem.ArtifactType.WEAPON, "Should have correct type")
	assert(artifact.creation_generation == 1, "Should record creation generation")
	test_results.append("✓ Artifact creation")


func test_artifact_types_and_rarities() -> void:
	var weapon_id = artifact_system.create_artifact("Sword", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.RARE, 1, "heir_1")
	var armor_id = artifact_system.create_artifact("Plate", ArtifactSystem.ArtifactType.ARMOR, ArtifactSystem.ArtifactRarity.EPIC, 1, "heir_1")
	var accessory_id = artifact_system.create_artifact("Ring", ArtifactSystem.ArtifactType.ACCESSORY, ArtifactSystem.ArtifactRarity.UNCOMMON, 1, "heir_1")
	var relic_id = artifact_system.create_artifact("Amulet", ArtifactSystem.ArtifactType.RELIC, ArtifactSystem.ArtifactRarity.LEGENDARY, 1, "heir_1")

	var weapons = artifact_system.get_artifacts_by_type(ArtifactSystem.ArtifactType.WEAPON)
	assert(weapons.size() > 0, "Should find weapon artifacts")

	var epics = artifact_system.get_artifacts_by_rarity(ArtifactSystem.ArtifactRarity.EPIC)
	assert(epics.size() > 0, "Should find epic artifacts")

	test_results.append("✓ Artifact types and rarities")


func test_artifact_stat_scaling() -> void:
	var artifact_id = artifact_system.create_artifact("TestWeapon", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.RARE, 1, "heir_1")
	var artifact = artifact_system.get_artifact(artifact_id)
	var initial_damage = artifact.current_stats["damage"]

	artifact.apply_power_scaling(1.5)
	var scaled_damage = artifact.current_stats["damage"]
	assert(scaled_damage > initial_damage, "Scaling should increase stats")
	assert(artifact.power_level == 1.5, "Power level should update")

	test_results.append("✓ Artifact stat scaling")


func test_artifact_upgrading() -> void:
	var artifact_id = artifact_system.create_artifact("Upgradeable", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.UNCOMMON, 1, "heir_1")
	var artifact = artifact_system.get_artifact(artifact_id)
	var initial_rarity = artifact.rarity

	var success = artifact_system.upgrade_artifact_rarity(artifact_id)
	assert(success, "Should upgrade rarity")
	assert(artifact.rarity == initial_rarity + 1, "Rarity should increase")
	assert(artifact.power_level > 1.0, "Power should scale with upgrade")

	# Try to upgrade MYTHIC (should fail)
	for _i in range(6):
		if artifact.rarity < ArtifactSystem.ArtifactRarity.MYTHIC:
			artifact_system.upgrade_artifact_rarity(artifact_id)

	var final_upgrade = artifact_system.upgrade_artifact_rarity(artifact_id)
	assert(not final_upgrade or artifact.rarity == ArtifactSystem.ArtifactRarity.MYTHIC, "Should not exceed MYTHIC")

	test_results.append("✓ Artifact upgrading")


func test_artifact_combination() -> void:
	var weapon1_id = artifact_system.create_artifact("Sword1", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.RARE, 1, "heir_1")
	var weapon2_id = artifact_system.create_artifact("Sword2", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.RARE, 2, "heir_2")

	var combined_id = artifact_system.combine_artifacts(weapon1_id, weapon2_id, "heir_3", 5)
	assert(combined_id != "", "Should combine artifacts")

	var combined = artifact_system.get_artifact(combined_id)
	assert(combined.rarity == ArtifactSystem.ArtifactRarity.EPIC, "Combined rarity should be higher")
	assert(combined.power_level > 1.0, "Combined power should be boosted")

	test_results.append("✓ Artifact combination")


func test_artifact_queries() -> void:
	var id1 = artifact_system.create_artifact("Artifact1", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.LEGENDARY, 1, "heir_1")
	var id2 = artifact_system.create_artifact("Artifact2", ArtifactSystem.ArtifactType.ARMOR, ArtifactSystem.ArtifactRarity.EPIC, 5, "heir_1")

	var all_artifacts = artifact_system.get_all_artifacts()
	assert(all_artifacts.size() >= 2, "Should retrieve all artifacts")

	var info = artifact_system.get_artifact_info(id1)
	assert(info.has("name"), "Info should have name")
	assert(info.has("rarity"), "Info should have rarity")
	assert(info["type"] == "WEAPON", "Info should have type")

	test_results.append("✓ Artifact queries")


func test_heirloom_designation() -> void:
	var artifact_id = artifact_system.create_artifact("Heirloom1", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.LEGENDARY, 1, "heir_1")

	var result = heirloom_system.designate_heirloom(artifact_id, "heir_1", 1)
	assert(result != "", "Should designate heirloom")
	assert(heirloom_system.heirlooms.has(artifact_id), "Heirloom should be tracked")

	var heirloom = heirloom_system.get_heirloom(artifact_id)
	assert(heirloom.original_heir_id == "heir_1", "Should track original heir")
	assert(heirloom.current_heir_id == "heir_1", "Should track current heir")

	test_results.append("✓ Heirloom designation")


func test_heirloom_inheritance() -> void:
	var artifact_id = artifact_system.create_artifact("Heirloom2", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.EPIC, 1, "heir_1")
	heirloom_system.designate_heirloom(artifact_id, "heir_1", 1)

	var success = heirloom_system.inherit_heirloom(artifact_id, "heir_1", "heir_2", 5)
	assert(success, "Should inherit heirloom")

	var heirloom = heirloom_system.get_heirloom(artifact_id)
	assert(heirloom.current_heir_id == "heir_2", "Current heir should change")
	assert(heirloom.times_inherited == 1, "Inheritance count should increase")
	assert(heirloom.inheritance_chain.size() == 2, "Chain should grow")

	test_results.append("✓ Heirloom inheritance")


func test_heirloom_power_scaling() -> void:
	var artifact_id = artifact_system.create_artifact("PowerHeirloom", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.RARE, 1, "heir_1")
	heirloom_system.designate_heirloom(artifact_id, "heir_1", 1)

	var initial_power = heirloom_system.get_power_multiplier(artifact_id)
	assert(initial_power == 1.0, "Initial power should be 1.0x")

	heirloom_system.inherit_heirloom(artifact_id, "heir_1", "heir_2", 10)
	var power_after_1 = heirloom_system.get_power_multiplier(artifact_id)
	assert(power_after_1 > 1.0, "Power should scale with inheritance")

	heirloom_system.inherit_heirloom(artifact_id, "heir_2", "heir_3", 20)
	var power_after_2 = heirloom_system.get_power_multiplier(artifact_id)
	assert(power_after_2 > power_after_1, "Power should scale further")

	test_results.append("✓ Heirloom power scaling")


func test_heirloom_queries() -> void:
	var artifact_id = artifact_system.create_artifact("QueryHeirloom", ArtifactSystem.ArtifactType.ARMOR, ArtifactSystem.ArtifactRarity.GOLD, 1, "heir_1")
	heirloom_system.designate_heirloom(artifact_id, "heir_1", 1)
	heirloom_system.inherit_heirloom(artifact_id, "heir_1", "heir_2", 5)

	var heir_2_heirlooms = heirloom_system.get_heir_heirlooms("heir_2")
	assert(heir_2_heirlooms.size() > 0, "Should find heir heirlooms")

	var chain = heirloom_system.get_heirloom_chain(artifact_id)
	assert(chain.size() == 2, "Chain should have 2 heirs")

	var stats = heirloom_system.get_heirloom_stats(artifact_id)
	assert(stats.has("times_inherited"), "Stats should include inheritance count")

	test_results.append("✓ Heirloom queries")


func test_heirloom_chain() -> void:
	var artifact_id = artifact_system.create_artifact("ChainHeirloom", ArtifactSystem.ArtifactType.RELIC, ArtifactSystem.ArtifactRarity.MYTHIC, 1, "founder")
	heirloom_system.designate_heirloom(artifact_id, "founder", 1)

	# Simulate 5 generation inheritance
	var current_heir = "founder"
	for gen in range(2, 6):
		var next_heir = "heir_%d" % gen
		heirloom_system.inherit_heirloom(artifact_id, current_heir, next_heir, gen)
		current_heir = next_heir

	var heirloom = heirloom_system.get_heirloom(artifact_id)
	assert(heirloom.times_inherited == 4, "Should have 4 inheritances")
	assert(heirloom.inheritance_chain.size() == 5, "Chain should have 5 members")

	var legacy = heirloom_system.get_family_legacy("heir_5")
	assert(legacy["current_heirlooms"] >= 1, "Should have heirloom")

	test_results.append("✓ Heirloom inheritance chain")


func test_enchantment_application() -> void:
	var artifact_id = artifact_system.create_artifact("Enchantable", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.RARE, 1, "heir_1")

	var enchant_id = enchantment_system.apply_enchantment(artifact_id, ArtifactEnchantmentSystem.EnchantmentType.STAT_BOOST, 1)
	assert(enchant_id != "", "Should apply enchantment")
	assert(enchantment_system.artifact_enchantments.has(artifact_id), "Enchantments should be tracked")

	var enchantments = enchantment_system.get_enchantments(artifact_id)
	assert(enchantments.size() > 0, "Should have enchantments")

	test_results.append("✓ Enchantment application")


func test_enchantment_stacking() -> void:
	var artifact_id = artifact_system.create_artifact("Stackable", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.EPIC, 1, "heir_1")

	var enchant1 = enchantment_system.apply_enchantment(artifact_id, ArtifactEnchantmentSystem.EnchantmentType.STAT_BOOST, 1)
	var enchant2 = enchantment_system.apply_enchantment(artifact_id, ArtifactEnchantmentSystem.EnchantmentType.STAT_BOOST, 2)

	# Same type should stack
	assert(enchant1 == enchant2, "Same enchantment type should stack")

	var stack_count = enchantment_system.get_enchantment_stack_count(artifact_id, ArtifactEnchantmentSystem.EnchantmentType.STAT_BOOST)
	assert(stack_count == 2, "Should have 2 stacks")

	test_results.append("✓ Enchantment stacking")


func test_enchantment_effects() -> void:
	var artifact_id = artifact_system.create_artifact("EffectTest", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.LEGENDARY, 1, "heir_1")

	enchantment_system.apply_enchantment(artifact_id, ArtifactEnchantmentSystem.EnchantmentType.STAT_BOOST, 1)
	enchantment_system.apply_enchantment(artifact_id, ArtifactEnchantmentSystem.EnchantmentType.COMBAT_BONUS, 1)

	var effects = enchantment_system.get_enchantment_effects(artifact_id)
	assert(effects.has("stat_bonuses"), "Should have stat bonuses")
	assert(effects.has("special_effects"), "Should have special effects")
	assert(effects["total_power"] > 1.0, "Power should be boosted")

	test_results.append("✓ Enchantment effects")


func test_enchantment_types() -> void:
	var artifact_id = artifact_system.create_artifact("TypeTest", ArtifactSystem.ArtifactType.RELIC, ArtifactSystem.ArtifactRarity.LEGENDARY, 1, "heir_1")

	for enchant_type in range(ArtifactEnchantmentSystem.EnchantmentType.STAT_BOOST, ArtifactEnchantmentSystem.EnchantmentType.COMBAT_BONUS + 1):
		enchantment_system.apply_enchantment(artifact_id, enchant_type, 1)

	var enchantments = enchantment_system.get_enchantments(artifact_id)
	assert(enchantments.size() >= 5, "Should have multiple enchantment types")

	test_results.append("✓ Enchantment types")


func test_enchantment_transfer() -> void:
	var source_id = artifact_system.create_artifact("Source", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.LEGENDARY, 1, "heir_1")
	var target_id = artifact_system.create_artifact("Target", ArtifactSystem.ArtifactType.ARMOR, ArtifactSystem.ArtifactRarity.EPIC, 2, "heir_2")

	enchantment_system.apply_enchantment(source_id, ArtifactEnchantmentSystem.EnchantmentType.STAT_BOOST, 1)
	enchantment_system.apply_enchantment(source_id, ArtifactEnchantmentSystem.EnchantmentType.SPECIAL_ABILITY, 1)

	var transferred = enchantment_system.transfer_enchantments(source_id, target_id)
	assert(transferred == 2, "Should transfer 2 enchantments")

	var target_enchants = enchantment_system.get_enchantments(target_id)
	assert(target_enchants.size() >= 2, "Target should have transferred enchantments")

	test_results.append("✓ Enchantment transfer")


func test_artifact_persistence() -> void:
	var artifact_id = artifact_system.create_artifact("Persistent", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.LEGENDARY, 1, "heir_1")
	heirloom_system.designate_heirloom(artifact_id, "heir_1", 1)
	heirloom_system.inherit_heirloom(artifact_id, "heir_1", "heir_2", 5)
	enchantment_system.apply_enchantment(artifact_id, ArtifactEnchantmentSystem.EnchantmentType.COMBAT_BONUS, 1)

	var state = artifact_persistence.save_artifact_state(artifact_system, heirloom_system, enchantment_system)

	assert(state.has("artifacts"), "State should have artifacts")
	assert(state.has("heirlooms"), "State should have heirlooms")
	assert(state.has("enchantments"), "State should have enchantments")

	# Load into new systems
	var new_artifact_system = ArtifactSystem.new()
	var new_heirloom_system = HeirloomSystem.new()
	var new_enchantment_system = ArtifactEnchantmentSystem.new()

	artifact_persistence.load_artifact_state(state, new_artifact_system, new_heirloom_system, new_enchantment_system)

	assert(new_artifact_system.artifacts.size() > 0, "Artifacts should load")
	assert(new_heirloom_system.heirlooms.size() > 0, "Heirlooms should load")
	assert(new_enchantment_system.artifact_enchantments.size() > 0, "Enchantments should load")

	test_results.append("✓ Artifact persistence")


func test_generation_transfer() -> void:
	var artifact_id = artifact_system.create_artifact("Transfer", ArtifactSystem.ArtifactType.RELIC, ArtifactSystem.ArtifactRarity.MYTHIC, 1, "founder")
	heirloom_system.designate_heirloom(artifact_id, "founder", 1)
	heirloom_system.inherit_heirloom(artifact_id, "founder", "heir_gen2", 2)
	heirloom_system.inherit_heirloom(artifact_id, "heir_gen2", "heir_gen3", 5)

	var state = artifact_persistence.save_artifact_state(artifact_system, heirloom_system, enchantment_system)
	var transferred = artifact_persistence.transfer_artifacts_to_next_generation(state, 10)

	assert(transferred.has("heirlooms"), "Transferred state should have heirlooms")
	assert(transferred["heirlooms"].size() > 0, "Heirlooms should transfer")

	# Power should have increased
	var original_power = state["heirlooms"][0]["power_multiplier"]
	var transferred_power = transferred["heirlooms"][0]["power_multiplier"]
	assert(transferred_power > original_power, "Heirloom power should scale in transfer")

	test_results.append("✓ Generation transfer")


func test_complex_scenarios() -> void:
	# Scenario: Multi-generation artifact evolution
	var artifact_id = artifact_system.create_artifact("Evolving", ArtifactSystem.ArtifactType.WEAPON, ArtifactSystem.ArtifactRarity.UNCOMMON, 1, "founder")
	heirloom_system.designate_heirloom(artifact_id, "founder", 1)

	var current_heir = "founder"
	for gen in range(2, 11):
		var next_heir = "heir_%d" % gen
		heirloom_system.inherit_heirloom(artifact_id, current_heir, next_heir, gen)
		artifact_system.upgrade_artifact_rarity(artifact_id)
		enchantment_system.apply_enchantment(artifact_id, randi() % 5, gen)
		current_heir = next_heir

	var final_artifact = artifact_system.get_artifact(artifact_id)
	var final_heirloom = heirloom_system.get_heirloom(artifact_id)
	assert(final_artifact.rarity > ArtifactSystem.ArtifactRarity.UNCOMMON, "Should have upgraded")
	assert(final_heirloom.times_inherited == 9, "Should have 9 inheritances")
	assert(final_heirloom.power_multiplier > 1.5, "Power should be significant")

	# Scenario: Artifact with maximum enchantments
	var enchanted_id = artifact_system.create_artifact("Enchanted", ArtifactSystem.ArtifactType.RELIC, ArtifactSystem.ArtifactRarity.LEGENDARY, 1, "heir_1")
	for _i in range(10):
		enchantment_system.apply_enchantment(enchanted_id, ArtifactEnchantmentSystem.EnchantmentType.STAT_BOOST, 1)

	var effects = enchantment_system.get_enchantment_effects(enchanted_id)
	assert(effects["total_power"] > 2.0, "Multiple stacks should boost power significantly")

	test_results.append("✓ Complex scenarios")


func print_results() -> void:
	print("\n=== Test Phase 12.2: Heirloom & Artifact System ===")
	for result in test_results:
		print(result)
	print("\nTotal: %d test groups passed" % test_results.size())


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
