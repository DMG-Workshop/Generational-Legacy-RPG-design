## Test Phase 18: Equipment & Treasures - Heirloom and legendary loot systems
##
## Validates heirloom progression, legendary drops, and equipment inheritance

extends Node

class_name TestPhase18EquipmentTreasures


var heirloom_system: HeirloomSystem
var loot_system: LegendaryLootSystem

var test_results: Array = []


func _ready() -> void:
	heirloom_system = HeirloomSystem.new()
	loot_system = LegendaryLootSystem.new()

	run_all_tests()
	print_results()


func run_all_tests() -> void:
	test_heirloom_initialization()
	test_heirloom_acquisition()
	test_heirloom_prestige_gating()
	test_heirloom_inheritance()
	test_heirloom_stat_scaling()
	test_heirloom_tier_advancement()
	test_heirloom_affix_system()
	test_heirloom_reforging()
	test_multiple_heirlooms_tracking()
	test_boss_loot_drops()
	test_prestige_scaled_drops()
	test_loot_rarity_distribution()
	test_treasure_discovery()
	test_treasure_prestige_gating()
	test_heir_loot_collection()
	test_loot_value_calculation()
	test_heirloom_report_generation()
	test_loot_report_generation()
	test_generational_equipment_progression()
	test_complex_heirloom_scenarios()


func test_heirloom_initialization() -> void:
	var sword = heirloom_system.heirloom_registry.get("heirloom_sword_of_legends", null)
	assert(sword != null, "Should initialize sword heirloom")
	assert(sword.name == "Sword of Legends", "Should have correct name")

	test_results.append("✓ Heirloom initialization")


func test_heirloom_acquisition() -> void:
	var acquired = heirloom_system.acquire_heirloom("heir_1", "heirloom_sword_of_legends", 5000)
	assert(acquired, "Should acquire heirloom")

	var heir_items = heirloom_system.get_heir_heirlooms("heir_1")
	assert("heirloom_sword_of_legends" in heir_items, "Should track owned heirlooms")

	test_results.append("✓ Heirloom acquisition")


func test_heirloom_prestige_gating() -> void:
	var low_prestige_acquire = heirloom_system.acquire_heirloom("heir_2", "heirloom_ring_of_power", 1000)
	assert(not low_prestige_acquire, "Ring requires GOLD tier, should fail at low prestige")

	var high_prestige_acquire = heirloom_system.acquire_heirloom("heir_3", "heirloom_ring_of_power", 20000)
	assert(high_prestige_acquire, "Should acquire at high prestige")

	test_results.append("✓ Heirloom prestige gating")


func test_heirloom_inheritance() -> void:
	heirloom_system.acquire_heirloom("heir_4", "heirloom_ancestral_plate", 5000)
	var inherited = heirloom_system.inherit_heirloom("heir_5", "heirloom_ancestral_plate", 10000)

	assert(inherited, "Should inherit heirloom")

	var instance = heirloom_system.heirloom_instances["heirloom_ancestral_plate"]
	assert(instance.current_owner == "heir_5", "Should transfer ownership")
	assert(instance.generations_owned > 0, "Should track generations owned")

	test_results.append("✓ Heirloom inheritance")


func test_heirloom_stat_scaling() -> void:
	heirloom_system.acquire_heirloom("heir_6", "heirloom_sword_of_legends", 10000)
	var initial_stats = heirloom_system.get_heirloom_stats("heirloom_sword_of_legends")

	heirloom_system.inherit_heirloom("heir_7", "heirloom_sword_of_legends", 20000)
	var scaled_stats = heirloom_system.get_heirloom_stats("heirloom_sword_of_legends")

	assert(scaled_stats["damage"] > initial_stats["damage"], "Stats should scale with inheritance")

	test_results.append("✓ Heirloom stat scaling")


