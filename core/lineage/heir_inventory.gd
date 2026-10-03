## Heir Inventory: helper class for managing heir inventory
##
## Wraps inventory array with convenient methods for adding/removing/querying items

class_name HeirInventory


var heir: Heir


func _init(p_heir: Heir) -> void:
	heir = p_heir


## Add an item to inventory
func add_item(item: Item) -> void:
	if item:
		heir.inventory.append(item)


## Remove an item by reference
func remove_item(item: Item) -> bool:
	return heir.inventory.erase(item)


## Get count of items with specific ID
func get_item_count(item_id: String) -> int:
	var count = 0
	for item in heir.inventory:
		if item.item_id == item_id:
			count += 1
	return count


## Get all items of a specific type
func get_items_by_type(item_type: int) -> Array[Item]:
	var result: Array[Item] = []
	for item in heir.inventory:
		if item.item_type == item_type:
			result.append(item)
	return result


## Get all weapons
func get_weapons() -> Array[Item]:
	return get_items_by_type(Item.ItemType.WEAPON)


## Get all armor pieces
func get_armor() -> Array[Item]:
	return get_items_by_type(Item.ItemType.ARMOR)


## Get all accessories
func get_accessories() -> Array[Item]:
	return get_items_by_type(Item.ItemType.ACCESSORY)


## Get all consumables
func get_consumables() -> Array[Item]:
	return get_items_by_type(Item.ItemType.CONSUMABLE)


## Get all crafting materials
func get_materials() -> Array[Item]:
	return get_items_by_type(Item.ItemType.CRAFTING_MATERIAL)


## Get all quest items
func get_quest_items() -> Array[Item]:
	return get_items_by_type(Item.ItemType.QUEST_ITEM)


## Get total inventory count
func get_total_count() -> int:
	return heir.inventory.size()


## Get total weight of inventory
func get_total_weight() -> float:
	var total = 0.0
	for item in heir.inventory:
		total += item.weight
	return total


## Get total value of all items in inventory
func get_total_value() -> int:
	var total_copper = 0
	for item in heir.inventory:
		total_copper += item.value.to_copper()
	return total_copper


## Sort inventory by rarity (highest first)
func sort_by_rarity() -> void:
	heir.inventory.sort_custom(func(a, b): return a.rarity > b.rarity)


## Sort inventory by type
func sort_by_type() -> void:
	heir.inventory.sort_custom(func(a, b): return a.item_type < b.item_type)


## Sort inventory by value (highest first)
func sort_by_value() -> void:
	heir.inventory.sort_custom(func(a, b): return a.value.to_copper() > b.value.to_copper())


## Sort inventory by name
func sort_by_name() -> void:
	heir.inventory.sort_custom(func(a, b): return a.name < b.name)


## Find item by ID (returns first match)
func find_item(item_id: String) -> Item:
	for item in heir.inventory:
		if item.item_id == item_id:
			return item
	return null


## Get inventory summary
func get_summary() -> String:
	var weapons = get_weapons().size()
	var armor = get_armor().size()
	var accessories = get_accessories().size()
	var consumables = get_consumables().size()
	var materials = get_materials().size()
	var quest_items = get_quest_items().size()

	return "Inventory: %d weapons, %d armor, %d accessories, %d consumables, %d materials, %d quest items (Total: %d items, %.1f lbs)" % [
		weapons, armor, accessories, consumables, materials, quest_items,
		get_total_count(), get_total_weight()
	]


## Clear inventory
func clear() -> void:
	heir.inventory.clear()
