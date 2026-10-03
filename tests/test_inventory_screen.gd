## Tests for Inventory Screen UI component
##
## Tests: item display, filtering, sorting, searching, item selection, and actions

extends GutTest


var inventory_screen: InventoryScreen
var heir: Heir
var test_items: Array[Item] = []


func before_each() -> void:
	# Create a test heir
	heir = Heir.new()
	heir.name = "Test Hero"
	heir.class_id = "warrior"
	heir.generation = 5
	heir.inventory = []

	# Create test items
	_create_test_items()

	# Add items to heir inventory
	for item in test_items:
		heir.inventory.append(item)

	# Create inventory screen
	inventory_screen = InventoryScreen.new(heir)


func _create_test_items() -> void:
	test_items.clear()

	# Weapon
	var sword = Item.new("iron_sword", "Iron Sword", Item.ItemType.WEAPON, Item.Rarity.COMMON)
	sword.description = "A simple iron sword"
	sword.value = Currency.new(0, 25, 0, 0)
	sword.weight = 3.5
	test_items.append(sword)

	# Armor
	var armor = Item.new("leather_chest", "Leather Chest", Item.ItemType.ARMOR, Item.Rarity.UNCOMMON)
	armor.description = "Basic leather armor"
	armor.value = Currency.new(0, 40, 0, 0)
	armor.weight = 8.0
	test_items.append(armor)

	# Consumable
	var potion = Item.new("health_potion", "Health Potion", Item.ItemType.CONSUMABLE, Item.Rarity.COMMON)
	potion.description = "Restores 30 HP"
	potion.value = Currency.new(0, 5, 0, 0)
	potion.weight = 0.5
	potion.is_stackable = true
	potion.max_stack = 5
	test_items.append(potion)

	# Material
	var ore = Item.new("iron_ore", "Iron Ore", Item.ItemType.CRAFTING_MATERIAL, Item.Rarity.COMMON)
	ore.description = "Raw iron ore for crafting"
	ore.value = Currency.new(0, 3, 0, 0)
	ore.weight = 2.0
	ore.is_stackable = true
	ore.max_stack = 10
	test_items.append(ore)

	# Rare item
	var rare_sword = Item.new("excalibur", "Excalibur", Item.ItemType.WEAPON, Item.Rarity.LEGENDARY)
	rare_sword.description = "A legendary blade of immense power"
	rare_sword.value = Currency.new(2, 50, 0, 0)
	rare_sword.weight = 2.5
	test_items.append(rare_sword)

	# Quest item
	var quest_item = Item.new("ancient_rune", "Ancient Rune", Item.ItemType.QUEST_ITEM, Item.Rarity.RARE)
	quest_item.description = "Required for the ancient ritual"
	quest_item.value = Currency.new(0, 0, 0, 0)
	quest_item.weight = 1.0
	quest_item.is_tradeable = false
	test_items.append(quest_item)

	# Accessory
	var ring = Item.new("ring_of_wisdom", "Ring of Wisdom", Item.ItemType.ACCESSORY, Item.Rarity.UNCOMMON)
	ring.description = "Increases wisdom"
	ring.value = Currency.new(0, 20, 0, 0)
	ring.weight = 0.1
	test_items.append(ring)


## Test: Inventory screen initializes with correct heir
func test_inventory_screen_init() -> void:
	assert_not_null(inventory_screen)
	assert_eq(inventory_screen.heir, heir)
	assert_eq(inventory_screen.heir.name, "Test Hero")


## Test: Filter type enum values
func test_filter_type_enum() -> void:
	assert_eq(InventoryScreen.FilterType.ALL, 0)
	assert_eq(InventoryScreen.FilterType.WEAPONS, 1)
	assert_eq(InventoryScreen.FilterType.ARMOR, 2)
	assert_eq(InventoryScreen.FilterType.ACCESSORIES, 3)
	assert_eq(InventoryScreen.FilterType.CONSUMABLES, 4)
	assert_eq(InventoryScreen.FilterType.MATERIALS, 5)
	assert_eq(InventoryScreen.FilterType.QUEST_ITEMS, 6)


