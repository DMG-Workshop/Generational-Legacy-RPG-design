## Equipment-Heir Integration: Equip items, inheritance, and vault storage
##
## Manages heir equipment, legendary item inheritance, equipment vault,
## and applies equipment bonuses to heir stats

class_name EquipmentHeirIntegration


signal equipment_equipped(heir_name: String, item_name: String)
signal equipment_unequipped(heir_name: String, item_name: String)
signal legendary_inherited(heir_name: String, item_name: String, from_heir: String)
signal item_added_to_vault(item_name: String)
signal item_claimed_from_vault(heir_name: String, item_name: String)


var equipment_system: EquipmentSystem
var rune_system: RuneSystem

# Heir equipment vaults (shared family storage)
var family_vault: Array = []  # [item, item, item, ...]

# Equipped items per heir (from equipment_system)
# Track currently equipped items and their stats


func _init(equipment: EquipmentSystem, runes: RuneSystem) -> void:
	equipment_system = equipment
	rune_system = runes


## Equip item to heir
func equip_item(heir_name: String, item: Dictionary) -> bool:
	var success = equipment_system.equip_item(heir_name, item)
	if success:
		equipment_equipped.emit(heir_name, item["name"])
	return success


## Unequip item from heir
func unequip_item(heir_name: String, equipment_type: int) -> Dictionary:
	var equipped = equipment_system.get_heir_equipment(heir_name)
	if equipment_type in equipped:
		var item = equipped[equipment_type]
		equipped.erase(equipment_type)
		equipment_unequipped.emit(heir_name, item["name"])
		return item
	return {}


## Get heir total stat bonus from equipment
func get_heir_equipment_bonus(heir_name: String) -> Dictionary:
	var equipment_bonus = equipment_system.get_equipment_stat_bonus(heir_name)
	var equipped = equipment_system.get_heir_equipment(heir_name)

	# Add rune bonuses
	var rune_bonus = {
		"strength": 0,
		"dexterity": 0,
		"constitution": 0,
		"intelligence": 0,
		"wisdom": 0,
		"charisma": 0,
	}

	var heir_affinities = rune_system.get_heir_affinities(heir_name)

	for equipment_type in equipped.keys():
		var item = equipped[equipment_type]
		var item_rune_stats = rune_system.get_item_rune_stats(item["id"], heir_affinities)

		for stat_key in item_rune_stats.keys():
			if stat_key in rune_bonus:
				rune_bonus[stat_key] += item_rune_stats[stat_key]

	# Combine equipment and rune bonuses
	var total_bonus = equipment_bonus.duplicate()
	for stat_key in rune_bonus.keys():
		if stat_key in total_bonus:
			total_bonus[stat_key] += rune_bonus[stat_key]
		else:
			total_bonus[stat_key] = rune_bonus[stat_key]

	return total_bonus


## Add item to family vault
func add_to_vault(item: Dictionary) -> bool:
	family_vault.append(item)
	item_added_to_vault.emit(item["name"])
	return true


## Get family vault items
func get_vault_items() -> Array:
	return family_vault.duplicate()


## Claim item from vault
func claim_from_vault(heir_name: String, item_index: int) -> Dictionary:
	if item_index < 0 or item_index >= family_vault.size():
		return {}

	var item = family_vault[item_index]
	family_vault.remove_at(item_index)
	item_claimed_from_vault.emit(heir_name, item["name"])
	return item


## Clear vault (for new game)
func clear_vault() -> void:
	family_vault.clear()


## Get vault capacity
func get_vault_info() -> Dictionary:
	return {
		"items_stored": family_vault.size(),
		"max_capacity": 20,
		"is_full": family_vault.size() >= 20,
		"items": family_vault.duplicate(),
	}


