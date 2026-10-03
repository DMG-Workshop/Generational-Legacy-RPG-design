## Equipment System: Equipment definitions, rarity tiers, and stat bonuses
##
## Manages equipment database, crafting recipes, inheritance, and equipment stats
## Legendary items persist across generations with accumulated bonuses

class_name EquipmentSystem


signal equipment_created(item_id: String, item_name: String, rarity: String)
signal equipment_equipped(heir_name: String, item_name: String)
signal equipment_inherited(heir_name: String, item_name: String, previous_owner: String)


enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum EquipmentType { WEAPON, ARMOR, ACCESSORY }

# Equipment definitions
var equipment_database: Dictionary = {
	"iron_sword": {
		"name": "Iron Sword",
		"type": EquipmentType.WEAPON,
		"rarity": Rarity.COMMON,
		"base_stats": {"strength": 3, "dexterity": 1},
		"durability": 50,
		"weight": 4,
		"description": "A simple iron blade, reliable and sturdy",
	},
	"steel_sword": {
		"name": "Steel Sword",
		"type": EquipmentType.WEAPON,
		"rarity": Rarity.UNCOMMON,
		"base_stats": {"strength": 5, "dexterity": 2},
		"durability": 75,
		"weight": 5,
		"description": "A well-forged steel weapon",
	},
	"enchanted_blade": {
		"name": "Enchanted Blade",
		"type": EquipmentType.WEAPON,
		"rarity": Rarity.RARE,
		"base_stats": {"strength": 7, "dexterity": 4, "intelligence": 2},
		"durability": 100,
		"weight": 5,
		"description": "A blade infused with magical essence",
	},
	"dragon_slayer": {
		"name": "Dragon Slayer",
		"type": EquipmentType.WEAPON,
		"rarity": Rarity.EPIC,
		"base_stats": {"strength": 12, "dexterity": 6, "constitution": 3},
		"durability": 150,
		"weight": 6,
		"description": "Forged specifically to slay dragons",
	},
	"shadow_knight_blade": {
		"name": "Shadow Knight's Blade",
		"type": EquipmentType.WEAPON,
		"rarity": Rarity.LEGENDARY,
		"base_stats": {"strength": 15, "dexterity": 10, "intelligence": 5},
		"durability": 200,
		"weight": 7,
		"description": "The blade of a fallen warrior, dark and powerful",
		"legendary": true,
		"inheritance_bonus": 0.1,  # 10% stat bonus per generation owned
	},
	"leather_armor": {
		"name": "Leather Armor",
		"type": EquipmentType.ARMOR,
		"rarity": Rarity.COMMON,
		"base_stats": {"constitution": 2, "dexterity": 1},
		"durability": 40,
		"weight": 3,
		"description": "Light and flexible leather protection",
	},
	"plate_armor": {
		"name": "Plate Armor",
		"type": EquipmentType.ARMOR,
		"rarity": Rarity.UNCOMMON,
		"base_stats": {"constitution": 5, "strength": 1},
		"durability": 100,
		"weight": 8,
		"description": "Heavy plate protection",
	},
	"mithril_mail": {
		"name": "Mithril Mail",
		"type": EquipmentType.ARMOR,
		"rarity": Rarity.RARE,
		"base_stats": {"constitution": 8, "dexterity": 3},
		"durability": 150,
		"weight": 6,
		"description": "Rare mithril woven into protective mail",
	},
	"dragon_scale_armor": {
		"name": "Dragon Scale Armor",
		"type": EquipmentType.ARMOR,
		"rarity": Rarity.EPIC,
		"base_stats": {"constitution": 12, "strength": 3, "wisdom": 2},
		"durability": 200,
		"weight": 7,
		"description": "Armor crafted from dragon scales",
	},
	"void_fragment": {
		"name": "Void Fragment",
		"type": EquipmentType.ACCESSORY,
		"rarity": Rarity.LEGENDARY,
		"base_stats": {"intelligence": 8, "wisdom": 6, "charisma": 4},
		"durability": 150,
		"weight": 1,
		"description": "A fragment from beyond dimensions",
		"legendary": true,
		"inheritance_bonus": 0.12,
	},
	"ring_of_wisdom": {
		"name": "Ring of Wisdom",
		"type": EquipmentType.ACCESSORY,
		"rarity": Rarity.RARE,
		"base_stats": {"wisdom": 4, "intelligence": 2},
		"durability": 50,
		"weight": 0,
		"description": "A ring that enhances wisdom",
	},
	"amulet_of_protection": {
		"name": "Amulet of Protection",
		"type": EquipmentType.ACCESSORY,
		"rarity": Rarity.UNCOMMON,
		"base_stats": {"constitution": 3, "wisdom": 1},
		"durability": 60,
		"weight": 0,
		"description": "A protective charm",
	},
}

