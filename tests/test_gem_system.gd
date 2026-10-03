## Tests for gem and gem pouch systems
##
## Tests: gem creation, conditions, values, gem pouch management, catalog

extends GutTest


var gem: Gem
var pouch: GemPouch


func before_each() -> void:
	gem = Gem.new()
	pouch = GemPouch.new()


## Test: Create gem with all properties
func test_create_gem() -> void:
	var ruby = Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250)

	assert_eq(ruby.gem_type, "ruby")
	assert_eq(ruby.condition, Gem.Condition.EXCELLENT)
	assert_eq(ruby.rarity, Gem.Rarity.RARE)
	assert_eq(ruby.base_value_gp, 250)


## Test: Gem condition names
func test_gem_condition_names() -> void:
	var names = {
		Gem.Condition.FLAWLESS: "Flawless",
		Gem.Condition.EXCELLENT: "Excellent",
		Gem.Condition.GOOD: "Good",
		Gem.Condition.FAIR: "Fair",
		Gem.Condition.POOR: "Poor",
		Gem.Condition.DAMAGED: "Damaged"
	}

	for condition in range(Gem.Condition.DAMAGED + 1):
		var test_gem = Gem.new("test", condition)
		assert_eq(test_gem.get_condition_name(), names[condition])


## Test: Gem rarity names
func test_gem_rarity_names() -> void:
	var names = {
		Gem.Rarity.COMMON: "Common",
		Gem.Rarity.UNCOMMON: "Uncommon",
		Gem.Rarity.RARE: "Rare",
		Gem.Rarity.VERY_RARE: "Very Rare",
		Gem.Rarity.LEGENDARY: "Legendary"
	}

	for rarity in range(Gem.Rarity.LEGENDARY + 1):
		var test_gem = Gem.new("test", 0, rarity)
		assert_eq(test_gem.get_rarity_name(), names[rarity])


## Test: Condition affects value (multiplier)
func test_condition_multiplier() -> void:
	var base_gem = Gem.new("ruby", Gem.Condition.FLAWLESS, Gem.Rarity.RARE, 100)
	var damaged = Gem.new("ruby", Gem.Condition.DAMAGED, Gem.Rarity.RARE, 100)

	var base_value = base_gem.get_value_gp()
	var damaged_value = damaged.get_value_gp()

	assert_eq(base_value, 100)  # 100%
	assert_eq(damaged_value, 10)  # 10%


## Test: Gem value calculation
func test_gem_value_calculation() -> void:
	var excellent = Gem.new("diamond", Gem.Condition.EXCELLENT, Gem.Rarity.VERY_RARE, 1000)
	var good = Gem.new("diamond", Gem.Condition.GOOD, Gem.Rarity.VERY_RARE, 1000)

	assert_eq(excellent.get_value_gp(), 900)  # 90% of 1000
	assert_eq(good.get_value_gp(), 750)  # 75% of 1000


## Test: Gem value as currency
func test_gem_value_currency() -> void:
	var gem = Gem.new("sapphire", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 240)
	var currency = gem.get_value_currency()

	assert_eq(currency.to_copper(), 216 * 10)  # 216 gp in copper


## Test: Gem to string
func test_gem_to_string() -> void:
	var gem = Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250)
	var str = gem.to_string()

	assert_true("Excellent" in str)
	assert_true("Ruby" in str)
	assert_true("Rare" in str)


## Test: Damage gem (downgrade condition)
func test_damage_gem() -> void:
	var gem = Gem.new("diamond", Gem.Condition.EXCELLENT)

	gem.damage()

	assert_eq(gem.condition, Gem.Condition.GOOD)
	assert_lt(gem.get_value_gp(), 900)


## Test: Restore gem (upgrade condition)
func test_restore_gem() -> void:
	var gem = Gem.new("diamond", Gem.Condition.DAMAGED)

	gem.restore()

	assert_eq(gem.condition, Gem.Condition.POOR)
	assert_gt(gem.get_value_gp(), 10)


## Test: Is valuable (100+ gp)
func test_is_valuable() -> void:
	var valuable = Gem.new("diamond", Gem.Condition.FLAWLESS, Gem.Rarity.VERY_RARE, 1000)
	var worthless = Gem.new("quartz", Gem.Condition.DAMAGED, Gem.Rarity.COMMON, 15)

	assert_true(valuable.is_valuable())
	assert_false(worthless.is_valuable())


## Test: Gem catalog has gems
func test_gem_catalog_has_gems() -> void:
	var gems = GemCatalog.get_all_gem_types()

	assert_gt(gems.size(), 0)
	assert_true("ruby" in gems)
	assert_true("diamond" in gems)


## Test: Create gem from catalog
func test_create_gem_from_catalog() -> void:
	var ruby = GemCatalog.create_gem("ruby", Gem.Condition.EXCELLENT)

	assert_eq(ruby.gem_type, "ruby")
	assert_eq(ruby.condition, Gem.Condition.EXCELLENT)
	assert_eq(ruby.rarity, Gem.Rarity.RARE)
	assert_eq(ruby.base_value_gp, 250)


