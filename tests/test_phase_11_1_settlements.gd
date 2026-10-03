## Test Suite for Phase 11.1: Settlement & Building Systems
##
## Comprehensive tests for buildings, settlements, resources, and player interactions

extends GutTest


var building_system: BuildingSystem
var settlement_system: SettlementSystem
var interaction_system: BuildingInteractionSystem
var persistence_system: SettlementPersistence


func before_each() -> void:
	building_system = BuildingSystem.new()
	settlement_system = SettlementSystem.new()
	interaction_system = BuildingInteractionSystem.new(building_system)
	persistence_system = SettlementPersistence.new(settlement_system)


# ============================================================
# Building System Tests
# ============================================================

func test_building_system_created() -> void:
	assert_not_null(building_system)


func test_create_building() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.BLACKSMITH, Vector2i(10, 10), "smith")
	assert_true(building_system.building_exists(building_id))


func test_building_properties() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.INN, Vector2i(5, 5), "innkeeper")
	var building = building_system.get_building(building_id)
	
	assert_eq(building.type, BuildingSystem.BuildingType.INN)
	assert_eq(building.location, Vector2i(5, 5))
	assert_eq(building.owner, "innkeeper")
	assert_eq(building.condition, 1.0)


func test_building_resource_production() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.BLACKSMITH, Vector2i(0, 0), "owner")
	var produced = building_system.produce_resources(building_id, 100.0, 1.0)
	
	assert_true("gold" in produced)
	assert_gt(produced["gold"], 0)
	assert_true("ore" in produced)


func test_production_affected_by_prosperity() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.MARKET, Vector2i(0, 0), "owner")
	
	var produced_100 = building_system.produce_resources(building_id, 100.0, 1.0)
	var produced_50 = building_system.produce_resources(building_id, 50.0, 1.0)
	
	assert_gt(produced_100["gold"], produced_50["gold"])


func test_production_affected_by_realm_multiplier() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.TAVERN, Vector2i(0, 0), "owner")
	
	var produced_1x = building_system.produce_resources(building_id, 100.0, 1.0)
	var produced_3x = building_system.produce_resources(building_id, 100.0, 3.0)
	
	assert_gt(produced_3x["gold"], produced_1x["gold"])


func test_production_affected_by_condition() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.CRAFT_SHOP, Vector2i(0, 0), "owner")
	
	var produced_perfect = building_system.produce_resources(building_id, 100.0, 1.0)
	
	building_system.update_condition(building_id, -0.5)
	var produced_degraded = building_system.produce_resources(building_id, 100.0, 1.0)
	
	assert_gt(produced_perfect["gold"], produced_degraded["gold"])


func test_building_stock_management() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.BLACKSMITH, Vector2i(0, 0), "owner")
	
	building_system.add_to_stock(building_id, "ore", 10)
	var building = building_system.get_building(building_id)
	assert_eq(building.resource_stockpile.get("ore"), 10)
	
	var removed = building_system.remove_from_stock(building_id, "ore", 5)
	assert_true(removed)
	assert_eq(building.resource_stockpile.get("ore"), 5)


func test_building_ownership_change() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.INN, Vector2i(0, 0), "old_owner")
	
	building_system.change_owner(building_id, "new_owner")
	var building = building_system.get_building(building_id)
	assert_eq(building.owner, "new_owner")


func test_building_repair() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.TEMPLE, Vector2i(0, 0), "owner")
	building_system.update_condition(building_id, -0.5)
	
	var building = building_system.get_building(building_id)
	var degraded_condition = building.condition
	
	building_system.repair_building(building_id, 0.3)
	assert_gt(building.condition, degraded_condition)


# ============================================================
# Settlement System Tests
# ============================================================

func test_settlement_system_created() -> void:
	assert_not_null(settlement_system)


func test_create_settlement() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(100, 100))
	assert_true(settlement_system.settlement_exists(settlement_id))


func test_settlement_properties() -> void:
	var settlement_id = settlement_system.create_settlement("Mountainhold", Vector2i(50, 50))
	var settlement = settlement_system.get_settlement(settlement_id)
	
	assert_eq(settlement.name, "Mountainhold")
	assert_eq(settlement.location, Vector2i(50, 50))
	assert_eq(settlement.prosperity, 50.0)


