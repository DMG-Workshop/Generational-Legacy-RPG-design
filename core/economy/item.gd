## Item base class: foundation for all items in the game
##
## Weapons, armor, consumables, quest items all extend this

extends Resource

class_name Item


## Item rarity affects stats and value
enum Rarity {
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	VERY_RARE = 3,
	LEGENDARY = 4
}


## Item type/category
enum ItemType {
	WEAPON = 0,
	ARMOR = 1,
	ACCESSORY = 2,
	CONSUMABLE = 3,
	QUEST_ITEM = 4,
	CRAFTING_MATERIAL = 5
}


## Basic properties
var item_id: String = ""
var name: String = ""
var description: String = ""
var item_type: int = ItemType.CRAFTING_MATERIAL
var rarity: int = Rarity.COMMON

## Value and weight
var value: Currency = Currency.new(0, 10, 0, 0)
var weight: float = 0.5  # in pounds

## Flags
var is_stackable: bool = false
var max_stack: int = 1
var is_tradeable: bool = true
var is_cursed: bool = false
var is_identified: bool = true

## Properties/effects
var properties: Dictionary = {}  # Additional properties
var effects: Array[String] = []  # Effect IDs (poison, fire, etc.)

## Quality/condition
var quality: int = 100  # 0-100, affects durability and performance
var max_durability: int = 100
var current_durability: int = 100


func _init(
	p_id: String = "",
	p_name: String = "",
	p_type: int = ItemType.CRAFTING_MATERIAL,
	p_rarity: int = Rarity.COMMON,
	p_value: Currency = null
) -> void:
	item_id = p_id
	name = p_name
	item_type = p_type
	rarity = p_rarity
	if p_value:
		value = p_value
	else:
		value = Currency.new(0, 10, 0, 0)


## Get rarity name
func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.VERY_RARE:
			return "Very Rare"
		Rarity.LEGENDARY:
			return "Legendary"
	return "Unknown"


## Get type name
func get_type_name() -> String:
	match item_type:
		ItemType.WEAPON:
			return "Weapon"
		ItemType.ARMOR:
			return "Armor"
		ItemType.ACCESSORY:
			return "Accessory"
		ItemType.CONSUMABLE:
			return "Consumable"
		ItemType.QUEST_ITEM:
			return "Quest Item"
		ItemType.CRAFTING_MATERIAL:
			return "Material"
	return "Unknown"


## Get display string (e.g., "Iron Sword (Common)")
func to_string() -> String:
	if is_cursed:
		return "[CURSED] %s (%s)" % [name, get_rarity_name()]
	return "%s (%s)" % [name, get_rarity_name()]


## Get detailed string for tooltip
func to_detailed_string() -> String:
	var str = "%s\n" % to_string()
	str += "Type: %s\n" % get_type_name()
	if not description.is_empty():
		str += "Description: %s\n" % description
	str += "Value: %s\n" % value.to_string()
	if item_type in [ItemType.WEAPON, ItemType.ARMOR]:
		str += "Durability: %d/%d\n" % [current_durability, max_durability]
	if is_stackable:
		str += "Max Stack: %d\n" % max_stack
	return str


## Get durability percentage
func get_durability_percent() -> float:
	if max_durability == 0:
		return 100.0
	return (float(current_durability) / float(max_durability)) * 100.0


## Damage item (reduce durability)
func damage(amount: int = 1) -> bool:
	current_durability -= amount
	if current_durability < 0:
		current_durability = 0
		return true  # Item broken
	return false


## Repair item
func repair(amount: int = 10) -> void:
	current_durability = mini(current_durability + amount, max_durability)


## Fully repair item
func fully_repair() -> void:
	current_durability = max_durability


## Check if item is broken
func is_broken() -> bool:
	return current_durability <= 0


## Check if item is nearly broken (under 25%)
func is_nearly_broken() -> bool:
	return get_durability_percent() < 25.0


## Add effect to item
func add_effect(effect_id: String) -> void:
	if effect_id not in effects:
		effects.append(effect_id)


## Remove effect from item
func remove_effect(effect_id: String) -> void:
	effects.erase(effect_id)


## Check if item has effect
func has_effect(effect_id: String) -> bool:
	return effect_id in effects


## Set custom property
func set_property(key: String, value: Variant) -> void:
	properties[key] = value


## Get custom property
func get_property(key: String, default_value: Variant = null) -> Variant:
	return properties.get(key, default_value)


## Get rarity color
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color.GRAY
		Rarity.UNCOMMON:
			return Color.GREEN
		Rarity.RARE:
			return Color.BLUE
		Rarity.VERY_RARE:
			return Color.MAGENTA
		Rarity.LEGENDARY:
			return Color.GOLD
	return Color.WHITE


## Can this item be equipped (for equipment check)
func can_equip() -> bool:
	return item_type in [ItemType.WEAPON, ItemType.ARMOR, ItemType.ACCESSORY]


## Can this item be used (for consumables check)
func can_use() -> bool:
	return item_type == ItemType.CONSUMABLE


## Can this item be sold
func can_sell() -> bool:
	return is_tradeable and item_type != ItemType.QUEST_ITEM