## Test: Random gem generation
func test_create_random_gem() -> void:
	var gem = GemCatalog.create_random_gem()

	assert_not_null(gem)
	assert_false(gem.gem_type.is_empty())
	assert_gte(gem.condition, Gem.Condition.FLAWLESS)
	assert_lte(gem.condition, Gem.Condition.DAMAGED)


## Test: Get gems by rarity
func test_get_gems_by_rarity() -> void:
	var rare_gems = GemCatalog.get_gems_by_rarity(Gem.Rarity.RARE)

	assert_gt(rare_gems.size(), 0)
	for gem_type in rare_gems:
		var data = GemCatalog.get_gem_data(gem_type)
		assert_eq(data["rarity"], Gem.Rarity.RARE)


## Test: Gem Pouch add gem
func test_pouch_add_gem() -> void:
	var gem = Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250)

	pouch.add_gem(gem)

	assert_eq(pouch.get_count(), 1)


## Test: Gem Pouch remove gem
func test_pouch_remove_gem() -> void:
	var gem = Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250)
	pouch.add_gem(gem)

	var success = pouch.remove_gem(0)

	assert_true(success)
	assert_eq(pouch.get_count(), 0)


## Test: Gem Pouch total value
func test_pouch_total_value() -> void:
	var ruby = Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250)
	var sapphire = Gem.new("sapphire", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 240)

	pouch.add_gem(ruby)
	pouch.add_gem(sapphire)

	# 225 + 216 = 441 gp
	assert_eq(pouch.get_total_value_gp(), 441)


## Test: Count gems by type
func test_pouch_count_by_type() -> void:
	pouch.add_gem(Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250))
	pouch.add_gem(Gem.new("ruby", Gem.Condition.GOOD, Gem.Rarity.RARE, 250))
	pouch.add_gem(Gem.new("sapphire", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 240))

	assert_eq(pouch.get_count_by_type("ruby"), 2)
	assert_eq(pouch.get_count_by_type("sapphire"), 1)


## Test: Get gems by type
func test_pouch_get_gems_by_type() -> void:
	pouch.add_gem(Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250))
	pouch.add_gem(Gem.new("ruby", Gem.Condition.GOOD, Gem.Rarity.RARE, 250))
	pouch.add_gem(Gem.new("sapphire", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 240))

	var rubies = pouch.get_gems_by_type("ruby")

	assert_eq(rubies.size(), 2)


## Test: Get top gems
func test_pouch_get_top_gems() -> void:
	pouch.add_gem(Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250))
	pouch.add_gem(Gem.new("sapphire", Gem.Condition.GOOD, Gem.Rarity.RARE, 240))
	pouch.add_gem(Gem.new("diamond", Gem.Condition.EXCELLENT, Gem.Rarity.VERY_RARE, 1000))

	var top = pouch.get_top_gems(2)

	assert_eq(top.size(), 2)
	assert_true(top[0].gem_type == "diamond")


## Test: Average gem value
func test_pouch_average_value() -> void:
	pouch.add_gem(Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 100))
	pouch.add_gem(Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 100))

	assert_eq(pouch.get_average_value_gp(), 90)  # 90% of 100


## Test: Take gem by type
func test_pouch_take_gem_by_type() -> void:
	pouch.add_gem(Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250))
	pouch.add_gem(Gem.new("sapphire", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 240))

	var taken = pouch.take_gem_of_type("ruby")

	assert_eq(taken.gem_type, "ruby")
	assert_eq(pouch.get_count(), 1)


## Test: Pouch statistics
func test_pouch_statistics() -> void:
	pouch.add_gem(Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250))
	pouch.add_gem(Gem.new("diamond", Gem.Condition.EXCELLENT, Gem.Rarity.VERY_RARE, 1000))

	var stats = pouch.get_stats()

	assert_eq(stats["total_gems"], 2)
	assert_gt(stats["total_value_gp"], 0)
	assert_true(stats["by_type"].has("ruby"))


## Test: Clear pouch
func test_pouch_clear() -> void:
	pouch.add_gem(Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250))
	pouch.add_gem(Gem.new("sapphire", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 240))

	pouch.clear()

	assert_eq(pouch.get_count(), 0)


## Test: Get sellable gems
func test_pouch_get_sellable_gems() -> void:
	pouch.add_gem(Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250))
	pouch.add_gem(Gem.new("quartz", Gem.Condition.DAMAGED, Gem.Rarity.COMMON, 15))

	var sellable = pouch.get_sellable_gems()

	assert_eq(sellable.size(), 2)  # Both worth at least 10 gp


## Test: Get valuable gems
func test_pouch_get_valuable_gems() -> void:
	pouch.add_gem(Gem.new("ruby", Gem.Condition.EXCELLENT, Gem.Rarity.RARE, 250))
	pouch.add_gem(Gem.new("quartz", Gem.Condition.EXCELLENT, Gem.Rarity.COMMON, 15))

	var valuable = pouch.get_valuable_gems()

	assert_eq(valuable.size(), 1)  # Only ruby worth 100+ gp