func test_add_building_to_settlement() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	var building_id = settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.INN)
	
	var settlement = settlement_system.get_settlement(settlement_id)
	assert_true(building_id in settlement.buildings)


func test_get_settlement_buildings() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.INN)
	settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.BLACKSMITH)
	
	var buildings = settlement_system.get_settlement_buildings(settlement_id)
	assert_eq(buildings.size(), 2)


func test_settlement_production() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.MARKET)
	
	var production = settlement_system.process_settlement_production(settlement_id, 1.0)
	assert_true("gold" in production)
	assert_gt(production["gold"], 0)


func test_settlement_prosperity_update() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	var settlement = settlement_system.get_settlement(settlement_id)
	
	var initial = settlement.prosperity
	settlement_system.update_settlement_prosperity(settlement_id, 10.0)
	
	assert_gt(settlement.prosperity, initial)


func test_settlement_population_update() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	
	settlement_system.update_settlement_population(settlement_id, 50)
	var settlement = settlement_system.get_settlement(settlement_id)
	assert_eq(settlement.population, 50)


func test_calculate_settlement_wealth() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.MARKET)
	
	settlement_system.process_settlement_production(settlement_id, 1.0)
	var wealth = settlement_system.calculate_settlement_wealth(settlement_id)
	
	assert_gt(wealth, 0)


func test_nearby_settlements() -> void:
	var settlement1 = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	var settlement2 = settlement_system.create_settlement("Stonehold", Vector2i(20, 20))
	var settlement3 = settlement_system.create_settlement("Faraway", Vector2i(200, 200))
	
	var nearby = settlement_system.get_nearby_settlements(Vector2i(0, 0), 50)
	assert_eq(nearby.size(), 2)


# ============================================================
# Building Interaction Tests
# ============================================================

func test_interaction_system_created() -> void:
	assert_not_null(interaction_system)


func test_player_has_starting_gold() -> void:
	assert_eq(interaction_system.get_player_gold(), 500)


func test_buy_item_from_building() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.MARKET, Vector2i(0, 0), "owner")
	building_system.add_to_stock(building_id, "trade_goods", 10)
	
	var success = interaction_system.buy_item(building_id, "trade_goods", 2)
	assert_true(success)
	assert_eq(interaction_system.get_player_inventory()["trade_goods"], 2)


func test_cannot_buy_insufficient_gold() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.MARKET, Vector2i(0, 0), "owner")
	building_system.add_to_stock(building_id, "trade_goods", 100)
	
	interaction_system.player_gold = 5
	var success = interaction_system.buy_item(building_id, "trade_goods", 100)
	assert_false(success)


func test_cannot_buy_out_of_stock() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.MARKET, Vector2i(0, 0), "owner")
	
	var success = interaction_system.buy_item(building_id, "trade_goods", 10)
	assert_false(success)


func test_sell_item_to_building() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.MARKET, Vector2i(0, 0), "owner")
	
	interaction_system.add_to_player_inventory("ore", 5)
	var gold_before = interaction_system.get_player_gold()
	
	var success = interaction_system.sell_item(building_id, "ore", 2)
	assert_true(success)
	assert_gt(interaction_system.get_player_gold(), gold_before)


func test_price_scarcity_multiplier() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.MARKET, Vector2i(0, 0), "owner")
	
	building_system.add_to_stock(building_id, "ore", 2)
	var price_scarce = interaction_system.calculate_purchase_price(building_id, "ore", 1)
	
	building_system.add_to_stock(building_id, "ore", 20)
	var price_abundant = interaction_system.calculate_purchase_price(building_id, "ore", 1)
	
	assert_gt(price_scarce, price_abundant)


func test_hire_npc() -> void:
	var success = interaction_system.hire_npc("innkeeper", 50)
	assert_true(success)
	assert_eq(interaction_system.get_player_inventory()["hired_npc"], 1)


func test_donate_to_temple() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.TEMPLE, Vector2i(0, 0), "priest")
	
	var success = interaction_system.donate_to_temple(building_id, 100)
	assert_true(success)
	assert_eq(interaction_system.get_player_gold(), 400)


func test_commission_craft() -> void:
	var building_id = building_system.create_building(BuildingSystem.BuildingType.CRAFT_SHOP, Vector2i(0, 0), "smith")
	
	var success = interaction_system.commission_craft(building_id, "sword", 100)
	assert_true(success)
	assert_eq(interaction_system.get_player_gold(), 400)