## Inherit legendary items to next heir
func inherit_legendary_items(heir_name: String, previous_heir_name: String) -> Array:
	var equipped = equipment_system.get_heir_equipment(previous_heir_name)
	var inherited = []

	for equipment_type in equipped.keys():
		var item = equipped[equipment_type]

		if item.get("legendary", false):
			# Apply inheritance bonus
			var inheritance_bonus = equipment_system.get_legendary_inheritance_bonus(item["key"])
			if inheritance_bonus > 0:
				for stat_key in item["stats"].keys():
					item["stats"][stat_key] = int(item["stats"][stat_key] * (1.0 + inheritance_bonus))

			# Transfer ownership
			equipment_system.transfer_legendary_item(heir_name, item, previous_heir_name)

			# Equip to new heir
			equip_item(heir_name, item)
			legendary_inherited.emit(heir_name, item["name"], previous_heir_name)
			inherited.append(item)

	return inherited


## Craft item and equip
func craft_and_equip(heir_name: String, equipment_key: String, crafting_sys: CraftingSystem, resources: Dictionary) -> Dictionary:
	# Attempt craft
	var craft_result = crafting_sys.craft_equipment(heir_name, equipment_key, equipment_system, resources)

	if not craft_result.get("success", false):
		return craft_result

	# Equip if successful
	var item = craft_result["item"]
	equip_item(heir_name, item)

	return {
		"success": true,
		"item": item,
		"equipped": true,
	}


## Get crafting recommendations for heir
func get_equipment_recommendations(heir_name: String, crafting_sys: CraftingSystem) -> Array[String]:
	return crafting_sys.get_craftable_equipment(heir_name, equipment_system)


## Repair equipment in vault
func repair_vault_equipment(item_index: int, repair_amount: int = -1) -> Dictionary:
	if item_index < 0 or item_index >= family_vault.size():
		return {}

	var item = family_vault[item_index]
	var repaired = equipment_system.repair_equipment(item, repair_amount)
	family_vault[item_index] = repaired
	return repaired


## Get equipment display info for UI
func get_equipment_display_info(heir_name: String) -> Dictionary:
	var equipped = equipment_system.get_heir_equipment(heir_name)
	var equipment_bonus = get_heir_equipment_bonus(heir_name)
	var vault_info = get_vault_info()

	var display = {
		"equipped": {},
		"equipment_bonus": equipment_bonus,
		"vault": vault_info,
	}

	for equipment_type in equipped.keys():
		var item = equipped[equipment_type]
		var rune_stats = rune_system.get_item_rune_stats(item["id"], rune_system.get_heir_affinities(heir_name))
		var rune_effects = rune_system.get_item_rune_effects(item["id"])

		display["equipped"][EquipmentSystem.EquipmentType.keys()[equipment_type]] = {
			"name": item["name"],
			"rarity": item["rarity_name"],
			"base_stats": item["stats"],
			"rune_stats": rune_stats,
			"rune_effects": rune_effects,
			"durability": item["durability"],
			"max_durability": item["max_durability"],
		}

	return display


## Get heir equipment summary
func get_heir_equipment_summary(heir_name: String) -> Dictionary:
	var equipped = equipment_system.get_heir_equipment(heir_name)
	var items = []

	for equipment_type in equipped.keys():
		var item = equipped[equipment_type]
		items.append({
			"name": item["name"],
			"type": EquipmentSystem.EquipmentType.keys()[item["type"]],
			"rarity": item["rarity_name"],
			"legendary": item.get("legendary", false),
		})

	return {
		"equipped_items": items,
		"total_bonus": get_heir_equipment_bonus(heir_name),
		"vault_available": get_vault_info()["items_stored"],
	}


## Check if item is legendary
func is_legendary_item(item: Dictionary) -> bool:
	return item.get("legendary", false)


## Get legendary item stat multiplier
func get_legendary_multiplier(item: Dictionary) -> float:
	if not is_legendary_item(item):
		return 1.0

	var inheritance_bonus = equipment_system.get_legendary_inheritance_bonus(item["key"])
	return 1.0 + inheritance_bonus