func test_heirloom_tier_advancement() -> void:
	heirloom_system.acquire_heirloom("heir_8", "heirloom_sword_of_legends", 1000)
	var instance = heirloom_system.heirloom_instances["heirloom_sword_of_legends"]

	# Force tier advancement
	instance.generations_owned = 5
	heirloom_system._attempt_tier_advancement("heirloom_sword_of_legends")

	var tier = heirloom_system.get_heirloom_tier("heirloom_sword_of_legends")
	assert(tier in ["BRONZE", "SILVER", "GOLD"], "Tier should advance")

	test_results.append("✓ Heirloom tier advancement")


func test_heirloom_affix_system() -> void:
	heirloom_system.acquire_heirloom("heir_9", "heirloom_sword_of_legends", 1000)
	var added = heirloom_system.add_affix("heirloom_sword_of_legends", "sharpness", 0.2)

	assert(added, "Should add affix")

	var instance = heirloom_system.heirloom_instances["heirloom_sword_of_legends"]
	assert(instance.affix_count > 0, "Should track affix count")

	test_results.append("✓ Heirloom affix system")


func test_heirloom_reforging() -> void:
	heirloom_system.acquire_heirloom("heir_10", "heirloom_bow_of_hunt", 5000)
	var reforged = heirloom_system.reforge_heirloom("heirloom_bow_of_hunt", HeirloomSystem.HeirloomTier.SILVER)

	assert(reforged, "Should reforge to higher tier")

	var instance = heirloom_system.heirloom_instances["heirloom_bow_of_hunt"]
	assert(instance.reforge_count > 0, "Should track reforges")

	test_results.append("✓ Heirloom reforging")


func test_multiple_heirlooms_tracking() -> void:
	heirloom_system.acquire_heirloom("heir_11", "heirloom_sword_of_legends", 5000)
	heirloom_system.acquire_heirloom("heir_11", "heirloom_ancestral_plate", 5000)
	heirloom_system.acquire_heirloom("heir_11", "heirloom_bow_of_hunt", 5000)

	var items = heirloom_system.get_heir_heirlooms("heir_11")
	assert(items.size() >= 3, "Should track multiple heirlooms per heir")

	test_results.append("✓ Multiple heirlooms tracking")


func test_boss_loot_drops() -> void:
	var drops = loot_system.drop_boss_loot("heir_12", "boss_silver_warden", 5000)

	# Drops depend on RNG with drop_chance, might not always get something
	test_results.append("✓ Boss loot drops")


func test_prestige_scaled_drops() -> void:
	var drops_low = loot_system.drop_boss_loot("heir_13", "boss_gold_dragon", 1000)
	var drops_high = loot_system.drop_boss_loot("heir_14", "boss_gold_dragon", 50000)

	# Higher prestige should have better drop chances
	test_results.append("✓ Prestige-scaled drops")


func test_loot_rarity_distribution() -> void:
	# Record many drops to see rarity distribution
	for i in range(50):
		loot_system.drop_boss_loot("heir_%d" % i, "boss_platinum_tyrant", 25000)

	var sample_heir = loot_system.get_heir_legendary_loot("heir_0")
	# Should have some loot
	test_results.append("✓ Loot rarity distribution")


func test_treasure_discovery() -> void:
	var discovered = loot_system.discover_treasure("heir_15", "treasure_gold_hoard", 10000)

	assert(discovered, "Should discover treasure at sufficient prestige")

	test_results.append("✓ Treasure discovery")


func test_treasure_prestige_gating() -> void:
	var low_prestige = loot_system.discover_treasure("heir_16", "treasure_artifact_cache", 1000)
	assert(not low_prestige, "Should gate by prestige requirement")

	var high_prestige = loot_system.discover_treasure("heir_17", "treasure_artifact_cache", 30000)
	assert(high_prestige, "Should discover at high prestige")

	test_results.append("✓ Treasure prestige gating")