## Test: Sort type enum values
func test_sort_type_enum() -> void:
	assert_eq(InventoryScreen.SortType.RARITY, 0)
	assert_eq(InventoryScreen.SortType.TYPE, 1)
	assert_eq(InventoryScreen.SortType.VALUE, 2)
	assert_eq(InventoryScreen.SortType.NAME, 3)
	assert_eq(InventoryScreen.SortType.QUANTITY, 4)


## Test: Initial filter is ALL
func test_initial_filter_is_all() -> void:
	assert_eq(inventory_screen.current_filter, InventoryScreen.FilterType.ALL)


## Test: Initial sort is RARITY
func test_initial_sort_is_rarity() -> void:
	assert_eq(inventory_screen.current_sort, InventoryScreen.SortType.RARITY)


## Test: Filter by weapons
func test_filter_by_weapons() -> void:
	inventory_screen._on_filter_changed(InventoryScreen.FilterType.WEAPONS)

	var filtered = inventory_screen.filtered_items

	# Should contain iron_sword and excalibur
	assert_eq(filtered.size(), 2)
	assert_true(_contains_item_id(filtered, "iron_sword"))
	assert_true(_contains_item_id(filtered, "excalibur"))


## Test: Filter by armor
func test_filter_by_armor() -> void:
	inventory_screen._on_filter_changed(InventoryScreen.FilterType.ARMOR)

	var filtered = inventory_screen.filtered_items

	assert_eq(filtered.size(), 1)
	assert_true(_contains_item_id(filtered, "leather_chest"))


## Test: Filter by consumables
func test_filter_by_consumables() -> void:
	inventory_screen._on_filter_changed(InventoryScreen.FilterType.CONSUMABLES)

	var filtered = inventory_screen.filtered_items

	assert_eq(filtered.size(), 1)
	assert_true(_contains_item_id(filtered, "health_potion"))


## Test: Filter by materials
func test_filter_by_materials() -> void:
	inventory_screen._on_filter_changed(InventoryScreen.FilterType.MATERIALS)

	var filtered = inventory_screen.filtered_items

	assert_eq(filtered.size(), 1)
	assert_true(_contains_item_id(filtered, "iron_ore"))


## Test: Filter by quest items
func test_filter_by_quest_items() -> void:
	inventory_screen._on_filter_changed(InventoryScreen.FilterType.QUEST_ITEMS)

	var filtered = inventory_screen.filtered_items

	assert_eq(filtered.size(), 1)
	assert_true(_contains_item_id(filtered, "ancient_rune"))


## Test: Filter by accessories
func test_filter_by_accessories() -> void:
	inventory_screen._on_filter_changed(InventoryScreen.FilterType.ACCESSORIES)

	var filtered = inventory_screen.filtered_items

	assert_eq(filtered.size(), 1)
	assert_true(_contains_item_id(filtered, "ring_of_wisdom"))


## Test: Filter ALL shows all items
func test_filter_all() -> void:
	inventory_screen._on_filter_changed(InventoryScreen.FilterType.ALL)

	var filtered = inventory_screen.filtered_items

	assert_eq(filtered.size(), 7)


## Test: Sort by rarity (highest first)
func test_sort_by_rarity() -> void:
	inventory_screen.current_filter = InventoryScreen.FilterType.ALL
	inventory_screen.filtered_items = inventory_screen._apply_filter(heir.inventory)
	inventory_screen._apply_sort(inventory_screen.filtered_items)

	# Should be sorted legendary -> rare -> uncommon -> common
	assert_eq(inventory_screen.filtered_items[0].rarity, Item.Rarity.LEGENDARY)
	assert_eq(inventory_screen.filtered_items[1].rarity, Item.Rarity.RARE)


