## Heir Equipment: helper class for managing heir equipment
##
## Wraps equipment slots with convenient methods for equipping/unequipping items

class_name HeirEquipment


var heir: Heir


func _init(p_heir: Heir) -> void:
	heir = p_heir


## Equip an item to a slot
## Returns true if successful, false if slot incompatible
func equip_item(item: Item, slot: int) -> bool:
	if not item is Equipment:
		return false

	var equipment = item as Equipment

	# Validate slot compatibility
	if not _is_slot_valid(equipment, slot):
		return false

	# Check class restriction
	if not equipment.can_equip_class(heir.class_id):
		return false

	# Unequip whatever was in this slot
	unequip_item(slot)

	# Equip the item
	heir.equipment_slots[slot] = equipment
	return true


## Unequip item from slot
func unequip_item(slot: int) -> Item:
	if slot in heir.equipment_slots:
		var item = heir.equipment_slots[slot]
		heir.equipment_slots.erase(slot)
		return item
	return null


## Get equipped item in slot
func get_equipped(slot: int) -> Item:
	return heir.equipment_slots.get(slot, null)


## Check if slot has equipment
func is_slot_filled(slot: int) -> bool:
	return slot in heir.equipment_slots


## Get all equipped items
func get_all_equipped() -> Array[Item]:
	var equipped: Array[Item] = []
	for slot in heir.equipment_slots:
		equipped.append(heir.equipment_slots[slot])
	return equipped


## Get total stat bonuses from all equipped items
func get_total_stat_bonuses() -> Dictionary:
	var bonuses = {
		"strength": 0,
		"dexterity": 0,
		"constitution": 0,
		"intelligence": 0,
		"wisdom": 0,
		"charisma": 0
	}

	for item in get_all_equipped():
		if item is Equipment:
			var eq = item as Equipment
			for stat in bonuses:
				if stat in eq.stat_bonuses:
					bonuses[stat] += eq.stat_bonuses[stat]

	return bonuses


## Get total resistances from all equipped items
func get_total_resistances() -> Dictionary:
	var resistances = {
		"fire": 0,
		"cold": 0,
		"lightning": 0,
		"poison": 0,
		"magic": 0
	}

	for item in get_all_equipped():
		if item is Equipment:
			var eq = item as Equipment
			for res_type in resistances:
				if res_type in eq.resistances:
					# Resistances stack additively but cap at 100
					resistances[res_type] = mini(resistances[res_type] + eq.resistances[res_type], 100)

	return resistances


## Get total equipment value
func get_total_value() -> int:
	var total_copper = 0
	for item in get_all_equipped():
		total_copper += item.value.to_copper()
	return total_copper


## Get equipment slot name
func get_slot_name(slot: int) -> String:
	match slot:
		Equipment.EquipmentSlot.MAIN_HAND:
			return "Main Hand"
		Equipment.EquipmentSlot.OFF_HAND:
			return "Off Hand"
		Equipment.EquipmentSlot.TWO_HANDED:
			return "Two Handed"
		Equipment.EquipmentSlot.HEAD:
			return "Head"
		Equipment.EquipmentSlot.CHEST:
			return "Chest"
		Equipment.EquipmentSlot.HANDS:
			return "Hands"
		Equipment.EquipmentSlot.LEGS:
			return "Legs"
		Equipment.EquipmentSlot.FEET:
			return "Feet"
		Equipment.EquipmentSlot.NECK:
			return "Neck"
		Equipment.EquipmentSlot.FINGER:
			return "Finger"
	return "Unknown"


## Get equipment summary
func get_summary() -> String:
	var equipped_count = heir.equipment_slots.size()
	var total_bonus = 0
	for stat in get_total_stat_bonuses():
		total_bonus += get_total_stat_bonuses()[stat]

	return "Equipment: %d items equipped, +%d total stat bonus" % [equipped_count, total_bonus]


## Internal: Validate slot compatibility
func _is_slot_valid(equipment: Equipment, slot: int) -> bool:
	# Special handling for hand slots
	if equipment.equipment_slot == Equipment.EquipmentSlot.TWO_HANDED:
		# Two-handed weapons can only go in main hand
		return slot == Equipment.EquipmentSlot.MAIN_HAND

	# For other equipment, slot must match
	return equipment.equipment_slot == slot


## Clear all equipment
func clear() -> void:
	heir.equipment_slots.clear()