# Equipped items per heir
var heir_equipment: Dictionary = {}  # heir_name -> {slot_type -> item_id}

# Legendary item tracking (persists across generations)
var legendary_items: Dictionary = {}  # item_id -> {name, owner_history, generation_count, current_owner}


func _init() -> void:
	_initialize_legendary_tracking()


## Create item instance
func create_item(equipment_key: String, custom_stats: Dictionary = {}) -> Dictionary:
	if equipment_key not in equipment_database:
		return {}

	var template = equipment_database[equipment_key]
	var item_id = "%s_%d" % [equipment_key, randi()]

	var stats = template["base_stats"].duplicate()
	for stat_key in custom_stats.keys():
		if stat_key in stats:
			stats[stat_key] += custom_stats[stat_key]

	var item = {
		"id": item_id,
		"key": equipment_key,
		"name": template["name"],
		"type": template["type"],
		"rarity": template["rarity"],
		"rarity_name": Rarity.keys()[template["rarity"]],
		"stats": stats,
		"durability": template["durability"],
		"max_durability": template["durability"],
		"weight": template["weight"],
		"description": template["description"],
		"created_at": Time.get_ticks_msec(),
	}

	if "legendary" in template and template["legendary"]:
		item["legendary"] = true
		item["inheritance_bonus"] = template.get("inheritance_bonus", 0.0)

	equipment_created.emit(item_id, item["name"], item["rarity_name"])
	return item


## Get equipment template
func get_equipment_template(equipment_key: String) -> Dictionary:
	return equipment_database.get(equipment_key, {})


## Get all equipment
func get_all_equipment() -> Array[String]:
	return equipment_database.keys()


## Get equipment by rarity
func get_equipment_by_rarity(rarity: int) -> Array[String]:
	var items = []
	for key in equipment_database.keys():
		if equipment_database[key]["rarity"] == rarity:
			items.append(key)
	return items


## Get equipment by type
func get_equipment_by_type(equip_type: int) -> Array[String]:
	var items = []
	for key in equipment_database.keys():
		if equipment_database[key]["type"] == equip_type:
			items.append(key)
	return items


## Equip item to heir
func equip_item(heir_name: String, item: Dictionary) -> bool:
	if heir_name not in heir_equipment:
		heir_equipment[heir_name] = {}

	var equip_type = item["type"]
	heir_equipment[heir_name][equip_type] = item

	equipment_equipped.emit(heir_name, item["name"])
	return true


## Get equipped items for heir
func get_heir_equipment(heir_name: String) -> Dictionary:
	return heir_equipment.get(heir_name, {})


## Get heir equipment stats bonus
func get_equipment_stat_bonus(heir_name: String) -> Dictionary:
	if heir_name not in heir_equipment:
		return {}

	var bonus = {
		"strength": 0,
		"dexterity": 0,
		"constitution": 0,
		"intelligence": 0,
		"wisdom": 0,
		"charisma": 0,
	}

	for equipment_type in heir_equipment[heir_name].keys():
		var item = heir_equipment[heir_name][equipment_type]
		for stat_key in item["stats"].keys():
			if stat_key in bonus:
				bonus[stat_key] += item["stats"][stat_key]

	return bonus