# ============================================================
# Settlement Persistence Tests
# ============================================================

func test_persistence_system_created() -> void:
	assert_not_null(persistence_system)


func test_save_settlement() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.INN)
	
	var saved_data = persistence_system.save_settlement(settlement_id)
	assert_true("id" in saved_data)
	assert_eq(saved_data["name"], "Riverside")


func test_load_settlement() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.MARKET)
	settlement_system.update_settlement_prosperity(settlement_id, 25.0)
	
	var saved_data = persistence_system.save_settlement(settlement_id)
	
	persistence_system.clear_saved_data()
	settlement_system.settlements.clear()
	
	var loaded_id = persistence_system.load_settlement(saved_data)
	var loaded_settlement = settlement_system.get_settlement(loaded_id)
	
	assert_eq(loaded_settlement.name, "Riverside")
	assert_eq(loaded_settlement.prosperity, 75.0)


func test_save_all_settlements() -> void:
	settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	settlement_system.create_settlement("Stonehold", Vector2i(50, 50))
	
	var all_data = persistence_system.save_all_settlements()
	assert_eq(all_data.size(), 2)


func test_settlement_history_export() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.INN)
	settlement_system.process_settlement_production(settlement_id, 1.0)
	
	var history = persistence_system.export_settlement_history(settlement_id)
	assert_true("total_gold_generated" in history)
	assert_true("wealth" in history)


# ============================================================
# Complex Scenario Tests
# ============================================================

func test_full_settlement_lifecycle() -> void:
	var settlement_id = settlement_system.create_settlement("Riverhold", Vector2i(100, 100))
	
	settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.MARKET)
	settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.INN)
	settlement_system.update_settlement_prosperity(settlement_id, 20.0)
	settlement_system.update_settlement_population(settlement_id, 150)
	
	for i in range(10):
		settlement_system.process_settlement_production(settlement_id, 1.0)
	
	var wealth = settlement_system.calculate_settlement_wealth(settlement_id)
	assert_gt(wealth, 0)


func test_multi_settlement_economy() -> void:
	var river = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	var stone = settlement_system.create_settlement("Stonehold", Vector2i(100, 100))
	
	settlement_system.add_building_to_settlement(river, BuildingSystem.BuildingType.MARKET)
	settlement_system.add_building_to_settlement(stone, BuildingSystem.BuildingType.BLACKSMITH)
	
	settlement_system.process_settlement_production(river, 1.0)
	settlement_system.process_settlement_production(stone, 1.0)
	
	var river_wealth = settlement_system.calculate_settlement_wealth(river)
	var stone_wealth = settlement_system.calculate_settlement_wealth(stone)
	
	assert_gt(river_wealth, 0)
	assert_gt(stone_wealth, 0)


func test_player_trading_flow() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.MARKET)
	
	settlement_system.process_settlement_production(settlement_id, 1.0)
	
	var gold_start = interaction_system.get_player_gold()
	
	var building_id = settlement_system.building_system.get_buildings_in_settlement(Vector2i(0, 0))[0].id
	interaction_system.buy_item(building_id, "trade_goods", 2)
	interaction_system.sell_item(building_id, "trade_goods", 2)
	
	var gold_end = interaction_system.get_player_gold()
	assert_gt(gold_start, gold_end)


func test_settlement_persistence_through_degradation() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.INN)
	
	persistence_system.decay_settlements_over_time(5000, 0.05)
	
	var settlement = settlement_system.get_settlement(settlement_id)
	assert_lt(settlement.prosperity, 50.0)
	
	persistence_system.restore_settlement_prosperity(settlement_id, 10.0)
	assert_gt(settlement.prosperity, 40.0)


func test_building_quantity_by_type() -> void:
	var settlement_id = settlement_system.create_settlement("Riverside", Vector2i(0, 0))
	
	for i in range(3):
		settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.INN)
	for i in range(2):
		settlement_system.add_building_to_settlement(settlement_id, BuildingSystem.BuildingType.MARKET)
	
	var summary = settlement_system.get_settlement_summary(settlement_id)
	assert_eq(summary["building_types"]["INN"], 3)
	assert_eq(summary["building_types"]["MARKET"], 2)