## Test: Sort by value (highest first)
func test_sort_by_value() -> void:
	inventory_screen.current_sort = InventoryScreen.SortType.VALUE
	inventory_screen.current_filter = InventoryScreen.FilterType.ALL
	inventory_screen.filtered_items = inventory_screen._apply_filter(heir.inventory)
	inventory_screen._apply_sort(inventory_screen.filtered_items)

	# Excalibur (250 gp) should be first
	assert_eq(inventory_screen.filtered_items[0].item_id, "excalibur")


## Test: Sort by name (A-Z)
func test_sort_by_name() -> void:
	inventory_screen.current_sort = InventoryScreen.SortType.NAME
	inventory_screen.current_filter = InventoryScreen.FilterType.ALL
	inventory_screen.filtered_items = inventory_screen._apply_filter(heir.inventory)
	inventory_screen._apply_sort(inventory_screen.filtered_items)

	# First should be alphabetically first
	var first_name = inventory_screen.filtered_items[0].name
	assert_true(first_name.begins_with("A") or first_name.begins_with("E"))


## Test: Search by item name
func test_search_by_name() -> void:
	inventory_screen.search_text = "sword"
	inventory_screen.current_filter = InventoryScreen.FilterType.ALL
	var filtered = inventory_screen._apply_filter(heir.inventory)
	filtered = inventory_screen._apply_search(filtered)

	# Should find iron_sword and excalibur
	assert_eq(filtered.size(), 2)


## Test: Search by description
func test_search_by_description() -> void:
	inventory_screen.search_text = "crafting"
	inventory_screen.current_filter = InventoryScreen.FilterType.ALL
	var filtered = inventory_screen._apply_filter(heir.inventory)
	filtered = inventory_screen._apply_search(filtered)

	# Should find iron_ore
	assert_eq(filtered.size(), 1)
	assert_eq(filtered[0].item_id, "iron_ore")


## Test: Search is case-insensitive
func test_search_case_insensitive() -> void:
	inventory_screen.search_text = "SWORD"
	inventory_screen.current_filter = InventoryScreen.FilterType.ALL
	var filtered = inventory_screen._apply_filter(heir.inventory)
	filtered = inventory_screen._apply_search(filtered)

	assert_eq(filtered.size(), 2)


## Test: Empty search returns all items
func test_empty_search() -> void:
	inventory_screen.search_text = ""
	inventory_screen.current_filter = InventoryScreen.FilterType.ALL
	var filtered = inventory_screen._apply_filter(heir.inventory)
	filtered = inventory_screen._apply_search(filtered)

	assert_eq(filtered.size(), 7)


## Test: Filter + Sort + Search combined
func test_filter_sort_search_combined() -> void:
	inventory_screen.current_filter = InventoryScreen.FilterType.WEAPONS
	inventory_screen.current_sort = InventoryScreen.SortType.VALUE
	inventory_screen.search_text = "sword"

	var filtered = inventory_screen._apply_filter(heir.inventory)
	inventory_screen.filtered_items = filtered
	inventory_screen._apply_sort(inventory_screen.filtered_items)
	filtered = inventory_screen._apply_search(inventory_screen.filtered_items)

	# Should get 2 weapons named sword, sorted by value
	assert_eq(filtered.size(), 2)
	# Excalibur (legendary) should come first due to higher value
	assert_eq(filtered[0].item_id, "excalibur")


## Test: Item selection
func test_item_selection() -> void:
	var item = test_items[0]  # iron_sword
	inventory_screen.selected_item = item

	assert_eq(inventory_screen.selected_item, item)
	assert_eq(inventory_screen.get_selected_item(), item)


## Test: Selected item cleared when filtered out
func test_selected_item_cleared_when_filtered_out() -> void:
	# Select a sword
	inventory_screen.selected_item = test_items[0]
	assert_eq(inventory_screen.selected_item.item_id, "iron_sword")

	# Filter to only consumables
	inventory_screen._on_filter_changed(InventoryScreen.FilterType.CONSUMABLES)

	# Selected item should be cleared
	assert_null(inventory_screen.selected_item)