## Track legendary item ownership
func transfer_legendary_item(heir_name: String, item: Dictionary, previous_owner: String = "") -> void:
	if not item.get("legendary", false):
		return

	var item_key = item["key"]
	if item_key not in legendary_items:
		legendary_items[item_key] = {
			"name": item["name"],
			"owner_history": [],
			"generation_count": 0,
			"current_owner": heir_name,
		}

	var legendary = legendary_items[item_key]
	legendary["owner_history"].append(previous_owner)
	legendary["generation_count"] += 1
	legendary["current_owner"] = heir_name

	equipment_inherited.emit(heir_name, item["name"], previous_owner)


## Get legendary items
func get_legendary_items() -> Array[String]:
	return legendary_items.keys()


## Get legendary item history
func get_legendary_history(item_key: String) -> Dictionary:
	return legendary_items.get(item_key, {})


## Get equipment stat bonus for legendary item
func get_legendary_inheritance_bonus(item_key: String) -> float:
	if item_key not in equipment_database:
		return 0.0

	var template = equipment_database[item_key]
	if not template.get("legendary", false):
		return 0.0

	var legendary_data = legendary_items.get(item_key, {})
	var generation_count = legendary_data.get("generation_count", 1)
	var inheritance_bonus = template.get("inheritance_bonus", 0.1)

	# Bonus scales with generations owned (capped at 50% total)
	return minf(inheritance_bonus * generation_count, 0.5)


## Repair equipment
func repair_equipment(item: Dictionary, repair_amount: int = -1) -> Dictionary:
	var repaired = item.duplicate()
	if repair_amount < 0:
		repaired["durability"] = repaired["max_durability"]
	else:
		repaired["durability"] = mini(repaired["durability"] + repair_amount, repaired["max_durability"])
	return repaired


## Damage equipment
func damage_equipment(item: Dictionary, damage_amount: int) -> Dictionary:
	var damaged = item.duplicate()
	damaged["durability"] = maxi(damaged["durability"] - damage_amount, 0)
	return damaged


## Check if equipment is broken
func is_broken(item: Dictionary) -> bool:
	return item["durability"] <= 0


## Get crafting requirements for equipment
func get_crafting_requirements(equipment_key: String) -> Dictionary:
	var template = get_equipment_template(equipment_key)
	if template.is_empty():
		return {}

	var rarity = template["rarity"]
	var material_cost = 10 + (rarity * 15)
	var gold_cost = 50 + (rarity * 100)
	var skill_level_required = rarity + 1

	return {
		"materials": material_cost,
		"gold": gold_cost,
		"skill_level": skill_level_required,
		"crafting_skill": _get_crafting_skill_for_type(template["type"]),
	}


## Get rarity color/label
func get_rarity_label(rarity: int) -> String:
	return Rarity.keys()[rarity]


## Internal: Initialize legendary item tracking
func _initialize_legendary_tracking() -> void:
	for key in equipment_database.keys():
		var template = equipment_database[key]
		if template.get("legendary", false):
			legendary_items[key] = {
				"name": template["name"],
				"owner_history": [],
				"generation_count": 0,
				"current_owner": "",
			}


## Internal: Get crafting skill for equipment type
func _get_crafting_skill_for_type(equip_type: int) -> String:
	match equip_type:
		EquipmentType.WEAPON:
			return "Blacksmithing"
		EquipmentType.ARMOR:
			return "Leatherworking"
		EquipmentType.ACCESSORY:
			return "Runecrafting"
	return "Crafting"


## Get equipment summary
func get_equipment_summary(item: Dictionary) -> Dictionary:
	return {
		"name": item["name"],
		"type": EquipmentType.keys()[item["type"]],
		"rarity": item["rarity_name"],
		"stats": item["stats"],
		"durability": item["durability"],
		"max_durability": item["max_durability"],
		"description": item["description"],
		"legendary": item.get("legendary", false),
	}