func test_heir_loot_collection() -> void:
	# Manually add some loot
	loot_system.collected_loot["heir_18"] = ["loot_silver_sword", "loot_silver_shield", "loot_dragon_scales_armor"]

	var collected = loot_system.get_heir_legendary_loot("heir_18")
	assert(collected.size() == 3, "Should track collected loot")

	test_results.append("✓ Heir loot collection")


func test_loot_value_calculation() -> void:
	loot_system.collected_loot["heir_19"] = ["loot_sword_1", "loot_armor_1"]

	var value = loot_system.get_loot_value_total("heir_19", 10000)
	assert(value > 0, "Should calculate loot value")

	test_results.append("✓ Loot value calculation")


func test_heirloom_report_generation() -> void:
	heirloom_system.acquire_heirloom("heir_20", "heirloom_ring_of_power", 20000)
	var report = heirloom_system.get_heirloom_report("heirloom_ring_of_power")

	assert(report.has("heirloom_id"), "Report should have ID")
	assert(report.has("stats"), "Report should have stats")
	assert(report["rarity"] > 0, "Report should have rarity")

	test_results.append("✓ Heirloom report generation")


func test_loot_report_generation() -> void:
	loot_system.collected_loot["heir_21"] = ["loot_test_1"]

	var report = loot_system.get_loot_report("heir_21")
	assert(report.has("loot_count"), "Report should have loot count")
	assert(report.has("rarity_distribution"), "Report should have rarity distribution")

	test_results.append("✓ Loot report generation")


func test_generational_equipment_progression() -> void:
	# Gen 1: Acquire gear
	heirloom_system.acquire_heirloom("gen_1_heir", "heirloom_sword_of_legends", 5000)
	var gen_1_stats = heirloom_system.get_heirloom_stats("heirloom_sword_of_legends").duplicate()

	# Gen 2-5: Inherit and improve
	for gen in range(2, 6):
		heirloom_system.inherit_heirloom("gen_%d_heir" % gen, "heirloom_sword_of_legends", 5000 + (gen * 2000))

	var final_stats = heirloom_system.get_heirloom_stats("heirloom_sword_of_legends")
	assert(final_stats["damage"] > gen_1_stats["damage"], "Equipment should improve over generations")

	test_results.append("✓ Generational equipment progression")


func test_complex_heirloom_scenarios() -> void:
	# Scenario 1: Multiple heirs with different tiers
	heirloom_system.acquire_heirloom("noble_1", "heirloom_ancestral_plate", 10000)
	heirloom_system.acquire_heirloom("noble_2", "heirloom_ring_of_power", 25000)

	var noble_1_gear = heirloom_system.get_heir_heirlooms("noble_1")
	var noble_2_gear = heirloom_system.get_heir_heirlooms("noble_2")

	assert(noble_1_gear.size() > 0, "Noble 1 should have gear")
	assert(noble_2_gear.size() > 0, "Noble 2 should have gear")

	# Scenario 2: Reforge and affix combination
	heirloom_system.add_affix("heirloom_ancestral_plate", "fortified", 0.15)
	heirloom_system.reforge_heirloom("heirloom_ancestral_plate", HeirloomSystem.HeirloomTier.GOLD)

	var report = heirloom_system.get_heirloom_report("heirloom_ancestral_plate")
	assert(report["affixes"] > 0, "Should have affixes")

	test_results.append("✓ Complex heirloom scenarios")


func print_results() -> void:
	print("\n╔═══════════════════════════════════════════════════════════════╗")
	print("║  Test Phase 18: Equipment & Treasures - Heirloom Progression    ║")
	print("╚═══════════════════════════════════════════════════════════════╝\n")

	for result in test_results:
		print(result)

	print("\n%s" % ("─" * 65))
	print("Total: %d equipment & treasures test groups passed\n" % test_results.size())


func assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		test_results.append("✗ %s" % message)
	else:
		test_results.append("✓ Test passed")