## Test: Item can equip (weapons/armor/accessories)
func test_item_can_equip() -> void:
	var sword = test_items[0]  # weapon
	var armor = test_items[1]  # armor
	var potion = test_items[2]  # consumable

	assert_true(sword.can_equip())
	assert_true(armor.can_equip())
	assert_false(potion.can_equip())


## Test: Item can use (consumables only)
func test_item_can_use() -> void:
	var sword = test_items[0]  # weapon
	var potion = test_items[2]  # consumable

	assert_false(sword.can_use())
	assert_true(potion.can_use())


## Test: Item can sell (tradeable items)
func test_item_can_sell() -> void:
	var sword = test_items[0]  # weapon (tradeable)
	var quest_item = test_items[5]  # quest item (not tradeable)

	assert_true(sword.can_sell())
	assert_false(quest_item.can_sell())


## Test: Use button removes consumable
func test_use_consumable_removes_item() -> void:
	var potion = test_items[2]
	inventory_screen.selected_item = potion

	var initial_count = heir.inventory.size()
	inventory_screen._on_use_button_pressed()

	assert_eq(heir.inventory.size(), initial_count - 1)
	assert_false(potion in heir.inventory)


## Test: Drop button removes item
func test_drop_button_removes_item() -> void:
	var sword = test_items[0]
	inventory_screen.selected_item = sword

	var initial_count = heir.inventory.size()
	inventory_screen._on_drop_button_pressed()

	assert_eq(heir.inventory.size(), initial_count - 1)
	assert_false(sword in heir.inventory)


## Test: Equip button disabled for non-equipment
func test_equip_button_disabled_for_consumables() -> void:
	var potion = test_items[2]
	inventory_screen.selected_item = potion
	inventory_screen._update_details_panel()

	assert_true(inventory_screen.equip_button.disabled)


## Test: Use button disabled for non-consumables
func test_use_button_disabled_for_weapons() -> void:
	var sword = test_items[0]
	inventory_screen.selected_item = sword
	inventory_screen._update_details_panel()

	assert_true(inventory_screen.use_button.disabled)


## Test: Sell button disabled for quest items
func test_sell_button_disabled_for_quest_items() -> void:
	var quest_item = test_items[5]
	inventory_screen.selected_item = quest_item
	inventory_screen._update_details_panel()

	assert_true(inventory_screen.sell_button.disabled)


## Test: Signals emitted on actions
func test_signals_emitted() -> void:
	var sword = test_items[0]

	var item_equipped_signal_fired = false
	inventory_screen.item_equipped.connect(func(_item): item_equipped_signal_fired = true)

	# Simulate equip action
	inventory_screen.selected_item = sword
	inventory_screen._on_equip_button_pressed()

	assert_true(item_equipped_signal_fired)


## Test: Inventory header shows correct stats
func test_inventory_stats_calculation() -> void:
	var total_count = heir.inventory.size()
	var total_weight = 0.0
	for item in heir.inventory:
		total_weight += item.weight

	var heir_inv = HeirInventory.new(heir)
	assert_eq(heir_inv.get_total_count(), total_count)
	assert_eq(heir_inv.get_total_weight(), total_weight)


## Test: Item rarity colors are correct
func test_item_rarity_colors() -> void:
	assert_eq(test_items[0].get_rarity_color(), Color.GRAY)  # Common
	assert_eq(test_items[1].get_rarity_color(), Color.GREEN)  # Uncommon
	assert_eq(test_items[4].get_rarity_color(), Color.GOLD)  # Legendary


## Test: Item durability display
func test_item_durability_display() -> void:
	var sword = test_items[0]
	sword.max_durability = 100
	sword.current_durability = 75

	var durability_percent = sword.get_durability_percent()
	assert_eq(durability_percent, 75.0)


## Helper function to find item by ID
func _contains_item_id(items: Array[Item], item_id: String) -> bool:
	for item in items:
		if item.item_id == item_id:
			return true
	return false
