## Enchantment: magical effect applied to items
##
## Types: offensive, defensive, utility, special
## Rarities determine power and value multiplier

class_name Enchantment


## Enchantment types
enum EnchantmentType {
	OFFENSIVE,
	DEFENSIVE,
	UTILITY,
	SPECIAL
}

## Rarity/power tiers
enum EnchantmentRarity {
	MINOR,
	MODERATE,
	MAJOR,
	SUPREME,
	LEGENDARY
}

## Enchantment identifier
var enchantment_id: String = ""

## Display name
var name: String = ""

## Description of effect
var description: String = ""

## Type (offensive, defensive, etc.)
var enchantment_type: int = EnchantmentType.UTILITY

## Power tier
var rarity: int = EnchantmentRarity.MINOR

## Effect (what stat it modifies)
var effect_name: String = ""

## Effect value (bonus amount)
var effect_value: float = 0.0

## Which item types can have this (empty = all)
var compatible_item_types: Array[int] = []

## Cost multiplier (1.0 = base price, 2.0 = doubles price)
var cost_multiplier: float = 1.0

## Flavor text/lore
var lore: String = ""


func _init(
	p_id: String = "",
	p_name: String = "",
	p_effect: String = "",
	p_value: float = 0.0,
	p_type: int = EnchantmentType.UTILITY,
	p_rarity: int = EnchantmentRarity.MINOR
) -> void:
	enchantment_id = p_id
	name = p_name
	effect_name = p_effect
	effect_value = p_value
	enchantment_type = p_type
	rarity = p_rarity


## Get rarity name
func get_rarity_name() -> String:
	match rarity:
		EnchantmentRarity.MINOR:
			return "Minor"
		EnchantmentRarity.MODERATE:
			return "Moderate"
		EnchantmentRarity.MAJOR:
			return "Major"
		EnchantmentRarity.SUPREME:
			return "Supreme"
		EnchantmentRarity.LEGENDARY:
			return "Legendary"
		_:
			return "Unknown"


## Get type name
func get_type_name() -> String:
	match enchantment_type:
		EnchantmentType.OFFENSIVE:
			return "Offensive"
		EnchantmentType.DEFENSIVE:
			return "Defensive"
		EnchantmentType.UTILITY:
			return "Utility"
		EnchantmentType.SPECIAL:
			return "Special"
		_:
			return "Unknown"


## Check if can enchant item type
func can_enchant_type(item_type: int) -> bool:
	if compatible_item_types.is_empty():
		return true
	return item_type in compatible_item_types


## Get power value (1-5 based on rarity)
func get_power() -> int:
	return rarity + 1


## Get cost multiplier with stacking bonus
static func get_stacked_multiplier(enchantments: Array[Enchantment]) -> float:
	var multiplier = 1.0
	for ench in enchantments:
		multiplier *= ench.cost_multiplier
	# Stacking penalty: each additional enchantment adds diminishing returns
	if enchantments.size() > 1:
		multiplier *= pow(1.1, enchantments.size() - 1)
	return multiplier


## Full display string
func to_string() -> String:
	return "%s [%s %s]" % [name, get_type_name(), get_rarity_name()]


## Detailed display with effect
func to_detailed_string() -> String:
	var str = "%s\n" % to_string()
	str += "Type: %s\n" % get_type_name()
	str += "Effect: %s +%.1f\n" % [effect_name, effect_value]
	str += "Cost Multiplier: %.2fx\n" % cost_multiplier
	if not description.is_empty():
		str += "\n%s\n" % description
	if not lore.is_empty():
		str += "\nLore: %s\n" % lore
	return str
