## Equipment: items that can be worn/wielded and provide stat bonuses
##
## Weapons, armor, and accessories with stat modifiers

extends Item

class_name Equipment


## Equipment slot types
enum EquipmentSlot {
	MAIN_HAND = 0,
	OFF_HAND = 1,
	TWO_HANDED = 2,
	HEAD = 3,
	CHEST = 4,
	HANDS = 5,
	LEGS = 6,
	FEET = 7,
	NECK = 8,
	FINGER = 9
}


## Stat bonuses this equipment provides
var stat_bonuses: Dictionary = {
	"strength": 0,
	"dexterity": 0,
	"constitution": 0,
	"intelligence": 0,
	"wisdom": 0,
	"charisma": 0
}

## Resistances (0-100, percentage damage reduction)
var resistances: Dictionary = {
	"fire": 0,
	"cold": 0,
	"lightning": 0,
	"poison": 0,
	"magic": 0
}

## Equipment slot this goes in
var equipment_slot: int = EquipmentSlot.MAIN_HAND

## Required level to equip
var required_level: int = 1

## Class restrictions (empty = no restriction)
var allowed_classes: Array[String] = []

## Special abilities
var special_abilities: Array[String] = []


func _init(
	p_id: String = "",
	p_name: String = "",
	p_slot: int = EquipmentSlot.MAIN_HAND,
	p_value: Currency = null
) -> void:
	super._init(p_id, p_name, ItemType.ARMOR, Item.Rarity.COMMON, p_value)
	equipment_slot = p_slot


## Add stat bonus
func add_stat_bonus(stat: String, amount: int) -> void:
	if stat in stat_bonuses:
		stat_bonuses[stat] += amount


## Get total stat bonus value (sum of all bonuses)
func get_total_bonus() -> int:
	var total = 0
	for stat in stat_bonuses:
		total += stat_bonuses[stat]
	return total


## Add resistance
func add_resistance(resistance_type: String, amount: int) -> void:
	if resistance_type in resistances:
		resistances[resistance_type] = mini(resistances[resistance_type] + amount, 100)


## Add special ability
func add_ability(ability_id: String) -> void:
	if ability_id not in special_abilities:
		special_abilities.append(ability_id)


## Check if class can equip
func can_equip_class(class_id: String) -> bool:
	if allowed_classes.is_empty():
		return true
	return class_id in allowed_classes


## Check if level requirement met
func meets_level_requirement(level: int) -> bool:
	return level >= required_level


## Get slot name
func get_slot_name() -> String:
	match equipment_slot:
		EquipmentSlot.MAIN_HAND:
			return "Main Hand"
		EquipmentSlot.OFF_HAND:
			return "Off Hand"
		EquipmentSlot.TWO_HANDED:
			return "Two Handed"
		EquipmentSlot.HEAD:
			return "Head"
		EquipmentSlot.CHEST:
			return "Chest"
		EquipmentSlot.HANDS:
			return "Hands"
		EquipmentSlot.LEGS:
			return "Legs"
		EquipmentSlot.FEET:
			return "Feet"
		EquipmentSlot.NECK:
			return "Neck"
		EquipmentSlot.FINGER:
			return "Finger"
	return "Unknown"


## Get detailed string with stats
func to_detailed_string() -> String:
	var str = super.to_detailed_string()
	str += "\nSlot: %s\n" % get_slot_name()

	if get_total_bonus() > 0:
		str += "\nStat Bonuses:\n"
		for stat in stat_bonuses:
			if stat_bonuses[stat] > 0:
				str += "  %s +%d\n" % [stat.capitalize(), stat_bonuses[stat]]

	var active_resistances = 0
	for resistance_type in resistances:
		if resistances[resistance_type] > 0:
			active_resistances += 1

	if active_resistances > 0:
		str += "\nResistances:\n"
		for resistance_type in resistances:
			if resistances[resistance_type] > 0:
				str += "  %s: %d%%\n" % [resistance_type.capitalize(), resistances[resistance_type]]

	if required_level > 1:
		str += "Required Level: %d\n" % required_level

	return str


## Create a weapon with stat bonuses
static func create_weapon(
	p_id: String,
	p_name: String,
	damage_bonus: int,
	value: Currency
) -> Equipment:
	var weapon = Equipment.new(p_id, p_name, EquipmentSlot.MAIN_HAND, value)
	weapon.add_stat_bonus("strength", damage_bonus)
	weapon.item_type = ItemType.WEAPON
	return weapon


## Create armor with stat bonuses
static func create_armor(
	p_id: String,
	p_name: String,
	defense_bonus: int,
	value: Currency
) -> Equipment:
	var armor = Equipment.new(p_id, p_name, EquipmentSlot.CHEST, value)
	armor.add_stat_bonus("constitution", defense_bonus)
	armor.item_type = ItemType.ARMOR
	return armor


## Create accessory with resistances
static func create_accessory(
	p_id: String,
	p_name: String,
	resistance_type: String,
	resistance_amount: int,
	value: Currency
) -> Equipment:
	var accessory = Equipment.new(p_id, p_name, EquipmentSlot.NECK, value)
	accessory.add_resistance(resistance_type, resistance_amount)
	accessory.item_type = ItemType.ACCESSORY
	return accessory
